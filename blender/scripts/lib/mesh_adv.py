"""Modelagem avançada por bmesh: lofts (anéis ligados), sólidos de revolução (pneus, aros, arcos).

Complementa `mesh3d.py`. Convenções iguais: metros, frente = +Y, chão Z=0.
"""
from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from .mesh3d import _link


def rounded_rect_ring(hw: float, y0: float, y1: float, z: float, rf: float, rr: float, n: int = 6):
    """Anel (lista de (x,y,z)) de um retângulo com cantos arredondados, visto de cima, sentido anti-horário.
    Frente (y1) com raio `rf`, traseira (y0) com raio `rr`."""
    rf = max(0.001, min(rf, hw - 0.001, (y1 - y0) / 2 - 0.001))
    rr = max(0.001, min(rr, hw - 0.001, (y1 - y0) / 2 - 0.001))
    corners = [((hw - rf, y1 - rf), rf, 0), ((-hw + rf, y1 - rf), rf, 90),
               ((-hw + rr, y0 + rr), rr, 180), ((hw - rr, y0 + rr), rr, 270)]
    pts = []
    for (cx, cy), r, a0 in corners:
        for k in range(n + 1):
            a = math.radians(a0 + 90.0 * k / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
    return pts


def loft(name, rings, mat=None, cap_bottom=True, cap_top=True, collection=None):
    """Liga anéis consecutivos (todos com o mesmo número de pontos, anti-horário visto de cima)."""
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(vr[0])
    for i in range(len(vr) - 1):
        for j in range(n):
            k = (j + 1) % n
            bm.faces.new((vr[i][j], vr[i][k], vr[i + 1][k], vr[i + 1][j]))
    if cap_bottom:
        bm.faces.new(vr[0][::-1])
    if cap_top:
        bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _link(name, bm, mat, collection)


def lathe(name, profile, loc, mat=None, axis="X", seg=32, sweep=360.0, collection=None, start=0.0, disp=None):
    """Sólido de revolução. `profile` = polígono fechado de (raio, posição_axial); gira em torno do eixo
    local Z e depois o eixo é virado para `axis` (X, Y ou Z). `sweep` < 360 gera um arco (arcos de roda).
    Pontos com raio ~0 viram um único vértice (sem faces degeneradas).
    `disp(r, a, t)` opcional devolve o raio deslocado (ex.: sulcos do pneu); t em radianos."""
    bm = bmesh.new()
    full = sweep >= 359.99
    steps = seg if full else seg + 1
    grid = []
    for (r, a) in profile:
        row = []
        axis_pt = r < 1e-6
        shared = bm.verts.new((0.0, 0.0, a)) if axis_pt else None
        for s in range(steps):
            if axis_pt:
                row.append(shared)
                continue
            t = math.radians(start + sweep * s / seg)
            rr = disp(r, a, t) if disp else r
            row.append(bm.verts.new((rr * math.cos(t), rr * math.sin(t), a)))
        grid.append(row)
    m = len(profile)
    cols = seg if full else seg
    uvl = bm.loops.layers.uv.new("UVMap")          # u = volta (0..1), v = ponto do perfil ((i+0.5)/m; repete)
    for i in range(m):
        i2 = (i + 1) % m
        for s in range(cols):
            s2 = (s + 1) % steps if full else s + 1
            quad = [grid[i][s], grid[i][s2], grid[i2][s2], grid[i2][s]]
            uvq = [(s / seg, (i + 0.5) / m), ((s + 1) / seg, (i + 0.5) / m), ((s + 1) / seg, (i + 1.5) / m), (s / seg, (i + 1.5) / m)]
            uniq, uvs = [], []
            for v, c in zip(quad, uvq):
                if v not in uniq:
                    uniq.append(v)
                    uvs.append(c)
            if len(uniq) >= 3:
                f = bm.faces.new(uniq)
                for lp, c in zip(f.loops, uvs):
                    lp[uvl].uv = c
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    if axis == "X":
        ob.rotation_euler = (0, math.radians(90), 0)
    elif axis == "Y":
        ob.rotation_euler = (math.radians(-90), 0, 0)
    return ob


def arch_shell(name, cy_cz, r_in, r_out, x0, x1, mat=None, seg=20, collection=None):
    """Arco de para-lama: meia coroa (180 graus superiores) ao redor do eixo X, de x0 a x1.
    `cy_cz` = (y, z) do centro da roda."""
    prof = [(r_in, 0.0), (r_out, 0.0), (r_out, x1 - x0), (r_in, x1 - x0)]
    return lathe(name, prof, (x0, cy_cz[0], cy_cz[1]), mat, axis="X", seg=seg, sweep=180.0,
                 collection=collection, start=90.0)


def bevel_corner_quad(p0, p1):
    """Auxiliar: vetor unitário entre dois pontos."""
    return (Vector(p1) - Vector(p0)).normalized()
