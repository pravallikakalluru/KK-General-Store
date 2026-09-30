"""Applies the brinjal variety photos "as it is" per explicit instruction -
the ENTIRE source photo from brinjal_images/, letterboxed to fit the
square canvas, never cropped down to isolate a single brinjal. Same
approach as the other apply_*_entire.py scripts.

Brinjal_Green.jpg shows dark purple/black eggplants, not green - flagged
to the user (again - same issue found earlier this project), who chose to
use it anyway this round, consistent with "as it is" for this whole batch.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\brinjal_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Baby_Brinjal.jpg": "Baby Brinjal",
    "Brinjal_Green.jpg": "Green Brinjal",
    "Brinjal_Long_Purple.jpg": "Long Purple Brinjal",
    "Brinjal_Purple.jpg": "Brinjal (Eggplant)",
    "Brinjal_Round_Purple.jpg": "Round Purple Brinjal",
    "Brinjal_Striped.jpg": "Striped Brinjal",
    "Brinjal_White.jpg": "White Brinjal",
    "Small_Brinjal.jpg": "Small Brinjal",
}


def slugify(name: str) -> str:
    return "".join(c.lower() if c.isalnum() else "-" for c in name).strip("-")


def entire_image_on_canvas(img: Image.Image) -> Image.Image:
    img = img.convert("RGB")
    canvas = Image.new("RGB", (CANVAS, CANVAS), "white")
    fitted = img.copy()
    fitted.thumbnail((CANVAS, CANVAS), Image.LANCZOS)
    px = (CANVAS - fitted.width) // 2
    py = (CANVAS - fitted.height) // 2
    canvas.paste(fitted, (px, py))
    return canvas


def run() -> None:
    products_dir = Path(settings.static_dir) / "products"
    db = SessionLocal()
    try:
        updated = 0
        not_found = []
        for filename, product_name in FILENAME_TO_PRODUCT.items():
            src_path = SOURCE_DIR / filename
            if not src_path.exists():
                print(f"  WARNING: {filename} not found, skipping")
                continue

            product = db.scalar(select(Product).where(Product.name == product_name))
            if product is None:
                not_found.append(product_name)
                continue

            img = Image.open(src_path)
            final_img = entire_image_on_canvas(img)

            out_filename = f"{slugify(product_name)}-photo.png"
            new_url = f"/static/products/{out_filename}"

            if product.image_url != new_url:
                delete_product_image(product.image_url)

            final_img.save(products_dir / out_filename)
            product.image_url = new_url
            updated += 1
            print(f"  {product_name} <- {filename}")

        db.commit()
        print(f"\nUpdated {updated} brinjal products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
