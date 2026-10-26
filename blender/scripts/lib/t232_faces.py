"""Rostos de frente da T-232: ator de kabuki (maquiagem kumadori), leão do kabuki (juba longa), máscaras hannya, oni,
kitsune, tengu e Noh. Desenhos nossos por código, simétricos; inspirados nos tipos tradicionais (Sharaku para o
kabuki; as máscaras de Noh/kyōgen e do festival), sem copiar nenhuma obra.
Quadro local: centro do rosto em (0, 0); testa em y ~ -0,6, queixo em y ~ +0,65; largura ~1.
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from .paint2d import hexc
from .t232_kit import Local, paint

INK = "#140808"


def _sym(fn):
    for s in (-1, 1):
        fn(s)


def _face_shape(L, w=0.5, h=0.62, chin=0.12):
    return L.sdf((-0.75, -0.8, 0.75, 0.9), lambda x, y: p.smin(p.sd_ellipse(x, y, 0, -0.05, w, h),
                                                               p.sd_ellipse(x, y, 0, 0.42, w * 0.62, 0.22 + chin), 0.12))


def _eye(cv, L, s, x, y, w, h, tilt, iris="#ffffff", pupil=INK, glow=0.0):
    e = L.sdf((s * x - w * 1.2, y - h * 2, s * x + w * 1.2, y + h * 2),
              lambda lx, ly: p.sd_ellipse(lx, ly, s * x, y, w, h, s * math.radians(tilt)))
    cv.fill(p.outline(cv, e, 0.006), hexc(INK))
    cv.fill(e, hexc(iris), neon=glow)
    cv.fill(L.E(s * x, y, h * 0.75, h * 0.75), hexc(pupil))


def kabuki(cv, L: Local, mane=None, paint_col="#d61f36", hair="#0a0a12"):
    """Ator de kabuki com kumadori (linhas vermelhas de força). `mane` = cor da juba longa do leão (renjishi) ou None
    (cabelo preso com topete)."""
    if mane:
        for k in range(17):
            a = math.radians(-180 + k * 11.25)                 # raízes no alto da cabeça, fios caem como capa
            sx = 1 if math.cos(a) >= 0 else -1
            root = (math.cos(a) * 0.42, -0.3 + math.sin(a) * 0.5)
            out = 0.55 + 0.75 * abs(math.cos(a)) + 0.08 * (k % 3)
            tip = (sx * out, 1.25 + 0.18 * (k % 4))
            mid = (sx * (out * 0.75 + 0.15), (root[1] + tip[1]) * 0.5 - 0.15)
            lay = L.SV(p.spline([root, mid, tip], 12), [0.17, 0.15, 0.03])[0]
            cv.fill(p.outline(cv, lay, 0.004), hexc("#6a5a5a" if mane == "#f8f4ee" else "#3a0606"))
            paint(cv, lay, mane, "#c9b8b0" if mane == "#f8f4ee" else "#8a0a14", width=0.02 * L.s)
    else:
        hd = L.sdf((-0.75, -1.05, 0.75, 0.3), lambda x, y: p.smin(p.sd_ellipse(x, y, 0, -0.32, 0.6, 0.48),
                                                                  p.sd_ellipse(x, y, 0, -0.85, 0.16, 0.12), 0.08))
        cv.fill(p.outline(cv, hd, 0.006), hexc(INK))
        paint(cv, hd, hair, "#2a2a40", width=0.04 * L.s, light="#5a5a8a")
        cv.fill(L.E(0, -0.62, 0.3, 0.14), hexc("#cfd6e6"))      # sakayaki (testa raspada)
    f = _face_shape(L)
    cv.fill(p.outline(cv, f, 0.007), hexc(INK))
    cv.fill(f, hexc("#fbf6f0"))
    # kumadori: linhas grossas que sobem dos olhos e descem da boca
    def lines(s):
        for pts, w in (([(s * 0.12, -0.12), (s * 0.3, -0.32), (s * 0.42, -0.55)], 0.045),
                       ([(s * 0.25, -0.05), (s * 0.45, -0.18), (s * 0.5, -0.35)], 0.035),
                       ([(s * 0.18, 0.32), (s * 0.35, 0.42), (s * 0.4, 0.58)], 0.035),
                       ([(s * 0.06, -0.38), (s * 0.12, -0.58)], 0.03)):
            sp = p.spline(pts, 8)
            cv.fill(L.SV(sp, [w * 0.4, w, w * 0.2])[0], hexc(paint_col))
    _sym(lines)
    # sobrancelhas, olhos com contorno grosso, nariz, boca virada para baixo
    def feats(s):
        cv.fill(L.SV(p.spline([(s * 0.05, -0.24), (s * 0.22, -0.34), (s * 0.4, -0.3)], 8), [0.03, 0.05, 0.015])[0], hexc(INK))
        e = L.sdf((s * 0.22 - 0.15, -0.2, s * 0.22 + 0.15, 0.0), lambda lx, ly: np.maximum(
            p.sd_ellipse(lx, ly, s * 0.22, -0.1, 0.13, 0.05, s * 0.3), -p.sd_circle(lx, ly, s * 0.22, 0.05, 0.1)))
        cv.fill(p.outline(cv, e, 0.008), hexc(paint_col))
        cv.fill(p.outline(cv, e, 0.004), hexc(INK))
        cv.fill(e, hexc("#ffffff"))
        cv.fill(L.E(s * 0.18, -0.085, 0.03, 0.03), hexc(INK))
    _sym(feats)
    cv.fill(L.S(p.spline([(-0.05, 0.12), (0.0, 0.15), (0.05, 0.12)], 6), 0.012), hexc("#a08080"))
    lips = L.P(p.spline([(-0.22, 0.36), (-0.1, 0.28), (0.0, 0.3), (0.1, 0.28), (0.22, 0.36)], 6) +
               p.spline([(0.22, 0.36), (0.1, 0.34), (0.0, 0.35), (-0.1, 0.34), (-0.22, 0.36)], 6))
    cv.fill(p.outline(cv, lips, 0.004), hexc(INK))
    cv.fill(lips, hexc("#c0102a"))


def hannya(cv, L: Local, skin="#f6e9c8", horn="#f2c14e"):
    """Máscara hannya: chifres, olhos dourados, sorriso largo com presas, cabelo solto dos lados."""
    _sym(lambda s: [cv.fill(L.SV(p.spline([(s * 0.3, -0.5), (s * 0.55 + 0.1 * s * k, 0.2), (s * 0.6 + 0.12 * s * k, 0.9)], 10),
                                [0.05, 0.03, 0.01])[0], hexc("#0d0a14")) for k in range(4)])
    def horns(s):
        h = L.SV(p.spline([(s * 0.28, -0.48), (s * 0.45, -0.75), (s * 0.42, -1.0), (s * 0.3, -1.15)], 10), [0.1, 0.07, 0.04, 0.01])[0]
        cv.fill(p.outline(cv, h, 0.006), hexc(INK))
        paint(cv, h, horn, "#9a6a12", width=0.03 * L.s, light="#fff4c0")
        for k in range(3):
            y = -0.62 - k * 0.12
            cv.fill(L.S([(s * (0.36 + k * 0.02), y), (s * (0.48 + k * 0.01), y - 0.03)], 0.008), hexc("#9a6a12"))
    _sym(horns)
    f = L.sdf((-0.75, -0.8, 0.75, 0.95), lambda x, y: p.smin(p.sd_ellipse(x, y, 0, -0.05, 0.5, 0.6),
                                                             p.sd_ellipse(x, y, 0, 0.45, 0.42, 0.32), 0.1))
    cv.fill(p.outline(cv, f, 0.008), hexc(INK))
    paint(cv, f, skin, "#c9a878", width=0.12 * L.s)
    def feats(s):
        b = L.P([(s * 0.05, -0.18), (s * 0.15, -0.38), (s * 0.45, -0.45), (s * 0.4, -0.3), (s * 0.18, -0.22)])
        cv.fill(b, hexc(INK))
        _eye(cv, L, s, 0.22, -0.1, 0.12, 0.07, 25, iris="#f2c14e", glow=0.9)
        cv.fill(L.S(p.spline([(s * 0.08, 0.0), (s * 0.15, 0.12), (s * 0.12, 0.22)], 6), 0.01), hexc("#a07850"))
    _sym(feats)
    mouth = L.sdf((-0.5, 0.2, 0.5, 0.75), lambda x, y: np.maximum(p.sd_ellipse(x, y, 0, 0.32, 0.42, 0.3), -(y - 0.27 - x * x * 0.6)))
    cv.fill(p.outline(cv, mouth, 0.008), hexc(INK))
    cv.fill(mouth, hexc("#8a0a1a"))
    cv.fill(L.E(0, 0.5, 0.16, 0.06), hexc("#e8325a"))
    for x in np.linspace(-0.3, 0.3, 7):
        y0 = 0.28 + x * x * 0.6
        cv.fill(L.P([(x - 0.035, y0), (x, y0 + 0.07), (x + 0.035, y0)]), hexc("#ffffff"))
    _sym(lambda s: cv.fill(L.P([(s * 0.3, 0.35), (s * 0.24, 0.55), (s * 0.2, 0.36)]), hexc("#ffffff")))
    _sym(lambda s: cv.fill(L.P([(s * 0.18, 0.6), (s * 0.15, 0.45), (s * 0.11, 0.6)]), hexc("#ffffff")))


def oni(cv, L: Local, skin="#d6262e", hair="#1a0a14"):
    """Oni: pele vermelha, 2 chifres, cabelo arrepiado, olhos esbugalhados, presas para cima."""
    for k in range(13):
        a = math.radians(-175 + k * 14.5)
        tip = (math.cos(a) * 0.95, -0.25 + math.sin(a) * 0.85)
        hh = L.P([(math.cos(a - 0.2) * 0.4, -0.25 + math.sin(a - 0.2) * 0.45), tip, (math.cos(a + 0.2) * 0.4, -0.25 + math.sin(a + 0.2) * 0.45)])
        cv.fill(hh, hexc(hair))
    def horns(s):
        h = L.SV(p.spline([(s * 0.22, -0.5), (s * 0.28, -0.8), (s * 0.18, -1.0)], 8), [0.1, 0.06, 0.01])[0]
        cv.fill(p.outline(cv, h, 0.006), hexc(INK))
        paint(cv, h, "#fff4d6", "#b8a070", width=0.03 * L.s)
    _sym(horns)
    f = _face_shape(L, 0.55, 0.6, 0.18)
    cv.fill(p.outline(cv, f, 0.008), hexc(INK))
    paint(cv, f, skin, "#7a0a14", width=0.14 * L.s, light="#ff8a7a")
    def feats(s):
        cv.fill(L.SV(p.spline([(s * 0.04, -0.2), (s * 0.25, -0.38), (s * 0.48, -0.32)], 8), [0.05, 0.07, 0.03])[0], hexc(hair))
        _eye(cv, L, s, 0.23, -0.1, 0.12, 0.1, 0, iris="#fff6a0", glow=0.9)
        for k in range(3):
            cv.fill(L.S([(s * (0.45 + k * 0.02), -0.05 + k * 0.08), (s * 0.55, -0.02 + k * 0.08)], 0.006), hexc("#7a0a14"))
    _sym(feats)
    nose = L.sdf((-0.2, 0.0, 0.2, 0.3), lambda x, y: p.smin(p.sd_circle(x, y, -0.07, 0.18, 0.06), p.sd_circle(x, y, 0.07, 0.18, 0.06), 0.05))
    cv.fill(p.outline(cv, nose, 0.005), hexc(INK))
    paint(cv, nose, "#ff5a5a", "#7a0a14", width=0.03 * L.s)
    m = L.sdf((-0.4, 0.25, 0.4, 0.7), lambda x, y: p.sd_ellipse(x, y, 0, 0.45, 0.32, 0.13))
    cv.fill(p.outline(cv, m, 0.007), hexc(INK))
    cv.fill(m, hexc("#3a0610"))
    for x in np.linspace(-0.22, 0.22, 6):
        cv.fill(L.P([(x - 0.035, 0.34), (x, 0.4), (x + 0.035, 0.34)]), hexc("#ffffff"))
    _sym(lambda s: cv.fill(L.P([(s * 0.28, 0.55), (s * 0.24, 0.22), (s * 0.18, 0.55)]), hexc("#fffaf0")))


def kitsune(cv, L: Local, base="#fbfaf6", mark="#e8202c", gold="#f2c14e"):
    """Máscara de raposa (kitsune): orelhas pontudas, focinho fino, marcas vermelhas e douradas."""
    def ears(s):
        e = L.P([(s * 0.12, -0.45), (s * 0.5, -1.05), (s * 0.55, -0.3)])
        cv.fill(p.outline(cv, e, 0.007), hexc(INK))
        cv.fill(e, hexc(base))
        cv.fill(L.P([(s * 0.22, -0.45), (s * 0.48, -0.9), (s * 0.48, -0.4)]), hexc(mark))
    _sym(ears)
    f = L.sdf((-0.7, -0.75, 0.7, 0.95), lambda x, y: p.smin(p.sd_ellipse(x, y, 0, -0.15, 0.55, 0.45),
                                                            p.sd_poly(x, y, [(-0.3, 0.0), (0.3, 0.0), (0.06, 0.85), (-0.06, 0.85)]), 0.15))
    cv.fill(p.outline(cv, f, 0.008), hexc(INK))
    paint(cv, f, base, "#d9d4ce", width=0.08 * L.s)
    def feats(s):
        sw = L.SV(p.spline([(s * 0.08, -0.08), (s * 0.3, -0.25), (s * 0.55, -0.32)], 10), [0.02, 0.06, 0.01])[0]
        cv.fill(sw, hexc(mark), neon=0.3)
        e = L.sdf((s * 0.25 - 0.15, -0.25, s * 0.25 + 0.15, 0.0),
                  lambda lx, ly: np.maximum(p.sd_ellipse(lx, ly, s * 0.24, -0.12, 0.13, 0.04, s * 0.45), -1.0))
        cv.fill(p.outline(cv, e, 0.004), hexc(INK))
        cv.fill(e, hexc(gold), neon=0.9)
        cv.fill(L.S([(s * 0.06, -0.48), (s * 0.18, -0.4)], 0.02), hexc(mark))
        cv.fill(L.S([(s * 0.05, -0.38), (s * 0.15, -0.32)], 0.015), hexc(gold))
        for k in range(3):
            cv.fill(L.S([(s * 0.1, 0.55 + k * 0.04), (s * 0.35, 0.5 + k * 0.08)], 0.004), hexc(INK))
    _sym(feats)
    cv.fill(L.S([(0, -0.6), (0, -0.25)], 0.025), hexc(mark))
    cv.fill(L.E(0, 0.82, 0.07, 0.05), hexc(INK))
    cv.fill(L.S(p.spline([(-0.1, 0.72), (0.0, 0.78), (0.1, 0.72)], 6), 0.012), hexc(mark))


def tengu(cv, L: Local, skin="#c8102e", beard="#f4f0ea"):
    """Tengu: rosto vermelho, nariz comprido, sobrancelhas e barba brancas, chapeuzinho (tokin) preto."""
    for k in range(9):
        x = -0.45 + k * 0.11
        cv.fill(L.SV(p.spline([(x * 0.8, 0.35), (x * 1.1, 0.75), (x * 1.3, 1.1)], 8), [0.07, 0.05, 0.01])[0], hexc(beard))
    _sym(lambda s: cv.fill(L.SV(p.spline([(s * 0.45, -0.3), (s * 0.7, 0.1), (s * 0.75, 0.6)], 8), [0.08, 0.06, 0.01])[0], hexc(beard)))
    f = _face_shape(L, 0.5, 0.6, 0.1)
    cv.fill(p.outline(cv, f, 0.008), hexc(INK))
    paint(cv, f, skin, "#5a0610", width=0.13 * L.s, light="#ff7a6a")
    tk = L.P([(-0.22, -0.62), (0.22, -0.62), (0.16, -0.9), (-0.16, -0.9)])
    cv.fill(p.outline(cv, tk, 0.005), hexc("#5a5a6a"))
    cv.fill(tk, hexc("#0a0a10"))
    def feats(s):
        cv.fill(L.SV(p.spline([(s * 0.05, -0.18), (s * 0.28, -0.32), (s * 0.55, -0.42)], 8), [0.04, 0.07, 0.02])[0], hexc(beard))
        _eye(cv, L, s, 0.22, -0.12, 0.11, 0.06, 15, iris="#ffe14a", glow=0.8)
    _sym(feats)
    nose = L.sdf((-0.2, -0.15, 0.2, 0.65), lambda x, y: p.sd_seg(x, y, 0, -0.05, 0, 0.55, 0.07, 0.11))
    cv.fill(p.outline(cv, nose, 0.007), hexc(INK))
    paint(cv, nose, "#e8243a", "#6a0612", width=0.05 * L.s, light="#ffb0a0")
    cv.fill(L.S(p.spline([(-0.2, 0.45), (0.0, 0.38), (0.2, 0.45)], 6), 0.012), hexc(INK))


def noh(cv, L: Local, skin="#fbf8f2", hair="#0b0b12"):
    """Máscara de Noh (moça, ko-omote): rosto branco oval, sobrancelhas pintadas no alto da testa, boca pequena."""
    hd = L.sdf((-0.7, -0.85, 0.7, 0.6), lambda x, y: p.sd_ellipse(x, y, 0, -0.15, 0.6, 0.68))
    cv.fill(hd, hexc(hair))
    f = L.sdf((-0.6, -0.75, 0.6, 0.85), lambda x, y: p.sd_ellipse(x, y, 0, 0.05, 0.45, 0.68))
    cv.fill(p.outline(cv, f, 0.006), hexc(INK))
    paint(cv, f, skin, "#e6dccd", width=0.1 * L.s)
    _sym(lambda s: cv.fill(L.SV(p.spline([(s * 0.02, -0.62), (s * 0.25, -0.5), (s * 0.48, -0.25)], 10), [0.05, 0.035, 0.005])[0], hexc(hair)))
    def feats(s):
        cv.fill(L.E(s * 0.2, -0.38, 0.09, 0.035), hexc("#2a2a30"))
        cv.fill(p.mul(L.E(s * 0.2, -0.38, 0.14, 0.07), 0.25), hexc("#2a2a30"))
        e = L.sdf((s * 0.2 - 0.1, -0.15, s * 0.2 + 0.1, 0.0), lambda lx, ly: p.sd_ellipse(lx, ly, s * 0.2, -0.07, 0.08, 0.018))
        cv.fill(e, hexc(INK))
        cv.fill(p.mul(L.E(s * 0.22, 0.12, 0.1, 0.06), 0.35), hexc("#f0a0a8"))
    _sym(feats)
    lips = L.sdf((-0.12, 0.3, 0.12, 0.45), lambda x, y: p.smin(p.sd_ellipse(x, y, 0, 0.37, 0.09, 0.03), p.sd_circle(x, y, 0, 0.35, 0.03), 0.02))
    cv.fill(lips, hexc("#c0102a"))
    cv.fill(L.E(0, 0.375, 0.05, 0.008), hexc(INK))
