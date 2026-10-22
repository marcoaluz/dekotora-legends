"""T-193: locomotive and wagons from the Marco's new folders (docs/Modelos/train and docs/Modelos/Vagoes, outside Git;
"Royalty Free, sem IA, sem credito") for the railway of T-154. Only READS the originals.

  train_loco_b.glb       diesel locomotive (docs/Modelos/train/3d-model.fbx, 10,6 mil tri, file in the wrong unit:
                         2,3 m long) -> 19 m, painted blue with a cream stripe, grey roof, dark bogies
  train_wagon_log.glb    logging car with a load of logs made here (Vagoes/Logging car.fbx)
  train_wagon_flat.glb   platform car with its 2 containers (Vagoes/Platform car.fbx)
  train_wagon_semi.glb   low-side gondola (Vagoes/Semi - platform car.fbx)
  train_wagon_box.glb / train_wagon_box_b.glb  well car with a big container, 2 colours (Vagoes/Transporter car.fbx)

The wagons come at ~1:1,9 (1,55 m wide): scaled to 2,9 m. The wheels are squeezed sideways to sit on our rails
(+-0,62 m, the same as train_loco). Every face points to a cell of the railway atlas (textures/rail/rail_atlas.png,
build_railway_kit.py) by the colour of its original material: one material for all trains ("rail_train", with the
night emission of the atlas), so the game draws them with the same RailKit material.
Front = +Y, centre of the car at the origin, Z = 0 on the rail top. Deterministic.

Usage: blender -b --factory-startup -P blender/scripts/build_t193_rail.py -- [--src docs/Modelos] [--only a,b] [--preview]
"""
from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import mesh3d as M  # noqa: E402

OUT_GLB = os.path.join(ROOT, "game", "assets", "scenery", "rail")
WORK = os.path.join(ROOT, "blender", "renders", "t193", "rail")

# same cells/colours as build_railway_kit.py (8 x 8 atlas of 64 px); only the ones used here
CELL = {"steel": 0, "dark": 2, "black": 3, "insulator": 4, "loco_red": 5, "loco_cream": 6, "yellow": 7, "roof": 8,
        "glass": 9, "headlight": 10, "taillight": 11, "bogie": 12, "grille": 13, "flatcar": 14, "c_blue": 15,
        "c_green": 16, "c_red": 17, "c_gray": 18, "c_orange": 19, "c_white": 20, "c_teal": 21, "c_brown": 22}
COLORS = {"steel": (0.62, 0.64, 0.66), "dark": (0.13, 0.13, 0.14), "black": (0.04, 0.04, 0.05),
          "flatcar": (0.27, 0.22, 0.19), "c_green": (0.21, 0.46, 0.31), "c_gray": (0.56, 0.58, 0.59),
          "c_white": (0.86, 0.87, 0.85), "glass": (0.10, 0.14, 0.19)}
GAUGE_X = 0.70            # outer face of the wheels (train_loco: wheels at +-0.62, 0.14 wide)
LOCO_LOW_Z = 1.15         # T-195: running gear of train_loco_b (bogies, tanks) = the only part decimated
WAGON_SCALE = 1.87
WAGON_PARTS = {"Cylinder": "dark", "Cart": "bogie", "Coupling": "dark"}      # objects of the Vagoes files

SPECS = {
    "train_wagon_log": dict(src="Vagoes/wagons.fbx/Logging car.fbx", recolor={"c_green": "dark"}, tris=2000, cargo="logs"),
    "train_wagon_flat": dict(src="Vagoes/wagons.fbx/Platform car.fbx", recolor={"c_green": "flatcar"}, tris=2200,
                             container="c_teal"),
    "train_wagon_semi": dict(src="Vagoes/wagons.fbx/Semi - platform car.fbx", recolor={"c_green": "c_brown"}, tris=2000),
    "train_wagon_box": dict(src="Vagoes/wagons.fbx/Transporter car.fbx", recolor={"c_green": "flatcar"}, tris=2200,
                            container="c_red"),
    "train_wagon_box_b": dict(src="Vagoes/wagons.fbx/Transporter car.fbx", recolor={"c_green": "dark"}, tris=2200,
                              container="c_blue"),
    "train_loco_b": dict(src="train/3d-model.fbx/3d-model.fbx", length=19.0, tris=6500, loco=True),   # T-195: body intact, only the bogies reduced
}


