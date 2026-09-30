"""One-off: apply the user-supplied rice photos (rice_images/) to their
matching products, "as it is" per explicit instruction - the ENTIRE source
photo, letterboxed to fit our square canvas, never cropped down to a
close-up of a single grain. No ML background removal either: these
sources are already good, clean photography (several already shot on a
plain background, others a deliberate macro/bowl/table composition) -
running them through cutout/crop would only throw away real content, the
exact mistake this instruction was written to prevent (see the Potato
lesson in apply_vegetable_photos.py's history).

Idli Rice and Dosa Rice have no usable source of their own (every idli-rice
candidate is a cooked-dish photo, one with an explicit no-reproduction
copyright notice, another showing branded retail packaging - see the
conversation this script came out of) - both fall back to Regular_Rice.jpg
as a generic raw white-rice stand-in, per explicit user decision.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\rice_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Basmati_Rice.jpg": "Basmati Rice",
    "Black_Rice.jpg": "Black Rice",
    "Boiled_Rice.jpg": "Boiled Rice",
    "Brown_Rice.jpg": "Brown Rice",
    "Ponni_Rice.jpg": "Ponni Rice",
    "Raw_Rice.jpg": "Raw Rice",
    "Red_Rice.JPG": "Red Rice",
    "Sona_Masuri.jpg": "Rice (Sona Masoori)",
    "Regular_Rice.jpg": "Regular Rice",
    "Traditional_Rice.jpg": "Traditional Rice",
    # Stand-ins - see module docstring.
    "Regular_Rice.jpg::idli": "Idli Rice",
    "Regular_Rice.jpg::dosa": "Dosa Rice",
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
        for key, product_name in FILENAME_TO_PRODUCT.items():
            filename = key.split("::")[0]
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
        print(f"\nUpdated {updated} rice products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
