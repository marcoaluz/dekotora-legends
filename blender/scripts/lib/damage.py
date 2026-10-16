"""Estados de dano das peças: ok, dent (amassada) e broken (quebrada). Determinístico (semente fixa)."""
from __future__ import annotations

import math
import random

import bpy
from mathutils import Vector, noise

STATES = ("ok", "dent", "broken")


def _snapshot(objs):
    return {o.name: (o.data.copy() if o.type == "MESH" else None, o.location.copy(),
                     o.rotation_euler.copy(), o.hide_render) for o in objs}


def capture(objs) -> dict:
    """Guarda o estado original (malha, posição, rotação) para restaurar entre estados."""
    return {o.name: ([v.co.copy() for v in o.data.vertices] if o.type == "MESH" else None,
                     o.location.copy(), o.rotation_euler.copy(), o.hide_render) for o in objs}


def restore(objs, snap: dict) -> None:
    for o in objs:
        cos, loc, rot, hid = snap[o.name]
        if cos is not None:
            for v, c in zip(o.data.vertices, cos):
                v.co = c
            o.data.update()
        o.location, o.rotation_euler, o.hide_render = loc, rot, hid


def apply_state(objs, state: str, snap: dict, seed: int = 7, strength: float = 0.08) -> None:
    """Aplica `state` partindo sempre do original. objs = lista de objetos da peça.
    dent: ruído nos vértices + objetos emissivos apagados alternadamente.
    broken: metade dos objetos some e o resto cai/inclina."""
    restore(objs, snap)
    if state == "ok":
        return
    rnd = random.Random(seed)
    if state == "dent":
        for o in objs:
            if o.type != "MESH":
                continue
            for v in o.data.vertices:
                w = o.matrix_world @ v.co
                n = noise.noise(Vector((w.x * 2.1 + seed, w.y * 2.1, w.z * 2.1)))
                v.co += Vector((0, 0, 0)) + (v.normal * (n * strength))
            o.data.update()
            if any(s.material and s.material.get("px_kind") == "emissive" for s in o.material_slots):
                if rnd.random() < 0.4:
                    o.hide_render = True
    elif state == "broken":
        for i, o in enumerate(objs):
            if i % 2 == 1:
                o.hide_render = True
            else:
                o.rotation_euler.x += math.radians(rnd.uniform(15, 35))
                o.location.z -= 0.15
                o.location.x += rnd.uniform(-0.1, 0.1)
