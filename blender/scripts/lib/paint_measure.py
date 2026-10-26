"""Faces de pintura do baú (T-232): mural de cada lateral, pintura da traseira (portas) e pintura do teto.

Cada face vira um RETÂNGULO no plano real da lataria, medido por RAIOS na malha do .glb (BVH), em coordenadas do Godot:
  {"c": centro, "n": normal (para fora), "u": direita da imagem, "v": cima da imagem, "w": largura, "h": altura}
O jogo põe ali um quadrado com a textura (`game/scripts/truck/paint_fit.gd`), 5 mm para fora do plano.

Regras (decisão 12 do Marco: nada cobre farol, lanterna, placa, para-brisa, porta ou roda):
- a face fica por DENTRO do contorno de LED (T-231) e, na traseira, dentro das portas (zona `rear_doors`: a pintura é
  isenta dela, porque é tinta na própria porta, não um volume na frente);
- célula ruim = buraco/vão (o raio entra mais de 1,5 cm atrás do plano) ou luzinha de fábrica rente à face (até 1,2 cm
  para fora): a borda do retângulo recua até cada linha/coluna da borda ter >= 92% de células boas. O que sai mais
  que isso da face (trilhos, montantes, ferragens, luzinhas salientes) continua NA FRENTE da pintura;
- vão estreito (até 6 cm, a fresta entre as portas) não corta o retângulo: a fresta é pintada na própria arte.
Determinístico (raios numa grade fixa de 2,5 cm).
"""
from __future__ import annotations

import numpy as np

from . import truck_measure as TM

STEP = 0.025          # m: grade de amostras
DEEP = 0.015          # m: mais fundo que isso atrás do plano = vão/buraco
FLUSH = 0.012         # m: luzinha até essa altura para fora do plano = rente (a pintura a cobriria)
GOOD = 0.92           # fração mínima de células boas em cada borda do retângulo
GAP_OK = 0.06         # m: vãos estreitos (fresta das portas) não cortam o retângulo
MARGIN = 0.03         # m: folga para dentro do contorno de LED / da borda do baú
OFFSET = 0.005        # m: o jogo desenha a pintura esse tanto para fora do plano


def _lines(segs, across_axis):
    """Posições (no eixo `across_axis`) das linhas do contorno que correm perpendiculares a ele."""
    out = []
    for g in segs:
        w = g["w"]
        if abs(w[across_axis]) > 0.5:
            out.append(float(g["a"][across_axis]))
    return out


def _inside(vals, lo, hi):
    """Aperta [lo, hi] para ficar por dentro das linhas `vals` que estão perto das bordas."""
    mid = (lo + hi) / 2
    lo2 = max([lo] + [v + TM.STRIP_W / 2 + MARGIN for v in vals if v < mid])
    hi2 = min([hi] + [v - TM.STRIP_W / 2 - MARGIN for v in vals if v > mid])
    return lo2, hi2


def _close_gaps(bad: np.ndarray, cells: int) -> np.ndarray:
    """Tira das linhas de `bad` (ao longo do eixo 1) os trechos ruins com até `cells` células (fresta)."""
    out = bad.copy()
    for i in range(bad.shape[0]):
        row = bad[i]
        j = 0
        n = len(row)
        while j < n:
            if row[j]:
                k = j
                while k < n and row[k]:
                    k += 1
                if j > 0 and k < n and (k - j) <= cells:
                    out[i, j:k] = False
                j = k
            else:
                j += 1
    return out


def _shrink(bad: np.ndarray):
    """Recorta linhas/colunas da borda até cada borda ter >= GOOD de células boas. Devolve (i0, i1, j0, j1) exclusivo."""
    i0, i1, j0, j1 = 0, bad.shape[0], 0, bad.shape[1]
    while i1 - i0 > 2 and j1 - j0 > 2:
        sub = bad[i0:i1, j0:j1]
        fr = {"i0": 1 - sub[0].mean(), "i1": 1 - sub[-1].mean(), "j0": 1 - sub[:, 0].mean(), "j1": 1 - sub[:, -1].mean()}
        worst = min(fr, key=lambda k: (fr[k], k))
        if fr[worst] >= GOOD:
            break
        if worst == "i0":
            i0 += 1
        elif worst == "i1":
            i1 -= 1
        elif worst == "j0":
            j0 += 1
        else:
            j1 -= 1
    return i0, i1, j0, j1


