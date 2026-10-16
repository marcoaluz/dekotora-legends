"""Formas básicas. Medidas em metros; caixa tem a BASE no ponto loc."""
from __future__ import annotations

import math

import bpy


def box(name: str, size: tuple, loc: tuple, mat=None, bevel: float = 0.0, collection=None):
    """Caixa com tamanho (x, y, z) em metros e base no ponto loc (z = chão da caixa)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0], loc[1], loc[2] + size[2] / 2))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    if mat:
        ob.data.materials.append(mat)
    if collection:
        for c in ob.users_collection:
            c.objects.unlink(ob)
        collection.objects.link(ob)
    return ob


def cylinder_x(name: str, radius: float, width: float, loc: tuple, mat=None, verts: int = 12):
    """Cilindro deitado no eixo X (rodas, faróis redondos)."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=width,
                                        location=loc, rotation=(0, math.radians(90), 0))
    ob = bpy.context.active_object
    ob.name = name
    if mat:
        ob.data.materials.append(mat)
    return ob
