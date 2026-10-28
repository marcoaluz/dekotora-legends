"""Medidas da oficina, lote 5 (T-234), por RAIOS na malha real do caminhão importado (coordenadas do Godot):

- grade: z da frente da cabine dentro da caixa do encaixe `grille` (a peça encosta no ponto mais à frente);
- buzina: em cima da viseira, encostada na testa (`socket_rules.lot5`); `horn_spot` (topo da carga) ficou só como medida;
- interior: retângulo no plano do para-brisa (maior retângulo só de vidro, ajustado a um plano), onde o jogo põe a arte
  do interior "vista pelo vidro" (`game/scripts/truck/paint_fit.gd`, mesmo formato das pinturas da T-232).
Determinístico (grades fixas de raios).
"""
from __future__ import annotations

import numpy as np
from mathutils import Vector

from . import truck_measure as TM

GRILLE_STEP = 0.04        # m: grade de raios na frente da grade
HORN_W = 0.32             # m: meia largura da caixa da buzina
HORN_L = 0.64             # m: comprimento da caixa da buzina (para a frente da testa)
HORN_H = 0.28             # m: altura da caixa da buzina acima da viseira
HORN_FLAT = 0.06          # m: o topo pode variar isso dentro da caixa (tanque redondo)
HORN_TOP = 0.15           # m: o lugar tem de estar a no máximo isto abaixo do topo da carga (caçamba aberta: não)
HORN_SEARCH = 2.6         # m: procura atrás da frente da carga até isto
HORN_LIFT_MAX = 0.45      # m: andon mais alto que isto = sem pedestal (a buzina fica atrás dele)
WIND_STEP = 0.03          # m: grade de raios no para-brisa
WIND_IN = 0.02            # m: o retângulo recua isto das bordas do vidro
WIND_OFF = 0.004          # m: a arte fica isto na frente do vidro
GRID_U, GRID_V = 12, 6     # grade da arte que segue a curvatura do para-brisa


def _ray_front(tree, x, y, zf):
    """z (Godot) do primeiro ponto atingido vindo da frente, ou None."""
    hit = tree.ray_cast(Vector((x, -zf, y)), Vector((0, -1, 0)))
    return None if hit[0] is None else -hit[0].y


def _ray_down(tree, x, z, top):
    hit = tree.ray_cast(Vector((x, -z, top)), Vector((0, 0, -1)))
    return None if hit[0] is None else hit[0].z


def grille_seat(tree, sock: dict, front_z: float) -> dict:
    """Frente da cabine na área da grade: `face_z` = ponto mais à frente (a peça encosta nele), `back_z` = o mais
    recuado (folga atrás da peça), `cover` = fração da área com lataria (o resto é vão)."""
    (x0, y0, _z0), (x1, y1, _z1) = sock["box"]
    zf = front_z - 3.0
    zs = []
    n = 0
    for x in np.arange(x0 + 0.02, x1 - 0.019, GRILLE_STEP):
        for y in np.arange(y0 + 0.02, y1 - 0.019, GRILLE_STEP):
            n += 1
            z = _ray_front(tree, float(x), float(y), zf)
            if z is not None and z < front_z + 0.6:
                zs.append(z)
    if not zs:
        return {}
    return {"face_z": round(min(zs), 3), "back_z": round(max(zs), 3), "cover": round(len(zs) / max(n, 1), 3)}


def horn_spot(tree, m: dict) -> dict:
    """Lugar da buzina no topo da carga: a primeira janela de HORN_L m (a partir de 5 cm atrás da frente) onde o topo,
    em x = -0,25 / 0 / +0,25, varia menos que HORN_FLAT e fica perto do topo da carga. {} se não houver."""
    bx = m.get("box")
    if not bx:
        return {}
    top = bx["top_y"] + 2.0
    z = bx["front_z"] + 0.05
    zs = np.arange(z, z + HORN_SEARCH, 0.05)
    rows = []
    for zz in zs:
        hs = [_ray_down(tree, x, float(zz), top) for x in (-0.25, 0.0, 0.25)]
        rows.append(None if any(h is None for h in hs) else hs)
    k = int(round(HORN_L / 0.05))
    for i in range(len(rows) - k):
        win = rows[i:i + k + 1]
        if any(r is None for r in win):
            continue
        vals = np.array(win)
        hi, lo = float(vals.max()), float(vals.min())
        if hi - lo <= HORN_FLAT and hi >= bx["top_y"] - HORN_TOP:
            z0 = float(zs[i])
            # andon baixo de fábrica na frente da carga (graneleira, Canter...): a buzina sobe num pedestal até as
            # cornetas passarem por cima dele
            front = [h for r in rows[:i] if r is not None for h in r]
            obs = max(front) if front else hi
            lift = round(obs - hi + 0.03, 3) if obs > hi + 0.05 else 0.0
            if lift > HORN_LIFT_MAX:          # andon alto (0,7-0,9 m): sem pedestal, a buzina fica atrás dele
                lift = 0.0
            return {"y": round(hi, 3), "low": round(lo, 3), "z0": round(z0, 3), "z1": round(z0 + HORN_L, 3), "lift": lift}
    return {}


