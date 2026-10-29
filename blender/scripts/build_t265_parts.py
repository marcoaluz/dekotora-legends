"""Saias laterais GRANDES (T-265, capturas 085–094): as 8 saias passam a ir da frente do baú até a traseira, quase no
chão, com arco em volta das rodas (accessories/skirt_t265.py; montadas pelo jogo, game/scripts/truck/skirt_fit.gd).

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t265_parts.py -- [--only id1,id2] [--tris ARQ.json]

Gera (dentro de game/assets/vehicles/dekotora/):
  accessories/skirt_t265/<id>.glb   enfeites MOTIF_<forma>_<material> + amostras MAT_<material> (o jogo monta o resto)
  catalog.json                      as 8 entradas `skirt_*` (fit "skirt", desenho em `skirt`), no lugar das da T-233
`--tris`: JSON {id: [triângulos de perto, de longe]} medido no jogo em todos os caminhões (o pior caso), gravado por
`godot --headless --path game -s res://tools_dev/measure_t265.gd -- --out=ARQ.json`. Sem ele, mantém o que já estava.
Determinístico. Encaixes (faixa da saia, arcos, trechos): `build_sockets.py`. `dimensions_m` = a maior saia montada
(um lado) num caminhão jogável, lida desses encaixes: rode este script de novo depois do `build_sockets.py`.
"""
import argparse
import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from accessories import skirt_t265, t211_kit as K  # noqa: E402
from lib import mesh3d as M, scene  # noqa: E402

OUT = "game/assets/vehicles/dekotora"
MAT_KEY = {"deco_body": "body", "deco_trim": "trim", "deco_led": "led", "deco_neon": "neon", "chrome": "chrome"}


def log(*a):
    print("[t265]", *a)


def export_glb(path, objs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False, export_image_format="NONE")


def used_materials(p) -> list:
    sk = p["skirt"]
    mats = {sk.get("trim", "chrome")}
    if sk.get("panel", True):
        mats.add(sk.get("body", "deco_body"))
    for r in sk.get("rows", []):
        mats.add(r.get("m", "deco_neon"))
    for d in (sk.get("arch"), sk.get("posts")):
        if d:
            mats.add(d.get("m", "deco_neon"))
    return sorted(mats)


