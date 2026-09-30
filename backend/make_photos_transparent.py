"""One-off: convert every product photo in static/products/ from an opaque
white 500x500 canvas (image_normalize.py's original output) to a real RGBA
transparent canvas, in place - so the frontend can show product photos on
any card backdrop color (a warm tan, per the new card design) instead of
only ever looking right on a pure-white card.

No re-segmentation needed: every photo already has the product centered on
a *uniform, un-textured* white canvas with guaranteed margin on all sides
(image_normalize.py's TARGET_FRACTION always leaves whitespace), so a
corner-seeded flood fill - only the white region reachable from the four
corners becomes transparent - cleanly recovers the subject's silhouette
without touching any legitimately-white/pale interior pixels (a
cauliflower's florets, garlic's papery skin, ...), since those aren't
connected to the border through an unbroken near-white path.

Some earlier photos (the "skip ML cutout" fallback, used for full-bleed
pile/crate sources with no real background to remove - Onion, Potato,
Turmeric, a chunk of the new vegetable batch, etc.) are a plain rectangular
crop with little to no canvas margin baked in. Flood fill still runs on
these safely (it only ever removes background it can prove is background),
it just can't do much - they'll keep a hard-edged, roughly-rectangular
silhouette rather than a soft one. That's a pre-existing composition
limit of those source photos, not something this script introduces.
"""

from pathlib import Path

from PIL import Image, ImageDraw

PRODUCTS_DIR = Path(__file__).parent / "static" / "products"


def to_transparent(img: Image.Image, thresh: int = 60) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    for pt in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        ImageDraw.floodfill(img, pt, (255, 255, 255, 0), thresh=thresh)
    return img


def run() -> None:
    converted = 0
    skipped = 0
    for path in sorted(PRODUCTS_DIR.glob("*.png")):
        img = Image.open(path)
        if img.mode == "RGBA" and img.getextrema()[3][0] < 255:
            # Already has real transparency somewhere - not one of our
            # opaque-white normalize() outputs (e.g. a manually-uploaded
            # logo/icon asset) - leave it alone.
            skipped += 1
            continue
        out = to_transparent(img)
        out.save(path)
        converted += 1
    print(f"Converted {converted} photos to transparent, skipped {skipped}.")


if __name__ == "__main__":
    run()
