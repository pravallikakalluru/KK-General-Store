"""Applies the other_common_vegetables_images/ photos "as it is" per
explicit instruction - the ENTIRE source photo, letterboxed to fit the
square canvas, never cropped down to isolate a single item. Same approach
as the other apply_*_entire.py scripts.

Bamboo_Shoot.JPG, Banana_Stem.jpg, Fennel_Bulb.jpg and Lotus_Stem.jpg in
this folder are byte-identical duplicates of files already applied from
bulb_stem_vegetables_images/ this session - skipped here.

Green_Mango.jpg replaces what turned out to be a genuinely wrong photo
(the existing "Green Mango" product was showing pickled mango slices in
oil, not a fresh raw mango) - a real fix, not just a refresh.
Drumstick_Moringa.jpg and Mushroom.jpg replace already-reasonable photos
of the same correct subject, for consistency with this whole batch's
"entire image" treatment.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\other_common_vegetables_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Baby_Corn.jpg": "Baby Corn",
    "Banana_Flower.jpg": "Banana Flower",
    "Corn_Sweet_Corn.jpg": "Sweet Corn",
    "Drumstick_Moringa.jpg": "Drumstick",
    "Green_Mango.jpg": "Green Mango",
    "Mushroom.jpg": "Button Mushroom",
    "Raw_Banana_Green_Banana.jpg": "Raw Banana",
    "Raw_Jackfruit.jpg": "Raw Jackfruit",
    "Raw_Papaya.jpg": "Raw Papaya",
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
        print(f"\nUpdated {updated} other-common-vegetable products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
