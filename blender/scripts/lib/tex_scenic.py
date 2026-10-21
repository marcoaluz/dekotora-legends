"""T-188: repeatable scenery textures made with numpy (no downloads): terrain detail channels, building facades,
tree cards. All functions return float arrays (h, w, 4) in 0..1, row 0 = TOP of the image (save_rgba flips).
Deterministic: every function takes a seed.
"""
from __future__ import annotations

import os

import numpy as np


# ---------------------------------------------------------------- helpers
def value_noise(size: int, rng, octaves=((8, 0.5), (32, 0.3), (128, 0.2))) -> np.ndarray:
    """Tileable value noise (edges match) summed over octaves; mean ~0.5."""
    acc = np.zeros((size, size))
    for k, amp in octaves:
        g = rng.random((k, k))
        idx = np.arange(size) * k / size
        i0 = np.floor(idx).astype(int)
        f = idx - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % k
        row = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
        row2 = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
        acc += amp * (row * (1 - f)[:, None] + row2 * f[:, None])
    return acc


def norm01(a: np.ndarray) -> np.ndarray:
    lo, hi = np.percentile(a, 1), np.percentile(a, 99)
    return np.clip((a - lo) / max(hi - lo, 1e-6), 0, 1)


def blobs(size: int, rng, count: int, rmin: float, rmax: float, shade: float = 0.0) -> np.ndarray:
    """Soft round blobs that wrap around the edges (tileable). `shade` darkens the lower-right of each blob
    (light from the upper-left), so tree crowns read as bumps."""
    out = np.zeros((size, size))
    yy, xx = np.mgrid[0:size, 0:size]
    for _ in range(count):
        cx, cy = rng.random(2) * size
        r = rng.uniform(rmin, rmax)
        dx = (xx - cx + size / 2) % size - size / 2
        dy = (yy - cy + size / 2) % size - size / 2
        d = np.sqrt(dx * dx + dy * dy) / r
        b = np.clip(1.0 - d * d, 0, 1)
        lit = 1.0 - shade * np.clip((dx + dy) / (2 * r) + 0.3, 0, 1)
        out = np.maximum(out, b * lit)
    return out


