"""Mural do baú rosa (T-218): gueixa no estilo ukiyo-e, grande onda, sol nascente, Fuji, sakura e tubos de neon.
Arte 100% NOSSA, desenhada aqui por código (formas geométricas em numpy, semente fixa); nenhuma imagem de terceiros.
Registrada em docs/CREDITOS_MURAIS.md. Sem texto/kanji (não há o que espelhar).

Saídas (linha 0 = topo):
  mural_geisha.png       2048 x 512, cor (de dia os neons aparecem como tubos coloridos pintados);
  mural_geisha_emit.png  1024 x 256, emissão para a noite: a arte escurecida + os neons fortes.
Coordenadas do desenho: x de 0 a 4 (esquerda -> direita), y de 0 (topo) a 1 (base).
Cada forma só mexe na janela (retângulo) dela: o mural sai em segundos, não em minutos.
"""
from __future__ import annotations

import math
import os

import numpy as np

W, H = 2048, 512
SS = 2                                     # supersample (desenha 4096 x 1024 e reduz)


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


class Canvas:
    def __init__(self):
        self.w, self.h = W * SS, H * SS
        ys, xs = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.x = (xs + 0.5) / self.h          # 0..4
        self.y = (ys + 0.5) / self.h          # 0..1
        self.px = 1.0 / self.h
        self.rgb = np.zeros((self.h, self.w, 3), np.float32)
        self.neon = np.zeros((self.h, self.w, 3), np.float32)

    def fill(self, layer, color, neon=False):
        """`layer` = (cobertura da janela, (r0, r1, c0, c1)); `color` = cor RGB ou imagem da tela inteira."""
        a, (r0, r1, c0, c1) = layer
        if a.size == 0:
            return
        a = np.clip(a, 0.0, 1.0)[..., None]
        c = np.asarray(color, np.float32)
        if c.ndim == 3:
            c = c[r0:r1, c0:c1]
        rgb = self.rgb[r0:r1, c0:c1]
        self.rgb[r0:r1, c0:c1] = rgb * (1 - a) + c * a
        nn = self.neon[r0:r1, c0:c1]
        self.neon[r0:r1, c0:c1] = np.maximum(nn, c * a) if neon else nn * (1 - a)

    def win(self, x0, y0, x1, y1):
        c0, c1 = max(0, int(x0 * self.h) - 2), min(self.w, int(x1 * self.h) + 3)
        r0, r1 = max(0, int(y0 * self.h) - 2), min(self.h, int(y1 * self.h) + 3)
        c1, r1 = max(c1, c0), max(r1, r0)
        return (r0, r1, c0, c1), self.x[r0:r1, c0:c1], self.y[r0:r1, c0:c1]

    def aa(self, d):
        """Cobertura suave a partir da distância assinada (negativa = dentro)."""
        return np.clip(0.5 - d / (self.px * 1.5), 0.0, 1.0)


def E(cv, cx, cy, rx, ry, rot=0.0):
    """Elipse cheia (cobertura suave) na janela dela."""
    r = max(rx, ry)
    win, X, Y = cv.win(cx - r, cy - r, cx + r, cy + r)
    x, y = X - cx, Y - cy
    if rot:
        c, s = math.cos(rot), math.sin(rot)
        x, y = x * c + y * s, -x * s + y * c
    k = np.sqrt((x / rx) ** 2 + (y / ry) ** 2)
    return cv.aa((k - 1.0) * min(rx, ry)), win


def P(cv, pts):
    """Polígono cheio (0/1; o supersample suaviza) na janela dele."""
    p = np.asarray(pts, np.float32)
    (x0, y0), (x1, y1) = p.min(0), p.max(0)
    win, X, Y = cv.win(x0, y0, x1, y1)
    inside = np.zeros(X.shape, bool)
    n = len(p)
    for i in range(n):
        xa, ya = p[i]
        xb, yb = p[(i + 1) % n]
        cond = (ya > Y) != (yb > Y)
        xint = (xb - xa) * (Y - ya) / (yb - ya if yb != ya else 1e-9) + xa
        inside ^= cond & (X < xint)
    return inside.astype(np.float32), win


