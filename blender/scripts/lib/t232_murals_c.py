"""Murais da T-232, parte C: kabuki, guerreiro, mulheres de quimono, fênix/grous e máscaras.
Mesmas regras da parte A (R: frente à direita; L: frente à esquerda; nada importante nos 10% das bordas)."""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from . import t232_birds as B
from . import t232_faces as F
from . import t232_figures as G
from . import t232_kit as K
from .paint2d import hexc
from .t232_murals_a import fuji


def peony(cv, x, y, r, color="#ff5a8a", dark="#b8124a", leaf="#2f8a4a"):
    """Peônia (botan): pétalas em camadas, a flor do leão do kabuki."""
    for k in range(5):
        a = math.radians(k * 72 + 20)
        K.bamboo_leaf(cv, x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.8, r * 1.1, math.degrees(a), leaf, "#145a26")
    for ring_, n, rr in ((1.0, 9, 0.42), (0.7, 7, 0.36), (0.42, 5, 0.3)):
        for k in range(n):
            a = k * math.tau / n + ring_
            pe = p.E(cv, x + math.cos(a) * r * ring_ * 0.6, y + math.sin(a) * r * ring_ * 0.6, r * rr, r * rr * 0.75, a)
            cv.fill(p.outline(cv, pe, 0.002), hexc(dark))
            K.paint(cv, pe, color, dark, width=r * 0.25)
    cv.fill(p.C(cv, x, y, r * 0.15), hexc("#ffe14a"))


def kabuki(cv, side):
    """Kabuki. R: ator com kumadori vermelho, sakura e raios. L: leão do kabuki (juba branca) entre peônias."""
    if side == "R":
        K.sky(cv, [(0, "#1a0a2a"), (0.5, "#5a0f3a"), (1, "#c2245a")])
        K.rays(cv, 2.6, 0.5, 20, "#ff9ac0", 0.18, 2.4)
        K.seigaiha(cv, 0.86, 1.0, 0.06, colors=("#ffd1e6", "#c2245a", "#ffd1e6", "#5a0f3a"))
        for x, y, s in ((0.6, 0.3, 0.12), (1.3, 0.75, 0.1), (3.6, 0.7, 0.12)):
            K.ruyi(cv, x, y, s, fill="#ffe6f0", line="#5a0f3a", shade="#e8a0c0")
        F.kabuki(cv, K.Local(cv, 2.6, 0.5, 0.42))
        K.petals(cv, 60, 31, (0.1, 0.05, 3.9, 0.85))
        for x, y in ((0.35, 0.6), (1.6, 0.3), (3.45, 0.25), (3.75, 0.45), (1.0, 0.55)):
            K.sakura(cv, x, y, 0.045, line="#8a0f30")
    else:
        K.sky(cv, [(0, "#0a0a24"), (0.5, "#2a1060"), (1, "#7a1a5a")])
        K.stars(cv, 60, 51)
        for x, y, r in ((0.5, 0.3, 0.13), (0.4, 0.75, 0.15), (2.7, 0.75, 0.14), (3.2, 0.35, 0.12), (3.7, 0.7, 0.15), (2.9, 0.2, 0.1)):
            peony(cv, x, y, r)
        F.kabuki(cv, K.Local(cv, 1.55, 0.36, 0.31), mane="#f8f4ee", paint_col="#d61f36")
        K.petals(cv, 40, 52, (0.1, 0.05, 3.9, 0.9), "#ffb0c8")
    K.border(cv, "#ff4fb4", "#ffd25c")


