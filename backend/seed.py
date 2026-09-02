"""Create/update the store, an owner login, and a broad bilingual
(English + Telugu) product catalog covering fruits, vegetables, pooja/temple
items, cleaning & household needs, grains & pulses, cooking essentials,
spices, instant foods, and dairy.

Fully idempotent — every store/category/product is get-or-created by name,
so re-running this after adding new items to CATALOG only inserts what's
missing (and refreshes price/unit/name_te on existing rows) rather than
duplicating anything.
"""

from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.models import Category, Product, Store, User, UserRole
from app.security import hash_password

settings = get_settings()

# category_name_en: (category_name_te, [(name_en, name_te, price, unit), ...])
CATALOG: dict[str, tuple[str, list[tuple[str, str, float, str]]]] = {
    "Fruits": (
        "పండ్లు",
        [
            ("Banana", "అరటిపండ్లు", 40, "dozen"),
            ("Apple", "ఆపిల్", 180, "kg"),
            ("Mango", "మామిడిపండ్లు", 90, "kg"),
            ("Orange", "నారింజ", 80, "kg"),
            ("Papaya", "బొప్పాయి", 40, "kg"),
            ("Watermelon", "పుచ్చకాయ", 25, "kg"),
            ("Grapes", "ద్రాక్ష", 90, "kg"),
            ("Pomegranate", "దానిమ్మ", 150, "kg"),
            ("Guava", "జామకాయ", 60, "kg"),
            ("Pineapple", "అనాస పండు", 50, "pc"),
            ("Sapota (Chikoo)", "సపోటా", 70, "kg"),
            ("Custard Apple", "సీతాఫలం", 100, "kg"),
        ],
    ),
    "Vegetables": (
        "కూరగాయలు",
        [
            ("Tomato", "టమాటా", 30, "kg"),
            ("Onion", "ఉల్లిపాయలు", 25, "kg"),
            ("Potato", "బంగాళదుంప", 28, "kg"),
            ("Brinjal (Eggplant)", "వంకాయ", 35, "kg"),
            ("Ladies Finger (Okra)", "బెండకాయ", 40, "kg"),
            ("Green Chilli", "పచ్చిమిర్చి", 40, "kg"),
            ("Carrot", "క్యారెట్", 45, "kg"),
            ("Cabbage", "క్యాబేజీ", 25, "kg"),
            ("Cauliflower", "కాలీఫ్లవర్", 35, "pc"),
            ("Beans", "బీన్స్", 50, "kg"),
            ("Bottle Gourd", "సొరకాయ", 30, "kg"),
            ("Ridge Gourd", "బీరకాయ", 35, "kg"),
            ("Drumstick", "మునగకాడలు", 60, "kg"),
            ("Coriander Leaves", "కొత్తిమీర", 10, "bunch"),
            ("Curry Leaves", "కరివేపాకు", 5, "bunch"),
            ("Ginger", "అల్లం", 90, "kg"),
            ("Garlic", "వెల్లుల్లి", 120, "kg"),
            ("Lemon", "నిమ్మకాయలు", 40, "kg"),
        ],
    ),
    "Temple & Pooja Needs": (
        "పూజా సామాగ్రి",
        [
            ("Agarbatti (Incense Sticks)", "అగరబత్తులు", 30, "pack"),
            ("Camphor", "కర్పూరం", 40, "pack"),
            ("Cotton Wicks (Lamp Thread)", "వత్తులు", 20, "pack"),
            ("Kumkum", "కుంకుమ", 15, "pack"),
            ("Turmeric Powder (Pooja)", "పసుపు", 25, "pack"),
            ("Sandalwood Powder", "గంధం పొడి", 50, "pack"),
            ("Coconut", "కొబ్బరికాయ", 30, "pc"),
            ("Betel Leaves", "తమలపాకులు", 20, "bunch"),
            ("Betel Nut", "వక్క", 40, "pack"),
            ("Pooja Lamp Oil", "దీపారాధన నూనె", 60, "bottle"),
            ("Cotton Garland Thread", "దండ దారం", 15, "pack"),
            ("Pooja Bell", "పూజా గంట", 100, "pc"),
        ],
    ),
    "Cleaning & Household": (
        "శుభ్రపరిచే సామాగ్రి",
        [
            ("Surf Excel Detergent Powder", "సర్ఫ్ ఎక్సెల్ డిటర్జెంట్ పొడి", 60, "pack"),
            ("Detergent Soap Bar", "డిటర్జెంట్ సబ్బు", 20, "pc"),
            ("Broomstick", "చీపురు", 50, "pc"),
            ("Floor Cleaner", "ఫ్లోర్ క్లీనర్", 90, "bottle"),
            ("Dishwash Bar", "పాత్రలు కడిగే సబ్బు", 15, "pc"),
            ("Dishwash Liquid", "పాత్రలు కడిగే లిక్విడ్", 80, "bottle"),
            ("Toilet Cleaner", "టాయిలెట్ క్లీనర్", 70, "bottle"),
            ("Phenyl", "ఫినాయిల్", 50, "bottle"),
            ("Mop", "మాప్", 120, "pc"),
            ("Naphthalene Balls", "నాఫ్తలీన్ బాల్స్", 25, "pack"),
            ("Scrub Pad", "స్క్రబ్ ప్యాడ్", 10, "pc"),
            ("Garbage Bags", "చెత్త సంచులు", 40, "pack"),
        ],
    ),
    "Grains & Pulses": (
        "ధాన్యాలు మరియు పప్పులు",
        [
            ("Rice (Sona Masoori)", "బియ్యం", 60, "kg"),
            ("Wheat Flour (Atta)", "గోధుమ పిండి", 45, "kg"),
            ("Toor Dal", "కంది పప్పు", 140, "kg"),
            ("Moong Dal", "పెసర పప్పు", 120, "kg"),
            ("Chana Dal", "సెనగ పప్పు", 90, "kg"),
            ("Urad Dal", "మినప్పప్పు", 130, "kg"),
            ("Rajma (Kidney Beans)", "రాజ్మా", 110, "kg"),
            ("Chickpeas (Kabuli Chana)", "సెనగలు", 100, "kg"),
            ("Basmati Rice", "బాస్మతి బియ్యం", 120, "kg"),
            ("Sooji (Rava)", "రవ్వ", 50, "kg"),
            ("Poha (Atukulu)", "అటుకులు", 45, "kg"),
            ("Green Gram Whole", "పెసలు", 100, "kg"),
        ],
    ),
    "Cooking Essentials": (
        "వంట సరుకులు",
        [
            ("Sunflower Oil", "సన్‌ఫ్లవర్ నూనె", 150, "litre"),
            ("Groundnut Oil", "వేరుశనగ నూనె", 180, "litre"),
            ("Ghee", "నెయ్యి", 550, "kg"),
            ("Salt", "ఉప్పు", 20, "kg"),
            ("Sugar", "చక్కెర", 45, "kg"),
            ("Jaggery", "బెల్లం", 60, "kg"),
            ("Tamarind", "చింతపండు", 90, "kg"),
            ("Vinegar", "వెనిగర్", 40, "bottle"),
            ("Baking Soda", "బేకింగ్ సోడా", 20, "pack"),
            ("Coconut Oil", "కొబ్బరి నూనె", 200, "litre"),
        ],
    ),
    "Spices": (
        "మసాలా దినుసులు",
        [
            ("Turmeric Powder", "పసుపు పొడి", 40, "pack"),
            ("Red Chilli Powder", "కారం పొడి", 60, "pack"),
            ("Coriander Powder", "ధనియాల పొడి", 45, "pack"),
            ("Cumin Seeds (Jeera)", "జీలకర్ర", 80, "pack"),
            ("Mustard Seeds", "ఆవాలు", 30, "pack"),
            ("Garam Masala", "గరం మసాలా", 70, "pack"),
            ("Black Pepper", "మిరియాలు", 100, "pack"),
            ("Cardamom", "ఏలకులు", 200, "pack"),
            ("Cloves", "లవంగాలు", 90, "pack"),
            ("Cinnamon", "దాల్చిన చెక్క", 60, "pack"),
            ("Fenugreek Seeds", "మెంతులు", 30, "pack"),
            ("Fennel Seeds", "సోంపు", 40, "pack"),
            ("Sambar Powder", "సాంబార్ పొడి", 55, "pack"),
            ("Rasam Powder", "రసం పొడి", 55, "pack"),
        ],
    ),
    "Instant Foods & Snacks": (
        "ఇన్‌స్టంట్ ఫుడ్స్ & స్నాక్స్",
        [
            ("Maggi Noodles", "మాగీ నూడుల్స్", 14, "pack"),
            ("Yippee Noodles", "యిప్పీ నూడుల్స్", 15, "pack"),
            ("Potato Chips", "పొటాటో చిప్స్", 20, "pack"),
            ("Biscuits", "బిస్కెట్లు", 10, "pack"),
            ("Namkeen Mixture", "మిక్చర్", 30, "pack"),
            ("Bread", "బ్రెడ్", 40, "pack"),
            ("Tomato Ketchup", "కెచప్", 90, "bottle"),
            ("Cornflakes", "కార్న్‌ఫ్లేక్స్", 150, "pack"),
            ("Cup Noodles", "కప్ నూడుల్స్", 45, "pc"),
            ("Rusk", "రస్క్", 35, "pack"),
        ],
    ),
    "Dairy & Eggs": (
        "పాల ఉత్పత్తులు & గుడ్లు",
        [
            ("Milk", "పాలు", 28, "litre"),
            ("Eggs", "గుడ్లు", 60, "dozen"),
            ("Curd (Yogurt)", "పెరుగు", 30, "pack"),
            ("Paneer", "పన్నీర్", 90, "pack"),
            ("Butter", "వెన్న", 50, "pack"),
            ("Cheese Slices", "చీజ్ స్లైసెస్", 110, "pack"),
        ],
    ),
}


