"""Pintura do teto da T-232: as 9 frases do Marco em caligrafia de pincel (Yuji Syuku) escritas na VERTICAL ao longo
do teto (o alto da imagem fica para a frente do caminhão: a câmera da corrida, atrás e acima, lê de pé), sobre um fundo
pintado. Duas proporções por frase: comprida (1:4, baús médio/longo) e curta (1:2, leve e Canter); o jogo escolhe a
mais parecida com o teto e corta no máximo ~10% das pontas, que ficam livres.
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from . import t232_kit as K
from . import t232_text as TX
from . import t232_texts as TT
from .paint2d import hexc

# fundo de cada frase: (degradê, enfeite, tinta, contorno, halo)
STYLE = [
    ([(0, "#05061e"), (1, "#2a1a6b")], "stars", "#fff4a0", "#1d1450", "#ffe14a"),     # 一番星
    ([(0, "#2a0b3a"), (1, "#a3245a")], "sakura", "#ffffff", "#8a0f30", "#ff6fae"),    # 男花道
    ([(0, "#14060a"), (1, "#5a0f14")], "flames", "#ffe14a", "#3a0606", "#ff7a1a"),    # 爆走
    ([(0, "#0a0418"), (1, "#3a1a6b")], "lightning", "#ffffff", "#3a0a8a", "#b46cff"),  # 御意見無用
    ([(0, "#3a1a06"), (1, "#7a4a0a")], "clouds", "#fff4c0", "#3a1a06", "#ffd25c"),    # 唯我独尊
    ([(0, "#06122a"), (1, "#1b4fb3")], "waves", "#ffffff", "#0a2a6b", "#3ff0ff"),     # 義理人情
    ([(0, "#2a0b4a"), (0.6, "#c2346a"), (1, "#ff9a5a")], "road", "#ffffff", "#5a0f3a", "#ff4fb4"),   # 浪漫街道
    ([(0, "#fff4e0"), (1, "#ffd9a0")], "sun", "#141018", "#ffffff", "#e8202c"),       # 天下御免
    ([(0, "#0a0626"), (0.55, "#6a2a8a"), (1, "#ffb37a")], "dawn", "#ffffff", "#3a0a5a", "#ffd25c"),  # 夜明けまで
]
ASPECTS = {"long": 0.25, "short": 0.5}


def _deco(cv, kind):
    a = cv.aspect
    if kind == "stars":
        K.stars(cv, 70, 1, 1.0)
        for y in (0.08, 0.92):
            star = [(a / 2 + math.cos(math.radians(-90 + k * 36)) * (0.07 if k % 2 == 0 else 0.03) * min(1, a * 4),
                     y + math.sin(math.radians(-90 + k * 36)) * (0.07 if k % 2 == 0 else 0.03) * min(1, a * 4)) for k in range(10)]
            lay = p.P(cv, star)
            cv.add(p.glow(cv, lay, 0.02), hexc("#ffe14a"), 1.0, neon=1.0)
            cv.fill(lay, hexc("#fff4a0"), neon=1.0)
    elif kind == "sakura":
        K.petals(cv, int(60 * a * 4), 2, (0, 0, a, 1))
        rng = np.random.default_rng(3)
        for _ in range(int(10 * a * 4)):
            K.sakura(cv, rng.uniform(0, a), rng.uniform(0, 1), rng.uniform(0.02, 0.035), line="#8a0f30")
    elif kind == "flames":
        K.flames(cv, [(0, 1.02), (a, 1.02)], 0.25, seed=5, n=5)
        K.flames(cv, [(a, -0.02), (0, -0.02)], -0.0001, seed=6, n=2, colors=("#ff7a1a",), line=None)
        win, X, Y = cv.full()
        cv.fill(((np.sin(Y * 90) > 0.6) * np.clip(np.abs(X - a / 2) / (a / 2) - 0.75, 0, 1) * 2.0, win), hexc("#ff7a1a"))
    elif kind == "lightning":
        for k, x0 in enumerate((a * 0.15, a * 0.85)):
            pts = [(x0, 0.0)] + [(x0 + (0.03 if j % 2 else -0.03) * min(1, a * 4), 0.1 * (j + 1)) for j in range(10)]
            K.lightning(cv, pts, "#c9a7ff", 0.004)
    elif kind == "clouds":
        for k, y in enumerate(np.linspace(0.06, 0.94, 6)):
            K.ruyi(cv, a * (0.25 if k % 2 else 0.75), y, 0.05 * min(1, a * 4) + 0.02, fill="#ffe08a", line="#7a3a06",
                   shade="#e8a21a", tail=0.3, flip=k % 2 == 1)
    elif kind == "waves":
        K.seigaiha(cv, 0.0, 1.0, 0.035 * min(1, a * 4) + 0.01, colors=("#f2f6ff", "#2f6fd0", "#f2f6ff", "#122a6b"))
        win, X, Y = cv.full()
        cv.fill((np.clip(1 - np.abs(X - a / 2) / (a * 0.32), 0, 1) ** 0.6 * 0.75, win), hexc("#0a1f5c"))
    elif kind == "road":
        win, X, Y = cv.full()
        for k in range(3):
            x = a * (0.2 + 0.3 * k)
            cv.fill((((np.abs(X - x) < 0.006) & ((Y * 12) % 1 < 0.55)).astype(np.float32), win), hexc("#ffd25c"))
        for y in np.linspace(0.04, 0.96, 12):
            for x in (a * 0.07, a * 0.93):
                cv.add(p.glow(cv, p.C(cv, x, y, 0.008), 0.012), hexc("#ff4fb4"), 1.2, neon=1.0)
    elif kind == "sun":
        K.rays(cv, a / 2, 0.5, 18, "#e8202c", 0.85, 3.0)
        K.sun(cv, a / 2, 0.5, a * 0.42, top="#ff3a3a", bottom="#c0102a", ring_col=None)
        win, X, Y = cv.full()
        cv.fill((np.clip(1 - np.abs(X - a / 2) / (a * 0.3), 0, 1) ** 0.5 * 0.8, win), hexc("#fff4e0"))
    elif kind == "dawn":
        K.stars(cv, 40, 9, 0.45)
        K.sun(cv, a / 2, 1.02, a * 0.45, top="#fff4a0", bottom="#ff6a2a", ring_col=None)


def make(cv, idx, glyphs):
    """Desenha o teto `idx` (0..8) numa tela de proporção 0,25 (comprida) ou 0,5 (curta)."""
    grad, deco, ink, edge, halo = STYLE[idx]
    K.sky(cv, grad)
    _deco(cv, deco)
    txt = TT.ROOF[idx]
    a = cv.aspect
    n = len(txt)
    size = min(a * 0.78, 0.76 / n)
    y0 = 0.5 - size * (n - 1) / 2
    TX.draw(cv, glyphs, txt, a / 2, y0, size, ink=ink, edge=edge, edge_w=size * 0.07, halo=halo, halo_w=size * 0.06, neon=0.7)
    K.frame(cv, color="#f2c14e", w=0.006 if a < 0.3 else 0.008)
