"""Dados das peças da oficina, lote 4 (T-233): 11 para-choques da frente, 6 retrovisores, 3 escadas e 8 saias (.tres) e os
textos pt-BR. Números = proposta do catálogo (docs/REFERENCIA_PECAS.md, seções 3, 5, 8 e 9).

Uso (raiz do projeto, Python do sistema, só biblioteca padrão):  python tools/gen_t233_data.py
Regra do Marco (decisão 4): raridade e "fama mínima" ficam nos dados, mas NÃO travam a compra (fame_required = 0).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
PART_SCRIPT = "res://scripts/data/part_def.gd"

# id, nome, encaixe (slot), zona de dano, peso kg, durabilidade, destaque, preço ¥, fama mínima (informativa), raridade
F, S = "front", "left\", \"right"
PARTS = [
    ("fb_fan_plate", "Leque baixo com placa", "front_bumper", F, 280, 180, 16, 26000, 20, "incomum"),
    ("fb_fan_amber", "Leque com caixas âmbar", "front_bumper", F, 300, 190, 18, 29000, 20, "incomum"),
    ("fb_fan_red", "Leque de luz vermelha", "front_bumper", F, 280, 180, 16, 27000, 20, "incomum"),
    ("fb_fan_gold", "Leque de caixas douradas", "front_bumper", F, 320, 200, 22, 36000, 60, "rara"),
    ("fb_fan_stripe", "Leque de faixas rosa", "front_bumper", F, 290, 180, 18, 29000, 20, "incomum"),
    ("fb_fan_chrome", "Leque cromado", "front_bumper", F, 330, 210, 20, 38000, 60, "rara"),
    ("fb_box_amber", "Caixa alta âmbar", "front_bumper", F, 380, 240, 22, 42000, 60, "rara"),
    ("fb_box_steps", "Caixa alta com degraus", "front_bumper", F, 400, 250, 24, 46000, 60, "rara"),
    ("fb_smooth_chrome", "Cromado liso", "front_bumper", F, 350, 230, 18, 36000, 60, "rara"),
    ("fb_deck_checker", "Deque de chapa xadrez", "front_bumper", F, 450, 260, 30, 58000, 120, "lendaria"),
    ("fb_deck_neon", "Deque xadrez com neon largo", "front_bumper", F, 470, 260, 34, 64000, 120, "lendaria"),
    ("mirror_stay_l", "Haste em L", "mirror_stay", F, 25, 40, 6, 7000, 0, "comum"),
    ("mirror_stay_truss", "Haste treliçada", "mirror_stay", F, 35, 40, 10, 12000, 0, "comum"),
    ("mirror_stay_frame", "Moldura retangular", "mirror_stay", F, 35, 45, 9, 11000, 0, "comum"),
    ("mirror_stay_box", "Moldura grossa", "mirror_stay", F, 45, 55, 10, 14000, 0, "comum"),
    ("mirror_stay_chain", "Treliça vazada", "mirror_stay", F, 40, 40, 12, 16000, 20, "incomum"),
    ("mirror_stay_grand", "Moldura gigante", "mirror_stay", F, 60, 45, 18, 26000, 20, "incomum"),
    ("ladder_neon", "Escada de neon", "ladder", S, 30, 30, 12, 14000, 0, "comum"),
    ("ladder_green", "Escada de luzes verdes", "ladder", S, 30, 30, 12, 14000, 0, "comum"),
    ("ladder_chrome", "Escada cromada", "ladder", S, 45, 50, 10, 16000, 20, "incomum"),
    ("skirt_chrome_rails", "Trilhos cromados", "side_skirts", S, 240, 190, 14, 28000, 20, "incomum"),
    ("skirt_neon_twin", "Neon de 2 linhas", "side_skirts", S, 120, 80, 16, 20000, 20, "incomum"),
    ("skirt_neon_diamond", "Corrente de losangos", "side_skirts", S, 130, 80, 18, 24000, 20, "incomum"),
    ("skirt_neon_dash", "Neon tracejado duplo", "side_skirts", S, 130, 80, 18, 24000, 20, "incomum"),
    ("skirt_neon_arch", "Neon com arco da roda", "side_skirts", S, 140, 85, 22, 30000, 60, "rara"),
    ("skirt_neon_green", "Traços verdes e ciano", "side_skirts", S, 130, 80, 18, 25000, 20, "incomum"),
    ("skirt_neon_gems", "Pedras de luz", "side_skirts", S, 150, 85, 22, 32000, 60, "rara"),
    ("skirt_neon_arrows", "Setas duplas", "side_skirts", S, 150, 85, 24, 34000, 60, "rara"),
]
TEXTS = {
    "slot.mirror_stay": "Retrovisor",
    "slot.ladder": "Escada da cabine (ao lado da porta)",
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
    print(f"OK gen_t233_data: {len(PARTS)} pecas, {len(keys)} textos")


main()
