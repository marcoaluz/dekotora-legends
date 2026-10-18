"""Cabine "americana" de bico longo (T-129) a partir do Kenworth W990 (Sketchfab, Royalty Free): só a cabine "dia",
o capô e a grade, sem marcas, com os NOSSOS materiais e reduzida por ilha (`lib/extract.decimate_islands`).

`build_kw(m, add, src)` monta tudo com as costas da cabine em CAB_Y0 (8,45, como as outras cabines) e devolve
`KwInfo`: teto, base das luzes da decoração V7 (fileira na frente do para-sol), superfície da frente, pontos de
montagem, eixo dianteiro (o bico longo leva o eixo para a frente: y 10,66 em vez de 10,2) e raio da roda.
Determinístico: mesmo .glb -> mesmo resultado.
"""
from __future__ import annotations

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import extract
from lib import mesh3d as M

from . import kw_src
from .dims import CAB_Y0

BUDGET = 17000            # triângulos das peças do Kenworth (sem o fundo e o emblema nossos)


class KwInfo:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def _co(objs):
    arr = [np.array([v.co[:] for v in o.data.vertices]) for o in objs if len(o.data.vertices)]
    return np.concatenate(arr) if arr else np.zeros((0, 3))


def _tree(objs):
    verts, polys = [], []
    for o in objs:
        base = len(verts)
        verts += [v.co.copy() for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


def _back_wall(m, add, shell, y_back):
    """Fecha o fundo aberto (onde o dormitório foi cortado): placa pintada com o contorno da cabine, janela de trás."""
    co = _co(shell)
    near = co[co[:, 1] < y_back + 0.15]
    z0, z1 = float(near[:, 2].min()) + 0.02, float(near[:, 2].max()) - 0.01
    n = 24
    zs = [z0 + (z1 - z0) * i / n for i in range(n + 1)]
    hws = []
    for z in zs:
        band = near[np.abs(near[:, 2] - z) < (z1 - z0) / n]
        hws.append(float(np.abs(band[:, 0]).max()) - 0.01 if len(band) else 0.3)
    bm = bmesh.new()
    y = y_back + 0.012
    rows = [(bm.verts.new((-hw, y, z)), bm.verts.new((hw, y, z))) for z, hw in zip(zs, hws)]
    for (a0, b0), (a1, b1) in zip(rows, rows[1:]):
        bm.faces.new((a0, b0, b1, a1))                 # normal para -Y (para trás)
    wall = M._link("kw_back_wall", bm, m["paint_white_panel"])
    add(wall)
    zw = z0 + (z1 - z0) * 0.62
    add(M.box("kw_back_window", (0.9, 0.02, 0.36), (0, y_back - 0.0, zw), m["glass"], bevel=0.03, seg=1))
    add(M.box("kw_back_window_frame", (0.98, 0.015, 0.44), (0, y_back + 0.004, zw), m["plastic"], bevel=0.03, seg=1))
    return M.count_tris([wall]) + 24


def _badge(m, add, y, z):
    """Emblema redondo nosso no lugar do da grade (o original foi apagado): anel cromado + miolo rosa."""
    a = add(M.cylinder("badge_ring", 0.08, 0.03, (0, y + 0.012, z), m["chrome"], axis="Y", seg=24))
    b = add(M.cylinder("badge_core", 0.056, 0.03, (0, y + 0.02, z), m["paint_pink"], axis="Y", seg=24))
    return M.count_tris([a, b])


def build_kw(m, add, src=None) -> KwInfo:
    y_back = CAB_Y0
    objs = kw_src.load(src, y_back)
    tris_in = extract.tris(objs)
    objs = extract.decimate_islands(objs, BUDGET)
    shell, solid = [], []
    for o in objs:
        name = o["our_mat"]
        o.data.materials.clear()
        o.data.materials.append(m[name])
        o.name = "kw_" + name
        if name == "glass_wind":
            M.uv_planar(o)                                # para-brisa: textura 0..1 (arcos do limpador)
            o["has_uv"] = True
        if name == "paint_white_panel":
            shell.append(o)
        if name in ("paint_white_panel", "chrome", "plastic", "glass", "glass_wind"):
            solid.append(o)
        add(o)
    tris_out = extract.tris(objs)
    print(f"americana: triangulos {tris_in} -> {tris_out}")
    co = _co(shell)
    y_front = float(_co(objs)[:, 1].max())
    hw = float(np.abs(co[:, 0]).max())
    cabin = co[co[:, 1] < y_back + 1.4]
    roof = float(cabin[:, 2].max())
    tree = _tree(solid)

    def surf(x, z):
        hit = tree.ray_cast(Vector((x, y_front + 3.0, z)), Vector((0, -1, 0)))
        if hit[0] is None:
            return Vector((x, y_front, z)), Vector((0, 1, 0))
        nrm = hit[1] if hit[1].y >= 0 else -hit[1]
        return hit[0].copy(), nrm.normalized()
    extra = _back_wall(m, add, shell, y_back)
    yg = lambda ys: kw_src.y_game(ys, y_back)                       # noqa: E731
    extra += _badge(m, add, surf(0.0, 1.89)[0].y, 1.89)
    axle = round(yg(kw_src.AXLE_SRC), 3)
    r = kw_src.WHEEL_R
    hood = surf(0.0, 1.7)[0]
    wind = [o for o in objs if o["our_mat"] == "glass_wind"]
    wz1 = float(_co(wind)[:, 2].max()) if wind else roof - 0.4
    lamp_z = 2.78                                                   # fileira de luzes na frente do para-sol
    mounts = {
        "MOUNT_FRONT_BUMPER": (0.0, round(yg(kw_src.FRONT_SRC), 3), 0.5),
        "MOUNT_FRONT_GRILLE": (0.0, round(surf(0.0, 1.3)[0].y, 3), 1.3),
        "MOUNT_FRONT_ORNAMENT": (0.0, round(hood.y - 0.25, 3), round(hood.z + 0.22, 3)),
        "MOUNT_VISOR": (0.0, round(surf(0.0, wz1)[0].y + 0.05, 3), round(wz1 + 0.05, 3)),
        "MOUNT_ROOF": (0.0, round(y_back + 0.75, 3), round(roof, 3)),
        "MOUNT_ROOF_LIGHTS": (0.0, round(y_back + 1.2, 3), round(roof, 3)),
    }
    side = {"MOUNT_STEP_R": (1.2, round(yg(0.55), 3), 0.55), "MOUNT_CAB_SIDE_R": (round(hw, 3), round(yg(0.45), 3), 1.0),
            "MOUNT_WHEEL_FRONT_R": (1.0, axle, r), "MOUNT_WHEEL_FRONT_FACE_R": (1.165, axle, r)}
    for nm, p in side.items():
        mounts[nm] = p
        mounts[nm[:-1] + "L"] = (-p[0], p[1], p[2])
    return KwInfo(top=roof, wz0=lamp_z + 0.15, surf=surf, mounts=mounts, y_back=y_back, y_front=y_front, half_w=hw,
                  tris=tris_out + extra, front_axle=axle, front_r=r, gap=0.25)
