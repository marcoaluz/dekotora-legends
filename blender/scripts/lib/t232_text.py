"""Escrever kanji nas pinturas da T-232 (triângulos da fonte Yuji, gerados por lib/t232_glyphs.py no Blender).
Texto vertical (tategaki: de cima para baixo) ou horizontal, com contorno grosso e brilho de neon opcionais."""
from __future__ import annotations

import os

import numpy as np

from . import paint2d as p
from .paint2d import hexc

_CACHE: dict = {}


def load(npz_path: str) -> dict:
    if npz_path not in _CACHE:
        with np.load(npz_path) as z:
            _CACHE[npz_path] = {k: z[k] for k in z.files}
    return _CACHE[npz_path]


def glyph(glyphs: dict, ch: str) -> np.ndarray:
    key = "U+%04X" % ord(ch)
    if key not in glyphs:
        raise KeyError("caractere sem glifo: %s (rode a geração das letras)" % key)
    return glyphs[key]


def layout(glyphs, text, x, y, size, vertical=True, spacing=1.0):
    """Triângulos (tela) do texto com o 1º caractere centrado em (x, y); cada caractere ocupa `size` (a letra em si é
    ~0,8-0,9 disso). Vertical: desce; horizontal: vai para a direita. Devolve uma lista (um item por caractere)."""
    out = []
    for i, ch in enumerate(text):
        t = glyph(glyphs, ch).copy() * size
        if vertical:
            t[..., 0] += x
            t[..., 1] += y + i * size * spacing
        else:
            t[..., 0] += x + i * size * spacing
            t[..., 1] += y
        out.append(t)
    return out


def draw(cv, glyphs, text, x, y, size, ink="#ffffff", edge="#140808", edge_w=0.0, halo=None, halo_w=0.0,
         vertical=True, spacing=1.0, neon=0.0, grad=None):
    """Pinta o texto: halo de neon (opcional), contorno grosso (`edge_w`) e a tinta (cor ou degradê vertical `grad`)."""
    parts = layout(glyphs, text, x, y, size, vertical, spacing)
    lay = p.union(cv, [p.tris_layer(cv, t) for t in parts])
    if halo:
        cv.add(p.glow(cv, lay, halo_w), hexc(halo), 1.0, neon=1.0)
    if edge_w > 0:
        cv.fill(p.outline(cv, lay, edge_w), hexc(edge), neon=neon * 0.6)
    if grad:
        X, Y = cv.coords(lay)
        a = lay[0] > 0.5
        y0, y1 = (Y[a].min(), Y[a].max()) if a.any() else (0, 1)
        cv.fill(lay, p.grad_v(Y, y0, y1, grad), neon=neon)
    else:
        cv.fill(lay, hexc(ink), neon=neon)
    return lay
