"""T-193: buildings of docs/Modelos/Cidade (outside Git; "Royalty Free, sem IA, sem credito") for the city blocks.
Only READS the originals.

  --building KEY   one building (one Blender process each: the 4096 px 16-bit textures take ~270 MB each):
                   low-poly SHELL (voxel remesh 1/45 of the size + collapse, 1.000-1.600 tri) with the original's
                   diffuse BAKED onto it (Cycles, 512 px): the originals are thousands of loose panels that no
                   reduction keeps whole. Real size in metres, pivot at the centre of the base, UV moved into its
                   cell of the shared atlas -> game/assets/scenery/city/bldg_<KEY>.glb (far away: a box in the game)
                   + cell texture blender/renders/t193/city/cell_<KEY>.png (diffuse reduced to 512 px)
  --atlas          joins the 8 cells -> game/assets/textures/city/bldg_atlas.png (2048 x 1024, 4 x 2 cells)
  --skyline        "The City" (city.fbx + texture/cty2x.jpg): the block of towers, 10,4 mil tri, scaled so the
                   storeys of the texture are ~3,5 m (the whole block ~620 m wide) -> scenery/city/city_skyline.glb
                   + textures/city/skyline_facades.png (1024). Ground planes and backdrop of the file are dropped.
All buildings share one material ("city_bldg") so a block of different buildings is one draw call (MeshBatch).
Usage: blender -b --factory-startup -P blender/scripts/build_t193_city.py -- [--src docs/Modelos/Cidade] (--building KEY | --atlas | --skyline) [--preview]
"""
from __future__ import annotations

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import export as EX  # noqa: E402
from lib import mesh3d as M  # noqa: E402

OUT_GLB = os.path.join(ROOT, "game", "assets", "scenery", "city")
OUT_TEX = os.path.join(ROOT, "game", "assets", "textures", "city")
WORK = os.path.join(ROOT, "blender", "renders", "t193", "city")
CELL_PX = 512
SMALL_PART_M = 4.0        # loose pieces smaller than this (diagonal) are dropped before reducing
COLS, ROWS = 4, 2
# key: (file name without extension, texture prefix, atlas cell, LOD0 tris, LOD1 tris (unused))
BUILDINGS = {
    "big01": ("Building-Big-01", "Building-Big-01", 0, 1400, 0),
    "bigwide01": ("Building-Big-Wide-01", "Building-Big-Wide-01", 1, 1400, 0),
    "bigwide02": ("Building-Big-Wide-02", "Building-Big-Wide-02", 2, 1400, 0),
    "med01": ("Building-Medium-01", "Building-Medium-01", 3, 1200, 0),
    "med02": ("Building-Medium-02", "Building-Medium-02", 4, 1200, 0),
    "small": ("Building-Small", "Building-Small", 5, 1000, 0),
    "sky01": ("Skyscraper-01", "Skyscraper-01", 6, 1600, 0),
    "sky02": ("Skyscraper-02", "Skyscraper-02", 7, 1600, 0),
}
VOXEL_DIV = {"big01": 0.0, "med01": 0.0, "small": 0.0}    # 0 = box of the bounds (glass walls the remesh loses)
IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def write_import(png: str) -> None:
    p = png + ".import"
    if not os.path.isfile(p):
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(IMPORT_TMPL)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def joined_meshes(keep=lambda o: True):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and keep(o)]
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH" and not keep(o)]:
        bpy.data.objects.remove(o, do_unlink=True)
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
    return bpy.context.view_layer.objects.active


