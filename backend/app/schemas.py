from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models import OrderStatus, UserRole

# Indian mobile numbers: 10 digits, first digit 6-9 (no country code prefix —
# the app collects the local number only).
PHONE_PATTERN = r"^[6-9]\d{9}$"
# Indian PIN codes: 6 digits, first digit 1-9.
PINCODE_PATTERN = r"^[1-9]\d{5}$"

# ---------------------------------------------------------------------------
# Auth / users
# ---------------------------------------------------------------------------


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    store_id: int | None
    name: str
    email: str | None
    phone: str
    role: UserRole
    is_active: bool
    address_line1: str | None
    town: str | None
    district: str | None
    state: str | None
    pincode: str | None


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    phone: str = Field(pattern=PHONE_PATTERN, description="10-digit Indian mobile number, no country code")
    email: str | None = None
    address_line1: str = Field(min_length=1, max_length=255)
    town: str = Field(min_length=1, max_length=120)
    district: str = Field(min_length=1, max_length=120)
    state: str = Field(min_length=1, max_length=120)
    pincode: str = Field(pattern=PINCODE_PATTERN, description="6-digit Indian PIN code")

    @field_validator("email")
    @classmethod
    def empty_email_to_none(cls, v: str | None) -> str | None:
        return v.strip() if v and v.strip() else None


class RegisterResponse(BaseModel):
    message: str
    user: UserOut


class LoginRequest(BaseModel):
    """Owner login only — customers authenticate via phone + OTP instead."""

    phone: str
    password: str


class TokenResponse(BaseModel):
    token: str
    user: UserOut


# ---------------------------------------------------------------------------
# OTP login (customers)
# ---------------------------------------------------------------------------


class OtpRequestRequest(BaseModel):
    phone: str = Field(pattern=PHONE_PATTERN)


class OtpRequestResponse(BaseModel):
    message: str
    expires_in_seconds: int
    # Only populated in dev mode (no real SMS provider configured) so the
    # app can display the code without an actual text message.
    dev_otp: str | None = None


class OtpVerifyRequest(BaseModel):
    phone: str = Field(pattern=PHONE_PATTERN)
    code: str = Field(min_length=4, max_length=4)


# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    store_id: int
    name: str
    sort_order: int
    is_active: bool


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    sort_order: int = 0


class CategoryUpdate(BaseModel):
    name: str | None = None
    sort_order: int | None = None
    is_active: bool | None = None


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    store_id: int
    category_id: int
    name: str
    name_te: str | None
    description: str | None
    image_url: str | None
    price: float
    unit: str
    is_available: bool


class AvailabilityUpdate(BaseModel):
    is_available: bool


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------


class OrderItemIn(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)


class OrderCreateRequest(BaseModel):
    items: list[OrderItemIn] = Field(min_length=1)
    notes: str | None = None


class OrderItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    product_name: str
    product_price: float
    unit: str
    quantity: int
    line_total: float


class OrderStatusHistoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    status: OrderStatus
    changed_at: datetime


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    store_id: int
    order_number: str
    customer_id: int
    customer_name: str
    customer_phone: str
    status: OrderStatus
    notes: str | None
    subtotal: float
    total_amount: float
    order_date: datetime
    updated_at: datetime
    items: list[OrderItemOut]
    status_history: list[OrderStatusHistoryOut]


class OrderCreateResponse(BaseModel):
    order: OrderOut
    whatsapp_message: str
    whatsapp_url: str


class OrderStatusUpdateRequest(BaseModel):
    status: OrderStatus


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    order_id: int | None
    type: str
    message: str
    is_read: bool
    created_at: datetime


class UnreadCountOut(BaseModel):
    count: int
