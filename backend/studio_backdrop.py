"""Procedurally composites a product cutout onto a warm, soft studio-style
backdrop - approximating a modern Indian grocery-app product photo (a
diffused warm-tan surface, a hint of out-of-focus wood grain, a soft
grounded shadow, gentle vignette) since no image-generation model is
available in this environment to produce true photographed depth-of-field
backgrounds. Deterministic per product (seeded from its name) so re-runs
are stable rather than producing a different random backdrop each time.
"""

import hashlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CANVAS = 512
PRODUCT_FRACTION = 0.66  # product's largest dimension as a fraction of canvas


def _seeded_rng(label: str) -> np.random.Generator:
    seed = int(hashlib.sha256(label.encode()).hexdigest()[:8], 16)
    return np.random.default_rng(seed)


def _base_gradient(rng: np.random.Generator) -> Image.Image:
    """Soft radial gradient, warm cream center fading to a slightly deeper
    tan at the edges - the "diffused studio light" look."""
    center = np.array([0xF3, 0xE8, 0xD6], dtype=np.float32)
    edge = np.array([0xCE, 0xB8, 0x94], dtype=np.float32)
    # Small per-product hue jitter so a whole grid of cards doesn't look
    # like one flat repeated color swatch.
    jitter = rng.uniform(-8, 8, size=3)
    center = np.clip(center + jitter, 0, 255)
    edge = np.clip(edge + jitter, 0, 255)

    yy, xx = np.mgrid[0:CANVAS, 0:CANVAS].astype(np.float32)
    cx, cy = CANVAS * rng.uniform(0.45, 0.55), CANVAS * rng.uniform(0.4, 0.5)
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    dist = dist / dist.max()
    dist = np.clip(dist * 1.15, 0, 1)

    arr = center[None, None, :] * (1 - dist[:, :, None]) + edge[None, None, :] * dist[:, :, None]
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def _wood_grain_layer(rng: np.random.Generator) -> Image.Image:
    """A very soft, out-of-focus horizontal wood-grain suggestion - low
    contrast, heavily blurred, so it reads as a defocused surface behind
    the product rather than a sharp in-focus texture."""
    rows = rng.normal(0, 1, size=(CANVAS, 1)).astype(np.float32)
    rows = np.cumsum(rows)
    rows = (rows - rows.min()) / (rows.max() - rows.min())
    grain = np.tile(rows[:, None], (1, CANVAS))
    noise = rng.normal(0, 0.04, size=(CANVAS, CANVAS)).astype(np.float32)
    grain = np.clip(grain * 0.15 + noise, -0.15, 0.15)

    img = Image.fromarray(((grain + 0.15) / 0.3 * 255).astype(np.uint8), "L")
    img = img.filter(ImageFilter.GaussianBlur(6))
    return img


def _vignette() -> Image.Image:
    yy, xx = np.mgrid[0:CANVAS, 0:CANVAS].astype(np.float32)
    cx = cy = CANVAS / 2
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (CANVAS * 0.72)
    shade = np.clip(1 - dist, 0, 1) ** 1.5
    return shade


def make_backdrop(label: str) -> Image.Image:
    rng = _seeded_rng(label)
    base = np.array(_base_gradient(rng), dtype=np.float32)

    grain = np.array(_wood_grain_layer(rng), dtype=np.float32) / 255.0
    # Warm brown grain tint multiplied over the gradient at low strength -
    # a hint of wood tone, not a literal wood photo.
    wood_tint = np.array([0x8A, 0x63, 0x3D], dtype=np.float32)
    grain_strength = 0.10
    base = base * (1 - grain_strength * (1 - grain[:, :, None])) + wood_tint[None, None, :] * (
        grain_strength * (1 - grain[:, :, None])
    )

    vignette = _vignette()
    base = base * (0.85 + 0.15 * vignette[:, :, None])

    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")


