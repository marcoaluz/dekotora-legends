"""Dados das peças da oficina, lote 2 (T-231): 11 para-choques traseiros, 7 foguetes, 3 contornos do baú (.tres) e os
textos pt-BR. Números = proposta do catálogo (docs/REFERENCIA_PECAS.md, seções 4, 6 e 7).

Uso (raiz do projeto, Python do sistema, só biblioteca padrão):  python tools/gen_t231_data.py
Regra do Marco (decisão 4): raridade e "fama mínima" ficam nos dados, mas NÃO travam a compra (fame_required = 0).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
PART_SCRIPT = "res://scripts/data/part_def.gd"

# id, nome, encaixe (slot), zona de dano, peso kg, durabilidade, destaque, preço ¥, fama mínima (informativa), raridade
PARTS = [
    ("rb_square_row", "Fileira de lanternas quadradas", "rear_bumper", "rear", 140, 110, 12, 16000, 20, "incomum"),
    ("rb_round_twin", "Duas fileiras redondas", "rear_bumper", "rear", 220, 150, 20, 28000, 20, "incomum"),
    ("rb_square_grid", "Grade de quadradas", "rear_bumper", "rear", 230, 150, 20, 29000, 20, "incomum"),
    ("rb_round_grid", "Grade de redondas", "rear_bumper", "rear", 230, 150, 22, 31000, 60, "rara"),
    ("rb_target", "Lanternas alvo", "rear_bumper", "rear", 260, 160, 26, 36000, 60, "rara"),
    ("rb_double_deck", "Dois andares", "rear_bumper", "rear", 260, 170, 26, 38000, 60, "rara"),
    ("rb_neon_rows", "Fileiras com neon", "rear_bumper", "rear", 240, 150, 26, 36000, 60, "rara"),
    ("rb_neon_plate", "Placa neon", "rear_bumper", "rear", 230, 150, 24, 34000, 60, "rara"),
    ("rb_bullet", "Lanternas bala", "rear_bumper", "rear", 270, 170, 30, 44000, 60, "rara"),
    ("rb_torpedo", "Bateria torpedo", "rear_bumper", "rear", 300, 170, 36, 52000, 120, "lendaria"),
    ("rb_grand_panel", "Painel grande cromado", "rear_bumper", "rear", 380, 240, 40, 72000, 120, "lendaria"),
    ("rocket_round", "Foguete redondo", "rocket", "roof", 60, 50, 10, 12000, 0, "comum"),
    ("rocket_square", "Foguete quadrado", "rocket", "roof", 65, 50, 11, 13000, 0, "comum"),
    ("rocket_twin", "Foguete duplo", "rocket", "roof", 90, 60, 14, 18000, 20, "incomum"),
    ("rocket_led", "Foguete com LED", "rocket", "roof", 70, 45, 16, 20000, 20, "incomum"),
    ("rocket_flat_neon", "Calha neon", "rocket", "roof", 55, 40, 16, 19000, 20, "incomum"),
    ("rocket_neon_dash", "Foguete neon tracejado", "rocket", "roof", 65, 45, 18, 22000, 20, "incomum"),
    ("rocket_frame", "Moldura de teto", "rocket", "roof", 110, 60, 26, 34000, 60, "rara"),
    ("boxlight_dash_r", "Contorno de luz – direita", "box_light_r", "right", 12, 15, 6, 6000, 0, "comum"),
    ("boxlight_dash_l", "Contorno de luz – esquerda", "box_light_l", "left", 12, 15, 6, 6000, 0, "comum"),
    ("boxlight_dash_top", "Contorno de luz – teto", "box_light_top", "roof", 12, 15, 6, 6000, 0, "comum"),
]
TEXTS = {
    "slot.rocket": "Foguete",
    "slot.box_light_r": "Contorno do baú – direita",
    "slot.box_light_l": "Contorno do baú – esquerda",
    "slot.box_light_top": "Contorno do baú – teto",
    "garage.box_only": "Só para baú fechado: neste caminhão a peça fica guardada (não aparece nem conta).",
}


def part_tres(pid, slot, zone, w, dur, fame, price, fame_min, rarity):
    return f'''[gd_resource type="Resource" script_class="PartDef" format=3]

[ext_resource type="Script" path="{PART_SCRIPT}" id="1_pd"]

[resource]
script = ExtResource("1_pd")
id = &"{pid}"
display_key = "part.{pid}"
slot = &"{slot}"
zones = PackedStringArray("{zone}")
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
    keys = dict(TEXTS)
    for pid, name, slot, zone, w, dur, fame, price, fmin, rar in PARTS:
        write(os.path.join(ROOT, "data", "parts", pid + ".tres"), part_tres(pid, slot, zone, w, dur, fame, price, fmin, rar))
        keys["part." + pid] = name
    path = os.path.join(ROOT, "data", "i18n", "pt-BR.json")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    d.update(keys)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"OK gen_t231_data: {len(PARTS)} pecas, {len(keys)} textos")


main()
