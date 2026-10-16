"""Teste da biblioteca: cubo cromado + esfera vermelha nos 5 ângulos + folha de contato.
Uso: blender -b --factory-startup -P blender/scripts/test_lib.py -- --out blender/renders/test_lib
"""
import argparse
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import camera_rig, damage, export, materials, palette as pal, pixelize, render, scene, shapes  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--out", default="blender/renders/test_lib")
ap.add_argument("--palette", default="blender/palettes/dekotora.json")
args = ap.parse_args(argv)
out = os.path.abspath(args.out)
os.makedirs(out, exist_ok=True)

scene.reset_scene()
colors, outline = pal.load_palette(args.palette)
H = pal.hex_to_rgb
cube = shapes.box("cubo", (1.2, 1.2, 1.2), (-1.0, 0, 0), materials.chrome_material(), bevel=0.05)
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.7, location=(1.0, 0, 0.7), segments=16, ring_count=8)
ball = bpy.context.active_object
ball.name = "esfera"
ball.data.materials.append(materials.toon_material("red", H("#d1303f")))
for p in ball.data.polygons:
    p.use_smooth = False
objs = [cube, ball]
scene.add_key_light()
camera_rig.camera_rig(ortho_scale=5.0, target_z=0.7)
piv = camera_rig.pivot(objs)
camera_rig.fit_camera(objs, piv)

W, Hh, S = 64, 48, 4
tmp = os.path.join(out, "_tmp.png")
sheet = []
snap = damage.capture([cube])
for name, deg in camera_rig.ANGLES.items():
    piv.rotation_euler = (0, 0, math.radians(deg))
    render.set_layer(visible=objs)
    a = pixelize.pixelize(render.render_rgba(tmp, W * S, Hh * S), S, colors, outline)
    export.save_png(a, os.path.join(out, f"test_{name}.png"))
    sheet.append((f"test_{name}", a))
for st in damage.STATES:   # estados de dano no cubo, ângulo C
    piv.rotation_euler = (0, 0, 0)
    damage.apply_state([cube], st, snap)
    render.set_layer(visible=objs)
    a = pixelize.pixelize(render.render_rgba(tmp, W * S, Hh * S), S, colors, outline)
    sheet.append((f"cubo_{st}", a))
os.remove(tmp)

# checagem de paleta
allc = np.concatenate([a[a[..., 3] > 0][:, :3] for _, a in sheet])
pc = np.round(colors * 255).astype(int)
for c in np.unique(np.round(allc * 255).astype(int), axis=0):
    assert (pc == c).all(1).any(), f"cor fora da paleta {c}"
export.save_meta(os.path.join(out, "test.json"), size=[W, Hh], angles=list(camera_rig.ANGLES))
export.contact_sheet(sheet, os.path.join(out, "contact_sheet.png"), cols=4)
print("OK test_lib ->", out)
