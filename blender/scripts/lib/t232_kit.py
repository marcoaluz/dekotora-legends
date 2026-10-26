"""Kit das pinturas da T-232: quadro local das figuras e os fundos de aerógrafo (céu, raios, sol, lua, nuvens ruyi,
ondas, seigaiha, sakura, chamas, bambu, raio, neve, moldura de neon). Arte nossa, por código (lib/paint2d.py).
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from .paint2d import hexc


class Local:
    """Quadro local de uma figura: ponto (lx, ly) do desenho -> tela (ox + lx*s, oy + ly*s), espelhado em x se `flip`.
    As figuras são desenhadas em unidades próprias (ex.: a cabeça tem 1 de altura) e reaproveitadas em tamanhos,
    lugares e lados diferentes."""

    def __init__(self, cv, ox, oy, s, flip=False, rot=0.0):
        self.cv, self.ox, self.oy, self.s, self.flip, self.rot = cv, ox, oy, s, flip, rot
        self._c, self._s = math.cos(math.radians(rot)), math.sin(math.radians(rot))

    def pt(self, x, y):
        x = -x if self.flip else x
        x, y = x * self._c - y * self._s, x * self._s + y * self._c
        return self.ox + x * self.s, self.oy + y * self.s

    def pts(self, lst):
        return [self.pt(x, y) for x, y in lst]

    def to_local(self, X, Y):
        x, y = (X - self.ox) / self.s, (Y - self.oy) / self.s
        x, y = x * self._c + y * self._s, -x * self._s + y * self._c
        return (-x if self.flip else x), y

    def sdf(self, bbox, fn):
        """Camada da SDF local `fn(x, y)` dentro da caixa local (x0, y0, x1, y1)."""
        x0, y0, x1, y1 = bbox
        cs = [self.pt(x0, y0), self.pt(x1, y0), self.pt(x0, y1), self.pt(x1, y1)]
        xs, ys = [c[0] for c in cs], [c[1] for c in cs]
        win, X, Y = self.cv.win(min(xs), min(ys), max(xs), max(ys))
        lx, ly = self.to_local(X, Y)
        return self.cv.aa(fn(lx, ly) * self.s), win

    def local_xy(self, layer):
        X, Y = self.cv.coords(layer)
        return self.to_local(X, Y)

    def E(self, cx, cy, rx, ry, rot=0.0):
        r = max(rx, ry)
        return self.sdf((cx - r, cy - r, cx + r, cy + r), lambda x, y: p.sd_ellipse(x, y, cx, cy, rx, ry, math.radians(rot)))

    def P(self, pts):
        return p.P(self.cv, self.pts(pts))

    def S(self, pts, w):
        return p.S(self.cv, self.pts(pts), w * self.s)

    def SV(self, pts, radii, need_uv=False):
        return p.SV(self.cv, self.pts(pts), [r * self.s for r in radii], need_uv)


# ---------------------------------------------------------------------- tinta
def paint(cv, layer, base, shade=None, light=None, width=0.03, outline=None, ow=0.006, neon=0.0):
    """Pinta uma forma no estilo aerógrafo: cor `base`, borda escurecida para `shade` (largura `width`), brilho
    `light` em cima, contorno `outline` (largura `ow`)."""
    if outline is not None:
        cv.fill(p.outline(cv, layer, ow), hexc(outline) if isinstance(outline, str) else outline, neon=neon * 0.5)
    b = hexc(base) if isinstance(base, str) else np.asarray(base, np.float32)
    if shade is None:
        cv.fill(layer, b, neon=neon)
    else:
        k = p.inner(cv, layer, width)[0]
        img = p.mix(hexc(shade), b, k[..., None])
        cv.fill(layer, img, neon=neon)
    if light is not None:
        a, win = layer
        X, Y = cv.coords(layer)
        y0 = Y[a > 0.5].min() if (a > 0.5).any() else 0
        y1 = Y[a > 0.5].max() if (a > 0.5).any() else 1
        t = np.clip(1 - (Y - y0) / max(y1 - y0, 1e-6) * 2.2, 0, 1)
        cv.add((a * t * 0.55, win), hexc(light))


def neon_line(cv, pts, color, width=0.005, k=1.0):
    """Tubo de neon: halo + núcleo colorido + miolo claro (vai para a emissão)."""
    col = hexc(color)
    core = p.S(cv, pts, width)
    cv.add(p.glow(cv, core, width * 3.0), col, 0.55 * k, neon=1.0)
    cv.fill(core, col, neon=1.0)
    cv.fill(p.S(cv, pts, width * 0.45), col * 0.3 + 0.7, neon=1.0)


# ---------------------------------------------------------------------- céu e luz
def sky(cv, stops, y0=0.0, y1=1.0):
    win, X, Y = cv.full()
    cv.rgb[...] = p.grad_v(Y, y0, y1, stops)


def stars(cv, n, seed, y_max=0.4, color="#fff4d8"):
    rng = np.random.default_rng(seed)
    for _ in range(n):
        x, y = rng.uniform(0, cv.aspect), rng.uniform(0, y_max)
        r = rng.uniform(0.0015, 0.0045)
        cv.add(p.C(cv, x, y, r), hexc(color), rng.uniform(0.5, 1.0), neon=0.4)


def rays(cv, cx, cy, n, color, alpha=0.3, reach=2.0, a0=0.0):
    win, X, Y = cv.full()
    ang = np.arctan2(Y - cy, X - cx) + a0
    on = (np.floor((ang + math.pi) / (math.pi / n)) % 2 == 0).astype(np.float32)
    fade = np.clip(1.15 - np.hypot(X - cx, Y - cy) / reach, 0, 1)
    cv.fill((on * fade * alpha, win), hexc(color))


def sun(cv, cx, cy, r, top="#ffcf4a", bottom="#e8203c", ring_col="#ff4fb4"):
    win, X, Y = cv.win(cx - r * 1.6, cy - r * 1.6, cx + r * 1.6, cy + r * 1.6)
    cv.add((p.blur(cv.aa(np.hypot(X - cx, Y - cy) - r), int(r * cv.h * 0.35)), win), hexc(top), 0.5)
    lay = p.C(cv, cx, cy, r)
    X, Y = cv.coords(lay)
    cv.fill(lay, p.grad_v(Y, cy - r, cy + r, [(0, top), (1, bottom)]))
    if ring_col:
        neon_line(cv, p.arc(cx, cy, r + 0.02, r + 0.02, 0, 360, 96), ring_col, 0.004)


def moon(cv, cx, cy, r, color="#fff6d6", halo="#bfe3ff"):
    win, X, Y = cv.win(cx - r * 3, cy - r * 3, cx + r * 3, cy + r * 3)
    d = np.hypot(X - cx, Y - cy)
    cv.add((np.clip(1 - (d - r) / (r * 2), 0, 1) ** 2, win), hexc(halo), 0.6, neon=0.5)
    lay = p.C(cv, cx, cy, r)
    X, Y = cv.coords(lay)
    n = p.vnoise(X, Y, r * 0.5, seed=7)
    cv.fill(lay, p.mix(hexc(color), hexc("#e7d7a8"), (n[..., None] - 0.4).clip(0, 1) * 0.8), neon=0.8)


def ruyi(cv, cx, cy, s, fill="#f4f1ff", line="#2a2a6b", flip=False, tail=1.0, shade="#b9c3ef"):
    """Nuvem auspiciosa (ruyi): 3 cachos com espirais e uma cauda de faixas."""
    L = Local(cv, cx, cy, s, flip)
    lobes = [(-0.55, 0.05, 0.32), (0.0, -0.18, 0.42), (0.55, 0.02, 0.34), (0.22, 0.2, 0.3), (-0.25, 0.22, 0.28)]
    shape = L.sdf((-1.0, -0.7, 1.0, 0.6), lambda x, y: np.minimum.reduce([p.sd_circle(x, y, a, b, r) for a, b, r in lobes]))
    if tail > 0:
        for k, dy in enumerate((0.12, 0.3)):
            t = L.SV([(0.6, dy), (1.2 + tail * 0.6, dy + 0.02), (1.7 + tail, dy - 0.02)], [0.09 - k * 0.02, 0.06, 0.012])[0]
            paint(cv, t, fill, shade, width=0.02, outline=line, ow=0.004)
    paint(cv, shape, fill, shade, width=0.05 * s, outline=line, ow=0.005)
    for a, b, r in lobes[:3]:
        sp = [(a + math.cos(t) * r * 0.75 * (1 - t / 9.5), b + math.sin(t) * r * 0.75 * (1 - t / 9.5)) for t in np.linspace(0, 7.5, 50)]
        cv.fill(L.S(sp, 0.012), hexc(line))


def seigaiha(cv, y0, y1, r, colors=("#f2f6ff", "#2f6fd0", "#f2f6ff", "#122a6b"), x0=0.0, x1=None):
    """Faixa de ondas seigaiha (arcos concêntricos em escamas)."""
    x1 = cv.aspect if x1 is None else x1
    win, X, Y = cv.win(x0, y0, x1, y1)
    cv.fill((np.ones_like(X), win), hexc(colors[-1]))
    rows = int((y1 - y0) / (r * 0.5)) + 2
    for i in range(rows):
        cy = y0 + i * r * 0.5 + r * 0.5
        off = (i % 2) * r
        for xx in np.arange(x0 - r + off, x1 + r, 2 * r):
            for k, col in enumerate(colors):
                rr = r * (1 - k * 0.24)
                a, w = p.C(cv, xx, cy, rr)
                Yw = cv.coords((a, w))[1]
                cv.fill((a * ((Yw < cy + 0.001) & (Yw > y0)), w), hexc(col))


def sakura(cv, x, y, r, color="#ffd1e6", center="#e0a526", rot=0.0, line=None):
    L = Local(cv, x, y, r, rot=rot)
    lay = L.sdf((-1.2, -1.2, 1.2, 1.2), lambda lx, ly: _sakura_sd(lx, ly))
    if line:
        cv.fill(p.outline(cv, lay, 0.003), hexc(line))
    paint(cv, lay, color, "#ff8fbf", width=r * 0.6)
    cv.fill(L.E(0, 0, 0.22, 0.22), hexc(center))


def _sakura_sd(x, y):
    d = np.full(x.shape, 1e9, np.float32)
    for k in range(5):
        t = math.tau * k / 5 - math.pi / 2
        cx, cy = math.cos(t) * 0.55, math.sin(t) * 0.55
        e = p.sd_ellipse(x, y, cx, cy, 0.52, 0.38, t)
        notch = p.sd_circle(x, y, math.cos(t) * 1.05, math.sin(t) * 1.05, 0.14)
        d = np.minimum(d, np.maximum(e, -notch))
    return d


def petals(cv, n, seed, box, color="#ffc6dd", size=(0.006, 0.014)):
    rng = np.random.default_rng(seed)
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(*size)
        cv.fill(p.mul(p.E(cv, x, y, r, r * 0.55, rng.uniform(0, math.pi)), 0.9), hexc(color))


def flames(cv, base_pts, height, colors=("#ffe066", "#ff7a1a", "#d61f36"), seed=1, n=9, lean=0.0, line="#3a0610"):
    """Labaredas (línguas que sobem de uma linha de base)."""
    rng = np.random.default_rng(seed)
    base = np.asarray(p.resample(base_pts, n), np.float32)
    for k, col in enumerate(colors):
        sc = 1.0 - k * 0.3
        for i, (bx, by) in enumerate(base):
            h = height * rng.uniform(0.6, 1.1) * sc
            w = height * 0.22 * sc
            tip = (bx + lean * h + rng.uniform(-0.3, 0.3) * w, by - h)
            mid = (bx + lean * h * 0.4 + w * 0.6 * (1 if i % 2 else -1), by - h * 0.5)
            pts = p.spline([(bx - w, by), mid, tip], 10) + p.spline([tip, (bx + w * 0.3, by - h * 0.45), (bx + w, by)], 10)
            lay = p.P(cv, pts)
            if k == 0 and line:
                cv.fill(p.outline(cv, lay, 0.004), hexc(line))
            cv.fill(lay, hexc(col), neon=0.25 if k == 0 else 0.4)


def lightning(cv, pts, color="#c9a7ff", width=0.006):
    neon_line(cv, pts, color, width)


def bamboo(cv, x, y_top, y_bot, w, color="#3e9b4f", dark="#1f5a2c", node="#d8f0a8", flip=False):
    lay = p.P(cv, [(x - w, y_top), (x + w, y_top), (x + w, y_bot), (x - w, y_bot)])
    X, Y = cv.coords(lay)
    t = np.clip((X - (x - w)) / (2 * w), 0, 1)
    img = p.grad_t(np.abs(t - 0.35) * 1.6, [(0, color), (1, dark)])
    cv.fill(lay, img)
    seg = w * 9
    yy = y_top + seg * 0.6
    while yy < y_bot:
        cv.fill(p.E(cv, x, yy, w * 1.15, w * 0.16), hexc(node))
        cv.fill(p.E(cv, x, yy + w * 0.12, w * 1.05, w * 0.08), hexc(dark))
        yy += seg


def bamboo_leaf(cv, x, y, length, angle, color="#57b85f", vein="#245f2f"):
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    tip = (x + dx * length, y + dy * length)
    pts = [(x, y)] + [(x + dx * length * t + nx * length * 0.12 * math.sin(math.pi * t) ** 0.7,
                       y + dy * length * t + ny * length * 0.12 * math.sin(math.pi * t) ** 0.7) for t in np.linspace(0.05, 0.95, 10)]
    pts += [tip] + [(x + dx * length * t - nx * length * 0.12 * math.sin(math.pi * t) ** 0.7,
                     y + dy * length * t - ny * length * 0.12 * math.sin(math.pi * t) ** 0.7) for t in np.linspace(0.95, 0.05, 10)]
    lay = p.P(cv, pts)
    cv.fill(p.outline(cv, lay, 0.003), hexc("#0e2a14"))
    cv.fill(lay, hexc(color))
    cv.fill(p.S(cv, [(x, y), tip], 0.0015), hexc(vein))


def snow(cv, n, seed, box=None, color="#ffffff"):
    rng = np.random.default_rng(seed)
    x0, y0, x1, y1 = box or (0, 0, cv.aspect, 1)
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(0.003, 0.009)
        cv.add(p.C(cv, x, y, r), hexc(color), rng.uniform(0.6, 1.0))


def border(cv, top="#ff4fb4", bottom="#3ff0ff"):
    """Moldura fina de neon em cima e embaixo (como a do baú rosa)."""
    neon_line(cv, [(0.0, 0.012), (cv.aspect, 0.012)], top, 0.0045)
    neon_line(cv, [(0.0, 0.988), (cv.aspect, 0.988)], bottom, 0.0045)


def frame(cv, color="#f2c14e", w=0.012, line="#3a2400"):
    """Moldura dourada em volta da arte inteira (traseira e teto)."""
    a = cv.aspect
    for pts in ([(0, w), (a, w)], [(0, 1 - w), (a, 1 - w)], [(w, 0), (w, 1)], [(a - w, 0), (a - w, 1)]):
        cv.fill(p.S(cv, pts, w * 1.25), hexc(line))
        cv.fill(p.S(cv, pts, w * 0.8), hexc(color))


def wave_crest(cv, L, colors=("#2f6fd0", "#0d1f5c"), foam="#f2f6ff", neon="#3ff0ff", lines=7):
    """A grande onda num quadro local (cabe em x 0..1,2, y 0..1; crista curvando para a direita)."""
    body = [(0.0, 1.0), (0.0, 0.42), (0.12, 0.3), (0.3, 0.18), (0.52, 0.11), (0.74, 0.1), (0.95, 0.14), (1.1, 0.22),
            (1.18, 0.32), (1.16, 0.42), (1.08, 0.46), (1.0, 0.42), (0.98, 0.34), (0.9, 0.3), (0.86, 0.36), (0.9, 0.5),
            (1.05, 0.66), (1.3, 0.8), (1.6, 0.9), (1.8, 1.0)]
    m = L.P(body)
    X, Y = cv.coords(m)
    lx, ly = L.to_local(X, Y)
    cv.fill(m, p.grad_t((ly - 0.1) / 0.9, [(0, colors[0]), (1, colors[1])]))
    for k in range(lines):
        off = 0.06 + k * 0.07
        line = []
        for s in np.linspace(0, 1, 24):
            x = 0.02 + off * 0.3 + s * (1.15 + off * 0.4)
            y = 0.47 + off - 0.32 * math.sin(math.pi * min(1.0, s * 1.25)) * (1 - off * 0.6) + s * s * 0.25
            line.append((x, y))
        cv.fill(p.mul(p.mul(L.S(line, 0.004), m), 0.7), hexc("#9cc8ff"))
    crest = [(0.12, 0.3), (0.3, 0.18), (0.52, 0.11), (0.74, 0.1), (0.95, 0.14), (1.1, 0.22), (1.18, 0.32), (1.16, 0.42),
             (1.08, 0.46)]
    for (xa, ya), (xb, yb) in zip(crest[:-1], crest[1:]):
        for s in np.linspace(0, 1, 5, endpoint=False):
            x, y = xa + (xb - xa) * s, ya + (yb - ya) * s
            cv.fill(L.E(x, y, 0.035, 0.03), hexc(foam))
            cv.fill(L.E(x + 0.012, y + 0.016, 0.014, 0.012), hexc(colors[0]))
    for k, (x, y) in enumerate(((1.24, 0.3), (1.3, 0.38), (1.22, 0.45), (1.33, 0.5), (1.27, 0.24))):
        r = 0.012 + 0.004 * (k % 2)
        cv.fill(L.E(x, y, r, r), hexc(foam))
    if neon:
        neon_line(cv, L.pts(crest), neon, 0.0055)


def water_band(cv, y0, color_top="#1b4fb3", color_bot="#071a4a", seed=3, crest="#cfe8ff"):
    """Mar com cristinhas de espuma na base da arte."""
    win, X, Y = cv.win(0, y0, cv.aspect, 1)
    cv.fill((np.clip((Y - y0) * 80, 0, 1), win), p.grad_v(Y, y0, 1, [(0, color_top), (1, color_bot)]))
    rng = np.random.default_rng(seed)
    for row in range(5):
        yy = y0 + 0.02 + row * (1 - y0) / 5
        for xx in np.arange(rng.uniform(0, 0.1), cv.aspect, 0.16 + row * 0.02):
            arcp = p.arc(xx, yy + 0.02, 0.05, 0.02, 200, 340, 12)
            cv.fill(p.mul(p.S(cv, arcp, 0.003), 0.8), hexc(crest))
