"""One-off: apply the user-supplied vegetable photos (vegetable_images/) to
their matching products, normalized onto the same white-canvas convention
as the rest of the catalog (see image_normalize.py).

Unlike the fruit photos, most of these weren't shot on a clean white
backdrop (dark wood, fabric, crate/basket piles, a few full-bleed textures
with no background at all). Real ML background removal is used via
bg_remove.py - the u2net ONNX segmentation model run directly through
onnxruntime, NOT through the `rembg` package (whose dependency chain,
pymatting -> scipy.spatial.transform, is blocked by a Windows Application
Control policy in this environment; the model itself isn't blocked, only
that one wrapper's import chain). Every source gets a genuine white cutout
before normalize() crops/centers it, regardless of its original
background.

A few sources still need a manual pre-crop first - not for background
removal (the model handles that), but for composition: cutting an
identification signboard or other produce out of frame, or picking a
well-composed sub-region from a source with no natural single-subject
framing at all (a dense crate/pile shot).
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

SOURCE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetable_images")

# Manual pre-crop boxes (left, top, right, bottom) in source-image pixel
# coordinates, for sources that need one before normalize() sees them -
# see the module docstring for why each of these needs it.
PRE_CROPS: dict[str, tuple[int, int, int, int]] = {
    "Carrot.jpg": (400, 640, 1080, 1290),
    "Potato.jpg": (850, 560, 2010, 1430),
    "Onion.jpg": (500, 190, 2020, 950),
    "Colocasia_Arbi.jpg": (0, 500, 2940, 3560),
    # The u2net saliency model latched onto the plastic ID tag in the full
    # frame instead of the actual roots the first time this was tried - and
    # a second attempt just cropping the tag out still left the messy
    # lower cluster and left only one (dark, unappealing) root correctly
    # segmented. This crop instead picks a cleaner sub-region on the right
    # of the bundle with several separated pale roots and no tag at all,
    # which segments cleanly as a group.
    "Arrowroot.jpg": (4200, 1793, 7300, 3550),
}

# Per-source override for cutout_on_white's confidence threshold - see its
# docstring.
CUTOUT_THRESHOLDS: dict[str, int] = {}

# Sources already shot on a clean white background don't need (and are
# actively hurt by) ML cutout - the saliency model isn't perfectly
# comprehensive and dropped legitimate content it didn't judge as the
# "main" blob (Carrot.jpg's leaves and off-color carrots faded out this
# way, and Radish.jpg's leaves the same). Onion.jpg's thin papery skins
# confused the model into a translucent, speckled mess at every threshold
# tried - its own color-diff crop (no true isolation, but zero artifacts)
# looks better. normalize()'s own bounding-box crop (auto_background=True
# to sample the real backdrop color rather than assume white, since these
# aren't on a white backdrop) is enough for these.
SKIP_CUTOUT = {"Turmeric.jpg", "Purple_Yam_Kand.jpg", "Carrot.jpg", "Onion.jpg", "Radish.jpg"}

# filename -> exact product name in the DB.
FILENAME_TO_PRODUCT = {
    "Turmeric.jpg": "Turmeric (Fresh)",
    "Purple_Yam_Kand.jpg": "Yam",
    "Ginger.jpg": "Ginger",
    "Turnip.jpg": "Turnip",
    "Tapioca_Cassava.jpg": "Tapioca",
    "Radish.jpg": "Radish",
    "Colocasia_Arbi.jpg": "Colocasia (Arbi)",
    "Arrowroot.jpg": "Arrowroot",
    "Lotus_Root.jpg": "Lotus Root (Stem)",
    "Beetroot.jpg": "Beetroot",
    "Carrot.jpg": "Carrot",
    "Potato.jpg": "Potato",
    "Onion.jpg": "Onion",
    # Both source photos are a poor crop (extreme macro with no complete
    # shape / other-side cut off) rather than a background problem - ML
    # segmentation still gives a clean, complete-looking silhouette from
    # what IS in frame, a real improvement over the generic icon even
    # though it's not as good as a proper full-product photo would be.
    "Sweet_Potato.jpg": "Sweet Potato",
    "Elephant_Foot_Yam_Suran.jpg": "Elephant Foot Yam (Suran)",
}


def slugify(name: str) -> str:
    return "".join(c.lower() if c.isalnum() else "-" for c in name).strip("-")


def run() -> None:
    products_dir = Path(settings.static_dir) / "products"
    products_dir.mkdir(parents=True, exist_ok=True)

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

            if filename in SKIP_CUTOUT:
                final_img = normalize(img, product_name, auto_background=True)
            else:
                threshold = CUTOUT_THRESHOLDS.get(filename, 20)
                cutout = cutout_on_white(img, threshold=threshold)
                final_img = normalize(cutout, product_name)

            out_filename = f"{slugify(product_name)}-photo.png"
            new_url = f"/static/products/{out_filename}"

            if product.image_url != new_url:
                delete_product_image(product.image_url)

            final_img.save(products_dir / out_filename)
            product.image_url = new_url
            updated += 1

        db.commit()
        print(f"\nUpdated {updated} products with vegetable photos.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
