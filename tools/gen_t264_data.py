"""Dados dos para-choques GRANDES da frente (T-264, capturas 054–062): 5 .tres e os textos pt-BR.
Números = proposta (docs/REFERENCIA_PECAS.md seção 3 e docs/BALANCEAMENTO.md seção T-264).

Uso (raiz do projeto, Python do sistema, só biblioteca padrão):  python tools/gen_t264_data.py
Regra do Marco (decisão 4): raridade e "fama mínima" ficam nos dados, mas NÃO travam a compra (fame_required = 0).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
PART_SCRIPT = "res://scripts/data/part_def.gd"

# id, nome, peso kg, durabilidade, destaque, preço ¥, fama mínima (informativa), raridade
PARTS = [
    ("fb_wrap_lamps", "Caixa alta de painéis de luz", 480, 290, 30, 48000, 60, "rara"),
    ("fb_wrap_tower", "Torre da placa com faixas", 500, 300, 32, 54000, 120, "lendaria"),
    ("fb_wrap_chrome", "Cromado envolvente", 540, 340, 26, 52000, 120, "lendaria"),
    ("fb_wrap_deck4", "Deque xadrez de 4 painéis", 540, 300, 38, 68000, 120, "lendaria"),
    ("fb_wrap_deck_wide", "Deque xadrez de painéis largos", 560, 300, 40, 72000, 120, "lendaria"),
]


def part_tres(pid, w, dur, fame, price, fame_min, rarity):
    return f'''[gd_resource type="Resource" script_class="PartDef" format=3]

[ext_resource type="Script" path="{PART_SCRIPT}" id="1_pd"]

[resource]
script = ExtResource("1_pd")
id = &"{pid}"
display_key = "part.{pid}"
slot = &"front_bumper"
zones = PackedStringArray("front")
weight_kg = {float(w)}
durability = {float(dur)}
fame = {fame}
price = {price}
accessory_id = "{pid}"
rarity = &"{rarity}"
fame_min = {fame_min}
'''


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    keys = {}
    for pid, name, w, dur, fame, price, fmin, rar in PARTS:
        write(os.path.join(ROOT, "data", "parts", pid + ".tres"), part_tres(pid, w, dur, fame, price, fmin, rar))
        keys["part." + pid] = name
    path = os.path.join(ROOT, "data", "i18n", "pt-BR.json")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    d.update(keys)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"OK gen_t264_data: {len(PARTS)} pecas, {len(keys)} textos")


main()
