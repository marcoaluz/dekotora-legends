"""Pinturas a partir de obras prontas (T-242): ler a imagem, recortar, tratar cor/contraste, compor (recorte único,
quadros lado a lado ou traseira com kanji) e desenhar À MÃO o mapa de brilho noturno (só nos pontos escolhidos:
olhos, lua, sol, raio, lanternas, vaga-lumes, molduras de neon).

Coordenadas da arte final: x de 0 a `aspect` (esquerda -> direita), y de 0 (topo) a 1 (base), como no paint2d.
Recortes da obra: frações (x0, y0, x1, y1) da largura/altura da imagem original.
Só numpy (+ bpy para abrir o JPG/PNG). Determinístico: mesma imagem, mesmos bytes.
"""
from __future__ import annotations

import os

import numpy as np

from . import paint2d as p
from .paint2d import hexc

LUMA = np.array([0.299, 0.587, 0.114], np.float32)


# ---------------------------------------------------------------------------------------------- leitura
def load(path: str, max_side: int = 4200) -> np.ndarray:
    """Imagem (h, w, 3) float32 0..1 sRGB, linha 0 = topo. Usa o Blender (sem Pillow)."""
    import bpy
    img = bpy.data.images.load(os.path.abspath(path), check_existing=False)
    try:
        w, h = img.size
        k = max(w, h) / max_side
        if k > 1.0:
            img.scale(int(round(w / k)), int(round(h / k)))
            w, h = img.size
        buf = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(buf)
    finally:
        bpy.data.images.remove(img)
    return np.ascontiguousarray(buf.reshape(h, w, 4)[::-1, :, :3])


def find_source(root: str, filename: str) -> str:
    """Procura primeiro em docs/Murais/ (imagens do Marco), depois em blender/renders/t242/fontes/ (baixadas)."""
    for d in ("docs/Murais", "docs/Murais/fontes", "blender/renders/t242/fontes"):
        f = os.path.join(root, d, filename)
        if os.path.exists(f):
            return f
    raise FileNotFoundError("fonte não encontrada: %s (rode: python -I tools/fetch_t242_sources.py)" % filename)


# ---------------------------------------------------------------------------------------------- reamostragem
def _lerp_axis(a, coords, axis):
    n = a.shape[axis]
    c = np.clip(coords, 0, n - 1)
    i0 = np.floor(c).astype(np.int64)
    i1 = np.minimum(i0 + 1, n - 1)
    f = (c - i0).astype(np.float32)
    shape = [1] * a.ndim
    shape[axis] = -1
    f = f.reshape(shape)
    return np.take(a, i0, axis=axis) * (1 - f) + np.take(a, i1, axis=axis) * f


def resample(img, box_px, out_w, out_h):
    """Recorte (x0, y0, x1, y1 em pixels, frações permitidas) reamostrado para out_w x out_h (filtro contra serrilhado)."""
    x0, y0, x1, y1 = box_px
    sx = (x1 - x0) / out_w
    sy = (y1 - y0) / out_h
    r0, r1 = max(0, int(y0) - 4), min(img.shape[0], int(np.ceil(y1)) + 4)
    c0, c1 = max(0, int(x0) - 4), min(img.shape[1], int(np.ceil(x1)) + 4)
    a = img[r0:r1, c0:c1]
    k = int(max(sx, sy) / 2)
    if k >= 1:
        a = p.blur(a, k)
    ys = y0 - r0 + (np.arange(out_h, dtype=np.float32) + 0.5) * sy - 0.5
    xs = x0 - c0 + (np.arange(out_w, dtype=np.float32) + 0.5) * sx - 0.5
    return _lerp_axis(_lerp_axis(a, ys, 0), xs, 1).astype(np.float32)


def fit(img, box, out_w, out_h, stretch_max=1.12):
    """Recorte `box` (frações) da obra numa área out_w x out_h. Se o recorte for mais estreito que a área, estica na
    horizontal até `stretch_max` e completa as laterais com a cor da borda (esfumada); se for mais largo, corta no meio."""
    H, W = img.shape[:2]
    x0, y0, x1, y1 = box[0] * W, box[1] * H, box[2] * W, box[3] * H
    want = out_w / out_h
    have = (x1 - x0) / (y1 - y0)
    if have > want:                                   # mais largo: corta as laterais
        cx, half = (x0 + x1) / 2, (y1 - y0) * want / 2
        return resample(img, (cx - half, y0, cx + half, y1), out_w, out_h)
    s = min(want / have, stretch_max)
    inner_w = int(round(out_h * have * s))
    if inner_w >= out_w - 1:
        return resample(img, (x0, y0, x1, y1), out_w, out_h)
    mid = resample(img, (x0, y0, x1, y1), inner_w, out_h)
    out = np.empty((out_h, out_w, 3), np.float32)
    left = (out_w - inner_w) // 2
    out[:, left:left + inner_w] = mid
    for side, sl, edge in (("L", slice(0, left), mid[:, :24]), ("R", slice(left + inner_w, out_w), mid[:, -24:])):
        col = p.blur(edge.mean(1, keepdims=True), 18)              # cor da borda, linha a linha, esfumada
        n = sl.stop - sl.start
        if n <= 0:
            continue
        t = np.linspace(0, 1, n, dtype=np.float32)[None, :, None]
        if side == "L":
            t = t[:, ::-1]
        out[:, sl] = col * (1 - 0.35 * t)                          # escurece para fora (some no fundo)
    return out


# ---------------------------------------------------------------------------------------------- cor
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


