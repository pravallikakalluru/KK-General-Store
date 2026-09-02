"""Generate a clean, illustrative icon-card image for every product that
doesn't already have one, and set its image_url.

These are NOT real product photography (no licensed source is available to
fetch that automatically) - each is a colored card (by category) with a
representative emoji and the product's English name, rendered locally with
Pillow. The owner can replace any of these with a real photo at any time via
the existing "Edit Product" image upload in the app - this script only fills
in a picture for products that don't have one yet, so it never overwrites a
real photo an owner has already uploaded.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.models import Category, Product

settings = get_settings()

IMAGE_SIZE = 500
EMOJI_FONT_PATH = "C:/Windows/Fonts/seguiemj.ttf"
NAME_FONT_PATH = "C:/Windows/Fonts/segoeuib.ttf"

CATEGORY_COLORS: dict[str, str] = {
    "Fruits": "#FFF3D6",
    "Vegetables": "#E3F2E1",
    "Temple & Pooja Needs": "#FFE8D6",
    "Cleaning & Household": "#E1F0FA",
    "Grains & Pulses": "#F5EBDD",
    "Cooking Essentials": "#FFF6DA",
    "Spices": "#FBE3E0",
    "Instant Foods & Snacks": "#F0E6FA",
    "Dairy & Eggs": "#FFFBEA",
}
DEFAULT_COLOR = "#F0F4EF"

# product name (must match seed.py's CATALOG exactly) -> emoji
EMOJI_MAP: dict[str, str] = {
    # Fruits
    "Banana": "\U0001F34C",
    "Apple": "\U0001F34E",
    "Mango": "\U0001F96D",
    "Orange": "\U0001F34A",
    "Papaya": "\U0001F348",
    "Watermelon": "\U0001F349",
    "Grapes": "\U0001F347",
    "Pomegranate": "\U0001F534",
    "Guava": "\U0001F34F",
    "Pineapple": "\U0001F34D",
    "Sapota (Chikoo)": "\U0001F7E4",
    "Custard Apple": "\U0001F7E2",
    # Vegetables
    "Tomato": "\U0001F345",
    "Onion": "\U0001F9C5",
    "Potato": "\U0001F954",
    "Brinjal (Eggplant)": "\U0001F346",
    "Ladies Finger (Okra)": "\U0001F33F",
    "Green Chilli": "\U0001F336\uFE0F",
    "Carrot": "\U0001F955",
    "Cabbage": "\U0001F96C",
    "Cauliflower": "\U0001F966",
    "Beans": "\U0001FAD8",
    "Bottle Gourd": "\U0001F952",
    "Ridge Gourd": "\U0001F952",
    "Drumstick": "\U0001F33F",
    "Coriander Leaves": "\U0001F33F",
    "Curry Leaves": "\U0001F343",
    "Ginger": "\U0001FADA",
    "Garlic": "\U0001F9C4",
    "Lemon": "\U0001F34B",
    # Temple & Pooja Needs
    "Agarbatti (Incense Sticks)": "\U0001F56F\uFE0F",
    "Camphor": "\U000026AA",
    "Cotton Wicks (Lamp Thread)": "\U0001F9F5",
    "Kumkum": "\U0001F534",
    "Turmeric Powder (Pooja)": "\U0001F7E1",
    "Sandalwood Powder": "\U0001F7E0",
    "Coconut": "\U0001F965",
    "Betel Leaves": "\U0001F343",
    "Betel Nut": "\U0001F330",
    "Pooja Lamp Oil": "\U0001FA94",
    "Cotton Garland Thread": "\U0001F9F5",
    "Pooja Bell": "\U0001F514",
    # Cleaning & Household
    "Surf Excel Detergent Powder": "\U0001F9FC",
    "Detergent Soap Bar": "\U0001F9FC",
    "Broomstick": "\U0001F9F9",
    "Floor Cleaner": "\U0001F9F4",
    "Dishwash Bar": "\U0001F9FC",
    "Dishwash Liquid": "\U0001F9F4",
    "Toilet Cleaner": "\U0001F9F4",
    "Phenyl": "\U0001F9F4",
    "Mop": "\U0001F9F9",
    "Naphthalene Balls": "\U000026AA",
    "Scrub Pad": "\U0001F9FD",
    "Garbage Bags": "\U0001F5D1\uFE0F",
    # Grains & Pulses
    "Rice (Sona Masoori)": "\U0001F35A",
    "Wheat Flour (Atta)": "\U0001F33E",
    "Toor Dal": "\U0001F7E1",
    "Moong Dal": "\U0001F7E2",
    "Chana Dal": "\U0001F7E4",
    "Urad Dal": "\U000026AB",
    "Rajma (Kidney Beans)": "\U0001F534",
    "Chickpeas (Kabuli Chana)": "\U0001F7E1",
    "Basmati Rice": "\U0001F35A",
    "Sooji (Rava)": "\U0001F33E",
    "Poha (Atukulu)": "\U0001F33E",
    "Green Gram Whole": "\U0001F7E2",
    # Cooking Essentials
    "Sunflower Oil": "\U0001F33B",
    "Groundnut Oil": "\U0001F95C",
    "Ghee": "\U0001F9C8",
    "Salt": "\U0001F9C2",
    "Sugar": "\U00002B1C",
    "Jaggery": "\U0001F7E4",
    "Tamarind": "\U0001F7E4",
    "Vinegar": "\U0001F9F4",
    "Baking Soda": "\U00002B1C",
    "Coconut Oil": "\U0001F965",
    # Spices
    "Turmeric Powder": "\U0001F7E1",
    "Red Chilli Powder": "\U0001F336\uFE0F",
    "Coriander Powder": "\U0001F33F",
    "Cumin Seeds (Jeera)": "\U0001F7E4",
    "Mustard Seeds": "\U0001F7E1",
    "Garam Masala": "\U0001F7E0",
    "Black Pepper": "\U000026AB",
    "Cardamom": "\U0001F7E2",
    "Cloves": "\U0001F7E4",
    "Cinnamon": "\U0001F7E4",
    "Fenugreek Seeds": "\U0001F7E1",
    "Fennel Seeds": "\U0001F7E2",
    "Sambar Powder": "\U0001F7E0",
    "Rasam Powder": "\U0001F534",
    # Instant Foods & Snacks
    "Maggi Noodles": "\U0001F35C",
    "Yippee Noodles": "\U0001F35C",
    "Potato Chips": "\U0001F35F",
    "Biscuits": "\U0001F36A",
    "Namkeen Mixture": "\U0001F968",
    "Bread": "\U0001F35E",
    "Tomato Ketchup": "\U0001F345",
    "Cornflakes": "\U0001F963",
    "Cup Noodles": "\U0001F35C",
    "Rusk": "\U0001F36A",
    # Dairy & Eggs
    "Milk": "\U0001F95B",
    "Eggs": "\U0001F95A",
    "Curd (Yogurt)": "\U0001F963",
    "Paneer": "\U00002B1C",
    "Butter": "\U0001F9C8",
    "Cheese Slices": "\U0001F9C0",
}
DEFAULT_EMOJI = "\U0001F6D2"  # shopping trolley, generic fallback


def slugify(name: str) -> str:
    return "".join(c.lower() if c.isalnum() else "-" for c in name).strip("-")


def render_product_image(name: str, emoji: str, bg_color: str) -> Image.Image:
    img = Image.new("RGB", (IMAGE_SIZE, IMAGE_SIZE), bg_color)
    draw = ImageDraw.Draw(img)

    emoji_font = ImageFont.truetype(EMOJI_FONT_PATH, 200)
    draw.text(
        (IMAGE_SIZE / 2, IMAGE_SIZE / 2 - 30),
        emoji,
        font=emoji_font,
        embedded_color=True,
        anchor="mm",
    )

    name_font = ImageFont.truetype(NAME_FONT_PATH, 34)
    # Wrap long names onto two lines so they don't overflow the card.
    words = name.split(" ")
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=name_font) > IMAGE_SIZE - 40:
            if current:
                lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)

    y = IMAGE_SIZE - 60 - (len(lines) - 1) * 40
    for line in lines:
        draw.text((IMAGE_SIZE / 2, y), line, font=name_font, fill="#1B1B1B", anchor="mm")
        y += 40

    return img


def run() -> None:
    products_dir = Path(settings.static_dir) / "products"
    products_dir.mkdir(parents=True, exist_ok=True)

    db = SessionLocal()
    try:
        products = db.scalars(select(Product)).all()
        categories = {c.id: c.name for c in db.scalars(select(Category)).all()}

        generated = 0
        skipped = 0
        for product in products:
            if product.image_url:
                skipped += 1
                continue

            category_name = categories.get(product.category_id, "")
            bg_color = CATEGORY_COLORS.get(category_name, DEFAULT_COLOR)
            emoji = EMOJI_MAP.get(product.name, DEFAULT_EMOJI)

            img = render_product_image(product.name, emoji, bg_color)
            filename = f"{slugify(product.name)}.png"
            img.save(products_dir / filename)

            product.image_url = f"/static/products/{filename}"
            generated += 1

        db.commit()
        print(f"Generated {generated} product images, skipped {skipped} that already had one.")
    finally:
        db.close()


if __name__ == "__main__":
    run()