def _face(tree, lamps, origin, ea, eb, na, nb, n):
    """Mede a face: `origin` + i*STEP*ea + j*STEP*eb (i < na, j < nb), normal `n` (para fora).
    Devolve (plano, i0, i1, j0, j1) ou None."""
    o, a, b, nv = (np.array(x, float) for x in (origin, ea, eb, n))
    pr = np.full((na, nb), np.nan)
    for i in range(na):
        for j in range(nb):
            p = o + a * (STEP * (i + 0.5)) + b * (STEP * (j + 0.5))
            q = TM._protrusion(tree, [float(x) for x in p], [float(x) for x in nv])
            if q is not None:
                pr[i, j] = q
    ok = pr[~np.isnan(pr)]
    if ok.size < 0.5 * pr.size:
        return None
    plane = float(np.median(ok))
    bad = np.isnan(pr) | (pr < plane - DEEP)
    if len(lamps):
        rel = lamps - o
        ii = np.floor((rel @ a) / STEP).astype(int)
        jj = np.floor((rel @ b) / STEP).astype(int)
        hh = rel @ nv
        sel = (ii >= 0) & (ii < na) & (jj >= 0) & (jj < nb) & (hh >= plane - DEEP) & (hh <= plane + FLUSH)
        bad[ii[sel], jj[sel]] = True
    gap = int(round(GAP_OK / STEP))
    bad = _close_gaps(bad, gap)
    bad = _close_gaps(bad.T, gap).T
    i0, i1, j0, j1 = _shrink(bad)
    return plane, i0, i1, j0, j1


def _rect(origin, ea, eb, plane, n, i0, i1, j0, j1, u, v):
    """Retângulo final (centro no plano + OFFSET) com os eixos da imagem u (direita) e v (cima)."""
    o, a, b, nv = (np.array(x, float) for x in (origin, ea, eb, n))
    p0 = o + a * (STEP * i0) + b * (STEP * j0)
    p1 = o + a * (STEP * i1) + b * (STEP * j1)
    c = (p0 + p1) / 2 + nv * (plane + OFFSET)
    ext = np.abs(p1 - p0)
    uu, vv = np.array(u, float), np.array(v, float)
    return {"c": [round(float(x), 3) for x in c], "n": [float(x) for x in n], "u": [float(x) for x in u],
            "v": [float(x) for x in v], "w": round(float(ext @ np.abs(uu)), 3), "h": round(float(ext @ np.abs(vv)), 3)}


def paint_faces(data: dict, m: dict, edges: dict, rear_doors: list) -> dict:
    """Retângulos das 4 faces de pintura de um baú fechado (vazio para carroceria aberta).
    `edges` = saída de `truck_measure.box_edges` (contorno de LED); `rear_doors` = caixa da zona das portas de trás."""
    if m.get("open_body") or not m.get("box"):
        return {}
    objs = data["objs"]
    bx = m["box"]
    bh, top, bot, bf, rz = bx["half_w"], bx["top_y"], bx["bottom_y"], bx["front_z"], bx["rear_z"]
    tree = TM._bvh()
    lamps = TM._cat(objs, [k for k in objs if k.startswith("truck_lamp")])
    strips = edges.get("strips", {})
    out = {}
    # --- laterais: y entre as linhas de cima/baixo do contorno, z entre as da frente/trás
    for side, sx in (("r", 1), ("l", -1)):
        segs = strips.get("box_light_" + side, [])
        y0, y1 = _inside(_lines(segs, 1), bot + MARGIN, top - MARGIN)
        z0, z1 = _inside(_lines(segs, 2), bf + MARGIN, rz - MARGIN)
        na, nb = int((y1 - y0) / STEP), int((z1 - z0) / STEP)
        origin = (sx * bh, y0, z0)
        f = _face(tree, lamps, origin, (0, 1, 0), (0, 0, 1), na, nb, (sx, 0, 0))
        if f:
            plane, i0, i1, j0, j1 = f
            u = (0, 0, -1) if sx > 0 else (0, 0, 1)       # a frente fica à direita da imagem no lado direito
            out["mural_" + side] = _rect(origin, (0, 1, 0), (0, 0, 1), plane, (sx, 0, 0), i0, i1, j0, j1, u, (0, 1, 0))
    # --- traseira: dentro da zona das portas (a pintura é tinta na porta)
    (dx0, dy0, _dz0), (dx1, dy1, _dz1) = rear_doors
    na, nb = int((dy1 - dy0) / STEP), int((dx1 - dx0) / STEP)
    origin = (dx0, dy0, rz)
    f = _face(tree, lamps, origin, (0, 1, 0), (1, 0, 0), na, nb, (0, 0, 1))
    if f:
        plane, i0, i1, j0, j1 = f
        out["rear_paint"] = _rect(origin, (0, 1, 0), (1, 0, 0), plane, (0, 0, 1), i0, i1, j0, j1, (1, 0, 0), (0, 1, 0))
    # --- teto: por dentro das linhas compridas e das pontas do contorno do teto
    segs = strips.get("box_light_top", [])
    x0, x1 = _inside(_lines(segs, 0), -bh + MARGIN, bh - MARGIN)
    z0, z1 = _inside(_lines(segs, 2), bf + MARGIN, rz - MARGIN)
    na, nb = int((x1 - x0) / STEP), int((z1 - z0) / STEP)
    origin = (x0, top, z0)
    f = _face(tree, lamps, origin, (1, 0, 0), (0, 0, 1), na, nb, (0, 1, 0))
    if f:
        plane, i0, i1, j0, j1 = f
        out["roof_paint"] = _rect(origin, (1, 0, 0), (0, 0, 1), plane, (0, 1, 0), i0, i1, j0, j1, (1, 0, 0), (0, 0, -1))
    return out
