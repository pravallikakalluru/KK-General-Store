"""Re-applies the Root Vegetables photos "as it is" per explicit
instruction - the ENTIRE source photo from vegetable_images/, letterboxed
to fit the square canvas, never cropped down to isolate a single
vegetable/piece. Replaces the earlier ML-cutout/crop pipeline for this
category entirely (see apply_vegetable_photos.py for that older
approach) - same reasoning as the rice photos: these sources are already
real, complete photographs, and cropping them was throwing away context
the user wants kept.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\vegetable_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Carrot.jpg": "Carrot",
    "Ginger.jpg": "Ginger",
    "Yam.jpg": "Purple Yam",
    "Potato.jpg": "Potato",
    "Radish.jpg": "Radish",
    "Turnip.jpg": "Turnip",
    "Purple_Yam_Kand.jpg": "Yam",
    "Beetroot.jpg": "Beetroot",
    "Sweet_Potato.jpg": "Sweet Potato",
    "Tapioca_Cassava.jpg": "Tapioca",
    "Colocasia_Arbi.jpg": "Colocasia (Arbi)",
    "Turmeric.jpg": "Turmeric (Fresh)",
    "Lotus_Root.jpg": "Lotus Root (Stem)",
    "Arrowroot.jpg": "Arrowroot",
    "Elephant_Foot_Yam_Suran.jpg": "Elephant Foot Yam (Suran)",
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
        print(f"\nUpdated {updated} root vegetable products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
