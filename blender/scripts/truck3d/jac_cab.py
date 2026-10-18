"""Cabine curta japonesa (T-125) a partir do JAC 1045 (CGTrader, Royalty Free): marca apagada, NOSSOS materiais,
peças reduzidas (teto de triângulos por peça em `jac_parts`), emblema redondo nosso no lugar do "JAC".

`build_jac(m, add, frame, groups)` monta as peças dos grupos pedidos ("cab" e/ou "chassis") no `frame`
(`jac_src.CANTER` ou `jac_src.CURTA`) e devolve `JacInfo` com o que o caminhão precisa: teto, base do para-brisa,
superfície da frente (para a fileira de luzes da decoração V7) e pontos de montagem da cabine.
Determinístico: mesmo .blend -> mesmo .glb.
"""
from __future__ import annotations

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import mesh3d as M

from . import jac_parts, jac_src


class JacInfo:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def _select_only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def _decimate(o, target):
    tris = M.count_tris([o])
    if target is None or tris <= target:
        return
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(0.01, target / tris)
    mod.use_collapse_triangulate = True
    xs = [v.co.x for v in o.data.vertices]
    if min(xs) < -0.3 and max(xs) > 0.3:          # peças que cruzam o centro: reduz igual dos dois lados
        mod.use_symmetry = True
        mod.symmetry_axis = "X"
    _select_only(o)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _co(objs):
    return np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in objs])


def _tree(objs):
    verts, polys = [], []
    for o in objs:
        base = len(verts)
        verts += [v.co.copy() for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


def build_jac(m, add, frame, groups=("cab",), src=None) -> JacInfo:
    k = frame.scale / jac_src.CANTER.scale            # 1,0 no Canter; 1,135 na cabine curta
    objs = jac_src.load(frame, src, keep=lambda n: jac_parts.spec(n)[1] in groups)
    tris_in = M.count_tris(list(objs.values()))
    kept = {}
    for name, o in objs.items():
        mat, _grp, cap = jac_parts.spec(name)
        if mat == "drop":
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        _decimate(o, cap)
        o.data.materials.append(m[mat])
        if mat == "glass_wind":
            M.uv_planar(o)                             # para-brisa: textura 0..1 (arcos do limpador)
            o["has_uv"] = True
        kept[name] = o
        add(o)
    tris_out = M.count_tris(list(kept.values()))
    print(f"jac {groups}: pecas {len(objs)} -> {len(kept)}  triangulos {tris_in} -> {tris_out}")
    shell = [kept[n] for n in ("CABINA", "CAPOTA", "PUERTA_Left", "PUERTA_Right") if n in kept]
    co = _co(shell)
    roof = float(co[:, 2].max())
    top = co[co[:, 2] > roof - 0.04]
    roof_front = float(top[:, 1].max())
    y_back = float(co[co[:, 2] > 0.6 * roof][:, 1].min())
    y_front = float(co[:, 1].max())
    hw = float(np.abs(co[:, 0]).max())
    tree = _tree(shell)

    def surf(x, z):
        hit = tree.ray_cast(Vector((x, y_front + 3.0, z)), Vector((0, -1, 0)))
        if hit[0] is None:
            return Vector((x, y_front, z)), Vector((0, 1, 0))
        n = hit[1] if hit[1].y >= 0 else -hit[1]
        return hit[0].copy(), n.normalized()
    extra = _badge(m, add, surf, k)
    wind = kept.get("PARABRISAS")
    wz0 = float(_co([wind])[:, 2].min()) if wind else 1.5 * k
    lamp_z = 1.12 * k                                  # fileira de luzes da decoração: painel entre a grade e o para-brisa
    face = surf(0.0, 1.36 * k)[0]
    mounts = {
        "MOUNT_FRONT_BUMPER": (0.0, frame.y(jac_src.Y_FRONT_SRC), 0.6 * k),
        "MOUNT_FRONT_GRILLE": (0.0, surf(0.0, 0.88 * k)[0].y, 0.88 * k),
        "MOUNT_FRONT_ORNAMENT": (0.0, face.y, 1.36 * k),
        "MOUNT_VISOR": (0.0, roof_front + 0.03, roof - 0.01),
        "MOUNT_ROOF": (0.0, (y_back + roof_front) / 2, roof),
        "MOUNT_ROOF_LIGHTS": (0.0, roof_front - 0.2 * k, roof),
    }
    side = {"MOUNT_STEP_R": frame.pt((1.02, 6.45, 0.42)), "MOUNT_CAB_SIDE_R": frame.pt((1.05, 6.0, 0.78))}
    for n, p in side.items():
        mounts[n] = p
        mounts[n[:-1] + "L"] = (-p[0], p[1], p[2])
    return JacInfo(top=roof, wz0=lamp_z + 0.15, wind_z0=wz0, surf=surf, mounts=mounts, y_back=y_back, y_front=y_front,
                   half_w=hw, tris=tris_out + extra, mount_scale=k * jac_src.CANTER.scale / jac_src.CURTA.scale)


def _badge(m, add, surf, k):
    """Emblema redondo nosso (o "JAC" da frente foi apagado): anel cromado + miolo rosa."""
    p, _n = surf(0.0, 1.36 * k)
    a = add(M.cylinder("badge_ring", 0.075 * k, 0.03, (0, p.y + 0.012, 1.36 * k), m["chrome"], axis="Y", seg=24))
    b = add(M.cylinder("badge_core", 0.052 * k, 0.03, (0, p.y + 0.02, 1.36 * k), m["paint_pink"], axis="Y", seg=24))
    return M.count_tris([a, b])
