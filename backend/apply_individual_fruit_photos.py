"""One-off: normalize the 36 individually-supplied fruit photos (already
much better composed than the auto-extracted grid crops - single item per
file, generous native whitespace) onto the same clean 500x500 white-canvas
format as the rest of the catalog, and set them as those products'
image_url, replacing the grid-extracted versions.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product
from image_normalize import normalize

settings = get_settings()

SOURCE_DIR = r"C:\Users\Bharath Sarvasetty\Downloads\individual_fruit_images_512x512"

# filename -> exact product name in the DB (only differs from the obvious
# "strip NN_ prefix, underscores to spaces" mapping for two products whose
# catalog name carries a parenthetical).
FILENAME_TO_PRODUCT = {
    "01_Apple.png": "Apple",
    "02_Apricot.png": "Apricot",
    "03_Avocado.png": "Avocado",
    "04_Banana.png": "Banana",
    "05_Ber.png": "Ber",
    "06_Cherry.png": "Cherry",
    "07_Coconut.png": "Coconut",
    "08_Custard_Apple.png": "Custard Apple",
    "09_Dragon_Fruit.png": "Dragon Fruit",
    "10_Grapefruit.png": "Grapefruit",
    "11_Grapes.png": "Grapes",
    "12_Guava.png": "Guava",
    "13_Jackfruit.png": "Jackfruit",
    "14_Jamun.png": "Jamun",
    "15_Kinnow.png": "Kinnow",
    "16_Kiwi.png": "Kiwi",
    "17_Lemon.png": "Lemon",
    "18_Litchi.png": "Litchi",
    "19_Mango.png": "Mango",
    "20_Mangosteen.png": "Mangosteen",
    "21_Muskmelon.png": "Muskmelon",
    "22_Orange.png": "Orange",
    "23_Papaya.png": "Papaya",
    "24_Passion_Fruit.png": "Passion Fruit",
    "25_Peach.png": "Peach",
    "26_Pear.png": "Pear",
    "27_Persimmon.png": "Persimmon",
    "28_Pineapple.png": "Pineapple",
    "29_Plum.png": "Plum",
    "30_Pomegranate.png": "Pomegranate",
    "31_Rambutan.png": "Rambutan",
    "32_Sapota.png": "Sapota (Chikoo)",
    "33_Soursop.png": "Soursop",
    "34_Strawberry.png": "Strawberry",
    "35_Sweet_Lime.png": "Sweet Lime (Mosambi)",
    "36_Watermelon.png": "Watermelon",
}


def slugify(name: str) -> str:
    return "".join(c.lower() if c.isalnum() else "-" for c in name).strip("-")


def run() -> None:
    source_dir = Path(SOURCE_DIR)
    if not source_dir.exists():
        raise SystemExit(f"Source folder not found: {SOURCE_DIR}")

    products_dir = Path(settings.static_dir) / "products"
    products_dir.mkdir(parents=True, exist_ok=True)

    db = SessionLocal()
    try:
        updated = 0
        not_found = []
        for filename, product_name in FILENAME_TO_PRODUCT.items():
            src_path = source_dir / filename
            if not src_path.exists():
                print(f"  WARNING: {filename} not found in source folder, skipping")
                continue

            product = db.scalar(select(Product).where(Product.name == product_name))
            if product is None:
                not_found.append(product_name)
                continue

            img = Image.open(src_path)
            final_img = normalize(img, product_name)

            out_filename = f"{slugify(product_name)}-photo.png"
            new_url = f"/static/products/{out_filename}"

            if product.image_url != new_url:
                delete_product_image(product.image_url)

            final_img.save(products_dir / out_filename)
            product.image_url = new_url
            updated += 1

        db.commit()
        print(f"\nUpdated {updated} products with individually-supplied photos.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
