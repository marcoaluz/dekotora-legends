"""Renderização com camadas (holdout) e leitura exata dos pixels."""
from __future__ import annotations

import bpy
import numpy as np


def render_rgba(path: str, width: int, height: int) -> np.ndarray:
    """Renderiza e devolve array (h, w, 4) com linha 0 no topo, valores 0..1 exatos (sRGB)."""
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = width, height
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"      # lê os bytes como estão, sem conversão
    buf = np.empty(width * height * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return buf.reshape(height, width, 4)[::-1].copy()


def set_layer(visible, holdout=(), hidden=()):
    """Configura uma camada: visíveis, invisíveis que tampam (holdout) e escondidos."""
    for o in bpy.context.scene.objects:
        if o.type not in {"MESH", "CURVE", "FONT"}:
            continue
        o.hide_render = True
        o.is_holdout = False
    for o in visible:
        o.hide_render = False
    for o in holdout:
        o.hide_render = False
        o.is_holdout = True
    for o in hidden:
        o.hide_render = True


def emissive_objects(objs):
    out = []
    for o in objs:
        for slot in getattr(o, "material_slots", []):
            if slot.material and slot.material.get("px_kind") == "emissive":
                out.append(o)
                break
    return out
