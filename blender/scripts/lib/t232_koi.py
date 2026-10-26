"""Carpa (koi) e nenúfar da T-232. Desenho nosso por código (a carpa subindo a cachoeira é tema tradicional)."""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from .paint2d import hexc
from .t232_kit import Local, paint

KINDS = {
    "red": ("#ff5a2a", "#c0181c", "#ffd0a0"),
    "gold": ("#ffd23a", "#d88a0a", "#fff4b0"),
    "white": ("#fffaf2", "#e8302a", "#ffffff"),
}
LINE = "#2a0606"


def koi(cv, L: Local, kind="red", seed=1):
    """Carpa olhando para +x local: cabeça em x ~ 0,9, cauda em x ~ -1,1."""
    base, accent, light = KINDS[kind]
    spine = p.spline([(-0.95, 0.06), (-0.5, -0.04), (0.1, 0.0), (0.6, 0.02), (0.95, 0.0)], 12)
    radii = [0.05, 0.13, 0.22, 0.24, 0.17]
    # nadadeira da cauda (2 lóbulos) e nadadeiras
    tail = L.P(p.spline([(-0.9, 0.04), (-1.25, -0.25), (-1.45, -0.32)], 6) + p.spline([(-1.45, -0.32), (-1.25, 0.02), (-1.5, 0.4)], 8)
               + p.spline([(-1.5, 0.4), (-1.2, 0.3), (-0.9, 0.1)], 6))
    fins = [L.P(p.spline([(0.35, 0.15), (0.2, 0.45), (0.05, 0.5), (0.15, 0.2)], 6)),
            L.P(p.spline([(-0.1, -0.2), (-0.35, -0.42), (-0.6, -0.35), (-0.55, -0.15)], 6)),
            L.P(p.spline([(-0.45, 0.12), (-0.62, 0.32), (-0.75, 0.3), (-0.65, 0.1)], 6))]
    for f in [tail] + fins:
        cv.fill(p.outline(cv, f, 0.004), hexc(LINE))
        X, Y = cv.coords(f)
        lx, ly = L.to_local(X, Y)
        rays_ = (np.sin(np.arctan2(ly, lx + 0.4) * 30) > 0.4).astype(np.float32)
        col = p.mix(hexc(light), hexc(accent), 0.35 + 0.25 * rays_[..., None])
        cv.fill(f, col, neon=0.0)
        cv.add(f, hexc(light), 0.15)
    lay, (S, W) = L.SV(spine, radii, need_uv=True)
    cv.fill(p.outline(cv, lay, 0.005), hexc(LINE))
    lx, ly = L.local_xy(lay)
    n = p.vnoise(lx, ly, 0.35, seed=seed)
    patch = np.clip((n - 0.45) * 8, 0, 1)
    if kind == "white":
        col = p.mix(hexc(base), hexc(accent), patch[..., None])
        blk = np.clip((p.vnoise(lx + 3, ly, 0.2, seed=seed + 5) - 0.68) * 10, 0, 1)
        col = p.mix(col, hexc("#141018"), blk[..., None])
    else:
        col = p.mix(hexc(base), hexc(accent), (0.3 + 0.5 * patch)[..., None])
    cell = 0.07 * L.s
    u = S / cell
    row = np.floor((W + 1) * 3.5)
    uu = (u + 0.5 * (row % 2)) % 1.0 - 0.5
    vv = ((W + 1) * 3.5) % 1.0
    scl = np.clip(1 - np.abs(np.hypot(uu, vv * 0.9) - 0.48) / 0.08, 0, 1)
    col = col * (1 - 0.3 * scl[..., None])
    col = col + np.clip(1 - np.abs(W + 0.4) / 0.25, 0, 1)[..., None] * 0.35 * (hexc(light) - col)
    cv.fill(lay, col.astype(np.float32))
    # cabeça: olho, boca, bigodes
    eye = L.E(0.78, -0.05, 0.045, 0.045)
    cv.fill(p.outline(cv, eye, 0.002), hexc(LINE))
    cv.fill(eye, hexc("#ffffff"))
    cv.fill(L.E(0.79, -0.05, 0.025, 0.025), hexc("#101010"))
    cv.fill(L.E(1.02, 0.02, 0.04, 0.03), hexc(LINE))
    for d in (-1, 1):
        cv.fill(L.SV(p.spline([(0.98, 0.05), (1.1, 0.1 + d * 0.04), (1.15, 0.2 + d * 0.05)], 6), [0.012, 0.004])[0], hexc(accent))
    cv.fill(L.S(p.arc(0.6, 0.0, 0.12, 0.2, -70, 70, 12), 0.006), hexc(LINE))


def lily(cv, x, y, r, leaf="#2f9a4a", flower="#ff8fbf"):
    """Folha de nenúfar (disco com corte) e uma flor."""
    L = Local(cv, x, y, r)
    lf = L.sdf((-1.1, -1.1, 1.1, 1.1), lambda lx, ly: np.maximum(p.sd_circle(lx, ly, 0, 0, 1),
                                                                   -p.sd_poly(lx, ly, [(0, 0), (1.3, -0.25), (1.3, 0.25)])))
    cv.fill(p.outline(cv, lf, 0.003), hexc("#0a2a12"))
    paint(cv, lf, leaf, "#145a26", width=r * 0.3)
    for k in range(8):
        a = k * math.tau / 8 + 0.2
        cv.fill(L.S([(0, 0), (math.cos(a) * 0.85, math.sin(a) * 0.85)], 0.015), hexc("#1d6a32"))
    for k in range(8):
        a = k * math.tau / 8
        pe = L.E(-0.3 + math.cos(a) * 0.22, -0.3 + math.sin(a) * 0.22, 0.25, 0.1, math.degrees(a))
        cv.fill(pe, hexc(flower))
    cv.fill(L.E(-0.3, -0.3, 0.1, 0.1), hexc("#ffe14a"))
