"""Applies the daily_essentials_images/ photos "as it is" per explicit
instruction - the ENTIRE source photo, letterboxed to fit the square
canvas, never cropped down to isolate a single item. Same approach as
the other apply_*_entire.py scripts.

Sesame_Oil.jpg here is a byte-identical duplicate of the one already
applied from pooja_items_images/ earlier this session - skipped.

5 photos show clear competitor branding (Arm & Hammer baking soda, Kraft
cheese, Hollywood peanut oil, Maldon sea salt, a vintage Abbotts Ald.
Dairies milk bottle opener) - used with branding intact per explicit user
choice ("use all 5 anyway"). Figs.jpg's visible price tag and Butter.jpg's
incidental hand were also kept as-is per user choice.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\daily_essentials_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Almonds.jpg": "Almonds",
    "Baking_Soda.jpg": "Baking Soda",
    "Betel_Leaves.jpg": "Betel Leaves",
    "Betel_Nut.jpg": "Betel Nut",
    "Biscuits.jpg": "Biscuits",
    "Bread.jpg": "Bread",
    "Butter.jpg": "Butter",
    "Cheese_Slices.jpg": "Cheese Slices",
    "Cornflakes.jpg": "Cornflakes",
    "Dried_Apricots.jpg": "Dried Apricots",
    "Eggs.jpg": "Eggs",
    "Figs.jpg": "Figs",
    "Ground_Nut_Oil.jpg": "Groundnut Oil",
    "Himalayan_Pink_Salt.jpg": "Himalayan Pink Salt",
    "Jaggery.jpg": "Jaggery",
    "Maggi_Noodles.jpg": "Maggi Noodles",
    "Makhana.jpg": "Makhana",
    "Milk.jpg": "Milk",
    "Paneer.jpg": "Paneer",
    "Peanuts.jpg": "Peanuts",
    "Raisins.jpg": "Raisins",
    "Rock_Salt.jpg": "Rock Salt",
    "Rusk.jpg": "Rusk",
    "Salt.jpg": "Salt",
    "Sesame_Seeds.jpg": "Sesame Seeds",
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
        print(f"\nUpdated {updated} daily essentials products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
