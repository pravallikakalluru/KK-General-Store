"""One-off: add the "Purple Yam" product under Root Vegetables and set its
photo from vegetable_images/Yam.jpg, processed through the same ML
background-removal + normalize pipeline as the rest of the catalog.

Yam.jpg is objectively blurrier than every other source photo used so far
(edge-variance sharpness check: ~45 vs ~290 for Purple_Yam_Kand.jpg, the
photo already used for the plain "Yam" product) and doesn't show any
purple flesh - flagged to the user, who asked to use it anyway. Cropped
to the sharpest-looking, most complete single tuber in the pile to
minimize how much that shows.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.models import Category, Product
from image_normalize import normalize

settings = get_settings()

SOURCE_PATH = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetable_images\Yam.jpg")
PRODUCT_NAME = "Purple Yam"
PRODUCT_NAME_TE = "ఊదా చేమదుంప"


def slugify(name: str) -> str:
    return "".join(c.lower() if c.isalnum() else "-" for c in name).strip("-")


def run() -> None:
    products_dir = Path(settings.static_dir) / "products"
    products_dir.mkdir(parents=True, exist_ok=True)

    db = SessionLocal()
    try:
        existing = db.scalar(select(Product).where(Product.name == PRODUCT_NAME))
        if existing is not None:
            print(f"'{PRODUCT_NAME}' already exists (id={existing.id}), updating in place.")
            product = existing
        else:
            category = db.scalar(select(Category).where(Category.name == "Root Vegetables"))
            if category is None:
                raise SystemExit("Root Vegetables category not found")
            product = Product(
                store_id=category.store_id,
                category_id=category.id,
                name=PRODUCT_NAME,
                name_te=PRODUCT_NAME_TE,
                price=9.00,
                unit="100 g",
                is_available=True,
            )
            db.add(product)
            print(f"Creating new product '{PRODUCT_NAME}' under Root Vegetables.")

        img = Image.open(SOURCE_PATH)
        # The whole photo is uniformly out of focus (not something cropping
        # can fix) - and, unlike every other source used so far, uniformly
        # toned enough (no true background patch, similar tan color
        # throughout) that ML segmentation had nothing to key off: it
        # returned a near-empty sliver on a tight single-tuber crop, and a
        # heavily ghosted blob on a wider one. Skipping ML cutout entirely
        # and using the same "framed crop, no isolation" treatment that
        # worked for Potato/Onion's similarly backgroundless source photos
        # gives a complete, non-ghosted (if still soft-focus) result.
        cropped = img.crop((900, 100, 2900, 2100))
        final_img = normalize(cropped, PRODUCT_NAME)

        out_filename = f"{slugify(PRODUCT_NAME)}-photo.png"
        new_url = f"/static/products/{out_filename}"
        final_img.save(products_dir / out_filename)
        product.image_url = new_url

        db.commit()
        print(f"Done: {PRODUCT_NAME} -> {new_url}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
