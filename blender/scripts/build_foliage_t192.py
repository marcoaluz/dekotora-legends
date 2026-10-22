"""T-192: the code-made trees redone (Marco: "still look like toys"): pine, Japanese cedar, round tree, bush and the
3 coconut palms. Layered foliage = textured cards (atlas foliage_leaves.png, lib/tex_foliage.py) around a dark
inner volume, irregular silhouette, colour varying per branch/clump, "volume" normals (outward from the crown), V-folded
palm fronds, ringed palm trunks. Each model has LOD0 and a light LOD1 (<name>_lod1.glb), same heights as before.
Materials by name (the game builds them, BackdropKit.tree_mesh_of): "tree_bark" (vertex colour) and "tree_leaves"
(atlas x vertex colour, alpha scissor). Origin at the base, front = +Y (Blender). Deterministic (fixed seeds).

Usage: blender -b --factory-startup -P blender/scripts/build_foliage_t192.py -- [--only name1,name2] [--preview]
  Outputs: game/assets/scenery/<name>[_lod1].glb, game/assets/textures/backdrop/foliage_leaves.png,
  blender/renders/t192/foliage.json and (--preview) blender/renders/t192/foliage_sheet.png
"""
from __future__ import annotations

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import preview, scene, tex_foliage as TF, tex_scenic, tree_atlas as TA  # noqa: E402

OUT = os.path.join(ROOT, "game", "assets", "scenery")
TEX = os.path.join(ROOT, "game", "assets", "textures", "backdrop", "foliage_leaves.png")
WORK = os.path.join(ROOT, "blender", "renders", "t192")
UP = Vector((0, 0, 1))
CORE = (0.028, 0.055, 0.02)           # inner volume (linear vertex colour = dark foliage in the shade)
CORE_FAR = (0.05, 0.085, 0.025)       # LOD1: the inner volume carries the whole crown far away
PALM_PTS = [(0.0, 0.0, 0.0), (0.25, 0.0, 2.0), (0.7, 0.0, 4.0), (1.3, 0.0, 5.8), (1.9, 0.0, 7.2)]
TALL_PTS = [(0.0, 0.0, 0.0), (0.1, 0.0, 2.6), (0.3, 0.0, 5.2), (0.6, 0.0, 7.6), (0.95, 0.0, 9.8)]
BENT_PTS = [(0.0, 0.0, 0.0), (0.6, 0.0, 1.5), (1.6, 0.0, 2.9), (2.8, 0.0, 4.2), (3.9, 0.0, 5.6)]


