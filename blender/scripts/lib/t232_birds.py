"""Aves da T-232: fênix (hōō) e grou (tsuru), voando, de lado. Desenhos nossos por código; a fênix segue o tipo das
pinturas de aves e flores (Hokusai, Jakuchū), sem copiar obra. Quadro local: cabeça olhando para +x.
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from .paint2d import hexc
from .t232_kit import Local, neon_line, paint

INK = "#1a0612"


def _feather(cv, L, base, tip, w, c0, c1, line=INK, eye=None):
    """Pena: folha com raque no meio, degradê da base para a ponta e, se `eye`, um olho na ponta."""
    d = np.array(tip) - np.array(base)
    ln = float(np.hypot(*d))
    nx, ny = -d[1] / ln, d[0] / ln
    side_a = [(base[0] + d[0] * t + nx * w * math.sin(math.pi * t) ** 0.6, base[1] + d[1] * t + ny * w * math.sin(math.pi * t) ** 0.6)
              for t in np.linspace(0, 1, 14)]
    side_b = [(base[0] + d[0] * t - nx * w * math.sin(math.pi * t) ** 0.6, base[1] + d[1] * t - ny * w * math.sin(math.pi * t) ** 0.6)
              for t in np.linspace(1, 0, 14)]
    lay = L.P(side_a + side_b)
    cv.fill(p.outline(cv, lay, 0.003), hexc(line))
    lx, ly = L.local_xy(lay)
    t = ((lx - base[0]) * d[0] + (ly - base[1]) * d[1]) / (ln * ln)
    cv.fill(lay, p.grad_t(t, [(0, c0), (1, c1)]))
    cv.fill(L.S([base, tip], 0.004), hexc(line))
    if eye:
        ex, ey = base[0] + d[0] * 0.78, base[1] + d[1] * 0.78
        cv.fill(L.E(ex, ey, w * 0.55, w * 0.45), hexc(eye[0]))
        cv.fill(L.E(ex, ey, w * 0.32, w * 0.26), hexc(eye[1]), neon=0.6)
        cv.fill(L.E(ex, ey, w * 0.14, w * 0.12), hexc("#0a0a2a"))


def phoenix(cv, L: Local, wing_up=1.0):
    """Fênix voando para +x: asas abertas para cima, cauda com 5 plumas compridas com olhos (neon)."""
    plumes = [((-0.35, 0.05), (-2.6, -0.35), 0.11), ((-0.35, 0.08), (-2.4, 0.25), 0.1), ((-0.3, 0.1), (-2.0, 0.65), 0.09),
              ((-0.35, 0.02), (-1.9, -0.8), 0.09), ((-0.3, 0.12), (-1.5, 0.95), 0.08)]
    for k, (b, t, w) in enumerate(plumes):
        mid = ((b[0] + t[0]) / 2, (b[1] + t[1]) / 2 + 0.25 * (1 if k % 2 else -1))
        curve = p.spline([b, mid, t], 14)
        lay = L.SV(curve, [w * 0.5, w * 1.6, w * 1.1, w * 0.25])[0]
        cv.fill(p.outline(cv, lay, 0.003), hexc(INK))
        lx, ly = L.local_xy(lay)
        tt = np.clip((b[0] - lx) / (b[0] - t[0]), 0, 1)
        cv.fill(lay, p.grad_t(tt, [(0, "#ffd25c"), (0.5, "#ff5a2a"), (1, "#d61f36")]))
        ex, ey = curve[int(len(curve) * 0.8)]
        cv.fill(L.E(ex, ey, w * 0.9, w * 0.6), hexc("#3ff0ff"), neon=0.8)
        cv.fill(L.E(ex, ey, w * 0.5, w * 0.35), hexc("#1d3fd0"))
        neon_line(cv, L.pts(curve[2:]), "#ffb347", 0.002, 0.6)
    # asa de trás (mais escura) e da frente
    for k, (sx, dark) in enumerate(((-0.12, True), (0.08, False))):
        root = (sx, -0.08)
        for j in range(9):
            a = math.radians(-168 + j * 15) if wing_up > 0 else math.radians(168 - j * 15)
            ln = (1.25 + 0.5 * math.sin(j / 8 * math.pi)) * (0.85 if dark else 1.0)
            tip = (root[0] + math.cos(a) * ln * 0.75, root[1] + math.sin(a) * ln)
            c0, c1 = ("#1f7a5a", "#0d3a5a") if dark else ("#ffd25c", "#2fbf71" if j % 2 else "#2f7fe0")
            _feather(cv, L, root, tip, 0.1 + 0.025 * (j % 2), c0, c1)
        cov = L.E(sx - 0.1, -0.22, 0.28, 0.16, -25)
        cv.fill(p.outline(cv, cov, 0.004), hexc(INK))
        paint(cv, cov, "#d61f36" if not dark else "#7a0a20", "#5a0610", width=0.03 * L.s)
    # corpo, pescoço, cabeça com crista
    body = L.sdf((-0.6, -0.6, 1.0, 0.4), lambda x, y: p.smin(p.smin(
        p.sd_ellipse(x, y, -0.05, 0.08, 0.42, 0.18, 0.1), p.sd_seg(x, y, 0.25, 0.0, 0.62, -0.32, 0.11, 0.06), 0.08),
        p.sd_circle(x, y, 0.7, -0.38, 0.09), 0.04))
    cv.fill(p.outline(cv, body, 0.005), hexc(INK))
    lx, ly = L.local_xy(body)
    cv.fill(body, p.grad_t((lx + 0.4) / 1.2, [(0, "#d61f36"), (0.6, "#ff7a1a"), (1, "#ffd25c")]))
    for k in range(5):
        cv.fill(p.mul(L.S(p.arc(0.0 + k * 0.08, 0.06, 0.05, 0.08, 20, 160, 8), 0.004), 0.7), hexc("#7a0a20"))
    for j in range(3):
        cv.fill(L.SV(p.spline([(0.68, -0.44), (0.6 - j * 0.05, -0.62 - j * 0.04), (0.5 - j * 0.1, -0.7 - j * 0.02)], 8),
                     [0.02, 0.012, 0.003])[0], hexc("#3ff0ff"), neon=0.6)
        cv.fill(L.E(0.5 - j * 0.1, -0.7 - j * 0.02, 0.025, 0.02), hexc("#ffd25c"), neon=0.8)
    beak = L.P([(0.76, -0.42), (0.92, -0.36), (0.77, -0.33)])
    cv.fill(p.outline(cv, beak, 0.003), hexc(INK))
    cv.fill(beak, hexc("#ffd25c"))
    cv.fill(L.E(0.72, -0.4, 0.022, 0.018), hexc("#ffffff"))
    cv.fill(L.E(0.725, -0.4, 0.012, 0.012), hexc(INK))
    for k in range(3):
        cv.fill(L.SV(p.spline([(0.66, -0.32), (0.6, -0.15 - k * 0.04), (0.45, -0.05 - k * 0.06)], 8), [0.015, 0.02, 0.004])[0],
                hexc("#2f7fe0"))


def crane(cv, L: Local, flap=1.0):
    """Grou voando para +x: corpo branco, pescoço comprido preto, coroa vermelha, asas brancas com pontas pretas."""
    for j in range(8):
        a = math.radians(-168 + j * 14) if flap > 0 else math.radians(168 - j * 14)
        ln = 1.2 + 0.35 * math.sin(j / 7 * math.pi)
        tip = (-0.05 + math.cos(a) * ln * 0.8, -0.05 + math.sin(a) * ln)
        _feather(cv, L, (-0.05, -0.02), tip, 0.12, "#ffffff", "#141414" if j < 3 else "#dfe6f0", line="#2a2a3a")
    body = L.sdf((-0.8, -0.4, 1.4, 0.35), lambda x, y: p.smin(p.sd_ellipse(x, y, 0, 0.05, 0.42, 0.14, 0.05),
                                                              p.sd_seg(x, y, 0.3, 0.0, 1.05, -0.12, 0.05, 0.032), 0.08))
    cv.fill(p.outline(cv, body, 0.004), hexc("#2a2a3a"))
    lx, ly = L.local_xy(body)
    cv.fill(body, np.where((lx > 0.42)[..., None], hexc("#141418"), hexc("#ffffff")).astype(np.float32))
    for k in range(5):
        cv.fill(L.SV([(-0.38, 0.05 + k * 0.02), (-0.7, 0.0 + k * 0.05), (-0.85, 0.02 + k * 0.06)], [0.03, 0.02, 0.005])[0],
                hexc("#141418"))
    cv.fill(L.E(1.08, -0.13, 0.05, 0.04), hexc("#ffffff"))
    cv.fill(L.E(1.08, -0.16, 0.025, 0.018), hexc("#e8202c"), neon=0.5)
    cv.fill(L.P([(1.12, -0.14), (1.3, -0.1), (1.12, -0.1)]), hexc("#c9b080"))
    cv.fill(L.E(1.09, -0.13, 0.008, 0.008), hexc(INK))
    for d in (0.0, 0.03):
        cv.fill(L.S([(-0.35, 0.12 + d), (-0.95, 0.22 + d * 2)], 0.008), hexc("#2a2a3a"))
