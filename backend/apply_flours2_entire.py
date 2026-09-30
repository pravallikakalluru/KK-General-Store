"""Applies the flours_batch2_images/ photos "as it is" per explicit
instruction - the ENTIRE source photo, letterboxed to fit the square
canvas, never cropped down to isolate a single scoop of flour. Same
approach as the other apply_*_entire.py scripts.

Singhara_Flour.jpg is left out entirely - it's actually a retail shelf
photo of a competitor's branded packaging (Hong Kong pricing, barcodes,
a photo timestamp), not usable under any interpretation, confirmed with
the user. Oats_Flour.jpg (oat flour/powder, not whole oats) replaces the
"Oats" product's generic icon placeholder - a real photo, even if
technically the flour form, per explicit user choice. Sooji_Rava.jpg had
a small "5cm" scale-reference graphic in the corner, trimmed off via
PRE_CROPS (a small edge trim, not a subject-isolation crop).
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\flours_batch2_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Buckwheat_Kuttu_Flour.jpg": "Buckwheat (Kuttu)",
    "Corn_Maize_Flour.jpg": "Corn Flour",
    "Oats_Flour.jpg": "Oats",
    "Sooji_Rava.jpg": "Sooji (Rava)",
}

# rel filename -> crop box, for the one source with a small scale-reference
# graphic to trim off (not a subject-isolation crop).
PRE_CROPS: dict[str, tuple[int, int, int, int]] = {
    "Sooji_Rava.jpg": (0, 0, 1024, 590),
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
        print(f"\nUpdated {updated} flour products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
