"""T-217: trucks of the OTHER carriageway (and parked ones) from Marco's models (docs/Modelos, Royalty Free, no AI).

Only READS the originals and writes a reduced .glb with flat colours (2 materials: "paint_white", which the game
recolours per copy, and the 4x4 "trim" atlas of lib/traffic_kit.py): no texture/logo of the author goes into the game.
  truck_box  : docs/Modelos/Caminhão novo/ShippingTruckFBX.fbx (box truck, US conventional cab)
  truck_dump : docs/Modelos/Caminhão vasculante/constuction_vehicle_5.fbx (3-axle dump truck)
  truck_semi : docs/Modelos/Carreta/trailer2.fbx (tractor + box trailer; interior, seats and engine dropped)
  truck_army : docs/Modelos/Caminhão antigo/813/Tatra_813.obj (8x8 army truck; olive in the game)
Front +Y, rear at Y = 0, ground Z = 0, real size; wheels stay in the body (they never spin at that distance).

Uso: blender -b --factory-startup -P blender/scripts/build_t217_trucks.py -- [--root PASTA_PRINCIPAL]
         [--only truck_box,...] [--out game/assets/vehicles/traffic] [--preview PASTA_ABS]
"""
import argparse
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, scene  # noqa: E402
from lib import traffic_kit as K  # noqa: E402

CELLS = dict(K.CELLS)
CELLS["box"] = ("#e6e6e0", 0.55, 0.0, None)

# length m, target triangles, flip (front was -long axis), regex of objects to drop, wheel radius m
SPECS = {
    "truck_box": dict(src="Caminhão novo/ShippingTruckFBX.fbx", length=8.4, target=4200, flip=True, drop="", wheel_r=0.52,
                      mats={"cabin": "paint", "box": "box", "glass": "glass"}),
    "truck_dump": dict(src="Caminhão vasculante/constuction_vehicle_5.fbx", length=8.6, target=6500, flip=True, drop="",
                       wheel_r=0.55, mats={"icon": "drop"}),                 # brand badge: deleted
    "truck_semi": dict(src="Carreta/trailer2.fbx", length=16.6, target=8000, flip=True, height=4.0,
                       drop=r"Interier|Seats|Engine|sub02|Cylinder|^d\d+", wheel_r=0.52, mats={}),
    "truck_army": dict(src="Caminhão antigo/813/Tatra_813.obj", length=8.8, target=7000, flip=False, drop="", wheel_r=0.62,
                       mats={}),
}


def _args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.getcwd())
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default="game/assets/vehicles/traffic")
    ap.add_argument("--preview", default="")
    return ap.parse_args(a)


def import_file(path):
    before = set(bpy.data.objects)
    if path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path, use_image_search=False)
    else:
        bpy.ops.wm.obj_import(filepath=path)
    return [o for o in bpy.data.objects if o not in before and o.type == "MESH"]


def mat_class(m, spec) -> str:
    """Class of a source material: by name (spec) or by its base colour (saturated = paint, dark = plastic...)."""
    if m is None:
        return "paint"
    low = m.name.lower()
    for k, c in spec["mats"].items():
        if k in low:
            return c
    col = (0.8, 0.8, 0.8)
    if m.use_nodes:
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if b is not None:
            col = tuple(b.inputs["Base Color"].default_value)[:3]
    else:
        col = tuple(m.diffuse_color)[:3]
    mx, mn = max(col), min(col)
    lum = 0.3 * col[0] + 0.59 * col[1] + 0.11 * col[2]
    sat = 0.0 if mx < 1e-4 else (mx - mn) / mx
    if sat > 0.35 and lum > 0.04:
        return "paint"
    if lum < 0.03:
        return "plastic"
    if lum < 0.2:
        return "grey"
    return "box"


