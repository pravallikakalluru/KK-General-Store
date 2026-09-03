"""Generate a clean icon-card image for every product that doesn't have a
real photo, and set its image_url.

These are NOT real product photography (no licensed source is available to
fetch that automatically) - each is a representative emoji centered on a
plain white canvas, rendered locally with Pillow. This matches the same
white-canvas, no-text, consistent-fill-fraction convention used by the real
photos (see image_normalize.py) rather than the earlier per-category tinted
card with a baked-in text label - the app's ProductCard already shows the
name below the image, so a second copy of it baked into the picture was
redundant and, being a different visual style per category, made the
catalog look inconsistent across categories.

Only touches products whose image isn't a real photo (filename doesn't end
in "-photo.png", the marker the real-photo pipelines use) - re-running this
regenerates every icon-card product onto the current convention without
ever overwriting a real photo or something an owner uploaded through the
app's image-upload flow (which always saves with a random filename, never
the plain slugified-name one this script uses).
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.models import Product

settings = get_settings()

CANVAS_SIZE = 500
TARGET_FRACTION = 0.62  # matches image_normalize.py's real-photo convention

EMOJI_FONT_PATH = "C:/Windows/Fonts/seguiemj.ttf"

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
    "Sweet Lime (Mosambi)": "\U0001F7E2",
    "Muskmelon": "\U0001F348",
    "Jackfruit": "\U0001F7E1",
    "Strawberry": "\U0001F353",
    "Kiwi": "\U0001F95D",
    "Dragon Fruit": "\U0001F7E3",
    "Avocado": "\U0001F951",
    "Pear": "\U0001F350",
    "Peach": "\U0001F351",
    "Plum": "\U0001F7E3",
    "Apricot": "\U0001F7E0",
    "Litchi": "\U0001F534",
    "Cherry": "\U0001F352",
    "Jamun": "\U0001F7E3",
    "Ber": "\U0001F7E2",
    "Amla": "\U0001F7E2",
    "Passion Fruit": "\U0001F7E0",
    "Rambutan": "\U0001F534",
    "Mangosteen": "\U0001F7E3",
    "Grapefruit": "\U0001F34A",
    "Soursop": "\U0001F7E2",
    "Persimmon": "\U0001F7E0",
    "Kinnow": "\U0001F34A",
    # Vegetables
    "Broccoli": "\U0001F966",
    "Capsicum": "\U0001FAD1",
    "Green Peas": "\U0001FAD9",
    "Sweet Corn": "\U0001F33D",
    "Baby Corn": "\U0001F33D",
    "Cluster Beans (Guar)": "\U0001FAD8",
    "Broad Beans (Avarakkai)": "\U0001FAD8",
    "Cowpea (Lobia)": "\U0001FAD8",
    "Cucumber": "\U0001F952",
    "Gherkin": "\U0001F952",
    "Raw Banana": "\U0001F34C",
    "Raw Papaya": "\U0001F348",
    "Raw Jackfruit": "\U0001F7E1",
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
    "Spinach": "\U0001F96C",
    "Mint Leaves": "\U0001F33F",
    "Amaranth Leaves": "\U0001F343",
    "Fenugreek Leaves (Methi)": "\U0001F33F",
    "Red Amaranth": "\U0001F343",
    "Mustard Leaves": "\U0001F96C",
    "Drumstick Leaves": "\U0001F343",
    "Gongura": "\U0001F343",
    "Spring Onion": "\U0001F9C5",
    "Lettuce": "\U0001F96C",
    "Celery": "\U0001F33F",
    "Ginger": "\U0001FADA",
    "Garlic": "\U0001F9C4",
    "Lemon": "\U0001F34B",
    # Root Vegetables
    "Potato": "\U0001F954",
    "Sweet Potato": "\U0001F360",
    "Carrot": "\U0001F955",
    "Beetroot": "\U0001F7E3",
    "Radish": "\U000026AA",
    "Turnip": "\U000026AA",
    "Yam": "\U0001F7E4",
    "Elephant Foot Yam (Suran)": "\U0001F7E4",
    "Tapioca": "\U0001F7E4",
    "Colocasia (Arbi)": "\U0001F7E4",
    "Turmeric (Fresh)": "\U0001F7E1",
    "Lotus Root (Stem)": "\U000026AA",
    "Arrowroot": "\U0001F7E4",
    # Gourds
    "Bottle Gourd": "\U0001F952",
    "Bitter Gourd (Karela)": "\U0001F952",
    "Ridge Gourd": "\U0001F952",
    "Sponge Gourd": "\U0001F952",
    "Snake Gourd": "\U0001F952",
    "Ash Gourd (Winter Melon)": "\U0001F348",
    "Pointed Gourd (Parwal)": "\U0001F952",
    "Ivy Gourd (Dondakaya)": "\U0001F952",
    "Tinda": "\U0001F7E2",
    "Pumpkin": "\U0001F383",
    # Mushrooms
    "Button Mushroom": "\U0001F344",
    "Oyster Mushroom": "\U0001F344",
    "Shiitake Mushroom": "\U0001F344",
    "Milky Mushroom": "\U0001F344",
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
    # Rice
    "Rice (Sona Masoori)": "\U0001F35A",
    "Basmati Rice": "\U0001F35A",
    "Raw Rice": "\U0001F35A",
    "Boiled Rice": "\U0001F35A",
    "Idli Rice": "\U0001F35A",
    "Dosa Rice": "\U0001F35A",
    "Ponni Rice": "\U0001F35A",
    "Brown Rice": "\U0001F35A",
    "Black Rice": "\U0001F35A",
    "Red Rice": "\U0001F35A",
    "Poha (Atukulu)": "\U0001F33E",
    # Grains & Millets
    "Wheat": "\U0001F33E",
    "Barley": "\U0001F33E",
    "Maize (Corn)": "\U0001F33D",
    "Oats": "\U0001F33E",
    "Ragi (Finger Millet)": "\U0001F7E4",
    "Jowar (Sorghum)": "\U0001F33E",
    "Bajra (Pearl Millet)": "\U0001F33E",
    "Foxtail Millet": "\U0001F7E1",
    "Little Millet": "\U0001F7E1",
    "Kodo Millet": "\U0001F7E4",
    "Amaranth Grain (Rajgira)": "\U0001F7E4",
    "Buckwheat (Kuttu)": "\U0001F7E4",
    "Quinoa": "\U000026AA",
    # Dals & Pulses
    "Toor Dal": "\U0001F7E1",
    "Moong Dal": "\U0001F7E2",
    "Chana Dal": "\U0001F7E4",
    "Urad Dal": "\U000026AB",
    "Masoor Dal": "\U0001F7E0",
    "Rajma (Kidney Beans)": "\U0001F534",
    "Chickpeas (Kabuli Chana)": "\U0001F7E1",
    "Kala Chana": "\U000026AB",
    "Green Gram Whole": "\U0001F7E2",
    "Lobia": "\U0001F7E4",
    "Moth Dal": "\U0001F7E4",
    "Horse Gram (Ulavalu)": "\U0001F7E4",
    "Dried Peas": "\U0001F7E2",
    "Soybean": "\U0001FAD8",
    # Flours
    "Wheat Flour (Atta)": "\U0001F33E",
    "Multigrain Atta": "\U0001F33E",
    "Maida": "\U00002B1C",
    "Besan": "\U0001F7E1",
    "Sooji (Rava)": "\U0001F33E",
    "Rice Flour": "\U00002B1C",
    "Ragi Flour": "\U0001F7E4",
    "Jowar Flour": "\U0001F7E1",
    "Bajra Flour": "\U0001F7E4",
    "Corn Flour": "\U00002B1C",
    # Spices - Whole
    "Cumin Seeds (Jeera)": "\U0001F7E4",
    "Coriander Seeds": "\U0001F7E4",
    "Black Pepper": "\U000026AB",
    "Fennel Seeds": "\U0001F7E2",
    "Fenugreek Seeds": "\U0001F7E1",
    "Mustard Seeds": "\U0001F7E1",
    "Ajwain": "\U0001F7E4",
    "Sesame Seeds": "\U000026AA",
    "Cloves": "\U0001F7E4",
    "Cardamom": "\U0001F7E2",
    "Cinnamon": "\U0001F7E4",
    "Bay Leaf (Tej Patta)": "\U0001F343",
    "Star Anise": "\U0001F7E4",
    "Nutmeg (Jaiphal)": "\U0001F7E4",
    "Dry Red Chilli": "\U0001F336\uFE0F",
    "Tamarind": "\U0001F7E4",
    # Spice Powders
    "Turmeric Powder": "\U0001F7E1",
    "Red Chilli Powder": "\U0001F336\uFE0F",
    "Coriander Powder": "\U0001F33F",
    "Cumin Powder": "\U0001F7E4",
    "Garam Masala": "\U0001F7E0",
    "Sambar Powder": "\U0001F7E0",
    "Rasam Powder": "\U0001F534",
    "Chaat Masala": "\U0001F7E0",
    "Biryani Masala": "\U0001F7E0",
    "Amchur Powder": "\U0001F7E1",
    # Oils
    "Sunflower Oil": "\U0001F33B",
    "Groundnut Oil": "\U0001F95C",
    "Coconut Oil": "\U0001F965",
    "Rice Bran Oil": "\U0001F35A",
    "Mustard Oil": "\U0001F7E1",
    "Soybean Oil": "\U0001FAD8",
    "Sesame Oil": "\U000026AA",
    "Olive Oil": "\U0001FAD2",
    # Sugar, Salt & Sweeteners
    "Sugar": "\U00002B1C",
    "Brown Sugar": "\U0001F7E4",
    "Jaggery": "\U0001F7E4",
    "Salt": "\U0001F9C2",
    "Rock Salt": "\U000026AA",
    "Himalayan Pink Salt": "\U0001F9C2",
    # Dry Fruits & Nuts
    "Almonds": "\U0001F7E4",
    "Cashews": "\U0001F330",
    "Walnuts": "\U0001F7E4",
    "Pistachios": "\U0001F7E2",
    "Raisins": "\U0001F7E3",
    "Dates": "\U0001F7E4",
    "Figs": "\U0001F7E3",
    "Dried Apricots": "\U0001F7E0",
    "Makhana": "\U000026AA",
    "Peanuts": "\U0001F95C",
    # Cooking Essentials
    "Ghee": "\U0001F9C8",
    "Vinegar": "\U0001F9F4",
    "Baking Soda": "\U00002B1C",
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


RENDER_SIZE = 700  # generous headroom - emoji glyphs often sit off-center
# within their own font metrics (anchor="mm" centers on the font's ascent/
# descent box, not the glyph's actual ink), so a plain centered draw can
# come out visibly lopsided (e.g. hugging the top with empty space below).
# Rendering onto a transparent canvas and cropping to the glyph's actual
# alpha (ink) bounding box - not a color-difference guess against a white
# backdrop - fixes that regardless of the glyph's own color: a
# color-difference approach (as used for real photos, which have no alpha
# channel to fall back on) fails for naturally pale glyphs like the milk
# glass or garlic emoji, which are close enough to white to be
# indistinguishable from the background and were coming out as blank
# images. Alpha is exact for anything Pillow itself drew, so this can never
# misdetect regardless of the emoji's own color.


def _longest_run(counts: np.ndarray, threshold_frac: float = 0.15) -> tuple[int, int] | None:
    """(start, end-exclusive) of the longest contiguous run of rows/columns
    whose ink count is at least threshold_frac of the peak - i.e. the main
    body, not a thin (or, like a leaf, briefly wider-but-still-minor)
    appendage. A simple "trim anything below the threshold" doesn't work
    because an appendage with any wide-ish point (a leaf, not just a thin
    stem) can still poke above a flat threshold - it just doesn't do it
    *contiguously* with the body, separated by a dip below threshold at the
    narrow stem itself.
    """
    if counts.max() == 0:
        return None
    mask = counts > (counts.max() * threshold_frac)
    padded = np.concatenate(([False], mask, [False]))
    diffs = np.diff(padded.astype(int))
    starts = np.where(diffs == 1)[0]
    ends = np.where(diffs == -1)[0]
    if len(starts) == 0:
        return None
    lengths = ends - starts
    i = int(np.argmax(lengths))
    return int(starts[i]), int(ends[i])


def render_product_image(emoji: str, label: str = "") -> Image.Image:
    canvas = Image.new("RGBA", (RENDER_SIZE, RENDER_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    emoji_font = ImageFont.truetype(EMOJI_FONT_PATH, round(RENDER_SIZE * 0.6))
    draw.text(
        (RENDER_SIZE / 2, RENDER_SIZE / 2),
        emoji,
        font=emoji_font,
        embedded_color=True,
        anchor="mm",
    )

    alpha = np.array(canvas.split()[-1])
    ys, xs = np.where(alpha > 10)
    if len(xs) == 0:
        print(f"  WARNING {label}: emoji glyph not rendered by this font, using fallback")
        bbox = (0, 0, RENDER_SIZE, RENDER_SIZE)
    else:
        bbox = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)

    content = canvas.crop(bbox)
    cw, ch = content.size

    # Scale to a target size for the glyph's main BODY, not its raw bounding
    # box - some emoji have a thin appendage (a melon's curly stem, a
    # chilli's stalk) that stretches the bounding box well past the actual
    # fruit/vegetable shape without adding meaningful visual size. Scaling
    # by the raw bbox's max dimension then makes that glyph's real body come
    # out visibly smaller than a same-target-dimension glyph with no such
    # appendage (e.g. a cucumber), which is exactly the size inconsistency
    # this was producing. Trimming rows/columns with only sparse ink (a
    # stem is a handful of pixels wide relative to the body) before
    # measuring gives a "core body" dimension to scale against instead,
    # while the stem itself still gets included when the content is pasted.
    alpha_crop = np.array(content.split()[-1]) > 10
    row_run = _longest_run(alpha_crop.sum(axis=1))
    col_run = _longest_run(alpha_crop.sum(axis=0))
    row_run = row_run or (0, ch)
    col_run = col_run or (0, cw)
    core_h = row_run[1] - row_run[0]
    core_w = col_run[1] - col_run[0]
    core_max_dim = max(core_h, core_w)

    max_dim = round(CANVAS_SIZE * TARGET_FRACTION)
    scale = max_dim / core_max_dim
    # Cap it against the FULL bbox (stem included) so scaling up to hit the
    # core-body target can never push the appendage itself off the canvas.
    max_scale = (CANVAS_SIZE * 0.94) / max(cw, ch)
    scale = min(scale, max_scale)
    new_size = (max(1, round(cw * scale)), max(1, round(ch * scale)))
    content_resized = content.resize(new_size, Image.LANCZOS)

    # Center on the BODY's midpoint, not the full bbox's midpoint - an
    # appendage sitting only on one side (a stem above, never below) pulls
    # the whole bbox's geometric center away from the body's own center, so
    # centering the full bbox leaves the actual fruit/vegetable shape
    # sitting off-center by half the appendage's length. Every product's
    # body then lands at a different height depending on whether (and how
    # much of) an appendage it happens to have - exactly the "boxes don't
    # line up" mismatch this fixes: every body now centers on the same
    # canvas position regardless of its appendage.
    body_center_x = (col_run[0] + col_run[1]) / 2 * scale
    body_center_y = (row_run[0] + row_run[1]) / 2 * scale
    paste_x = round(CANVAS_SIZE / 2 - body_center_x)
    paste_y = round(CANVAS_SIZE / 2 - body_center_y)
    # Clamp so the full (appendage-included) content never goes off-canvas.
    paste_x = max(0, min(paste_x, CANVAS_SIZE - new_size[0]))
    paste_y = max(0, min(paste_y, CANVAS_SIZE - new_size[1]))

    final = Image.new("RGB", (CANVAS_SIZE, CANVAS_SIZE), "white")
    final.paste(content_resized, (paste_x, paste_y), content_resized)
    return final


def run() -> None:
    products_dir = Path(settings.static_dir) / "products"
    products_dir.mkdir(parents=True, exist_ok=True)

    db = SessionLocal()
    try:
        products = db.scalars(select(Product)).all()

        generated = 0
        skipped = 0
        for product in products:
            if product.image_url and "-photo.png" in product.image_url:
                skipped += 1
                continue

            emoji = EMOJI_MAP.get(product.name, DEFAULT_EMOJI)

            img = render_product_image(emoji, product.name)
            filename = f"{slugify(product.name)}.png"
            img.save(products_dir / filename)

            product.image_url = f"/static/products/{filename}"
            generated += 1

        db.commit()
        print(f"Generated {generated} product images (consistent white-canvas style), skipped {skipped} real photos.")
    finally:
        db.close()


if __name__ == "__main__":
    run()
