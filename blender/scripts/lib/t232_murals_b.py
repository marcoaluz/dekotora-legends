"""Murais da T-232, parte B: tigres e carpas. Mesmas regras da parte A (R: frente à direita; L: frente à esquerda)."""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from . import t232_kit as K
from . import t232_tiger as T
from .paint2d import hexc
from .t232_murals_a import fuji


def _rock(cv, pts, top="#5a4a7a", bot="#1d1430"):
    lay = p.P(cv, pts)
    cv.fill(p.outline(cv, lay, 0.005), hexc("#0a0612"))
    X, Y = cv.coords(lay)
    y0, y1 = min(q[1] for q in pts), max(q[1] for q in pts)
    cv.fill(lay, p.grad_v(Y, y0, y1, [(0, top), (1, bot)]))
    for k in range(4):
        a, b = pts[1 + k % (len(pts) - 2)], pts[2 + k % (len(pts) - 3)]
        cv.fill(p.mul(p.S(cv, [a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + 0.05)], 0.003), 0.6), hexc("#b9a8e0"))


def tora_take(cv, side):
    """Tigre no bambu. R: tigre andando para a frente, rugindo, num bambuzal ao pôr do sol. L: rosto enorme do tigre."""
    flip = side == "L"
    K.sky(cv, [(0, "#2a0f2a"), (0.45, "#b8364a"), (0.8, "#ff9a3c"), (1, "#ffd27a")])
    sx = 2.9 if not flip else 1.1
    K.sun(cv, sx, 0.4, 0.26, top="#fff0a0", bottom="#ff6a2a", ring_col=None)
    K.rays(cv, sx, 0.4, 12, "#ffe3a0", 0.18, 2.0)
    rng = np.random.default_rng(4 if flip else 2)
    for k in range(9):
        x = rng.uniform(0.05, 3.95)
        K.bamboo(cv, x, -0.05, 1.05, rng.uniform(0.018, 0.03), color="#2f7a3a", dark="#0f3a1a", node="#9fd88a")
    for k in range(22):
        K.bamboo_leaf(cv, rng.uniform(0, 4), rng.uniform(0.0, 0.5), rng.uniform(0.06, 0.12), rng.uniform(20, 160))
    if not flip:
        _rock(cv, [(0.9, 1.02), (1.2, 0.83), (1.9, 0.78), (2.7, 0.8), (3.2, 0.9), (3.4, 1.02)])
        T.side(cv, K.Local(cv, 2.05, 0.5, 0.42), "stand", seed=5, mouth=0.7)
    else:
        _rock(cv, [(0.4, 1.02), (0.8, 0.9), (2.5, 0.86), (3.4, 1.02)], top="#4a3a62")
        T.face(cv, K.Local(cv, 1.7, 0.47, 0.52), roar=0.8)
        T.side(cv, K.Local(cv, 3.05, 0.66, 0.2, flip=True), "stand", seed=8, mouth=0.0)
    for k in range(10):
        K.bamboo_leaf(cv, rng.uniform(0, 4), rng.uniform(0.75, 1.0), rng.uniform(0.07, 0.13), rng.uniform(-160, -20))
    K.border(cv, "#ff9a3c", "#3ff0a0")


def tora_yuki(cv, side):
    """Tigre na neve. R: tigre saltando sob a lua cheia. L: tigre de tocaia sob o pinheiro nevado e o Fuji."""
    flip = side == "L"
    K.sky(cv, [(0, "#050a26"), (0.55, "#1c2f78"), (1, "#5a7fd0")])
    K.stars(cv, 70, 41 + flip)
    K.moon(cv, 0.75 if flip else 3.25, 0.3, 0.2, halo="#9fd0ff")
    if flip:
        fuji(cv, 2.6, 0.84, 0.8, 0.4, body="#2a3a8a", snow="#f4f8ff")
    win, X, Y = cv.win(0, 0.78, 4, 1)
    cv.fill((np.clip((Y - (0.82 + 0.03 * np.sin(X * 3.0))) * 60, 0, 1), win),
            p.grad_v(Y, 0.78, 1, [(0, "#eaf2ff"), (1, "#9fb8ef")]))
    _pine(cv, 3.55 if flip else 0.45, flip)
    if not flip:
        T.side(cv, K.Local(cv, 2.0, 0.42, 0.42), "leap", seed=9, mouth=0.8)
    else:
        T.side(cv, K.Local(cv, 1.45, 0.52, 0.36, flip=True), "stand", seed=12, mouth=0.4)
    K.snow(cv, 220, 7 + flip)
    K.border(cv, "#9fd0ff", "#ffffff")


