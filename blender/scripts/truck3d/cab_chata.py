"""5ª cabine, "chata" (cara chata japonesa, T-119): casca da International CF500 (CGTrader, autor dany-sanchez,
Royalty Free) reduzida, re-texturizada com os NOSSOS materiais e sem a marca.

Passos (determinísticos: mesmo STL -> mesmo .glb):
  1. `chata_src.load`: importa o STL, gira/escala para o jogo e separa as ~227 peças soltas;
  2. `chata_parts.classify`: material por geometria (ou descarta: rodas, marca, retrovisores americanos, interior);
  3. aqui: acerta as normais das chapas, reduz cada peça (Decimate por peça, orçamento por área) e leva para a
     posição do caminhão (eixo da roda dianteira original em FRONT_AXLE_Y);
  4. `chata_extras`: extensão traseira (dormitório) até CAB_Y0, defletor de teto, nossos espelhos, emblema da grade;
  5. pontos de montagem próprios (`ChataInfo.mounts`) e superfície da frente para a decoração V7 (raio na malha).

Uso: build_truck_3d.py -- --cab chata [--cab-src CAMINHO_DO_STL]
"""
from __future__ import annotations

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import mesh3d as M

from . import chata_extras, chata_parts, chata_src
from .dims import FRONT_AXLE_Y

DY = FRONT_AXLE_Y          # eixo da roda original (y local 0) -> eixo dianteiro do caminhão
DZ = -0.02                 # centro da roda original em z 0,52 -> o nosso em 0,50
BUDGET = 18000             # triângulos para as peças da CF500 (sem extensão/defletor/espelhos)
MIN_TRIS = 12
HIDDEN = {"front_lower": 0.3, "default_big": 1.0, "wheel_liner": 1.0, "rear_lower": 0.15}
CENTER = Vector((0.0, 0.35, 1.6))      # centro aproximado da cabine (local), para orientar as chapas para fora


class ChataInfo:
    """O que o caminhão precisa saber da cabine: altura, base do para-brisa, superfície da frente e montagens."""

    def __init__(self, top, wz0, surf, mounts, tris):
        self.top = top
        self.wz0 = wz0
        self.surf = surf
        self.mounts = mounts
        self.tris = tris


def _select_only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def _orient(p):
    """Chapas abertas (normal média forte) ficam viradas para fora do centro da cabine."""
    n = Vector(p.n)
    if n.length < 0.5:
        return
    out = Vector(p.c) - CENTER
    if n.dot(out) < 0:
        p.obj.data.flip_normals()


def _budgets(parts, total):
    """Divide `total` triângulos pelas peças: peso = raiz(área) x raiz(triângulos originais). O CAD já põe mais
    triângulos onde a peça é curva, então peças grandes E curvas ficam com mais. Peças quase escondidas
    (HIDDEN) pesam menos. Nunca passa do que a peça já tem; o que sobra volta para as outras."""
    w = {p.obj.name: (max(p.area, 1e-4) * p.tris) ** 0.5 * HIDDEN.get(p.rule, 1.0) for p in parts}
    left = dict(w)
    out = {}
    rest = total
    for _ in range(6):
        s = sum(left.values())
        if s <= 0:
            break
        done = []
        for name, wi in left.items():
            p = next(q for q in parts if q.obj.name == name)
            t = max(MIN_TRIS, int(rest * wi / s))
            if t >= p.tris:
                out[name] = p.tris
                done.append(name)
        if not done:
            for name, wi in left.items():
                out[name] = max(MIN_TRIS, int(rest * wi / s))
            break
        for name in done:
            rest -= out[name]
            left.pop(name)
    return out


def _decimate(p, target):
    o = p.obj
    tris = M.count_tris([o])
    if tris <= target:
        return
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(0.002, target / tris)
    mod.use_collapse_triangulate = True
    if p.ax < 0.02 and p.d[0] > 0.5:          # peças inteiras (cruzam o centro): reduz igual dos dois lados
        mod.use_symmetry = True
        mod.symmetry_axis = "X"
    _select_only(o)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _to_truck(o):
    me = o.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    co[:, 1] += DY
    co[:, 2] += DZ
    me.vertices.foreach_set("co", co.ravel())
    me.update()


def _front_surface(objs):
    """(x, z) -> (ponto, normal) na frente da cabine: raio vindo da frente (+Y) na malha pintada."""
    verts, polys = [], []
    for o in objs:
        base = len(verts)
        verts += [v.co.copy() for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    tree = BVHTree.FromPolygons(verts, polys)

    def surf(x, z):
        hit = tree.ray_cast(Vector((x, DY + 4.0, z)), Vector((0, -1, 0)))
        if hit[0] is None:
            return Vector((x, DY + 1.15, z)), Vector((0, 1, 0))
        n = hit[1]
        if n.y < 0:
            n = -n
        return hit[0].copy(), n.normalized()
    return surf, tree


def build_cab_chata(m, add, src=None) -> ChataInfo:
    parts = chata_src.load(src)
    count = chata_parts.classify(parts)
    print("chata: pecas", len(parts), count)
    keep = []
    for p in parts:
        if p.cat == "drop":
            bpy.data.objects.remove(p.obj, do_unlink=True)
        else:
            keep.append(p)
    tris_in = sum(p.tris for p in keep)
    for p in keep:
        _orient(p)
    bud = _budgets(keep, BUDGET)
    for p in keep:
        _decimate(p, bud[p.obj.name])
    tris_out = M.count_tris([p.obj for p in keep])
    print(f"chata: triangulos {sum(p.tris for p in parts)} -> sem descartes {tris_in} -> reduzido {tris_out}")
    shell = []
    geo_lamps = [(float(p.c[0]), float(p.hi[1]) + DY, float(p.c[2]) + DZ, float(min(p.d[0], p.d[2])) / 2)
                 for p in keep if p.rule == "hl_bulb"]
    for p in keep:
        o = p.obj
        _to_truck(o)
        o.data.materials.clear()
        o.data.materials.append(m[chata_parts.MATERIAL[p.cat]])
        if p.cat == "wind":
            M.uv_planar(o)                  # para-brisa: textura 0..1 (arcos do limpador)
            o["has_uv"] = True
        if p.cat == "paint":
            shell.append(o)
        add(o)
    surf, tree = _front_surface(shell)
    geo = chata_extras.measure(shell, DY)
    geo["lamps"] = geo_lamps
    extra = chata_extras.build(m, add, geo, surf, tree)
    mounts = chata_extras.mounts(geo, surf, tree)
    return ChataInfo(geo["fair_top"], geo["wz0"], surf, mounts, tris_out + extra)
