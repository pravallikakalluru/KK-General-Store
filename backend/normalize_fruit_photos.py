"""Re-frame the 36 real fruit photos (extracted from the owner's reference
grid) so the fruit itself is properly composed on the canvas: auto-detect
the fruit's actual pixel bounding box (trimming away any incidental
whitespace already in the crop), then paste it back onto a fresh white
square canvas scaled down to a fixed target fraction of that canvas.

This bakes the whitespace into the file itself, rather than relying only on
runtime layout scaling - the source image is "properly framed" on disk,
which is what actually gets served, downloaded, and shown everywhere
(product card, detail screen, receipts, WhatsApp share).
"""

from pathlib import Path

from PIL import Image, ImageChops

STATIC_PRODUCTS = Path(__file__).parent / "static" / "products"
CANVAS_SIZE = 500
# Fruit's largest dimension as a fraction of the canvas - middle of the
# requested 55-70% range.
TARGET_FRACTION = 0.62
WHITE_TOLERANCE = 45  # how far from pure white still counts as "background" -
# the source crops have a faint ~28-off-white shadow/border line right at
# their top edge (from the original grid's card styling); real fruit colors
# have far more contrast than that, so this safely skips the artifact
# without risking clipping actual product pixels.


def tight_bbox(img: Image.Image) -> tuple[int, int, int, int] | None:
    rgb = img.convert("RGB")
    bg = Image.new("RGB", rgb.size, "white")
    diff = ImageChops.difference(rgb, bg)
    diff_gray = diff.convert("L")
    bbox = diff_gray.point(lambda p: 255 if p > WHITE_TOLERANCE else 0).getbbox()
    return bbox


def normalize(path: Path) -> None:
    img = Image.open(path).convert("RGB")
    bbox = tight_bbox(img)
    if bbox is None:
        print(f"  SKIP {path.name}: couldn't detect content (all white?)")
        return

    fruit = img.crop(bbox)
    fw, fh = fruit.size

    max_dim = int(CANVAS_SIZE * TARGET_FRACTION)
    scale = max_dim / max(fw, fh)
    new_size = (max(1, round(fw * scale)), max(1, round(fh * scale)))
    fruit_resized = fruit.resize(new_size, Image.LANCZOS)

    canvas = Image.new("RGB", (CANVAS_SIZE, CANVAS_SIZE), "white")
    paste_x = (CANVAS_SIZE - new_size[0]) // 2
    paste_y = (CANVAS_SIZE - new_size[1]) // 2
    canvas.paste(fruit_resized, (paste_x, paste_y))

    canvas.save(path)
    print(f"  OK {path.name}: fruit bbox {fw}x{fh} -> placed at {new_size[0]}x{new_size[1]} on {CANVAS_SIZE}x{CANVAS_SIZE}")


def run() -> None:
    photos = sorted(STATIC_PRODUCTS.glob("*-photo.png"))
    print(f"Normalizing {len(photos)} real fruit photos...")
    for path in photos:
        normalize(path)
    print("Done.")


if __name__ == "__main__":
    run()
