"""One-off: apply the big vegetables/ photo batch (9 subfolders, ~90 usable
photos) to their matching products - both existing ones (swapping in a
real photo for whatever they had) and the 43 new variety-level products
just created by add_new_vegetables.py.

Same pipeline as apply_vegetable_photos.py: ML background removal
(bg_remove.cutout_on_white, the u2net model run directly through
onnxruntime) then image_normalize.normalize() to crop/center/scale onto
the catalog's white-canvas convention. PRE_CROPS/SKIP_CUTOUT/
CUTOUT_THRESHOLDS hold per-source overrides discovered during visual QA -
see inline comments for why each one is there.

Where the same subject had more than one candidate photo across folders,
DUPLICATES_SKIPPED (bottom of file) lists which file lost out and why.
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

# subfolder/filename (relative to BASE_DIR) -> exact product name in the DB.
FILENAME_TO_PRODUCT: dict[str, str] = {
    # beans_legumes_images
    "beans_legumes_images/Broad_Beans_Avarakkai.jpg": "Broad Beans (Avarakkai)",
    "beans_legumes_images/Cluster_Beans_Guar.jpg": "Cluster Beans (Guar)",
    "beans_legumes_images/Cowpea_Alasandalu.jpg": "Cowpea (Lobia)",
    "beans_legumes_images/French_Beans.jpg": "French Beans",
    "beans_legumes_images/Green_Beans.jpg": "Beans",
    "beans_legumes_images/Hyacinth_Beans_Avarekai.jpg": "Hyacinth Beans (Avarekai)",
    "beans_legumes_images/Lima_Beans.jpg": "Lima Beans",
    "beans_legumes_images/Long_Beans_Yardlong_Beans.jpg": "Long Beans (Yardlong)",
    "beans_legumes_images/Mochai_Beans.jpg": "Mochai Beans",
    "beans_legumes_images/Runner_Beans.jpg": "Runner Beans",
    "beans_legumes_images/Soybean_Fresh.jpg": "Soybean (Fresh)",
    "beans_legumes_images/Winged_Beans.jpg": "Winged Beans",
    # brinjal_images
    "brinjal_images/Baby_Brinjal.jpg": "Baby Brinjal",
    "brinjal_images/Brinjal_Green.jpg": "Green Brinjal",
    "brinjal_images/Brinjal_Long_Purple.jpg": "Long Purple Brinjal",
    "brinjal_images/Brinjal_Purple.jpg": "Brinjal (Eggplant)",
    "brinjal_images/Brinjal_Round_Purple.jpg": "Round Purple Brinjal",
    "brinjal_images/Brinjal_Striped.jpg": "Striped Brinjal",
    "brinjal_images/Brinjal_White.jpg": "White Brinjal",
    "brinjal_images/Small_Brinjal.jpg": "Small Brinjal",
    # bulb_stem_vegetables_images
    "bulb_stem_vegetables_images/Asparagus.jpg": "Asparagus",
    "bulb_stem_vegetables_images/Bamboo_Shoot.jpg": "Bamboo Shoot",
    "bulb_stem_vegetables_images/Banana_Stem.jpg": "Banana Stem",
    "bulb_stem_vegetables_images/Celery.jpg": "Celery",
    "bulb_stem_vegetables_images/Fennel.jpg": "Fennel",
    "bulb_stem_vegetables_images/Garlic.jpg": "Garlic",
    "bulb_stem_vegetables_images/Leek.jpg": "Leek",
    "bulb_stem_vegetables_images/Shallots_Small_Onion.jpg": "Shallots (Small Onion)",
    # chillies_peppers_images
    "chillies_peppers_images/Banana_Pepper.jpg": "Banana Pepper",
    "chillies_peppers_images/Bell_Pepper_Green.jpg": "Capsicum",
    "chillies_peppers_images/Bell_Pepper_Orange.jpg": "Orange Bell Pepper",
    "chillies_peppers_images/Bell_Pepper_Red.jpg": "Red Bell Pepper",
    "chillies_peppers_images/Bell_Pepper_Yellow.jpg": "Yellow Bell Pepper",
    "chillies_peppers_images/Green_Chilli.jpg": "Green Chilli",
    "chillies_peppers_images/Guntur_Chilli_Fresh.jpg": "Guntur Chilli (Fresh)",
    "chillies_peppers_images/Jalapeno.jpeg": "Jalapeno",
    "chillies_peppers_images/Red_Chilli_Fresh.jpg": "Red Chilli (Fresh)",
    # gourds_squash_images
    "gourds_squash_images/Ash_Gourd_Winter_Melon.jpg": "Ash Gourd (Winter Melon)",
    "gourds_squash_images/Bitter_Gourd_Karela.jpg": "Bitter Gourd (Karela)",
    "gourds_squash_images/Bottle_Gourd_Lauki_Sorakaya.jpg": "Bottle Gourd",
    "gourds_squash_images/Chayote_Chow_Chow.jpg": "Chayote (Chow Chow)",
    "gourds_squash_images/Cucumber.jpg": "Cucumber",
    "gourds_squash_images/Ivy_Gourd_Dondakaya.jpg": "Ivy Gourd (Dondakaya)",
    "gourds_squash_images/Pumpkin.jpg": "Pumpkin",
    "gourds_squash_images/Ridge_Gourd_Beerakaya.jpg": "Ridge Gourd",
    "gourds_squash_images/Round_Gourd_Tinda.jpg": "Tinda",
    "gourds_squash_images/Snake_Gourd_Potlakaya.jpg": "Snake Gourd",
    "gourds_squash_images/Sponge_Gourd.jpg": "Sponge Gourd",
    "gourds_squash_images/Yellow_Squash.jpg": "Yellow Squash",
    # leafy_vegetable_images
    "leafy_vegetable_images/Amaranth_Leaves.jpg": "Amaranth Leaves",
    "leafy_vegetable_images/Arugula.jpg": "Arugula",
    "leafy_vegetable_images/Basella_Malabar_Spinach.jpg": "Malabar Spinach (Basella)",
    "leafy_vegetable_images/Coriander_Leaves.jpg": "Coriander Leaves",
    "leafy_vegetable_images/Curry_Leaves.jpg": "Curry Leaves",
    "leafy_vegetable_images/Dill_Soa.jpg": "Dill (Soa)",
    "leafy_vegetable_images/Drumstick_Moringa_Leaves.jpg": "Drumstick Leaves",
    "leafy_vegetable_images/Fenugreek_Methi.jpg": "Fenugreek Leaves (Methi)",
    "leafy_vegetable_images/Gongura_Sorrel.jpg": "Gongura",
    "leafy_vegetable_images/Kale.jpg": "Kale",
    "leafy_vegetable_images/Lettuce.jpg": "Lettuce",
    "leafy_vegetable_images/Mint_Leaves.jpg": "Mint Leaves",
    "leafy_vegetable_images/Mustard_Sarson.jpg": "Mustard Leaves",
    "leafy_vegetable_images/Radish_Leaves.jpg": "Radish Leaves",
    "leafy_vegetable_images/Red_Amaranth.jpg": "Red Amaranth",
    "leafy_vegetable_images/Spinach_Palak.jpg": "Spinach",
    "leafy_vegetable_images/Spring_Onion_Greens.jpg": "Spring Onion",
    "leafy_vegetable_images/Turnip_Greens.jpg": "Turnip Greens",
    # other_common_vegetables_images
    "other_common_vegetables_images/Baby_Corn.jpg": "Baby Corn",
    "other_common_vegetables_images/Banana_Flower.jpg": "Banana Flower",
    "other_common_vegetables_images/Corn_Sweet_Corn.jpg": "Sweet Corn",
    "other_common_vegetables_images/candidates/unripemango_2.jpg": "Green Mango",
    "other_common_vegetables_images/Mushroom.jpg": "Button Mushroom",
    "other_common_vegetables_images/Raw_Banana_Green_Banana.jpg": "Raw Banana",
    "other_common_vegetables_images/Raw_Jackfruit.jpg": "Raw Jackfruit",
    "other_common_vegetables_images/Raw_Papaya.jpg": "Raw Papaya",
    # other_vegetable_images
    "other_vegetable_images/Broccoli.jpg": "Broccoli",
    "other_vegetable_images/Cabbage.jpg": "Cabbage",
    "other_vegetable_images/Cauliflower.jpg": "Cauliflower",
    "other_vegetable_images/Okra_Ladys_Finger_Bhindi.JPG": "Ladies Finger (Okra)",
    "other_vegetable_images/Tomato.jpg": "Tomato",
    "other_vegetable_images/Zucchini.jpg": "Zucchini",
    # peas_pods_images
    "peas_pods_images/Drumstick_Moringa_Pods.jpg": "Drumstick",
    "peas_pods_images/Fresh_Chickpea_Green_Chana.jpg": "Green Chickpea (Chana)",
    "peas_pods_images/Fresh_Pigeon_Peas_Tuvar.jpg": "Fresh Pigeon Peas (Tuvar)",
    "peas_pods_images/Green_Peas.jpg": "Green Peas",
    "peas_pods_images/Snow_Peas.JPG": "Snow Peas",
    "peas_pods_images/Sugar_Snap_Peas.JPG": "Sugar Snap Peas",
}

# Files intentionally NOT used because a better duplicate exists elsewhere,
# or (Lotus_Stem/Onion/Garlic-adjacent) the product already has a good
# photo from the earlier vegetable_images/ batch:
#   bulb_stem_vegetables_images/Onion.jpg          (Onion already has a good photo)
#   bulb_stem_vegetables_images/Lotus_Stem.jpg     (Lotus Root (Stem) already has a good photo)
#   bulb_stem_vegetables_images/Spring_Onion.jpg   (using leafy_vegetable_images' instead)
#   other_common_vegetables_images/Bamboo_Shoot.JPG, Banana_Stem.jpg, Fennel_Bulb.jpg,
#     Lotus_Stem.jpg                                (duplicates of bulb_stem_vegetables_images)
#   other_vegetable_images/Bell_Pepper_Capsicum.jpg, Cucumber.jpg, Green_Beans.jpg,
#     Green_Peas.jpg                                (duplicates, using the other folder's copy)
#   other_common_vegetables_images/candidates/*      (all but unripemango_2.jpg - picked the best)

# Manual pre-crop boxes (left, top, right, bottom) in source-image pixel
# coordinates.
PRE_CROPS: dict[str, tuple[int, int, int, int]] = {}

# Per-source override for cutout_on_white's confidence threshold.
CUTOUT_THRESHOLDS: dict[str, int] = {}

# Sources where ML cutout should be skipped (already-white background, or
# the model is known to mishandle this one) - normalize() runs with
# auto_background=True instead.
SKIP_CUTOUT: set[str] = set()


def slugify(name: str) -> str:
    return "".join(c.lower() if c.isalnum() else "-" for c in name).strip("-")


def run() -> None:
    products_dir = Path(settings.static_dir) / "products"
    products_dir.mkdir(parents=True, exist_ok=True)

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

            if rel_path in SKIP_CUTOUT:
                final_img = normalize(img, product_name, auto_background=True)
            else:
                threshold = CUTOUT_THRESHOLDS.get(rel_path, 20)
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
        print(f"\nUpdated {updated} products.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
