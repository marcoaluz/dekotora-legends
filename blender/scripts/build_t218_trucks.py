"""Caminhões de homenagem (T-218): 5 modelos NOVOS feitos do zero por código (cabine `truck3d/t218_cab.py`,
carrocerias `truck3d/t218_bodies.py`), no chassi, rodas e decoração do caminhão padrão, com 3 LODs.

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t218_trucks.py -- [--only alubox,tarp,pinkbox,tanker,dump]
          [--out game/assets/vehicles/dekotora] [--preview PASTA_ABS] [--night]
Saídas: <out>/truck/dekotora_truck_<id>.glb (LOD0, com os MOUNT_*), <out>/truck/lod/dekotora_truck_<id>_lod1.glb e
_lod2.glb (sem pontos de montagem; o TruckNode troca pela distância), texturas compartilhadas em <out>/textures/.
`--preview`: frente, lateral, traseira, 3/4 (+ cabine de perto e os 3 LODs) em PASTA_ABS, com folha de contato.
Marcas e textos: só fictícios (marca "HAYATE", empresa 銀河運輸). Determinístico.
"""
import argparse
import os
import sys

import bpy
import bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, pbr, preview, scene, shared_tex  # noqa: E402
from lib import tex  # noqa: E402
from truck3d import t218_bodies as B, t218_cab as C  # noqa: E402
from truck3d.chassis import build_chassis  # noqa: E402
from truck3d.deco import build_deco, cab_brow  # noqa: E402
from truck3d.dims import MOUNTS, WHEEL_R  # noqa: E402
from truck3d.wheels import make_wheel, tire_profile  # noqa: E402

# id: (estilo da cabine, cor de fábrica da cabine para as prévias/BodyDef.default_paint)
TRUCKS = {
    "alubox": ("wide", "#c9cdd2"),
    "tarp": ("quad", "#1d2a4a"),
    "pinkbox": ("wide", "#f06aa8"),
    "tanker": ("wide", "#e8ecef"),
    "dump": ("quad", "#b3262d"),
}
REAR_AXLES = (1.5, 3.0)
LOD1_RATIO, LOD2_RATIO = 0.22, 0.05          # fração dos triângulos do LOD0
MURAL_DIR = "murals"


def materials(out_dir):
    m = pbr.truck_set(pbr.standard_set())
    m["rubber_tire"] = pbr.tire_material(tire_profile(WHEEL_R, 0.3), WHEEL_R)
    m["box_alu"] = pbr.pbr("box_alu", "#c3c8cf", metallic=0.55, roughness=0.3)
    m["box_pink"] = pbr.paint("box_pink", "#f27bb2")
    m["tarp"] = pbr.pbr("tarp", "#2d7d74", metallic=0.0, roughness=0.82)
    m["tarp_dark"] = pbr.pbr("tarp_dark", "#1f5a53", metallic=0.0, roughness=0.85)
    m["rope"] = pbr.pbr("rope", "#d9d2bd", metallic=0.0, roughness=0.9)
    m["band_white"] = pbr.pbr("band_white", "#f2f2ee", metallic=0.0, roughness=0.4)
    m["tank_shell"] = pbr.pbr("tank_shell", "#dfe4ea", metallic=1.0, roughness=0.1)
    m["dump_bed"] = pbr.pbr("dump_bed", "#b8bfc7", metallic=0.6, roughness=0.28)
    return m


def mural_material(truck_id, out_dir):
    """Mural do baú rosa: a arte nossa (lib/tex_mural_t218.py). No .glb vai uma miniatura (o jogo carrega o PNG)."""
    from lib import tex_mural_t218 as TM
    paths = TM.ensure(os.path.join(out_dir, MURAL_DIR))
    img = bpy.data.images.load(paths["albedo"], check_existing=False)
    img.name = "tex_mural"
    img.colorspace_settings.name = "sRGB"
    return pbr.textured("mural", img, 0.15, 0.35, coat=0.6, coat_rough=0.05)


