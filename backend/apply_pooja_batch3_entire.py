"""Applies the newest additions to pooja_items_images/ "as it is" per
explicit instruction - the ENTIRE source photo, letterboxed to fit the
square canvas, never cropped down to isolate a single item (except the
one explicit exception below). Same approach as the other
apply_*_entire.py scripts, including ImageOps.exif_transpose() first.

11 new products (Aarti Plate, Brass Diya, Clay Diya, Diya (Oil Lamp), Dry
Fruits, Honey, Kalash, Lota, Paan, Puja Thali, Shankha (Conch)) were
created this session for photos with no prior product match. Bell_Ghanta,
Curd, Dates and Sugar matched existing products directly.

Dates.jpg is cropped (PRE_CROPS) to exclude a visible "Best before
Sept/2025" expiry sticker (already in the past) and marketing text -
not a subject-isolation crop, just removing a stale date stamp, per
explicit user choice.
"""

from pathlib import Path

from PIL import Image, ImageOps
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\pooja_items_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Aarti_Plate.jpg": "Aarti Plate",
    "Bell_Ghanta.jpg": "Pooja Bell",
    "Brass_Diya.jpg": "Brass Diya",
    "Clay_Diya.jpg": "Clay Diya",
    "Curd.jpg": "Curd (Yogurt)",
    "Dates.jpg": "Dates",
    "Diya_Oil_Lamp.jpg": "Diya (Oil Lamp)",
    "Dry_Fruits.jpg": "Dry Fruits",
    "Honey.jpg": "Honey",
    "Kalash.jpg": "Kalash",
    "Lota.jpg": "Lota",
    "Paan.jpg": "Paan",
    "Puja_Thali.jpg": "Puja Thali",
    "Shankha_Conch.jpg": "Shankha (Conch)",
    "Sugar.jpg": "Sugar",
}

# rel filename -> crop box, for the one source with a stale expiry-date
# sticker to exclude (not a subject-isolation crop).
PRE_CROPS: dict[str, tuple[int, int, int, int]] = {
    "Dates.jpg": (0, 0, 3350, 2600),
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
            if filename in PRE_CROPS:
                img = img.crop(PRE_CROPS[filename])
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
        print(f"\nUpdated {updated} pooja products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