def _get_or_create_store(db) -> Store:
    store = db.scalar(select(Store).where(Store.code == settings.seed_store_code))
    if store is None:
        store = Store(
            name=settings.seed_store_name,
            code=settings.seed_store_code,
            whatsapp_number=settings.seed_store_whatsapp_number,
        )
        db.add(store)
        db.flush()
        print(f"Created store '{store.name}' ({store.code})")
    elif store.name != settings.seed_store_name:
        print(f"Renaming store '{store.name}' -> '{settings.seed_store_name}'")
        store.name = settings.seed_store_name
    else:
        print(f"Store '{store.name}' already up to date")
    return store


def _get_or_create_owner(db, store: Store) -> None:
    owner = db.scalar(select(User).where(User.phone == settings.seed_owner_phone))
    if owner is None:
        owner = User(
            store_id=store.id,
            name="Store Owner",
            phone=settings.seed_owner_phone,
            password_hash=hash_password(settings.seed_owner_password),
            role=UserRole.OWNER,
        )
        db.add(owner)
        print(f"Created owner login: phone={settings.seed_owner_phone} password={settings.seed_owner_password}")
    else:
        print("Owner account already exists, skipping")


def _sync_catalog(db, store: Store) -> None:
    created_categories = 0
    created_products = 0
    updated_products = 0

    for sort_order, (cat_name_en, (cat_name_te, products)) in enumerate(CATALOG.items()):
        category = db.scalar(
            select(Category).where(Category.store_id == store.id, Category.name == cat_name_en)
        )
        if category is None:
            category = Category(store_id=store.id, name=cat_name_en, sort_order=sort_order)
            db.add(category)
            db.flush()
            created_categories += 1
        else:
            category.sort_order = sort_order

        for name_en, name_te, price, unit in products:
            product = db.scalar(
                select(Product).where(Product.store_id == store.id, Product.name == name_en)
            )
            if product is None:
                db.add(
                    Product(
                        store_id=store.id,
                        category_id=category.id,
                        name=name_en,
                        name_te=name_te,
                        price=price,
                        unit=unit,
                        is_available=True,
                    )
                )
                created_products += 1
            else:
                product.category_id = category.id
                product.name_te = name_te
                product.price = price
                product.unit = unit
                updated_products += 1

    print(
        f"Categories: {created_categories} created, "
        f"{len(CATALOG) - created_categories} already existed"
    )
    print(f"Products: {created_products} created, {updated_products} updated")


def run() -> None:
    db = SessionLocal()
    try:
        store = _get_or_create_store(db)
        db.flush()
        _get_or_create_owner(db, store)
        db.flush()
        _sync_catalog(db, store)
        db.commit()
        print("Seed complete.")
    finally:
        db.close()


if __name__ == "__main__":
    run()
