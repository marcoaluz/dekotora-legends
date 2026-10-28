"""T-258: dados das pinturas do grupo "Wallpapers" a partir da lista que o build grava
(blender/renders/t258/wallpapers.json, `build_t258_wallpapers.py -- --install`): entrada no catálogo (fit "paint",
`group: "wallpapers"`), .tres (PartDef) e nome pt-BR. Origem nos créditos: "gerada pelo Marco (Gemini)".
Números = PROPOSTA (mesma faixa das pinturas da T-232). Idempotente.

Uso (raiz do projeto, Python do sistema):  python -I tools/gen_t258_data.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
GAME = os.path.join(ROOT, "game")
PART_SCRIPT = "res://scripts/data/part_def.gd"
SLOT = {"mural": ("mural", "mural_r", "mural_l", "SOCKET_mural_r", "SOCKET_mural_l", "left\", \"right"),
        "rear": ("rear_paint", "rear_paint", None, "SOCKET_rear_paint", None, "rear"),
        "roof": ("roof_paint", "roof_paint", None, "SOCKET_roof_paint", None, "roof")}
PRICE = {"mural": (30000, 22), "rear": (14000, 12), "roof": (12000, 10)}
LABEL = {"mural": "Wallpaper", "rear": "Traseira (wallpaper)", "roof": "Teto (wallpaper)"}
ORIGIN = "gerada pelo Marco (Gemini), uso por decisão dele (grupo Wallpapers, T-258; ver docs/CREDITOS_MURAIS.md)"


def tres(pid, slot, zone, fame, price):
    return f'''[gd_resource type="Resource" script_class="PartDef" format=3]

[ext_resource type="Script" path="{PART_SCRIPT}" id="1_pd"]

[resource]
script = ExtResource("1_pd")
id = &"{pid}"
display_key = "part.{pid}"
slot = &"{slot}"
zones = PackedStringArray("{zone}")
weight_kg = 0.0
durability = 0.0
fame = {fame}
price = {price}
accessory_id = "{pid}"
rarity = &"incomum"
fame_min = 20
'''


def main():
    import sys
    args = sys.argv[1:]
    dry = "--dry" in args                                   # confere sem gravar nada (teste)
    man = args[args.index("--manifest") + 1] if "--manifest" in args else os.path.join(ROOT, "blender", "renders", "t258", "wallpapers.json")
    if not os.path.exists(man):
        raise SystemExit("rode antes: blender -b --factory-startup -P blender/scripts/build_t258_wallpapers.py -- --install")
    pieces = json.load(open(man, encoding="utf-8"))
    cpath = os.path.join(GAME, "assets", "vehicles", "dekotora", "catalog.json")
    cat = json.load(open(cpath, encoding="utf-8"))
    tr_path = os.path.join(GAME, "data", "i18n", "pt-BR.json")
    tr = json.load(open(tr_path, encoding="utf-8"))
    ids = []
    for pc in pieces:
        slot, sock, sock_l, mp, mp_l, zone = SLOT[pc["kind"]]
        paint = {}
        for side, arts in pc["sides"].items():
            res = lambda st: "res://" + st[len("game/"):]          # noqa: E731
            paint[side] = [{"tex": res(a["stem"]) + ".png", "emit": res(a["stem"]) + "_emit.png", "aspect": a["aspect"],
                            "px": a["px"]} for a in arts]
        name = "%s: %s" % (LABEL[pc["kind"]], pc["name"].replace("_", " "))
        e = {"id": pc["id"], "name": name, "category": "paint", "model": "", "mount_point": mp, "mount_point_left": mp_l,
             "mirror_for_left": sock_l is not None, "dimensions_m": None, "triangles": 2,
             "compatibility": ["só baú fechado (retângulo medido por caminhão: truck/sockets/*.json, rect)"],
             "materials_used": ["paint_art"], "materials_available": {}, "customizable": None, "license": ORIGIN,
             "fit_warnings": [], "tier": "oficina", "socket": sock, "fit": "paint", "group": "wallpapers", "paint": paint}
        if sock_l:
            e["socket_left"] = sock_l
        cat["accessories"] = [x for x in cat["accessories"] if x["id"] != pc["id"]] + [e]
        price, fame = PRICE[pc["kind"]]
        if dry:
            print(json.dumps(e, ensure_ascii=False)[:300])
            ids.append(pc["id"])
            continue
        with open(os.path.join(GAME, "data", "parts", pc["id"] + ".tres"), "w", encoding="utf-8", newline="\n") as f:
            f.write(tres(pc["id"], slot, zone, fame, price))
        tr["part." + pc["id"]] = name
        ids.append(pc["id"])
    if dry:
        print("OK gen_t258_data (sem gravar):", ", ".join(ids))
        return
    with open(cpath, "w", encoding="utf-8", newline="\n") as f:
        json.dump(cat, f, ensure_ascii=False, indent=2)
    with open(tr_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(tr, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("OK gen_t258_data:", len(ids), "pintura(s):", ", ".join(ids))


main()
