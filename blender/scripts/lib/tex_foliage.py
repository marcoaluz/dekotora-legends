"""T-192: foliage atlas painted with numpy (no downloads) for the code-made trees (pine, cedar, round tree, bush,
coconut palms). 512 x 512 RGBA, sRGB values, straight alpha (cut by alpha scissor in the game):
  left top    (u 0-0.5, v 0.5-1)  conifer spray: twig + needles, base at the bottom of the cell
  left bottom (u 0-0.5, v 0-0.5)  broadleaf clump: overlapping small leaves, lit from the upper left
  right       (u 0.5-1, v 0-1)    coconut frond: rachis + leaflets, base at the bottom, tip at the top
Arrays are (h, w, 4) floats with row 0 = TOP of the image (tex_scenic.save_rgba flips). Deterministic (seeded).
"""
from __future__ import annotations

import math

import numpy as np

SIZE = 512
CELL = 256
# UV rectangles (u0, v0, u1, v1) used by build_foliage_t192.py
UV_CONIFER = (0.0, 0.5, 0.5, 1.0)
UV_CLUMP = (0.0, 0.0, 0.5, 0.5)
UV_FROND = (0.5, 0.0, 1.0, 1.0)


def _strokes(img: np.ndarray, segs: list, step: float = 0.5) -> None:
    """Paints anti-aliased strokes. segs = [(x0, y0, x1, y1, r0, r1, (r, g, b)), ...] in pixels (row = y)."""
    h, w = img.shape[:2]
    for x0, y0, x1, y1, r0, r1, col in segs:
        n = max(int(math.hypot(x1 - x0, y1 - y0) / step), 1)
        t = np.linspace(0.0, 1.0, n + 1)
        xs = x0 + (x1 - x0) * t
        ys = y0 + (y1 - y0) * t
        rs = r0 + (r1 - r0) * t
        rmax = int(math.ceil(max(r0, r1))) + 1
        for oy in range(-rmax, rmax + 1):
            for ox in range(-rmax, rmax + 1):
                px = np.floor(xs).astype(int) + ox
                py = np.floor(ys).astype(int) + oy
                ok = (px >= 0) & (px < w) & (py >= 0) & (py < h)
                d = np.hypot(px + 0.5 - xs, py + 0.5 - ys)
                cov = np.clip(rs + 0.5 - d, 0.0, 1.0)
                ok &= cov > 0.0
                px, py, cov = px[ok], py[ok], cov[ok]
                if px.size == 0:
                    continue
                strong = cov > img[py, px, 3] * 0.5
                img[py[strong], px[strong], :3] = col
                np.maximum.at(img[:, :, 3], (py, px), cov)


def conifer_spray(rng) -> np.ndarray:
    """Branch spray seen from above/side: main twig bottom -> top, side twigs, dense needles (tip shorter)."""
    img = np.zeros((CELL, CELL, 4))
    segs = []
    twigs = [(128.0, 250.0, 128.0 + rng.uniform(-10, 10), 14.0, 1.0)]
    for k in range(7):                                   # side twigs, alternating, shorter toward the tip
        t = 0.12 + k * 0.11
        y = 250.0 - t * 236.0
        side = 1.0 if k % 2 == 0 else -1.0
        ln = (1.0 - t) * 105.0 + 20.0
        twigs.append((128.0, y, 128.0 + side * ln * 0.75, y - ln * 0.55, 0.7))
    for x0, y0, x1, y1, scale in twigs:
        segs.append((x0, y0, x1, y1, 1.8 * scale, 0.8, (0.30, 0.22, 0.13)))
        ln = math.hypot(x1 - x0, y1 - y0)
        ax, ay = (x1 - x0) / ln, (y1 - y0) / ln
        for i in range(int(ln / 1.5)):
            t = i / max(ln / 1.5, 1.0)
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for side in (-1.0, 1.0):
                ang = side * rng.uniform(0.55, 1.05)
                ca, sa = math.cos(ang), math.sin(ang)
                dx, dy = ax * ca - ay * sa, ax * sa + ay * ca
                nl = (18.0 + rng.uniform(-3, 6)) * (1.0 - 0.45 * t) * scale ** 0.3
                lit = rng.uniform(0.75, 1.15) * (0.85 + 0.3 * t)
                tip = (0.22 * lit, 0.40 * lit, 0.17 * lit)
                segs.append((px, py, px + dx * nl, py + dy * nl, 1.25, 0.6, tip))
    _strokes(img, segs)
    return img


