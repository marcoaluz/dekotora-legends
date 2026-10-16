"""Caminhão base 3D (PBR) para o Godot: cabine cab-over arredondada (referência Volvo FH) + baú, ~12 x 2,5 x 3,4 m.

Uso: blender -b --factory-startup -P blender/scripts/build_truck_3d.py -- [--out game/assets/vehicles/dekotora] [--variant base|leve|longo|carreta]
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
from lib import mesh3d as M, pbr, preview, scene  # noqa: E402
from truck3d.body import build_body  # noqa: E402
from truck3d.cab import build_cab  # noqa: E402
from truck3d.chassis import build_chassis  # noqa: E402
from truck3d.dims import (BODY_L, BODY_TOP, BODY_W, BODY_Z0, CAB_TOP, CAB_W, CAB_Y0, CAB_Y1,  # noqa: E402,F401
                          CAB_Z0, FRONT_AXLE_Y, MOUNTS, REAR_AXLES_Y, WHEEL_R)
from truck3d.variants import LENGTH_DELTA, VARIANTS, apply_variant
from truck3d.wheels import make_wheel  # noqa: E402


def build_truck(m: dict, paint_name: str = "paint_white", variant: str = "base"):
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
    build_cab(m, add)
    for sx in (-1, 1):
        side = "L" if sx < 0 else "R"
        for y in spec["rear_axles"]:
            for tx in (0.72, 1.06):
                wheels.append(make_wheel(f"wheel_r_{side}_{y}_{tx}", (sx * tx, y, WHEEL_R), m, rim=(tx > 1.0), seg=spec["seg"]))
        wheels.append(make_wheel(f"wheel_f_{side}", (sx * 1.0, FRONT_AXLE_Y, 0.5), m, rim=True, radius=0.5))
    empties = [M.empty(n, p) for n, p in MOUNTS.items()]
    apply_variant(variant, m, parts, wheels, empties)
    return parts, wheels, empties


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/vehicles/dekotora")
    ap.add_argument("--paint", default="paint_white")
    ap.add_argument("--variant", default="base", choices=list(VARIANTS), help="base | leve | longo | carreta")
    args = ap.parse_args(argv)
    out = os.path.abspath(args.out)
    scene.reset_scene()
    m = pbr.standard_set()
    parts, wheels, empties = build_truck(m, args.paint, args.variant)
    for o in parts:                                  # texturas precisam de UV que cubra cada face
        if o.active_material and o.active_material.name in ("mesh_perf", "mesh_perf_vent", "diamond"):
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
    tag = args.variant
    glb = os.path.join(out, "truck", f"dekotora_truck_{tag}.glb")
    M.export_glb(glb, final)
    os.makedirs(os.path.join(out, "source_blend"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "source_blend", f"truck_{tag}.blend"))
    d = LENGTH_DELTA[args.variant]
    pdir = os.path.join(out, "previews")
    preview.render_views(os.path.join(pdir, f"truck_{tag}"), merged + wheel_objs, size=(960, 540),
                         views={"34": (35, 14, 22.0 + d * 1.1, (0, 6.0 + d / 2, 1.6)), "rear": (180, 8, 22.0 + d, (0, 6.0 + d / 2, 1.6)),
                                "side": (90, 4, 22.0 + d * 1.1, (0, 6.0 + d / 2, 1.6)), "front": (0, 10, 22.0 + d, (0, 6.0 + d / 2, 1.6)),
                                "cab34": (38, 10, 9.0, (0, 10.0 + d, 1.8)), "cabside": (90, 3, 9.0, (0, 10.0 + d, 1.8)),
                                "wheel": (55, 6, 3.2, (1.0, 10.2 + d, 0.5)), "grille": (15, 8, 3.5, (0, 11.5 + d, 1.1))})
    print("OK build_truck_3d ->", glb)


if __name__ == "__main__":
    main()