def save_rgba(arr: np.ndarray, path: str) -> None:
    """Writes (h, w, 4) 0..1 as an RGBA PNG through Blender (no colour conversion)."""
    import bpy
    os.makedirs(os.path.dirname(path), exist_ok=True)
    h, w = arr.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    img.pixels.foreach_set(np.clip(arr[::-1], 0, 1).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


# ---------------------------------------------------------------- terrain detail (grayscale per channel)
def terrain_detail(size: int = 512, seed: int = 188) -> np.ndarray:
    """R = grass (blades and clumps), G = dirt (pebbles), B = rock (cracks), A = forest canopy (crowns from above).
    Each channel ~0.25..1 so the shader can multiply a colour by it."""
    rng = np.random.default_rng(seed)
    clumps = value_noise(size, rng, ((16, 0.45), (64, 0.35), (256, 0.2)))
    blades = rng.random((size, size))
    grass = 0.55 + 0.45 * norm01(clumps) * 0.7 + 0.3 * (blades - 0.5)
    pebbles = blobs(size, rng, 260, 1.5, 5.0, shade=0.5)
    dirt_n = value_noise(size, rng, ((8, 0.5), (32, 0.3), (128, 0.2)))
    dirt = 0.6 + 0.35 * (norm01(dirt_n) - 0.5) + 0.35 * pebbles - 0.1 * (rng.random((size, size)) > 0.97)
    ridge = 1.0 - np.abs(2.0 * value_noise(size, rng, ((6, 0.5), (24, 0.35), (96, 0.15))) - 1.0)
    cracks = np.clip((ridge - 0.86) * 8.0, 0, 1)
    rock = 0.72 + 0.25 * (norm01(value_noise(size, rng, ((4, 0.4), (16, 0.35), (64, 0.25)))) - 0.5) - 0.45 * cracks
    crowns = blobs(size, rng, 420, 9.0, 20.0, shade=0.75)
    canopy = 0.3 + 0.7 * crowns + 0.08 * (rng.random((size, size)) - 0.5)
    out = np.stack([grass, dirt, rock, canopy], axis=2)
    return np.clip(out, 0.08, 1.0)


# ---------------------------------------------------------------- building facades
CELL = 256          # one cell = 4 bays x 4 floors = 12 m x 14 m
BAY = CELL // 4
FLOOR = CELL // 4


def _rect(img, mask, x0, y0, x1, y1, col, m=None):
    img[y0:y1, x0:x1, :3] = col
    if m is not None:
        mask[y0:y1, x0:x1] = m


def _grime(cell: np.ndarray, rng, amount: float) -> None:
    """Rain streaks under every window row + soft dirt (darkens the wall, not the glass mask)."""
    h, w = cell.shape[:2]
    n = value_noise(CELL, rng, ((4, 0.5), (16, 0.3), (64, 0.2)))[:h, :w]
    streak = np.repeat(rng.random((1, w)), h, axis=0)
    streak = np.clip((streak - 0.55) * 2.2, 0, 1) * np.linspace(0.2, 1.0, h)[:, None]
    cell[..., :3] *= (1.0 - amount * (0.35 * streak + 0.25 * (n - 0.5)))[..., None]


def facade_cell(style: int, rng) -> np.ndarray:
    c = np.zeros((CELL, CELL, 4))
    mask = np.zeros((CELL, CELL))
    if style == 0:      # glass curtain wall, thin mullions
        c[..., :3] = [0.30, 0.38, 0.46]
        g = np.linspace(0.85, 1.15, CELL)[:, None, None]
        c[..., :3] *= g
        mask[:] = 0.9
        for x in range(0, CELL, BAY // 2):
            _rect(c, mask, x, 0, x + 2, CELL, [0.62, 0.65, 0.68], 0.0)
        for y in range(0, CELL, FLOOR):
            _rect(c, mask, 0, y, CELL, y + 5, [0.55, 0.58, 0.6], 0.0)
    elif style == 1:    # concrete bands + ribbon windows
        c[..., :3] = [0.66, 0.64, 0.60]
        for y in range(0, CELL, FLOOR):
            _rect(c, mask, 0, y + 18, CELL, y + 52, [0.20, 0.25, 0.30], 1.0)
            for x in range(0, CELL, 16):
                _rect(c, mask, x, y + 18, x + 2, y + 52, [0.45, 0.46, 0.47], 0.0)
    elif style == 2:    # apartment ("mansion"): balconies, railings, AC units
        c[..., :3] = [0.80, 0.77, 0.70]
        for y in range(0, CELL, FLOOR):
            for x in range(0, CELL, BAY):
                _rect(c, mask, x + 8, y + 8, x + 56, y + 44, [0.24, 0.28, 0.32], 1.0)
                _rect(c, mask, x + 30, y + 8, x + 32, y + 44, [0.6, 0.6, 0.6], 0.0)
                _rect(c, mask, x + 2, y + 40, x + 62, y + 60, [0.86, 0.85, 0.82], 0.0)     # balcony slab/railing
                for k in range(x + 4, x + 62, 5):
                    _rect(c, None, k, y + 42, k + 1, y + 58, [0.55, 0.56, 0.58])
                _rect(c, None, x + 44, y + 46, x + 58, y + 56, [0.9, 0.9, 0.88])          # AC unit
            _rect(c, None, 0, y + 60, CELL, y + 64, [0.55, 0.53, 0.5])
    elif style == 3:    # old beige tile grid, 2 small windows per bay
        c[..., :3] = [0.74, 0.66, 0.52]
        tile = (np.add.outer(np.arange(CELL) // 4, np.arange(CELL) // 8) % 2) * 0.03
        c[..., :3] += tile[..., None]
        for y in range(0, CELL, FLOOR):
            for x in range(0, CELL, BAY // 2):
                _rect(c, mask, x + 7, y + 14, x + 25, y + 46, [0.18, 0.2, 0.22], 1.0)
                _rect(c, None, x + 5, y + 46, x + 27, y + 49, [0.82, 0.8, 0.74])
    elif style == 4:    # brown brick tile, one window per bay with dark frame
        c[..., :3] = [0.46, 0.30, 0.22]
        rows = np.arange(CELL) // 4
        joint = ((np.arange(CELL)[:, None] % 4) == 0) | (((np.arange(CELL)[None, :] + (rows[:, None] % 2) * 6) % 12) == 0)
        c[..., :3] *= np.where(joint, 0.8, 1.0)[..., None]
        for y in range(0, CELL, FLOOR):
            for x in range(0, CELL, BAY):
                _rect(c, None, x + 12, y + 10, x + 52, y + 48, [0.12, 0.12, 0.12])
                _rect(c, mask, x + 15, y + 13, x + 49, y + 45, [0.22, 0.26, 0.3], 1.0)
    elif style == 5:    # shop fronts (ground floor = bottom row) + plain offices above
        c[..., :3] = [0.58, 0.60, 0.62]
        for y in range(0, CELL - FLOOR, FLOOR):
            for x in range(0, CELL, BAY):
                _rect(c, mask, x + 6, y + 16, x + 58, y + 46, [0.2, 0.24, 0.28], 1.0)
        y = CELL - FLOOR
        cols = [[0.75, 0.15, 0.15], [0.12, 0.35, 0.65], [0.9, 0.7, 0.1], [0.15, 0.55, 0.3]]
        for i, x in enumerate(range(0, CELL, BAY)):
            _rect(c, None, x, y, x + BAY, y + 14, cols[(i + rng.integers(4)) % 4])           # awning / sign band
            if i % 3 == 2:
                _rect(c, None, x + 4, y + 16, x + 60, y + 64, [0.5, 0.5, 0.52])               # shutter
                for k in range(y + 18, y + 64, 4):
                    _rect(c, None, x + 4, k, x + 60, k + 1, [0.4, 0.4, 0.42])
            else:
                _rect(c, mask, x + 4, y + 16, x + 60, y + 64, [0.3, 0.32, 0.3], 1.0)
    elif style == 6:    # white tile apartment, small windows, stair core strip
        c[..., :3] = [0.86, 0.86, 0.84]
        for y in range(0, CELL, FLOOR):
            for x in range(0, CELL, BAY):
                if x == BAY * 2:
                    _rect(c, None, x + 16, y, x + 48, y + FLOOR, [0.7, 0.72, 0.74])
                    _rect(c, mask, x + 26, y + 20, x + 38, y + 40, [0.25, 0.28, 0.3], 0.8)
                else:
                    _rect(c, mask, x + 10, y + 18, x + 54, y + 42, [0.22, 0.25, 0.28], 1.0)
    else:               # dark glass tower with spandrels
        c[..., :3] = [0.12, 0.14, 0.18]
        mask[:] = 0.85
        for y in range(0, CELL, FLOOR):
            _rect(c, mask, 0, y + 50, CELL, y + FLOOR, [0.22, 0.22, 0.24], 0.0)
        for x in range(0, CELL, BAY // 4):
            _rect(c, None, x, 0, x + 1, CELL, [0.3, 0.32, 0.35])
    _grime(c, rng, 0.25 if style in (0, 7) else 0.45)
    c[..., 3] = mask
    return c


def facade_atlas(seed: int = 7) -> np.ndarray:
    """1024 x 512: 8 styles in 4 columns x 2 rows (see facade_cell)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((CELL * 2, CELL * 4, 4))
    for s in range(8):
        r, k = divmod(s, 4)
        out[r * CELL:(r + 1) * CELL, k * CELL:(k + 1) * CELL] = facade_cell(s, rng)
    return out


# ---------------------------------------------------------------- tree cards (silhouettes with alpha)
def tree_cards(seed: int = 21) -> np.ndarray:
    """512 x 256: left = conifer (cedar/pine tiers), right = broadleaf crown with trunk. Light from the upper left."""
    rng = np.random.default_rng(seed)
    h, w = 256, 512
    out = np.zeros((h, w, 4))
    yy, xx = np.mgrid[0:h, 0:256].astype(float)
    # conifer: stacked tiers, ragged edges
    v = yy / h                                          # 0 top .. 1 bottom
    half = 0.04 + 0.42 * v + 0.05 * np.sin(v * 60.0) * v
    edge = 0.035 * (rng.random((h, 256)) - 0.5)
    dx = (xx - 128) / 256
    a = (np.abs(dx) < half + edge) & (v < 0.9)
    trunk = (np.abs(dx) < 0.03) & (v >= 0.86)
    shade = 0.55 + 0.45 * np.clip(0.5 - dx * 2.5, 0, 1) - 0.25 * ((v * 9.0) % 1.0)
    col = np.array([0.10, 0.24, 0.13])[None, None, :] * shade[..., None]
    out[:, :256, :3] = np.where(a[..., None], col, np.array([0.22, 0.15, 0.1]))
    out[:, :256, 3] = (a | trunk).astype(float)
    # broadleaf: union of discs, darker lower right
    crown = np.zeros((h, 256))
    lit = np.zeros((h, 256))
    for _ in range(26):
        cx = 128 + rng.normal(0, 34)
        cy = 95 + rng.normal(0, 30)
        r = rng.uniform(28, 46)
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
        disc = d < 1.0
        crown = np.maximum(crown, disc)
        lit = np.maximum(lit, np.where(disc, 1.0 - 0.6 * np.clip(((xx - cx) + (yy - cy)) / (2 * r) + 0.4, 0, 1), 0))
    tr = (np.abs(xx - 128) < 9) & (yy > 150) & (yy < 250)
    leaf = np.array([0.16, 0.30, 0.12])[None, None, :] * (0.6 + 0.5 * lit[..., None])
    out[:, 256:, :3] = np.where(crown[..., None] > 0, leaf, np.array([0.26, 0.19, 0.12]))
    out[:, 256:, 3] = np.maximum(crown, tr.astype(float))
    return out