def _ground_shadow(width: int) -> Image.Image:
    """A simple flat soft-edged ellipse, not shape-matched to the product
    (a shape-matched shadow shows through any hole/notch in an irregular
    silhouette - e.g. ginger's gaps between fingers - as a stray dark
    patch on the product itself). This is how most grocery-app product
    shots actually fake a grounded shadow anyway."""
    w = int(width * 1.15)
    h = max(6, int(w * 0.16))
    pad = h * 3
    canvas = Image.new("L", (w + pad * 2, h + pad * 2), 0)
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((pad, pad, pad + w, pad + h), fill=110)
    return canvas.filter(ImageFilter.GaussianBlur(h / 2.2))


def decontaminate_edges(img: Image.Image) -> Image.Image:
    """Removes the white fringe left around the cutout's edge.

    These cutouts started life alpha-blended onto a white canvas, then had
    alpha recovered via a corner-seeded flood fill
    (make_photos_transparent.py). That flood fill only clears pixels close
    enough to pure white to pass its threshold - anti-aliased boundary
    pixels just inside that threshold stay fully opaque despite still
    being a color blend toward white from the original compositing.
    Invisible on a white card; a visible pale ring on any other backdrop.
    Eroding the alpha mask a couple pixels strips that contaminated
    boundary ring entirely (trading a couple pixels of edge for a clean
    silhouette), then a 1px blur softens the now-clean edge.
    """
    img = img.convert("RGBA")
    r, g, b, a = img.split()
    a = a.filter(ImageFilter.MinFilter(5))
    a = a.filter(ImageFilter.GaussianBlur(1))
    return Image.merge("RGBA", (r, g, b, a))


def soft_edge_fade(img: Image.Image, inner: float = 0.62) -> Image.Image:
    """For full-bleed pile sources with no real background anywhere in
    frame (a crate/basket shot filling the entire photo edge-to-edge) -
    true segmentation has nothing to key off. Rather than a hard
    rectangular crop, fade the crop's own edges out to transparent with a
    soft elliptical gradient, so it blends into the studio backdrop as a
    gentle falloff instead of a visible box. This doubles as a stand-in
    for the shallow depth-of-field look real product photography uses at
    the edges of a pile shot.
    """
    img = img.convert("RGBA")
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w / 2, h / 2
    # Normalized elliptical distance from center (1.0 at the inner edge).
    dist = np.sqrt(((xx - cx) / (w / 2)) ** 2 + ((yy - cy) / (h / 2)) ** 2)
    fade = np.clip(1 - (dist - inner) / (1 - inner), 0, 1)
    fade_img = Image.fromarray((fade * 255).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(min(w, h) * 0.03)
    )
    r, g, b, a = img.split()
    a = Image.fromarray(
        (np.array(a, dtype=np.float32) * (np.array(fade_img, dtype=np.float32) / 255.0)).astype(np.uint8)
    )
    return Image.merge("RGBA", (r, g, b, a))


def composite(product_cutout: Image.Image, label: str) -> Image.Image:
    """product_cutout: RGBA image, subject already tightly cropped to its
    own bounding box (no canvas margin baked in - this function adds the
    margin, backdrop, and shadow itself)."""
    product_cutout = decontaminate_edges(product_cutout)
    pw, ph = product_cutout.size
    scale = (CANVAS * PRODUCT_FRACTION) / max(pw, ph)
    new_size = (max(1, int(pw * scale)), max(1, int(ph * scale)))
    product = product_cutout.resize(new_size, Image.LANCZOS)

    backdrop = make_backdrop(label).convert("RGBA")

    px = (CANVAS - product.width) // 2
    py = (CANVAS - product.height) // 2 + int(CANVAS * 0.03)  # slight downward bias, sits "on" the surface

    shadow = _ground_shadow(product.width)
    shadow_rgba = Image.new("RGBA", shadow.size, (0x3A, 0x2A, 0x18, 0))
    shadow_rgba.putalpha(shadow)
    sx = px + product.width // 2 - shadow.width // 2
    sy = py + int(product.height * 0.86) - shadow.height // 2
    backdrop.alpha_composite(shadow_rgba, (sx, sy))

    backdrop.alpha_composite(product, (px, py))
    return backdrop.convert("RGB")
