"""Pintura 2D por código (T-232): tela com supersample, formas por distância assinada (SDF), traços de largura variável,
degradês, desfoque, contorno e brilho de neon. Só numpy (roda no Python do Blender ou no Python do sistema), sem
Pillow, sem imagem de terceiros. Determinístico: mesma chamada, mesmos pixels.

Coordenadas: x de 0 a `aspect` (esquerda -> direita), y de 0 (topo) a 1 (base). Distâncias na mesma unidade (1 = altura).
Toda forma devolve uma CAMADA = (cobertura 0..1 na janela, janela (r0, r1, c0, c1)); só a janela é calculada.
A tela guarda a cor (`rgb`) e a emissão dos neons (`neon`), que vira o mapa de emissão da noite.
"""
from __future__ import annotations

import math
import struct
import zlib

import numpy as np


def hexc(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def mix(a, b, t):
    return np.asarray(a, np.float32) * (1 - t) + np.asarray(b, np.float32) * t


class Canvas:
    def __init__(self, aspect: float, px_h: int, ss: int = 2):
        self.aspect = aspect
        self.out_h, self.out_w = px_h, int(round(px_h * aspect))
        self.ss = ss
        self.h, self.w = px_h * ss, self.out_w * ss
        self.px = 1.0 / self.h
        self.rgb = np.zeros((self.h, self.w, 3), np.float32)
        self.neon = np.zeros((self.h, self.w, 3), np.float32)

    # ------------------------------------------------------------------ janelas
    def win(self, x0, y0, x1, y1, pad: float = 0.0):
        """Janela (r0, r1, c0, c1) e as grades X, Y dela (centros dos pixels)."""
        c0 = max(0, int((x0 - pad) * self.h) - 2)
        c1 = min(self.w, int((x1 + pad) * self.h) + 3)
        r0 = max(0, int((y0 - pad) * self.h) - 2)
        r1 = min(self.h, int((y1 + pad) * self.h) + 3)
        c1, r1 = max(c1, c0), max(r1, r0)
        ys = (np.arange(r0, r1, dtype=np.float32) + 0.5) / self.h
        xs = (np.arange(c0, c1, dtype=np.float32) + 0.5) / self.h
        X, Y = np.meshgrid(xs, ys)
        return (r0, r1, c0, c1), X, Y

    def full(self):
        return self.win(0, 0, self.aspect, 1)

    def aa(self, d):
        """Cobertura suave a partir da distância assinada (negativa = dentro)."""
        return np.clip(0.5 - d / (self.px * 1.2), 0.0, 1.0).astype(np.float32)

    # ------------------------------------------------------------------ pintar
    def fill(self, layer, color, neon: float = 0.0, alpha: float = 1.0):
        """Pinta a camada com `color` (RGB, ou imagem do tamanho da janela). `neon` > 0 também grava na emissão."""
        a, (r0, r1, c0, c1) = layer
        if a.size == 0:
            return
        a = (np.clip(a, 0.0, 1.0) * alpha)[..., None]
        c = np.asarray(color, np.float32)
        if c.ndim == 1:
            c = c[None, None, :]
        rgb = self.rgb[r0:r1, c0:c1]
        rgb[...] = rgb * (1 - a) + c * a
        nn = self.neon[r0:r1, c0:c1]
        if neon > 0:
            nn[...] = np.maximum(nn * (1 - a), c * a * neon)
        else:
            nn[...] = nn * (1 - a)

    def add(self, layer, color, k: float = 1.0, neon: float = 0.0):
        """Soma luz (brilho/halo): cor x cobertura x k, e a mesma coisa na emissão se `neon`."""
        a, (r0, r1, c0, c1) = layer
        if a.size == 0:
            return
        c = np.asarray(color, np.float32)
        if c.ndim == 1:
            c = c[None, None, :]
        v = np.clip(a, 0, None)[..., None] * c * k
        self.rgb[r0:r1, c0:c1] = 1 - (1 - self.rgb[r0:r1, c0:c1]) * (1 - np.clip(v, 0, 1))   # "tela"
        if neon > 0:
            self.neon[r0:r1, c0:c1] = np.maximum(self.neon[r0:r1, c0:c1], v * neon)

    def coords(self, layer):
        """Grades X, Y da janela de uma camada."""
        _a, (r0, r1, c0, c1) = layer
        ys = (np.arange(r0, r1, dtype=np.float32) + 0.5) / self.h
        xs = (np.arange(c0, c1, dtype=np.float32) + 0.5) / self.h
        return np.meshgrid(xs, ys)

    # ------------------------------------------------------------------ saída
    def result(self, emit_scale: int = 2, dim: float = 0.3):
        """(cor out_h x out_w x 3, emissão (out/emit_scale) = arte escurecida + neons), sRGB 0..1, linha 0 = topo."""
        col = downsample(self.rgb, self.ss)
        em = downsample(self.rgb * dim + self.neon, self.ss * emit_scale)
        return np.clip(col, 0, 1), np.clip(em, 0, 1)


def downsample(a, k):
    h, w = a.shape[:2]
    return a[: h - h % k, : w - w % k].reshape(h // k, k, w // k, k, -1).mean((1, 3))


# ---------------------------------------------------------------------- operações de camada
def mul(layer, k):
    """Camada x número, ou x outra camada (máscara) na janela da primeira."""
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


def minus(layer, k):
    """Camada sem a parte coberta por `k` (outra camada)."""
    m, _ = mul(layer, k)
    return np.clip(layer[0] - m, 0, 1), layer[1]


def union(cv, layers):
    """Junta várias camadas numa (janela que cobre todas)."""
    layers = [l for l in layers if l[0].size]
    r0 = min(l[1][0] for l in layers)
    r1 = max(l[1][1] for l in layers)
    c0 = min(l[1][2] for l in layers)
    c1 = max(l[1][3] for l in layers)
    out = np.zeros((r1 - r0, c1 - c0), np.float32)
    for a, (q0, q1, d0, d1) in layers:
        sl = out[q0 - r0:q1 - r0, d0 - c0:d1 - c0]
        sl[...] = np.maximum(sl, a)
    return out, (r0, r1, c0, c1)


def expand(cv, layer, pad: float):
    """A mesma camada numa janela maior (para contorno/brilho que passam da forma)."""
    a, (r0, r1, c0, c1) = layer
    p = int(pad * cv.h) + 3
    n0, n1, m0, m1 = max(0, r0 - p), min(cv.h, r1 + p), max(0, c0 - p), min(cv.w, c1 + p)
    out = np.zeros((n1 - n0, m1 - m0), np.float32)
    out[r0 - n0:r1 - n0, c0 - m0:c1 - m0] = a
    return out, (n0, n1, m0, m1)


def blur(a, r_px: int):
    """Desfoque (3 caixas separáveis ~ gaussiano) de raio `r_px` pixels."""
    if r_px < 1:
        return a
    out = a.astype(np.float32)
    for _ in range(3):
        for ax in (0, 1):
            n = out.shape[ax]
            if n < 2:
                continue
            pad = [(0, 0)] * out.ndim
            pad[ax] = (r_px + 1, r_px)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=ax, dtype=np.float64)
            hi = np.take(c, np.arange(2 * r_px + 1, 2 * r_px + 1 + n), axis=ax)
            lo = np.take(c, np.arange(0, n), axis=ax)
            out = ((hi - lo) / (2 * r_px + 1)).astype(np.float32)
    return out


def outline(cv, layer, width: float, soft: float = 0.0):
    """Camada do CONTORNO por fora da forma (dilatação de `width`), sem a forma."""
    big = expand(cv, layer, width + soft + 0.01)
    a, win = big
    r = max(1, int(width * cv.h / 2))
    d = blur(a, r)
    grown = np.clip((d - 0.02) / 0.06, 0, 1)
    if soft > 0:
        grown = blur(grown, max(1, int(soft * cv.h)))
    return np.clip(grown - a, 0, 1), win


def glow(cv, layer, radius: float):
    """Halo suave em volta da forma (para neon e auréolas)."""
    big = expand(cv, layer, radius * 2.5)
    a, win = big
    return blur(a, max(1, int(radius * cv.h))), win


def inner(cv, layer, width: float):
    """0 na borda da forma até 1 a `width` para dentro (sombreado de aerógrafo)."""
    a, win = layer
    d = blur(a, max(1, int(width * cv.h / 2)))
    return np.clip((d - 0.5) * 2, 0, 1) * a, win


# ---------------------------------------------------------------------- distâncias assinadas (SDF)
def sd_circle(X, Y, cx, cy, r):
    return np.hypot(X - cx, Y - cy) - r


def sd_ellipse(X, Y, cx, cy, rx, ry, rot=0.0):
    x, y = X - cx, Y - cy
    if rot:
        c, s = math.cos(rot), math.sin(rot)
        x, y = x * c + y * s, -x * s + y * c
    k = np.sqrt((x / rx) ** 2 + (y / ry) ** 2)
    return (k - 1.0) * min(rx, ry)


def sd_seg(X, Y, ax, ay, bx, by, ra, rb=None):
    """Cone arredondado de a (raio ra) até b (raio rb): cápsula de largura variável."""
    rb = ra if rb is None else rb
    vx, vy = bx - ax, by - ay
    L2 = max(vx * vx + vy * vy, 1e-12)
    t = np.clip(((X - ax) * vx + (Y - ay) * vy) / L2, 0, 1)
    return np.hypot(X - (ax + t * vx), Y - (ay + t * vy)) - (ra + (rb - ra) * t)


def sd_poly(X, Y, pts):
    p = np.asarray(pts, np.float32)
    d = np.full(X.shape, 1e9, np.float32)
    inside = np.zeros(X.shape, bool)
    n = len(p)
    for i in range(n):
        xa, ya = p[i]
        xb, yb = p[(i + 1) % n]
        vx, vy = xb - xa, yb - ya
        L2 = max(vx * vx + vy * vy, 1e-12)
        t = np.clip(((X - xa) * vx + (Y - ya) * vy) / L2, 0, 1)
        d = np.minimum(d, np.hypot(X - (xa + t * vx), Y - (ya + t * vy)))
        cond = (ya > Y) != (yb > Y)
        xint = (xb - xa) * (Y - ya) / (yb - ya if yb != ya else 1e-9) + xa
        inside ^= cond & (X < xint)
    return np.where(inside, -d, d)


def smin(a, b, k):
    """União suave (junta formas como massa de modelar)."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


# ---------------------------------------------------------------------- formas prontas
def _bbox(pts, pad=0.0):
    p = np.asarray(pts, np.float32)
    return p[:, 0].min() - pad, p[:, 1].min() - pad, p[:, 0].max() + pad, p[:, 1].max() + pad


def E(cv, cx, cy, rx, ry, rot=0.0):
    r = max(rx, ry)
    win, X, Y = cv.win(cx - r, cy - r, cx + r, cy + r)
    return cv.aa(sd_ellipse(X, Y, cx, cy, rx, ry, rot)), win


def C(cv, cx, cy, r):
    return E(cv, cx, cy, r, r)


def P(cv, pts):
    win, X, Y = cv.win(*_bbox(pts))
    return cv.aa(sd_poly(X, Y, pts)), win


def S(cv, pts, width):
    """Traço de largura constante (meia largura = width) por uma polilinha."""
    return SV(cv, pts, [width] * len(pts))[0]


def SV(cv, pts, radii, need_uv: bool = False):
    """Tubo de raio variável ao longo da polilinha. Devolve (camada, extra) onde extra = (s, w) por pixel quando
    `need_uv`: s = comprimento ao longo do tubo (0 no 1º ponto), w = -1..1 de um lado ao outro (sinal do lado)."""
    p = np.asarray(pts, np.float32)
    rr = np.asarray(radii, np.float32)
    if len(rr) != len(p):                     # poucos raios: espalha ao longo do comprimento
        L = lengths(p)
        rr = np.interp(L / max(L[-1], 1e-9), np.linspace(0, 1, len(rr)), rr).astype(np.float32)
    x0, y0, x1, y1 = _bbox(p, float(rr.max()) + 0.01)
    win, X, Y = cv.win(x0, y0, x1, y1)
    r0, r1, c0, c1 = win
    d = np.full(X.shape, 1e9, np.float32)
    S_ = np.zeros(X.shape, np.float32) if need_uv else None
    W_ = np.zeros(X.shape, np.float32) if need_uv else None
    acc = 0.0
    for i in range(len(p) - 1):
        (xa, ya), (xb, yb) = p[i], p[i + 1]
        ra, rb = float(rr[i]), float(rr[i + 1])
        pad = max(ra, rb) + 3 * cv.px
        q0 = max(r0, int((min(ya, yb) - pad) * cv.h) - 1) - r0
        q1 = min(r1, int((max(ya, yb) + pad) * cv.h) + 2) - r0
        d0 = max(c0, int((min(xa, xb) - pad) * cv.h) - 1) - c0
        d1 = min(c1, int((max(xa, xb) + pad) * cv.h) + 2) - c0
        seg_len = math.hypot(xb - xa, yb - ya)
        if q1 > q0 and d1 > d0:
            Xs, Ys = X[q0:q1, d0:d1], Y[q0:q1, d0:d1]
            vx, vy = xb - xa, yb - ya
            L2 = max(vx * vx + vy * vy, 1e-12)
            t = np.clip(((Xs - xa) * vx + (Ys - ya) * vy) / L2, 0, 1)
            px_, py_ = Xs - (xa + t * vx), Ys - (ya + t * vy)
            rad = ra + (rb - ra) * t
            dd = np.hypot(px_, py_) - rad
            cur = d[q0:q1, d0:d1]
            better = dd < cur
            cur[...] = np.where(better, dd, cur)
            if need_uv:
                cross = (vx * py_ - vy * px_) / max(seg_len, 1e-9)
                S_[q0:q1, d0:d1] = np.where(better, acc + t * seg_len, S_[q0:q1, d0:d1])
                W_[q0:q1, d0:d1] = np.where(better, cross / np.maximum(rad, 1e-6), W_[q0:q1, d0:d1])
        acc += seg_len
    layer = (cv.aa(d), win)
    return layer, ((S_, W_) if need_uv else d)


def ring(cv, cx, cy, r, width):
    win, X, Y = cv.win(cx - r - width, cy - r - width, cx + r + width, cy + r + width)
    return cv.aa(np.abs(np.hypot(X - cx, Y - cy) - r) - width), win


def sdf_layer(cv, bbox, fn):
    """Camada de uma SDF qualquer `fn(X, Y) -> distância` dentro da caixa (x0, y0, x1, y1)."""
    win, X, Y = cv.win(*bbox)
    return cv.aa(fn(X, Y)), win


def tris_layer(cv, tris):
    """Camada de uma lista de triângulos (n, 3, 2) em coordenadas da tela (letras em vetor)."""
    t = np.asarray(tris, np.float32)
    x0, y0 = t[..., 0].min(), t[..., 1].min()
    x1, y1 = t[..., 0].max(), t[..., 1].max()
    win, X, Y = cv.win(x0, y0, x1, y1)
    r0, r1, c0, c1 = win
    out = np.zeros(X.shape, np.float32)
    for (ax, ay), (bx, by), (qx, qy) in t:
        q0 = max(r0, int(min(ay, by, qy) * cv.h) - 1) - r0
        q1 = min(r1, int(max(ay, by, qy) * cv.h) + 2) - r0
        d0 = max(c0, int(min(ax, bx, qx) * cv.h) - 1) - c0
        d1 = min(c1, int(max(ax, bx, qx) * cv.h) + 2) - c0
        if q1 <= q0 or d1 <= d0:
            continue
        Xs, Ys = X[q0:q1, d0:d1], Y[q0:q1, d0:d1]
        e0 = (bx - ax) * (Ys - ay) - (by - ay) * (Xs - ax)
        e1 = (qx - bx) * (Ys - by) - (qy - by) * (Xs - bx)
        e2 = (ax - qx) * (Ys - qy) - (ay - qy) * (Xs - qx)
        ins = ((e0 >= 0) & (e1 >= 0) & (e2 >= 0)) | ((e0 <= 0) & (e1 <= 0) & (e2 <= 0))
        sl = out[q0:q1, d0:d1]
        sl[ins] = 1.0
    return out, win


# ---------------------------------------------------------------------- curvas
def bezier(p0, p1, p2, p3, n=32):
    t = np.linspace(0, 1, n)[:, None]
    a, b, c, d = (np.asarray(q, np.float32) for q in (p0, p1, p2, p3))
    return ((1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t ** 2 * c + t ** 3 * d).tolist()


def spline(pts, n_per=12):
    """Catmull-Rom passando por todos os pontos."""
    p = np.asarray(pts, np.float32)
    p = np.vstack([p[0] * 2 - p[1], p, p[-1] * 2 - p[-2]])
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for t in np.linspace(0, 1, n_per, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(p[-2])
    return np.array(out, np.float32).tolist()


def arc(cx, cy, rx, ry, a0, a1, n=48):
    return [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in np.linspace(a0, a1, n)]


def xf(pts, ox=0.0, oy=0.0, s=1.0, flip=False, rot=0.0, sy=None):
    """Transforma pontos de um desenho local: espelha em x (flip), gira (graus), escala e desloca."""
    sy = s if sy is None else sy
    c, sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    out = []
    for x, y in pts:
        x = -x if flip else x
        x, y = x * c - y * sn, x * sn + y * c
        out.append((ox + x * s, oy + y * sy))
    return out


def lengths(pts):
    p = np.asarray(pts, np.float32)
    return np.concatenate([[0], np.cumsum(np.hypot(*(p[1:] - p[:-1]).T))])


def resample(pts, n):
    """Mesma curva com `n` pontos igualmente espaçados."""
    p = np.asarray(pts, np.float32)
    L = lengths(p)
    t = np.linspace(0, L[-1], n)
    return np.stack([np.interp(t, L, p[:, 0]), np.interp(t, L, p[:, 1])], 1).tolist()


def normals(pts):
    p = np.asarray(pts, np.float32)
    d = np.gradient(p, axis=0)
    d /= np.maximum(np.hypot(d[:, 0], d[:, 1]), 1e-9)[:, None]
    return np.stack([-d[:, 1], d[:, 0]], 1)


# ---------------------------------------------------------------------- degradês e textura
def grad_v(Y, y0, y1, stops):
    """Degradê vertical: stops = [(t, cor hex), ...] com t de 0 (y0) a 1 (y1). Imagem (h, w, 3)."""
    t = np.clip((Y - y0) / max(y1 - y0, 1e-6), 0, 1)
    ts = np.array([s[0] for s in stops], np.float32)
    cs = np.stack([hexc(s[1]) for s in stops])
    return np.stack([np.interp(t, ts, cs[:, k]) for k in range(3)], -1).astype(np.float32)


def grad_t(T, stops):
    """Degradê por um parâmetro T (0..1) qualquer (radial, ao longo do corpo...)."""
    t = np.clip(T, 0, 1)
    ts = np.array([s[0] for s in stops], np.float32)
    cs = np.stack([hexc(s[1]) if isinstance(s[1], str) else np.asarray(s[1], np.float32) for s in stops])
    return np.stack([np.interp(t, ts, cs[:, k]) for k in range(3)], -1).astype(np.float32)


def vnoise(X, Y, scale, seed=0, octaves=3):
    """Ruído suave (valor) determinístico, 0..1."""
    out = np.zeros(X.shape, np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        f = (2 ** o) / scale
        gx, gy = X * f, Y * f
        ix, iy = np.floor(gx).astype(np.int64), np.floor(gy).astype(np.int64)
        fx, fy = gx - ix, gy - iy
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

        def h(a, b):
            v = (a * 374761393 + b * 668265263 + (seed + o * 1013) * 2147483647) & 0xFFFFFFFF
            v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
            return ((v ^ (v >> 16)) & 0xFFFF).astype(np.float32) / 65535.0
        v00, v10, v01, v11 = h(ix, iy), h(ix + 1, iy), h(ix, iy + 1), h(ix + 1, iy + 1)
        out += amp * ((v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy)
        tot += amp
        amp *= 0.5
    return out / tot


# ---------------------------------------------------------------------- PNG sem Pillow
def _png_filter_rows(a: np.ndarray) -> bytes:
    """T-266: filtro adaptativo por linha do PNG (None/Sub/Up/Average/Paeth; escolhe a menor soma |byte com sinal|,
    a regra do libpng). Mesmos pixels, arquivo ~30-40% menor em foto/ilustração."""
    h, w, c = a.shape
    x = a.reshape(h, w * c).astype(np.int16)
    left = np.zeros_like(x)
    left[:, c:] = x[:, :-c]
    up = np.zeros_like(x)
    up[1:] = x[:-1]
    ul = np.zeros_like(x)
    ul[1:, c:] = x[:-1, :-c]
    p = left + up - ul
    pa, pb, pc = np.abs(p - left), np.abs(p - up), np.abs(p - ul)
    paeth = np.where((pa <= pb) & (pa <= pc), left, np.where(pb <= pc, up, ul))
    cands = [x, x - left, x - up, x - ((left + up) >> 1), x - paeth]
    cands = [(f & 0xFF).astype(np.uint8) for f in cands]
    cost = np.stack([np.abs(f.astype(np.int8).astype(np.int16)).sum(1) for f in cands], 0)
    best = np.argmin(cost, 0)
    return b"".join(bytes([int(best[y])]) + cands[int(best[y])][y].tobytes() for y in range(h))


def save_png(arr: np.ndarray, path: str, filtered: bool = False) -> None:
    """Grava (h, w, 3) 0..1 sRGB como PNG RGB 8 bits (zlib nível 9, sem metadados: bytes determinísticos).
    `filtered` (T-266): filtro adaptativo por linha (arquivo menor, mesmos pixels); padrão = sem filtro, como antes."""
    import os
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    a = np.clip(np.round(np.asarray(arr)[..., :3] * 255.0), 0, 255).astype(np.uint8)
    h, w = a.shape[:2]
    if filtered:
        raw = _png_filter_rows(a)
    else:
        raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
