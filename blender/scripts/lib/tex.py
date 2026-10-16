"""Texturas procedurais pequenas (numpy) para materiais PBR exportados no .glb.

Cada função devolve uma imagem do Blender já empacotada (vai embutida no .glb).
Resoluções baixas (256-512 px) para o celular.
"""
from __future__ import annotations

import bpy
import numpy as np

from .palette import hex_to_rgb


def _image(name: str, arr: np.ndarray, srgb: bool = True):
    """arr: (h, w, 3|4) float 0..1 em sRGB (cores) ou dados lineares (normal/rugosidade)."""
    h, w = arr.shape[:2]
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1))], axis=2)
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    img.pack()
    return img


def perforated_mesh(name: str = "tex_perforated", cols: int = 28, rows: int = 2, w: int = 1024, h: int = 72):
    """Chapa perfurada (a proporção w:h deve seguir a da face, para os furos ficarem redondos): furos escuros redondos sobre aço claro (grade do estilo Actros/Dekotora)."""
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx / w * cols) % 1.0 - 0.5
    v = (yy / h * rows) % 1.0 - 0.5
    d = np.sqrt((u * (w / cols)) ** 2 + (v * (h / rows)) ** 2) / (w / cols)
    hole = np.clip((0.34 - d) / 0.05, 0, 1)
    steel = np.array(hex_to_rgb("#aab4c2"))
    dark = np.array(hex_to_rgb("#08080a"))
    arr = steel * (1 - hole[..., None]) + dark * hole[..., None]
    return _image(name, arr)


def diamond_plate(name: str = "tex_diamond", n: int = 8, size: int = 256):
    """Chapa xadrez antiderrapante (degraus): losangos claros sobre aço escuro."""
    yy, xx = np.mgrid[0:size, 0:size]
    u = (xx / size * n) % 1.0
    v = (yy / size * n * 2) % 1.0
    a = np.abs(u - 0.5) + np.abs(v - 0.5) * 0.5
    bump = np.clip((0.32 - a) / 0.06, 0, 1)
    lo = np.array(hex_to_rgb("#4a505a"))
    hi = np.array(hex_to_rgb("#c4ccd8"))
    arr = lo * (1 - bump[..., None]) + hi * bump[..., None]
    return _image(name, arr)