def weld_and_flatten(o) -> None:
    """The buildings come as loose faces: weld them, then dissolve flat walls (keeping the UV islands), so the collapse
    below can actually reduce them."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-2)
    # small loose pieces (window frames, sills, AC boxes: already painted in the baked texture) block the collapse
    seen = set()
    dead = []
    for v0 in bm.verts:
        if v0.index in seen:
            continue
        stack, part = [v0], []
        seen.add(v0.index)
        while stack:
            v = stack.pop()
            part.append(v)
            for e in v.link_edges:
                w = e.other_vert(v)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        co = np.array([v.co[:] for v in part])
        if np.linalg.norm(co.max(0) - co.min(0)) < SMALL_PART_M:
            dead += part
    bmesh.ops.delete(bm, geom=dead, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    md = o.modifiers.new("flat", "DECIMATE")
    md.decimate_type = "DISSOLVE"
    md.angle_limit = math.radians(2.0)
    md.delimit = {"UV"}
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=md.name)
    tri = o.modifiers.new("tri", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)


def decimated_copy(o, target: int, name: str):
    c = o.copy()
    c.data = o.data.copy()
    c.name = c.data.name = name
    bpy.context.scene.collection.objects.link(c)
    cur = sum(len(p.vertices) - 2 for p in c.data.polygons)
    if cur > target:
        md = c.modifiers.new("dec", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = target / cur
        md.use_collapse_triangulate = True
        bpy.ops.object.select_all(action="DESELECT")
        c.select_set(True)
        bpy.context.view_layer.objects.active = c
        r = bpy.ops.object.modifier_apply(modifier=md.name)
        print("  reduzir %s: %d -> %d (ratio %.4f, %s, modifiers=%s)" % (name, cur, tris(c), target / cur, r, [m.name for m in c.modifiers]))
    for p in c.data.polygons:
        p.use_smooth = False
    return c


def cell_rect(cell: int) -> tuple:
    col, row = cell % COLS, cell // COLS
    pad = 2.0 / (CELL_PX * COLS)                       # 2 px margin inside the cell (mipmaps)
    padv = 2.0 / (CELL_PX * ROWS)
    u0, u1 = col / COLS + pad, (col + 1) / COLS - pad
    v1 = 1.0 - row / ROWS - padv                      # Blender UV: v = 0 at the bottom; row 0 = top
    v0 = 1.0 - (row + 1) / ROWS + padv
    return u0, v0, u1, v1


def remap_uv(o, cell: int) -> tuple:
    uv = o.data.uv_layers.active.data
    a = np.zeros(len(uv) * 2, np.float32)
    uv.foreach_get("uv", a)
    a = a.reshape(-1, 2)
    lo, hi = a.min(0), a.max(0)
    a = np.clip(a, 0.0, 1.0)
    u0, v0, u1, v1 = cell_rect(cell)
    a[:, 0] = u0 + a[:, 0] * (u1 - u0)
    a[:, 1] = v0 + a[:, 1] * (v1 - v0)
    uv.foreach_set("uv", a.ravel())
    return lo, hi


def export(o, path: str, mat: str) -> None:
    o.data.materials.clear()
    o.data.materials.append(bpy.data.materials.get(mat) or bpy.data.materials.new(mat))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_image_format="NONE", export_materials="EXPORT")


def tris(o) -> int:
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def reduced_pixels(path: str, size: int) -> np.ndarray:
    """(size, size, 4) float, row 0 at the TOP. Scales inside Blender first (the 4096 px original never goes to numpy)."""
    im = bpy.data.images.load(path)
    linear = im.is_float and im.colorspace_settings.name != "Non-Color"   # 16-bit PNG: Blender hands out linear values
    im.scale(size, size)
    px = np.zeros(size * size * 4, np.float32)
    im.pixels.foreach_get(px)
    bpy.data.images.remove(im)
    px = px.reshape(size, size, 4)[::-1].copy()
    if linear:
        c = np.clip(px[..., :3], 0.0, 1.0)
        px[..., :3] = np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)
    return px


def textured_source(o, diffuse: str) -> None:
    """Material of the original = its baked diffuse texture (the FBX does not find it), for the bake below."""
    m = bpy.data.materials.new("src_bake")
    m.use_nodes = True
    nt = m.node_tree
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = bpy.data.images.load(diffuse)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    o.data.materials.clear()
    o.data.materials.append(m)


def proxy_of(o, target: int, name: str, div: float = 45.0):
    """Low-poly shell of the building: voxel remesh (closed, no loose parts) + collapse + smart UV."""
    c = o.copy()
    c.data = o.data.copy()
    c.name = c.data.name = name
    bpy.context.scene.collection.objects.link(c)
    lo, hi = M.bounds([c])
    vox = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) / max(div, 1.0)
    bpy.ops.object.select_all(action="DESELECT")
    c.select_set(True)
    bpy.context.view_layer.objects.active = c
    if div <= 0.0:                      # glass walls (single planes): the remesh loses them -> box of the bounds
        import bmesh
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=hi - lo, verts=bm.verts)
        bmesh.ops.translate(bm, vec=(lo + hi) * 0.5, verts=bm.verts)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=7, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        c.data.clear_geometry()
        bm.to_mesh(c.data)
        bm.free()
        vox = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) / 45.0
        target = 10 ** 9                            # no collapse
    else:
        rm = c.modifiers.new("vox", "REMESH")
        rm.mode = "VOXEL"
        rm.voxel_size = vox
        bpy.ops.object.modifier_apply(modifier=rm.name)
    md = c.modifiers.new("dec", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = min(1.0, target / max(tris(c), 1))
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=md.name)
    while c.data.uv_layers:
        c.data.uv_layers.remove(c.data.uv_layers[0])
    c.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    for p in c.data.polygons:
        p.use_smooth = False
    return c, vox


def bake_onto(src, dst, size: int, extrusion: float) -> np.ndarray:
    """Cycles: diffuse colour of `src` (high poly) onto the UV of `dst`. Returns (size, size, 4), row 0 at the top."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    img = bpy.data.images.new("bake", size, size, alpha=False)
    m = bpy.data.materials.new("dst_bake")
    m.use_nodes = True
    tn = m.node_tree.nodes.new("ShaderNodeTexImage")
    tn.image = img
    m.node_tree.nodes.active = tn
    dst.data.materials.clear()
    dst.data.materials.append(m)
    bpy.ops.object.select_all(action="DESELECT")
    src.select_set(True)
    dst.select_set(True)
    bpy.context.view_layer.objects.active = dst
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True,
                        cage_extrusion=extrusion, max_ray_distance=extrusion * 2.5, margin=4)
    px = np.zeros(size * size * 4, np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(size, size, 4)[::-1].copy()


def build_building(key: str, src: str) -> None:
    fname, tex, cell, t0, _t1 = BUILDINGS[key]
    reset()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "Buildings-FBX", "Buildings-FBX", fname + ".fbx"))
    o = joined_meshes()
    src_tris = tris(o)
    lo, hi = M.bounds([o])
    o.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))))
    textured_source(o, os.path.join(src, "Textures_no", "Textures", tex + "_Bake1_PBR_Diffuse.png"))
    l0, vox = proxy_of(o, t0, "bldg_" + key, VOXEL_DIV.get(key, 45.0))
    px = bake_onto(o, l0, CELL_PX, vox * 1.6)
    px[..., 3] = 1.0
    EX.save_png(px, os.path.join(WORK, "cell_%s.png" % key))
    remap_uv(l0, cell)
    lo, hi = M.bounds([l0])
    l0.location.z -= lo.z                                       # the remesh can grow a little below the ground
    bpy.ops.object.select_all(action="DESELECT")
    l0.select_set(True)
    bpy.context.view_layer.objects.active = l0
    bpy.ops.object.transform_apply(location=True)
    export(l0, os.path.join(OUT_GLB, "bldg_%s.glb" % key), "city_bldg")
    lo, hi = M.bounds([l0])
    print("CITY_T193 bldg_%-9s origem=%7d tri -> %5d tri (voxel %.2f m)  %.1f x %.1f x %.1f m" % (
        key, src_tris, tris(l0), vox, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))