def musha(cv, side):
    """Guerreiro. R: samurai de armadura azul com chifres dourados, espada erguida, chamas. L: samurai de armadura
    vermelha com lua crescente, estandartes e raios."""
    if side == "R":
        K.sky(cv, [(0, "#14060a"), (0.5, "#5a0f14"), (1, "#c2361a")])
        K.rays(cv, 2.5, 0.45, 16, "#ffb347", 0.2, 2.4)
        K.flames(cv, [(0.1, 1.02), (1.6, 1.02)], 0.45, seed=3, n=12)
        K.flames(cv, [(3.0, 1.02), (3.95, 1.02)], 0.4, seed=4, n=8)
        G.warrior(cv, K.Local(cv, 2.45, 0.52, 0.34), armor="#1a2a6b", lace="#d61f36", crest="kuwagata", sword_side=1)
        _banner(cv, 0.55, "#1a2a6b", "#f2c14e")
        _banner(cv, 1.05, "#d61f36", "#ffffff")
    else:
        K.sky(cv, [(0, "#05061a"), (0.5, "#1a1450"), (1, "#5a2a8a")])
        K.moon(cv, 3.3, 0.3, 0.16, halo="#c7b8ff")
        for x0 in (0.5, 3.6):
            pts = [(x0, 0.0)] + [(x0 + 0.05 * math.sin(k * 2.3), 0.15 * (k + 1)) for k in range(6)]
            K.lightning(cv, pts, "#c9a7ff", 0.005)
        G.warrior(cv, K.Local(cv, 1.6, 0.54, 0.34), armor="#7a0a14", lace="#f2c14e", crest="moon", menpo="#141018", sword_side=-1)
        _banner(cv, 3.0, "#141018", "#f2c14e")
        _banner(cv, 3.45, "#7a0a14", "#ffffff")
        K.water_band(cv, 0.9, "#2a1460", "#0a0620", crest="#c9a7ff")
    K.border(cv, "#ffb347", "#3ff0ff")


def _banner(cv, x, color, mon):
    """Estandarte (nobori) vertical com um brasão redondo (sem texto)."""
    cv.fill(p.S(cv, [(x, 0.05), (x, 1.02)], 0.006), hexc("#2a1a0a"))
    fl = p.P(cv, [(x + 0.01, 0.08), (x + 0.2, 0.1), (x + 0.21, 0.75), (x + 0.01, 0.72)])
    cv.fill(p.outline(cv, fl, 0.003), hexc("#0a0606"))
    cv.fill(fl, hexc(color))
    cv.fill(p.ring(cv, x + 0.11, 0.3, 0.055, 0.008), hexc(mon))
    for k in range(3):
        a = math.radians(k * 120 - 90)
        cv.fill(p.C(cv, x + 0.11 + math.cos(a) * 0.025, 0.3 + math.sin(a) * 0.025, 0.018), hexc(mon))


def bijin_ogi(cv, side):
    """Mulher de quimono com leque. R: coque com grampos, quimono vermelho de sakura, Fuji ao pôr do sol.
    L: quimono azul de ondas, leque, lua e flores de ameixa."""
    if side == "R":
        K.sky(cv, [(0, "#2a0b4a"), (0.45, "#a3245a"), (0.8, "#ff8a5c"), (1, "#ffc27a")])
        K.rays(cv, 0.9, 0.55, 14, "#ffd36b", 0.2, 2.2)
        K.sun(cv, 0.9, 0.5, 0.25)
        fuji(cv, 1.2, 0.9, 0.7, 0.36)
        K.seigaiha(cv, 0.86, 1.0, 0.06)
        G.bijin(cv, K.Local(cv, 2.55, 0.4, 0.34), hair="updo", prop="fan", seed=4)
        K.petals(cv, 60, 61, (0.1, 0.05, 3.9, 0.85))
        for x, y in ((3.5, 0.2), (3.75, 0.35), (3.3, 0.12), (1.7, 0.2)):
            K.sakura(cv, x, y, 0.04, line="#8a0f30")
    else:
        K.sky(cv, [(0, "#060a2a"), (0.55, "#1a2a78"), (1, "#3a6ab8")])
        K.stars(cv, 80, 62)
        K.moon(cv, 2.9, 0.32, 0.22)
        _plum_branch(cv, 3.2, 0.0, flip=True)
        K.water_band(cv, 0.88, "#1b3fa3", "#050f3a")
        G.bijin(cv, K.Local(cv, 1.5, 0.4, 0.34), hair="updo", prop="fan", robe="#1d4fd0", robe2="#0a1a5a", obi="#f2c14e",
                pattern="wave", eyes_closed=False, seed=5)
    K.border(cv, "#ff4fb4", "#3ff0ff")


def _plum_branch(cv, x, y, flip=False):
    s = -1 if flip else 1
    br = p.spline([(x, y), (x + 0.2 * s, y + 0.15), (x + 0.15 * s, y + 0.35), (x + 0.4 * s, y + 0.5)], 10)
    cv.fill(p.SV(cv, br, [0.025, 0.018, 0.012, 0.006])[0], hexc("#2a1a14"))
    rng = np.random.default_rng(7)
    for k in range(9):
        q = br[rng.integers(3, len(br))]
        K.sakura(cv, q[0] + rng.uniform(-0.04, 0.04), q[1] + rng.uniform(-0.04, 0.04), 0.03, color="#ffffff", center="#ff4f6a")