TONE = {"lo": 0.6, "hi": 99.6, "paper": 0.35, "paper_lo": 0.55, "paper_hi": 0.85, "paper_sat": 0.32,
        "paper_tint": (0.62, 0.5, 0.38), "sat": 1.18, "gamma": 1.08, "gain": 1.0}


def tone(rgb, **kw):
    """Tratamento para o jogo: níveis (preto/branco da obra), papel/seda escurecido e tingido (as gravuras são claras e
    estouravam de dia), saturação e gama leves. Não mexe no desenho (só curva de cor)."""
    t = dict(TONE, **kw)
    L = rgb @ LUMA
    lo, hi = np.percentile(L, t["lo"]), np.percentile(L, t["hi"])
    a = np.clip((rgb - lo) / max(hi - lo, 1e-3), 0, 1)
    L = a @ LUMA
    sat = a.max(-1) - a.min(-1)
    m = smooth(t["paper_lo"], t["paper_hi"], L) * (1 - smooth(t["paper_sat"] * 0.5, t["paper_sat"], sat))
    k = (t["paper"] * m)[..., None]
    a = a * (1 - k) + a * np.array(t["paper_tint"], np.float32) * k
    L = (a @ LUMA)[..., None]
    a = L + (a - L) * t["sat"]
    a = np.clip(a, 0, 1) ** t["gamma"] * t["gain"]
    return np.clip(a, 0, 1).astype(np.float32)


# ---------------------------------------------------------------------------------------------- brilho (à mão)
class Glow:
    """Mapa de brilho desenhado por formas, na resolução da arte (depois reduzido)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.e = np.zeros((h, w, 3), np.float32)
        ys = (np.arange(h, dtype=np.float32) + 0.5) / h
        xs = (np.arange(w, dtype=np.float32) + 0.5) / h
        self.X, self.Y = np.meshgrid(xs, ys)

    def _add(self, m, color, k):
        self.e += m[..., None] * hexc(color) * k

    def disc(self, x, y, r, color, k=1.0, halo=1.6, clip=None):
        """Lua, sol, lanterna: disco cheio + auréola. `clip`: só acima dessa linha (sol nascendo atrás do mar)."""
        d = np.hypot(self.X - x, self.Y - y)
        core = smooth(r * 1.02, r * 0.85, d)
        aur = np.exp(-np.square(np.maximum(d - r, 0) / (r * halo * 0.6 + 1e-4)))
        m = core + 0.55 * aur * (1 - core)
        if clip is not None:
            m = m * smooth(clip + 0.01, clip - 0.01, self.Y)
        self._add(m, color, k)

    def dots(self, pts, r, color, k=1.0, halo=2.5):
        """Olhos, vaga-lumes: pontos pequenos com halo."""
        for x, y in pts:
            d = np.hypot(self.X - x, self.Y - y)
            self._add(smooth(r, r * 0.4, d) + 0.6 * np.exp(-np.square(d / (r * halo))), color, k)

    def eye(self, x, y, rx, ry, color, k=1.0, rot=0.0):
        """Olho (elipse) com brilho suave em volta."""
        c, s = np.cos(np.radians(rot)), np.sin(np.radians(rot))
        dx, dy = self.X - x, self.Y - y
        u, v = (dx * c + dy * s) / rx, (-dx * s + dy * c) / ry
        d = np.sqrt(u * u + v * v)
        self._add(smooth(1.05, 0.7, d) + 0.45 * np.exp(-np.square(np.maximum(d - 1, 0) / 1.6)), color, k)

    def line(self, pts, width, color, k=1.0, halo=3.0):
        """Raio, lâmina, feixe de luz: traço com halo."""
        d = np.full(self.X.shape, 1e9, np.float32)
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            vx, vy = bx - ax, by - ay
            t = np.clip(((self.X - ax) * vx + (self.Y - ay) * vy) / (vx * vx + vy * vy + 1e-9), 0, 1)
            d = np.minimum(d, np.hypot(self.X - ax - t * vx, self.Y - ay - t * vy))
        self._add(smooth(width, width * 0.4, d) + 0.5 * np.exp(-np.square(d / (width * halo))), color, k)

    def key(self, art, x, y, rx, ry, color, k=1.0, thr=0.6, soft=0.2, use_color=True):
        """Só as partes CLARAS da obra dentro de uma elipse (ex.: o feixe de luz pintado, a lua pintada)."""
        u, v = (self.X - x) / rx, (self.Y - y) / ry
        inside = smooth(1.0, 0.75, np.sqrt(u * u + v * v))
        lum = smooth(thr, thr + soft, art @ LUMA) * inside
        base = art if use_color else 1.0
        self.e += lum[..., None] * (0.5 * base + 0.5 * hexc(color)) * k

    def rect_frame(self, x0, y0, x1, y1, width, color, k=1.0):
        self.line([(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)], width, color, k, halo=2.5)


def emission(col, glow, dim, scale):
    """Emissão final = obra bem escurecida (a luz das luzinhas do baú, como na T-232) + os pontos acesos."""
    e = col * dim + glow.e
    return np.clip(p.downsample(e, scale), 0, 1)


def night(col, emit):
    """Prévia da noite (a mesma conta das folhas da T-232): pouca luz ambiente + a emissão."""
    k = col.shape[0] // emit.shape[0]
    up = np.repeat(np.repeat(emit, k, 0), k, 1)[: col.shape[0], : col.shape[1]]
    return np.clip(col * 0.12 + up * 1.1, 0, 1)
