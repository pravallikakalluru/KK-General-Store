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
#
# Fruits, Vegetables, Root Vegetables, Gourds, Leafy Vegetables, Mushrooms,
# and Coconut are sold in small fixed packs rather than by the kilogram —
# the "unit" for every product in these categories is the pack size itself
# (e.g. "100 g", "50 g", "1 piece"), not a measurement type like "kg"/"pack".
# This is what the app shows as the product's quantity/weight everywhere
# (card, detail, cart, order, WhatsApp message, receipt) — see
# docs/API_CONTRACT.md and
# mobile/lib/screens/owner/product_form_screen.dart's category->default-unit
# suggestion, which mirrors this same mapping for new products.
CATALOG: dict[str, tuple[str, list[tuple[str, str, float, str]]]] = {
    "Fruits": (
        "పండ్లు",
        [
            ("Banana", "అరటిపండ్లు", 4, "100 g"),
            ("Apple", "ఆపిల్", 18, "100 g"),
            ("Mango", "మామిడిపండ్లు", 12, "100 g"),
            ("Orange", "నారింజ", 10, "100 g"),
            ("Sweet Lime (Mosambi)", "బత్తాయి", 6, "100 g"),
            ("Lemon", "నిమ్మకాయలు", 7, "100 g"),
            ("Grapes", "ద్రాక్ష", 12, "100 g"),
            ("Pomegranate", "దానిమ్మ", 20, "100 g"),
            ("Guava", "జామకాయ", 8, "100 g"),
            ("Papaya", "బొప్పాయి", 6, "100 g"),
            ("Pineapple", "అనాస పండు", 6, "100 g"),
            ("Watermelon", "పుచ్చకాయ", 4, "100 g"),
            ("Muskmelon", "ఖర్బూజా", 5, "100 g"),
            ("Sapota (Chikoo)", "సపోటా", 9, "100 g"),
            ("Custard Apple", "సీతాఫలం", 13, "100 g"),
            ("Jackfruit", "పనసపండు", 8, "100 g"),
            ("Strawberry", "స్ట్రాబెర్రీ", 25, "100 g"),
            ("Kiwi", "కివి పండు", 20, "100 g"),
            ("Dragon Fruit", "డ్రాగన్ ఫ్రూట్", 30, "100 g"),
            ("Avocado", "అవకాడో", 25, "100 g"),
            ("Pear", "బేరిపండు", 15, "100 g"),
            ("Peach", "పీచ్ పండు", 18, "100 g"),
            ("Plum", "ప్లం పండు", 18, "100 g"),
            ("Apricot", "యాప్రికాట్", 20, "100 g"),
            ("Litchi", "లిచీ పండు", 22, "100 g"),
            ("Cherry", "చెర్రీ పండు", 35, "100 g"),
            ("Jamun", "నేరేడు పండు", 12, "100 g"),
            ("Ber", "రేగిపండు", 6, "100 g"),
            ("Amla", "ఉసిరికాయ", 6, "100 g"),
            ("Passion Fruit", "పాషన్ ఫ్రూట్", 15, "100 g"),
            ("Rambutan", "రాంబుటాన్", 25, "100 g"),
            ("Mangosteen", "మాంగోస్టీన్", 28, "100 g"),
            ("Grapefruit", "గ్రేప్‌ఫ్రూట్", 12, "100 g"),
            ("Soursop", "సోర్‌సాప్", 20, "100 g"),
            ("Persimmon", "పర్సిమన్", 18, "100 g"),
            ("Kinnow", "కిన్నో నారింజ", 8, "100 g"),
        ],
    ),
    "Vegetables": (
        "కూరగాయలు",
        [
            ("Tomato", "టమాటా", 5, "100 g"),
            ("Onion", "ఉల్లిపాయలు", 4, "100 g"),
            ("Brinjal (Eggplant)", "వంకాయ", 6, "100 g"),
            ("Cabbage", "క్యాబేజీ", 4, "100 g"),
            ("Cauliflower", "కాలీఫ్లవర్", 6, "100 g"),
            ("Broccoli", "బ్రోకలీ", 15, "100 g"),
            ("Capsicum", "క్యాప్సికం", 8, "100 g"),
            ("Green Chilli", "పచ్చిమిర్చి", 7, "100 g"),
            ("Green Peas", "బఠానీలు", 8, "100 g"),
            ("Sweet Corn", "స్వీట్ కార్న్", 8, "100 g"),
            ("Baby Corn", "బేబీ కార్న్", 10, "100 g"),
            ("Ladies Finger (Okra)", "బెండకాయ", 7, "100 g"),
            ("Beans", "బీన్స్", 8, "100 g"),
            ("Cluster Beans (Guar)", "గోరుచిక్కుడు", 8, "100 g"),
            ("Broad Beans (Avarakkai)", "చిక్కుడుకాయ", 7, "100 g"),
            ("Cowpea (Lobia)", "అలసందలు", 7, "100 g"),
            ("Cucumber", "దోసకాయ", 4, "100 g"),
            ("Gherkin", "చిన్న దోసకాయ", 6, "100 g"),
            ("Garlic", "వెల్లుల్లి", 20, "100 g"),
            ("Drumstick", "మునగకాడలు", 10, "100 g"),
            ("Raw Banana", "అరటికాయ", 5, "100 g"),
            ("Raw Papaya", "బొప్పాయికాయ", 5, "100 g"),
            ("Raw Jackfruit", "పనసకాయ", 6, "100 g"),
        ],
    ),
    "Root Vegetables": (
        "దుంప కూరగాయలు",
        [
            ("Potato", "బంగాళదుంప", 5, "100 g"),
            ("Sweet Potato", "చిలగడదుంప", 6, "100 g"),
            ("Carrot", "క్యారెట్", 7, "100 g"),
            ("Beetroot", "బీట్‌రూట్", 6, "100 g"),
            ("Radish", "ముల్లంగి", 4, "100 g"),
            ("Turnip", "టర్నిప్", 6, "100 g"),
            ("Yam", "చేమదుంప", 7, "100 g"),
            ("Elephant Foot Yam (Suran)", "కంద దుంప", 8, "100 g"),
            ("Tapioca", "కర్రపెండలం", 5, "100 g"),
            ("Colocasia (Arbi)", "చామదుంప", 6, "100 g"),
            ("Ginger", "అల్లం", 15, "100 g"),
            ("Turmeric (Fresh)", "పచ్చి పసుపు", 12, "100 g"),
            ("Lotus Root (Stem)", "తామర దుంప", 15, "100 g"),
            ("Arrowroot", "అరారూట్", 10, "100 g"),
        ],
    ),
    "Gourds": (
        "బీర జాతి కూరగాయలు",
        [
            ("Bottle Gourd", "సొరకాయ", 5, "100 g"),
            ("Bitter Gourd (Karela)", "కాకరకాయ", 7, "100 g"),
            ("Ridge Gourd", "బీరకాయ", 6, "100 g"),
            ("Sponge Gourd", "స్పాంజ్ బీరకాయ", 6, "100 g"),
            ("Snake Gourd", "పొట్లకాయ", 6, "100 g"),
            ("Ash Gourd (Winter Melon)", "బూడిద గుమ్మడికాయ", 5, "100 g"),
            ("Pointed Gourd (Parwal)", "పర్వల్ కాయ", 9, "100 g"),
            ("Ivy Gourd (Dondakaya)", "దొండకాయ", 6, "100 g"),
            ("Tinda", "టిండా కాయ", 7, "100 g"),
            ("Pumpkin", "గుమ్మడికాయ", 5, "100 g"),
        ],
    ),
    "Leafy Vegetables": (
        "ఆకు కూరగాయలు",
        [
            ("Spinach", "పాలకూర", 12, "50 g"),
            ("Coriander Leaves", "కొత్తిమీర", 10, "50 g"),
            ("Mint Leaves", "పుదీనా", 10, "50 g"),
            ("Curry Leaves", "కరివేపాకు", 8, "50 g"),
            ("Amaranth Leaves", "తోటకూర", 12, "50 g"),
            ("Fenugreek Leaves (Methi)", "మెంతికూర", 10, "50 g"),
            ("Red Amaranth", "ఎర్ర తోటకూర", 12, "50 g"),
            ("Mustard Leaves", "ఆవాకూర", 10, "50 g"),
            ("Drumstick Leaves", "మునగాకు", 10, "50 g"),
            ("Gongura", "గోంగూర", 12, "50 g"),
            ("Spring Onion", "స్ప్రింగ్ ఆనియన్", 10, "50 g"),
            ("Lettuce", "లెట్యూస్", 15, "50 g"),
            ("Celery", "సెలెరీ", 15, "50 g"),
        ],
    ),
    "Mushrooms": (
        "పుట్టగొడుగులు",
        [
            ("Button Mushroom", "బటన్ పుట్టగొడుగులు", 12, "100 g"),
            ("Oyster Mushroom", "ఆయిస్టర్ పుట్టగొడుగులు", 14, "100 g"),
            ("Shiitake Mushroom", "షియటాకె పుట్టగొడుగులు", 25, "100 g"),
            ("Milky Mushroom", "మిల్కీ పుట్టగొడుగులు", 15, "100 g"),
        ],
    ),
    "Coconut": (
        "కొబ్బరికాయలు",
        [
            ("Coconut", "కొబ్బరికాయ", 30, "1 piece"),
        ],
    ),
    "Rice": (
        "బియ్యం",
        [
            ("Rice (Sona Masoori)", "సోనా మసూరి బియ్యం", 60, "kg"),
            ("Basmati Rice", "బాస్మతి బియ్యం", 120, "kg"),
            ("Raw Rice", "పచ్చి బియ్యం", 55, "kg"),
            ("Boiled Rice", "ఉప్పుడు బియ్యం", 55, "kg"),
            ("Idli Rice", "ఇడ్లీ బియ్యం", 55, "kg"),
            ("Dosa Rice", "దోశ బియ్యం", 55, "kg"),
            ("Ponni Rice", "పొన్ని బియ్యం", 65, "kg"),
            ("Brown Rice", "గోధుమ రంగు బియ్యం", 90, "kg"),
            ("Black Rice", "నల్ల బియ్యం", 150, "kg"),
            ("Red Rice", "ఎర్ర బియ్యం", 80, "kg"),
            ("Poha (Atukulu)", "అటుకులు", 45, "kg"),
        ],
    ),
    "Grains & Millets": (
        "ధాన్యాలు మరియు చిరుధాన్యాలు",
        [
            ("Wheat", "గోధుమలు", 40, "kg"),
            ("Barley", "బార్లీ", 60, "kg"),
            ("Maize (Corn)", "మొక్కజొన్న", 45, "kg"),
            ("Oats", "ఓట్స్", 90, "kg"),
            ("Ragi (Finger Millet)", "రాగులు", 65, "kg"),
            ("Jowar (Sorghum)", "జొన్నలు", 55, "kg"),
            ("Bajra (Pearl Millet)", "సజ్జలు", 50, "kg"),
            ("Foxtail Millet", "కొర్రలు", 90, "kg"),
            ("Little Millet", "సామలు", 90, "kg"),
            ("Kodo Millet", "అరికెలు", 90, "kg"),
            ("Amaranth Grain (Rajgira)", "రాజ్‌గిరా", 120, "kg"),
            ("Buckwheat (Kuttu)", "కుట్టు", 130, "kg"),
            ("Quinoa", "క్వినోవా", 350, "kg"),
        ],
    ),
    "Dals & Pulses": (
        "పప్పులు",
        [
            ("Toor Dal", "కంది పప్పు", 140, "kg"),
            ("Moong Dal", "పెసర పప్పు", 120, "kg"),
            ("Chana Dal", "సెనగ పప్పు", 90, "kg"),
            ("Urad Dal", "మినప్పప్పు", 130, "kg"),
            ("Masoor Dal", "మసూర్ పప్పు", 100, "kg"),
            ("Rajma (Kidney Beans)", "రాజ్మా", 110, "kg"),
            ("Chickpeas (Kabuli Chana)", "సెనగలు", 100, "kg"),
            ("Kala Chana", "నల్ల సెనగలు", 90, "kg"),
            ("Green Gram Whole", "పెసలు", 100, "kg"),
            ("Lobia", "అలసంద పప్పు", 90, "kg"),
            ("Moth Dal", "మోత్ పప్పు", 100, "kg"),
            ("Horse Gram (Ulavalu)", "ఉలవలు", 90, "kg"),
            ("Dried Peas", "ఎండు బఠానీలు", 70, "kg"),
            ("Soybean", "సోయాబీన్", 90, "kg"),
        ],
    ),
    "Flours": (
        "పిండి పదార్థాలు",
        [
            ("Wheat Flour (Atta)", "గోధుమ పిండి", 45, "kg"),
            ("Multigrain Atta", "మల్టీగ్రెయిన్ పిండి", 65, "kg"),
            ("Maida", "మైదా", 45, "kg"),
            ("Besan", "శనగపిండి", 90, "kg"),
            ("Sooji (Rava)", "రవ్వ", 50, "kg"),
            ("Rice Flour", "బియ్యప్పిండి", 50, "kg"),
            ("Ragi Flour", "రాగిపిండి", 70, "kg"),
            ("Jowar Flour", "జొన్నపిండి", 60, "kg"),
            ("Bajra Flour", "సజ్జపిండి", 55, "kg"),
            ("Corn Flour", "మొక్కజొన్న పిండి", 60, "kg"),
        ],
    ),
    "Spices - Whole": (
        "మసాలా గింజలు",
        [
            ("Cumin Seeds (Jeera)", "జీలకర్ర", 80, "pack"),
            ("Coriander Seeds", "ధనియాలు", 45, "pack"),
            ("Black Pepper", "మిరియాలు", 100, "pack"),
            ("Fennel Seeds", "సోంపు", 40, "pack"),
            ("Fenugreek Seeds", "మెంతులు", 30, "pack"),
            ("Mustard Seeds", "ఆవాలు", 30, "pack"),
            ("Ajwain", "వాము", 50, "pack"),
            ("Sesame Seeds", "నువ్వులు", 60, "pack"),
            ("Cloves", "లవంగాలు", 90, "pack"),
            ("Cardamom", "ఏలకులు", 200, "pack"),
            ("Cinnamon", "దాల్చిన చెక్క", 60, "pack"),
            ("Bay Leaf (Tej Patta)", "బిర్యానీ ఆకు", 25, "pack"),
            ("Star Anise", "అనాస పువ్వు", 150, "pack"),
            ("Nutmeg (Jaiphal)", "జాజికాయ", 180, "pack"),
            ("Dry Red Chilli", "ఎండు మిర్చి", 70, "pack"),
            ("Tamarind", "చింతపండు", 90, "kg"),
        ],
    ),
    "Spice Powders": (
        "మసాలా పొడులు",
        [
            ("Turmeric Powder", "పసుపు పొడి", 40, "pack"),
            ("Red Chilli Powder", "కారం పొడి", 60, "pack"),
            ("Coriander Powder", "ధనియాల పొడి", 45, "pack"),
            ("Cumin Powder", "జీలకర్ర పొడి", 60, "pack"),
            ("Garam Masala", "గరం మసాలా", 70, "pack"),
            ("Sambar Powder", "సాంబార్ పొడి", 55, "pack"),
            ("Rasam Powder", "రసం పొడి", 55, "pack"),
            ("Chaat Masala", "చాట్ మసాలా", 50, "pack"),
            ("Biryani Masala", "బిర్యానీ మసాలా", 65, "pack"),
            ("Amchur Powder", "మామిడి పొడి", 55, "pack"),
        ],
    ),
    "Oils": (
        "నూనెలు",
        [
            ("Sunflower Oil", "సన్‌ఫ్లవర్ నూనె", 150, "litre"),
            ("Groundnut Oil", "వేరుశనగ నూనె", 180, "litre"),
            ("Coconut Oil", "కొబ్బరి నూనె", 200, "litre"),
            ("Rice Bran Oil", "రైస్ బ్రాన్ నూనె", 160, "litre"),
            ("Mustard Oil", "ఆవనూనె", 170, "litre"),
            ("Soybean Oil", "సోయాబీన్ నూనె", 140, "litre"),
            ("Sesame Oil", "నువ్వుల నూనె", 220, "litre"),
            ("Olive Oil", "ఆలివ్ నూనె", 500, "litre"),
        ],
    ),
    "Sugar, Salt & Sweeteners": (
        "చక్కెర, ఉప్పు",
        [
            ("Sugar", "చక్కెర", 45, "kg"),
            ("Brown Sugar", "బ్రౌన్ షుగర్", 70, "kg"),
            ("Jaggery", "బెల్లం", 60, "kg"),
            ("Salt", "ఉప్పు", 20, "kg"),
            ("Rock Salt", "సైంధవ లవణం", 40, "kg"),
            ("Himalayan Pink Salt", "హిమాలయన్ పింక్ సాల్ట్", 60, "kg"),
        ],
    ),
    "Dry Fruits & Nuts": (
        "డ్రై ఫ్రూట్స్ & గింజలు",
        [
            ("Almonds", "బాదం పప్పు", 180, "pack"),
            ("Cashews", "జీడిపప్పు", 220, "pack"),
            ("Walnuts", "వాల్‌నట్స్", 250, "pack"),
            ("Pistachios", "పిస్తా పప్పు", 280, "pack"),
            ("Raisins", "ఎండుద్రాక్ష", 90, "pack"),
            ("Dates", "ఖర్జూరం", 120, "pack"),
            ("Figs", "అంజీర", 200, "pack"),
            ("Dried Apricots", "ఎండు యాప్రికాట్", 220, "pack"),
            ("Makhana", "మఖానా", 150, "pack"),
            ("Peanuts", "వేరుశనగలు", 50, "pack"),
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
    "Cooking Essentials": (
        "వంట సరుకులు",
        [
            ("Ghee", "నెయ్యి", 550, "kg"),
            ("Vinegar", "వెనిగర్", 40, "bottle"),
            ("Baking Soda", "బేకింగ్ సోడా", 20, "pack"),
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
