"""Peças da oficina, lote 4 (T-233): 11 para-choques da frente, 6 hastes de retrovisor, 3 escadas e 8 saias.

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t233_parts.py -- [--only id1,id2] [--no-preview]

Gera (dentro de game/assets/vehicles/dekotora/):
  accessories/front_t233/<id>.glb    para-choques (grupos TOP_/MID_/BOT_/CEN_ + pontos SIGNAL_L/R: o jogo ajusta a altura)
  accessories/mirror_t233/<id>.glb   hastes de retrovisor (uma por lado; o jogo ajusta a altura pelo vidro da cabine)
  accessories/ladder_t233/<id>.glb   escadas (grupos BOT_/MID_/TOP_: o jogo repete o degrau até o topo do baú)
  accessories/skirt_t233/<id>.glb    saias (grupos HEAD_/MID_/TAIL_: o jogo monta um pedaço em cada trecho livre)
  catalog.json                       entradas "style": "deco" (encaixe, fit, grupos)
  previews/t233_<id>_{day,night}.png + previews/t233_sheet_<tipo>.png   (sem --no-preview)
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
from accessories import front_t233, ladder_t233, mirror_t233, skirt_t233, t233_kit as Q  # noqa: E402
from lib import mesh3d as M, scene  # noqa: E402
import t214_textures  # noqa: E402

OUT = "game/assets/vehicles/dekotora"
ATLAS = OUT + "/textures/deck_signs.png"
MAX_TRIS, MAX_TRIS_LEGEND = 4500, 6000
TALLEST_BOX = 2.35          # m: baú mais alto jogável (altura da escada)
LONGEST_RUNS = 4.4          # m: soma dos trechos de saia de um lado no caminhão mais comprido (REPORT/sockets)
MAX_RUNS = 3                # trechos por lado (pontas)
LEGEND = ("fb_deck_checker", "fb_deck_neon")
KINDS = (("front", front_t233), ("mirror", mirror_t233), ("ladder", ladder_t233), ("skirt", skirt_t233))
GROUPS = ("TOP", "MID", "BOT", "CEN", "HEAD", "TAIL")


def log(*a):
    print("[t233]", *a)


# (as funções abaixo são as de build_t231_parts.py: aquele script roda ao ser importado, então ficam copiadas aqui)
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


def _drop_module_ends(objs, axis, a0, a1):
    """Tampas escondidas nas pontas do módulo repetido (o vizinho encosta nelas): apagadas (menos triângulos)."""
    for o in objs:
        if o.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        dead = [f for f in bm.faces if abs(f.normal[axis]) > 0.99 and
                (all(abs(v.co[axis] - a0) < 0.002 for v in f.verts) or all(abs(v.co[axis] - a1) < 0.002 for v in f.verts))]
        if dead:
            bmesh.ops.delete(bm, geom=dead, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


def _group(o):
    for g in GROUPS:
        if o.name.startswith(g + "_"):
            return g
    return ""


def build_one(p, m, rel):
    """Constrói, junta por material (por grupo) e exporta. Devolve (raiz, objetos, tamanho, mn, mx, tris, tris por grupo,
    materiais)."""
    built = p["build"](m)
    empties = [o for o in built if o.type == "EMPTY"]
    objs = [o for o in built if o.type == "MESH"]
    M.apply_transforms(objs)
    _uv_all(objs)
    st = p.get("stretch")
    if st and p["fit"] == "ladder":
        _drop_module_ends([o for o in objs if _group(o) == "MID"], 2, st["head"], st["head"] + st["mid"])
    elif st and p["fit"] == "runs":
        _drop_module_ends([o for o in objs if _group(o) == "MID"], 1, st["head"], st["head"] + st["mid"])
    M.smooth(objs, 35.0)
    merged = []
    groups = {}
    for o in objs:
        groups.setdefault(_group(o), []).append(o)
    for g in sorted(groups):
        merged += M.join_by_material(groups[g], prefix=f"{p['id']}_{g}_" if g else p["id"] + "_")
    root = bpy.data.objects.new(p["id"], None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged + empties:
        o.parent = root
    mn, mx = M.bounds(merged)
    size = mx - mn
    export_glb(os.path.join(OUT, rel), [root] + merged + empties)
    tris_g = {g: M.count_tris([o for o in merged if f"_{g}_" in o.name]) for g in GROUPS}
    tris = M.count_tris(merged)
    mats = sorted({s.material.name for o in merged for s in o.material_slots if s.material})
    return root, merged + empties, size, mn, mx, tris, tris_g, mats


def entry_for(p, rel, kind, size, mn, mx, tris, mats, extra):
    cat = {"front": "front", "mirror": "front", "ladder": "sides", "skirt": "sides"}[kind]
    e = {
        "id": p["id"], "name": p["name"], "category": cat,
        "model": "res://assets/vehicles/dekotora/" + rel, "mount_point": "SOCKET_" + p["socket"],
        "mount_point_left": ("SOCKET_" + p["socket_left"]) if p.get("socket_left") else None,
        "mirror_for_left": bool(p.get("socket_left")),
        "dimensions_m": {"x": round(size.x, 3), "y": round(size.z, 3), "z": round(size.y, 3)},
        "bounds_godot": [[round(mn.x, 3), round(mn.z, 3), round(-mx.y, 3)], [round(mx.x, 3), round(mx.z, 3), round(-mn.y, 3)]],
        "triangles": tris, "compatibility": ["todos (encaixe por caminhão: truck/sockets/*.json)"],
        "materials_used": mats, "materials_available": {}, "customizable": None,
        "preview": f"res://assets/vehicles/dekotora/previews/t233_{p['id']}_day.png",
        "license": "original (gerado por script; desenho nosso inspirado nas capturas da oficina, nada copiado)",
        "fit_warnings": [], "tier": "oficina", "style": "deco", "socket": p["socket"],
        "fit": p["fit"], "nominal_w": round(p["nominal_w"], 3), "default_color": p["default_color"],
        "has_sign": False, "sign_cell": -1, "captures": p["captures"], "pods": 0, "stack": None,
    }
    if p.get("socket_left"):
        e["socket_left"] = p["socket_left"]
    e.update(extra)
    return e


def build_all(todo_ids):
    atlas = bpy.data.images.load(os.path.abspath(ATLAS))
    m = Q.materials(atlas)
    built, entries = {}, []
    for kind, mod in KINDS:
        for p in mod.PARTS:
            if todo_ids and p["id"] not in todo_ids:
                continue
            rel = f"accessories/{p['folder']}/{p['id']}.glb"
            root, objs, size, mn, mx, tris, tg, mats = build_one(p, m, rel)
            lim = MAX_TRIS_LEGEND if p["id"] in LEGEND else MAX_TRIS
            extra = {"module_tris": tg}
            if kind == "front":
                worst = int(tris + tg["MID"] * 1.2)                       # meio esticado não muda os triângulos
                extra.update({"vfit": dict(p["vfit"]), "broken_tilt": [2.0, 4.0]})
                worst = tris
            elif kind == "mirror":
                worst = 2 * tris
                extra.update({"vfit": dict(p["vfit"]), "broken_tilt": [0.0, 9.0], "fade_end": 110.0})
            elif kind == "ladder":
                st = p["stretch"]
                n = max(1, round((TALLEST_BOX - st["head"] - st["tail"]) / st["mid"]))
                worst = 2 * (tg["BOT"] + tg["TOP"] + n * tg["MID"])
                extra.update({"stretch": dict(st), "broken_tilt": [0.0, 4.0], "fade_end": 110.0})
            else:
                st = p["stretch"]
                n = max(1, round(LONGEST_RUNS / st["mid"]))
                worst = 2 * (MAX_RUNS * (tg["HEAD"] + tg["TAIL"]) + n * tg["MID"])
                extra.update({"stretch": dict(st), "broken_tilt": [0.0, 3.0]})
            warn = [f"orçamento de triângulos excedido: {worst} > {lim}"] if worst > lim else []
            e = entry_for(p, rel, kind, size, mn, mx, worst, mats, dict(extra, fit_warnings=warn))
            built[p["id"]] = (root, objs, e, kind)
            entries.append(e)
            log(f"{p['id']:20s} tris={tris:5d} pior caso={worst:5d} grupos={ {g: v for g, v in tg.items() if v} } mats={len(mats)} "
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


# ----------------------------------------------------------------------------- prévias

def _assembled(objs, axis, st, copies=4):
    """Prévia de uma peça repetível: ponta + `copies` módulos + ponta (cópias só para a imagem)."""
    out = []
    head = st["head"]
    for o in objs:
        if o.type != "MESH":
            continue
        reps = copies if "_MID_" in o.name else 1
        shift = st["mid"] * (copies - 1) if ("_TAIL_" in o.name or "_TOP_" in o.name) else 0.0
        for k in range(reps):
            c = o.copy()
            bpy.context.scene.collection.objects.link(c)
            d = Vector((0, 0, 0))
            d[axis] = (st["mid"] * k) if "_MID_" in o.name else shift
            c.location = o.location + d
            out.append(c)
    return out


def previews(built, co, lights):
    from lib import preview as P
    sheets = {"front": [], "mirror": [], "ladder": [], "skirt": []}
    for pid, (root, objs, entry, kind) in built.items():
        st = entry.get("stretch")
        if kind in ("ladder", "skirt"):
            shown = _assembled(objs, 2 if kind == "ladder" else 1, st)
        else:
            shown = [o for o in objs if o.type == "MESH"]
        for o in shown:
            o.hide_render = False
        mn, mx = M.bounds(shown)
        ctr = (mn + mx) / 2
        for tag, night in (("day", False), ("night", True)):
            set_night(lights, night)
            path = os.path.abspath(os.path.join(OUT, "previews", f"t233_{pid}_{tag}.png"))
            if kind == "front":
                shoot(co, ctr, 330, 14, 4.6, path)              # de frente, 3/4 pela esquerda, baixa
            elif kind == "mirror":
                shoot(co, ctr, 40, 18, 2.4, path)
            elif kind == "ladder":
                shoot(co, ctr, 60, 10, 3.6, path)
            else:
                shoot(co, ctr, 70, 12, 3.4, path)
            sheets[kind].append(path)
        for o in shown:
            o.hide_render = True
        if kind in ("ladder", "skirt"):
            for o in shown:
                bpy.data.objects.remove(o)
    set_night(lights, False)
    for kind, paths in sheets.items():
        if paths:
            P.contact_sheet(paths, os.path.abspath(os.path.join(OUT, "previews", f"t233_sheet_{kind}.png")), cols=4)


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
    log("OK build_t233_parts:", len(entries), "peças", ("; avisos: " + ", ".join(bad)) if bad else "")


main()
