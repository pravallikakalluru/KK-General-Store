"""Applies the bulb & stem vegetable photos "as it is" per explicit
instruction - the ENTIRE source photo from bulb_stem_vegetables_images/,
letterboxed to fit the square canvas, never cropped down to isolate a
single vegetable. Same approach as the other apply_*_entire.py scripts.

These products live in the generic "Vegetables" category (no dedicated
"Bulb & Stem" category exists). Celery.jpg here is a duplicate of the one
in leafy_vegetable_images/, already applied to the Celery product this
session - skipped. Lotus_Stem.jpg has no matching product ("Lotus Root
(Stem)" is a different product already photographed from a different
source). Spring_Onion.jpg here is a second source for the Spring Onion
product (already freshly set this session from a different file in the
leafy-vegetables batch) - left alone rather than overwritten without being
asked.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\bulb_stem_vegetables_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Asparagus.jpg": "Asparagus",
    "Bamboo_Shoot.jpg": "Bamboo Shoot",
    "Banana_Stem.jpg": "Banana Stem",
    "Fennel.jpg": "Fennel",
    "Garlic.jpg": "Garlic",
    "Leek.jpg": "Leek",
    "Onion.jpg": "Onion",
    "Shallots_Small_Onion.jpg": "Shallots (Small Onion)",
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
        print(f"\nUpdated {updated} bulb/stem vegetable products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
