"""T-193: classes of a car whose materials carry NO colour/texture (3ds Max materials that do not survive the FBX:
"Low Poly Cars Set" and the Skyline). Each material slot = one part of the car (body, glass, lamps, tyres...), so the
class is decided per SLOT by geometry: where the part is (front/back, height, sides), its area and where it faces.
Wheels: the slot that touches the ground is the tyre; the axles come from the contact patches; everything inside the
wheel cylinders goes to the wheel objects (build_traffic_cars.py then puts our own round wheels in the same place).
Tiny loose parts at the nose/tail centre (badges, logos) and the interior (seats, wheel) are deleted.
Frame: front +Y, rear at Y=0, ground Z=0 (after place_std).
"""
from __future__ import annotations

import numpy as np

from . import traffic_kit as K


def _verts(o) -> np.ndarray:
    co = np.zeros(len(o.data.vertices) * 3, np.float32)
    o.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def _face_vert_lists(o):
    me = o.data
    start = np.zeros(len(me.polygons), np.int32)
    tot = np.zeros(len(me.polygons), np.int32)
    me.polygons.foreach_get("loop_start", start)
    me.polygons.foreach_get("loop_total", tot)
    lv = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", lv)
    return start, tot, lv


def axles(o, dims, slot_of_face: np.ndarray):
    """[(y, r)] of the front and rear axle + the tyre slot (the one with most vertices on the ground)."""
    L, W, H = dims
    co = _verts(o)
    start, tot, lv = _face_vert_lists(o)
    low = co[:, 2] < 0.03 + co[:, 2].min()
    # tyre slot = slot of the faces that use the most ground vertices
    count: dict = {}
    for f in range(len(slot_of_face)):
        vs = lv[start[f]:start[f] + tot[f]]
        n = int(low[vs].sum())
        if n:
            count[int(slot_of_face[f])] = count.get(int(slot_of_face[f]), 0) + n
    top = max(count.values())
    tyre = sorted(k for k, v in count.items() if v >= top * 0.2)      # one slot per tyre in some models
    tyre_v = np.zeros(len(co), bool)
    for f in np.nonzero(np.isin(slot_of_face, tyre))[0]:
        tyre_v[lv[start[f]:start[f] + tot[f]]] = True
    out = []
    for front in (True, False):
        half = (co[:, 1] > L * 0.5) if front else (co[:, 1] <= L * 0.5)
        P = co[tyre_v & half & (np.abs(co[:, 0]) > W * 0.25)]
        ya = float((P[:, 1].min() + P[:, 1].max()) * 0.5)
        r = float((P[:, 2].max() - P[:, 2].min()) * 0.5)
        out.append((ya, r))
    return out, tyre