class Tree:
    """bmesh with colour + UV layers; leaves remember their 'crown centre' for the volume normals."""

    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.leaf_centre = {}            # vert index -> crown centre (Vector)

    def face(self, pts, uvs, cols, mat: int, centre=None):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = mat
        for lp, uv, c in zip(f.loops, uvs, cols):
            lp[self.uv].uv = uv
            lp[self.col] = (c[0], c[1], c[2], 1.0)
        if centre is not None:
            self.bm.verts.index_update()
            for v in vs:
                self.leaf_centre[v.index] = Vector(centre)
        return f

    def strip(self, rows, uv_rows, col_rows, mat: int, centre=None):
        """Grid between consecutive rows (each row = list of points across)."""
        for r in range(len(rows) - 1):
            for c in range(len(rows[r]) - 1):
                self.face([rows[r][c], rows[r][c + 1], rows[r + 1][c + 1], rows[r + 1][c]],
                          [uv_rows[r][c], uv_rows[r][c + 1], uv_rows[r + 1][c + 1], uv_rows[r + 1][c]],
                          [col_rows[r][c], col_rows[r][c + 1], col_rows[r + 1][c + 1], col_rows[r + 1][c]], mat, centre)

    def tube(self, pts, radii, sides: int, cols, jitter=0.0, rng=None):
        """Bark tube along pts (closed sides, no caps); cols = colour per ring."""
        rows = []
        for i, p in enumerate(pts):
            p = Vector(p)
            ax = (Vector(pts[min(i + 1, len(pts) - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
            s = ax.cross(Vector((0.0, 1.0, 0.0)) if abs(ax.y) < 0.9 else Vector((1.0, 0.0, 0.0))).normalized()
            t = ax.cross(s)
            ring = []
            for k in range(sides + 1):
                a = math.tau * (k % sides) / sides
                r = radii[i] * (1.0 + (jitter * (rng.random() - 0.5) if rng is not None and k < sides else 0.0))
                ring.append(p + (s * math.cos(a) + t * math.sin(a)) * r)
            rows.append(ring)
        uvs = [[(0.0, 0.0)] * (sides + 1) for _ in rows]
        self.strip(rows, uvs, [[c] * (sides + 1) for c in cols], 0)

    def finish(self, name: str) -> bpy.types.Object:
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for mname in ("tree_bark", "tree_leaves"):
            me.materials.append(bpy.data.materials.get(mname) or bpy.data.materials.new(mname))
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        me.shade_smooth()
        normals = []
        vn = [Vector(v.normal) for v in me.vertices]
        for lp in me.loops:
            c = self.leaf_centre.get(lp.vertex_index)
            if c is None:
                normals.append(tuple(vn[lp.vertex_index]))
            else:
                d = me.vertices[lp.vertex_index].co - c
                normals.append(tuple((d.normalized() * 0.7 + UP * 0.35).normalized() if d.length > 1e-4 else UP))
        me.normals_split_custom_set(normals)
        return obj


def _uv(rect, u, v):
    return (rect[0] + (rect[2] - rect[0]) * u, rect[1] + (rect[3] - rect[1]) * v)


def _mul(c, k):
    return (c[0] * k, c[1] * k, c[2] * k)


# ------------------------------------------------------------------ conifers (pine, cedar)
def conifer(rng, H, base, rmax, whorls, per, pitch, droop, tint, bark, lod, column=1.0):
    t = Tree()
    sides = 7 if lod == 0 else 5
    zs = np.linspace(0.0, H * 0.9, 6 if lod == 0 else 3)
    t.tube([(0, 0, z) for z in zs], [0.24 * (1.0 - 0.8 * z / H) + 0.03 for z in zs], sides,
           [_mul(bark, 0.8 + 0.2 * z / H) for z in zs])

    def radius(z):
        f = max(0.0, min(1.0, (z - base) / (H - base)))
        return rmax * (1.0 - f) ** column * (0.35 + 0.65 * min(1.0, (z - base + 0.4) / 1.2))

    core = []                                            # dark inner volume (cone, jittered)
    nz = 5 if lod == 0 else 3
    for i in range(nz):
        z = base + 0.2 + (H - 0.6 - base - 0.2) * i / (nz - 1)
        core.append(((0, 0, z), radius(z) * (0.55 if lod == 0 else 0.78)))
    crow = [CORE if lod == 0 else CORE_FAR] * nz
    t.tube([c[0] for c in core], [max(c[1], 0.05) for c in core], 7 if lod == 0 else 5, crow, 0.3, rng)
    golden = 2.39996
    az = rng.uniform(0, math.tau)
    zs = np.linspace(base, H - 0.7, whorls)
    rect = TF.UV_CONIFER
    for wi, z in enumerate(zs):
        z += rng.uniform(-0.12, 0.12)
        n = per + (rng.integers(-1, 2) if lod == 0 else 0)
        for _ in range(n):
            az += golden + rng.uniform(-0.3, 0.3)
            d = Vector((math.cos(az), math.sin(az), 0.0))
            ln = radius(z) * rng.uniform(0.8, 1.2) + 0.25
            p = pitch + rng.uniform(-0.12, 0.12)
            hf = (z - base) / (H - base)
            shade = (0.62 + 0.28 * hf + rng.uniform(-0.07, 0.07)) * rng.uniform(0.93, 1.05)
            col = (tint[0] * shade * rng.uniform(0.92, 1.08), tint[1] * shade, tint[2] * shade * rng.uniform(0.9, 1.1))
            b = Vector((0, 0, z)) + d * 0.08
            wd = max(0.6, ln * 0.95)
            rolls = (0.62, -0.62) if lod == 0 else ((0.9 if wi % 2 else -0.9),)
            steps = (0.0, 0.5, 1.0) if lod == 0 else (0.0, 1.0)
            for roll in rolls:
                side = d.cross(UP).normalized()
                across = side * math.cos(roll) + UP * math.sin(roll)
                rows, uvs, cols = [], [], []
                for s in steps:
                    sp = b + d * ln * s * math.cos(p) + UP * (ln * s * math.sin(p) - droop * ln * s * s)
                    w = wd * (0.55 + 0.45 * math.sin(math.pi * min(s * 0.8 + 0.2, 1.0)))
                    rows.append([sp - across * w * 0.5, sp + across * w * 0.5])
                    uvs.append([_uv(rect, 0.0, s), _uv(rect, 1.0, s)])
                    cols.append([_mul(col, 0.7 + 0.3 * s)] * 2)
                t.strip(rows, uvs, cols, 1, (0, 0, z - 0.4))
    for k in range(2):                                   # leader tuft on top
        a = az + k * math.pi * 0.5
        d = Vector((math.cos(a), math.sin(a), 0.0)) * 0.45
        top = Vector((0, 0, H + 0.5))
        bot = Vector((0, 0, H - 1.1))
        t.face([bot - d, bot + d, top + d, top - d], [_uv(rect, 0, 0), _uv(rect, 1, 0), _uv(rect, 1, 1), _uv(rect, 0, 1)],
               [_mul(tint, 0.85)] * 4, 1, (0, 0, H - 1.5))
    return t


def tree_pine(lod):
    rng = np.random.default_rng(31)
    return conifer(rng, 7.2, 1.7, 2.1, 12 if lod == 0 else 4, 6 if lod == 0 else 4, 0.12, 0.30,
                   (0.78, 0.92, 0.72), (0.30, 0.20, 0.13), lod)


def tree_cedar(lod):
    rng = np.random.default_rng(37)
    return conifer(rng, 11.6, 2.4, 1.75, 15 if lod == 0 else 5, 5 if lod == 0 else 4, 0.30, 0.38,
                   (0.62, 0.80, 0.66), (0.36, 0.22, 0.14), lod, column=0.8)


# ------------------------------------------------------------------ broadleaf clumps (bush, round tree)
def clumps(t, rng, centre, radii, n, size, cards, tint, lod):
    centre = Vector(centre)
    rect = TF.UV_CLUMP
    golden = 2.39996
    for i in range(n):
        zf = 1.0 - 1.6 * (i + 0.5) / n                    # spread over the upper part of the ellipsoid
        zf = max(-0.45, zf)
        a = i * golden + rng.uniform(-0.3, 0.3)
        rr = math.sqrt(max(0.0, 1.0 - zf * zf))
        dirv = Vector((math.cos(a) * rr, math.sin(a) * rr, zf))
        pos = centre + Vector((dirv.x * radii[0], dirv.y * radii[1], dirv.z * radii[2])) * rng.uniform(0.78, 0.98)
        s = size * rng.uniform(0.8, 1.2)
        shade = (0.66 + 0.3 * (zf * 0.5 + 0.5) + rng.uniform(-0.07, 0.07))
        col = (tint[0] * shade * rng.uniform(0.9, 1.1), tint[1] * shade, tint[2] * shade * rng.uniform(0.85, 1.1))
        rot = rng.uniform(0, math.pi)
        for k in range(cards):
            ang = rot + k * math.pi / cards
            h = Vector((math.cos(ang), math.sin(ang), 0.0)) * s * 0.5
            tilt = rng.uniform(-0.35, 0.35)
            v = (UP + dirv * 0.25 + h.normalized() * tilt).normalized() * s * 0.5
            q = [pos - h - v, pos + h - v, pos + h + v, pos - h + v]
            t.face(q, [_uv(rect, 0, 0), _uv(rect, 1, 0), _uv(rect, 1, 1), _uv(rect, 0, 1)],
                   [_mul(col, 0.78), _mul(col, 0.78), col, col], 1, centre)


def blob(t, rng, centre, radii, tint, lod):
    """Dark inner volume (jittered ellipsoid, bark material with leaf colour)."""
    rings = 4 if lod == 0 else 3
    sides = 7 if lod == 0 else 5
    pts, rad = [], []
    for i in range(rings + 1):
        f = -0.85 + 1.7 * i / rings
        pts.append((centre[0], centre[1], centre[2] + f * radii[2]))
        rad.append(max(0.04, math.sqrt(max(0.0, 1 - f * f)) * radii[0]))
    far = CORE_FAR if lod else CORE
    t.tube(pts, rad, sides, [_mul(far, 0.8 + 0.4 * i / rings) for i in range(rings + 1)], 0.35, rng)


def bush(lod):
    rng = np.random.default_rng(41)
    t = Tree()
    tint = (0.66, 0.80, 0.58)
    blob(t, rng, (0, 0, 0.5), (0.6, 0.55, 0.42), tint, lod)
    clumps(t, rng, (0, 0, 0.55), (1.05, 0.9, 0.7), 12 if lod == 0 else 5, 0.95, 3 if lod == 0 else 2, tint, lod)
    clumps(t, rng, (0.75, 0.25, 0.42), (0.6, 0.55, 0.45), 4 if lod == 0 else 0, 0.85, 3, _mul(tint, 0.95), lod)
    return t


def tree_round(lod):
    rng = np.random.default_rng(43)
    t = Tree()
    bark = (0.30, 0.24, 0.18)
    t.tube([(0, 0, 0), (0.05, 0, 1.6), (0.12, 0.05, 3.2)], [0.22, 0.17, 0.12], 7 if lod == 0 else 5, [bark] * 3)
    if lod == 0:
        for k in range(3):                               # 3 limbs into the crown
            a = k * math.tau / 3 + 0.4
            t.tube([(0.1, 0.03, 2.4), (math.cos(a) * 0.9, math.sin(a) * 0.9, 3.6)], [0.09, 0.05], 5, [bark] * 2)
    tint = (0.85, 1.0, 0.72)
    blob(t, rng, (0, 0, 3.8), (1.15, 1.1, 0.95), tint, lod)
    clumps(t, rng, (0, 0, 3.8), (1.9, 1.8, 1.55), 16 if lod == 0 else 6, 1.45, 3 if lod == 0 else 2, tint, lod)
    return t


# ------------------------------------------------------------------ coconut palms
def _resample(pts, step):
    out = [Vector(pts[0])]
    for a, b in zip(pts[:-1], pts[1:]):
        a, b = Vector(a), Vector(b)
        n = max(1, int((b - a).length / step))
        out += [a.lerp(b, (i + 1) / n) for i in range(n)]
    return out


def palm_tree(seed, pts, fronds, flen, lod):
    rng = np.random.default_rng(seed)
    t = Tree()
    trunk = _resample(pts, 0.42 if lod == 0 else 1.6)
    n = len(trunk)
    radii = [(0.26 - 0.1 * i / (n - 1)) * (1.35 if i == 0 else 1.0) for i in range(n)]
    ring = [(0.36, 0.30, 0.23), (0.25, 0.21, 0.16)]
    cols = [ring[i % 2] if lod == 0 else (0.31, 0.26, 0.20) for i in range(n)]
    t.tube([tuple(p) for p in trunk], radii, 7 if lod == 0 else 5, cols)
    top = trunk[-1]
    lean = (trunk[-1] - trunk[-2]).normalized()
    t.tube([tuple(top - lean * 0.1), tuple(top + lean * 0.55)], [0.2, 0.1], 6 if lod == 0 else 4,
           [(0.30, 0.32, 0.16), (0.24, 0.30, 0.13)])         # crownshaft
    if lod == 0:
        for k in range(5):                                # coconuts
            a = k * math.tau / 5 + 0.3
            c = top + Vector((math.cos(a) * 0.24, math.sin(a) * 0.24, -0.22 - 0.08 * (k % 2)))
            t.tube([tuple(c + UP * 0.13), tuple(c - UP * 0.13)], [0.12, 0.1], 5, [(0.30, 0.30, 0.10), (0.22, 0.20, 0.08)])
    rect = TF.UV_FROND
    order = rng.permutation(fronds)
    steps = (0.0, 0.2, 0.4, 0.6, 0.8, 1.0) if lod == 0 else (0.0, 0.5, 1.0)
    for k in range(fronds):
        rank = order[k] / max(fronds - 1, 1)              # 0 = top (rising), 1 = lowest (hanging)
        az = k * 2.39996 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(az), math.sin(az), 0.0))
        elev = math.radians(52.0 - 95.0 * rank + rng.uniform(-8, 8))
        ln = flen * rng.uniform(0.85, 1.1) * (0.8 if rank < 0.15 else 1.0)
        droop = 0.35 + 0.9 * rank
        dead = rank > 0.9 and lod == 0
        col = (0.55, 0.45, 0.22) if dead else _mul((0.86, 0.98, 0.78), rng.uniform(0.85, 1.05))
        side = d.cross(UP).normalized()
        rows, uvs, crow = [], [], []
        for s in steps:
            sp = top + d * ln * s * math.cos(elev) + UP * (ln * s * math.sin(elev) - droop * ln * s * s)
            w = 0.9 * (0.4 + 0.6 * min(1.0, s * 3.0))
            fold = UP * (-0.32 * w if lod == 0 else -0.15 * w)
            rows.append([sp - side * w + fold, sp, sp + side * w + fold])
            uvs.append([_uv(rect, 0.0, s), _uv(rect, 0.5, s), _uv(rect, 1.0, s)])
            crow.append([_mul(col, 0.65 + 0.35 * s)] * 3)
        t.strip(rows, uvs, crow, 1, top - UP * 0.8)
    return t


BUILD = {
    "tree_pine": tree_pine, "tree_cedar": tree_cedar, "tree_round": tree_round, "bush": bush,
    "palm": lambda lod: palm_tree(51, PALM_PTS, 14 if lod == 0 else 8, 3.0, lod),
    "palm_tall": lambda lod: palm_tree(53, TALL_PTS, 16 if lod == 0 else 8, 3.3, lod),
    "palm_bent": lambda lod: palm_tree(57, BENT_PTS, 12 if lod == 0 else 7, 2.7, lod),
}


def export(obj, name: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_cameras=False, export_lights=False,
                              export_image_format="NONE", export_materials="EXPORT",
                              export_vertex_color="NAME", export_vertex_color_name="Col",
                              export_all_vertex_colors=False)


def main() -> None:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = a[a.index("--only") + 1].split(",") if "--only" in a else list(BUILD)
    os.makedirs(WORK, exist_ok=True)
    tex_scenic.save_rgba(TF.atlas(), TEX)
    report, shots = [], []
    for name in only:
        scene.reset_scene()
        objs = []
        for lod in (0, 1):
            nm = name if lod == 0 else name + "_lod1"
            obj = BUILD[name](lod).finish(nm)
            export(obj, nm)
            tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            dims = [round(v, 2) for v in obj.dimensions]
            report.append({"name": nm, "tris": tris, "size_m": dims})
            print("FOLIAGE", json.dumps(report[-1]))
            objs.append(obj)
        if "--preview" in a:
            shots += TA.preview_variant(objs, TEX, WORK, name)
    with open(os.path.join(WORK, "foliage.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=1)
    if shots:
        preview.contact_sheet(shots, os.path.join(WORK, "foliage_sheet.png"), cols=4)
    print("OK foliage")


main()
