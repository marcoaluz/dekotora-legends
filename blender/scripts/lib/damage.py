"""Estados de dano das peças: ok, dent (amassada) e broken (quebrada). Determinístico (semente fixa).

Uso: prepare(objs) -> capture(objs) -> apply_state(objs, "dent", snap) ... -> visible(objs) para renderizar.
Objetos escondidos pelo dano recebem a propriedade px_hidden (não use hide_render: set_layer a sobrescreve).
"""
from __future__ import annotations

import math
import random

import bmesh
import bpy
from mathutils import Vector, noise

from . import materials
from .palette import hex_to_rgb

STATES = ("ok", "dent", "broken")
_DENT_MATS: dict = {}


def prepare(objs, cuts: int = 2) -> None:
    """Subdivide as malhas para o amassado ter vértices onde deformar. Chame UMA vez, antes de capture."""
    for o in objs:
        if o.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


def capture(objs) -> dict:
    """Guarda o original (vértices, posição, rotação, materiais) para restaurar entre estados."""
    return {o.name: ([v.co.copy() for v in o.data.vertices] if o.type == "MESH" else None,
                     o.location.copy(), o.rotation_euler.copy(),
                     [s.material for s in o.material_slots]) for o in objs}


def restore(objs, snap: dict) -> None:
    for o in objs:
        cos, loc, rot, mats = snap[o.name]
        if cos is not None:
            for v, c in zip(o.data.vertices, cos):
                v.co = c
            o.data.update()
        o.location, o.rotation_euler = loc, rot
        for slot, m in zip(o.material_slots, mats):
            slot.material = m
        o["px_hidden"] = False


def visible(objs) -> list:
    return [o for o in objs if not o.get("px_hidden", False)]


def _dent_material(src):
    """Versão escurecida do material de cromo (cromo amassado/sujo)."""
    if src.name not in _DENT_MATS:
        _DENT_MATS[src.name] = materials.toon_material(src.name + "_dent", hex_to_rgb("#4a5262"),
                                                       dark=0.45, light=0.4, steps=(0.4, 0.8))
    return _DENT_MATS[src.name]


def apply_state(objs, state: str, snap: dict, seed: int = 7, strength: float = 0.1) -> None:
    """Aplica `state` partindo sempre do original.
    dent: ruído + uma cratera nos vértices, cromo escurecido, ~40% das luzes apagadas.
    broken: objetos alternados somem; os restantes caem e se inclinam."""
    restore(objs, snap)
    if state == "ok":
        return
    rnd = random.Random(seed)
    if state == "dent":
        for o in objs:
            if o.type != "MESH":
                continue
            mw = o.matrix_world
            verts = o.data.vertices
            center = Vector(rnd.choice(verts).co) if len(verts) else Vector()
            for v in verts:
                w = mw @ v.co
                n = noise.noise(Vector((w.x * 2.3 + seed, w.y * 2.3, w.z * 2.3)))
                v.co += v.normal * (n * strength)
                if (v.co - center).length < 0.35:
                    v.co -= v.normal * 0.08
            o.data.update()
            for slot in o.material_slots:
                if slot.material and slot.material.name.startswith("chrome"):
                    slot.material = _dent_material(slot.material)
            if any(s.material and s.material.get("px_kind") == "emissive" for s in o.material_slots):
                if rnd.random() < 0.4:
                    o["px_hidden"] = True
    elif state == "broken":
        for i, o in enumerate(objs):
            if i % 2 == 1:
                o["px_hidden"] = True
            else:
                o.rotation_euler.x += math.radians(rnd.uniform(15, 35))
                o.location.z -= 0.2
                o.location.x += rnd.uniform(-0.15, 0.15)
