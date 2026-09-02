from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.deps import get_current_user
from app.models import OtpCode, User, UserRole
from app.otp_service import generate_code, send_otp
from app.schemas import (
    LoginRequest,
    OtpRequestRequest,
    OtpRequestResponse,
    OtpVerifyRequest,
    RegisterRequest,
    RegisterResponse,
    TokenResponse,
    UserOut,
)
from app.security import create_access_token, verify_password
from app.store_utils import get_default_store

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> RegisterResponse:
    """Creates the customer's profile. No password is collected — the
    customer logs in afterward with phone + OTP via /auth/otp/request and
    /auth/otp/verify."""
    store = get_default_store(db)

    existing = db.scalar(select(User).where(User.phone == payload.phone))
    if existing is not None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "An account with this phone number already exists")

    if payload.email is not None:
        existing_email = db.scalar(select(User).where(User.email == payload.email))
        if existing_email is not None:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "An account with this email already exists")

    user = User(
        store_id=store.id,
        name=payload.name,
        email=payload.email,
        phone=payload.phone,
        role=UserRole.CUSTOMER,
        address_line1=payload.address_line1,
        town=payload.town,
        district=payload.district,
        state=payload.state,
        pincode=payload.pincode,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return RegisterResponse(
        message="Registration successful! You can now log in with your mobile number and OTP.",
        user=UserOut.model_validate(user),
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Owner (password) login. Customers use /auth/otp/* instead."""
    user = db.scalar(select(User).where(User.phone == payload.phone))
    if user is None or user.password_hash is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid phone number or password")
    if not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "This account has been deactivated")

    token = create_access_token(user_id=user.id, role=user.role.value, store_id=user.store_id)
    return TokenResponse(token=token, user=UserOut.model_validate(user))


@router.post("/otp/request", response_model=OtpRequestResponse)
def request_otp(payload: OtpRequestRequest, db: Session = Depends(get_db)) -> OtpRequestResponse:
    user = db.scalar(select(User).where(User.phone == payload.phone))
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "This number is not registered. Please register first.")
    if not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "This account has been deactivated")

    if user.otp_locked_until is not None and _utcnow() < user.otp_locked_until:
        remaining = int((user.otp_locked_until - _utcnow()).total_seconds())
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            f"Too many incorrect attempts. Please try again in {max(remaining // 60 + 1, 1)} minute(s).",
        )

    code = generate_code()
    otp = OtpCode(
        user_id=user.id,
        phone=user.phone,
        code=code,
        purpose="login",
        expires_at=_utcnow() + timedelta(seconds=settings.otp_expire_seconds),
    )
    db.add(otp)
    db.commit()

    send_otp(user.phone, code)

    return OtpRequestResponse(
        message="OTP sent to your mobile number.",
        expires_in_seconds=settings.otp_expire_seconds,
        dev_otp=code if settings.otp_dev_mode else None,
    )


@router.post("/otp/verify", response_model=TokenResponse)
def verify_otp(payload: OtpVerifyRequest, db: Session = Depends(get_db)) -> TokenResponse:
    user = db.scalar(select(User).where(User.phone == payload.phone))
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "This number is not registered. Please register first.")

    if user.otp_locked_until is not None and _utcnow() < user.otp_locked_until:
        remaining = int((user.otp_locked_until - _utcnow()).total_seconds())
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            f"Too many incorrect attempts. Please try again in {max(remaining // 60 + 1, 1)} minute(s).",
        )

    latest_otp = db.scalar(
        select(OtpCode)
        .where(OtpCode.user_id == user.id, OtpCode.purpose == "login", OtpCode.consumed.is_(False))
        .order_by(OtpCode.created_at.desc())
    )

    if latest_otp is None or latest_otp.expires_at < _utcnow():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "OTP has expired. Please request a new one.")

    if latest_otp.code != payload.code:
        user.otp_failed_attempts += 1
        if user.otp_failed_attempts >= settings.otp_max_attempts:
            user.otp_locked_until = _utcnow() + timedelta(minutes=settings.otp_lockout_minutes)
            user.otp_failed_attempts = 0
            db.commit()
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS,
                f"Too many incorrect attempts. Please try again in {settings.otp_lockout_minutes} minutes.",
            )
        remaining_attempts = settings.otp_max_attempts - user.otp_failed_attempts
        db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Incorrect OTP. {remaining_attempts} attempt(s) remaining.")

    latest_otp.consumed = True
    user.otp_failed_attempts = 0
    user.otp_locked_until = None
    db.commit()
    db.refresh(user)

    token = create_access_token(user_id=user.id, role=user.role.value, store_id=user.store_id)
    return TokenResponse(token=token, user=UserOut.model_validate(user))


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(current_user)