def bijin_tsuki(cv, side):
    """Mulher sob a lua. R: cabelo solto, guarda-chuva vermelho, lua cheia e glicínias. L: cabelo solto, quimono roxo,
    noite de vaga-lumes no rio."""
    if side == "R":
        K.sky(cv, [(0, "#0a0626"), (0.5, "#2a1a6b"), (1, "#6a3aa0")])
        K.stars(cv, 90, 71)
        K.moon(cv, 3.3, 0.35, 0.24, halo="#ffd9f0")
        _wisteria(cv, 0.1, 1.5)
        G.bijin(cv, K.Local(cv, 2.15, 0.45, 0.32), hair="long", prop="umbrella", robe="#d61f8a", robe2="#5a0a4a",
                obi="#f2c14e", seed=8)
        K.petals(cv, 50, 72, (0.1, 0.05, 3.9, 0.9), "#d9b8ff")
    else:
        K.sky(cv, [(0, "#020818"), (0.6, "#0a2a4a"), (1, "#0f4a5a")])
        K.stars(cv, 120, 73, 0.6)
        K.moon(cv, 0.6, 0.28, 0.16)
        K.water_band(cv, 0.84, "#0f5a6a", "#021a2a", crest="#9ff0ff")
        rng = np.random.default_rng(74)
        for _ in range(60):
            x, y = rng.uniform(0.2, 3.9), rng.uniform(0.2, 0.85)
            cv.add(p.glow(cv, p.C(cv, x, y, 0.005), 0.01), hexc("#e8ff6a"), 1.5, neon=1.0)
        _wisteria(cv, 2.6, 3.95)
        G.bijin(cv, K.Local(cv, 1.7, 0.4, 0.34), hair="long", robe="#6a2ad0", robe2="#1a0a4a", obi="#ff6fae", pattern="wave",
                eyes_closed=False, prop="fan", seed=9)
    K.border(cv, "#b46cff", "#ff6fae")


def _wisteria(cv, x0, x1):
    """Cachos de glicínia pendurados no alto."""
    rng = np.random.default_rng(int(x0 * 100))
    cv.fill(p.S(cv, p.spline([(x0, 0.03), ((x0 + x1) / 2, 0.08), (x1, 0.03)], 12), 0.008), hexc("#3a2a1a"))
    for k in range(int((x1 - x0) / 0.12)):
        x = x0 + 0.06 + k * 0.12
        ln = rng.uniform(0.15, 0.32)
        for j in range(9):
            t = j / 8
            yy = 0.07 + t * ln
            r = 0.022 * (1 - t * 0.6)
            cv.fill(p.C(cv, x + 0.012 * math.sin(j * 1.7), yy, r), hexc("#b98aff" if j % 2 else "#d9b8ff"))


def hoo(cv, side):
    """Fênix e grous. R: fênix sobre nuvens douradas ao nascer do sol. L: grous sobre o mar com pinheiro e sol."""
    if side == "R":
        K.sky(cv, [(0, "#3a0a2a"), (0.45, "#c2245a"), (0.8, "#ffb347"), (1, "#ffe08a")])
        K.rays(cv, 2.9, 0.6, 18, "#fff0a0", 0.25, 2.6)
        K.sun(cv, 2.9, 0.62, 0.24, top="#fff4a0", bottom="#ff6a2a", ring_col="#ffd25c")
        for x, y, s in ((0.5, 0.8, 0.16), (1.6, 0.85, 0.14), (3.5, 0.85, 0.15), (3.0, 0.2, 0.1)):
            K.ruyi(cv, x, y, s, fill="#ffe08a", line="#7a3a06", shade="#e8a21a")
        B.phoenix(cv, K.Local(cv, 2.35, 0.45, 0.32))
    else:
        K.sky(cv, [(0, "#0a1a3a"), (0.5, "#2a5aa0"), (1, "#bfe3ff")])
        K.sun(cv, 1.0, 0.45, 0.22, ring_col=None)
        _pine_branch(cv)
        K.water_band(cv, 0.84, "#2f7fe0", "#0a2a6b", crest="#ffffff")
        B.crane(cv, K.Local(cv, 1.7, 0.5, 0.36, flip=True))
        B.crane(cv, K.Local(cv, 2.7, 0.35, 0.26, flip=True), flap=-1)
        B.crane(cv, K.Local(cv, 3.3, 0.6, 0.2, flip=True))
    K.border(cv, "#ffd25c", "#ff4fb4")


