"""Applies the beans_legumes_images/ (fresh bean pod varieties) photos "as
it is" per explicit instruction - the ENTIRE source photo, letterboxed to
fit the square canvas, never cropped down to isolate a single pod/bean.
Same approach as the other apply_*_entire.py scripts - this replaces the
ML-cutout/crop pipeline this folder originally went through earlier in the
project.

Lima_Beans.jpg here (fresh on-vine pods) intentionally overrides the
Lima Beans product's photo set last turn from a different folder (dried,
shelled beans) - the fresh-pod photo fits the "Vegetables" (fresh produce)
category better, per explicit user choice.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\beans_legumes_images")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    "Broad_Beans_Avarakkai.jpg": "Broad Beans (Avarakkai)",
    "Cluster_Beans_Guar.jpg": "Cluster Beans (Guar)",
    "Cowpea_Alasandalu.jpg": "Cowpea (Lobia)",
    "French_Beans.jpg": "French Beans",
    "Green_Beans.jpg": "Beans",
    "Hyacinth_Beans_Avarekai.jpg": "Hyacinth Beans (Avarekai)",
    "Lima_Beans.jpg": "Lima Beans",
    "Long_Beans_Yardlong_Beans.jpg": "Long Beans (Yardlong)",
    "Mochai_Beans.jpg": "Mochai Beans",
    "Runner_Beans.jpg": "Runner Beans",
    "Soybean_Fresh.jpg": "Soybean (Fresh)",
    "Winged_Beans.jpg": "Winged Beans",
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
        print(f"\nUpdated {updated} bean/legume products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
