"""Cabine "chata" (T-119): importa a malha de terceiros (STL da International CF500, autor dany-sanchez, CGTrader,
Royalty Free) e separa as peças soltas, já na escala e na orientação do jogo.

Coordenada LOCAL da cabine (usada nas regras de `chata_parts.py`): metros, frente +Y, centro X = 0, chão Z = 0
(base dos pneus originais), Y = 0 no eixo da roda dianteira original. Para levar ao caminhão: y += FRONT_AXLE_Y.

O arquivo original NUNCA vai para o Git (pasta `docs/Modelos/Novos modelos/` no .gitignore); só o .glb reduzido e
re-texturizado entra no jogo. Se o arquivo não existir, `load()` para com uma mensagem clara.
"""
from __future__ import annotations

import os

import bmesh
import bpy
import numpy as np

_DOCS = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "docs"))
_NOVO = os.path.join(_DOCS, "Modelos", "Novos modelos")   # T-162: pasta nova; volta para a antiga se não existir
DEFAULT_SRC = os.path.join(_NOVO if os.path.isdir(_NOVO) else os.path.join(_DOCS, "Novos modelos"),
                           "Cabine", "CF_500_complete.stl")
SCALE = 0.09479          # largura da casca = 2,4 m (CAB_W); medido na T-115 sem os retrovisores
WELD = 1e-4              # solda de vértices (m, já na escala)


class Part:
    """Uma peça solta da malha: objeto do Blender + medidas em coordenada local."""

    def __init__(self, obj):
        self.obj = obj
        me = obj.data
        n = len(me.vertices)
        co = np.empty(n * 3, dtype=np.float64)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        self.lo = co.min(axis=0)
        self.hi = co.max(axis=0)
        self.c = (self.lo + self.hi) / 2
        self.d = self.hi - self.lo
        npoly = len(me.polygons)
        area = np.empty(npoly)
        me.polygons.foreach_get("area", area)
        nrm = np.empty(npoly * 3)
        me.polygons.foreach_get("normal", nrm)
        nrm = nrm.reshape(-1, 3)
        self.area = float(area.sum())
        self.n = (nrm * area[:, None]).sum(axis=0) / max(self.area, 1e-12)
        self.tris = int(sum(len(p.vertices) - 2 for p in me.polygons))
        self.cat = ""
        self.rule = ""

    @property
    def ax(self) -> float:
        return abs(float(self.c[0]))

    def __repr__(self):
        c, d = self.c, self.d
        return (f"{self.obj.name}: {self.cat:<10} {self.rule:<14} t={self.tris:6d} a={self.area:6.3f} "
                f"c=({c[0]:+.2f},{c[1]:+.2f},{c[2]:.2f}) d=({d[0]:.2f},{d[1]:.2f},{d[2]:.2f}) n=({self.n[0]:+.2f},{self.n[1]:+.2f},{self.n[2]:+.2f})")


def load(path: str | None = None) -> list:
    """Importa o STL, gira (frente +Y), escala, centraliza, solda e separa as peças soltas. Devolve [Part]."""
    path = os.path.abspath(path or DEFAULT_SRC)
    if not os.path.isfile(path):
        raise SystemExit(f"ERRO cabine chata: arquivo da cabine nao encontrado: {path}\n"
                         "  Coloque o CF_500_complete.stl (CGTrader, dany-sanchez) nessa pasta ou passe --cab-src CAMINHO.")
    before = set(bpy.data.objects)
    bpy.ops.wm.stl_import(filepath=path)
    obj = next(o for o in bpy.data.objects if o not in before)
    me = obj.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    new = np.column_stack((-co[:, 1], co[:, 0], co[:, 2])) * SCALE      # original: frente +X, cima Z
    new[:, 0] -= (new[:, 0].min() + new[:, 0].max()) / 2
    new[:, 2] -= new[:, 2].min()
    me.vertices.foreach_set("co", new.ravel())
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=WELD)
    bm.to_mesh(me)
    bm.free()
    me.update()
    obj.name = "cf"
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = [o for o in bpy.data.objects if o not in before]
    parts = [Part(o) for o in objs]
    # ordem estável (independe da ordem interna da separação): por posição e tamanho
    parts.sort(key=lambda p: (round(float(p.c[1]), 3), round(float(p.c[2]), 3), round(float(p.c[0]), 3), p.tris))
    for i, p in enumerate(parts):
        p.obj.name = f"cf_{i:03d}"
        p.obj.data.name = p.obj.name
    return parts