def build(key, spec, args):
    scene.reset_scene()
    src = os.path.join(args.root, "docs", "Modelos", spec["src"])
    objs = import_file(src)
    if spec["drop"]:
        rx = re.compile(spec["drop"])
        for o in [o for o in objs if rx.search(o.name)]:
            objs.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
    for o in objs:
        if o.data.users > 1:
            o.data = o.data.copy()                    # instanced wheels share one mesh: make each its own
    K.unparent_apply(objs)
    # per-face class from the source material, before joining (each object keeps its slots)
    classes = []
    for o in objs:
        mats = list(o.data.materials)
        mi = np.zeros(len(o.data.polygons), np.int32)
        o.data.polygons.foreach_get("material_index", mi)
        cls = [mat_class(mats[i] if i < len(mats) else None, spec) for i in mi]
        K.assign_classes(o, cls)
    body = K.join(objs, "body")
    drop = np.array([c == "drop" for c in K.face_classes(body)], bool)
    K.delete_faces(body, drop)                         # logos / brand badges never reach the game
    # long axis along Y, scale to the length, centre x, rear at y = 0, ground at z = 0
    lo, hi = M.bounds([body])
    d = hi - lo
    rot = Matrix.Rotation(math.radians(90), 4, "Z") if d.x > d.y else Matrix.Identity(4)
    if spec["flip"]:
        rot = Matrix.Rotation(math.radians(180), 4, "Z") @ rot
    K.place([body], rot)
    lo, hi = M.bounds([body])
    s = spec["length"] / (hi.y - lo.y)
    if "height" in spec:                              # semi: real height, then the trailer is shortened (below)
        s = spec["height"] / (hi.z - lo.z)
    K.place([body], Matrix.Scale(s, 4))
    lo, hi = M.bounds([body])
    K.place([body], Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -lo.y, -lo.z))))
    lo, hi = M.bounds([body])
    if hi.y > spec["length"] + 0.5:                    # squeeze the middle of the trailer (wheels and tractor untouched)
        _squeeze(body, 3.6, hi.y - 7.5, hi.y - spec["length"])
    lo, hi = M.bounds([body])
    W = hi.x - lo.x
    # wheels by geometry: low faces near the sides = rubber; the very bottom = under
    ctr, _n, _a, _uv = K.face_data(body)
    cls = K.face_classes(body)
    r = spec["wheel_r"]
    for i, c in enumerate(ctr):
        if c[2] < 0.22:
            cls[i] = "under"
        elif c[2] < 2.0 * r * 0.98 and abs(c[0]) > W * 0.3 and cls[i] in ("plastic", "grey", "paint"):
            cls[i] = "rubber" if cls[i] != "paint" or c[2] < r * 1.6 else cls[i]
    K.assign_classes(body, cls)
    K.weld(body, 0.0008)
    _planar(body)
    K.decimate(body, spec["target"], border_weight=0.4)
    imgs, uv = K.build_atlas(key, CELLS)
    K.finalize(body, K.paint_material(), K.trim_material(key, imgs), uv)
    out = K.export(key, body, [], args.out)
    lo, hi = M.bounds([body])
    print(f"OK {key}: {M.count_tris([body])} tri, {hi.x - lo.x:.2f} x {hi.y - lo.y:.2f} x {hi.z - lo.z:.2f} m -> {out}")
    if args.preview:
        _preview(key, body, args.preview)


def _planar(o, deg: float = 2.5) -> None:
    """Planar dissolve first (flat boxes like the trailer and the dump bed keep their shape), then triangulate."""
    md = o.modifiers.new("planar", "DECIMATE")
    md.decimate_type = "DISSOLVE"
    md.angle_limit = math.radians(deg)
    md.delimit = {"MATERIAL"}
    K.select_only([o])
    bpy.ops.object.modifier_apply(modifier=md.name)
    tri = o.modifiers.new("tri", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)


def _squeeze(o, y0: float, y1: float, cut: float) -> None:
    """Shortens the object by `cut` m compressing only the band y0..y1 (everything behind y0 moves forward)."""
    me = o.data
    co = np.zeros(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    y = co[:, 1]
    k = (y1 - y0 - cut) / (y1 - y0)
    ny = np.where(y >= y1, y - cut, np.where(y <= y0, y, y0 + (y - y0) * k))
    co[:, 1] = ny
    me.vertices.foreach_set("co", co.ravel())
    me.update()


def _preview(key, body, outdir):
    os.makedirs(outdir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.render.resolution_x, sc.render.resolution_y = 900, 420
    lo, hi = M.bounds([body])
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(hi.y - lo.y, 4.0) * 1.15
    for tag, loc, rotd in (("side", (14.0, (hi.y + lo.y) * 0.5, 1.6), (90, 0, 90)),
                           ("front", (0.0, hi.y + 14.0, 1.6), (90, 0, 180))):
        cam.location = loc
        cam.rotation_euler = [math.radians(v) for v in rotd]
        sc.render.filepath = os.path.join(outdir, f"{key}_{tag}.png")
        bpy.ops.render.render(write_still=True)


def main():
    args = _args()
    only = set(x for x in args.only.split(",") if x)
    for key, spec in SPECS.items():
        if only and key not in only:
            continue
        build(key, spec, args)


if __name__ == "__main__":
    main()
