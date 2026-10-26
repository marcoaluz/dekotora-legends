"""T-217: textures of the route ambience made with numpy (deterministic, nothing downloaded).

All functions return float arrays (h, w, 4) in 0..1, row 0 = TOP of the image (tex_scenic.save_rgba flips).
- stone_wall(): 谷積み (tanizumi) masonry of a retaining wall: squared stones laid DIAGONALLY (diamond grid), dark
  mortar joints, moss in the joints and on the lower part, rain streaks from the top. Tile = 3 m x 3 m.
  stone_wall_normal(): normal map (OpenGL, green = up) from the same height field (stones bulge, joints sink).
- hedge(): dense small leaves of a clipped hedge (tsutsuji / sakaki) for the median strip; tileable.
- mist(): soft cloud blob with alpha (valley mist sheets).
- water(): falling water streaks (tileable vertically) for the waterfall, alpha = foam density.
- danchi_atlas(): cells of the concrete apartment blocks (団地): wall, balcony parapet, window/door, laundry, stair.
- cut_frame(): concrete grid frame of a cut slope (のり枠) with grass in the squares; tileable 4 m.
"""
from __future__ import annotations

import numpy as np

from .tex_scenic import blobs, norm01, value_noise


def _hash2(i: np.ndarray, j: np.ndarray, salt: int) -> np.ndarray:
    """Deterministic 0..1 per integer cell (works on arrays)."""
    h = (i.astype(np.int64) * 73856093) ^ (j.astype(np.int64) * 19349663) ^ (salt * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


# ---------------------------------------------------------------- stone wall (谷積み)
STONES_PER_TILE = 6          # diamonds along each diagonal of the tile


def _stone_field(size: int, seed: int):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    jit = 16.0 * (value_noise(size, rng, ((8, 0.45), (32, 0.35), (96, 0.2))) - 0.5)
    jit2 = 16.0 * (value_noise(size, rng, ((8, 0.45), (32, 0.35), (96, 0.2))) - 0.5)
    x = xx + jit
    y = yy + jit2
    p = size / STONES_PER_TILE
    a = (x + y) / p
    b = (x - y) / p
    i = np.floor(a)
    j = np.floor(b)
    fa = a - i
    fb = b - j
    edge = np.minimum(np.minimum(fa, 1 - fa), np.minimum(fb, 1 - fb))      # 0 at the joint, 0.5 at the centre
    ci = np.mod(i, STONES_PER_TILE)
    cj = np.mod(j, STONES_PER_TILE)
    return rng, edge, ci, cj, fa, fb


def stone_wall(size: int = 1024, seed: int = 217) -> np.ndarray:
    rng, edge, ci, cj, fa, fb = _stone_field(size, seed)
    joint = edge < 0.03 + 0.025 * _hash2(ci, cj, 5)
    r1 = _hash2(ci, cj, 1)
    r2 = _hash2(ci, cj, 2)
    r3 = _hash2(ci, cj, 3)
    grey = 0.40 + 0.22 * r1
    warm = 0.02 + (r2 - 0.5) * 0.07
    base = np.stack([grey + warm, grey + warm * 0.5, grey - warm * 0.4], axis=2)
    grain = norm01(value_noise(size, rng, ((32, 0.3), (128, 0.4), (512, 0.3))))
    pits = blobs(size, rng, 900, 1.0, 3.0) * 0.18
    pillow = np.clip(edge / 0.22, 0, 1)
    tilt = (_hash2(ci, cj, 6) - 0.5) * 0.3
    shade = 0.72 + 0.28 * pillow - (0.16 + tilt) * (fa - 0.5) + (0.08 - tilt) * (fb - 0.5)   # light from the upper left
    col = base * (0.82 + 0.3 * grain - pits)[..., None] * shade[..., None]
    # chipped edges: a lighter rim on the upper sides of each stone
    rim = np.clip(1.0 - np.abs(edge - 0.07) / 0.03, 0, 1) * (fa < 0.5)
    col += rim[..., None] * 0.05
    mortar = np.array([0.16, 0.16, 0.15])
    col = np.where(joint[..., None], mortar * (0.8 + 0.4 * grain[..., None]), col)
    # moss: in the joints and on some stones, more towards the bottom of the tile (the wall repeats every 3 m)
    rows = np.linspace(0.0, 1.0, size)[:, None]
    moss_n = norm01(value_noise(size, rng, ((4, 0.5), (16, 0.3), (64, 0.2))))
    moss = np.clip((moss_n - 0.55) * 3.0, 0, 1) * (0.4 + 0.6 * rows)
    moss_j = joint * np.clip(moss_n * 1.4 - 0.2, 0, 1)
    m = np.clip(moss * (r3 > 0.6) * 0.55 + moss_j * (moss_n > 0.45), 0, 1)[..., None]
    col = col * (1 - m * 0.65) + np.array([0.20, 0.27, 0.11]) * m * 0.65
    # rain streaks (vertical, tileable: wraps)
    sr = rng.random(size // 16)
    sr = np.repeat(sr, 16)
    sr = np.convolve(np.concatenate([sr[-24:], sr, sr[:24]]), np.ones(24) / 24.0, mode="same")[24:-24]
    streak = np.repeat(np.clip((sr - 0.55) * 3.0, 0, 1)[None, :], size, axis=0)
    streak = np.clip(streak * norm01(value_noise(size, rng, ((2, 0.6), (8, 0.4)))) * 1.6, 0, 1)
    col *= (1.0 - 0.3 * streak)[..., None]
    out = np.ones((size, size, 4))
    out[..., :3] = np.clip(col, 0, 1)
    return out


def stone_wall_height(size: int = 1024, seed: int = 217) -> np.ndarray:
    rng, edge, ci, cj, fa, fb = _stone_field(size, seed)
    r1 = _hash2(ci, cj, 4)
    dome = np.clip(edge / 0.2, 0, 1)
    dome = dome * dome * (3 - 2 * dome)
    rough = norm01(value_noise(size, rng, ((32, 0.4), (128, 0.4), (512, 0.2))))
    h = dome * (0.75 + 0.25 * r1) + 0.12 * rough * (edge > 0.045)
    return h


def stone_wall_normal(size: int = 1024, seed: int = 217, strength: float = 5.0) -> np.ndarray:
    h = stone_wall_height(size, seed)
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dup = (np.roll(h, 1, axis=0) - np.roll(h, -1, axis=0)) * 0.5      # row 0 = top: "up" = previous row
    n = np.stack([-dx * strength, -dup * strength, np.ones_like(h)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    out = np.ones((size, size, 4))
    out[..., :3] = n * 0.5 + 0.5
    return out


# ---------------------------------------------------------------- hedge
def hedge(size: int = 512, seed: int = 218) -> np.ndarray:
    rng = np.random.default_rng(seed)
    leaves = blobs(size, rng, 1500, 5.0, 10.0, shade=0.8)
    leaves2 = blobs(size, rng, 1200, 3.0, 6.0, shade=0.6)
    v = np.maximum(leaves, leaves2 * 0.9)
    tone = norm01(value_noise(size, rng, ((4, 0.5), (16, 0.3), (64, 0.2))))
    dark = np.array([0.06, 0.12, 0.04])
    mid = np.array([0.20, 0.36, 0.12])
    light = np.array([0.42, 0.58, 0.22])
    col = dark + (mid - dark) * np.clip(v * 1.6, 0, 1)[..., None] + (light - mid) * np.clip(v * 2 - 1, 0, 1)[..., None]
    col *= (0.8 + 0.4 * tone)[..., None]
    out = np.ones((size, size, 4))
    out[..., :3] = np.clip(col, 0, 1)
    return out


# ---------------------------------------------------------------- mist / water
def mist(size: int = 256, seed: int = 219) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = norm01(value_noise(size, rng, ((4, 0.5), (8, 0.3), (32, 0.2))))
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1.0)
    fall = np.clip(1.0 - (((xx - 0.5) / 0.5) ** 2 + ((yy - 0.5) / 0.5) ** 2), 0, 1)
    a = np.clip(fall * (0.35 + 0.9 * n) - 0.1, 0, 1)
    out = np.ones((size, size, 4))
    out[..., 3] = a ** 1.3
    return out


def water(w: int = 256, h: int = 512, seed: int = 220) -> np.ndarray:
    rng = np.random.default_rng(seed)
    cols = rng.random(w)
    cols = np.convolve(np.concatenate([cols, cols[:8]]), np.ones(8) / 8.0, mode="same")[:w]
    streak = np.repeat(cols[None, :], h, axis=0)
    flow = np.zeros((h, w))
    for k in (4, 9, 17):                                   # vertically tileable stretched noise
        g = rng.random((k, w // 4))
        idx = np.arange(h) * k / h
        i0 = np.floor(idx).astype(int)
        f = (idx - i0)[:, None]
        i1 = (i0 + 1) % k
        rows = g[i0] * (1 - f) + g[i1] * f
        flow += np.repeat(rows, 4, axis=1)[:, :w] / 3.0
    foam = np.clip(0.4 * streak + 0.8 * flow - 0.35, 0, 1)
    out = np.ones((h, w, 4))
    out[..., 0] = 0.78 + 0.2 * foam
    out[..., 1] = 0.86 + 0.12 * foam
    out[..., 2] = 0.92 + 0.08 * foam
    out[..., 3] = np.clip(0.35 + 0.75 * foam, 0, 1)
    return out


# ---------------------------------------------------------------- danchi (団地) atlas
DC = 256     # cell size; atlas 1024 x 512 = 4 x 2 cells


def danchi_atlas(seed: int = 221) -> np.ndarray:
    """Cells (column, row): (0,0) wall, (1,0) balcony parapet, (2,0) window/door bay (alpha = glass), (3,0) laundry
    (alpha), (0,1) stair core grille, (1,1) gable wall with stains, (2,1) roof (tar/concrete), (3,1) small shop front."""
    rng = np.random.default_rng(seed)
    out = np.zeros((DC * 2, DC * 4, 4))
    out[..., 3] = 1.0

    def cell(cx, cy):
        return out[cy * DC:(cy + 1) * DC, cx * DC:(cx + 1) * DC]

    n = lambda: norm01(value_noise(DC, rng, ((4, 0.5), (16, 0.3), (64, 0.2))))
    streak = lambda amt: (1.0 - amt * np.clip((np.repeat(rng.random((1, DC)), DC, axis=0) - 0.6) * 2.5, 0, 1)
                          * np.linspace(1.0, 0.3, DC)[:, None])
    # wall: cream concrete with rain stains
    c = cell(0, 0)
    c[..., :3] = np.array([0.80, 0.78, 0.71]) * (0.9 + 0.15 * n())[..., None] * streak(0.25)[..., None]
    # balcony parapet: white panel, vertical drip stains, drain spout, dark top rail line
    c = cell(1, 0)
    c[..., :3] = np.array([0.86, 0.85, 0.80]) * (0.92 + 0.1 * n())[..., None] * streak(0.35)[..., None]
    c[:10, :, :3] = [0.55, 0.56, 0.56]
    c[-6:, :, :3] = [0.6, 0.58, 0.55]
    for x in range(0, DC, 64):
        c[:, x:x + 3, :3] *= 0.85
    # window / sliding door bay: frame, 2 glass panes (alpha 1 = glass), curtains in some
    c = cell(2, 0)
    c[..., :3] = [0.62, 0.63, 0.62]
    c[..., 3] = 0.0
    c[24:232, 20:236, :3] = [0.68, 0.70, 0.70]
    for x0, x1 in ((28, 126), (130, 228)):
        c[32:224, x0:x1, :3] = [0.18, 0.22, 0.26]
        c[32:224, x0:x1, 3] = 1.0
    c[32:224, 30:70, :3] = [0.75, 0.68, 0.55]                # curtain
    c[32:224, 30:70, 3] = 0.6
    # laundry on the balcony pole: towels and shirts in colours (alpha cut-out)
    c = cell(3, 0)
    c[..., :] = 0.0
    c[18:22, :, :3] = [0.6, 0.6, 0.62]
    c[18:22, :, 3] = 1.0
    x = 6
    pal = [[0.95, 0.95, 0.92], [0.55, 0.75, 0.95], [0.95, 0.75, 0.25], [0.85, 0.35, 0.35], [0.35, 0.6, 0.4],
           [0.95, 0.85, 0.85], [0.3, 0.35, 0.55]]
    while x < DC - 20:
        w = int(rng.integers(18, 44))
        h = int(rng.integers(60, 150))
        col = np.array(pal[int(rng.integers(len(pal)))]) * (0.85 + 0.15 * rng.random())
        c[22:22 + h, x:x + w, :3] = col
        c[22:22 + h, x:x + w, 3] = 1.0
        if rng.random() < 0.4:                                  # shirt: shoulders wider than the body
            c[22:40, max(x - 6, 0):x + w + 6, :3] = col
            c[22:40, max(x - 6, 0):x + w + 6, 3] = 1.0
        x += w + int(rng.integers(4, 14))
    # stair core: vertical slots + railings
    c = cell(0, 1)
    c[..., :3] = [0.74, 0.73, 0.69]
    for y in range(0, DC, 64):
        c[y + 20:y + 56, 30:226, :3] = [0.16, 0.17, 0.18]
        for xx in range(34, 226, 12):
            c[y + 20:y + 56, xx:xx + 2, :3] = [0.6, 0.6, 0.6]
    # gable wall: big flat wall with stains (the block number is a Label3D on top of it)
    c = cell(1, 1)
    c[..., :3] = np.array([0.82, 0.80, 0.74]) * (0.88 + 0.16 * n())[..., None] * streak(0.4)[..., None]
    # roof: tar sheet + concrete edge
    c = cell(2, 1)
    c[..., :3] = np.array([0.32, 0.31, 0.30]) * (0.85 + 0.2 * n())[..., None]
    # small shop front: shutter + awning band
    c = cell(3, 1)
    c[..., :3] = [0.55, 0.56, 0.57]
    for y in range(80, DC, 6):
        c[y:y + 2, :, :3] = [0.42, 0.43, 0.44]
    c[0:70, :, :3] = [0.15, 0.32, 0.62]
    c[60:70, :, :3] = [0.9, 0.9, 0.88]
    return np.clip(out, 0, 1)


# ---------------------------------------------------------------- cut slope with concrete frames (のり枠)
def cut_frame(size: int = 512, seed: int = 222) -> np.ndarray:
    rng = np.random.default_rng(seed)
    grass = norm01(value_noise(size, rng, ((8, 0.4), (32, 0.35), (128, 0.25))))
    blades = rng.random((size, size))
    col = np.stack([0.20 + 0.10 * grass, 0.30 + 0.14 * grass, 0.10 + 0.05 * grass], axis=2)
    col *= (0.85 + 0.3 * blades)[..., None]
    yy, xx = np.mgrid[0:size, 0:size]
    beam = size // 16
    frame = ((xx % (size // 2)) < beam) | ((yy % (size // 2)) < beam)
    conc = np.array([0.66, 0.65, 0.61]) * (0.85 + 0.2 * norm01(value_noise(size, rng, ((8, 0.5), (32, 0.5)))))[..., None]
    col = np.where(frame[..., None], conc, col)
    out = np.ones((size, size, 4))
    out[..., :3] = np.clip(col, 0, 1)
    return out
