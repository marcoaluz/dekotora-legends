"""Luz, câmera e foto das prévias das peças da oficina (as mesmas de build_t233_parts.py, que não pode ser importado:
ele roda tudo ao ser importado). T-234."""
import math

import bpy
from mathutils import Vector


def setup_render(size=(640, 420)):
    from lib import preview as P
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.film_transparent = False
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.view_settings.view_transform = "Standard"
    P._setup_world()
    lights = [P._light("key", "AREA", (8, 10, 12), 4200, (1.0, 0.95, 0.9), 6),
              P._light("rim", "AREA", (-9, -14, 8), 3000, (0.55, 0.65, 1.0), 6),
              P._light("fill", "AREA", (-8, 12, 4), 1400, (0.8, 0.85, 1.0), 6),
              P._light("back", "AREA", (0, 14, 6), 2600, (1.0, 1.0, 1.0), 6)]
    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    return co, lights


def set_night(lights, night):
    k = 0.10 if night else 1.0
    for ob, e in zip(lights, (4200, 3000, 1400, 2600)):
        ob.data.energy = e * k
    bg = bpy.context.scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Strength"].default_value = 0.2 if night else 2.0


def shoot(co, center, az, el, dist, path, lens=50):
    co.data.lens = lens
    a, e = math.radians(az), math.radians(el)
    c = Vector(center)
    co.location = c + Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e))) * dist
    co.rotation_euler = (c - co.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