def _max_rect(ok: np.ndarray):
    """Maior retângulo (em células) só com True numa matriz [linhas y, colunas x]. Devolve (i0, i1, j0, j1) exclusivo."""
    best = (0, 0, 0, 0, 0)
    h = np.zeros(ok.shape[1], dtype=int)
    for i in range(ok.shape[0]):
        h = np.where(ok[i], h + 1, 0)
        stack = []
        for j in range(len(h) + 1):
            cur = h[j] if j < len(h) else 0
            start = j
            while stack and stack[-1][1] >= cur:
                s, hh = stack.pop()
                area = hh * (j - s)
                if area > best[0]:
                    best = (area, i - hh + 1, i + 1, s, j)
                start = s
            stack.append((start, cur))
    return best[1:]


def windshield_rect(glass, m: dict) -> dict:
    """Retângulo da arte do interior no para-brisa: maior retângulo de células com vidro (raios vindos da frente que
    batem no `glass_wind`), ajustado a um plano z = a + b*y + c*x; a arte fica WIND_OFF na frente do ponto mais saliente.
    Formato das pinturas: {c, n, u (direita de quem olha de frente = -x), v (cima, ao longo do vidro), w, h}."""
    (wx0, wy0, wz0), (wx1, wy1, _wz1) = m["cab"]["windshield"]
    zf = wz0 - 3.0
    xs = np.arange(wx0 + 0.01, wx1 - 0.009, WIND_STEP)
    ys = np.arange(wy0 + 0.01, wy1 - 0.009, WIND_STEP)
    zz = np.full((len(ys), len(xs)), np.nan)
    for i, y in enumerate(ys):
        for j, x in enumerate(xs):
            z = _ray_front(glass, float(x), float(y), zf)
            if z is not None:
                zz[i, j] = z
    ok = ~np.isnan(zz)
    if ok.sum() < 20:
        return {}
    i0, i1, j0, j1 = _max_rect(ok)
    if i1 - i0 < 6 or j1 - j0 < 10:
        return {}
    sub = zz[i0:i1, j0:j1]
    X, Y = np.meshgrid(xs[j0:j1], ys[i0:i1])
    A = np.stack([np.ones(X.size), Y.ravel(), X.ravel()], 1)
    a, b, c = np.linalg.lstsq(A, sub.ravel(), rcond=None)[0]
    plane = a + b * Y + c * X
    off = float(np.max(plane - sub)) + WIND_OFF          # ponto mais saliente (z menor = mais à frente)
    x0, x1 = float(xs[j0]) + WIND_IN, float(xs[j1 - 1]) - WIND_IN
    y0, y1 = float(ys[i0]) + WIND_IN, float(ys[i1 - 1]) - WIND_IN
    xc, yc = (x0 + x1) / 2, (y0 + y1) / 2
    zc = a + b * yc + c * xc
    n = np.array([c, b, -1.0])
    n /= np.linalg.norm(n)
    v = np.array([0.0, 1.0, b])
    v /= np.linalg.norm(v)
    u = np.cross(v, n)
    u /= np.linalg.norm(u)
    w = (x1 - x0) * float(np.sqrt(1 + c * c))
    h = (y1 - y0) * float(np.sqrt(1 + b * b))
    # T-234: a arte segue a curvatura do vidro: grade GRID_U x GRID_V de deslocamentos ao longo da normal (m), cada
    # vértice WIND_OFF na frente do vidro de verdade (raio na mesma posição x, y). Linha 0 = embaixo, coluna 0 = s = -1.
    C = np.array([xc, yc, zc])
    grid = []
    for jv in range(GRID_V + 1):
        t = -1.0 + 2.0 * jv / GRID_V
        row = []
        for iu in range(GRID_U + 1):
            sx = -1.0 + 2.0 * iu / GRID_U
            P = C + u * (sx * w / 2) + v * (t * h / 2)
            zg = _ray_front(glass, float(P[0]), float(P[1]), zf)
            if zg is None:
                zg = float(P[2]) - (off - WIND_OFF)
            row.append(round((zg - WIND_OFF - float(P[2])) / float(n[2]), 4))
        grid.append(row)
    r = lambda q: [round(float(t), 4) for t in q]       # noqa: E731
    return {"c": r([xc, yc, zc]), "n": r(n), "u": r(u), "v": r(v), "w": round(w, 3), "h": round(h, 3),
            "grid": grid, "cover": round(float(ok[i0:i1, j0:j1].mean()), 3), "glass_w": round(wx1 - wx0, 3)}


def measure(m: dict) -> dict:
    """Tudo do lote 5 para um caminhão já importado (`truck_measure.import_truck`). Use antes de `socket_rules.sockets`
    só o que não depende dos encaixes; a grade é medida depois (precisa da caixa do encaixe)."""
    tree = TM._bvh()
    glass = TM._bvh(include=("truck_glass_wind",))
    return {"tree": tree, "horn": horn_spot(tree, m), "interior": windshield_rect(glass, m)}
