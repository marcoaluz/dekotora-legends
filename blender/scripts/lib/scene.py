"""Cena: limpa tudo, metros, fundo transparente, sem tone mapping, luz principal."""
from __future__ import annotations

import math
import random

import bpy
import numpy as np


def reset_scene(seed: int = 1234) -> bpy.types.Scene:
    """Cena vazia, determinística, cores sem tone mapping."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(seed)
    np.random.seed(seed)
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    # 4.2-4.x usam BLENDER_EEVEE_NEXT; 5.x voltou para BLENDER_EEVEE
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"   # nada de AgX/Filmic: cor da paleta = cor final
    sc.view_settings.look = "None"
    sc.unit_settings.system = "METRIC"
    world = bpy.data.worlds.new("world")
    sc.world = world
    return sc



def add_key_light(rot_deg=(50, 0, -35), energy: float = 3.0):
    sun = bpy.data.lights.new("key", "SUN")
    sun.energy = energy
    ob = bpy.data.objects.new("key", sun)
    bpy.context.scene.collection.objects.link(ob)
    ob.rotation_euler = [math.radians(a) for a in rot_deg]
    return ob


def group(name: str) -> bpy.types.Collection:
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col
