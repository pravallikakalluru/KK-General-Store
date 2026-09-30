"""Applies the Leafy Vegetables photos "as it is" per explicit
instruction - the ENTIRE source photo from leafy_vegetable_images/,
letterboxed to fit the square canvas, never cropped down to isolate a
single leaf/plant. Same approach as apply_rice_photos.py /
apply_root_vegetables_entire.py / apply_gourds_entire.py.

Three sources had real content concerns (a retail store crate w/ price
tags for Celery, a street/documentary photo w/ a person for Gongura, a
hand-holding-roots photo for Radish Leaves) - flagged to the user, who
confirmed using all three as-is.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\leafy_vegetable_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Amaranth_Leaves.jpg": "Amaranth Leaves",
    "Arugula.jpg": "Arugula",
    "Basella_Malabar_Spinach.jpg": "Malabar Spinach (Basella)",
    "Celery.jpg": "Celery",
    "Coriander_Leaves.jpg": "Coriander Leaves",
    "Curry_Leaves.jpg": "Curry Leaves",
    "Dill_Soa.jpg": "Dill (Soa)",
    "Drumstick_Moringa_Leaves.jpg": "Drumstick Leaves",
    "Fenugreek_Methi.jpg": "Fenugreek Leaves (Methi)",
    "Gongura_Sorrel.jpg": "Gongura",
    "Kale.jpg": "Kale",
    "Lettuce.jpg": "Lettuce",
    "Mint_Leaves.jpg": "Mint Leaves",
    "Mustard_Sarson.jpg": "Mustard Leaves",
    "Radish_Leaves.jpg": "Radish Leaves",
    "Red_Amaranth.jpg": "Red Amaranth",
    "Spinach_Palak.jpg": "Spinach",
    "Spring_Onion_Greens.jpg": "Spring Onion",
    "Turnip_Greens.jpg": "Turnip Greens",
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
        print(f"\nUpdated {updated} leafy vegetable products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
