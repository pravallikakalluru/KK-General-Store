import logging
import secrets

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger("otp")


def generate_code() -> str:
    """4-digit numeric OTP, e.g. '0492' (leading zeros allowed)."""
    return f"{secrets.randbelow(10 ** settings.otp_length):0{settings.otp_length}d}"


def send_otp(phone: str, code: str) -> None:
    """Deliver the OTP to the customer's phone.

    Dev mode (no SMS provider configured): just log it — the code is also
    returned directly in the API response so the app can display it. To go
    live, set otp_dev_mode=False and replace this function's body with a
    call to a real SMS provider (e.g. MSG91, Twilio) using `settings` for
    API credentials; nothing else in the OTP flow needs to change.
    """
    if settings.otp_dev_mode:
        logger.info("[DEV MODE] OTP for %s is %s (not actually sent via SMS)", phone, code)
        return

    raise NotImplementedError("No SMS provider configured. Set otp_dev_mode=True or implement send_otp().")