def build(truck_id, m, out_dir):
    style, _paint = TRUCKS[truck_id]
    parts = []

    def add(o):
        parts.append(o)
        return o
    build_chassis(m, add, REAR_AXLES, tanks=True)
    cab = C.build_cab(m, add, style)
    if truck_id == "pinkbox":
        info = B.build_pinkbox(m, add, mural_material(truck_id, out_dir))
    else:
        info = B.BUILDERS[truck_id](m, add)
    if info.get("drop_stacks"):                   # baú de alumínio liso: sem escapamentos altos (como a referência)
        for o in [o for o in parts if o.name.startswith("stack_")]:
            parts.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
    if info.get("stack_guards"):
        B.stack_guards(m, add)
    cab_front = (C.yf(cab.wz0), cab.wz0, cab.surf)
    if info["deco"] == "full":
        build_deco(m, add, B.L, cab.top, cab_front, box=info["box"], mural_plates=False)
    else:
        cab_brow(m, add, cab_front)
    wheels = []
    for sx in (-1, 1):
        side = "L" if sx < 0 else "R"
        for y in REAR_AXLES:
            for tx in (0.72, 1.06):
                wheels.append(make_wheel(f"wheel_r_{side}_{y}_{tx}", (sx * tx, y, WHEEL_R), m, rim=(tx > 1.0), seg=36))
        wheels.append(make_wheel(f"wheel_f_{side}", (sx * 1.0, cab.front_axle, cab.front_r), m, rim=True, radius=cab.front_r))
    mounts = dict(MOUNTS)
    mounts.update(cab.mounts)
    mounts.update(info["mounts"])
    empties = [M.empty(n, p) for n, p in sorted(mounts.items())]
    print(f"{truck_id}: cabine {style} {cab.tris} triangulos; carga ate {info['top']:.2f} m")
    return parts, wheels, empties


def _uv(objs):
    for o in objs:
        name = o.active_material.name if o.active_material else ""
        if name in ("paint_white_panel", "plastic_trim"):
            M.uv_height(o)
        elif name == "diamond":
            M.uv_world(o, 0.45)
        elif name in ("mesh_perf", "mesh_perf_vent", "mesh_perf_grille", "vent_slots") and not o.get("has_uv"):
            M.uv_planar(o)


def _diag(o):
    xs = [v.co for v in o.data.vertices]
    if not xs:
        return 0.0
    lo = [min(c[i] for c in xs) for i in range(3)]
    hi = [max(c[i] for c in xs) for i in range(3)]
    return sum((hi[i] - lo[i]) ** 2 for i in range(3)) ** 0.5


def _clone(objs):
    out = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


def _lod_pick(parts, wheels, level):
    """Peças que entram no LOD: o que é grande o bastante para aparecer de longe; luzes ficam (noite)."""
    keep = []
    min_d = 0.3 if level == 1 else 1.0
    lamp_d = 0.0 if level == 1 else 0.15
    for o in parts:
        mat = o.active_material.name if o.active_material else ""
        d = _diag(o)
        if mat.startswith(("lamp_", "andon")):
            if d >= lamp_d:
                keep.append(o)
        elif d >= min_d:
            keep.append(o)
    for ws in wheels:
        keep.append(ws[0])                      # pneu
        if level == 1 and len(ws) > 1:
            keep.append(ws[1])                  # aro / disco
    return keep


def _reduce(o, ratio):
    """Reduz sem derreter: dissolve planar (2°) e depois colapso só se ainda passar do alvo."""
    target = max(12, int(M.count_tris([o]) * ratio))
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=0.035, verts=bm.verts[:], edges=bm.edges[:], delimit={"MATERIAL"})
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(o.data)
    bm.free()
    tris = M.count_tris([o])
    if tris > target:
        mod = o.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(0.02, target / tris)
        mod.use_collapse_triangulate = True
        mod.use_symmetry = True
        mod.symmetry_axis = "X"
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)


