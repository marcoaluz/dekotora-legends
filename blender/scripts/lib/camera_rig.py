"""Câmera ortográfica atrás do caminhão, pivô de ângulos e enquadramento comum."""
from __future__ import annotations

import math

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


ANGLES = {"L2": 20.0, "L1": 10.0, "C": 0.0, "R1": -10.0, "R2": -20.0}


def camera_rig(ortho_scale: float = 6.0, height: float = 4.0, distance: float = 30.0,
               pitch_deg: float = 12.0, target_z: float = 1.6, target_y: float = 0.0):
    """Câmera ortográfica atrás do caminhão (em -Y), levemente acima, olhando para +Y."""
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = ortho_scale
    ob = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    p = math.radians(pitch_deg)
    ob.location = (0, target_y - distance * math.cos(p), target_z + distance * math.sin(p))
    ob.rotation_euler = (math.radians(90) - p, 0, 0)
    bpy.context.scene.camera = ob
    return ob


def pivot(objects, center=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    """Empty que gira todos os objetos juntos (para os ângulos L2..R2), em torno de `center`.
    Os objetos NÃO se movem ao serem ligados ao pivô."""
    e = bpy.data.objects.new("pivot", None)
    e.location = center
    bpy.context.scene.collection.objects.link(e)
    bpy.context.view_layer.update()
    inv = e.matrix_world.inverted()
    for o in objects:
        o.parent = e
        o.matrix_parent_inverse = inv
    return e


def fit_camera(objects, piv, angles: dict = None, margin: float = 0.06) -> float:
    """Ajusta ortho_scale para TODOS os ângulos caberem no quadro (mesmo zoom em todos,
    para as camadas e ângulos continuarem alinhados). Chame depois de camera_rig e pivot."""
    sc = bpy.context.scene
    cam = sc.camera
    angles = angles or ANGLES
    worst = 0.0
    for deg in angles.values():
        piv.rotation_euler = (0, 0, math.radians(deg))
        bpy.context.view_layer.update()
        for o in objects:
            for c in o.bound_box:
                v = world_to_camera_view(sc, cam, o.matrix_world @ Vector(c))
                worst = max(worst, abs(v.x - 0.5) * 2, abs(v.y - 0.5) * 2)
    piv.rotation_euler = (0, 0, 0)
    cam.data.ortho_scale *= worst * (1 + margin)
    bpy.context.view_layer.update()
    return cam.data.ortho_scale


def anchor_pixel(width: int, height: int, world_point=(0, 0, 0)) -> tuple[int, int]:
    """Pixel (x, y a partir do topo) onde um ponto do mundo aparece. Use como âncora no JSON."""
    sc = bpy.context.scene
    v = world_to_camera_view(sc, sc.camera, Vector(world_point))
    return int(round(v.x * width)), int(round((1 - v.y) * height))
