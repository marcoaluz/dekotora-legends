"""Para-choques GRANDES da frente (T-264, capturas 054–062): 5 peças com abas até a roda (accessories/front_t264.py).

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t264_parts.py -- [--only id1,id2] [--no-preview]

Gera (dentro de game/assets/vehicles/dekotora/):
  accessories/front_t264/<id>.glb    grupos TOP_/MID_/BOT_/CEN_ (completa) + LTOP_/LMID_/LBOT_/LCEN_ (LOD, de longe)
                                     + pontos SIGNAL_L/R; o jogo ajusta altura, largura das abas e comprimento
                                     (FrameFit + BumperWrap)
  catalog.json                       entradas "style": "deco" (encaixe, fit "bumper", vfit com `wrap`)
  previews/t264_<id>_{day,night}.png + previews/t264_sheet_front.png   (sem --no-preview)
Determinístico. Encaixes (abas medidas por raios): `build_sockets.py`.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from accessories import front_t264, t233_kit as Q  # noqa: E402
from lib import mesh3d as M, scene  # noqa: E402
import t214_textures  # noqa: E402

OUT = "game/assets/vehicles/dekotora"
ATLAS = OUT + "/textures/deck_signs.png"
MAX_TRIS, MAX_TRIS_LEGEND = 4500, 6000
LOD_SHARE = 0.35                     # a malha de longe tem no máximo 35% dos triângulos (REFERENCIA_PECAS 16.1)
LEGEND = ("fb_wrap_tower", "fb_wrap_chrome", "fb_wrap_deck4", "fb_wrap_deck_wide")
GROUPS = ("TOP", "MID", "BOT", "CEN", "LTOP", "LMID", "LBOT", "LCEN")


def log(*a):
    print("[t264]", *a)


# (iguais às de build_t233_parts.py: aquele script roda ao ser importado)
def export_glb(path, objs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False, export_image_format="NONE")


def _uv_all(objs):
    for o in objs:
        if o.type == "MESH" and not o.data.uv_layers:
            M.uv_world(o, tile=0.5)


def _group(o):
    for g in GROUPS:
        if o.name.startswith(g + "_"):
            return g
    return ""


def setup_render(size=(640, 420)):
    from lib import preview as P
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.film_transparent = False
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.view_settings.view_transform = "Standard"
    P._setup_world()
    lights = [P._light("key", "AREA", (8, 10, 12), 4200, (1.0, 0.95, 0.9), 6),
              P._light("rim", "AREA", (-9, -14, 8), 3000, (0.55, 0.65, 1.0), 6),
              P._light("fill", "AREA", (-8, 12, 4), 1400, (0.8, 0.85, 1.0), 6),
              P._light("back", "AREA", (0, 14, 6), 2600, (1.0, 1.0, 1.0), 6)]
    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    return co, lights


def set_night(lights, night):
    k = 0.10 if night else 1.0
    for ob, e in zip(lights, (4200, 3000, 1400, 2600)):
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


def build_one(p, m, rel):
    """Completa + LOD (grupos L*), junta por material em cada grupo e exporta."""
    full = p["build"](m)
    lod_all = p["build"](m, lod=True)
    lod = [o for o in lod_all if o.type == "MESH"]
    for o in [o for o in lod_all if o.type == "EMPTY"]:      # os pontos SIGNAL só uma vez (da completa)
        bpy.data.objects.remove(o)
    for o in lod:
        o.name = "L" + o.name
    empties = [o for o in full if o.type == "EMPTY"]
    objs = [o for o in full + lod if o.type == "MESH"]
    M.apply_transforms(objs)
    _uv_all(objs)
    M.smooth(objs, 35.0)
    groups = {}
    for o in objs:
        groups.setdefault(_group(o), []).append(o)
    merged = []
    for g in sorted(groups):
        merged += M.join_by_material(groups[g], prefix=f"{p['id']}_{g}_" if g else p["id"] + "_")
    root = bpy.data.objects.new(p["id"], None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged + empties:
        o.parent = root
    lod0 = [o for o in merged if not any(f"_{g}_" in o.name for g in GROUPS if g.startswith("L"))]
    mn, mx = M.bounds(lod0)
    export_glb(os.path.join(OUT, rel), [root] + merged + empties)
    tris_g = {g: M.count_tris([o for o in merged if f"_{g}_" in o.name]) for g in GROUPS}
    t0 = sum(tris_g[g] for g in GROUPS if not g.startswith("L"))
    t1 = sum(tris_g[g] for g in GROUPS if g.startswith("L"))
    mats = sorted({s.material.name for o in merged for s in o.material_slots if s.material})
    return root, merged + empties, mx - mn, mn, mx, t0, t1, tris_g, mats


def entry_for(p, rel, size, mn, mx, tris, tris_lod, mats, tg, warn):
    return {
        "id": p["id"], "name": p["name"], "category": "front",
        "model": "res://assets/vehicles/dekotora/" + rel, "mount_point": "SOCKET_" + p["socket"],
        "mount_point_left": None, "mirror_for_left": False,
        "dimensions_m": {"x": round(size.x, 3), "y": round(size.z, 3), "z": round(size.y, 3)},
        "bounds_godot": [[round(mn.x, 3), round(mn.z, 3), round(-mx.y, 3)], [round(mx.x, 3), round(mx.z, 3), round(-mn.y, 3)]],
        "triangles": tris, "triangles_lod": tris_lod, "lod_m": 35.0,
        "compatibility": ["todos (encaixe por caminhão: truck/sockets/*.json)"],
        "materials_used": mats, "materials_available": {}, "customizable": None,
        "preview": f"res://assets/vehicles/dekotora/previews/t264_{p['id']}_day.png",
        "license": "original (gerado por script; desenho nosso inspirado nas capturas da oficina, nada copiado)",
        "fit_warnings": warn, "tier": "oficina", "style": "deco", "socket": p["socket"],
        "fit": p["fit"], "nominal_w": round(p["nominal_w"], 3), "default_color": p["default_color"],
        "has_sign": False, "sign_cell": -1, "captures": p["captures"], "pods": 0, "stack": None,
        "module_tris": tg, "vfit": dict(p["vfit"]), "broken_tilt": [1.5, 2.5],
    }


def build_all(todo_ids):
    atlas = bpy.data.images.load(os.path.abspath(ATLAS))
    m = Q.materials(atlas)
    built, entries = {}, []
    for p in front_t264.PARTS:
        if todo_ids and p["id"] not in todo_ids:
            continue
        rel = f"accessories/{p['folder']}/{p['id']}.glb"
        root, objs, size, mn, mx, t0, t1, tg, mats = build_one(p, m, rel)
        lim = MAX_TRIS_LEGEND if p["id"] in LEGEND else MAX_TRIS
        warn = []
        if t0 > lim:
            warn.append(f"orçamento de triângulos excedido: {t0} > {lim}")
        if t1 > t0 * LOD_SHARE:
            warn.append(f"LOD com {t1} triângulos (> {LOD_SHARE:.0%} de {t0})")
        e = entry_for(p, rel, size, mn, mx, t0, t1, mats, tg, warn)
        built[p["id"]] = (root, objs, e)
        entries.append(e)
        log(f"{p['id']:20s} tris={t0:5d} lod={t1:4d} ({t1 / max(t0, 1):.0%}) mats={len(mats)} {mats} "
            f"tam=({size.x:.2f} x {size.z:.2f} x {size.y:.2f}) {'; '.join(warn)}")
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


def previews(built, co, lights):
    from lib import preview as P
    paths = []
    for pid, (root, objs, entry) in built.items():
        shown = [o for o in objs if o.type == "MESH" and not o.name.startswith(pid + "_L")]
        for o in shown:
            o.hide_render = False
        mn, mx = M.bounds(shown)
        ctr = (mn + mx) / 2
        for tag, night in (("day", False), ("night", True)):
            set_night(lights, night)
            path = os.path.abspath(os.path.join(OUT, "previews", f"t264_{pid}_{tag}.png"))
            shoot(co, ctr, 330, 14, 5.2, path)
            paths.append(path)
        for o in shown:
            o.hide_render = True
    set_night(lights, False)
    if paths:
        P.contact_sheet(paths, os.path.abspath(os.path.join(OUT, "previews", "t264_sheet_front.png")), cols=4)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--no-preview", action="store_true")
    args = ap.parse_args(argv)
    if not os.path.exists(t214_textures.ALB):
        t214_textures.make()
    scene.reset_scene()
    todo = [s for s in args.only.split(",") if s]
    built, entries = build_all(todo)
    write_catalog(entries)
    co, lights = setup_render()
    for b in built.values():
        for o in b[1]:
            o.hide_render = True
    if not args.no_preview:
        previews(built, co, lights)
    bad = [e["id"] for e in entries if e["fit_warnings"]]
    log("OK build_t264_parts:", len(entries), "peças", ("; avisos: " + ", ".join(bad)) if bad else "")


main()