def build_atlas() -> None:
    reset()
    at = np.zeros((CELL_PX * ROWS, CELL_PX * COLS, 4), np.float32)
    at[..., 3] = 1.0
    for key, (_f, _t, cell, _a, _b) in BUILDINGS.items():
        p = os.path.join(WORK, "cell_%s.png" % key)
        im = bpy.data.images.load(p)
        px = np.zeros(CELL_PX * CELL_PX * 4, np.float32)
        im.pixels.foreach_get(px)
        px = px.reshape(CELL_PX, CELL_PX, 4)[::-1]
        col, row = cell % COLS, cell // COLS
        at[row * CELL_PX:(row + 1) * CELL_PX, col * CELL_PX:(col + 1) * CELL_PX] = px
    out = os.path.join(OUT_TEX, "bldg_atlas.png")
    EX.save_png(at, out)
    write_import(out)
    print("CITY_T193 atlas", out)


def build_skyline(src: str) -> None:
    reset()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "city.fbx"), use_image_search=True)
    o = joined_meshes(lambda ob: "bldgs" in ob.name)
    src_tris = tris(o)
    lo, hi = M.bounds([o])
    s = 620.0 / max(hi.x - lo.x, hi.y - lo.y)
    o.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))))
    for p in o.data.polygons:
        p.use_smooth = False
    lo, hi = M.bounds([o])
    export(o, os.path.join(OUT_GLB, "city_skyline.glb"), "city_skyline")
    px = reduced_pixels(os.path.join(src, "texture", "cty2x.jpg"), 1024)
    px[..., 3] = 1.0
    out = os.path.join(OUT_TEX, "skyline_facades.png")
    EX.save_png(px, out)
    write_import(out)
    print("CITY_T193 skyline origem=%d tri  %.0f x %.0f x %.0f m  escala=%.1f" % (src_tris, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, s))


def main() -> None:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    src = os.path.abspath(a[a.index("--src") + 1]) if "--src" in a else os.path.join(ROOT, "docs", "Modelos", "Cidade")
    os.makedirs(WORK, exist_ok=True)
    if "--building" in a:
        build_building(a[a.index("--building") + 1], src)
    if "--atlas" in a:
        build_atlas()
    if "--skyline" in a:
        build_skyline(src)
    print("OK build_t193_city")


main()
