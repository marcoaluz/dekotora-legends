"""Paleta: lê blender/palettes/dekotora.json e converte cores."""
from __future__ import annotations

import json

import numpy as np


def hex_to_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def lin(rgb) -> tuple[float, float, float]:
    """sRGB (paleta) -> linear (o que os nós de material esperam). SEM isto, #ff4d4d sai rosa."""
    out = []
    for c in rgb[:3]:
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def load_palette(path: str) -> tuple[np.ndarray, np.ndarray]:
    """Lê blender/palettes/dekotora.json -> (cores Nx3 float 0..1, cor de contorno 3)."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    cols = [hex_to_rgb(c) for group in data["colors"].values() for c in group]
    return np.array(cols, dtype=np.float32), np.array(hex_to_rgb(data["outline"]), dtype=np.float32)