# T-195: livery of the Marco's locomotive (train_loco_b). The body sides are big polygons that cross every band, so a
# colour per face painted diagonal patches. The body now samples a vertical strip (cell LIVERY_CELL of the atlas) with
# v = height: dark blue skirt, blue body, cream band with a red pinstripe, blue top. Written into rail_atlas.png here
# (same pixels every run; the cell was empty).
LIVERY_CELL = 32
LIVERY_BANDS = [(0.00, (0.09, 0.17, 0.32)), (0.36, (0.17, 0.36, 0.66)), (0.47, (0.88, 0.84, 0.70)),
                (0.555, (0.70, 0.12, 0.10)), (0.575, (0.88, 0.84, 0.70)), (0.60, (0.17, 0.36, 0.66)),
                (0.86, (0.14, 0.30, 0.56))]
LIVERY_BODY = ("c_blue", "loco_cream")


def paint_livery_cell() -> None:
    path = os.path.join(ROOT, "game", "assets", "textures", "rail", "rail_atlas.png")
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], np.float32).reshape(h, w, 4)        # row 0 = bottom of the image
    cs = w // 8
    row, col = divmod(LIVERY_CELL, 8)
    y0 = h - (row + 1) * cs                                            # bottom row of the cell (Blender: bottom-up)
    rng = np.random.default_rng(195)
    for j in range(cs):
        t = (j + 0.5) / cs                                             # 0 = bottom of the locomotive
        rgb = LIVERY_BANDS[0][1]
        for t0, c in LIVERY_BANDS:
            if t >= t0:
                rgb = c
        lin = rgb                                                      # byte PNG: pixels[] are the sRGB values / 255
        grain = 1.0 + 0.05 * (rng.random(cs) - 0.5)
        for k in range(3):
            px[y0 + j, col * cs:(col + 1) * cs, k] = lin[k] * grain
        px[y0 + j, col * cs:(col + 1) * cs, 3] = 1.0
    img.pixels[:] = px.ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("LIVERY cell %d escrita em %s" % (LIVERY_CELL, path))


def livery_uv(z_frac: float) -> tuple:
    row, col = divmod(LIVERY_CELL, 8)
    v0 = 1.0 - (row + 1) / 8.0
    return (col + 0.5) / 8.0, v0 + (0.04 + 0.92 * min(max(z_frac, 0.0), 1.0)) / 8.0


def cell_uv(name: str) -> tuple:
    i = CELL[name]
    row, col = divmod(i, 8)
    return (col + 0.5) / 8.0, 1.0 - (row + 0.5) / 8.0


def mat_rgb(m) -> tuple:
    if m is None or not m.use_nodes:
        return (0.5, 0.5, 0.5)
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            c = n.inputs["Base Color"].default_value
            return tuple(float(v) ** (1.0 / 2.2) for v in c[:3])          # linear -> sRGB
    return (0.5, 0.5, 0.5)


def nearest(rgb) -> str:
    """Class of a material colour by hue and value (the "Vagoes" materials: green paint, greys, white = untextured)."""
    r, g, b = rgb
    mx, mn = max(rgb), min(rgb)
    sat = (mx - mn) / max(mx, 1e-6)
    if sat > 0.18 and g >= r and g >= b:
        return "c_green"
    if sat > 0.5 and r > g:
        return "c_orange"
    if mx < 0.3:
        return "dark"
    if mx < 0.62:
        return "c_gray"
    return "steel"