def build_one(p, m):
    objs = []
    for key, fn in sorted(p["motifs"].items()):
        o = fn(m, "MOTIF_" + key)
        objs.append(o)
    mats = used_materials(p)
    for k, mat in enumerate(mats):                    # amostra (triângulo de 1 cm) de cada material
        o = K.mesh_from("MAT_" + mat, [(0.0, 0.0, 0.0), (0.0, 0.01, 0.0), (0.0, 0.0, 0.01)], [(0, 1, 2)], m[MAT_KEY[mat]])
        objs.append(o)
    M.apply_transforms(objs)
    for o in objs:
        if not o.data.uv_layers:
            M.uv_world(o, tile=0.5)
    M.smooth([o for o in objs if o.name.startswith("MOTIF_rail")], 60.0)
    root = bpy.data.objects.new(p["id"], None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    rel = f"accessories/{p['folder']}/{p['id']}.glb"
    export_glb(os.path.join(OUT, rel), [root] + objs)
    motif_tris = {o.name[6:]: M.count_tris([o]) for o in objs if o.name.startswith("MOTIF_")}
    for o in [root] + objs:                           # (a próxima peça usa os mesmos nomes: sem ".001")
        bpy.data.objects.remove(o)
    return rel, mats, motif_tris


SOCKETS = os.path.join(OUT, "truck", "sockets")


def mounted_size():
    """Maior saia montada (um lado) nos caminhões jogáveis, lida dos encaixes `side_skirts_r` (build_sockets.py):
    x = espessura, y = altura, z = da 1ª à última ponta dos trechos (da frente do baú à traseira). A carreta (guardada,
    não jogável) fica de fora. Sem encaixes medidos ainda: o tamanho do baú longo (1ª rodada)."""
    x = y = z = 0.0
    for f in sorted(os.listdir(SOCKETS)) if os.path.isdir(SOCKETS) else []:
        if not f.endswith(".json") or f.endswith(".surf.json"):
            continue
        with open(os.path.join(SOCKETS, f), encoding="utf-8") as fh:
            d = json.load(fh)
        s = d.get("sockets", {}).get("side_skirts_r")
        if d.get("body") == "carreta" or not s or s.get("fit") != "skirt" or not s.get("runs"):
            continue
        x = max(x, float(s.get("depth", 0.0)))
        y = max(y, float(s.get("height", 0.0)))
        z = max(z, max(r[1] for r in s["runs"]) - min(r[0] for r in s["runs"]))
    if z <= 0.0:
        return 0.10, 1.08, 10.95
    return round(x, 3), round(y, 3), round(z, 3)


def entry_for(p, rel, mats, motif_tris, old, size):
    t = old.get("triangles", 0) if old.get("fit") == "skirt" else 0
    tl = old.get("triangles_lod", 0) if old.get("fit") == "skirt" else 0
    sx, sy, sz = size
    return {
        "id": p["id"], "name": p["name"], "category": "sides",
        "model": "res://assets/vehicles/dekotora/" + rel,
        "mount_point": "SOCKET_side_skirts_r", "mount_point_left": "SOCKET_side_skirts_l", "mirror_for_left": True,
        # (a maior saia montada num caminhão jogável, um lado; o jogo monta por caminhão a partir do encaixe)
        "dimensions_m": {"x": sx, "y": sy, "z": sz},
        "bounds_godot": [[-sx, -sy, -sz], [0.0, 0.0, 0.0]],
        "triangles": t, "triangles_lod": tl, "lod_m": 35.0,
        "compatibility": ["todos (encaixe por caminhão: truck/sockets/*.json; montada no jogo, SkirtFit)"],
        "materials_used": mats, "materials_available": {}, "customizable": None,
        "preview": f"res://assets/vehicles/dekotora/previews/t265_{p['id']}_day.png",
        "license": "original (gerado por script; desenho nosso inspirado nas capturas da oficina, nada copiado)",
        "fit_warnings": [], "tier": "oficina", "style": "deco", "socket": p["socket"], "fit": "skirt",
        "default_color": p["default_color"], "has_sign": False, "sign_cell": -1, "captures": p["captures"], "pods": 0,
        "stack": None, "socket_left": p["socket_left"], "motif_tris": motif_tris, "skirt": p["skirt"],
        "broken_tilt": [0.0, 2.0],
    }


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--tris", default="")
    args = ap.parse_args(argv)
    scene.reset_scene()
    m = K.materials(None)
    todo = [s for s in args.only.split(",") if s]
    path = os.path.join(OUT, "catalog.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    old = {e["id"]: e for e in data["accessories"]}
    tris = json.load(open(args.tris, encoding="utf-8")) if args.tris else {}
    entries = []
    size = mounted_size()
    log("maior saia montada (x, y, z):", size)
    for p in skirt_t265.PARTS:
        if todo and p["id"] not in todo:
            continue
        rel, mats, mt = build_one(p, m)
        e = entry_for(p, rel, mats, mt, old.get(p["id"], {}), size)
        if p["id"] in tris:
            e["triangles"], e["triangles_lod"] = int(tris[p["id"]][0]), int(tris[p["id"]][1])
        entries.append(e)
        log(f"{p['id']:20s} materiais {mats} enfeites {mt} tris {e['triangles']} / {e['triangles_lod']}")
    # (mesma ordem do arquivo: a entrada antiga da T-233 é trocada no lugar)
    new = {e["id"]: e for e in entries}
    data["accessories"] = [new.get(e["id"], e) for e in data["accessories"]]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    log("OK build_t265_parts:", len(entries), "saias; catálogo", path)


main()
