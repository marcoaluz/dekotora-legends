"""T-193: lists, per root object of an FBX, the materials (base colour, texture file) with their face counts and the
names of the child objects with the most faces. Read-only (nothing saved).
Usage: blender -b --factory-startup -P blender/scripts/t193_probe_mats.py -- --file X.fbx [--roots a,b] [--objs]
"""
import sys
from collections import Counter

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
src = a[a.index("--file") + 1]
roots = a[a.index("--roots") + 1].split(",") if "--roots" in a else None
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)


def sub(o):
    out = [o]
    for c in o.children:
        out += sub(c)
    return out


def mat_info(m):
    if m is None:
        return "None"
    col, tex = None, ""
    if m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                col = tuple(round(v, 2) for v in n.inputs["Base Color"].default_value[:3])
            if n.type == "TEX_IMAGE" and n.image:
                tex += n.image.name + " "
    return f"{m.name} col={col} tex={tex}"


for r in [o for o in bpy.context.scene.objects if o.parent is None]:
    if roots and r.name not in roots:
        continue
    cnt = Counter()
    per_obj = []
    for o in sub(r):
        if o.type != "MESH":
            continue
        per_obj.append((len(o.data.polygons), o.name, [s.material.name if s.material else None for s in o.material_slots][:3]))
        for p in o.data.polygons:
            m = o.material_slots[p.material_index].material if o.material_slots else None
            cnt[mat_info(m)] += 1
    print("ROOT", r.name)
    for k, v in cnt.most_common(40):
        print("   MAT", v, k)
    if "--objs" in a:
        for n, nm, ms in sorted(per_obj, reverse=True)[:60]:
            print("   OBJ", n, nm, ms)
