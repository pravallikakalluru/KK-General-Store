"""One-off: apply the individually-supplied Amla photo, with a genuinely
transparent background (not baked-in white like the rest of the catalog).

The source file is a JPEG (no real alpha channel) whose "transparent" look
is a checkerboard pattern baked into the pixels (a stock-photo-site preview
convention) rather than actual transparency. Background removal here works
by flood-filling the desaturated (grey/white checkerboard) region starting
from the image border, so isolated low-saturation spots fully surrounded by
fruit (specular highlights on water droplets) are correctly kept as content
instead of being punched out as background.
"""

from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from sqlalchemy import select

from app.config import get_settings
from app.database import SessionLocal
from app.image_storage import delete_product_image
from app.models import Product

settings = get_settings()

SOURCE_PATH = (
    r"C:\Users\BHARAT~1\AppData\Local\Temp\claude\c--Users-Bharath-Sarvasetty-Documents-KK"
    r"\0efcac0b-7bfa-44be-8a8b-67c0e38eab2d\scratchpad\amla\amla_source.jpg"
)
PRODUCT_NAME = "Amla"

CANVAS_SIZE = 500
TARGET_FRACTION = 0.62
SATURATION_THRESHOLD = 20  # max(r,g,b) - min(r,g,b) below this = "grey/white" candidate


def remove_checkerboard_background(img: Image.Image) -> Image.Image:
    rgb = np.array(img.convert("RGB")).astype(np.int16)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    saturation = rgb.max(axis=2) - rgb.min(axis=2)
    bg_candidate = saturation < SATURATION_THRESHOLD

    labeled, _ = ndimage.label(bg_candidate)
    border_labels = set(labeled[0, :]) | set(labeled[-1, :]) | set(labeled[:, 0]) | set(labeled[:, -1])
    border_labels.discard(0)

    is_background = np.isin(labeled, list(border_labels))
    alpha = np.where(is_background, 0, 255).astype(np.uint8)

    # Feather the cutout edge slightly so it isn't a hard jagged line.
    alpha_img = Image.fromarray(alpha, mode="L").filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(1.2))

    rgba = np.dstack([np.array(img.convert("RGB")), np.array(alpha_img)])
    return Image.fromarray(rgba, mode="RGBA")


def normalize_transparent(img: Image.Image) -> Image.Image:
    alpha = np.array(img.split()[-1])
    ys, xs = np.where(alpha > 10)
    bbox = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)

    content = img.crop(bbox)
    cw, ch = content.size
    max_dim = int(CANVAS_SIZE * TARGET_FRACTION)
    scale = max_dim / max(cw, ch)
    new_size = (max(1, round(cw * scale)), max(1, round(ch * scale)))
    content_resized = content.resize(new_size, Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    paste_x = (CANVAS_SIZE - new_size[0]) // 2
    paste_y = (CANVAS_SIZE - new_size[1]) // 2
    canvas.paste(content_resized, (paste_x, paste_y), content_resized)
    print(f"  OK Amla: content bbox {bbox} ({cw}x{ch}) -> {new_size[0]}x{new_size[1]} on {CANVAS_SIZE}x{CANVAS_SIZE} (transparent)")
    return canvas


def run() -> None:
    src_path = Path(SOURCE_PATH)
    if not src_path.exists():
        raise SystemExit(f"Source photo not found: {SOURCE_PATH}")

    products_dir = Path(settings.static_dir) / "products"
    products_dir.mkdir(parents=True, exist_ok=True)

    img = Image.open(src_path)
    cutout = remove_checkerboard_background(img)
    final_img = normalize_transparent(cutout)

    db = SessionLocal()
    try:
        product = db.scalar(select(Product).where(Product.name == PRODUCT_NAME))
        if product is None:
            raise SystemExit(f"No product named {PRODUCT_NAME!r} found in DB")

        out_filename = "amla-photo.png"
        new_url = f"/static/products/{out_filename}"

        if product.image_url != new_url:
            delete_product_image(product.image_url)

        final_img.save(products_dir / out_filename)
        product.image_url = new_url
        db.commit()
        print(f"Updated {PRODUCT_NAME} -> {new_url}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
