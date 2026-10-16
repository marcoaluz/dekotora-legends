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


def grime_panel(name: str = "tex_grime", w: int = 512, h: int = 256, seed: int = 7):
    """Sujeira discreta para chapa pintada (multiplica a cor): escurece a parte de baixo (poeira da estrada),
    riscos de água escorrendo de cima e pontinhos de uso. Valores 0,82..1,0 (nunca preto)."""
    rng = np.random.default_rng(seed)
    v = np.linspace(0, 1, h)[:, None]                       # 0 = embaixo, 1 = em cima
    grime = 0.16 * np.clip(1 - v / 0.35, 0, 1) ** 1.5       # poeira na barra inferior
    streaks = np.zeros((h, w))
    for _ in range(26):                                     # riscos verticais
        x = rng.integers(0, w)
        wd = rng.integers(1, 4)
        top = rng.uniform(0.5, 1.0)
        a = rng.uniform(0.02, 0.07)
        y1 = int((1 - top) * h)
        y0 = int(h * rng.uniform(0.0, 0.5))
        ramp = np.linspace(a, 0, max(h - y1 - y0, 1))
        streaks[y1:h - y0, x:x + wd] += ramp[:, None][: streaks[y1:h - y0, x:x + wd].shape[0]]
    speck = np.clip(rng.normal(0, 1, (h, w)), 1.6, 4) - 1.6   # arranhoes/pontinhos raros
    speck = (speck > 0.9) * 0.05
    val = np.clip(1.0 - grime - streaks - speck, 0.78, 1.0)
    return _image(name, np.repeat(val[..., None], 3, axis=2))


def concrete(name: str = "tex_concrete", size: int = 512, seed: int = 11):
    """Concreto polido repetível: ruído suave em várias escalas + manchas leves e juntas de dilatação."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size))
    for k, amp in ((8, 0.5), (32, 0.3), (128, 0.2)):          # ruído de valor em 3 escalas (repetível)
        g = rng.random((k, k))
        idx = np.arange(size) * k / size
        i0 = np.floor(idx).astype(int)
        f = idx - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % k
        row = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
        row2 = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
        acc += amp * (row * (1 - f)[:, None] + row2 * f[:, None])
    val = 0.42 + 0.16 * (acc - acc.mean())
    val[:3, :] *= 0.75                                        # junta de dilatação nas bordas do ladrilho
    val[:, :3] *= 0.75
    val += (rng.random((size, size)) - 0.5) * 0.025           # granulado fino
    return _image(name, np.repeat(np.clip(val, 0, 1)[..., None], 3, axis=2) * np.array([1.0, 1.0, 1.04]))


def corrugated(name: str = "tex_corrugated", w: int = 256, h: int = 64, waves: int = 8):
    """Chapa ondulada (parede do galpão): faixas claras/escuras verticais, repetível na horizontal."""
    x = np.linspace(0, waves * 2 * np.pi, w, endpoint=False)
    band = 0.5 + 0.5 * np.sin(x)
    base = np.array(hex_to_rgb("#3a4150"))
    hi = np.array(hex_to_rgb("#6c7686"))
    arr = base * (1 - band[None, :, None]) + hi * band[None, :, None]
    return _image(name, np.repeat(arr, h, axis=0))


def hazard(name: str = "tex_hazard", w: int = 256, h: int = 32):
    """Faixa zebrada amarelo/preto (piso de oficina)."""
    yy, xx = np.mgrid[0:h, 0:w]
    s = ((xx + yy) // 16) % 2
    y = np.array(hex_to_rgb("#e8b512"))
    k = np.array(hex_to_rgb("#16161a"))
    arr = y * (1 - s[..., None]) + k * s[..., None]
    return _image(name, arr)