def S(cv, pts, width):
    """Traço grosso por uma polilinha, suave."""
    p = np.asarray(pts, np.float32)
    (x0, y0), (x1, y1) = p.min(0) - width * 3, p.max(0) + width * 3
    win, X, Y = cv.win(x0, y0, x1, y1)
    d = np.full(X.shape, 1e9, np.float32)
    for (xa, ya), (xb, yb) in zip(p[:-1], p[1:]):
        vx, vy = xb - xa, yb - ya
        L2 = max(vx * vx + vy * vy, 1e-12)
        t = np.clip(((X - xa) * vx + (Y - ya) * vy) / L2, 0, 1)
        d = np.minimum(d, np.hypot(X - (xa + t * vx), Y - (ya + t * vy)))
    return cv.aa(d - width), win


def mul(layer, k):
    """Camada x número, ou camada x outra camada (máscara), na janela da primeira."""
    a, win = layer
    if not isinstance(k, tuple):
        return a * k, win
    b, wb = k
    out = np.zeros_like(a)
    r0, r1, c0, c1 = win
    q0, q1, d0, d1 = wb
    rr0, rr1, cc0, cc1 = max(r0, q0), min(r1, q1), max(c0, d0), min(c1, d1)
    if rr1 > rr0 and cc1 > cc0:
        out[rr0 - r0:rr1 - r0, cc0 - c0:cc1 - c0] = (a[rr0 - r0:rr1 - r0, cc0 - c0:cc1 - c0] *
                                                     b[rr0 - q0:rr1 - q0, cc0 - d0:cc1 - d0])
    return out, win


def _neon(cv, pts, color, width=0.006):
    """Tubo de neon: halo largo e fraco + núcleo claro (cor e emissão)."""
    col = _hex(color)
    cv.fill(mul(S(cv, pts, width * 3.0), 0.35), col, neon=True)
    cv.fill(S(cv, pts, width), col, neon=True)
    cv.fill(S(cv, pts, width * 0.4), col * 0.35 + 0.65, neon=True)


def _arc(cx, cy, rx, ry, a0, a1, n=48):
    return [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in np.linspace(a0, a1, n)]


def _sky(cv):
    stops = [(0.0, "#1c0b3d"), (0.35, "#6a1b7a"), (0.62, "#e8457f"), (0.82, "#ff8a5c"), (1.0, "#ffc27a")]
    ys = np.array([s[0] for s in stops])
    cols = np.stack([_hex(s[1]) for s in stops])
    cv.rgb[:] = np.stack([np.interp(cv.y, ys, cols[:, k]) for k in range(3)], -1)
    rng = np.random.default_rng(218)
    for _ in range(140):                                     # estrelas pequenas no alto
        x, y = rng.uniform(0, 4), rng.uniform(0, 0.3)
        r = rng.uniform(0.0015, 0.004)
        cv.fill(mul(E(cv, x, y, r, r), 0.8), _hex("#fff4d8"))


def _sun(cv, cx=3.3, cy=0.5, r=0.34):
    win, X, Y = cv.win(0.0, 0.0, 4.0, 1.0)
    ang = np.arctan2(Y - cy, X - cx)
    rays = (np.floor((ang + math.pi) / (math.pi / 12)) % 2 == 0)
    dist = np.hypot(X - cx, Y - cy)
    cv.fill((rays * np.clip(1.2 - dist / 1.6, 0, 1) * 0.28, win), _hex("#ffd36b"))
    win, X, Y = cv.win(cx - r, cy - r, cx + r, cy + r)
    g = np.clip((Y - (cy - r)) / (2 * r), 0, 1)[..., None]
    col = np.zeros(cv.rgb.shape, np.float32)
    col[win[0]:win[1], win[2]:win[3]] = _hex("#ffcf4a") * (1 - g) + _hex("#e8203c") * g
    cv.fill((cv.aa(np.hypot(X - cx, Y - cy) - r), win), col)
    _neon(cv, _arc(cx, cy, r + 0.025, r + 0.025, 180, 360, 64), "#ff4fb4", 0.005)


