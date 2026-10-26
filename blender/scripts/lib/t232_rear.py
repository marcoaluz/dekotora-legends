"""Pintura da traseira da T-232 ("focada no rosto", arte SEPARADA do mural, decisão 8 do Marco): 12 artes 640 x 512
(5:4, a proporção das portas do baú). Rosto grande no meio, kanji vertical dos dois lados, a fresta das portas pintada no
meio (as ferragens de verdade ficam na frente da pintura). Nada importante nos 6% das bordas (o jogo corta conforme o baú).
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from . import t232_birds as B
from . import t232_dragon as D
from . import t232_faces as F
from . import t232_figures as G
from . import t232_kit as K
from . import t232_koi as KO
from . import t232_text as TX
from . import t232_texts as TT
from . import t232_tiger as T
from .paint2d import hexc

ASPECT = 1.25
ORDER = ["ryu", "tora", "hannya", "oni", "kitsune", "tengu", "noh", "kabuki", "bijin", "shishi", "hoo", "koi"]
# (texto, contorno, halo) dos kanji de cada traseira
INK = {"ryu": ("#ffffff", "#0e4a3a", "#3ff0a0"), "tora": ("#ffe14a", "#3a0e00", "#ff9a3c"),
       "hannya": ("#fff4c0", "#3a0a5a", "#b46cff"), "oni": ("#ffffff", "#7a0a14", "#ff4f3a"),
       "kitsune": ("#ffffff", "#c0102a", "#ff4f6a"), "tengu": ("#ffffff", "#5a0610", "#ffb347"),
       "noh": ("#2a1a10", "#f2c14e", "#ffd25c"), "kabuki": ("#ffffff", "#c0102a", "#ff4fb4"),
       "bijin": ("#ffffff", "#8a0f50", "#ff6fae"), "shishi": ("#ffffff", "#8a0a14", "#ff4f6a"),
       "hoo": ("#fff4a0", "#7a1a06", "#ffb347"), "koi": ("#ffffff", "#0a2a6b", "#3ff0ff")}


def _bg(cv, kind):
    a = ASPECT
    if kind in ("ryu",):
        K.sky(cv, [(0, "#06122a"), (0.6, "#14406b"), (1, "#2a7a8a")])
        K.rays(cv, a / 2, 0.45, 14, "#7ff0c0", 0.12, 1.2)
        for x, y, s in ((0.15, 0.8, 0.08), (1.1, 0.85, 0.08), (0.95, 0.15, 0.06)):
            K.ruyi(cv, x, y, s, tail=0.3)
    elif kind == "tora":
        K.sky(cv, [(0, "#2a0f2a"), (0.5, "#b8364a"), (1, "#ffb347")])
        K.rays(cv, a / 2, 0.55, 16, "#ffe3a0", 0.2, 1.2)
        rng = np.random.default_rng(91)
        for k in range(10):
            K.bamboo_leaf(cv, rng.uniform(0, a), rng.uniform(0, 1), rng.uniform(0.06, 0.1), rng.uniform(0, 360))
    elif kind in ("hannya",):
        K.sky(cv, [(0, "#0a0418"), (0.6, "#2a0a4a"), (1, "#5a0a3a")])
        K.flames(cv, [(0.0, 1.02), (a, 1.02)], 0.3, seed=12, n=10, colors=("#c9a7ff", "#7a3aff", "#3a0a8a"))
    elif kind == "oni":
        K.sky(cv, [(0, "#14060a"), (0.6, "#5a0f14"), (1, "#c2361a")])
        K.flames(cv, [(0.0, 1.02), (a, 1.02)], 0.35, seed=13, n=10)
    elif kind == "kitsune":
        K.sky(cv, [(0, "#05051a"), (0.6, "#2a0a3a"), (1, "#5a0f3a")])
        for x in (0.12, a - 0.12):                                  # pilares de torii
            cv.fill(p.P(cv, [(x - 0.035, 0.0), (x + 0.035, 0.0), (x + 0.04, 1.0), (x - 0.04, 1.0)]), hexc("#d61f36"))
        cv.fill(p.P(cv, [(0, 0.06), (a, 0.06), (a, 0.12), (0, 0.12)]), hexc("#d61f36"))
        cv.fill(p.P(cv, [(0, 0.02), (a, 0.02), (a, 0.05), (0, 0.05)]), hexc("#141018"))
        for x in (0.3, a - 0.3):
            lay = p.E(cv, x, 0.2, 0.04, 0.05)
            cv.add(p.glow(cv, lay, 0.03), hexc("#ff7a3a"), 0.9, neon=0.8)
            cv.fill(lay, hexc("#ffb03a"), neon=0.9)
    elif kind == "tengu":
        K.sky(cv, [(0, "#0a1a3a"), (0.5, "#2a4a8a"), (1, "#c2a0d0")])
        cv.fill(p.P(cv, [(0, 1.0), (0.3, 0.55), (0.55, 0.75), (0.8, 0.45), (a, 0.8), (a, 1.0)]), hexc("#1d2a5a"))
        for x, y, s in ((0.2, 0.3, 0.07), (1.05, 0.25, 0.06)):
            K.ruyi(cv, x, y, s, tail=0.3)
    elif kind == "noh":
        win, X, Y = cv.full()
        cv.rgb[...] = p.grad_v(Y, 0, 1, [(0, "#f6d27a"), (1, "#c98a1a")])
        n = p.vnoise(X, Y, 0.05, seed=5)
        cv.rgb[...] *= (0.9 + 0.12 * n)[..., None]
        for x, y, w in ((0.25, 0.25, 0.25), (0.95, 0.2, 0.22), (0.6, 0.12, 0.3)):            # pinheiro do palco
            pad = p.E(cv, x, y, w, w * 0.25)
            cv.fill(p.outline(cv, pad, 0.004), hexc("#06210f"))
            cv.fill(pad, hexc("#1f6a3a"))
    elif kind in ("kabuki", "shishi"):
        K.sky(cv, [(0, "#1a0a2a"), (0.6, "#5a0f3a"), (1, "#c2245a")])
        K.rays(cv, a / 2, 0.5, 18, "#ff9ac0", 0.2, 1.2)
        if kind == "shishi":
            from .t232_murals_c import peony
            for x, y, r in ((0.15, 0.85, 0.12), (a - 0.15, 0.85, 0.12), (0.12, 0.25, 0.08), (a - 0.12, 0.25, 0.08)):
                peony(cv, x, y, r)
        else:
            K.petals(cv, 40, 95, (0, 0, a, 1))
    elif kind == "bijin":
        K.sky(cv, [(0, "#0a0626"), (0.6, "#3a1a6b"), (1, "#8a3a8a")])
        K.moon(cv, a / 2, 0.38, 0.32, halo="#ffd9f0")
        K.petals(cv, 50, 96, (0, 0, a, 1))
    elif kind == "hoo":
        K.sky(cv, [(0, "#3a0a2a"), (0.5, "#c2245a"), (1, "#ffe08a")])
        K.rays(cv, a / 2, 0.5, 18, "#fff0a0", 0.25, 1.3)
        K.sun(cv, a / 2, 0.5, 0.3, top="#fff4a0", bottom="#ff6a2a", ring_col="#ffd25c")
    elif kind == "koi":
        win, X, Y = cv.full()
        cv.rgb[...] = p.grad_v(Y, 0, 1, [(0, "#06264a"), (1, "#0d4a7a")])
        for k in range(5):
            cv.fill(p.mul(p.ring(cv, a / 2, 0.5, 0.12 + k * 0.1, 0.003), 0.5), hexc("#7fd8ff"))
        for x, y, r in ((0.12, 0.85, 0.07), (a - 0.12, 0.12, 0.06)):
            KO.lily(cv, x, y, r)


def _figure(cv, kind):
    a = ASPECT
    c = a / 2
    if kind == "ryu":
        D.head(cv, c - 0.22, 0.56, 0.4, -10, D.GREEN, mouth=0.35)
        D.pearl(cv, c + 0.12, 0.2, 0.05, flame="#3ff0a0")
    elif kind == "tora":
        T.face(cv, K.Local(cv, c, 0.47, 0.5), roar=0.85)
    elif kind == "hannya":
        F.hannya(cv, K.Local(cv, c, 0.58, 0.37))
    elif kind == "oni":
        F.oni(cv, K.Local(cv, c, 0.55, 0.42))
    elif kind == "kitsune":
        F.kitsune(cv, K.Local(cv, c, 0.55, 0.42))
    elif kind == "tengu":
        F.tengu(cv, K.Local(cv, c, 0.5, 0.4))
    elif kind == "noh":
        F.noh(cv, K.Local(cv, c, 0.5, 0.48))
    elif kind == "kabuki":
        F.kabuki(cv, K.Local(cv, c, 0.55, 0.45))
    elif kind == "shishi":
        F.kabuki(cv, K.Local(cv, c, 0.36, 0.36), mane="#e8243a", paint_col="#1a1a1a")
    elif kind == "bijin":
        G.bijin(cv, K.Local(cv, c, 0.36, 0.42), hair="updo", seed=11)
    elif kind == "hoo":
        B.phoenix(cv, K.Local(cv, c + 0.18, 0.6, 0.33))
    elif kind == "koi":
        KO.koi(cv, K.Local(cv, c, 0.32, 0.28, flip=True, rot=-12), "red")
        KO.koi(cv, K.Local(cv, c, 0.7, 0.28, rot=-12), "white")


def make(cv, kind, glyphs):
    """Desenha a traseira `kind` (ORDER) numa tela de proporção ASPECT."""
    _bg(cv, kind)
    _figure(cv, kind)
    left, right = TT.REAR[kind]
    ink, edge, halo = INK[kind]
    # kanji no alto: embaixo, nas quinas, ficam as colunas de lanternas de fábrica; fora dos 7% que o baú mais estreito corta
    for txt, x in ((left, 0.2), (right, ASPECT - 0.2)):
        n = len(txt)
        size = min(0.16, 0.46 / n)
        y0 = 0.08 + size * 0.5
        TX.draw(cv, glyphs, txt, x, y0, size, ink=ink, edge=edge, edge_w=0.012, halo=halo, halo_w=0.008, neon=0.6)
    # fresta das portas (o meio) e moldura dourada
    cv.fill(p.mul(p.S(cv, [(ASPECT / 2, 0.0), (ASPECT / 2, 1.0)], 0.0022), 0.85), hexc("#0a0606"))
    cv.fill(p.mul(p.S(cv, [(ASPECT / 2 + 0.004, 0.0), (ASPECT / 2 + 0.004, 1.0)], 0.0012), 0.5), hexc("#ffffff"))
    K.frame(cv, w=0.01)