def leaf_clump(rng) -> np.ndarray:
    """Round clump of ~420 small leaves (ellipses with a darker midrib), ragged edge, light from the upper left."""
    img = np.zeros((CELL, CELL, 4))
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(float)
    for _ in range(420):
        a = rng.uniform(0, math.tau)
        rr = 112.0 * math.sqrt(rng.uniform(0.0, 1.0))
        cx, cy = 128 + math.cos(a) * rr, 128 + math.sin(a) * rr * 0.95
        ln, wd = rng.uniform(9, 15), rng.uniform(4.0, 6.5)
        th = rng.uniform(0, math.tau)
        x0, x1 = int(max(cx - ln - 1, 0)), int(min(cx + ln + 2, CELL))
        y0, y1 = int(max(cy - ln - 1, 0)), int(min(cy + ln + 2, CELL))
        if x1 <= x0 or y1 <= y0:
            continue
        dx, dy = xx[y0:y1, x0:x1] - cx, yy[y0:y1, x0:x1] - cy
        u = dx * math.cos(th) + dy * math.sin(th)
        v = -dx * math.sin(th) + dy * math.cos(th)
        d = (u / ln) ** 2 + (v / wd) ** 2
        cov = np.clip((1.0 - d) * 6.0, 0, 1)
        light = 1.0 - 0.45 * np.clip(((cx - 128) + (cy - 128)) / 220.0 + 0.5, 0, 1)
        lit = light * rng.uniform(0.8, 1.15)
        base = np.array([0.20, 0.36, 0.13]) * lit + rng.uniform(-0.02, 0.03)
        shade = 1.0 - 0.25 * np.clip(v / wd, 0, 1) - 0.2 * (np.abs(v) < 0.6)   # half leaf darker + midrib
        cell = img[y0:y1, x0:x1]
        m = cov > 0.4
        cell[m, :3] = (base[None, :] * shade[m][:, None])
        cell[:, :, 3] = np.maximum(cell[:, :, 3], cov)
    return img


def palm_frond(rng, w: int = CELL, h: int = SIZE) -> np.ndarray:
    """Frond: rachis along the centre (base at the bottom), leaflets to both sides angled toward the tip, longest at
    ~35% of the length, a few gaps and torn leaflets. Card ~1.7 m wide x 3 m long (texels almost square)."""
    img = np.zeros((h, w, 4))
    segs = [(w / 2, h - 2.0, w / 2 + 3.0, 4.0, 3.2, 1.0, (0.42, 0.42, 0.20))]
    y = h - 18.0
    while y > 8.0:
        t = (h - y) / h
        reach = (w / 2 - 6.0) * (math.sin(math.pi * min(0.22 + 0.9 * t, 1.0)) ** 0.7) * (1.0 - 0.15 * t)
        for side in (-1.0, 1.0):
            if rng.random() < 0.07:
                continue                                  # gap
            ln = reach * rng.uniform(0.82, 1.05) * (0.55 if rng.random() < 0.08 else 1.0)
            ang = math.radians(rng.uniform(22.0, 34.0) + 10.0 * t)   # leaflet rises toward the tip
            x0 = w / 2 + side * 2.0
            x1 = x0 + side * ln * math.cos(ang)
            y1 = y - ln * math.sin(ang)
            lit = rng.uniform(0.8, 1.12)
            dry = rng.random() < 0.06
            col = (0.40 * lit, 0.38 * lit, 0.16 * lit) if dry else (0.20 * lit, 0.37 * lit, 0.12 * lit)
            segs.append((x0, y, x1, y1, 2.6, 0.6, col))
        y -= rng.uniform(4.5, 6.0)
    _strokes(img, segs, step=0.6)
    return img


# mean sRGB colour of the opaque texels of each cell (close to the Gleditsia atlases, ~0.53/0.60/0.33, a bit darker)
MEAN_CONIFER = (0.36, 0.47, 0.25)
MEAN_CLUMP = (0.40, 0.50, 0.25)
MEAN_FROND = (0.47, 0.56, 0.26)


def _calibrate(cell: np.ndarray, target) -> np.ndarray:
    m = cell[:, :, 3] > 0.5
    if m.any():
        k = np.array(target) / np.maximum(cell[:, :, :3][m].mean(axis=0), 1e-3)
        cell[:, :, :3] = np.clip(cell[:, :, :3] * k[None, None, :], 0, 1)
    return cell


def atlas(seed: int = 192) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros((SIZE, SIZE, 4))
    out[0:CELL, 0:CELL] = _calibrate(conifer_spray(rng), MEAN_CONIFER)   # row 0 = top -> v 0.5..1
    out[CELL:SIZE, 0:CELL] = _calibrate(leaf_clump(rng), MEAN_CLUMP)
    out[:, CELL:SIZE] = _calibrate(palm_frond(rng), MEAN_FROND)
    # alpha-scissor friendly: colour bleeds under transparent texels (no dark fringe with mipmaps)
    a = out[:, :, 3]
    avg = out[:, :, :3][a > 0.5].mean(axis=0)
    out[:, :, :3] = np.where((a > 0.02)[..., None], out[:, :, :3], avg[None, None, :])
    return out
