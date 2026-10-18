"""Caminhão base 3D (PBR) para o Godot: cabine cab-over arredondada (referência Volvo FH) + baú, ~12 x 2,5 x 3,4 m.

Uso: blender -b --factory-startup -P blender/scripts/build_truck_3d.py -- [--out game/assets/vehicles/dekotora] [--variant base|leve|longo|carreta] [--cab padrao|classica|aero|alta]
Saída: <out>/truck/dekotora_truck_base.glb, <out>/source_blend/truck_base.blend, <out>/previews/truck_base_*.png

Convenções: metros, +Y frente, Z cima, traseira do baú em Y=0, X=0 no centro. As peças usam os pontos
de montagem (empties MOUNT_*) criados aqui; o glTF os exporta como nós.
O código fica em `truck3d/` (dims, cab, chassis, body, wheels).
"""
import argparse
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, pbr, preview, scene, shared_tex  # noqa: E402
from truck3d.body import build_body  # noqa: E402
from truck3d.cab import CAB_STYLES, build_cab, cab_mounts  # noqa: E402
from truck3d.chassis import build_chassis  # noqa: E402
from truck3d.deco import build_deco  # noqa: E402
from truck3d.cab import STYLES  # noqa: E402
from truck3d.dims import (BODY_L, BODY_TOP, BODY_W, BODY_Z0, CAB_TOP, CAB_W, CAB_Y0, CAB_Y1,  # noqa: E402,F401
                          CAB_Z0, FRONT_AXLE_Y, MOUNTS, REAR_AXLES_Y, WHEEL_R)
from truck3d.variants import LENGTH_DELTA, VARIANTS, apply_variant
from truck3d.wheels import make_wheel, tire_profile  # noqa: E402


