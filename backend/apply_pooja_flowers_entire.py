"""Applies the new pooja flower/leaf photos from pooja_items_images/ "as
it is" per explicit instruction - the ENTIRE source photo, letterboxed to
fit the square canvas, never cropped down to isolate a single leaf/flower
(except the two explicit exceptions below). Same approach as the other
apply_*_entire.py scripts, but with one important fix: applies
ImageOps.exif_transpose() before anything else - a few of these source
photos (Neem_Leaves.jpg, Flowers.jpg) carry EXIF rotation metadata that
Image.open() alone ignores, which silently saves the photo sideways.
Earlier apply_*_entire.py scripts this session didn't do this; a spot
check of their contact sheets shows no sideways photos, so this appears
isolated to a handful of files, not a widespread issue - but worth fixing
here and remembering for any future batch.

14 new products were created this session for photos with no prior
product match. Milk.jpg, Raisins.jpg, Betel_Nut_Areca_Nut.jpg and
Betel_Leaves.jpg here are byte-identical duplicates of files already
applied earlier this session - skipped. Turmeric.jpg, Rice.jpg,
Sacred_Thread_Kalawa.jpg, Sandalwood_Paste.jpg and Sindoor.jpg were
already addressed/skipped in earlier rounds on this same folder.

Two crops, both excluding a person rather than isolating a subject:
- Neem_Leaves.jpg: the source is a street scene (car, auto-rickshaw with
  people) with the neem tree filling the upper-left - cropped to just the
  leaves.
- Flowers.jpg: a man carries a basket of roses on his head down a street -
  cropped to just the flower-filled basket, excluding him entirely, per
  explicit user request ("crop only flower basket from image").
Sugarcane.jpg (a harvest scene with a person, cut sugarcane filling most
of the frame) is used as-is - confirmed with the user as the best
available option after checking its 4 alternate candidates, all of which
also show workers/machinery.
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
    "Banana_Leaves.jpg": "Banana Leaves",
    "Bilva_Bel_Leaves.jpg": "Bilva Leaves (Bel Patra)",
    "Coconut_Leaves.jpg": "Coconut Leaves",
    "Durva_Grass.jpg": "Durva Grass",
    "Flower_Garland.jpg": "Flower Garland",
    "Flowers.jpg": "Flowers (Mixed)",
    "Jasmine.jpg": "Jasmine",
    "Lotus.jpg": "Lotus",
    "Mango_Leaves.jpg": "Mango Leaves",
    "Marigold.jpg": "Marigold",
    "Neem_Leaves.jpg": "Neem Leaves",
    "Rose.jpg": "Rose",
    "Sugarcane.jpg": "Sugarcane",
    "Tulsi_Leaves.jpg": "Tulsi Leaves",
}

# rel filename -> crop box, for the two sources needing a person excluded
# (not a subject-isolation crop).
PRE_CROPS: dict[str, tuple[int, int, int, int]] = {
    "Neem_Leaves.jpg": (0, 0, 2400, 3200),
    "Flowers.jpg": (1870, 1600, 2850, 2220),
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
        print(f"\nUpdated {updated} pooja flower/leaf products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