def _sharp_by_angle(o, angle):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = not (len(e.link_faces) != 2 or e.calc_face_angle(0.0) > angle)
    bm.to_mesh(o.data)
    bm.free()


def _export(path, objs, root_name, out_dir):
    root = bpy.data.objects.new(root_name, None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    final = [root] + objs
    mats = {sl.material for o in final if o.type == "MESH" for sl in o.material_slots if sl.material}
    swaps = shared_tex.externalize(sorted(mats, key=lambda mt: mt.name), os.path.join(out_dir, "textures"))
    _shrink_mural(mats)
    M.export_glb(path, final)
    shared_tex.restore(swaps)
    _restore_mural(mats)
    return final


_MURAL_FULL = {}


def _shrink_mural(mats):
    """O mural do baú rosa vai como miniatura no .glb (o TruckNode carrega o PNG grande do modelo)."""
    for mt in mats:
        if mt.name != "mural" or not mt.node_tree:
            continue
        for node in mt.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None and node.image.size[0] > 256:
                full = node.image
                mini = full.copy()
                mini.scale(256, 64)
                mini.pack()
                _MURAL_FULL[mini.name] = full
                node.image = mini


def _restore_mural(mats):
    for mt in mats:
        if mt.name != "mural" or not mt.node_tree:
            continue
        for node in mt.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None and node.image.name in _MURAL_FULL:
                node.image = _MURAL_FULL.pop(node.image.name)


def _join_wheels(wheels):
    out = []
    for ws in wheels:
        bpy.ops.object.select_all(action="DESELECT")
        for o in ws:
            o.select_set(True)
        bpy.context.view_layer.objects.active = ws[0]
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        base = o.name.replace("_tire", "")
        o.name = base
        o.data.name = base
        out.append(o)
    return out


def _set_preview_paint(hex_color, on=True):
    """Prévias: a pintura da cabine na cor de fábrica do modelo (no .glb fica a de sempre; o jogo tinge)."""
    from lib.palette import hex_to_rgb, lin
    mt = bpy.data.materials.get("paint_white_panel")
    for node in mt.node_tree.nodes:
        if node.type == "MIX" and getattr(node, "data_type", "") == "RGBA":
            node.inputs[7].default_value = lin(hex_to_rgb(hex_color if on else "#d6dce6")) + (1.0,)


def make_one(truck_id, args, out_dir):
    scene.reset_scene()
    m = materials(out_dir)
    parts, wheels, empties = build(truck_id, m, out_dir)
    _uv(parts)
    lods = {}
    for level in (1, 2):
        picked = _lod_pick(parts, [ws for ws in wheels], level)
        lods[level] = _clone(picked)
    all_meshes = parts + [w for ws in wheels for w in ws]
    M.smooth(all_meshes, 35.0)
    tris0 = M.count_tris(all_meshes)
    merged = M.join_by_material(parts, prefix="truck_")
    wheel_objs = _join_wheels(wheels)
    glb = os.path.join(out_dir, "truck", f"dekotora_truck_{truck_id}.glb")
    lod0 = _export(glb, merged + wheel_objs + empties, "DekotoraTruckBase", out_dir)
    report = {"lod0": tris0}
    lod_objs = {}
    for level in (1, 2):
        objs = lods[level]
        joined = M.join_by_material(objs, prefix=f"lod{level}_")
        ratio = (LOD1_RATIO if level == 1 else LOD2_RATIO) * tris0 / max(1, M.count_tris(joined))
        if ratio < 1.0:
            for o in joined:
                _reduce(o, ratio)
        for o in joined:                              # liso, com quina viva acima de 35 graus (sem manchas, poucos vértices)
            _sharp_by_angle(o, 0.61)
        report[f"lod{level}"] = M.count_tris(joined)
        path = os.path.join(out_dir, "truck", "lod", f"dekotora_truck_{truck_id}_lod{level}.glb")
        _export(path, joined, f"LOD{level}", out_dir)
        lod_objs[level] = joined
    sizes = {k: os.path.getsize(p) for k, p in (("lod0", glb),
             ("lod1", os.path.join(out_dir, "truck", "lod", f"dekotora_truck_{truck_id}_lod1.glb")),
             ("lod2", os.path.join(out_dir, "truck", "lod", f"dekotora_truck_{truck_id}_lod2.glb")))}
    print(f"[t218] {truck_id}: triangulos LOD0 {report['lod0']} LOD1 {report['lod1']} LOD2 {report['lod2']} | "
          f"bytes {sizes['lod0']} {sizes['lod1']} {sizes['lod2']}")
    os.makedirs(os.path.join(out_dir, "source_blend"), exist_ok=True)
    if args.preview:
        _previews(truck_id, args, merged + wheel_objs, lod_objs)
    return report, sizes


VIEWS = {"frente": (0, 6, 21.0, (0, 6.0, 1.7)), "lateral": (90, 3, 21.0, (0, 6.0, 1.7)),
         "traseira": (180, 7, 21.0, (0, 6.0, 1.7)), "34": (38, 13, 22.0, (0, 6.0, 1.6)),
         "cab34": (32, 9, 8.5, (0, 10.4, 1.8)), "cabfrente": (0, 4, 7.0, (0, 11.0, 1.8)),
         "traseira34": (150, 12, 12.0, (0, 1.5, 1.8)), "ladoperto": (90, 2, 7.0, (0, 4.6, 1.8))}


def _render(prefix, objs, **kw):
    """preview.render_views cria chão, luzes e câmera a cada chamada: apaga o que ela criou."""
    before = set(bpy.data.objects)
    preview.render_views(prefix, objs, **kw)
    for o in list(bpy.data.objects):
        if o not in before:
            bpy.data.objects.remove(o, do_unlink=True)


def _hide(objs, hide):
    for o in objs:
        o.hide_render = hide


def _previews(truck_id, args, lod0, lod_objs):
    pdir = args.preview
    _set_preview_paint(TRUCKS[truck_id][1])
    _hide(lod_objs[1] + lod_objs[2], True)
    times = ["dia", "noite"] if args.night else ["dia"]
    for t in times:
        prefix = os.path.join(pdir, f"{truck_id}_{t}")
        _render(prefix, lod0, size=(960, 540), night=(t == "noite"), views=VIEWS)
        preview.contact_sheet([f"{prefix}_{v}.png" for v in ("frente", "lateral", "traseira", "34", "cab34", "traseira34")],
                              os.path.join(pdir, f"folha_{truck_id}_{t}.png"), cols=3)
    # os 3 LODs no mesmo ângulo (conferência do custo x forma)
    shots = []
    for level, objs in ((0, lod0), (1, lod_objs[1]), (2, lod_objs[2])):
        _hide(lod0 + lod_objs[1] + lod_objs[2], True)
        _hide(objs, False)
        prefix = os.path.join(pdir, f"{truck_id}_lod{level}")
        _render(prefix, objs, size=(640, 360), views={"34": VIEWS["34"]})
        shots.append(prefix + "_34.png")
    preview.contact_sheet(shots, os.path.join(pdir, f"folha_{truck_id}_lods.png"), cols=3)
    _hide(lod0, False)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=",".join(TRUCKS))
    ap.add_argument("--out", default="game/assets/vehicles/dekotora")
    ap.add_argument("--preview", default="")
    ap.add_argument("--night", action="store_true")
    args = ap.parse_args(argv)
    out_dir = os.path.abspath(args.out)
    if args.preview:
        args.preview = os.path.abspath(args.preview)
        os.makedirs(args.preview, exist_ok=True)
    for tid in [s for s in args.only.split(",") if s]:
        if tid not in TRUCKS:
            raise SystemExit(f"ERRO: caminhao desconhecido: {tid} (use {', '.join(TRUCKS)})")
        make_one(tid, args, out_dir)
    print("OK build_t218_trucks")


if __name__ == "__main__":
    main()