def import_joined(path: str, by_name: dict | None = None):
    """Imports and joins everything. `by_name`: object name prefix -> class (the whole object gets that class)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        for pre, c in (by_name or {}).items():
            if o.name.startswith(pre):
                m = bpy.data.materials.get("cls_" + c) or bpy.data.materials.new("cls_" + c)
                o.data.materials.clear()
                o.data.materials.append(m)
                for p in o.data.polygons:
                    p.material_index = 0
                break
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    return o


def classes_by_colour(o, recolor: dict) -> list:
    names = [s.material.name[4:] if s.material and s.material.name.startswith("cls_") else nearest(mat_rgb(s.material))
             for s in o.material_slots] or ["c_gray"]
    if "--debug" in sys.argv:
        for s, n in zip(o.material_slots, names):
            print("  slot", s.material.name if s.material else None, [round(v, 2) for v in mat_rgb(s.material)],
                  [round(v, 2) for v in s.material.diffuse_color[:3]] if s.material else None, "->", n)
    mi = np.zeros(len(o.data.polygons), np.int32)
    o.data.polygons.foreach_get("material_index", mi)
    return [recolor.get(names[i], names[i]) for i in mi]


def loco_classes(o) -> list:
    """Blue body, cream stripe, grey roof, dark frame/bogies, glass where the original is green."""
    me = o.data
    lo, hi = M.bounds([o])
    H = hi.z - lo.z
    slot_glass = [nearest(mat_rgb(s.material)) == "c_green" or (mat_rgb(s.material)[1] > mat_rgb(s.material)[0] + 0.08)
                  for s in o.material_slots] or [False]
    out = []
    for p in me.polygons:
        z = p.center.z - lo.z
        nx, nz = abs(p.normal.x), p.normal.z
        if slot_glass[p.material_index if p.material_index < len(slot_glass) else 0]:
            c = "glass"
        elif z < H * 0.27:
            c = "bogie"
        elif nz > 0.7 and z > H * 0.8:
            c = "roof"
        elif z < H * 0.33:
            c = "dark"
        elif H * 0.47 < z < H * 0.53 and nx > 0.7:
            c = "loco_cream"
        else:
            c = "c_blue"
        out.append(c)
    return out


def set_classes(o, cls: list) -> None:
    names = sorted(set(cls))
    o.data.materials.clear()
    for n in names:
        o.data.materials.append(bpy.data.materials.get("cls_" + n) or bpy.data.materials.new("cls_" + n))
    idx = {n: i for i, n in enumerate(names)}
    o.data.polygons.foreach_set("material_index", np.array([idx[c] for c in cls], np.int32))


def get_classes(o) -> list:
    names = [m.name[4:] for m in o.data.materials]
    mi = np.zeros(len(o.data.polygons), np.int32)
    o.data.polygons.foreach_get("material_index", mi)
    return [names[i] for i in mi]


def squeeze_wheels(o, z_cut: float) -> float:
    """Wheels/bogies (below z_cut) pulled in sideways to sit on our rails; returns the factor used."""
    co = np.zeros(len(o.data.vertices) * 3, np.float64)
    o.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    low = co[:, 2] < 0.45
    xmax = float(np.abs(co[low, 0]).max()) if low.any() else 0.0
    if xmax <= GAUGE_X:
        return 1.0
    f = GAUGE_X / xmax
    k = np.clip((z_cut - co[:, 2]) / 0.25, 0.0, 1.0)            # full squeeze below z_cut - 0.25, fades to z_cut
    co[:, 0] *= 1.0 - (1.0 - f) * k
    o.data.vertices.foreach_set("co", co.ravel())
    o.data.update()
    return f


def decimate(o, target: int, loco: bool = False) -> None:
    """Wagons: symmetric collapse on the original vertices (welding first tears the containers apart).
    Locomotive: weld the seams first, no symmetry (its parts are not mirrored)."""
    if loco:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        # T-195: planar dissolve (merges only coplanar faces of the SAME colour class: the silhouette stays exact;
        # the old collapse to 5,2 mil tri melted the hood and the cab)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2.0), verts=bm.verts, edges=bm.edges,
                                 delimit={"MATERIAL"})
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.to_mesh(o.data)
        bm.free()
    cur = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if cur <= target:
        return
    md = o.modifiers.new("dec", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = target / cur
    if loco:                                                    # T-195: only the running gear (below LOCO_LOW_Z) loses
        vg = o.vertex_groups.new(name="low")                    # triangles; the body keeps its exact shape
        vg.add([v.index for v in o.data.vertices if v.co.z < LOCO_LOW_Z], 1.0, "REPLACE")
        low = sum(len(p.vertices) - 2 for p in o.data.polygons
                  if all(o.data.vertices[i].co.z < LOCO_LOW_Z for i in p.vertices))
        md.vertex_group = vg.name
        md.ratio = max(0.25, 1.0 - (cur - target) / max(low, 1))
    md.use_collapse_triangulate = True
    md.use_symmetry = not loco
    md.symmetry_axis = "X"
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=md.name)


def cyl(bm, uv, a: Vector, b: Vector, r: float, cell: str, seg: int = 7) -> None:
    d = (b - a).normalized()
    s = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    p = d.cross(s).normalized()
    q = d.cross(p).normalized()
    ra = [bm.verts.new(a + (p * math.cos(t) + q * math.sin(t)) * r) for t in (math.tau * i / seg for i in range(seg))]
    rb = [bm.verts.new(b + (p * math.cos(t) + q * math.sin(t)) * r) for t in (math.tau * i / seg for i in range(seg))]
    faces = []
    for i in range(seg):
        j = (i + 1) % seg
        faces.append(bm.faces.new([ra[i], ra[j], rb[j], rb[i]]))
    faces.append(bm.faces.new(ra[::-1]))
    faces.append(bm.faces.new(rb))
    u = cell_uv("c_brown" if cell == "log" else cell)
    end = cell_uv("loco_cream")
    for f in faces:
        for lp in f.loops:
            lp[uv].uv = end if (cell == "log" and len(f.verts) == seg) else u


def boxf(bm, uv, lo, hi, cell: str) -> None:
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    vs = [bm.verts.new(v) for v in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                    (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]]
    for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        f = bm.faces.new([vs[i] for i in q])
        for lp in f.loops:
            lp[uv].uv = cell_uv(cell)


def cargo(kind: str, deck: float, half_len: float, width: float):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = np.random.default_rng(193)
    if kind == "logs":
        r = 0.26
        rows = [(-0.55, 0), (0.0, 0), (0.55, 0), (-0.28, 1), (0.28, 1), (0.0, 2)]
        for seg_y in (-1, 1):                                   # two stacks of 7,5 m logs
            y0 = seg_y * half_len * 0.48
            for x, lev in rows:
                ln = 7.0 + float(rng.uniform(-0.4, 0.4))
                z = deck + r + lev * r * 1.75
                cyl(bm, uv, Vector((x * width / 1.4, y0 - ln / 2, z)), Vector((x * width / 1.4, y0 + ln / 2, z)), r, "log")
    else:                                                       # two 20 ft containers
        for k, col in enumerate(("c_orange", "c_gray")):
            yc = (k - 0.5) * 6.3
            boxf(bm, uv, (-1.22, yc - 3.0, deck), (1.22, yc + 3.0, deck + 2.6), col)
    me = bpy.data.meshes.new("cargo")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("cargo", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def deck_height(o) -> float:
    """Top of the floor: the most common height of the upward faces between 0.8 and 1.8 m."""
    hs = [p.center.z for p in o.data.polygons if p.normal.z > 0.9 and 0.8 < p.center.z < 1.8 and abs(p.center.x) < 0.4]
    if not hs:
        return 1.2
    v, e = np.histogram(hs, bins=20, weights=[1.0] * len(hs))
    return float(e[int(np.argmax(v)) + 1])


def build(name: str, spec: dict, src_root: str) -> tuple:
    path = os.path.join(src_root, spec["src"])
    if not os.path.isfile(path):
        raise SystemExit("original nao encontrado: " + path)
    o = import_joined(path, None if spec.get("loco") else dict(WAGON_PARTS, Container=spec.get("container", "c_gray")))
    src_tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    lo, hi = M.bounds([o])
    if spec.get("loco"):
        cls = loco_classes(o)
        s = spec["length"] / (hi.y - lo.y)
    else:
        cls = classes_by_colour(o, spec.get("recolor", {}))
        s = WAGON_SCALE
    set_classes(o, cls)
    ctr = (lo + hi) * 0.5
    o.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-ctr.x, -ctr.y, -lo.z))))
    if spec.get("loco"):                                        # front = cab = side where the glass is
        gl = [p.center.y for p, c in zip(o.data.polygons, get_classes(o)) if c == "glass"]
        print("  vidro: %d faces, y medio %.2f" % (len(gl), float(np.mean(gl)) if gl else 0.0))
        if gl and float(np.mean(gl)) < 0.0:
            o.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
    f = squeeze_wheels(o, 1.05 if not spec.get("loco") else 1.15)
    decimate(o, spec["tris"], bool(spec.get("loco")))
    lo, hi = M.bounds([o])
    parts = [o]
    if spec.get("cargo"):
        parts.append(cargo(spec["cargo"], deck_height(o), (hi.y - lo.y) * 0.5, hi.x - lo.x))
    # UV of every face = centre of its atlas cell; one material
    for ob in parts:
        if ob is o:
            cl = get_classes(ob)
            me = ob.data
            while me.uv_layers:
                me.uv_layers.remove(me.uv_layers[0])
            layer = me.uv_layers.new(name="UVMap")
            livery = bool(spec.get("loco"))                      # T-195: body = vertical livery strip
            zl, zh = lo.z, max(hi.z - lo.z, 1e-6)
            for p, c in zip(me.polygons, cl):
                u = cell_uv(c)
                for li in p.loop_indices:
                    if livery and c in LIVERY_BODY:
                        layer.data[li].uv = livery_uv((me.vertices[me.loops[li].vertex_index].co.z - zl) / zh)
                    else:
                        layer.data[li].uv = u
        ob.data.materials.clear()
        ob.data.materials.append(bpy.data.materials.get("rail_train") or bpy.data.materials.new("rail_train"))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = o
    if len(parts) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = o.data.name = name
    for p in o.data.polygons:
        p.use_smooth = False
    lo, hi = M.bounds([o])
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    os.makedirs(OUT_GLB, exist_ok=True)
    out = os.path.join(OUT_GLB, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False, export_image_format="NONE", export_materials="EXPORT")
    print("RAIL_T193 %-18s origem=%6d tri -> %5d tri  %.2f x %.2f x %.2f m  escala=%.3f  rodas x%.2f" % (
        name, src_tris, tris, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, s, f))
    return name, o, hi.y - lo.y


def preview(objs: list, path: str) -> None:
    """All models side by side (workbench, atlas texture)."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 700
    img = bpy.data.images.load(os.path.join(ROOT, "game", "assets", "textures", "rail", "rail_atlas.png"))
    for m in [m for m in bpy.data.materials if m.name.startswith("rail_train")]:   # one copy per imported file
        m.use_nodes = True
        nt = m.node_tree
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img
        tn.interpolation = "Closest"
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
        nt.nodes.active = tn
    x = 0.0
    for ob in objs:
        ob.location = (x, 0.0, 0.0)
        x += 4.2
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = (x * 0.5 + 22.0, -30.0, 16.0)
    cam.rotation_euler = (Vector((x * 0.5 - 2.0, 0.0, 1.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 32
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", path)


def main() -> None:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    src = os.path.abspath(a[a.index("--src") + 1]) if "--src" in a else os.path.join(ROOT, "docs", "Modelos")
    only = a[a.index("--only") + 1].split(",") if "--only" in a else list(SPECS)
    os.makedirs(WORK, exist_ok=True)
    done = []
    if "train_loco_b" in only and "--preview-only" not in a:
        paint_livery_cell()
    for name in ([] if "--preview-only" in a else only):
        n, _o, _l = build(name, SPECS[name], src)
        done.append(n)
    if "--preview-only" in a:
        done = only
    if "--preview" in a or "--preview-only" in a:               # re-import the exported files side by side
        bpy.ops.wm.read_factory_settings(use_empty=True)
        objs = []
        for n in done:
            bpy.ops.import_scene.gltf(filepath=os.path.join(OUT_GLB, n + ".glb"))
            objs += [o for o in bpy.context.selected_objects if o.type == "MESH"]
        preview(objs, os.path.join(WORK, "trains_t193.png"))
    print("OK build_t193_rail", done)


main()
