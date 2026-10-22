"""T-193: looks at docs/Modelos/Letras Japones e neon/NeonText.blend (opened, NEVER saved) and renders the whole
board from the front with its own neon materials, plus a list of every object (type, bounds, text body).
Usage: blender -b --factory-startup -P blender/scripts/t193_neon_probe.py -- --file NeonText.blend --out PNG
"""
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src = a[a.index("--file") + 1]
out = a[a.index("--out") + 1]
bpy.ops.wm.open_mainfile(filepath=src)
sc = bpy.context.scene
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for o in sc.objects:
    if o.type in ("MESH", "CURVE", "FONT") and not o.hide_render:
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        for p in bb:
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
        body = o.data.body if o.type == "FONT" else ""
        print("OBJ", o.name, o.type, [round(v, 2) for v in bb[0]], [round(v, 2) for v in bb[6]], repr(body),
              [s.material.name for s in o.material_slots if s.material], "hidden_render=", o.hide_render)
print("BOUNDS", lo, hi, "engine", sc.render.engine, "camera", sc.camera)
cam = bpy.data.objects.new("probe_cam", bpy.data.cameras.new("probe_cam"))
sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
c = (lo + hi) * 0.5
cam.data.ortho_scale = max(hi.x - lo.x, hi.z - lo.z) * 1.05
cam.location = (c.x, lo.y - 20.0, c.z)
cam.rotation_euler = (1.5708, 0.0, 0.0)
cam.data.clip_end = 200.0
sc.camera = cam
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = 1400
sc.render.resolution_y = int(1400 * (hi.z - lo.z) / max(hi.x - lo.x, 0.01))
sc.render.film_transparent = False
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("OK", out)
