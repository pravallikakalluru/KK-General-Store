"""Applies the spices/ photo tree "as it is" per explicit instruction -
the ENTIRE source photo, letterboxed to fit the square canvas, never
cropped down to isolate a single item. Same approach as the other
apply_*_entire.py scripts.

Duplicates already applied from other folders this session (Garlic,
Ginger, Turmeric, Curry Leaves, Coriander Leaves, Mint) are skipped
entirely, confirmed byte-identical. Within the spices tree itself,
Bay_Leaf, Garam_Masala and Black_Cardamom/Cardamom_Black each appear
twice (byte-identical) - only one copy of each is used. Mace.jpg is a
byte-identical duplicate of Nutmeg.jpg (not a real Mace photo) - no Mace
product was created, this file is unused.

27 new products were created this session for photos with no prior
product match - see this session's product-creation step.

Dried_Mint.jpg is cropped (PRE_CROPS) to remove a "Papillon" branded
product visible in the top of the frame, per explicit user choice.
Curry_Powder.jpg (Gino brand) and Asafoetida.jpg (Whole Foods/Vandevi
brands) are used with their branding intact - an explicit exception to
this session's usual practice, per direct user instruction ("use them
anyway") after being shown exactly what was in frame.
"""

from pathlib import Path

from PIL import Image
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

BASE_DIR = Path(r"C:\Users\Bharath Sarvasetty\Documents\KK\vegetables\spices")
CANVAS = 500

FILENAME_TO_PRODUCT = {
    # herbs_spices_images
    "herbs_spices_images/Basil.jpg": "Basil",
    "herbs_spices_images/Bay_Leaf.jpg": "Bay Leaf (Tej Patta)",
    "herbs_spices_images/Dried_Curry_Leaves.jpg": "Dried Curry Leaves",
    "herbs_spices_images/Dried_Mint.jpg": "Dried Mint",
    "herbs_spices_images/Kasuri_Methi.jpg": "Kasuri Methi",
    "herbs_spices_images/Oregano.jpg": "Oregano",
    "herbs_spices_images/Rosemary.JPG": "Rosemary",
    "herbs_spices_images/Thyme.jpg": "Thyme",
    # masala_blends_images
    "masala_blends_images/Chaat_Masala.jpg": "Chaat Masala",
    "masala_blends_images/Curry_Powder.jpg": "Curry Powder",
    "masala_blends_images/Garam_Masala.jpg": "Garam Masala",
    "masala_blends_images/Rasam_Powder.jpg": "Rasam Powder",
    "masala_blends_images/Sambar_Powder.jpg": "Sambar Powder",
    # specialty_spices_images
    "specialty_spices_images/Amchur.jpg": "Amchur Powder",
    "specialty_spices_images/Anardana.jpg": "Anardana",
    "specialty_spices_images/Black_Cardamom.jpg": "Black Cardamom",
    "specialty_spices_images/Byadgi_Chilli.jpg": "Byadgi Chilli",
    "specialty_spices_images/Greater_Galangal.jpg": "Greater Galangal",
    "specialty_spices_images/Guntur_Chilli.jpg": "Guntur Chilli (Dry)",
    "specialty_spices_images/Kashmiri_Chilli.jpg": "Kashmiri Chilli",
    "specialty_spices_images/Kokum.jpg": "Kokum",
    "specialty_spices_images/Malabar_Tamarind.jpg": "Malabar Tamarind",
    # spices_seeds2_images
    "spices_seeds2_images/Allspice.jpg": "Allspice",
    "spices_seeds2_images/Aniseed.jpg": "Aniseed",
    "spices_seeds2_images/Caraway_Seeds.jpg": "Caraway Seeds",
    "spices_seeds2_images/Cardamom_Green.jpg": "Cardamom",
    "spices_seeds2_images/Celery_Seeds.jpg": "Celery Seeds",
    "spices_seeds2_images/Cinnamon.jpg": "Cinnamon",
    "spices_seeds2_images/Cloves.jpg": "Cloves",
    "spices_seeds2_images/Dill_Seeds.jpg": "Dill Seeds",
    "spices_seeds2_images/Long_Pepper.jpg": "Long Pepper",
    "spices_seeds2_images/Nutmeg.jpg": "Nutmeg (Jaiphal)",
    "spices_seeds2_images/Poppy_Seeds.jpg": "Poppy Seeds",
    "spices_seeds2_images/Saffron.jpg": "Saffron",
    "spices_seeds2_images/Star_Anise.jpg": "Star Anise",
    # spices_seeds_images
    "spices_seeds_images/Ajwain.jpg": "Ajwain",
    "spices_seeds_images/Asafoetida.jpg": "Asafoetida",
    "spices_seeds_images/Black_Pepper.jpg": "Black Pepper",
    "spices_seeds_images/Coriander_Powder.jpg": "Coriander Powder",
    "spices_seeds_images/Coriander_Seeds.jpg": "Coriander Seeds",
    "spices_seeds_images/Cumin_Powder.jpg": "Cumin Powder",
    "spices_seeds_images/Cumin_Seeds.jpg": "Cumin Seeds (Jeera)",
    "spices_seeds_images/Dry_Ginger.jpg": "Dry Ginger",
    "spices_seeds_images/Fennel_Seeds.jpg": "Fennel Seeds",
    "spices_seeds_images/Fenugreek_Seeds.jpg": "Fenugreek Seeds",
    "spices_seeds_images/Mustard_Seeds.png": "Mustard Seeds",
    "spices_seeds_images/Nigella.jpg": "Nigella",
    "spices_seeds_images/Red_Chilli.jpg": "Dry Red Chilli",
    "spices_seeds_images/Red_Chilli_Powder.jpg": "Red Chilli Powder",
    "spices_seeds_images/Tamarind.JPG": "Tamarind",
}

# rel path -> crop box, for the one source with a branded product visible
# to exclude (not a subject-isolation crop).
PRE_CROPS: dict[str, tuple[int, int, int, int]] = {
    "herbs_spices_images/Dried_Mint.jpg": (0, 380, 1200, 1600),
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
        for rel_path, product_name in FILENAME_TO_PRODUCT.items():
            src_path = BASE_DIR / rel_path
            if not src_path.exists():
                print(f"  WARNING: {rel_path} not found, skipping")
                continue

            product = db.scalar(select(Product).where(Product.name == product_name))
            if product is None:
                not_found.append(product_name)
                continue

            img = Image.open(src_path)
            if rel_path in PRE_CROPS:
                img = img.crop(PRE_CROPS[rel_path])
            final_img = entire_image_on_canvas(img)

            out_filename = f"{slugify(product_name)}-photo.png"
            new_url = f"/static/products/{out_filename}"

            if product.image_url != new_url:
                delete_product_image(product.image_url)

            final_img.save(products_dir / out_filename)
            product.image_url = new_url
            updated += 1
            print(f"  {product_name} <- {rel_path}")

        db.commit()
        print(f"\nUpdated {updated} spice products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
