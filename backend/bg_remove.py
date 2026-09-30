"""Real ML background removal via the u2net ONNX model, run directly
through onnxruntime - NOT through the `rembg` package, whose dependency
chain (pymatting -> scipy.spatial.transform) is blocked by a Windows
Application Control policy in this environment. Same underlying model
rembg itself uses, just invoked without the blocked wrapper.
"""

from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageFilter

MODEL_PATH = Path(__file__).parent / "models" / "u2net.onnx"
INPUT_SIZE = 320
_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

_session: ort.InferenceSession | None = None


def _get_session() -> ort.InferenceSession:
    global _session
    if _session is None:
        _session = ort.InferenceSession(str(MODEL_PATH), providers=["CPUExecutionProvider"])
    return _session


def _predict_mask(img: Image.Image) -> Image.Image:
    """Returns a single-channel L-mode mask, same size as img, 0-255."""
    rgb = img.convert("RGB")
    small = rgb.resize((INPUT_SIZE, INPUT_SIZE), Image.LANCZOS)
    arr = np.array(small).astype(np.float32) / 255.0
    arr = (arr - _MEAN) / _STD
    arr = arr.transpose(2, 0, 1)[np.newaxis, :, :, :].astype(np.float32)

    session = _get_session()
    input_name = session.get_inputs()[0].name
    outputs = session.run(None, {input_name: arr})
    saliency = outputs[0][0, 0]  # (320, 320), roughly 0..1 but not guaranteed normalized

    lo, hi = saliency.min(), saliency.max()
    if hi > lo:
        saliency = (saliency - lo) / (hi - lo)
    mask = (saliency * 255).astype(np.uint8)
    mask_img = Image.fromarray(mask, mode="L").resize(rgb.size, Image.LANCZOS)
    return mask_img


def cutout_on_white(source_img: Image.Image, threshold: int = 20, feather: float = 2.0) -> Image.Image:
    """Removes the background from [source_img] using u2net saliency,
    composited onto a plain white canvas the same size as the source.
    [threshold] drops low-confidence mask values to fully transparent
    (avoids a faint grey halo around the subject); [feather] softens the
    remaining edge so it isn't a hard jagged cutout line.
    """
    rgb = source_img.convert("RGB")
    mask = _predict_mask(rgb)

    mask_arr = np.array(mask)
    mask_arr = np.where(mask_arr < threshold, 0, mask_arr).astype(np.uint8)
    mask = Image.fromarray(mask_arr, mode="L")
    if feather > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(feather))

    white = Image.new("RGB", rgb.size, "white")
    return Image.composite(rgb, white, mask)
