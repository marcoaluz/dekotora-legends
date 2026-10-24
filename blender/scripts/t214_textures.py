"""Textura de detalhe da estrutura das peças da oficina (T-214): metal escovado com emendas, rebites e desgaste.

Três PNGs 512 x 512 que repetem sem emenda (1 repetição = 0,5 m; as peças têm UV em metros, `build_t211_parts._uv_all`):
  textures/deco_detail_alb.png  cinza (multiplica a cor L/R da peça): veio escovado, emenda escura, riscos claros, sujeira
  textures/deco_detail_nrm.png  normal (convenção OpenGL, a do Godot): veio, emendas em baixo-relevo, rebites em domo
  textures/deco_detail_orm.png  R = oclusão (1), G = rugosidade (multiplica a do material), B = 0
Barato no celular: 3 texturas pequenas compartilhadas por TODAS as peças (o jogo põe nos papéis estrutura e painel,
`game/scripts/truck/deco_style.gd`). Determinístico (semente fixa). Sem Pillow: numpy + imagens do Blender.
"""
from __future__ import annotations

import os

import bpy
import numpy as np

OUT = "game/assets/vehicles/dekotora/textures"
ALB = OUT + "/deco_detail_alb.png"
NRM = OUT + "/deco_detail_nrm.png"
ORM = OUT + "/deco_detail_orm.png"
N = 512
SEED = 214


def _blur_x(a: np.ndarray, k: int) -> np.ndarray:
    """Média móvel circular ao longo de x (repete sem emenda)."""
    out = np.zeros_like(a)
    for d in range(-k, k + 1):
        out += np.roll(a, d, axis=1)
    return out / (2 * k + 1)


def _blur(a: np.ndarray, k: int) -> np.ndarray:
    out = _blur_x(a, k)
    return _blur_x(out.T, k).T


def _save(path: str, rgb: np.ndarray, srgb: bool) -> None:
    h, w = rgb.shape[:2]
    rgba = np.concatenate([rgb, np.ones((h, w, 1), np.float32)], axis=2)[::-1]   # Blender: linha 0 = embaixo
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    img.pixels.foreach_set(np.clip(rgba, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = os.path.abspath(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def make() -> None:
    rng = np.random.default_rng(SEED)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    # veio escovado: ruído por linha, quase constante ao longo de x
    rows = rng.normal(0, 1, (N, N)).astype(np.float32)
    brushed = _blur_x(rows, 24)
    brushed = (brushed - brushed.mean()) / (brushed.std() + 1e-6)
    low = _blur(rng.normal(0, 1, (N, N)).astype(np.float32), 18)
    low = (low - low.mean()) / (low.std() + 1e-6)
    height = 0.25 * brushed
    alb = 0.93 + 0.025 * brushed + 0.02 * low
    rough = 0.85 + 0.06 * brushed + 0.05 * low
    # emendas das chapas: horizontal na linha 0 e vertical na coluna 0 (a cada 0,5 m), em baixo-relevo
    for d, axis in ((np.minimum(yy, N - yy), 0), (np.minimum(xx, N - xx), 1)):
        groove = np.exp(-(d / 2.2) ** 2)
        height -= 2.2 * groove
        alb -= 0.30 * groove
        rough += 0.25 * groove
    # rebites ao longo das emendas (domo de 5 px a cada 64 px, 9 px para dentro da emenda)
    for c in range(0, N, 64):
        for (cx, cy) in ((c + 32, 9), (c + 32, N - 9), (9, c + 32), (N - 9, c + 32)):
            dx = np.minimum(np.abs(xx - cx), N - np.abs(xx - cx))
            dy = np.minimum(np.abs(yy - cy), N - np.abs(yy - cy))
            r2 = (dx ** 2 + dy ** 2) / 25.0
            dome = np.clip(1.0 - r2, 0, 1)
            height += 3.0 * np.sqrt(dome)
            alb += 0.08 * dome - 0.10 * np.exp(-((np.sqrt(r2) - 1.05) / 0.12) ** 2)
            rough -= 0.25 * dome
    # riscos de uso (claros, menos rugosos) e pontinhos de sujeira
    for _ in range(70):
        x0, y0 = rng.uniform(0, N, 2)
        ang = rng.normal(0, 0.25)
        ln = rng.uniform(12, 60)
        t = np.linspace(0, 1, int(ln * 2))
        px = ((x0 + np.cos(ang) * ln * t) % N).astype(int)
        py = ((y0 + np.sin(ang) * ln * t) % N).astype(int)
        alb[py, px] += 0.10
        rough[py, px] -= 0.30
        height[py, px] -= 0.4
    dirt = _blur((rng.random((N, N)) > 0.985).astype(np.float32), 2)
    alb -= 0.5 * dirt
    rough += 0.6 * dirt
    # normal (OpenGL: verde para cima)
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    k = 0.35
    nx, ny, nz = -gx * k, gy * k, np.ones_like(gx)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    nrm = np.stack([nx / ln, ny / ln, nz / ln], 2) * 0.5 + 0.5
    os.makedirs(OUT, exist_ok=True)
    _save(ALB, np.repeat(np.clip(alb, 0.45, 1.0)[..., None], 3, 2), True)
    _save(NRM, nrm.astype(np.float32), False)
    _save(ORM, np.stack([np.ones_like(rough), np.clip(rough, 0.25, 1.0), np.zeros_like(rough)], 2), False)
    print("[t214] texturas de detalhe:", ALB, NRM, ORM)