def _pine_branch(cv):
    br = p.spline([(4.05, 0.05), (3.7, 0.15), (3.4, 0.1), (3.1, 0.2)], 10)
    cv.fill(p.outline(cv, p.SV(cv, br, [0.03, 0.02, 0.015, 0.008])[0], 0.004), hexc("#120a06"))
    cv.fill(p.SV(cv, br, [0.03, 0.02, 0.015, 0.008])[0], hexc("#5a3a22"))
    for k, (x, y) in enumerate(((3.85, 0.13), (3.55, 0.2), (3.25, 0.25), (3.65, 0.06))):
        pad = p.E(cv, x, y, 0.14, 0.05)
        cv.fill(p.outline(cv, pad, 0.003), hexc("#06210f"))
        cv.fill(pad, hexc("#1f6a3a"))
        for j in range(9):
            a = math.radians(200 + j * 16)
            cv.fill(p.S(cv, [(x, y), (x + math.cos(a) * 0.13, y + math.sin(a) * 0.05)], 0.0025), hexc("#5fbf6a"))


def men(cv, side):
    """Máscaras. R: hannya dourada e oni vermelho entre chamas e raios. L: kitsune, tengu e Noh com lanternas de festival."""
    if side == "R":
        K.sky(cv, [(0, "#0a0418"), (0.5, "#3a0a2a"), (1, "#7a0a1a")])
        K.flames(cv, [(0.1, 1.02), (3.95, 1.02)], 0.35, seed=8, n=22, colors=("#c9a7ff", "#7a3aff", "#3a0a8a"))
        pts = [(1.95, 0.0), (2.05, 0.25), (1.92, 0.45), (2.08, 0.75), (2.0, 1.0)]
        K.lightning(cv, pts, "#ffe14a", 0.006)
        F.hannya(cv, K.Local(cv, 2.85, 0.55, 0.38))
        F.oni(cv, K.Local(cv, 1.15, 0.55, 0.36))
    else:
        K.sky(cv, [(0, "#05051a"), (0.55, "#1a1050"), (1, "#3a1a6b")])
        K.stars(cv, 60, 81)
        _lanterns(cv)
        F.kitsune(cv, K.Local(cv, 0.95, 0.56, 0.34))
        F.noh(cv, K.Local(cv, 2.0, 0.52, 0.36))
        F.tengu(cv, K.Local(cv, 3.05, 0.5, 0.34))
        K.petals(cv, 40, 82, (0.1, 0.05, 3.9, 0.95), "#ffb0c8")
    K.border(cv, "#b46cff", "#ffe14a")


def _lanterns(cv):
    """Fileira de lanternas de papel (chōchin) acesas, no alto."""
    cv.fill(p.S(cv, p.spline([(0.0, 0.06), (2.0, 0.14), (4.0, 0.06)], 16), 0.004), hexc("#2a1a0a"))
    for k in range(13):
        x = 0.15 + k * 0.3
        y = 0.06 + 0.08 * math.sin(math.pi * x / 4) + 0.06
        lay = p.E(cv, x, y, 0.045, 0.06)
        cv.add(p.glow(cv, lay, 0.04), hexc("#ff7a3a"), 0.9, neon=0.8)
        cv.fill(lay, hexc("#ff3a2a" if k % 2 else "#ffb03a"), neon=0.9)
        for j in range(3):
            cv.fill(p.mul(p.S(cv, [(x - 0.04, y - 0.03 + j * 0.03), (x + 0.04, y - 0.03 + j * 0.03)], 0.002), 0.6), hexc("#7a1a0a"))
        cv.fill(p.E(cv, x, y - 0.06, 0.03, 0.008), hexc("#1a1a1a"))
        cv.fill(p.E(cv, x, y + 0.06, 0.03, 0.008), hexc("#1a1a1a"))
