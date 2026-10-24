"""Peças da oficina, lote 1 (T-211): 17 deques frontais e 14 viseiras.

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t211_parts.py -- [--only id1,id2] [--no-preview]
      [--compare PASTA_ABS] [--mounted PASTA_ABS] [--atlas]

Gera (dentro de game/assets/vehicles/dekotora/):
  accessories/deck/<id>.glb, accessories/visor/<id>.glb   modelos (sem textura embutida: o jogo põe o atlas)
  textures/deck_signs.png                                 atlas dos letreiros e painéis pintados (--atlas ou se faltar)
  catalog.json                                            entradas com "style": "deco", encaixe e escala
  previews/t211_<id>_{day,night}.png + previews/t211_sheet_{deck,visor}.png   (sem --no-preview)
--mounted PASTA: cada peça montada no caminhão padrão (cabine chata) no MESMO ângulo das capturas, dia e noite.
--compare PASTA: folhas "captura | nossa" lado a lado (as capturas são de terceiros: a pasta deve ficar fora do Git).
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from accessories import deck_t211, t211_kit as K, visor_t211  # noqa: E402
from lib import mesh3d as M, scene  # noqa: E402
import t211_atlas  # noqa: E402

OUT = "game/assets/vehicles/dekotora"
ATLAS = OUT + "/textures/deck_signs.png"
TRUCK = OUT + "/truck/dekotora_truck_base_chata.glb"
SOCKETS = OUT + "/truck/sockets/dekotora_truck_base_chata.json"
REF = "docs/Referencias/oficina/img"
MAX_TRIS = 4500
PARTS = deck_t211.PARTS + visor_t211.PARTS
# Ângulo das capturas (azimute°, elevação°, distância, alvo relativo ao encaixe em Blender) para comparar.
VIEW = {"andon": (-32, 12, 4.0, (0.0, 0.55, 0.42)), "visor": (0, 14, 3.1, (0.0, 0.25, -0.22))}


def log(*a):
    print("[t211]", *a)


def g2b(p):
    return Vector((p[0], -p[2], p[1]))


def export_glb(path, objs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False, export_image_format="NONE")


def build_parts(todo, m):
    """Constrói e exporta cada peça. Devolve {id: (raiz, objetos, entrada do catálogo)}."""
    built = {}
    for p in todo:
        objs = p["build"](m)
        M.apply_transforms(objs)
        M.smooth(objs, 35.0)
        tris = M.count_tris(objs)
        merged = M.join_by_material(objs, prefix=p["id"] + "_")
        root = bpy.data.objects.new(p["id"], None)
        bpy.context.scene.collection.objects.link(root)
        for o in merged:
            o.parent = root
        mn, mx = M.bounds(merged)
        size = mx - mn
        folder = "deck" if p["slot"] == "andon" else "visor"
        rel = f"accessories/{folder}/{p['id']}.glb"
        export_glb(os.path.join(OUT, rel), [root] + merged)
        mats = sorted({s.material.name for o in merged for s in o.material_slots if s.material})
        warn = [f"orçamento de triângulos excedido: {tris}"] if tris > MAX_TRIS else []
        entry = {
            "id": p["id"], "name": p["name"], "category": "lighting" if p["slot"] == "andon" else "front",
            "model": "res://assets/vehicles/dekotora/" + rel, "mount_point": "SOCKET_" + p["socket"], "mount_point_left": None,
            "mirror_for_left": False,
            "dimensions_m": {"x": round(size.x, 3), "y": round(size.z, 3), "z": round(size.y, 3)},
            "bounds_godot": [[round(mn.x, 3), round(mn.z, 3), round(-mx.y, 3)], [round(mx.x, 3), round(mx.z, 3), round(-mn.y, 3)]],
            "triangles": tris, "compatibility": ["todos (encaixe por caminhão: truck/sockets/*.json)"],
            "materials_used": mats, "materials_available": {}, "customizable": None,
            "preview": f"res://assets/vehicles/dekotora/previews/t211_{p['id']}_day.png",
            "license": "original (gerado por script; desenho nosso inspirado nas capturas da oficina, nada copiado)",
            "fit_warnings": warn, "tier": "oficina", "style": "deco", "socket": p["socket"], "fit": "uniform",
            "nominal_w": round(max(size.x, p["nominal_w"]), 3), "default_color": p["default_color"], "has_sign": p["has_sign"],
            "sign_cell": _sign_cell(p), "captures": p["captures"],
        }
        built[p["id"]] = (root, merged, entry)
        log(f"{p['id']:22s} tris={tris:5d} mats={len(mats)} tam=({size.x:.2f} x {size.z:.2f} x {size.y:.2f}) {'; '.join(warn)}")
        for o in merged:
            o.hide_render = True
    return built


def _sign_cell(p):
    """Célula do atlas usada pelo letreiro da peça (o jogo troca o nome deslocando a UV a partir dela)."""
    cells = {"deck_kanji_rail": 0, "deck_led_box": 1, "deck_art_band": 2, "deck_led_columns": 3, "deck_lace": 4,
             "deck_triple_sign": 5, "deck_eyebrow": 8, "deck_pillars": 9, "deck_cyan_frame": 10, "deck_painted_wings": 11}
    return cells.get(p["id"], -1)


def write_catalog(entries):
    path = os.path.join(OUT, "catalog.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    by = {e["id"]: e for e in data["accessories"]}
    for e in entries:
        by[e["id"]] = e
    old = [e for e in data["accessories"] if e["id"] not in {x["id"] for x in entries}]
    new_ids = [p["id"] for p in PARTS]
    news = sorted([by[i] for i in by if i in new_ids], key=lambda e: new_ids.index(e["id"]))
    data["accessories"] = old + news
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    log("catálogo:", path, len(data["accessories"]), "peças")


# ----------------------------------------------------------------------------- render

def setup_render(size=(640, 420)):
    from lib import preview as P
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.film_transparent = False
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.view_settings.view_transform = "Standard"
    P._setup_world()
    lights = [P._light("key", "AREA", (8, -10, 12), 4200, (1.0, 0.95, 0.9), 6),
              P._light("rim", "AREA", (-9, 14, 8), 3000, (0.55, 0.65, 1.0), 6),
              P._light("fill", "AREA", (-8, 18, 4), 1400, (0.8, 0.85, 1.0), 6)]
    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    return co, lights


def set_night(lights, night):
    k = 0.10 if night else 1.0
    for ob, e in zip(lights, (4200, 3000, 1400)):
        ob.data.energy = e * k
    bg = bpy.context.scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Strength"].default_value = 0.2 if night else 2.0


def shoot(co, center, az, el, dist, path, lens=50):
    co.data.lens = lens
    a, e = math.radians(az), math.radians(el)
    c = Vector(center)
    co.location = c + Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e))) * dist
    co.rotation_euler = (c - co.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def previews(built, co, lights):
    from lib import preview as P
    sheets = {"deck": [], "visor": []}
    for pid, (root, merged, entry) in built.items():
        for o in merged:
            o.hide_render = False
        mn, mx = M.bounds(merged)
        ctr = (mn + mx) / 2
        dist = max((mx - mn).length * 1.5, 1.6)
        kind = "deck" if entry["socket"] == "andon" else "visor"
        for tag, night in (("day", False), ("night", True)):
            set_night(lights, night)
            path = os.path.abspath(os.path.join(OUT, "previews", f"t211_{pid}_{tag}.png"))
            shoot(co, ctr, -36 if kind == "deck" else -20, 20 if kind == "deck" else 14, dist, path)
            sheets[kind].append(path)
        for o in merged:
            o.hide_render = True
    set_night(lights, False)
    for kind, paths in sheets.items():
        if paths:
            P.contact_sheet(paths, os.path.abspath(os.path.join(OUT, "previews", f"t211_sheet_{kind}.png")), cols=4)
    return sheets


def import_truck():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(TRUCK))
    return [o for o in bpy.data.objects if o not in before]


def mounted(built, co, lights, out_dir, compare_dir):
    """Peça no caminhão padrão, no ângulo das capturas; folha "captura | nossa" (só local) se pedida."""
    with open(SOCKETS, encoding="utf-8") as f:
        sk = json.load(f)["sockets"]
    truck = import_truck()
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for pid, (root, merged, entry) in built.items():
        s = sk[entry["socket"]]
        scale = max(0.85, min(1.15, s["width"] / entry["nominal_w"]))
        root.location = g2b(s["anchor"])
        root.scale = (scale, scale, scale)
        for o in merged:
            o.hide_render = False
        bpy.context.view_layer.update()
        az, el, dist, tgt = VIEW[entry["socket"]]
        center = root.location + Vector(tgt)
        shots = []
        for tag, night in (("dia", False), ("noite", True)):
            set_night(lights, night)
            path = os.path.abspath(os.path.join(out_dir, f"{pid}_{tag}.png"))
            shoot(co, center, az, el, dist, path, lens=40)
            shots.append(path)
        if compare_dir:
            first = entry["captures"].split("-")[0]
            ref = os.path.abspath(os.path.join(REF, f"{first}.png"))
            if os.path.exists(ref):
                pairs.append((pid, ref, shots[0]))
        for o in merged:
            o.hide_render = True
        root.location = (0, 0, 0)
        root.scale = (1, 1, 1)
    set_night(lights, False)
    if compare_dir and pairs:
        compare_sheets(pairs, compare_dir)


def _load_rgba(path, w, h):
    import numpy as np
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = "Non-Color"
    if tuple(im.size) != (w, h):
        im.scale(w, h)
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(im)
    return a


def compare_sheets(pairs, out_dir):
    """Uma folha por peça: captura (esquerda) | nossa no mesmo ângulo (direita). LOCAL: contém arte de terceiros."""
    import numpy as np
    os.makedirs(out_dir, exist_ok=True)
    for pid, ref, ours in pairs:
        a = _load_rgba(ref, 640, 420)
        b = _load_rgba(ours, 640, 420)
        sheet = np.concatenate([a, np.zeros((420, 8, 4), np.float32) + [0.05, 0.05, 0.05, 1], b], axis=1)[::-1]
        img = bpy.data.images.new(pid, sheet.shape[1], sheet.shape[0], alpha=False)
        img.colorspace_settings.name = "Non-Color"
        img.pixels.foreach_set(sheet.astype(np.float32).ravel())
        img.filepath_raw = os.path.join(out_dir, f"cmp_{pid}.png")
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
    log("comparações:", out_dir)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--no-preview", action="store_true")
    ap.add_argument("--atlas", action="store_true")
    ap.add_argument("--mounted", default="")
    ap.add_argument("--compare", default="")
    args = ap.parse_args(argv)
    if args.atlas or not os.path.exists(ATLAS):
        t211_atlas.make(os.path.abspath(ATLAS))
    scene.reset_scene()
    atlas = bpy.data.images.load(os.path.abspath(ATLAS))
    m = K.materials(atlas)
    todo = [p for p in PARTS if not args.only or p["id"] in args.only.split(",")]
    built = build_parts(todo, m)
    write_catalog([b[2] for b in built.values()])
    co, lights = setup_render()
    if not args.no_preview:
        previews(built, co, lights)
    if args.mounted:
        mounted(built, co, lights, args.mounted, args.compare)
    bad = [pid for pid, b in built.items() if b[2]["fit_warnings"]]
    log("OK build_t211_parts:", len(built), "peças", ("; avisos: " + ", ".join(bad)) if bad else "")


main()