def _fuji(cv):
    cv.fill(P(cv, [(1.45, 0.86), (1.82, 0.47), (1.9, 0.45), (1.98, 0.47), (2.35, 0.86)]), _hex("#3b2a78"))
    snow = [(1.7, 0.6), (1.82, 0.47), (1.9, 0.45), (1.98, 0.47), (2.1, 0.6), (2.04, 0.58), (1.98, 0.62), (1.92, 0.57),
            (1.86, 0.63), (1.8, 0.58), (1.75, 0.62)]
    cv.fill(P(cv, snow), _hex("#f4f1ff"))


def _wave_main(cv):
    """Grande onda à esquerda (corpo azul com faixas, crista branca em "garras")."""
    body = [(0.0, 1.0), (0.0, 0.42), (0.12, 0.3), (0.3, 0.18), (0.52, 0.11), (0.74, 0.1), (0.95, 0.14), (1.1, 0.22),
            (1.18, 0.32), (1.16, 0.42), (1.08, 0.46), (1.0, 0.42), (0.98, 0.34), (0.9, 0.3), (0.86, 0.36), (0.9, 0.5),
            (1.05, 0.66), (1.3, 0.8), (1.6, 0.9), (1.8, 1.0)]
    m = P(cv, body)
    win = m[1]
    Y = cv.y[win[0]:win[1], win[2]:win[3]]
    t = np.clip((Y - 0.1) / 0.9, 0, 1)[..., None]
    col = np.zeros(cv.rgb.shape, np.float32)
    col[win[0]:win[1], win[2]:win[3]] = _hex("#2f6fd0") * (1 - t) + _hex("#0d1f5c") * t
    cv.fill(m, col)
    for k in range(7):                                       # faixas claras que seguem o corpo da onda (curvas suaves)
        off = 0.06 + k * 0.07
        line = []
        for s in np.linspace(0, 1, 24):
            x = 0.02 + off * 0.3 + s * (1.15 + off * 0.4)
            y = 0.47 + off - 0.32 * math.sin(math.pi * min(1.0, s * 1.25)) * (1 - off * 0.6) + s * s * 0.25
            line.append((x, y))
        cv.fill(mul(mul(S(cv, line, 0.004), m), 0.7), _hex("#9cc8ff"))
    crest = [(0.12, 0.3), (0.3, 0.18), (0.52, 0.11), (0.74, 0.1), (0.95, 0.14), (1.1, 0.22), (1.18, 0.32), (1.16, 0.42),
             (1.08, 0.46)]
    for (xa, ya), (xb, yb) in zip(crest[:-1], crest[1:]):  # espuma em garras
        for s in np.linspace(0, 1, 5, endpoint=False):
            x, y = xa + (xb - xa) * s, ya + (yb - ya) * s
            cv.fill(E(cv, x, y, 0.035, 0.03), _hex("#f2f6ff"))
            cv.fill(E(cv, x + 0.012, y + 0.016, 0.014, 0.012), _hex("#2f6fd0"))
    for k, (x, y) in enumerate(((1.24, 0.3), (1.3, 0.38), (1.22, 0.45), (1.33, 0.5), (1.27, 0.24))):
        r = 0.012 + 0.004 * (k % 2)
        cv.fill(E(cv, x, y, r, r), _hex("#f2f6ff"))
    _neon(cv, crest, "#3ff0ff", 0.0055)


def _sea(cv):
    """Faixa de ondas seigaiha (arcos concêntricos) na base, a largura toda."""
    y0 = 0.84
    win, X, Y = cv.win(0, y0 - 0.01, 4, 1)
    cv.fill((np.clip((Y - y0) * 50, 0, 1), win), _hex("#122a6b"))
    r = 0.07
    for i in range(4):
        yy = y0 + 0.02 + i * r * 0.5
        for xx in np.arange(-r + (i % 2) * r, 4 + r, 2 * r):
            cy = yy + r * 0.5
            for k, col in enumerate(("#f2f6ff", "#2f6fd0", "#f2f6ff", "#122a6b")):
                rr = r * (1 - k * 0.24)
                a, w = E(cv, xx, cy, rr, rr)
                Yw = cv.y[w[0]:w[1], w[2]:w[3]]
                cv.fill((a * ((Yw < cy) & (Yw > y0)), w), _hex(col))


