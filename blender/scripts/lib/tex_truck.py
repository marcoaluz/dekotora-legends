"""Texturas procedurais (numpy) do caminhão, T-106. Todas determinísticas (semente fixa) e leves (512-1024 px).

Convenção das imagens: linha 0 = EMBAIXO (como o Blender guarda os pixels).

Mapeamento "altura" (ver `mesh3d.uv_height`): u = metros na horizontal / TILE_U, v = altura / TILE_V. Assim a
sujeira fica sempre embaixo (lama das rodas) e os escorridos de chuva descem de cima, em qualquer peça.
A faixa de cima da textura (v > ROOF_V) é limpa: tetos e faces viradas para cima usam só ela.
"""
from __future__ import annotations

import numpy as np

TILE_U = 4.0
TILE_V = 5.0
ROOF_V = 0.92


def _noise(h, w, rng, octaves):
    """Ruído de valor repetível (bordas casam) em várias escalas; `octaves` = [(células_x, células_y, amp)]."""
    acc = np.zeros((h, w))
    for cx, cy, amp in octaves:
        g = rng.random((cy, cx))
        fx = np.arange(w) * cx / w
        fy = np.arange(h) * cy / h
        x0 = np.floor(fx).astype(int)
        y0 = np.floor(fy).astype(int)
        tx = fx - x0
        ty = fy - y0
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        x1 = (x0 + 1) % cx
        y1 = (y0 + 1) % cy
        a = g[y0][:, x0] * (1 - tx) + g[y0][:, x1] * tx
        b = g[y1][:, x0] * (1 - tx) + g[y1][:, x1] * tx
        acc += amp * (a * (1 - ty)[:, None] + b * ty[:, None])
    return acc


