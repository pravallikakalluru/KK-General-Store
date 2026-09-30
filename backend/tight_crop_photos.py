"""Trims the SOURCE image tightly around the product (using the existing
u2net saliency model from bg_remove.py to find the subject's bounding
box), then re-composites onto the standard 500x500 canvas - so the
product fills ~85-95% of the frame instead of floating in a sea of
leftover background/whitespace from the original full-picture photo.

This does NOT remove the background (no cutout, no white canvas) - it
keeps the real photo (wood table, dark background, whatever the source
has), just crops in tighter around the subject. The display frame
(square, object-fit: contain) is unchanged; this only touches the
source image content.
"""

from pathlib import Path

import numpy as np
from PIL import Image

from bg_remove import _predict_mask

CANVAS = 500
MARGIN_FRACTION = 0.08  # ~8% breathing room on each side of the tight bbox


def tight_crop(img: Image.Image, threshold: int = 30) -> Image.Image:
    """Crops to a SQUARE region tightly around the subject, using real
    photo content (not white padding) to fill out the shorter dimension -
    pasting a non-square crop onto a white square canvas just reintroduces
    the same letterbox bars this is meant to remove.
    """
    rgb = img.convert("RGB")
    mask = _predict_mask(rgb)
    mask_arr = np.array(mask)
    ys, xs = np.where(mask_arr >= threshold)
    if len(xs) == 0 or len(ys) == 0:
        return rgb  # no confident subject found - leave untouched

    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    w, h = x1 - x0, y1 - y0
    mx, my = int(w * MARGIN_FRACTION), int(h * MARGIN_FRACTION)

    x0 = max(0, x0 - mx)
    y0 = max(0, y0 - my)
    x1 = min(rgb.width, x1 + mx)
    y1 = min(rgb.height, y1 + my)

    # Expand the shorter side to match the longer one, centered on the
    # bbox, clamped to the image bounds (shifting the box first if the
    # naive centered expansion would run off one edge).
    box_w, box_h = x1 - x0, y1 - y0
    side = max(box_w, box_h)

    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    nx0, nx1 = cx - side / 2, cx + side / 2
    ny0, ny1 = cy - side / 2, cy + side / 2

    if nx0 < 0:
        nx1 -= nx0
        nx0 = 0
    if nx1 > rgb.width:
        nx0 -= nx1 - rgb.width
        nx1 = rgb.width
    if ny0 < 0:
        ny1 -= ny0
        ny0 = 0
    if ny1 > rgb.height:
        ny0 -= ny1 - rgb.height
        ny1 = rgb.height

    nx0, ny0 = max(0, int(round(nx0))), max(0, int(round(ny0)))
    nx1, ny1 = min(rgb.width, int(round(nx1))), min(rgb.height, int(round(ny1)))

    return rgb.crop((nx0, ny0, nx1, ny1))


def compose_on_canvas(img: Image.Image) -> Image.Image:
    """img is already square (or as close as the source allows) - resize
    directly rather than fitting inside a padded canvas."""
    if img.width != img.height:
        side = min(img.width, img.height)
        left = (img.width - side) // 2
        top = (img.height - side) // 2
        img = img.crop((left, top, left + side, top + side))
    return img.resize((CANVAS, CANVAS), Image.LANCZOS)
