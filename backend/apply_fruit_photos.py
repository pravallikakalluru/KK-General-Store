"""One-off: crop the 6x6 real-photo fruit grid the owner supplied into 36
individual product photos, normalize each one onto a clean white square
canvas with the fruit properly framed (no cropping, no border artifacts,
generous whitespace), and set it as that product's image_url.

Two-stage process per cell:
  1. Crop the cell with minimal margins (just enough to avoid the
     neighboring cell's card bleeding in) - this intentionally keeps more
     of the cell than the final image needs, since step 2 finds the exact
     fruit content on its own.
  2. Auto-detect the fruit's true pixel bounding box within that crop
     (ignoring near-white pixels, which catches the source grid's faint
     card-border/shadow lines without clipping actual fruit pixels - real
     fruit colors have far more contrast than that thin ~28-off-white
     line), then paste it centered and scaled onto a fresh 500x500 white
     canvas at a fixed 62% fill (whitespace baked into the file itself,
     not just relied on at display time).
"""

from pathlib import Path

from PIL import Image, ImageChops
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_IMAGE = r"C:\Users\Bharath Sarvasetty\Downloads\fruits.png"
CELL = 209  # 1254 / 6
SIDE_PAD = 22  # enough to reliably exclude the neighboring cell's card border
TOP_PAD = 18
BOTTOM_FRAC = 0.74  # label text starts ~0.77 down the cell - stop safely before it

CANVAS_SIZE = 500
TARGET_FRACTION = 0.62  # fruit's largest dimension as a fraction of the canvas
WHITE_TOLERANCE = 45  # skips the source grid's faint card-border/shadow line
# without risking clipping real fruit pixels (which have far more contrast).

# row-major, matches the grid exactly as shown
GRID: list[list[str]] = [
    ["Apple", "Apricot", "Avocado", "Banana", "Ber", "Cherry"],
    ["Coconut", "Custard Apple", "Dragon Fruit", "Grapefruit", "Grapes", "Guava"],
    ["Jackfruit", "Jamun", "Kinnow", "Kiwi", "Lemon", "Litchi"],
    ["Mango", "Mangosteen", "Muskmelon", "Orange", "Papaya", "Passion Fruit"],
    ["Peach", "Pear", "Persimmon", "Pineapple", "Plum", "Pomegranate"],
    ["Rambutan", "Sapota (Chikoo)", "Soursop", "Strawberry", "Sweet Lime (Mosambi)", "Watermelon"],
]


def slugify(name: str) -> str:
    return "".join(c.lower() if c.isalnum() else "-" for c in name).strip("-")


def crop_cell(img: Image.Image, row: int, col: int) -> Image.Image:
    x0 = col * CELL + SIDE_PAD
    y0 = row * CELL + TOP_PAD
    x1 = (col + 1) * CELL - SIDE_PAD
    y1 = row * CELL + int(CELL * BOTTOM_FRAC)
    cell = img.crop((x0, y0, x1, y1))
    flattened = Image.new("RGB", cell.size, "white")
    flattened.paste(cell, mask=cell.split()[3] if cell.mode == "RGBA" else None)
    return flattened


def normalize(cell_img: Image.Image, name: str) -> Image.Image:
    bg = Image.new("RGB", cell_img.size, "white")
    diff = ImageChops.difference(cell_img, bg).convert("L")
    bbox = diff.point(lambda p: 255 if p > WHITE_TOLERANCE else 0).getbbox()
    if bbox is None:
        print(f"  WARNING {name}: no content detected, using full crop")
        bbox = (0, 0, cell_img.width, cell_img.height)

    fruit = cell_img.crop(bbox)
    fw, fh = fruit.size
    max_dim = int(CANVAS_SIZE * TARGET_FRACTION)
    scale = max_dim / max(fw, fh)
    new_size = (max(1, round(fw * scale)), max(1, round(fh * scale)))
    fruit_resized = fruit.resize(new_size, Image.LANCZOS)

    canvas = Image.new("RGB", (CANVAS_SIZE, CANVAS_SIZE), "white")
    paste_x = (CANVAS_SIZE - new_size[0]) // 2
    paste_y = (CANVAS_SIZE - new_size[1]) // 2
    canvas.paste(fruit_resized, (paste_x, paste_y))
    print(f"  OK {name}: content bbox {bbox} ({fw}x{fh}) -> {new_size[0]}x{new_size[1]} on {CANVAS_SIZE}x{CANVAS_SIZE}")
    return canvas


def run() -> None:
    if not Path(SOURCE_IMAGE).exists():
        raise SystemExit(f"Source image not found: {SOURCE_IMAGE}")

    products_dir = Path(settings.static_dir) / "products"
    products_dir.mkdir(parents=True, exist_ok=True)

    grid_img = Image.open(SOURCE_IMAGE)

    db = SessionLocal()
    try:
        updated = 0
        not_found = []
        for row, names in enumerate(GRID):
            for col, name in enumerate(names):
                product = db.scalar(select(Product).where(Product.name == name))
                if product is None:
                    not_found.append(name)
                    continue

                cell = crop_cell(grid_img, row, col)
                final_img = normalize(cell, name)

                filename = f"{slugify(name)}-photo.png"
                new_url = f"/static/products/{filename}"

                # Delete the old file first - but only if it's not the same
                # path we're about to (re)write, since re-running this
                # script uses the same deterministic filename each time.
                if product.image_url != new_url:
                    delete_product_image(product.image_url)

                final_img.save(products_dir / filename)
                product.image_url = new_url
                updated += 1

        db.commit()
        print(f"\nUpdated {updated} products with real photos.")
        if not_found:
            print(f"WARNING - no matching product found for: {', '.join(not_found)}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