def _normal_from_height(hgt, strength):
    """Mapa de normais (OpenGL, +Y para cima) a partir de um campo de altura repetível."""
    dx = (np.roll(hgt, -1, axis=1) - np.roll(hgt, 1, axis=1)) * strength
    dy = (np.roll(hgt, -1, axis=0) - np.roll(hgt, 1, axis=0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(hgt)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def _height_m(h):
    return (np.arange(h) + 0.5) / h * TILE_V                    # altura (m) de cada linha


def paint_maps(size: int = 1024, seed: int = 106):
    """Pintura de caminhão usado: (cor que multiplica a tinta, ORM, normal).
    - poeira/lama embaixo (z < 1,5 m) quebrada por ruído, respingos e lascas de pedra na faixa baixa;
    - escorridos de chuva finos que descem de alturas aleatórias;
    - riscos finos raros; manchas suaves de verniz;
    - normal: casca de laranja (ondulação de ~2 cm do verniz) + ondulação larga da chapa + flocos metálicos."""
    rng = np.random.default_rng(seed)
    h = w = size
    z = _height_m(h)[:, None] * np.ones((1, w))
    mott = _noise(h, w, rng, [(8, 10, 0.6), (32, 40, 0.4)]) - 0.5
    brk = _noise(h, w, rng, [(16, 20, 0.5), (64, 80, 0.5)])
    dust = 0.42 * np.clip((1.45 - z) / 1.05, 0, 1) ** 1.6 * (0.55 + 0.9 * brk)
    spl = rng.random((h, w))
    dust += (spl > 1 - 0.035 * np.clip((1.2 - z) / 0.8, 0, 1)) * rng.uniform(0.1, 0.35, (h, w))
    streak = np.zeros((h, w))
    px_m = h / TILE_V
    for _ in range(110):
        x = int(rng.integers(0, w))
        wd = int(rng.integers(1, 4))
        z0 = rng.uniform(1.2, 3.8)
        ln = rng.uniform(0.25, 1.3)
        a = rng.uniform(0.025, 0.085)
        r1 = int(z0 * px_m)
        r0 = max(int((z0 - ln) * px_m), 0)
        if r1 <= r0:
            continue
        ramp = np.linspace(0.0, 1.0, r1 - r0) ** 1.5 * a           # mais forte em cima, some para baixo
        wig = (np.cumsum(rng.integers(-1, 2, r1 - r0)) // 9)
        for k in range(wd):
            cols = (x + k + wig) % w
            streak[np.arange(r0, r1), cols] += ramp * (1 - abs(k - wd / 2) / (wd + 1))
    chips = np.zeros((h, w))
    yy, xx = np.mgrid[-3:4, -3:4]
    for _ in range(260):                                         # lascas de pedra (frente/baixo): pontinhos redondos
        r = int(rng.uniform(0.35, 1.3) * px_m)
        cx = int(rng.integers(3, w - 3))
        rad = rng.uniform(0.7, 2.2)
        blob = np.clip(rad + 0.5 - np.sqrt(xx ** 2 + yy ** 2 * rng.uniform(0.6, 1.4)), 0, 1) * rng.uniform(0.2, 0.4)
        r0 = min(max(r, 3), h - 4)
        chips[r0 - 3:r0 + 4, cx - 3:cx + 4] = np.maximum(chips[r0 - 3:r0 + 4, cx - 3:cx + 4], blob)
    scratch = np.zeros((h, w))
    for _ in range(45):                                          # riscos finos
        r = rng.uniform(0.6, 2.6) * px_m
        c0 = rng.uniform(0, w)
        ang = rng.uniform(-0.5, 0.5)
        ln = rng.uniform(15, 70)
        t = np.linspace(0, ln, int(ln) * 2)
        rr = np.clip((r + t * np.sin(ang)).astype(int), 0, h - 1)
        cc = (c0 + t * np.cos(ang)).astype(int) % w
        scratch[rr, cc] = rng.uniform(0.06, 0.14)
    roof = z > ROOF_V * TILE_V
    dust = np.where(roof, 0.05 * brk + (spl > 0.997) * 0.12, dust)
    streak[roof] = 0
    dirt = np.clip(dust + streak, 0, 0.75)
    dust_col = np.array([0.78, 0.72, 0.63])
    col = 1.0 - dirt[..., None] * (1 - dust_col) - (chips + scratch)[..., None] * np.array([0.5, 0.5, 0.48])
    col *= (1.0 + 0.025 * mott)[..., None]
    col = np.clip(col, 0.35, 1.0)
    peel = _noise(h, w, rng, [(128, 160, 1.0)])
    rough = 0.24 + 0.03 * (peel - 0.5) + 0.06 * mott + 0.85 * dirt + 0.5 * chips
    metal = 0.35 * np.clip(1 - 1.6 * dirt - 2.0 * chips, 0.1, 1)
    orm = np.stack([np.ones((h, w)), np.clip(rough, 0.14, 0.9), metal], axis=2)
    orm = orm.reshape(h // 2, 2, w // 2, 2, 3).mean(axis=(1, 3))     # rugosidade em meia resolução (basta)
    wave = _noise(h, w, rng, [(6, 8, 1.0)])
    # casca de laranja (~3 cm) bem sutil + ondulação larga da chapa + bordas das lascas/riscos. Sem ruído
    # por pixel (flocos): não aparece a 30 m no celular e o PNG não comprimiria.
    hgt = 0.05 * peel + 0.9 * wave - 0.35 * chips - 0.15 * scratch
    return col, orm, _normal_from_height(hgt, 1.0)


def plastic_maps(size: int = 512, seed: int = 207):
    """Plástico preto texturizado com poeira clara embaixo: (cor, ORM)."""
    rng = np.random.default_rng(seed)
    h = w = size
    z = _height_m(h)[:, None] * np.ones((1, w))
    brk = _noise(h, w, rng, [(12, 15, 0.5), (48, 60, 0.5)])
    dust = 0.75 * np.clip((1.35 - z) / 1.0, 0, 1) ** 1.3 * (0.4 + 1.0 * brk)
    dust = np.where(z > ROOF_V * TILE_V, 0.08 * brk, dust)
    grain = (_noise(h, w, rng, [(128, 128, 1.0)]) - 0.5) * 0.012
    base = np.array([0.075, 0.075, 0.082])
    dcol = np.array([0.36, 0.33, 0.29])
    col = base + (dcol - base) * np.clip(dust, 0, 0.8)[..., None] + grain[..., None]
    rough = 0.55 + 0.35 * np.clip(dust, 0, 1) + (brk - 0.5) * 0.06
    orm = np.stack([np.ones((h, w)), np.clip(rough, 0.3, 0.95), np.zeros((h, w))], axis=2)
    return np.clip(col, 0, 1), orm


def glass_wind_maps(w: int = 512, h: int = 256, seed: int = 308):
    """Para-brisa: vidro escuro com película de poeira fora dos arcos limpos pelos limpadores, faixa suja embaixo
    (onde ficam as palhetas) e bordas. UV: u 0..1 de um lado ao outro, v 0..1 de baixo para cima. (cor, ORM)."""
    rng = np.random.default_rng(seed)
    v = (np.arange(h) + 0.5)[:, None] / h * np.ones((1, w))
    u = np.ones((h, 1)) * (np.arange(w) + 0.5)[None, :] / w
    W, H = 2.4, 1.0                                              # metros aproximados do vidro
    wiped = np.zeros((h, w), bool)
    for pu in (0.27, 0.66):
        d = np.sqrt(((u - pu) * W) ** 2 + ((v + 0.06) * H) ** 2)
        wiped |= (d > 0.22) & (d < 0.98) & (v > 0.07)
    brk = _noise(h, w, rng, [(16, 8, 0.5), (64, 32, 0.5)])
    edge = np.minimum(np.minimum(u, 1 - u) * W, np.minimum(v, 1 - v) * H)
    dirt = np.where(wiped, 0.03, 0.26 + 0.2 * brk)
    dirt += 0.25 * np.clip((0.06 - edge) / 0.06, 0, 1)
    dirt = np.clip(dirt, 0, 0.7)
    base = np.array([0.1, 0.17, 0.3])
    film = np.array([0.42, 0.41, 0.38])
    col = base + (film - base) * dirt[..., None]
    rough = 0.04 + 0.6 * dirt
    orm = np.stack([np.ones((h, w)), np.clip(rough, 0.03, 0.6), 0.5 * (1 - dirt)], axis=2)
    return np.clip(col, 0, 1), orm


def diamond_maps(n: int = 8, size: int = 256, seed: int = 409):
    """Chapa xadrez (degraus): losangos em relevo gastos (topo claro) e sujeira nos vãos. (cor, normal)."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size]
    u = (xx / size * n) % 1.0
    v = (yy / size * n) % 1.0
    flip = ((np.floor(xx / size * n) + np.floor(yy / size * n)) % 2) == 1
    a = np.where(flip, np.abs(u - 0.5) * 0.45 + np.abs(v - 0.5), np.abs(u - 0.5) + np.abs(v - 0.5) * 0.45)
    bump = np.clip((0.3 - a) / 0.07, 0, 1)
    dirt = _noise(size, size, rng, [(8, 8, 0.6), (32, 32, 0.4)])
    lo = np.array([0.27, 0.28, 0.3])
    hi = np.array([0.78, 0.8, 0.84])
    dcol = np.array([0.2, 0.18, 0.15])
    col = lo + (hi - lo) * bump[..., None]
    col = col + (dcol - col) * (np.clip(dirt - 0.45, 0, 1) * (1 - bump))[..., None] * 1.5
    nrm = _normal_from_height(bump, 2.5)
    return np.clip(col, 0, 1), nrm


def tire_maps(profile, R: float, w: int = 256, seed: int = 510):
    """Pneu: 1 linha por ponto do perfil do torno (v = índice / n). Banda de rodagem um pouco mais clara e lisa
    (gasta), flanco escuro com poeira marrom perto do ombro e anéis finos em relevo. (cor, ORM)."""
    rng = np.random.default_rng(seed)
    m = len(profile)
    rows = []
    rough = []
    for (r, _a) in profile:
        tread = r >= R - 1e-6
        t = max(0.0, min(1.0, (r - 0.6 * R) / (0.4 * R)))
        if tread:
            c = np.array([0.13, 0.13, 0.135])
            ro = 0.78
        else:
            c = np.array([0.075, 0.075, 0.08]) + np.array([0.09, 0.075, 0.055]) * t ** 2
            ro = 0.9
        rows.append(c)
        rough.append(ro)
    col = np.array(rows)[:, None, :] * np.ones((1, w, 1))
    col *= (1 + (rng.random((m, w)) - 0.5) * 0.12)[..., None]
    orm = np.stack([np.ones((m, w)), np.array(rough)[:, None] * np.ones((1, w)), np.zeros((m, w))], axis=2)
    return np.clip(col, 0, 1), orm


def honeycomb(w: int = 768, h: int = 384, cols: int = 30, seed: int = 611):
    """Grade em colmeia (plástico/metal escuro com furos hexagonais), como a grade baixa de um FH. (cor, normal)."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    dx = w / cols
    dy = dx * np.sqrt(3.0)
    cands = []
    for ox, oy in ((0.0, 0.0), (dx / 2, dy / 2)):
        jy = np.round((yy - oy) / dy) * dy + oy
        ix = np.floor((xx - ox) / dx) * dx + ox
        for k in (0, 1):
            cands.append(np.sqrt((xx - ix - k * dx) ** 2 + (yy - jy) ** 2))
    d = np.sort(np.stack(cands), axis=0)
    edge = d[1] - d[0]                                           # 0 na fronteira entre células (hexágono)
    frame = np.clip((0.16 * dx - edge) / (0.06 * dx), 0, 1)
    hole_shade = np.clip(d[0] / (0.5 * dx), 0, 1) * 0.06         # fundo do furo com leve gradiente
    frame_col = np.array([0.2, 0.21, 0.23]) * (1 + (_noise(h, w, rng, [(8, 4, 1.0)]) - 0.5) * 0.3)[..., None]
    col = frame_col * frame[..., None] + (0.02 + hole_shade)[..., None] * (1 - frame[..., None])
    return np.clip(col, 0, 1), _normal_from_height(frame, 1.5)


def slots(w: int = 1024, h: int = 48, n: int = 44):
    """Grelha de fendas (caixa de ar sob o para-brisa, respiros): fendas verticais arredondadas, escuras, sobre
    plástico grafite; feita para faixas finas e compridas (proporção ~20:1). (cor, normal)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    cw = w / n
    u = (xx % cw) / cw - 0.5                                     # -0,5..0,5 dentro de cada célula
    v = yy / h - 0.5
    d = np.sqrt((np.maximum(np.abs(u) - 0.18, 0) / 0.12) ** 2 + (np.maximum(np.abs(v) - 0.22, 0) / 0.16) ** 2)
    hole = np.clip((1.0 - d) / 0.25, 0, 1) * (np.abs(u) < 0.32) * (np.abs(v) < 0.4)
    frame = np.array([0.16, 0.165, 0.18])
    col = frame * (1 - hole[..., None]) + np.array([0.015, 0.015, 0.02]) * hole[..., None]
    return np.clip(col, 0, 1), _normal_from_height(1 - hole, 1.2)
