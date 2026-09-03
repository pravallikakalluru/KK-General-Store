"""Shared product-photo normalization: given ANY source photo (however it's
framed - tightly cropped, mostly whitespace, single item, item + a cut
slice), produce a clean 500x500 white-canvas version with the product
properly centered at a fixed target fill fraction, generous whitespace on
every side, and no cropping.

Approach:
  1. Threshold the image against pure white (WHITE_TOLERANCE) to find all
     non-background pixels.
  2. Label connected components and keep only the ones large enough
     relative to the biggest one (MIN_COMPONENT_FRACTION) - this is what
     makes it robust to small, unrelated color specks (a stray card-border
     artifact, a compression speckle) while still correctly keeping
     legitimate multi-piece compositions like "whole fruit + a cut slice",
     which are usually a comfortably large fraction of the main piece's
     area, unlike a tiny artifact.
  3. Take the union bounding box of the kept components, scale it down to
     TARGET_FRACTION of the canvas (preserving aspect ratio), and paste it
     centered on a fresh white square.
"""

from PIL import Image, ImageChops
from scipy import ndimage

CANVAS_SIZE = 500
TARGET_FRACTION = 0.62  # product's largest dimension as a fraction of the canvas
WHITE_TOLERANCE = 45  # how far from pure white still counts as "background"
MIN_COMPONENT_FRACTION = 0.08  # keep components >= 8% of the largest one's area


def _content_mask(img: Image.Image) -> "ndimage.numpy.ndarray":
    bg = Image.new("RGB", img.size, "white")
    diff = ImageChops.difference(img, bg).convert("L")
    binary = diff.point(lambda p: 1 if p > WHITE_TOLERANCE else 0)
    import numpy as np

    return np.array(binary)


def _combined_bbox(mask) -> tuple[int, int, int, int] | None:
    labeled, num_features = ndimage.label(mask)
    if num_features == 0:
        return None

    sizes = ndimage.sum(mask, labeled, index=range(1, num_features + 1))
    max_size = max(sizes)
    keep_labels = [i + 1 for i, s in enumerate(sizes) if s >= max_size * MIN_COMPONENT_FRACTION]

    x_min = y_min = None
    x_max = y_max = None
    objects = ndimage.find_objects(labeled)
    for label_id in keep_labels:
        sl = objects[label_id - 1]
        y_slice, x_slice = sl
        y0, y1 = y_slice.start, y_slice.stop
        x0, x1 = x_slice.start, x_slice.stop
        x_min = x0 if x_min is None else min(x_min, x0)
        y_min = y0 if y_min is None else min(y_min, y0)
        x_max = x1 if x_max is None else max(x_max, x1)
        y_max = y1 if y_max is None else max(y_max, y1)

    if x_min is None:
        return None
    return (x_min, y_min, x_max, y_max)


def normalize(source_img: Image.Image, label: str = "") -> Image.Image:
    """Takes any RGB(A) source image and returns a normalized 500x500 RGB
    product photo: content found, small artifacts dropped, scaled to
    TARGET_FRACTION, centered on a white square."""
    img = source_img.convert("RGB")
    mask = _content_mask(img)
    bbox = _combined_bbox(mask)

    if bbox is None:
        print(f"  WARNING {label}: no content detected, using full image")
        bbox = (0, 0, img.width, img.height)

    content = img.crop(bbox)
    cw, ch = content.size
    max_dim = int(CANVAS_SIZE * TARGET_FRACTION)
    scale = max_dim / max(cw, ch)
    new_size = (max(1, round(cw * scale)), max(1, round(ch * scale)))
    content_resized = content.resize(new_size, Image.LANCZOS)

    canvas = Image.new("RGB", (CANVAS_SIZE, CANVAS_SIZE), "white")
    paste_x = (CANVAS_SIZE - new_size[0]) // 2
    paste_y = (CANVAS_SIZE - new_size[1]) // 2
    canvas.paste(content_resized, (paste_x, paste_y))

    print(f"  OK {label}: content bbox {bbox} ({cw}x{ch}) -> {new_size[0]}x{new_size[1]} on {CANVAS_SIZE}x{CANVAS_SIZE}")
    return canvas
