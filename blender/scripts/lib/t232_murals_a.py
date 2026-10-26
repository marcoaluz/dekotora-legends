"""Murais da T-232, parte A: dragões e ondas. Cada mural tem DUAS artes (lado direito "R" e esquerdo "L", diferentes).
No lado direito a frente do caminhão fica à DIREITA da imagem; no esquerdo, à ESQUERDA: as figuras olham para a frente.
Arte 2048 x 512 (4:1); o jogo corta até ~10% das bordas conforme o baú (PaintFit), então nada importante fica nelas.
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from . import t232_dragon as D
from . import t232_kit as K
from .paint2d import hexc


def ryu_kumo(cv, side):
    """Dragão nas nuvens. R: noite de lua cheia, dragão verde correndo para a pérola. L: tempestade com raios."""
    if side == "R":
        K.sky(cv, [(0, "#090826"), (0.45, "#22175e"), (1, "#5b2a8c")])
        K.stars(cv, 90, 11)
        K.moon(cv, 3.25, 0.32, 0.2)
        K.rays(cv, 3.25, 0.32, 18, "#8f7bff", 0.12, 2.2)
        for x, y, s in ((0.45, 0.78, 0.16), (1.3, 0.22, 0.13), (2.35, 0.86, 0.15)):
            K.ruyi(cv, x, y, s, line="#2a2a6b")
        D.dragon(cv, [(0.22, 0.86), (0.55, 0.5), (1.05, 0.66), (1.55, 0.36), (2.1, 0.56), (2.6, 0.34), (2.95, 0.42)],
                 0.075, D.GREEN, -12, pearl_at=(3.62, 0.62))
        for x, y, s in ((1.05, 0.82, 0.14), (2.05, 0.18, 0.12)):
            K.ruyi(cv, x, y, s, line="#2a2a6b", tail=0.6)
        K.petals(cv, 25, 3, (0.2, 0.1, 3.9, 0.9), "#d9c8ff")
    else:
        K.sky(cv, [(0, "#14061e"), (0.5, "#3d0f3f"), (1, "#8a1f3a")])
        rng = np.random.default_rng(5)
        win, X, Y = cv.full()
        cv.fill((((np.sin(X * 140 + Y * 40) > 0.97) * 0.35).astype(np.float32), win), hexc("#c7b8ff"))   # chuva
        for k, x0 in enumerate((0.55, 2.2, 3.5)):
            pts = [(x0, 0.0)]
            for j in range(6):
                pts.append((pts[-1][0] + rng.uniform(-0.1, 0.1), pts[-1][1] + 0.16))
            K.lightning(cv, pts, "#d8c4ff", 0.006)
        for x, y, s in ((3.3, 0.8, 0.16), (2.4, 0.2, 0.13), (0.9, 0.86, 0.15)):
            K.ruyi(cv, x, y, s, fill="#d9d2ff", line="#1d1440", flip=True, shade="#8f86c9")
        D.dragon(cv, [(3.85, 0.3), (3.4, 0.6), (2.9, 0.38), (2.4, 0.65), (1.85, 0.42), (1.3, 0.62), (1.0, 0.5)],
                 0.075, D.GREEN, 200, pearl_at=(0.42, 0.42))
        for x, y, s in ((2.7, 0.86, 0.13), (1.6, 0.16, 0.12)):
            K.ruyi(cv, x, y, s, fill="#d9d2ff", line="#1d1440", flip=True, shade="#8f86c9", tail=0.6)
    K.border(cv, "#b46cff", "#3ff0a0")


def ryu_nami(cv, side):
    """Dragão e ondas. R: dragão azul sai do mar para o sol vermelho. L: dragão dourado sobre redemoinho e Fuji."""
    if side == "R":
        K.sky(cv, [(0, "#1a0b3a"), (0.5, "#a3245a"), (0.8, "#ff8a4c"), (1, "#ffc27a")])
        K.rays(cv, 3.1, 0.55, 14, "#ffd36b", 0.25, 2.4)
        K.sun(cv, 3.1, 0.5, 0.3)
        K.wave_crest(cv, K.Local(cv, -0.05, 0.12, 0.88), neon="#3ff0ff")
        D.dragon(cv, [(0.9, 0.98), (1.15, 0.6), (1.6, 0.78), (2.05, 0.42), (2.45, 0.62), (2.75, 0.36), (3.0, 0.3)],
                 0.075, D.BLUE, -25, pearl_at=(3.1, 0.5))
        K.water_band(cv, 0.86)
        K.wave_crest(cv, K.Local(cv, 2.3, 0.62, 0.42, flip=True), neon=None)
    else:
        K.sky(cv, [(0, "#0b1a3a"), (0.55, "#2c5a9a"), (1, "#9fd0ff")])
        K.stars(cv, 40, 21, 0.3)
        fuji(cv, 0.75, 0.86, 0.95, 0.5)
        _whirl(cv, 1.9, 0.86, 0.9)
        D.dragon(cv, [(3.7, 0.95), (3.3, 0.55), (2.8, 0.75), (2.35, 0.4), (1.9, 0.55), (1.45, 0.3), (1.2, 0.28)],
                 0.075, D.GOLD, 195, pearl_at=(0.4, 0.3))
        K.water_band(cv, 0.88, "#1b5fc3", "#061a4a")
    K.border(cv, "#3ff0ff", "#ffd25c")


def fuji(cv, cx, base_y, half_w, height, body="#3b2a78", snow="#f4f1ff"):
    top = base_y - height
    cv.fill(p.P(cv, [(cx - half_w, base_y), (cx - half_w * 0.12, top + height * 0.04), (cx, top), (cx + half_w * 0.12, top + height * 0.04),
                     (cx + half_w, base_y)]), hexc(body))
    sx = half_w * 0.36
    sy = top + height * 0.33
    zig = [(cx - sx, sy)]
    for k in range(6):
        zig.append((cx - sx + (k + 0.5) * sx / 3, sy + (0.05 if k % 2 == 0 else -0.01) * height))
    zig.append((cx + sx, sy))
    cv.fill(p.P(cv, [(cx - half_w * 0.12, top + height * 0.04), (cx, top), (cx + half_w * 0.12, top + height * 0.04)] + zig[::-1]),
            hexc(snow))


def _whirl(cv, cx, cy, r):
    """Redemoinho (espiral de faixas azuis e espuma), achatado em perspectiva."""
    for k in range(5):
        pts = []
        for t in np.linspace(0, 4.6, 90):
            rr = r * (1 - t / 5.2) * (1 - k * 0.12)
            a = t * 2.2 + k * 1.25
            pts.append((cx + math.cos(a) * rr, cy - 0.04 + math.sin(a) * rr * 0.28))
        cv.fill(p.S(cv, pts, 0.012), hexc("#0f3a8a"))
        cv.fill(p.S(cv, pts, 0.006), hexc("#9fd8ff"))


def nami_fuji(cv, side):
    """Grande onda e Fuji. R: a onda enorme quebrando sobre o Fuji ao amanhecer. L: ondas de noite com redemoinhos e lua."""
    if side == "R":
        K.sky(cv, [(0, "#2a0b4a"), (0.4, "#c2346a"), (0.75, "#ff9a5a"), (1, "#ffd9a0")])
        K.rays(cv, 2.6, 0.75, 16, "#ffe3a0", 0.22, 2.6)
        K.sun(cv, 2.6, 0.62, 0.22, ring_col="#ff4fb4")
        fuji(cv, 2.6, 0.9, 0.85, 0.42)
        K.wave_crest(cv, K.Local(cv, -0.1, 0.0, 1.1), neon="#3ff0ff")
        K.seigaiha(cv, 0.86, 1.0, 0.07, x0=1.6)
        K.wave_crest(cv, K.Local(cv, 3.9, 0.45, 0.5, flip=True), neon="#3ff0ff")
        _boats(cv, [(1.5, 0.78, 8), (1.85, 0.84, -6)])
        for x, y in ((3.35, 0.2), (3.55, 0.3), (3.2, 0.12)):
            K.sakura(cv, x, y, 0.035)
    else:
        K.sky(cv, [(0, "#05061e"), (0.6, "#14286b"), (1, "#2e5fb0")])
        K.stars(cv, 110, 33, 0.5)
        K.moon(cv, 0.75, 0.3, 0.18)
        fuji(cv, 2.1, 0.88, 0.75, 0.36, body="#22205a", snow="#dfe8ff")
        _whirl(cv, 1.0, 0.92, 0.75)
        _whirl(cv, 2.9, 0.9, 0.6)
        K.wave_crest(cv, K.Local(cv, 4.1, 0.05, 1.05, flip=True), colors=("#3d58d8", "#0a1550"), neon="#b46cff")
        K.water_band(cv, 0.9, "#1b3fa3", "#050f3a")
    K.border(cv)


def _boats(cv, boats):
    """Barcos compridos (oshiokuri) com remadores, como pontinhos escuros, no vale das ondas."""
    for x, y, rot in boats:
        L = K.Local(cv, x, y, 0.3, rot=rot)
        hull = L.P([(-0.6, 0.0), (0.6, -0.05), (0.55, 0.04), (-0.55, 0.07)])
        cv.fill(hull, hexc("#f3e2b0"))
        cv.fill(p.outline(cv, hull, 0.002), hexc("#3a2400"))
        for k in range(7):
            cv.fill(L.E(-0.45 + k * 0.15, -0.035, 0.03, 0.03), hexc("#14122a"))
