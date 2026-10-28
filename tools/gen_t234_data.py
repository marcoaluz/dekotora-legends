"""Dados das peças da oficina, lote 5 (T-234): 3 calotas, 3 escapamentos, 3 grades, 3 buzinas e 3 interiores (.tres),
os textos pt-BR (peças, encaixes novos e os 11 adesivos novos). Números = PROPOSTA (docs/BALANCEAMENTO.md, seção T-234),
na mesma régua dos lotes anteriores (cor de fábrica grátis, raridade sem trava).

Uso (raiz do projeto, Python do sistema, só biblioteca padrão):  python tools/gen_t234_data.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
PART_SCRIPT = "res://scripts/data/part_def.gd"

W, F, S, R = "wheels", "front", "left\", \"right", "roof"
# id, nome, encaixe (slot), zona de dano, peso kg, durabilidade, destaque, preço ¥, fama mínima (informativa), raridade, buzina
PARTS = [
    ("hub_led_ring", "Disco cromado com anel de LED", "hubcaps", W, 48, 70, 18, 26000, 20, "incomum", ""),
    ("hub_star_gold", "Estrela cromada no aro dourado", "hubcaps", W, 46, 75, 16, 24000, 20, "incomum", ""),
    ("hub_neon_spinner", "Calota funda com neon e spinner", "hubcaps", W, 52, 65, 22, 32000, 60, "rara", ""),
    ("stack_neon_twin", "Chaminé dupla com ponta neon", "exhaust_stacks", S, 95, 60, 20, 30000, 20, "incomum", ""),
    ("stack_j_amber", "Chaminé em J com fendas âmbar", "exhaust_stacks", S, 85, 60, 20, 30000, 20, "incomum", ""),
    ("stack_side_triple", "Saída lateral tripla acesa", "exhaust_stacks", S, 60, 50, 14, 20000, 0, "comum", ""),
    ("grille_bars_led", "Barras cromadas com LED", "grille", F, 55, 50, 12, 16000, 0, "comum", ""),
    ("grille_honey_sun", "Colmeia dourada com moldura de LED", "grille", F, 60, 50, 16, 22000, 20, "incomum", ""),
    ("grille_slats_neon", "Lâminas douradas com neon", "grille", F, 58, 50, 14, 19000, 0, "comum", ""),
    ("horn_triple", "Corneta tripla cromada", "horn", R, 22, 40, 10, 12000, 0, "comum", "horn_musical_dekotora"),
    ("horn_twin_long", "Par de cornetas douradas", "horn", R, 20, 40, 10, 12000, 0, "comum", "horn_dual_tone"),
    ("horn_ship", "Buzina de navio com aro âmbar", "horn", R, 30, 45, 14, 18000, 20, "incomum", "horn_ship_deep"),
    ("interior_curtain", "Cortina franzida vermelha", "interior", F, 0, 0, 8, 9000, 0, "comum", ""),
    ("interior_chandelier", "Lustre de cristal âmbar", "interior", F, 0, 0, 14, 18000, 20, "incomum", ""),
    ("interior_tufted", "Estofado capitonê com neon", "interior", F, 0, 0, 16, 24000, 20, "incomum", ""),
]
TEXTS = {
    "slot.horn": "Buzina (em cima da viseira)",
    "slot.interior": "Interior da cabine",
    "garage.horn_side": "Cornetas:",
    "garage.horn_side.both": "Dos dois lados",
    "garage.horn_side.left": "Só à esquerda",
    "garage.horn_side.right": "Só à direita",
    "garage.cab_art": "Adesivo na lataria da frente (faixa abaixo do para-brisa):",
    "garage.cab_art.none": "Sem adesivo",
    "garage.cab_art.12": "Ondas",
    "garage.cab_art.13": "Sakura",
    "garage.cab_art.14": "Raios",
    "garage.cab_art.15": "Nuvens",
    "garage.no_horn_spot": "A cabine americana não tem lugar para a buzina em cima da viseira (ela fica guardada).",
    "decal.decal_frase_01": "一番星 (estrela nº 1)",
    "decal.decal_frase_02": "男花道 (caminho de honra)",
    "decal.decal_frase_03": "爆走 (corrida louca)",
    "decal.decal_frase_04": "御意見無用 (dispenso opinião)",
    "decal.decal_frase_05": "唯我独尊 (único no mundo)",
    "decal.decal_frase_06": "義理人情 (dever e coração)",
    "decal.decal_frase_07": "浪漫街道 (estrada romântica)",
    "decal.decal_frase_08": "天下御免 (licença do mundo)",
    "decal.decal_frase_09": "夜明けまで (até o amanhecer)",
    "decal.decal_labaredas": "Labaredas",
    "decal.decal_sol_nascente": "Sol nascente sobre ondas",
}


def part_tres(pid, slot, zone, w, dur, fame, price, fame_min, rarity, horn):
    extra = f'horn = "{horn}"\n' if horn else ""
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
{extra}rarity = &"{rarity}"
fame_min = {fame_min}
'''


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    keys = dict(TEXTS)
    for pid, name, slot, zone, w, dur, fame, price, fmin, rar, horn in PARTS:
        write(os.path.join(ROOT, "data", "parts", pid + ".tres"), part_tres(pid, slot, zone, w, dur, fame, price, fmin, rar, horn))
        keys["part." + pid] = name
    path = os.path.join(ROOT, "data", "i18n", "pt-BR.json")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    d.update(keys)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"OK gen_t234_data: {len(PARTS)} pecas, {len(keys)} textos")


main()
