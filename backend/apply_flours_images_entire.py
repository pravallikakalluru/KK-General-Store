"""Applies the flour/flours_images/ photos "as it is" per explicit
instruction - the ENTIRE source photo, letterboxed to fit the square
canvas, never cropped down to isolate a single scoop. Same approach as
the other apply_*_entire.py scripts.

Buckwheat_Kuttu_Flour.JPG, Sooji_Rava.jpg and Wheat_Atta.jpg here are
byte-identical duplicates of files already applied from
flour/flours_batch2_images/ earlier this session - skipped.

7 new products (Almond Flour, Barley Flour, Chakki Atta, Coconut Flour,
Millet Flour, Sattu, Soy Flour) were created this session for photos with
no prior match. Chakki_Atta.jpg is cropped (PRE_CROPS) to isolate just
the flour bowl, excluding a fully-branded "AASHIRVAAD" (ITC) packet
visible in the rest of the frame - a real competitor brand, per explicit
user choice to trim rather than skip or use as-is.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\flour\flours_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Almond_Flour.jpg": "Almond Flour",
    "Bajra_Flour.jpg": "Bajra Flour",
    "Barley_Flour.jpg": "Barley Flour",
    "Besan.jpg": "Besan",
    "Chakki_Atta.jpg": "Chakki Atta",
    "Coconut_Flour.jpg": "Coconut Flour",
    "Jowar_Flour.jpg": "Jowar Flour",
    "Maida.jpg": "Maida",
    "Millet_Flour.jpg": "Millet Flour",
    "Ragi_Flour.jpg": "Ragi Flour",
    "Rice_Flour.jpg": "Rice Flour",
    "Sattu.jpg": "Sattu",
    "Soy_Flour.jpg": "Soy Flour",
}

# rel filename -> crop box, for the one source with a competitor brand
# packet in frame to exclude (not a subject-isolation crop - the bowl
# itself is shown in full).
PRE_CROPS: dict[str, tuple[int, int, int, int]] = {
    "Chakki_Atta.jpg": (50, 900, 1300, 2600),
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