def prep_groups(spec, objs, dims, _to_final):
    L, W, H = dims
    o = K.join(objs, "body")
    me = o.data
    slot = np.zeros(len(me.polygons), np.int32)
    me.polygons.foreach_get("material_index", slot)
    (af, ar), tyre = axles(o, dims, slot)
    ctr, nrm, area, _uv = K.face_data(o)
    co = _verts(o)
    start, tot, lv = _face_vert_lists(o)

    # wheels: every face whose vertices are inside one of the 4 wheel cylinders (outer part of the car)
    def in_wheel(vs) -> bool:
        P = co[vs]
        if np.abs(P[:, 0]).min() < W * 0.5 * spec.get("wheel_inner", 0.42):
            return False
        for ya, r in (af, ar):
            if (np.hypot(P[:, 1] - ya, P[:, 2] - r) <= r * 1.06).all():
                return True
        return False

    wheel = np.array([in_wheel(lv[start[f]:start[f] + tot[f]]) for f in range(len(slot))])

    # per slot (without the wheel faces): bbox, area, mean |x|, mean normal z
    cls = np.empty(len(slot), object)
    stats = {}
    for s in np.unique(slot):
        m = (slot == s) & ~wheel
        if not m.any():
            continue
        c = ctr[m]
        a = area[m]
        stats[int(s)] = dict(area=float(a.sum()), lo=c.min(0), hi=c.max(0), cz=float((c[:, 2] * a).sum() / max(a.sum(), 1e-9)),
                             cy=float((c[:, 1] * a).sum() / max(a.sum(), 1e-9)), ax=float((np.abs(c[:, 0]) * a).sum() / max(a.sum(), 1e-9)),
                             nz=float((nrm[m][:, 2] * a).sum() / max(a.sum(), 1e-9)), n=int(m.sum()))
    paint = max(stats, key=lambda k: stats[k]["area"])
    names = [mt.name if mt else "" for mt in me.materials] or [""]
    for s, st in stats.items():
        span_y = st["hi"][1] - st["lo"][1]
        if s in spec.get("force", {}):
            c = spec["force"][s]
        elif any(w in names[s].lower() for w in spec.get("name_cls", {})):
            c = next(v for w, v in spec["name_cls"].items() if w in names[s].lower())
        elif s == paint:
            c = K.PAINT
        elif st["nz"] < -0.6 or st["hi"][2] < H * 0.22:
            c = "under"
        elif st["lo"][2] > H * 0.42 and st["cz"] > H * 0.62 and span_y > L * 0.3 and st["nz"] < 0.8:
            c = "glass"
        elif st["nz"] >= 0.8 and st["cz"] > H * 0.8:
            c = K.PAINT                                   # roof panel in its own slot
        elif st["area"] < 0.8 and st["lo"][1] > L * 0.82 and H * 0.25 < st["cz"] < H * 0.8:
            c = "lamp_white" if st["ax"] > W * 0.22 else "grille"
        elif st["area"] < 0.8 and st["hi"][1] < L * 0.2 and H * 0.3 < st["cz"] < H * 0.85:
            c = "lamp_red" if st["ax"] > W * 0.22 else "plastic"
        elif st["area"] > 1.5 and span_y > L * 0.5:
            c = K.PAINT                                   # second big body panel (bumpers, doors in another slot)
        elif spec.get("default") == K.PAINT:              # one object per panel (Skyline): body colour unless tiny
            c = "plastic" if st["area"] < 0.04 else K.PAINT
        elif st["area"] < 0.25:
            c = "chrome" if st["ax"] < W * 0.35 else "plastic"
        else:
            c = "plastic"
        cls[(slot == s) & ~wheel] = c
        print(f"  slot {s:2d} {names[s][:22]:22s} n={st['n']:6d} area={st['area']:6.2f} y={st['lo'][1]:.2f}-{st['hi'][1]:.2f} "
              f"z={st['lo'][2]:.2f}-{st['hi'][2]:.2f} cz={st['cz']:.2f} ax={st['ax']:.2f} nz={st['nz']:.2f} -> {c}")
    cls[wheel & np.isin(slot, tyre)] = "rubber"
    cls[wheel & ~np.isin(slot, tyre)] = "rim"
    K.assign_classes(o, list(cls))

    # delete: crumbs, badges at the nose/tail centre, interior parts
    def is_badge(P) -> bool:
        lo, hi = P.min(0), P.max(0)
        return (np.linalg.norm(hi - lo) < spec.get("badge_m", 0.2) and np.abs(P[:, 0]).max() < W * 0.22
                and (lo[1] > L * 0.9 or hi[1] < L * 0.1))

    def is_interior(P) -> bool:
        lo, hi = P.min(0), P.max(0)
        return np.abs(P[:, 0]).max() < W * 0.5 * 0.72 and lo[2] > H * 0.25 and lo[1] > L * 0.18 and hi[1] < L * 0.82 and hi[2] < H * 0.93

    small, badge = K.part_masks(o, keep_min=0.025, inside=is_badge)
    _s, inner = K.part_masks(o, inside=is_interior)
    drop = (small | badge | inner) & ~wheel
    keep_wheel = wheel[~drop]
    K.delete_faces(o, drop)
    wheels = K.split_faces(o, keep_wheel, "wheels")
    print(f"[{spec['tag']}] eixos y={af[0]:.2f}/{ar[0]:.2f} r={af[1]:.2f}/{ar[1]:.2f} pneus=slots {tyre}; "
          f"apagadas: miudas={int(small.sum())} emblemas={int(badge.sum())} interior={int(inner.sum())}")
    return [o], [wheels]


# ---------------------------------------------------------------- importers (T-193)
def import_pick(path: str, pick: str):
    """FBX with several cars side by side: keeps only the root `pick` (and its children)."""
    import bpy
    bpy.ops.import_scene.fbx(filepath=path)
    keep = set()
    root = bpy.data.objects.get(pick)
    stack = [root] if root else []
    while stack:
        o = stack.pop()
        keep.add(o.name)
        stack += list(o.children)
    for o in list(bpy.context.scene.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def import_per_object(path: str, drop_words=(), margin: float = 0.12, anchor: str = "Body"):
    """FBX without materials and one object per panel: each object gets its own material (= its own slot). Objects
    whose name has one of `drop_words` or that stick out of the `anchor` box (+ `margin` of its size) are deleted."""
    import bpy
    from mathutils import Vector
    bpy.ops.import_scene.fbx(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

    def box(o):
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        return (Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb))),
                Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb))))

    alo, ahi = box(bpy.data.objects[anchor])
    pad = (ahi - alo) * margin
    alo, ahi = alo - pad, ahi + pad
    alo.z = -1e9                                       # wheels go below the body
    out = []
    for o in meshes:
        lo, hi = box(o)
        inside = all(lo[k] >= alo[k] and hi[k] <= ahi[k] for k in range(3))
        if not inside:
            print("  fora do carro:", o.name)
        if any(w in o.name.lower() for w in drop_words) or not inside or len(o.data.polygons) == 0:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        m = bpy.data.materials.new(o.name)
        o.data.materials.clear()
        o.data.materials.append(m)
        out.append(o)
    return out
