"""Applies the cleaning_products_images/ photos "as it is" per explicit
instruction - the ENTIRE source photo, letterboxed to fit the square
canvas. Same approach as the other apply_*_entire.py scripts, including
ImageOps.exif_transpose() first.

This folder is unusual: of 77 files, only 25 are unique - the rest form
17 groups where 2-5 DIFFERENT product names share one identical stock
photo. Per explicit user decision, only files with NO visible competitor
branding are used; anything clearly branded (Windex, VIM, Dettol, Tide,
Oxydol, Denkmit, Febreze, Sunlight, Libman, Attack/KAO, and more), plus a
handful of borderline cases (a vintage illustration instead of a real
photo, a person as the dominant subject, a busy multi-bottle shelf, a
photo with no actual dustbin visible, one with an added annotation
graphic), were skipped entirely - confirmed with the user across two
rounds of review. That cut the original ~70 candidate products down to
28 new products + 3 existing-product refreshes (Dishwash Liquid, Mop,
Toilet Cleaner). 4 other existing products (Floor Cleaner, Phenyl, Scrub
Pad, Detergent Soap Bar) had a matching filename in this folder too, but
every one of those turned out to be branded - so they were deliberately
left untouched, keeping their current photos rather than being
"updated" to a competitor-branded image.
"""

from pathlib import Path

from PIL import Image, ImageOps
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\cleaning_products_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Coconut_Broom.jpg": "Coconut Broom",
    "Grass_Broom_Jhadu.jpg": "Grass Broom (Jhadu)",
    "Hard_Floor_Brush.jpg": "Hard Floor Brush",
    "Soft_Broom.jpg": "Soft Broom",
    "Tile_Scrub_Brush.jpg": "Tile Scrub Brush",
    "Bathroom_Squeegee.jpg": "Bathroom Squeegee",
    "Floor_Cleaning_Cloth.jpg": "Floor Cleaning Cloth",
    "Floor_Wiper.jpg": "Floor Wiper",
    "Rubber_Wiper.jpg": "Rubber Wiper",
    "Floor_Mop.jpg": "Mop",
    "Mop_Refill.jpg": "Mop Refill",
    "Spin_Mop.jpg": "Spin Mop",
    "Spray_Mop.jpg": "Spray Mop",
    "Cobweb_Duster.jpg": "Cobweb Duster",
    "Dusting_Brush.jpg": "Dusting Brush",
    "Feather_Duster.jpg": "Feather Duster",
    "Dishwashing_Brush.jpg": "Dishwashing Brush",
    "Sink_Cleaning_Brush.jpg": "Sink Cleaning Brush",
    "Toilet_Bleach.jpg": "Toilet Bleach",
    "Toilet_Cleaner_Liquid.jpg": "Toilet Cleaner",
    "Dishwash_Liquid.jpg": "Dishwash Liquid",
    "Dustbin.jpg": "Dustbin",
    "Dustpan.jpg": "Dustpan",
    "Dustpan_Brush_Set.jpg": "Dustpan & Brush Set",
    "Electronics_Cleaning_Cloth.jpg": "Electronics Cleaning Cloth",
    "Laundry_Brush.jpg": "Laundry Brush",
    "Microfiber_Cloth.jpg": "Microfiber Cloth",
    "Plastic_Broom.jpg": "Plastic Broom",
    "Shoe_Cleaning_Brush.jpg": "Shoe Cleaning Brush",
    "Toilet_Brush.jpg": "Toilet Brush",
    "Toilet_Freshener.jpg": "Toilet Freshener",
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
            img = ImageOps.exif_transpose(img)
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
        print(f"\nUpdated {updated} cleaning products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
