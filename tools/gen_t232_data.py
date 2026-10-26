"""Dados das pinturas da T-232 (12 murais, 12 traseiras, 9 tetos): .tres das peças, entradas do catálogo
(`assets/vehicles/dekotora/catalog.json`, fit "paint") e textos pt-BR. A tabela fica em
`blender/scripts/lib/t232_registry.py` (a mesma que o build das artes usa). Números = PROPOSTA.

Uso (raiz do projeto, Python do sistema, só biblioteca padrão):  python tools/gen_t232_data.py
Idempotente: rodar de novo regrava as mesmas coisas (as entradas antigas com o mesmo id são substituídas).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "game")
sys.path.insert(0, os.path.join(HERE, "..", "blender", "scripts"))
from lib import t232_registry as REG  # noqa: E402

PART_SCRIPT = "res://scripts/data/part_def.gd"
TEXTS = {
    "slot.rear_paint": "Pintura da traseira",
    "slot.roof_paint": "Pintura do teto",
    "garage.paint_both_sides": "Mural: um desenho diferente em cada lado do baú.",
}


def part_tres(pid, slot, zones, fame, price):
    z = ", ".join(f'"{x}"' for x in zones)
    return f'''[gd_resource type="Resource" script_class="PartDef" format=3]

[ext_resource type="Script" path="{PART_SCRIPT}" id="1_pd"]

[resource]
script = ExtResource("1_pd")
id = &"{pid}"
display_key = "part.{pid}"
slot = &"{slot}"
zones = PackedStringArray({z})
fame = {fame}
price = {price}
accessory_id = "{pid}"
rarity = &"{REG.rarity(price)}"
fame_min = {REG.fame_min(price)}
'''


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def catalog_entry(pid, name, info):
    paint = {}
    for side, arts in info["sides"].items():
        paint[side] = [{"tex": f"{REG.RES_DIR}/{t}", "emit": f"{REG.RES_DIR}/{e}", "aspect": round(a, 4), "px": list(px)}
                       for t, e, a, px in arts]
    e = {"id": pid, "name": name, "category": "paint", "model": "",
         "mount_point": "SOCKET_" + info["socket"], "mount_point_left": ("SOCKET_" + info["socket_left"]) if "socket_left" in info else None,
         "mirror_for_left": "socket_left" in info, "dimensions_m": None, "triangles": 2 * len(info["sides"]),
         "compatibility": ["só baú fechado (retângulo medido por caminhão: truck/sockets/*.json, rect)"],
         "materials_used": ["paint_art"], "materials_available": {}, "customizable": None,
         "license": "original (arte nossa feita por código, T-232; kanji na fonte Yuji Syuku, OFL)",
         "fit_warnings": [], "tier": "oficina", "socket": info["socket"], "fit": "paint", "paint": paint}
    if "socket_left" in info:
        e["socket_left"] = info["socket_left"]
    return e


def main():
    files = REG.files()
    rows = [(pid, name, price, fame) for pid, _m, _f, name, price, fame in REG.MURALS]
    rows += [(pid, name, price, fame) for pid, _k, name, price, fame in REG.REARS]
    rows += [(pid, name, price, fame) for pid, _i, name, price, fame in REG.ROOFS]
    keys = dict(TEXTS)
    entries = []
    for pid, name, price, fame in rows:
        info = files[pid]
        write(os.path.join(ROOT, "data", "parts", pid + ".tres"), part_tres(pid, info["slot"], info["zones"], fame, price))
        keys["part." + pid] = name
        entries.append(catalog_entry(pid, name, info))
    cpath = os.path.join(ROOT, "assets", "vehicles", "dekotora", "catalog.json")
    with open(cpath, encoding="utf-8") as f:
        cat = json.load(f)
    ids = {e["id"] for e in entries}
    cat["accessories"] = [e for e in cat["accessories"] if e["id"] not in ids] + entries
    with open(cpath, "w", encoding="utf-8", newline="\n") as f:
        json.dump(cat, f, ensure_ascii=False, indent=2)          # mesmo formato do build_t231_parts.py
    path = os.path.join(ROOT, "data", "i18n", "pt-BR.json")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    d.update(keys)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"OK gen_t232_data: {len(rows)} pinturas, {len(keys)} textos")


main()
