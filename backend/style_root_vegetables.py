"""Bakes the warm studio backdrop (studio_backdrop.py) into every Root
Vegetables product photo, replacing the flat white/tan-at-render-time
canvas with an actual composited photo: soft gradient + hint of wood
grain + grounded shadow + vignette, baked directly into the PNG.

Potato is handled separately (see the studio_backdrop docstring / this
session's manual run) since its source is a full-bleed pile with no
background anywhere in frame - soft_edge_fade() feathers its own crop
edges into a vignette rather than relying on real segmentation, which
doesn't apply to any other item here.

Once these are baked in, the Flutter side no longer needs the
Root-Vegetables-only tan color branch in ProductCard/detail screen - see
that follow-up edit.
"""

from pathlib import Path

from PIL import Image

from studio_backdrop import composite

PRODUCTS_DIR = Path(__file__).parent / "static" / "products"

# Already-styled by a dedicated crop this session - skip.
ALREADY_DONE = {"potato-photo.png"}

ROOT_VEGETABLE_PHOTOS = {
    "carrot-photo.png": "Carrot",
    "radish-photo.png": "Radish",
    "turmeric--fresh-photo.png": "Turmeric",
    "purple-yam-photo.png": "Purple Yam",
    "ginger-photo.png": "Ginger",
    "beetroot-photo.png": "Beetroot",
    "turnip-photo.png": "Turnip",
    "yam-photo.png": "Yam",
    "sweet-potato-photo.png": "Sweet Potato",
    "tapioca-photo.png": "Tapioca",
    "colocasia--arbi-photo.png": "Colocasia",
    "lotus-root--stem-photo.png": "Lotus Root",
    "arrowroot-photo.png": "Arrowroot",
    "elephant-foot-yam--suran-photo.png": "Elephant Foot Yam",
}


def run() -> None:
    for filename, label in ROOT_VEGETABLE_PHOTOS.items():
        if filename in ALREADY_DONE:
            continue
        path = PRODUCTS_DIR / filename
        img = Image.open(path).convert("RGBA")
        bbox = img.getbbox()
        cropped = img.crop(bbox)
        result = composite(cropped, label)
        result.save(path)
        print(f"styled {filename}")


if __name__ == "__main__":
    run()
