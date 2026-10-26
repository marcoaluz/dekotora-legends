"""Figuras humanas de frente da T-232: mulher de quimono (bijin) e guerreiro samurai (musha), meio corpo.
Desenhos nossos por código; os tipos seguem as gravuras de bijin-ga (Utamaro, Eishi) e de guerreiros (Kuniyoshi),
sem copiar nenhuma obra. Quadro local: centro do rosto em (0, 0), rosto ~0,6 de largura; o corpo desce até y ~ 2.
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from . import t232_kit as K
from .paint2d import hexc
from .t232_kit import Local, neon_line, paint

INK = "#160a10"
SKIN = "#fbf1ea"


def _clip_sakura(cv, L, mask, n, seed, box, color="#ffd1e6"):
    rng = np.random.default_rng(seed)
    for _ in range(n):
        x, y = rng.uniform(box[0], box[2]), rng.uniform(box[1], box[3])
        r = rng.uniform(0.05, 0.09)
        cx, cy = L.pt(x, y)
        for k in range(5):
            t = math.tau * k / 5 - math.pi / 2
            pe = p.E(cv, cx + math.cos(t) * r * L.s * 0.55, cy + math.sin(t) * r * L.s * 0.55, r * L.s * 0.5, r * L.s * 0.36, t)
            cv.fill(p.mul(pe, mask), hexc(color))
        cv.fill(p.mul(p.C(cv, cx, cy, r * L.s * 0.2), mask), hexc("#e0a526"))


def bijin(cv, L: Local, hair="updo", robe="#b3122e", robe2="#5a0a1e", obi="#e0a526", prop=None, eyes_closed=True,
          pattern="sakura", seed=3):
    """Mulher de quimono de frente. hair: "updo" (coque com grampos) ou "long" (solto). prop: "fan" | "umbrella" | None."""
    if prop == "umbrella":
        cx, cy = 0.5, -0.8
        can = L.sdf((-1.2, -1.6, 2.3, -0.2), lambda x, y: np.maximum(p.sd_ellipse(x, y, cx, cy, 1.25, 0.52, -0.18),
                                                                     (y - cy - 0.15 - (x - cx) * 0.3)))
        cv.fill(p.outline(cv, can, 0.006), hexc(INK))
        lx, ly = L.local_xy(can)
        ang = np.arctan2(ly - cy, lx - cx)
        rib = np.clip(1 - np.abs(((ang * 12 / math.pi) % 1.0) - 0.5) * 8, 0, 1)
        col = p.mix(hexc("#d61f36"), hexc("#ff6a5a"), (0.5 + 0.5 * np.cos(ang * 12))[..., None] * 0.4)
        col = p.mix(col, hexc("#7a0a14"), rib[..., None] * 0.7)
        ring = np.clip(1 - np.abs(np.hypot((lx - cx) / 1.25, (ly - cy) / 0.52) - 0.55) / 0.04, 0, 1)
        col = p.mix(col, hexc("#fff4e0"), ring[..., None])
        cv.fill(can, col)
        cv.fill(L.S([(cx - 0.05, cy + 0.02), (0.35, 1.3)], 0.018), hexc("#3a1a0a"))
    # cabelo de trás
    if hair == "long":
        back = L.sdf((-1.0, -0.8, 1.0, 1.7), lambda x, y: p.smin(p.sd_ellipse(x, y, 0, -0.05, 0.5, 0.55),
                                                                 p.sd_poly(x, y, [(-0.48, 0.0), (0.48, 0.0), (0.7, 1.6), (-0.7, 1.6)]), 0.15))
        cv.fill(p.outline(cv, back, 0.006), hexc("#2a2a40"))
        paint(cv, back, "#0e0a16", "#2a2a48", width=0.05 * L.s)
        for k in range(9):
            x = -0.6 + k * 0.15
            cv.fill(p.mul(L.S(p.spline([(x * 0.6, -0.3), (x * 0.9, 0.5), (x * 1.1, 1.5)], 8), 0.006), 0.5), hexc("#4a4a7a"))
    else:
        for dx, dy, rx, ry in ((0, -0.42, 0.42, 0.28), (-0.4, -0.12, 0.17, 0.22), (0.4, -0.12, 0.17, 0.22), (0, -0.72, 0.32, 0.16),
                               (0, -0.84, 0.16, 0.09)):
            e = L.E(dx, dy, rx, ry)
            cv.fill(p.outline(cv, e, 0.005), hexc("#2a2a40"))
            paint(cv, e, "#0e0a16", "#2a2a48", width=0.04 * L.s, light="#6a6aaa")
    # pescoço e quimono
    cv.fill(L.P([(-0.1, 0.3), (0.1, 0.3), (0.13, 0.62), (-0.13, 0.62)]), hexc("#f3e2d8"))
    robe_pts = [(-1.05, 2.1), (-0.85, 0.75), (-0.32, 0.56), (0.0, 0.95), (0.32, 0.56), (0.85, 0.75), (1.05, 2.1)]
    rm = L.P(robe_pts)
    cv.fill(p.outline(cv, rm, 0.006), hexc(INK))
    lx, ly = L.local_xy(rm)
    cv.fill(rm, p.grad_t((ly - 0.5) / 1.5, [(0, robe), (1, robe2)]))
    if pattern == "sakura":
        _clip_sakura(cv, L, rm, 26, seed, (-0.95, 0.65, 0.95, 2.0))
    elif pattern == "wave":
        X, Y = cv.coords(rm)
        lx, ly = L.to_local(X, Y)
        r = 0.12
        row = np.floor(ly / (r * 0.5))
        cx_ = (np.floor((lx + (row % 2) * r) / (2 * r)) * 2 + 1) * r - (row % 2) * r
        d = np.hypot(lx - cx_, ly - (row + 1) * r * 0.5)
        bands = (np.floor(d / (r * 0.24)) % 2 == 0) & (d < r)
        cv.fill(p.mul(rm, bands.astype(np.float32) * 0.45), hexc("#f2f6ff"))
    for k, col in enumerate(("#f7f3ee", "#e8325a", "#f7f3ee")):
        o = 0.05 * k
        cv.fill(L.P([(-0.34 + o, 0.56), (0.0, 0.98 - o * 1.2), (0.34 - o, 0.56), (0.3 - o, 0.56), (0.0, 0.9 - o * 1.2), (-0.3 + o, 0.56)]),
                hexc(col))
    ob = L.P([(-0.92, 1.45), (0.92, 1.45), (0.95, 1.75), (-0.95, 1.75)])
    cv.fill(p.outline(cv, ob, 0.004), hexc(INK))
    cv.fill(ob, hexc(obi))
    for k in range(6):
        cv.fill(L.S([(-0.9 + k * 0.36, 1.5), (-0.75 + k * 0.36, 1.7)], 0.01), hexc("#b07a10"))
    cv.fill(L.S([(-0.93, 1.6), (0.93, 1.6)], 0.012), hexc("#d61f36"))
    # rosto
    f = L.E(0, 0, 0.27, 0.36)
    cv.fill(p.outline(cv, f, 0.005), hexc("#c9a090"))
    paint(cv, f, SKIN, "#ecd6cc", width=0.05 * L.s)
    if hair == "updo":
        cv.fill(L.E(0, -0.3, 0.27, 0.12), hexc("#0e0a16"))
        cv.fill(L.E(0, -0.53, 0.2, 0.04), hexc("#f2c14e"))
        for dx, a in ((0.3, -0.55), (0.38, -0.25), (-0.33, 0.45)):
            x0, y0 = dx, -0.6
            x1, y1 = x0 + math.sin(a) * 0.45, y0 - math.cos(a) * 0.45
            cv.fill(L.S([(x0, y0), (x1, y1)], 0.012), hexc("#f2c14e"))
            cv.fill(L.E(x1, y1, 0.045, 0.045), hexc("#ff6fae"), neon=0.4)
        for k in range(5):
            K.sakura(cv, *L.pt(0.48 + 0.03 * k, -0.4 + 0.12 * k), 0.05 * L.s, color="#ffd1e6" if k % 2 else "#ff6fae")
    else:
        cv.fill(L.P(p.spline([(-0.3, 0.0), (-0.25, -0.3), (0.0, -0.38), (0.25, -0.3), (0.3, 0.0)], 8) + [(0.3, -0.45), (-0.3, -0.45)]),
                hexc("#0e0a16"))
        K.sakura(cv, *L.pt(0.25, -0.33), 0.07 * L.s, color="#ff6fae")
    def feats(s):
        cv.fill(p.mul(L.E(s * 0.15, 0.12, 0.08, 0.05), 0.35), hexc("#f07a8a"))
        if eyes_closed:
            cv.fill(L.S(p.arc(s * 0.11, -0.01, 0.075, 0.03, 200, 340, 12), 0.008), hexc(INK))
        else:
            e = L.E(s * 0.11, -0.01, 0.07, 0.025)
            cv.fill(e, hexc("#ffffff"))
            cv.fill(L.E(s * 0.11, -0.01, 0.025, 0.025), hexc(INK))
        cv.fill(L.S(p.arc(s * 0.11, -0.03, 0.08, 0.035, 210, 330, 12), 0.006), hexc("#d42b4a"))
        cv.fill(L.S(p.arc(s * 0.12, -0.11, 0.085, 0.03, 205, 335, 12), 0.006), hexc("#2a1a20"))
    for s in (-1, 1):
        feats(s)
    cv.fill(L.E(0, 0.23, 0.05, 0.022), hexc("#d0102e"))
    cv.fill(L.E(0, 0.22, 0.03, 0.012), hexc("#ff3a5a"))
    if prop == "fan":
        _fan(cv, L, 0.62, 0.55)


def _fan(cv, L, x, y):
    """Leque aberto (sensu) com o sol vermelho e ondas, segurado por uma mão."""
    piv = (x - 0.05, y + 0.45)
    can = L.sdf((x - 1.0, y - 0.9, x + 1.0, y + 0.6), lambda lx, ly: np.maximum(np.maximum(
        p.sd_circle(lx, ly, *piv, 0.9), -p.sd_circle(lx, ly, *piv, 0.3)),
        np.abs(np.arctan2(lx - piv[0], -(ly - piv[1])) - 0.15) - 1.0))
    cv.fill(p.outline(cv, can, 0.006), hexc(INK))
    lx, ly = L.local_xy(can)
    ang = np.arctan2(lx - piv[0], -(ly - piv[1]))
    col = p.grad_t(np.hypot(lx - piv[0], ly - piv[1]) / 0.9, [(0.3, "#fff4e0"), (1, "#ffd9a0")])
    sun_d = np.hypot(lx - piv[0] - 0.1, ly - piv[1] + 0.62) - 0.16
    col = np.where((sun_d < 0)[..., None], hexc("#e8202c"), col).astype(np.float32)
    rib = np.clip(1 - np.abs(((ang * 14 / math.pi) % 1.0) - 0.5) * 10, 0, 1)
    col = p.mix(col, hexc("#b07a3a"), rib[..., None] * 0.5)
    cv.fill(can, col)
    neon_line(cv, L.pts(p.arc(piv[0], piv[1], 0.9, 0.9, -90 - 52, -90 + 75, 40)), "#ff4fb4", 0.003 * L.s / 0.4)
    hand = L.E(piv[0], piv[1] + 0.05, 0.09, 0.07, 30)
    cv.fill(p.outline(cv, hand, 0.003), hexc("#c9a090"))
    cv.fill(hand, hexc(SKIN))


def warrior(cv, L: Local, armor="#1a2a6b", lace="#d61f36", crest="kuwagata", menpo="#b8101e", sword_side=1):
    """Samurai de frente: elmo (kabuto) com crista dourada, máscara (menpo), armadura em lâminas com cordões, ombreiras
    largas e a espada erguida. crest: "kuwagata" (chifres em V com sol) ou "moon" (lua crescente)."""
    # espada (atrás do braço)
    s = sword_side
    blade = [(s * 0.55, 0.95), (s * 1.55, -1.1), (s * 1.6, -1.18), (s * 1.62, -1.08), (s * 0.62, 1.0)]
    bl = L.P(blade)
    cv.fill(p.outline(cv, bl, 0.004), hexc(INK))
    lx, ly = L.local_xy(bl)
    cv.fill(bl, p.grad_t((ly + 1.1) / 2.1, [(0, "#ffffff"), (0.5, "#b8c8e0"), (1, "#6a7a9a")]))
    neon_line(cv, L.pts([(s * 0.6, 0.97), (s * 1.6, -1.15)]), "#9fe8ff", 0.0025 * L.s / 0.4, 0.8)
    cv.fill(L.E(s * 0.55, 0.98, 0.1, 0.03, s * -60), hexc("#e0a526"))
    cv.fill(L.S([(s * 0.53, 1.0), (s * 0.4, 1.25)], 0.035), hexc("#2a0a0a"))
    # corpo: dō (peito) com fileiras de lâminas e ombreiras (sode)
    for sx in (-1, 1):
        so = L.P([(sx * 0.45, 0.62), (sx * 1.1, 0.75), (sx * 1.15, 1.6), (sx * 0.6, 1.5)])
        cv.fill(p.outline(cv, so, 0.006), hexc(INK))
        cv.fill(so, hexc(armor))
        for k in range(6):
            y = 0.72 + k * 0.15
            cv.fill(L.S([(sx * 0.47, y), (sx * 1.12, y + 0.12)], 0.008), hexc("#c9a040"))
            for j in range(6):
                t = (j + 0.5) / 6
                cv.fill(L.E(sx * (0.48 + 0.64 * t), y + 0.06 + 0.12 * t, 0.012, 0.02), hexc(lace))
    do = L.P([(-0.55, 0.62), (0.55, 0.62), (0.62, 2.1), (-0.62, 2.1)])
    cv.fill(p.outline(cv, do, 0.006), hexc(INK))
    lx, ly = L.local_xy(do)
    cv.fill(do, p.grad_t(np.abs(lx) / 0.6, [(0, "#3a4a9a"), (1, armor)]))
    for k in range(9):
        y = 0.75 + k * 0.15
        cv.fill(L.S([(-0.58, y), (0.58, y)], 0.008), hexc("#c9a040"))
        for j in range(10):
            cv.fill(L.E(-0.5 + j * 0.111, y + 0.07, 0.012, 0.025), hexc(lace))
    cv.fill(L.E(0, 1.05, 0.18, 0.18), hexc("#e0a526"))
    cv.fill(L.E(0, 1.05, 0.12, 0.12), hexc(lace))
    # braço erguido (do lado da espada)
    arm = L.SV([(s * 0.5, 0.8), (s * 0.75, 1.15), (s * 0.58, 1.0)], [0.14, 0.12, 0.1])[0]
    cv.fill(p.outline(cv, arm, 0.005), hexc(INK))
    cv.fill(arm, hexc(armor))
    cv.fill(L.E(s * 0.57, 0.98, 0.1, 0.09), hexc("#3a2010"))
    # cabeça: rosto com menpo, elmo, crista
    cv.fill(L.P([(-0.2, 0.3), (0.2, 0.3), (0.24, 0.66), (-0.24, 0.66)]), hexc("#2a1a10"))
    f = L.E(0, 0.0, 0.26, 0.33)
    cv.fill(p.outline(cv, f, 0.005), hexc(INK))
    cv.fill(f, hexc("#f0d0b0"))
    for sx in (-1, 1):
        cv.fill(L.SV(p.spline([(sx * 0.04, -0.12), (sx * 0.14, -0.17), (sx * 0.24, -0.12)], 8), [0.02, 0.035, 0.01])[0], hexc(INK))
        e = L.E(sx * 0.11, -0.05, 0.065, 0.03, sx * 15)
        cv.fill(p.outline(cv, e, 0.004), hexc(INK))
        cv.fill(e, hexc("#ffffff"))
        cv.fill(L.E(sx * 0.1, -0.05, 0.02, 0.02), hexc(INK))
    mp = L.sdf((-0.35, 0.0, 0.35, 0.45), lambda x, y: p.sd_poly(x, y, [(-0.28, 0.05), (0.28, 0.05), (0.24, 0.3), (0.0, 0.42), (-0.24, 0.3)]))
    cv.fill(p.outline(cv, mp, 0.005), hexc(INK))
    paint(cv, mp, menpo, "#5a0610", width=0.04 * L.s)
    for sx in (-1, 1):
        cv.fill(L.SV(p.spline([(sx * 0.03, 0.17), (sx * 0.15, 0.2), (sx * 0.27, 0.32)], 8), [0.02, 0.025, 0.005])[0], hexc("#f4f0ea"))
    cv.fill(L.S([(-0.08, 0.27), (0.08, 0.27)], 0.012), hexc(INK))
    # elmo: tigela + aba (shikoro) + fukigaeshi
    sh = L.P([(-0.62, -0.25), (0.62, -0.25), (0.75, 0.32), (0.36, 0.25), (0.3, -0.2), (-0.3, -0.2), (-0.36, 0.25), (-0.75, 0.32)])
    cv.fill(p.outline(cv, sh, 0.006), hexc(INK))
    cv.fill(sh, hexc(armor))
    for k in range(3):
        cv.fill(L.S([(-0.65 - k * 0.03, -0.08 + k * 0.12), (-0.32, -0.02 + k * 0.08)], 0.008), hexc("#c9a040"))
        cv.fill(L.S([(0.65 + k * 0.03, -0.08 + k * 0.12), (0.32, -0.02 + k * 0.08)], 0.008), hexc("#c9a040"))
    bowl = L.sdf((-0.5, -0.72, 0.5, -0.15), lambda x, y: np.maximum(p.sd_ellipse(x, y, 0, -0.25, 0.45, 0.42), y + 0.24))
    cv.fill(p.outline(cv, bowl, 0.006), hexc(INK))
    lx, ly = L.local_xy(bowl)
    col = p.grad_t((lx + 0.45) / 0.9, [(0, "#0a0a14"), (0.4, "#4a4a6a"), (1, "#0a0a14")])
    rib = np.clip(1 - np.abs(((lx * 12) % 1.0) - 0.5) * 6, 0, 1)
    cv.fill(bowl, p.mix(col, hexc("#c9a040"), rib[..., None] * 0.6))
    cv.fill(L.S([(-0.5, -0.24), (0.5, -0.24)], 0.025), hexc("#c9a040"))
    if crest == "kuwagata":
        for sx in (-1, 1):
            h = L.SV(p.spline([(sx * 0.08, -0.45), (sx * 0.35, -0.8), (sx * 0.48, -1.2)], 10), [0.05, 0.04, 0.012])[0]
            cv.fill(p.outline(cv, h, 0.005), hexc(INK))
            paint(cv, h, "#f2c14e", "#9a6a12", width=0.02 * L.s, light="#fff4c0")
        sun = L.E(0, -0.55, 0.13, 0.13)
        cv.fill(p.outline(cv, sun, 0.004), hexc(INK))
        cv.fill(sun, hexc("#e8202c"), neon=0.6)
    else:
        moon = L.sdf((-0.8, -1.2, 0.8, -0.3), lambda x, y: np.maximum(p.sd_circle(x, y, 0.0, -0.85, 0.62), -p.sd_circle(x, y, 0.0, -1.0, 0.58)))
        cv.fill(p.outline(cv, moon, 0.005), hexc(INK))
        paint(cv, moon, "#f2c14e", "#9a6a12", width=0.03 * L.s, light="#fff4c0", neon=0.3)
