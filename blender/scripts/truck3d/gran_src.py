"""Carroceria graneleira (T-145): importa o modelo de terceiros "Carroceria_Brasil_Graneleiro.obj" (pasta
`docs/Novas Melhorias/Carroceria/`, Royalty Free License (no AI), confirmado pelo Marco; fica FORA do Git) e devolve as
peças já no espaço do caminhão, reduzidas e com os NOSSOS materiais.

Original (depois do importador OBJ: metros, Z para cima, traseira em -Y): piso 2,0 x 6,0 m a 1,31 m do chão, tampas
de 0,57 m, lona até 2,89 m, suporte das lanternas e para-choque embaixo da traseira. Materiais do original (sem textura):
  blinn6SG piso · blinn3SG tampas (caixa de 12 triângulos + 3 frisos) · phong1SG fueiros e longarinas do piso ·
  blinn7SG 64 trincos (964 triângulos cada!) · blinn1SG lona · initialShadingGroup ganchos da corda da lona ·
  blinn5SG suporte das lanternas · phong2SG/phong3SG lanternas vermelhas/âmbar · blinn4SG para-choque traseiro.

O que entra: piso (aço), fueiros/longarinas (cromo), lona (plástico preto com poeira, como a lona preta das
graneleiras), suporte (plástico), lanternas (lâmpadas), para-choque (cromo), ganchos maiores que 3 cm (aço) e os
trincos trocados por caixinhas (12 triângulos cada). As tampas NÃO vêm do original: `graneleira.py` faz chapas novas
com o mural (UV própria). Parafusos de 1–2 cm somem (invisíveis a 10 m).

Espaço do caminhão: x' = x * S, z' = BODY_Z0 + (z - piso) * S e y' esticado para o comprimento pedido (traseira em 0).
"""
from __future__ import annotations

import os

import bpy
import numpy as np

from lib import extract

DEFAULT_SRC = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "docs", "Novas Melhorias",
                                            "Carroceria", "Carroceria_Brasil_Graneleiro.obj"))
S = 1.25                 # largura das tampas 2,0 m -> 2,5 m (BODY_W); a altura acompanha
FLOOR_SRC = 1.31         # base do piso no original
Y0_SRC, LEN_SRC = -3.01, 6.017      # traseira e comprimento do piso no original
WALL_SRC, TARP_SRC = 1.96, 2.89     # topo das tampas e da lona no original
MIN_SIZE = 0.03          # ilhas menores que isto (parafusos) somem
# material do original -> (nosso material, orçamento de triângulos do grupo); None = não entra
MATS = {
    "blinn6SG": ("steel", 400),
    "phong1SG": ("chrome", 1500),
    "blinn1SG": ("plastic_trim", 2600),
    "initialShadingGroup": ("steel", 300),
    "blinn5SG": ("plastic", 700),
    "phong2SG": ("lamp_red", 420),
    "phong3SG": ("lamp_amber", 140),
    "blinn4SG": ("chrome", 200),
}
LATCH_SRC = "blinn7SG"   # trincos: viram caixas


def height(z_src: float, z0: float) -> float:
    """Altura no caminhão de uma altura do original."""
    return z0 + (z_src - FLOOR_SRC) * S


def _to_truck(objs, length: float, z0: float) -> None:
    ky = length / LEN_SRC
    for o in objs:
        me = o.data
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        co[:, 0] *= S
        co[:, 1] = (co[:, 1] - Y0_SRC) * ky
        co[:, 2] = z0 + (co[:, 2] - FLOOR_SRC) * S
        me.vertices.foreach_set("co", co.ravel())
        me.update()


def _load(path: str):
    path = os.path.abspath(path or DEFAULT_SRC)
    if not os.path.isfile(path):
        raise SystemExit(f"ERRO graneleira: modelo nao encontrado: {path}\n"
                         "  Coloque Carroceria_Brasil_Graneleiro.obj em docs/Novas Melhorias/Carroceria/ ou passe --body-src CAMINHO.")
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=path)
    bpy.context.view_layer.update()
    return {o.name: o for o in bpy.data.objects if o not in before and o.type == "MESH"}


def _boxify(obj, mat_name: str) -> list:
    """Cada ilha de `obj` vira a caixa que a envolve (12 triângulos). Devolve os objetos novos (sem material)."""
    from lib import mesh3d as M
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    pieces = list(bpy.context.selected_objects)
    boxes = []
    for p in pieces:
        co = np.array([v.co[:] for v in p.data.vertices])
        lo, hi = co.min(axis=0), co.max(axis=0)
        boxes.append((tuple(np.round((lo + hi) / 2, 4)), tuple(np.round(np.maximum(hi - lo, 0.01), 4))))
        bpy.data.objects.remove(p, do_unlink=True)
    out = []
    for i, (c, d) in enumerate(sorted(boxes)):
        b = M.box(f"gran_latch_{i}", d, c, None, bevel=0.0, seg=1)
        b["our_mat"] = mat_name
        out.append(b)
    return out


def build(m, add, length: float, z0: float, src: str | None = None) -> dict:
    """Peças do original no caminhão: piso com traseira em y = 0 e frente em y = `length`, piso a `z0`.
    Devolve medidas úteis: wall_top, tarp_top, tris."""
    src_objs = _load(src)
    everything = [((-99, -99, -99), (99, 99, 99))]
    groups = {}
    for name in sorted(MATS):
        ours, budget = MATS[name]
        objs = extract.take(src_objs, everything, {name: ours}, f"gran_{name}", min_size=MIN_SIZE)
        _to_truck(objs, length, z0)
        objs = extract.decimate_islands(objs, budget)
        groups[name] = objs
    latch = extract.take(src_objs, everything, {LATCH_SRC: "steel"}, "gran_latch")
    _to_truck(latch, length, z0)
    latches = [b for o in latch for b in _boxify(o, "steel")]
    for o in src_objs.values():
        bpy.data.objects.remove(o, do_unlink=True)
    out = [o for name in sorted(groups) for o in groups[name]] + latches
    tris = 0
    for o in out:
        o.data.materials.clear()
        o.data.materials.append(m[o["our_mat"]])
        o.name = f"gran_{o['our_mat']}_{len(o.data.polygons)}"
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
        add(o)
    return {"wall_top": height(WALL_SRC, z0), "tarp_top": height(TARP_SRC, z0), "tris": tris}
