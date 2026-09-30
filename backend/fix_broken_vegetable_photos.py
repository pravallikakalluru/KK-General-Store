"""Targeted re-processing for the ~20 products that came out broken
(near-blank/ghosted) from apply_new_vegetable_photos.py's first pass -
found via visual review of a contact-sheet of all 87 results.

Two failure patterns:
1. Full-bleed source (a pile/crate/field with no true background at all,
   or an on-vine shot too entangled with foliage for the model to find a
   clean subject) - fixed by skipping ML cutout entirely and using
   normalize()'s own bounding-box crop (auto_background=True), same
   fallback used for Potato/Onion in the first vegetable_images/ batch.
2. On-vine shot WITH one clearly isolable pod/fruit - fixed with a tight
   manual crop around just that one subject, still run through ML cutout
   (removing the surrounding foliage from frame entirely gives the model
   something it can actually segment).

Ash_Gourd_Winter_Melon.jpg is a third case: a 3-panel collage where the
model kept keying onto a small flower in one panel instead of the actual
gourd - cropped to isolate just the cut-gourd panel.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product
from bg_remove import cutout_on_white
from image_normalize import normalize

settings = get_settings()

BASE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables")

# rel_path -> product name, for items needing a manual crop then ML cutout.
CROP_THEN_CUTOUT: dict[str, tuple[str, tuple[int, int, int, int]]] = {
    "gourds_squash_images/Ash_Gourd_Winter_Melon.jpg": (
        "Ash Gourd (Winter Melon)",
        (960, 600, 1927, 1600),
    ),
    "gourds_squash_images/Bitter_Gourd_Karela.jpg": (
        "Bitter Gourd (Karela)",
        (1100, 650, 2000, 2200),
    ),
    "brinjal_images/Brinjal_White.jpg": ("White Brinjal", (2850, 1100, 3550, 2100)),
    "other_vegetable_images/Okra_Ladys_Finger_Bhindi.JPG": (
        "Ladies Finger (Okra)",
        (1650, 200, 2300, 2350),
    ),
    "peas_pods_images/Snow_Peas.JPG": ("Snow Peas", (1000, 1050, 1650, 2600)),
    "other_common_vegetables_images/Banana_Flower.jpg": (
        "Banana Flower",
        (500, 200, 1450, 2550),
    ),
}

# rel_path -> product name, for items falling back to normalize() alone
# (no ML cutout at all).
SKIP_CUTOUT_ITEMS: dict[str, str] = {
    "beans_legumes_images/Cowpea_Alasandalu.jpg": "Cowpea (Lobia)",
    "beans_legumes_images/French_Beans.jpg": "French Beans",
    "beans_legumes_images/Green_Beans.jpg": "Beans",
    "beans_legumes_images/Mochai_Beans.jpg": "Mochai Beans",
    "beans_legumes_images/Runner_Beans.jpg": "Runner Beans",
    "chillies_peppers_images/Banana_Pepper.jpg": "Banana Pepper",
    "chillies_peppers_images/Green_Chilli.jpg": "Green Chilli",
    "bulb_stem_vegetables_images/Bamboo_Shoot.jpg": "Bamboo Shoot",
    "leafy_vegetable_images/Basella_Malabar_Spinach.jpg": "Malabar Spinach (Basella)",
    "leafy_vegetable_images/Drumstick_Moringa_Leaves.jpg": "Drumstick Leaves",
    "leafy_vegetable_images/Red_Amaranth.jpg": "Red Amaranth",
    "leafy_vegetable_images/Kale.jpg": "Kale",
    "leafy_vegetable_images/Lettuce.jpg": "Lettuce",
    "peas_pods_images/Fresh_Chickpea_Green_Chana.jpg": "Green Chickpea (Chana)",
    "gourds_squash_images/Round_Gourd_Tinda.jpg": "Tinda",
    "leafy_vegetable_images/Mustard_Sarson.jpg": "Mustard Leaves",
}


def slugify(name: str) -> str:
    return "".join(c.lower() if c.isalnum() else "-" for c in name).strip("-")


def save_product(db, product_name: str, final_img: Image.Image, products_dir: Path) -> bool:
    product = db.scalar(select(Product).where(Product.name == product_name))
    if product is None:
        print(f"  WARNING: product '{product_name}' not found")
        return False
    out_filename = f"{slugify(product_name)}-photo.png"
    new_url = f"/static/products/{out_filename}"
    if product.image_url != new_url:
        delete_product_image(product.image_url)
    final_img.save(products_dir / out_filename)
    product.image_url = new_url
    return True


def run() -> None:
    products_dir = Path(settings.static_dir) / "products"
    db = SessionLocal()
    try:
        updated = 0

        for rel_path, (product_name, box) in CROP_THEN_CUTOUT.items():
            src = BASE_DIR / rel_path
            img = Image.open(src).crop(box)
            cutout = cutout_on_white(img)
            final_img = normalize(cutout, product_name)
            if save_product(db, product_name, final_img, products_dir):
                updated += 1

        for rel_path, product_name in SKIP_CUTOUT_ITEMS.items():
            src = BASE_DIR / rel_path
            img = Image.open(src)
            final_img = normalize(img, product_name, auto_background=True)
            if save_product(db, product_name, final_img, products_dir):
                updated += 1

        db.commit()
        print(f"\nRe-processed {updated} products.")
    finally:
        db.close()


if __name__ == "__main__":
    run()
