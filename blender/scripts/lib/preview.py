"""Prévias para revisão: renderiza o modelo com Eevee, céu noturno e luzes (não vão para o jogo)."""
from __future__ import annotations

import math
import os

import bpy
from mathutils import Vector


def _setup_world():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("preview_world")
    sc.world = w
    nt = w.node_tree if hasattr(w, "node_tree") and w.node_tree else None
    if nt is None:
        w.use_nodes = True
        nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapn = nt.nodes.new("ShaderNodeMapping")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    mapn.inputs["Rotation"].default_value = (math.radians(-90), 0, 0)
    cr = ramp.color_ramp
    cr.interpolation = "CONSTANT"
    # faixas claras e escuras (como um estúdio de fotografia): dá o que refletir no cromo
    stops = [(0.0, (0.01, 0.012, 0.03)), (0.30, (0.25, 0.28, 0.45)), (0.36, (0.01, 0.012, 0.03)),
             (0.46, (0.9, 0.92, 1.0)), (0.52, (0.02, 0.02, 0.05)), (0.60, (0.35, 0.4, 0.7)),
             (0.68, (0.05, 0.05, 0.12)), (0.78, (1.0, 0.85, 0.9)), (0.84, (0.08, 0.1, 0.25))]
    while len(cr.elements) < len(stops):
        cr.elements.new(0.5)
    for el, (pos, col) in zip(cr.elements, stops):
        el.position = pos
        el.color = col + (1,)
    nt.links.new(coord.outputs["Generated"], mapn.inputs["Vector"])
    nt.links.new(mapn.outputs["Vector"], grad.inputs["Vector"])
    nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 2.0
    nt.links.new(bg.outputs[0], out.inputs[0])


def _light(name, kind, loc, energy, color=(1, 1, 1), size=3.0):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if kind == "AREA":
        ld.size = size
    ob = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    direction = Vector((0, 6, 1.5)) - Vector(loc)
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return ob


def contact_sheet(paths, out: str, cols: int = 3, gap: int = 6) -> None:
    """Junta PNGs do mesmo tamanho numa folha de contato (grade, fundo escuro) para revisão de uma vez."""
    import numpy as np
    imgs = []
    for p in paths:
        im = bpy.data.images.load(p)
        im.colorspace_settings.name = "Non-Color"
        w, h = im.size
        imgs.append(np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1])   # linha 0 = topo
        bpy.data.images.remove(im)
    h, w = imgs[0].shape[:2]
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * h + (rows + 1) * gap, cols * w + (cols + 1) * gap, 4), np.float32)
    sheet[..., :3] = 0.05
    sheet[..., 3] = 1.0
    for i, a in enumerate(imgs):
        r, c = divmod(i, cols)
        y, x = gap + r * (h + gap), gap + c * (w + gap)
        sheet[y:y + h, x:x + w] = a
    sheet = sheet[::-1]
    img = bpy.data.images.new(os.path.basename(out), sheet.shape[1], sheet.shape[0], alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()


def render_views(prefix: str, objs, size=(960, 540), center=(0.0, 6.0, 1.6), views=None, dist=22.0, lens=60.0, night=False):
    """Renderiza vistas (nome -> (azimute°, elevação°)) em <prefix>_<nome>.png."""
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.film_transparent = False
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    _setup_world()
    k = 0.12 if night else 1.0                      # noite: luzes fracas, so as lampadas e o cromo aparecem
    if night:
        sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
        if hasattr(sc.eevee, "use_bloom"):
            sc.eevee.use_bloom = True
    _light("key", "AREA", (8, -10, 12), 4200 * k, (1.0, 0.95, 0.9), 6)
    _light("rim", "AREA", (-9, 14, 8), 3000 * k, (0.55, 0.65, 1.0), 6)
    _light("fill", "AREA", (-8, -8, 4), 1400 * k, (0.8, 0.85, 1.0), 6)
    if night:
        _light("sodium", "AREA", (0, 6, 9), 1800, (1.0, 0.6, 0.3), 10)
    # chão escuro refletivo
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 6, 0))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    bsdf = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.06, 0.06, 0.07, 1)
    bsdf.inputs["Roughness"].default_value = 0.35
    ground.data.materials.append(gm)
    cam = bpy.data.cameras.new("cam")
    cam.lens = lens
    camo = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(camo)
    sc.camera = camo
    views = views or {"34": (35, 14), "rear": (180, 8), "side": (90, 4), "front": (0, 10)}
    os.makedirs(os.path.dirname(prefix), exist_ok=True)
    c = Vector(center)
    for name, v in views.items():
        az, el = v[0], v[1]
        dist_v = v[2] if len(v) > 2 else dist
        c = Vector(v[3]) if len(v) > 3 else Vector(center)
        a, e = math.radians(az), math.radians(el)
        # az=0 -> câmera na frente (+Y); az=180 -> atrás
        pos = c + Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e))) * dist_v
        camo.location = pos
        camo.rotation_euler = (c - pos).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = f"{prefix}_{name}.png"
        bpy.ops.render.render(write_still=True)
