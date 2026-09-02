from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "postgresql+psycopg2://grocery_app:changeme@localhost:5432/grocery_app"

    jwt_secret_key: str = "dev-only-change-me"
    jwt_algorithm: str = "HS256"
    jwt_expire_days: int = 30

    static_dir: str = "static"

    seed_store_name: str = "KK General Store"
    seed_store_code: str = "ORD"
    seed_store_whatsapp_number: str = "919999999999"
    seed_owner_phone: str = "9999999999"
    seed_owner_password: str = "owner12345"

    # OTP login rules (see docs/API_CONTRACT.md): 4-digit code, 2-minute
    # expiry, 3 wrong attempts locks the phone out for 10 minutes.
    otp_length: int = 4
    otp_expire_seconds: int = 120
    otp_max_attempts: int = 3
    otp_lockout_minutes: int = 10
    # Dev-mode: no real SMS provider is configured, so the generated code is
    # returned in the API response (and logged) instead of being texted.
    # Set to False once a real SMS provider is wired into otp_service.py.
    otp_dev_mode: bool = True


@lru_cache
def get_settings() -> Settings:
    return Settings()
