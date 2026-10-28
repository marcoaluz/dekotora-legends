"""Peças da oficina, lote 5 (T-234): as lacunas da seção 19 de docs/REFERENCIA_PECAS.md, pelas propostas aprovadas
(folha docs/capturas_t211/proposta_lacunas.png): 3 calotas, 3 escapamentos, 3 grades, 3 buzinas, 3 interiores e os
adesivos novos (as 9 frases na fonte Yuji, labaredas e sol nascente).

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t234_parts.py -- [--only id1,id2] [--no-preview] [--no-art]

Gera (dentro de game/assets/vehicles/dekotora/, salvo os adesivos):
  accessories/{wheel,stack,grille,horn}_t234/<id>.glb   peças 3D ("style": "deco"; cor L/R pelos papéis da T-211)
  textures/deco_honey.png                               favos da grade de colmeia (repetidos pelo tamanho real)
  paint_t234/interior/<id>.png + _emit.png              arte do interior "vista pelo para-brisa" (render 3D nosso)
  game/assets/decals/<id>.png                           adesivos (branco + contorno: o jogo tinge pela cor escolhida)
  catalog.json, previews/t234_<id>_{day,night}.png, previews/t234_sheet_<tipo>.png
Determinístico. Encaixes: `build_sockets.py` (grade, buzina e interior medidos por raios em cada caminhão).
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from accessories import grille_horn_t234, t234_kit as Z, wheel_stack_t234  # noqa: E402
from lib import mesh3d as M, scene  # noqa: E402
import t214_textures  # noqa: E402

OUT = "game/assets/vehicles/dekotora"
ATLAS = OUT + "/textures/deck_signs.png"
MAX_TRIS = 4500
OUTER_WHEELS = 6            # rodas de fora num caminhão de 2 eixos atrás (calota em cada uma)
CATEGORY = {"wheel": "sides", "stack": "sides", "grille": "front", "horn": "lighting"}
LICENSE = "original (gerado por script; desenho nosso pelas propostas da T-211, nada copiado)"


def log(*a):
    print("[t234]", *a)


def export_glb(path, objs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False, export_image_format="NONE")


def build_one(p, m, rel):
    objs = [o for o in p["build"](m) if o.type == "MESH"]
    M.apply_transforms(objs)
    for o in objs:
        if not o.data.uv_layers:
            M.uv_world(o, tile=0.5)
    M.smooth(objs, 35.0)
    cen = [o for o in objs if o.name.startswith("CEN_")]
    rest = [o for o in objs if not o.name.startswith("CEN_")]
    merged = M.join_by_material(rest, prefix=p["id"] + "_") + (M.join_by_material(cen, prefix=f"{p['id']}_CEN_") if cen else [])
    root = bpy.data.objects.new(p["id"], None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged:
        o.parent = root
    mn, mx = M.bounds(merged)
    export_glb(os.path.join(OUT, rel), [root] + merged)
    mats = sorted({s.material.name for o in merged for s in o.material_slots if s.material})
    return root, merged, mx - mn, mn, mx, M.count_tris(merged), mats


def entry_for(p, rel, size, mn, mx, worst, mats, warn):
    e = {
        "id": p["id"], "name": p["name"], "category": CATEGORY[p["kind"]],
        "model": "res://assets/vehicles/dekotora/" + rel,
        "dimensions_m": {"x": round(size.x, 3), "y": round(size.z, 3), "z": round(size.y, 3)},
        "bounds_godot": [[round(mn.x, 3), round(mn.z, 3), round(-mx.y, 3)], [round(mx.x, 3), round(mx.z, 3), round(-mn.y, 3)]],
        "triangles": worst, "compatibility": ["todos (encaixe por caminhão: truck/sockets/*.json)"],
        "materials_used": mats, "materials_available": {}, "customizable": None,
        "preview": f"res://assets/vehicles/dekotora/previews/t234_{p['id']}_day.png",
        "license": LICENSE, "fit_warnings": warn, "tier": "oficina", "style": "deco", "fit": p["fit"],
        "nominal_w": round(p.get("nominal", [1.0])[0], 3), "default_color": p["default_color"], "has_sign": False,
        "sign_cell": -1, "captures": "proposta T-211 (seção 19)", "pods": 0, "stack": None,
        "broken_tilt": [0.0, 0.0] if p["kind"] == "wheel" else [2.0, 5.0],
    }
    if p["kind"] == "wheel":
        e.update({"mount_point": p["mount"], "mount_point_left": p["mount_left"], "mirror_for_left": True, "socket": "hubcaps",
                  "wheel_r": p["wheel_r"]})
    else:
        e.update({"mount_point": "SOCKET_" + p["socket"], "socket": p["socket"],
                  "mount_point_left": ("SOCKET_" + p["socket_left"]) if p.get("socket_left") else None,
                  "mirror_for_left": bool(p.get("socket_left"))})
        if p.get("socket_left"):
            e["socket_left"] = p["socket_left"]
    if "nominal" in p:
        e["nominal"] = [round(v, 3) for v in p["nominal"]]
    if "horn" in p:
        e["horn"] = p["horn"]
    return e


def build_all(todo):
    m = Z.materials(bpy.data.images.load(os.path.abspath(ATLAS)))
    built, entries = {}, []
    for mod in (wheel_stack_t234, grille_horn_t234):
        for p in mod.PARTS:
            if todo and p["id"] not in todo:
                continue
            rel = f"accessories/{p['folder']}/{p['id']}.glb"
            root, objs, size, mn, mx, tris, mats = build_one(p, m, rel)
            worst = tris * (OUTER_WHEELS if p["kind"] == "wheel" else 2 if p.get("socket_left") else 1)
            warn = [f"orçamento de triângulos excedido: {worst} > {MAX_TRIS}"] if worst > MAX_TRIS else []
            e = entry_for(p, rel, size, mn, mx, worst, mats, warn)
            built[p["id"]] = (root, objs, e, p["kind"])
            entries.append(e)
            log(f"{p['id']:20s} tris={tris:5d} pior caso={worst:5d} mats={len(mats)} tam=({size.x:.2f} x {size.z:.2f} x {size.y:.2f}) "
                + "; ".join(warn))
    return built, entries


def write_catalog(entries):
    path = os.path.join(OUT, "catalog.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    ids = [e["id"] for e in entries]
    data["accessories"] = [e for e in data["accessories"] if e["id"] not in ids] + entries
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    log("catálogo:", path, len(data["accessories"]), "peças")


def previews(built):
    from lib.part_preview import setup_render, set_night, shoot
    from lib import preview as P
    co, lights = setup_render()
    for b in built.values():
        for o in b[1]:
            o.hide_render = True
    sheets = {}
    view = {"wheel": (60, 8, 1.6), "stack": (60, 12, 4.4), "grille": (335, 10, 2.6), "horn": (35, 22, 1.6)}
    for pid, (root, objs, entry, kind) in built.items():
        for o in objs:
            o.hide_render = False
        mn, mx = M.bounds(objs)
        az, el, dist = view[kind]
        for tag, night in (("day", False), ("night", True)):
            set_night(lights, night)
            path = os.path.abspath(os.path.join(OUT, "previews", f"t234_{pid}_{tag}.png"))
            shoot(co, (mn + mx) / 2, az, el, dist, path)
            sheets.setdefault(kind, []).append(path)
        for o in objs:
            o.hide_render = True
    set_night(lights, False)
    for kind, paths in sheets.items():
        P.contact_sheet(paths, os.path.abspath(os.path.join(OUT, "previews", f"t234_sheet_{kind}.png")), cols=2)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--no-preview", action="store_true")
    ap.add_argument("--no-art", action="store_true", help="não refaz interiores nem adesivos")
    args = ap.parse_args(argv)
    if not os.path.exists(t214_textures.ALB):
        t214_textures.make()
    Z.honey_texture()
    scene.reset_scene()
    todo = [s for s in args.only.split(",") if s]
    built, entries = build_all(todo)
    if not args.no_art and (not todo or any(t.startswith(("interior_", "decal_")) for t in todo)):
        from lib import t234_decals, t234_interior
        entries += t234_interior.build_all(OUT)
        t234_decals.build_all("game/assets/decals")
        scene.reset_scene()
    write_catalog(entries)
    if not args.no_preview and built:
        scene.reset_scene()
        built, _ = build_all(todo)
        previews(built)
    bad = [e["id"] for e in entries if e.get("fit_warnings")]
    log("OK build_t234_parts:", len(entries), "peças", ("; avisos: " + ", ".join(bad)) if bad else "")


main()
