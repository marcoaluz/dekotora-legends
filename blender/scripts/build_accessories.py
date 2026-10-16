"""Gera a biblioteca de acessórios Dekotora 3D: .glb por peça, .blend editável, prévias e catálogo.

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_accessories.py -- --prototypes
  blender -b --factory-startup -P blender/scripts/build_accessories.py -- --all
  blender -b --factory-startup -P blender/scripts/build_accessories.py -- --only fb_ornate_steps,step_metal
  blender -b --factory-startup -P blender/scripts/build_accessories.py -- --assembled   (prévias montadas)

Saída (dentro de game/, pasta do projeto Godot):
  assets/vehicles/dekotora/accessories/<categoria>/<id>.glb     modelo do jogo (materiais embutidos)
  assets/vehicles/dekotora/source_blend/accessories/<categoria>/<id>.blend   fonte editável
  assets/vehicles/dekotora/previews/<id>_34.png (+ assembled_<categoria>_*.png)
  assets/vehicles/dekotora/catalog.json
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import accessories as ACC  # noqa: E402
import build_truck_3d as T3  # noqa: E402
from lib import mesh3d as M, pbr, preview, scene  # noqa: E402

PROTOTYPES = ["fb_ornate_steps", "roof_light_bracket", "skirt_chrome_panel"]
MAX_TRIS = {"front": 4500, "lighting": 4500, "sides": 4500, "rear": 4500}   # orçamento por peça

# Caixas proibidas do caminhão (Blender, metros): (min, max). Penetração aceita = encaixe/fixação.
KEEPOUT = {
    "body": ((-1.25, 0.0, 1.1), (1.25, 8.2, 3.2)),
    "cab": ((-1.2, 8.45, 0.9), (1.2, 11.5, 3.35)),
    "windshield": ((-1.06, 11.3, 2.05), (1.06, 11.5, 3.2)),
    "wheel_front_r": ((0.84, 9.7, 0.0), (1.16, 10.7, 1.0)),
    "wheel_front_l": ((-1.16, 9.7, 0.0), (-0.84, 10.7, 1.0)),
    "wheel_rear_r": ((0.57, 0.98, 0.0), (1.21, 3.52, 1.04)),
    "wheel_rear_l": ((-1.21, 0.98, 0.0), (-0.57, 3.52, 1.04)),
}
ALLOWED_PENETRATION = 0.12       # m: o quanto uma peça pode "entrar" na pintura (fixação)


def log(*a):
    print("[acessorios]", *a)


def to_godot(v):
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def check_keepout(mn: Vector, mx: Vector, mount, mirrored: bool) -> list:
    """Compara as caixas da peça (já na posição do ponto de montagem) com as do caminhão."""
    sign = -1 if mirrored else 1
    ox, oy, oz = mount
    ax0 = min(sign * mn.x, sign * mx.x) + ox
    ax1 = max(sign * mn.x, sign * mx.x) + ox
    ay0, ay1 = mn.y + oy, mx.y + oy
    az0, az1 = mn.z + oz, mx.z + oz
    problems = []
    for name, (k0, k1) in KEEPOUT.items():
        dx = min(ax1, k1[0]) - max(ax0, k0[0])
        dy = min(ay1, k1[1]) - max(ay0, k0[1])
        dz = min(az1, k1[2]) - max(az0, k0[2])
        if dx > 0 and dy > 0 and dz > 0:
            depth = min(dx, dy, dz)
            if depth > ALLOWED_PENETRATION:
                problems.append(f"{name}: penetra {depth:.2f} m")
    return problems


def build_one(acc: dict, out: str, previews: bool = True) -> dict:
    scene.reset_scene()
    m = pbr.standard_set()
    objs = acc["build"](m)
    M.apply_transforms(objs)
    M.smooth(objs, 35.0)
    tris = M.count_tris(objs)
    editable = lambda o: o.name.startswith(("SIGN_", "PLATE_"))      # noqa: E731
    merged = M.join_by_material(objs, prefix="", keep=editable)
    root = bpy.data.objects.new(acc["id"], None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged:
        o.parent = root
    mats = sorted({s.material.name for o in merged for s in o.material_slots if s.material})
    mn, mx = M.bounds(merged)
    size = mx - mn
    glb_rel = f"accessories/{acc['category']}/{acc['id']}.glb"
    M.export_glb(os.path.join(out, glb_rel), [root] + merged)
    blend_rel = f"source_blend/accessories/{acc['category']}/{acc['id']}.blend"
    os.makedirs(os.path.dirname(os.path.join(out, blend_rel)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, blend_rel))
    mount = T3.MOUNTS[acc["mount"]]
    problems = check_keepout(mn, mx, mount, mirrored=mount[0] < 0)
    if tris > MAX_TRIS[acc["category"]]:
        problems.append(f"orçamento de triângulos excedido: {tris}")
    prev_rel = ""
    if previews:
        ctr = (mn + mx) / 2
        dist = max(size.length * 1.7, 1.2)
        prev_rel = f"previews/{acc['id']}_34.png"
        preview.render_views(os.path.join(out, "previews", acc["id"]), merged, size=(640, 480),
                             center=tuple(ctr), views={"34": (200, 18) if acc["category"] == "rear" or "REAR" in acc["mount"] else (35, 18)},
                             dist=dist, lens=55.0)
    entry = {
        "id": acc["id"],
        "name": acc["name"],
        "category": acc["category"],
        "model": "res://assets/vehicles/dekotora/" + glb_rel,
        "mount_point": acc["mount"],
        "mount_point_left": acc["mount"][:-1] + "L" if acc["mirror"] else None,
        "mirror_for_left": bool(acc["mirror"]),
        "dimensions_m": {"x": round(size.x, 3), "y": round(size.z, 3), "z": round(size.y, 3)},
        "triangles": tris,
        "compatibility": ["dekotora_truck_base"],
        "materials_used": mats,
        "materials_available": acc["materials"],
        "customizable": acc.get("customizable"),
        "source_blend": "res://assets/vehicles/dekotora/" + blend_rel,
        "preview": ("res://assets/vehicles/dekotora/" + prev_rel) if prev_rel else "",
        "license": "original (gerado por script; sem texturas externas)",
        "fit_warnings": problems,
    }
    log(f"{acc['id']:26s} tris={tris:5d} dims=({size.x:.2f},{size.z:.2f},{size.y:.2f}) {'AVISO: ' + '; '.join(problems) if problems else 'ok'}")
    return entry


def write_catalog(out: str, entries: list) -> None:
    path = os.path.join(out, "catalog.json")
    old = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            old = {e["id"]: e for e in json.load(f).get("accessories", [])}
    for e in entries:
        old[e["id"]] = e
    order = {a["id"]: i for i, a in enumerate(ACC.ALL)}
    items = sorted(old.values(), key=lambda e: order.get(e["id"], 999))
    mounts = {k: to_godot(v) for k, v in T3.MOUNTS.items()}
    data = {
        "version": 1,
        "units": "metros",
        "godot_forward": "-Z",
        "truck": {"id": "dekotora_truck_base", "model": "res://assets/vehicles/dekotora/truck/dekotora_truck_base.glb",
                  "mount_points_godot_xyz": mounts},
        "categories": {"front": "Frente", "lighting": "Teto e iluminação", "sides": "Laterais e rodas", "rear": "Traseira e decoração"},
        "accessories": items,
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    log("catálogo:", path, f"({len(items)} peças)")


def assembled_previews(out: str, categories) -> None:
    """Caminhão com todas as peças de cada categoria montadas nos pontos de encaixe (revisão visual)."""
    for cat in categories:
        scene.reset_scene()
        m = pbr.standard_set()
        parts, wheels, empties = T3.build_truck(m)
        all_objs = parts + [w for ws in wheels for w in ws]
        for acc in [a for a in ACC.ALL if a["category"] == cat]:
            for side in ((1, -1) if acc["mirror"] else (1,)):
                objs = acc["build"](m)
                M.apply_transforms(objs)
                if side == -1:
                    M.mirror_x(objs)
                mount = T3.MOUNTS[acc["mount"][:-1] + ("L" if side == -1 else "R")] if acc["mirror"] else T3.MOUNTS[acc["mount"]]
                for o in objs:
                    o.location = Vector(mount)
                all_objs += objs
        M.smooth(all_objs, 35.0)
        views = {"front": (10, 8), "rear": (180, 8), "side": (80, 6), "34": (35, 16)}
        preview.render_views(os.path.join(out, "previews", f"assembled_{cat}"), all_objs, size=(960, 540), views=views)
        log("montado:", cat)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/vehicles/dekotora")
    ap.add_argument("--only", default="")
    ap.add_argument("--category", default="")
    ap.add_argument("--prototypes", action="store_true")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--assembled", action="store_true")
    ap.add_argument("--no-preview", action="store_true")
    args = ap.parse_args(argv)
    out = os.path.abspath(args.out)
    if args.assembled:
        cats = [args.category] if args.category else list(ACC.CATEGORIES)
        assembled_previews(out, cats)
        return
    if args.prototypes:
        todo = [ACC.BY_ID[i] for i in PROTOTYPES]
    elif args.only:
        todo = [ACC.BY_ID[i] for i in args.only.split(",")]
    elif args.category:
        todo = [a for a in ACC.ALL if a["category"] == args.category]
    else:
        todo = ACC.ALL
    entries = [build_one(a, out, previews=not args.no_preview) for a in todo]
    write_catalog(out, entries)
    bad = [e["id"] for e in entries if e["fit_warnings"]]
    log("OK build_accessories:", len(entries), "peças;", "com avisos:" if bad else "sem avisos", ", ".join(bad))


main()