def _pine(cv, x, flip):
    s = -1 if flip else 1
    trunk = p.P(cv, [(x - 0.05, 1.02), (x + 0.05, 1.02), (x + 0.03 + 0.1 * s, 0.4), (x + 0.15 * s, 0.1), (x + 0.1 * s, 0.1),
                     (x - 0.02 + 0.05 * s, 0.42)])
    cv.fill(p.outline(cv, trunk, 0.004), hexc("#120a06"))
    cv.fill(trunk, hexc("#5a3a22"))
    for k, (dx, dy, w) in enumerate(((0.35, 0.18, 0.3), (0.05, 0.08, 0.22), (0.45, 0.38, 0.33), (0.0, 0.32, 0.2), (0.3, 0.58, 0.26))):
        cx, cy = x + dx * s, dy
        pad = p.E(cv, cx, cy, w, w * 0.22)
        cv.fill(p.outline(cv, pad, 0.004), hexc("#06210f"))
        cv.fill(pad, hexc("#1f6a3a"))
        cv.fill(p.E(cv, cx, cy - w * 0.12, w * 0.92, w * 0.12), hexc("#f4f8ff"))


def koi(cv, side):
    """Carpas. R: carpa vermelha subindo a cachoeira (koi-nobori). L: duas carpas em círculo num lago com nenúfares."""
    from . import t232_koi as KO
    if side == "R":
        K.sky(cv, [(0, "#0a1a3a"), (0.5, "#1f4fa0"), (1, "#7fc8ff")])
        win, X, Y = cv.win(2.2, 0, 3.6, 1)
        fall = np.clip(1 - np.abs(X - 2.9) / 0.7, 0, 1)
        n = p.vnoise(X * 0.6, Y * 8, 0.2, seed=3)
        cv.fill((fall ** 0.5, win), p.mix(hexc("#bfe8ff"), hexc("#ffffff"), (n > 0.55)[..., None].astype(np.float32)))
        _rock(cv, [(1.9, 1.02), (2.0, 0.0), (2.25, -0.02), (2.2, 1.02)], top="#3a4a7a", bot="#101a3a")
        _rock(cv, [(3.6, 1.02), (3.55, -0.02), (3.8, 0.0), (3.9, 1.02)], top="#3a4a7a", bot="#101a3a")
        K.water_band(cv, 0.84, "#2f7fe0", "#0a2a6b", crest="#ffffff")
        for x, y in ((2.5, 0.85), (3.2, 0.88), (2.85, 0.8)):
            K.ruyi(cv, x, y, 0.09, fill="#ffffff", line="#2a5aa0", tail=0)
        KO.koi(cv, K.Local(cv, 2.9, 0.45, 0.42, rot=-80), "red")
        KO.koi(cv, K.Local(cv, 1.1, 0.62, 0.36, rot=-12), "gold")
        for x, y in ((0.4, 0.3), (0.7, 0.18), (1.5, 0.25)):
            K.sakura(cv, x, y, 0.035)
    else:
        win, X, Y = cv.full()
        cv.rgb[...] = p.grad_v(Y, 0, 1, [(0, "#06264a"), (0.6, "#0d4a7a"), (1, "#062a4a")])
        for k in range(6):
            cv.fill(p.mul(p.ring(cv, 1.6, 0.5, 0.15 + k * 0.12, 0.004), 0.5), hexc("#7fd8ff"))
        for x, y, r in ((0.5, 0.3, 0.12), (3.2, 0.75, 0.15), (3.6, 0.25, 0.1), (0.8, 0.8, 0.1)):
            KO.lily(cv, x, y, r)
        KO.koi(cv, K.Local(cv, 1.6, 0.32, 0.36, flip=True, rot=10), "red")
        KO.koi(cv, K.Local(cv, 1.6, 0.68, 0.36, rot=10), "white")
        KO.koi(cv, K.Local(cv, 2.7, 0.45, 0.28, flip=True, rot=-10), "gold")
    K.border(cv, "#ff4f6a", "#3ff0ff")
