"""Conferência dos carros de trânsito (T-124): render EEVEE de 4 vistas e linha de medidas."""
from __future__ import annotations

import os

import bpy
from mathutils import Vector

from . import mesh3d as M
from . import scene
from .palette import hex_to_rgb, lin


def render_preview(objs, outdir: str, tag: str, paint_hex: str = "#2a5cc0", ortho_scale: float = 0.0) -> list:
    """Render de conferência (EEVEE): 3/4 frente, 3/4 trás e perfil, pintura colorida e luzes acesas."""
    os.makedirs(outdir, exist_ok=True)
    paint = bpy.data.materials.get("paint_white")
    if paint is not None:
        b = next(n for n in paint.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = lin(hex_to_rgb(paint_hex)) + (1.0,)
    scn = bpy.context.scene
    scn.render.film_transparent = False
    scn.render.resolution_x, scn.render.resolution_y = 960, 600
    bg = next(n for n in scn.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.35, 0.38, 0.45, 1)
    bg.inputs[1].default_value = 1.0
    if bpy.data.objects.get("key") is None:
        scene.add_key_light((50, 0, 35), 3.5)
    lo, hi = M.bounds(objs)
    ctr = (lo + hi) * 0.5
    size = max(hi.y - lo.y, 1.0)
    if bpy.data.objects.get("floor") is None:
        floor = M.box("floor", (size * 6, size * 6, 0.02), (0, ctr.y, -0.01), None, bevel=0.0)
        fm = bpy.data.materials.new("floor")
        next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.2, 0.2, 0.22, 1)
        floor.data.materials.append(fm)
    cam = bpy.data.objects.get("cam")
    if cam is None:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scn.collection.objects.link(cam)
    scn.camera = cam
    dist = size * 2.5
    out = []
    views = {"34front": (Vector((0.9, 1.0, 0.45)), False), "34rear": (Vector((-0.9, -1.0, 0.5)), False),
             "side": (Vector((1, 0, 0.0)), True), "front": (Vector((0.0, 1.0, 0.12)), True)}
    for name, (dv, ortho) in views.items():
        dv.normalize()
        cam.data.type = "ORTHO" if ortho else "PERSP"
        cam.data.ortho_scale = ortho_scale or size * 1.18
        if name == "front":
            cam.data.ortho_scale = (hi.x - lo.x) * 1.6
        cam.data.lens = 50
        cam.location = ctr + dv * (dist if not ortho else size * 4)
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(outdir, f"{tag}_{name}.png")
        scn.render.filepath = path
        bpy.ops.render.render(write_still=True)
        out.append(path)
    return out


def stats_line(tag: str, body, wheels, path: str) -> str:
    objs = [body] + list(wheels)
    lo, hi = M.bounds(objs)
    d = hi - lo
    return (f"[{tag}] tris={M.count_tris(objs)} (corpo {M.count_tris([body])}, rodas {M.count_tris(list(wheels))}) "
            f"tamanho={d.x:.2f}x{d.y:.2f}x{d.z:.2f} m y=[{lo.y:.2f},{hi.y:.2f}] z0={lo.z:.3f} "
            f"rodas={[(w.name, round(w.location.y, 2), round(w.location.z, 3)) for w in wheels]} "
            f"glb={os.path.getsize(path) / 1e6:.3f} MB")
