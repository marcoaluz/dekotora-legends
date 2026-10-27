"""Peças da oficina, lote 2 (T-231): 11 para-choques traseiros com lanternas, 7 foguetes e o contorno de LED do baú.

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t231_parts.py -- [--only id1,id2] [--no-preview]

Gera (dentro de game/assets/vehicles/dekotora/):
  accessories/rear_t231/<id>.glb     para-choques (montados inteiros, escala uniforme pela largura do baú)
  accessories/rocket_t231/<id>.glb   foguetes (grupos HEAD_/MID_/TAIL_: o jogo estica pelo comprimento do baú)
  accessories/rocket_t231/boxlight_dash.glb   módulo do contorno (MID_: o jogo repete ao longo das faixas medidas)
  catalog.json                       entradas "style": "deco" (encaixe, fit, módulos)
  previews/t231_<id>_{day,night}.png + previews/t231_sheet_{rear,rocket}.png   (sem --no-preview)
Determinístico (mesma entrada, mesmos arquivos). Encaixes: `build_sockets.py` (rodar antes, se os caminhões mudarem).
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from accessories import rear_t231, rocket_t231, t231_kit as T  # noqa: E402
from lib import mesh3d as M, scene  # noqa: E402
import t214_textures  # noqa: E402

OUT = "game/assets/vehicles/dekotora"
ATLAS = OUT + "/textures/deck_signs.png"
MAX_TRIS, MAX_TRIS_LEGEND = 4500, 6000
LONGEST_BOX = 10.6          # m: baú mais comprido jogável (longo + cabine curta): conta de triângulos do foguete/contorno
LONGEST_PERIM = {"box_light_r": 24.3, "box_light_l": 24.3, "box_light_top": 26.7}   # REPORT/sockets: longo_curta
LEGEND = ("rb_torpedo", "rb_grand_panel")


def log(*a):
    print("[t231]", *a)


# (as 5 funções abaixo são as de build_t211_parts.py; aquele script roda ao ser importado, então ficam copiadas aqui)
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
              P._light("fill", "AREA", (-8, 18, 4), 1400, (0.8, 0.85, 1.0), 6),
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


def _drop_module_ends(objs, y0, y1):
    """Peças contínuas do módulo do meio (tubo, trilho) se encostam umas nas outras: as tampas nas pontas do módulo
    ficam escondidas e são apagadas (menos triângulos por metro)."""
    for o in objs:
        if o.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        dead = [f for f in bm.faces if abs(f.normal.y) > 0.99 and
                all(abs(v.co.y - y0) < 0.002 for v in f.verts) or
                (abs(f.normal.y) > 0.99 and all(abs(v.co.y - y1) < 0.002 for v in f.verts))]
        if dead:
            bmesh.ops.delete(bm, geom=dead, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


def _group(o):
    for g in ("HEAD", "MID", "TAIL"):
        if o.name.startswith(g + "_"):
            return g
    return ""


def build_one(p, m, rel, kind):
    """Constrói, junta por material (por grupo, nas peças esticáveis) e exporta. Devolve (raiz, objetos, entrada)."""
    objs = p["build"](m)
    M.apply_transforms(objs)
    _uv_all(objs)
    st = p.get("stretch")
    if st:
        mid = [o for o in objs if _group(o) == "MID"]
        y0 = st.get("head", 0.0)
        _drop_module_ends(mid, y0, y0 + st["mid"])
    M.smooth(objs, 35.0)
    merged = []
    if st:
        groups = {g: [o for o in objs if _group(o) == g] for g in ("HEAD", "MID", "TAIL")}
        for g, grp in groups.items():
            if grp:
                merged += M.join_by_material(grp, prefix=f"{p['id']}_{g}_")
    else:
        merged = M.join_by_material(objs, prefix=p["id"] + "_")
    root = bpy.data.objects.new(p["id"], None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged:
        o.parent = root
    mn, mx = M.bounds(merged)
    size = mx - mn
    export_glb(os.path.join(OUT, rel), [root] + merged)
    tris_g = {g: M.count_tris([o for o in merged if f"_{g}_" in o.name]) for g in ("HEAD", "MID", "TAIL")}
    tris = M.count_tris(merged)
    mats = sorted({s.material.name for o in merged for s in o.material_slots if s.material})
    return root, merged, size, mn, mx, tris, tris_g, mats


def entry_for(p, rel, size, mn, mx, tris, mats, kind, extra):
    e = {
        "id": p["id"], "name": p["name"], "category": "rear" if kind == "rear" else "lighting",
        "model": "res://assets/vehicles/dekotora/" + rel, "mount_point": "SOCKET_" + p["socket"],
        "mount_point_left": ("SOCKET_" + p["socket_left"]) if p.get("socket_left") else None,
        "mirror_for_left": bool(p.get("socket_left")),
        "dimensions_m": {"x": round(size.x, 3), "y": round(size.z, 3), "z": round(size.y, 3)},
        "bounds_godot": [[round(mn.x, 3), round(mn.z, 3), round(-mx.y, 3)], [round(mx.x, 3), round(mx.z, 3), round(-mn.y, 3)]],
        "triangles": tris, "compatibility": ["todos (encaixe por caminhão: truck/sockets/*.json)"],
        "materials_used": mats, "materials_available": {}, "customizable": None,
        "preview": f"res://assets/vehicles/dekotora/previews/t231_{p['id']}_day.png",
        "license": "original (gerado por script; desenho nosso inspirado nas capturas da oficina, nada copiado)",
        "fit_warnings": [], "tier": "oficina", "style": "deco", "socket": p["socket"],
        "fit": p.get("fit", "uniform"), "nominal_w": round(p["nominal_w"], 3), "default_color": p["default_color"],
        "has_sign": False, "sign_cell": -1, "captures": p["captures"], "pods": 0, "stack": None,
    }
    if p.get("socket_left"):
        e["socket_left"] = p["socket_left"]
    e.update(extra)
    return e


def build_all(todo_ids):
    atlas = bpy.data.images.load(os.path.abspath(ATLAS))
    m = T.materials(atlas)
    built, entries = {}, []
    for p in rear_t231.PARTS:
        if todo_ids and p["id"] not in todo_ids:
            continue
        rel = f"accessories/rear_t231/{p['id']}.glb"
        root, merged, size, mn, mx, tris, tg, mats = build_one(p, m, rel, "rear")
        lim = MAX_TRIS_LEGEND if p["id"] in LEGEND else MAX_TRIS
        warn = [f"orçamento de triângulos excedido: {tris} > {lim}"] if tris > lim else []
        e = entry_for(p, rel, size, mn, mx, tris, mats, "rear", {"fit_warnings": warn})
        built[p["id"]] = (root, merged, e)
        entries.append(e)
        log(f"{p['id']:18s} tris={tris:5d} mats={len(mats)} tam=({size.x:.2f} x {size.z:.2f} x {size.y:.2f}) {'; '.join(warn)}")
    for p in rocket_t231.PARTS:
        if todo_ids and p["id"] not in todo_ids:
            continue
        rel = f"accessories/rocket_t231/{p['id']}.glb"
        root, merged, size, mn, mx, tris, tg, mats = build_one(p, m, rel, "rocket")
        st = p["stretch"]
        n_long = max(1, round((LONGEST_BOX - st["head"] - st["tail"]) / st["mid"]))
        worst = 2 * (tg["HEAD"] + tg["TAIL"] + n_long * tg["MID"])           # 2 lados, baú mais comprido
        warn = [f"orçamento de triângulos excedido no baú mais comprido: {worst}"] if worst > MAX_TRIS else []
        e = entry_for(p, rel, size, mn, mx, worst, mats, "rocket",
                      {"fit_warnings": warn, "stretch": dict(st), "module_tris": tg, "min_scale": 0.7, "max_scale": 1.35, "broken_tilt": [0.0, 5.0]})
        built[p["id"]] = (root, merged, e)
        entries.append(e)
        log(f"{p['id']:18s} cabeça/meio/ponta={tg['HEAD']}/{tg['MID']}/{tg['TAIL']} tris (2 lados, {LONGEST_BOX} m)={worst} mats={len(mats)} {'; '.join(warn)}")
    if not todo_ids or any(i.startswith("boxlight") for i in todo_ids):
        bl = rocket_t231.BOXLIGHT
        rel = "accessories/rocket_t231/boxlight_dash.glb"
        pmod = {"id": bl["id"], "build": bl["build"], "stretch": bl["stretch"]}
        root, merged, size, mn, mx, tris, tg, mats = build_one(pmod, m, rel, "strip")
        for pid, name, sock, caps in rocket_t231.BOXLIGHT_PARTS:
            p = {"id": pid, "name": name, "socket": sock, "nominal_w": 0.025, "default_color": "preto_verde", "captures": caps,
                 "fit": "strips"}
            worst = int(math.ceil(LONGEST_PERIM[sock] / bl["stretch"]["mid"])) * tg["MID"]
            warn = [f"orçamento de triângulos excedido: {worst}"] if worst > MAX_TRIS else []
            e = entry_for(p, rel, size, mn, mx, worst, mats, "strip",
                          {"fit_warnings": warn, "stretch": dict(bl["stretch"]), "module_tris": tg, "broken_tilt": [0.0, 0.0],
                           "fade_end": 90.0})
            e["preview"] = "res://assets/vehicles/dekotora/previews/t231_boxlight_dash_day.png"
            entries.append(e)
            log(f"{pid:18s} módulo={tg['MID']} tris (maior baú) = {worst} mats={len(mats)}")
        built["boxlight_dash"] = (root, merged, {"id": "boxlight_dash", "socket": "strip", "stretch": bl["stretch"]})
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


# ----------------------------------------------------------------------------- prévias

def _assembled(merged, st, copies=4):
    """Prévia de uma peça esticável: cabeça + `copies` módulos + ponta (cópias ligadas, só para a imagem)."""
    out = []
    for o in merged:
        if "_MID_" in o.name:
            for k in range(copies):
                c = o.copy()
                bpy.context.scene.collection.objects.link(c)
                c.location = o.location + Vector((0, st["mid"] * k, 0))
                out.append(c)
        elif "_TAIL_" in o.name:
            c = o.copy()
            bpy.context.scene.collection.objects.link(c)
            c.location = o.location + Vector((0, st["mid"] * (copies - 1), 0))
            out.append(c)
        else:
            c = o.copy()
            bpy.context.scene.collection.objects.link(c)
            out.append(c)
    return out


def previews(built, co, lights):
    from lib import preview as P
    sheets = {"rear": [], "rocket": []}
    for pid, (root, merged, entry) in built.items():
        st = entry.get("stretch")
        shown = _assembled(merged, st) if st else merged
        for o in shown:
            o.hide_render = False
        mn, mx = M.bounds(shown)
        ctr = (mn + mx) / 2
        kind = "rear" if pid.startswith("rb_") else "rocket"
        dist = max((mx - mn).length * (1.75 if kind == "rear" else 0.9), 0.8)
        for tag, night in (("day", False), ("night", True)):
            set_night(lights, night)
            path = os.path.abspath(os.path.join(OUT, "previews", f"t231_{pid}_{tag}.png"))
            if kind == "rear":
                shoot(co, ctr, 155, 12, dist, path)                 # de trás, 3/4 pela esquerda
            else:
                shoot(co, ctr + Vector((0, -1.2, 0)), 150, 26, 1.6, path)   # a ponta de trás, de trás e de cima, pela direita
            sheets[kind].append(path)
        for o in shown:
            o.hide_render = True
        if st:
            for o in shown:
                bpy.data.objects.remove(o)
    set_night(lights, False)
    for kind, paths in sheets.items():
        if paths:
            P.contact_sheet(paths, os.path.abspath(os.path.join(OUT, "previews", f"t231_sheet_{kind}.png")), cols=4)


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
    log("OK build_t231_parts:", len(entries), "peças", ("; avisos: " + ", ".join(bad)) if bad else "")


main()