def build_truck(m: dict, paint_name: str = "paint_white", variant: str = "base", cab: str = "padrao"):
    """Devolve (meshes_estaticas, rodas, empties). `m` = dicionário de materiais (pbr.standard_set)."""
    if paint_name != "paint_white":
        m = dict(m)
        m["paint_white"] = m[paint_name]
    parts = []
    wheels = []

    def add(o):
        parts.append(o)
        return o

    spec = VARIANTS[variant]
    build_chassis(m, add, spec["rear_axles"], spec["tanks"])
    build_body(m, add)
    sh = build_cab(m, add, cab)
    for sx in (-1, 1):
        side = "L" if sx < 0 else "R"
        for y in spec["rear_axles"]:
            for tx in (0.72, 1.06):
                wheels.append(make_wheel(f"wheel_r_{side}_{y}_{tx}", (sx * tx, y, WHEEL_R), m, rim=(tx > 1.0), seg=spec["seg"]))
        wheels.append(make_wheel(f"wheel_f_{side}", (sx * 1.0, FRONT_AXLE_Y, 0.5), m, rim=True, radius=0.5))
    mounts = dict(MOUNTS)
    mounts.update(cab_mounts(cab))                 # teto/para-brisa mudam com a cabine
    empties = [M.empty(n, p) for n, p in mounts.items()]
    apply_variant(variant, m, parts, wheels, empties)
    if variant != "carreta":                        # decoracao Dekotora (V7): luzes, andons, murais
        body_l = BODY_L + VARIANTS[variant]["delta"]
        cab_z = STYLES[cab]["top"]                   # altura real da cabine (com defletor de teto, se houver)
        for o in parts:
            mw = o.matrix_world
            for v in o.data.vertices:
                w = mw @ v.co
                if w.y > body_l + 0.3 and w.z > cab_z:
                    cab_z = w.z
        dy = VARIANTS[variant]["delta"]

        def surf(x, z):                                # ponto/normal na casca curva (luzes da "sobrancelha")
            q = sh.q_from_x(x, z)
            p = sh.ev(q, z)
            p.y += dy
            return p, sh.normal(q, z)
        build_deco(m, add, body_l, cab_z, (CAB_Y1 + dy, STYLES[cab]["wz0"], surf))
    return parts, wheels, empties


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/vehicles/dekotora")
    ap.add_argument("--paint", default="paint_white")
    ap.add_argument("--cab", default="padrao", choices=list(CAB_STYLES), help="padrao | classica | aero | alta")
    ap.add_argument("--no-preview", action="store_true")
    ap.add_argument("--night", action="store_true", help="previas de revisao a noite (luzes acesas)")
    ap.add_argument("--variant", default="base", choices=list(VARIANTS), help="base | leve | longo | carreta")
    args = ap.parse_args(argv)
    out = os.path.abspath(args.out)
    scene.reset_scene()
    m = pbr.truck_set(pbr.standard_set())
    m["rubber_tire"] = pbr.tire_material(tire_profile(WHEEL_R, 0.3), WHEEL_R)
    parts, wheels, empties = build_truck(m, args.paint, args.variant, args.cab)
    for o in parts:                                  # texturas precisam de UV que cubra cada face
        name = o.active_material.name if o.active_material else ""
        if name in ("paint_white_panel", "plastic_trim"):
            M.uv_height(o)                           # sujeira por altura (lib/tex_truck.py)
        elif name == "diamond":
            M.uv_world(o, 0.45)
        elif name in ("mesh_perf", "mesh_perf_vent", "mesh_perf_grille") and not o.get("has_uv"):
            M.uv_planar(o)
    all_meshes = parts + [w for ws in wheels for w in ws]
    M.smooth(all_meshes, 35.0)
    tris = M.count_tris(all_meshes)
    # junta por material (poucos draw calls); cada roda vira um objeto para poder girar
    merged = M.join_by_material(parts, prefix="truck_")
    wheel_objs = []
    for ws in wheels:
        bpy.ops.object.select_all(action="DESELECT")
        for o in ws:
            o.select_set(True)
        bpy.context.view_layer.objects.active = ws[0]
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        base = o.name.replace("_tire", "")      # a origem já é o centro do pneu (eixo X)
        o.name = base
        o.data.name = base
        wheel_objs.append(o)
    root = bpy.data.objects.new("DekotoraTruckBase", None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged + wheel_objs + empties:
        o.parent = root
    final = [root] + merged + wheel_objs + empties
    print(f"triangulos: {tris}  objetos: {len(final)}  materiais: {len(bpy.data.materials)}")
    tag = args.variant if args.cab == "padrao" else f"{args.variant}_{args.cab}"
    glb = os.path.join(out, "truck", f"dekotora_truck_{tag}.glb")
    mural_png = os.path.join(out, "murals", "mural_side.png")      # arte trocavel do mural (nunca sobrescreve)
    if not os.path.exists(mural_png):
        from lib import tex
        tex.save_png(tex.mural_geometric()[::-1], mural_png)
    # texturas grandes: uma cópia só em <out>/textures (o TruckNode aplica no jogo); o .glb leva miniaturas 4x4
    mats = {sl.material for o in final if o.type == "MESH" for sl in o.material_slots if sl.material}
    swaps = shared_tex.externalize(sorted(mats, key=lambda mt: mt.name), os.path.join(out, "textures"))
    M.export_glb(glb, final)
    shared_tex.restore(swaps)
    os.makedirs(os.path.join(out, "source_blend"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "source_blend", f"truck_{tag}.blend"))
    if args.no_preview:
        print("OK build_truck_3d ->", glb)
        return
    d = LENGTH_DELTA[args.variant]
    pdir = os.path.join(out, "previews")
    preview.render_views(os.path.join(pdir, f"truck_{tag}" + ("_night" if args.night else "")), merged + wheel_objs, size=(960, 540), night=args.night,
                         views={"34": (35, 14, 22.0 + d * 1.1, (0, 6.0 + d / 2, 1.6)), "rear": (180, 8, 22.0 + d, (0, 6.0 + d / 2, 1.6)),
                                "side": (90, 4, 22.0 + d * 1.1, (0, 6.0 + d / 2, 1.6)), "front": (0, 10, 22.0 + d, (0, 6.0 + d / 2, 1.6)),
                                "cab34": (38, 10, 9.0, (0, 10.0 + d, 1.8)), "cabside": (90, 3, 9.0, (0, 10.0 + d, 1.8)),
                                "wheel": (55, 6, 3.2, (1.0, 10.2 + d, 0.5)), "grille": (15, 8, 3.5, (0, 11.5 + d, 1.1)),
                                "cabfront": (8, 6, 7.5, (0, 11.0 + d, 1.9)), "cabrear34": (140, 14, 9.0, (0, 9.5 + d, 2.0)),
                                "door": (75, 4, 4.2, (1.2, 10.0 + d, 1.8))})
    pre = os.path.join(pdir, f"truck_{tag}" + ("_night" if args.night else ""))
    preview.contact_sheet([f"{pre}_{v}.png" for v in ("cabfront", "cab34", "cabside", "34", "front", "side", "cabrear34", "door", "grille")],
                          f"{pre}_sheet.png", cols=3)
    print("OK build_truck_3d ->", glb)


if __name__ == "__main__":
    main()