def _geisha(cv, cx=2.55, cy=0.43):
    hair = _hex("#0e0a16")
    for (dx, dy, rx, ry) in ((0, -0.08, 0.22, 0.22), (-0.19, 0.0, 0.1, 0.15), (0.19, 0.0, 0.1, 0.15), (0, -0.27, 0.19, 0.1),
                             (0, -0.34, 0.1, 0.06)):
        cv.fill(E(cv, cx + dx, cy + dy, rx, ry), hair)
    for (dx, dy, rx, ry, a) in ((-0.09, -0.29, 0.08, 0.02, -0.35), (0.09, -0.29, 0.08, 0.02, 0.35), (-0.2, 0.0, 0.025, 0.1, 0.2),
                                (0.2, 0.0, 0.025, 0.1, -0.2)):
        cv.fill(mul(E(cv, cx + dx, cy + dy, rx, ry, a), 0.5), _hex("#4a3a8f"))    # brilho azulado do cabelo
    cv.fill(P(cv, [(cx - 0.05, cy + 0.1), (cx + 0.05, cy + 0.1), (cx + 0.065, cy + 0.24), (cx - 0.065, cy + 0.24)]), _hex("#f3e6df"))
    robe = [(cx - 0.5, 1.0), (cx - 0.38, cy + 0.26), (cx - 0.12, cy + 0.19), (cx, cy + 0.38), (cx + 0.12, cy + 0.19),
            (cx + 0.38, cy + 0.26), (cx + 0.52, 1.0)]
    rm = P(cv, robe)
    cv.fill(rm, _hex("#b3122e"))
    rng = np.random.default_rng(7)
    for _ in range(30):                                      # sakura no kimono
        _sakura(cv, rng.uniform(cx - 0.44, cx + 0.46), rng.uniform(cy + 0.28, 0.98), rng.uniform(0.018, 0.03), rm)
    for k, col in enumerate(("#f7f3ee", "#e8325a", "#f7f3ee")):   # golas em camadas (V)
        o = 0.025 * k
        collar = [(cx - 0.13 + o, cy + 0.19), (cx, cy + 0.38 - o), (cx + 0.13 - o, cy + 0.19),
                  (cx + 0.11 - o, cy + 0.19), (cx, cy + 0.34 - o), (cx - 0.11 + o, cy + 0.19)]
        cv.fill(P(cv, collar), _hex(col))
    cv.fill(P(cv, [(cx - 0.48, 0.94), (cx + 0.5, 0.94), (cx + 0.51, 1.0), (cx - 0.49, 1.0)]), _hex("#e0a526"))
    cv.fill(E(cv, cx, cy, 0.105, 0.14), _hex("#f8f0ea"))                   # rosto
    cv.fill(E(cv, cx, cy - 0.115, 0.1, 0.048), hair)                      # franja
    for sx in (-1, 1):
        cv.fill(mul(E(cv, cx + sx * 0.06, cy + 0.045, 0.03, 0.018), 0.35), _hex("#f07a8a"))
        cv.fill(S(cv, _arc(cx + sx * 0.045, cy - 0.005, 0.03, 0.012, 200, 340, 12), 0.0035), _hex("#1a0d12"))
        cv.fill(S(cv, _arc(cx + sx * 0.045, cy - 0.012, 0.032, 0.014, 210, 330, 12), 0.0025), _hex("#d42b4a"))
        cv.fill(S(cv, _arc(cx + sx * 0.05, cy - 0.04, 0.035, 0.012, 205, 335, 12), 0.0022), _hex("#2a1a20"))
    cv.fill(mul(S(cv, [(cx + 0.004, cy + 0.02), (cx, cy + 0.05)], 0.0018), 0.6), _hex("#c9a49a"))
    cv.fill(E(cv, cx, cy + 0.085, 0.022, 0.009), _hex("#d0102e"))
    cv.fill(E(cv, cx, cy + 0.08, 0.014, 0.006), _hex("#ff3a5a"))
    # pente dourado na frente do coque, grampos (kanzashi) e flores penduradas
    cv.fill(E(cv, cx, cy - 0.19, 0.075, 0.014), _hex("#f2c14e"))
    for (dx, a) in ((0.13, -0.6), (0.17, -0.3), (-0.15, 0.5)):
        x0, y0 = cx + dx, cy - 0.22
        x1, y1 = x0 + math.sin(a) * 0.16, y0 - math.cos(a) * 0.16
        cv.fill(S(cv, [(x0, y0), (x1, y1)], 0.004), _hex("#f2c14e"))
        cv.fill(E(cv, x1, y1, 0.016, 0.016), _hex("#ff6fae"))
    for k in range(5):
        _sakura(cv, cx + 0.2 + 0.012 * k, cy - 0.15 + 0.045 * k, 0.02, None, "#ffd1e6" if k % 2 else "#ff6fae")
    _neon(cv, _arc(cx, cy - 0.08, 0.235, 0.235, 160, 380, 60), "#b46cff", 0.0045)
    _neon(cv, [(cx - 0.38, cy + 0.26), (cx - 0.12, cy + 0.19), (cx, cy + 0.38), (cx + 0.12, cy + 0.19), (cx + 0.38, cy + 0.26)],
          "#ff4fb4", 0.0045)


