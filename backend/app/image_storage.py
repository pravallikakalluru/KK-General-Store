import uuid
from pathlib import Path

from fastapi import UploadFile

from app.config import get_settings

settings = get_settings()

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def products_dir() -> Path:
    path = Path(settings.static_dir) / "products"
    path.mkdir(parents=True, exist_ok=True)
    return path


def save_product_image(file: UploadFile) -> str:
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        suffix = ".jpg"

    filename = f"{uuid.uuid4().hex}{suffix}"
    destination = products_dir() / filename

    with destination.open("wb") as out_file:
        out_file.write(file.file.read())

    return f"/static/products/{filename}"


def delete_product_image(image_url: str | None) -> None:
    if not image_url or not image_url.startswith("/static/products/"):
        return
    filename = image_url.removeprefix("/static/products/")
    path = products_dir() / filename
    if path.exists():
        path.unlink()
