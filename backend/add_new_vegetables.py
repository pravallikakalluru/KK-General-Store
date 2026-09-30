"""One-off: create the new vegetable/legume/chilli/etc. products that don't
exist yet in the DB, so the big vegetables/ photo batch (see
apply_new_vegetable_photos.py) has somewhere to attach each variety-level
photo. See PRODUCTS below for name/category/price/unit per item.

Telugu names are filled in only where a confident, commonly-used regional
term is known - left null otherwise (the app already falls back to
English-only display for that, an existing, established pattern).
"""

from sqlalchemy import select

from app.database import SessionLocal
from app.models import Category, Product

# (name, name_te, category_name, price, unit)
PRODUCTS = [
    # Beans & legumes
    ("French Beans", None, "Vegetables", 8.00, "100 g"),
    ("Hyacinth Beans (Avarekai)", "అవరెకాయ", "Vegetables", 6.00, "100 g"),
    ("Lima Beans", None, "Vegetables", 9.00, "100 g"),
    ("Long Beans (Yardlong)", "బొబ్బర్లు కాయ", "Vegetables", 7.00, "100 g"),
    ("Mochai Beans", None, "Vegetables", 7.00, "100 g"),
    ("Runner Beans", None, "Vegetables", 8.00, "100 g"),
    ("Soybean (Fresh)", None, "Vegetables", 8.00, "100 g"),
    ("Winged Beans", None, "Vegetables", 9.00, "100 g"),
    # Brinjal varieties
    ("Baby Brinjal", "చిన్న వంకాయ", "Vegetables", 6.00, "100 g"),
    ("Green Brinjal", "ఆకుపచ్చ వంకాయ", "Vegetables", 6.00, "100 g"),
    ("Long Purple Brinjal", "పొడవాటి వంకాయ", "Vegetables", 6.00, "100 g"),
    ("Round Purple Brinjal", "గుండ్రటి వంకాయ", "Vegetables", 6.00, "100 g"),
    ("Striped Brinjal", None, "Vegetables", 6.00, "100 g"),
    ("White Brinjal", "తెల్ల వంకాయ", "Vegetables", 6.00, "100 g"),
    ("Small Brinjal", "చిన్న వంకాయ", "Vegetables", 6.00, "100 g"),
    # Bulb & stem
    ("Asparagus", None, "Vegetables", 25.00, "100 g"),
    ("Bamboo Shoot", None, "Vegetables", 12.00, "100 g"),
    ("Banana Stem", "అరటి దూట", "Vegetables", 6.00, "100 g"),
    ("Fennel", "సోంపు కాడ", "Vegetables", 10.00, "100 g"),
    ("Leek", None, "Vegetables", 12.00, "100 g"),
    ("Shallots (Small Onion)", "చిన్న ఉల్లిపాయ", "Vegetables", 8.00, "100 g"),
    # Chillies & peppers
    ("Banana Pepper", None, "Vegetables", 10.00, "100 g"),
    ("Orange Bell Pepper", "నారింజ క్యాప్సికం", "Vegetables", 14.00, "100 g"),
    ("Red Bell Pepper", "ఎర్ర క్యాప్సికం", "Vegetables", 14.00, "100 g"),
    ("Yellow Bell Pepper", "పసుపు క్యాప్సికం", "Vegetables", 14.00, "100 g"),
    ("Guntur Chilli (Fresh)", "గుంటూరు మిర్చి", "Vegetables", 6.00, "100 g"),
    ("Jalapeno", None, "Vegetables", 12.00, "100 g"),
    ("Red Chilli (Fresh)", "ఎర్ర మిర్చి", "Vegetables", 6.00, "100 g"),
    # Gourds & squash
    ("Chayote (Chow Chow)", "చౌ చౌ", "Gourds", 6.00, "100 g"),
    ("Yellow Squash", None, "Gourds", 10.00, "100 g"),
    # Leafy vegetables
    ("Arugula", None, "Leafy Vegetables", 12.00, "50 g"),
    ("Malabar Spinach (Basella)", "బచ్చలికూర", "Leafy Vegetables", 5.00, "50 g"),
    ("Dill (Soa)", "సోవా ఆకు", "Leafy Vegetables", 4.00, "50 g"),
    ("Kale", None, "Leafy Vegetables", 10.00, "50 g"),
    ("Radish Leaves", "ముల్లంగి ఆకు", "Leafy Vegetables", 4.00, "50 g"),
    ("Turnip Greens", None, "Leafy Vegetables", 4.00, "50 g"),
    # Other common vegetables
    ("Banana Flower", "అరటి పువ్వు", "Vegetables", 8.00, "100 g"),
    ("Green Mango", "పచ్చి మామిడి", "Vegetables", 6.00, "100 g"),
    ("Zucchini", None, "Vegetables", 12.00, "100 g"),
    # Peas & pods
    ("Green Chickpea (Chana)", "పచ్చి శనగలు", "Vegetables", 8.00, "100 g"),
    ("Fresh Pigeon Peas (Tuvar)", "కంది కాయలు", "Vegetables", 8.00, "100 g"),
    ("Snow Peas", None, "Vegetables", 14.00, "100 g"),
    ("Sugar Snap Peas", None, "Vegetables", 14.00, "100 g"),
]


def run() -> None:
    db = SessionLocal()
    try:
        created = 0
        skipped = 0
        for name, name_te, category_name, price, unit in PRODUCTS:
            existing = db.scalar(select(Product).where(Product.name == name))
            if existing is not None:
                skipped += 1
                continue
            category = db.scalar(select(Category).where(Category.name == category_name))
            if category is None:
                print(f"  WARNING: category '{category_name}' not found for '{name}'")
                continue
            db.add(
                Product(
                    store_id=category.store_id,
                    category_id=category.id,
                    name=name,
                    name_te=name_te,
                    price=price,
                    unit=unit,
                    is_available=True,
                )
            )
            created += 1
        db.commit()
        print(f"Created {created} new products, {skipped} already existed.")
    finally:
        db.close()


if __name__ == "__main__":
    run()