def _sakura(cv, x, y, r, clip=None, color="#ffd1e6"):
    col = _hex(color)
    for k in range(5):
        t = math.tau * k / 5 - math.pi / 2
        petal = E(cv, x + math.cos(t) * r * 0.55, y + math.sin(t) * r * 0.55, r * 0.5, r * 0.36, t)
        cv.fill(mul(petal, clip) if clip is not None else petal, col)
    c = E(cv, x, y, r * 0.2, r * 0.2)
    cv.fill(mul(c, clip) if clip is not None else c, _hex("#e0a526"))


def _petals(cv):
    rng = np.random.default_rng(2218)
    for _ in range(70):
        x, y = rng.uniform(0.9, 4.0), rng.uniform(0.05, 0.85)
        r = rng.uniform(0.006, 0.013)
        cv.fill(mul(E(cv, x, y, r, r * 0.6, rng.uniform(0, math.pi)), 0.9), _hex("#ffc6dd"))
    for _ in range(9):
        _sakura(cv, rng.uniform(3.0, 3.95), rng.uniform(0.05, 0.3), rng.uniform(0.025, 0.04))


def _border(cv):
    _neon(cv, [(0.0, 0.012), (4.0, 0.012)], "#ff4fb4", 0.005)
    _neon(cv, [(0.0, 0.988), (4.0, 0.988)], "#3ff0ff", 0.005)


def _down(a, w, h):
    hh, ww = a.shape[:2]
    return a.reshape(h, hh // h, w, ww // w, -1).mean((1, 3))


def make():
    """(cor 2048x512x3, emissão 1024x256x3), linha 0 = topo, valores sRGB 0..1."""
    cv = Canvas()
    _sky(cv)
    _sun(cv)
    _fuji(cv)
    _petals(cv)
    _sea(cv)
    _wave_main(cv)
    _geisha(cv)
    _border(cv)
    col = _down(cv.rgb, W, H)
    emit = _down(cv.rgb * 0.32 + cv.neon * 1.0, W // 2, H // 2)
    return np.clip(col, 0, 1), np.clip(emit, 0, 1)


def ensure(out_dir: str) -> dict:
    """Grava os dois PNGs em `out_dir` (determinístico: mesmos pixels sempre)."""
    from . import tex
    col, emit = make()
    paths = {"albedo": os.path.join(out_dir, "mural_geisha.png"), "emit": os.path.join(out_dir, "mural_geisha_emit.png")}
    tex.save_png(col[::-1], paths["albedo"])
    tex.save_png(emit[::-1], paths["emit"])
    return paths
