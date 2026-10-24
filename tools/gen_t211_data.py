"""Dados das peças da oficina, lote 1 (T-211): 17 deques + 14 viseiras (.tres), a tabela de cores L/R (.tres) e os
textos pt-BR. Números = proposta do catálogo (docs/REFERENCIA_PECAS.md, seções 1 e 2; cores na seção 18).

Uso (raiz do projeto, Python do sistema, só biblioteca padrão):  python tools/gen_t211_data.py
Regra do Marco (decisão 4): raridade e "fama mínima" ficam nos dados, mas NÃO travam a compra (fame_required = 0).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
PART_SCRIPT = "res://scripts/data/part_def.gd"
COLOR_SCRIPT = "res://scripts/data/deco_color_def.gd"

# id, nome, peso kg, durabilidade, destaque, preço ¥, fama mínima (informativa), raridade
DECKS = [
    ("deck_cap_trio", "Capa de teto com 3 luzes", 35, 30, 8, 9000, 0, "comum"),
    ("deck_kanji_rail", "Deque com letreiro e grade", 70, 40, 16, 18000, 20, "incomum"),
    ("deck_led_box", "Deque LED com letreiro", 85, 40, 22, 26000, 20, "incomum"),
    ("deck_led_panel", "Deque LED com painel liso", 85, 45, 20, 24000, 20, "incomum"),
    ("deck_led_cyan", "Deque LED com tela ciano", 80, 40, 22, 25000, 20, "incomum"),
    ("deck_art_band", "Deque com faixa e pinturas", 100, 45, 30, 36000, 60, "rara"),
    ("deck_led_columns", "Deque LED com colunas", 95, 45, 26, 32000, 60, "rara"),
    ("deck_lace", "Deque com renda", 100, 45, 28, 34000, 60, "rara"),
    ("deck_triple_sign", "Deque de 3 letreiros", 110, 45, 32, 40000, 60, "rara"),
    ("deck_eyebrow", "Deque com sobrancelhas neon", 95, 40, 30, 38000, 60, "rara"),
    ("deck_pillars", "Deque de colunas neon", 100, 45, 30, 38000, 60, "rara"),
    ("deck_cyan_frame", "Deque com moldura neon", 105, 45, 32, 42000, 60, "rara"),
    ("deck_painted_wings", "Deque com asas pintadas", 120, 50, 40, 56000, 120, "lendaria"),
    ("deck_pods_square", "Par de canhões de luz quadrados", 45, 35, 14, 16000, 20, "incomum"),
    ("deck_pods_round", "Par de canhões de luz redondos", 45, 35, 14, 16000, 20, "incomum"),
    ("deck_pods_long", "Par de canhões longos", 55, 35, 18, 22000, 20, "incomum"),
    ("deck_pods_five", "Bateria de 5 canhões", 80, 40, 26, 32000, 60, "rara"),
]
VISORS = [
    ("visor_lamp_row", "Viseira com 8 lanternas", 45, 45, 10, 12000, 0, "comum"),
    ("visor_dash_short", "Viseira neon pontilhada", 40, 40, 8, 9000, 0, "comum"),
    ("visor_dash_long", "Viseira neon tracejada", 40, 40, 9, 10000, 0, "comum"),
    ("visor_twin_line", "Viseira de 2 linhas", 40, 40, 10, 11000, 0, "comum"),
    ("visor_morse", "Viseira traço-ponto", 40, 40, 10, 11000, 0, "comum"),
    ("visor_single_line", "Viseira de 1 linha", 40, 40, 7, 8000, 0, "comum"),
    ("visor_v_step", "Viseira em V com degraus", 55, 45, 16, 18000, 20, "incomum"),
    ("visor_v_band", "Viseira em V larga", 55, 45, 15, 17000, 20, "incomum"),
    ("visor_v_split", "Viseira em V partida", 55, 45, 16, 18000, 20, "incomum"),
    ("visor_v_chevron", "Viseira de 3 chevrons", 60, 45, 20, 24000, 20, "incomum"),
    ("visor_split_bars", "Viseira de 2 barras", 45, 40, 12, 14000, 0, "comum"),
    ("visor_chrome_v", "Viseira cromada em V", 80, 70, 14, 22000, 20, "incomum"),
    ("visor_chrome_louver", "Viseira cromada de lâminas", 95, 80, 22, 34000, 60, "rara"),
    ("visor_neon_frame", "Moldura neon da cabine", 50, 35, 22, 28000, 20, "incomum"),
]
# Tabela de cores L/R (proposta, seção 18 do catálogo): id, nome, faixa, preço, estrutura, painel, LED, neon, amostra
COLORS = [
    ("preto_ciano", "Preto + ciano", "comum", 2000, "deco_black", "deco_black", "lamp_green", "lamp_cyan", "#15171c", "#21e6ff"),
    ("preto_verde", "Preto + verde", "comum", 2000, "deco_black", "deco_black", "lamp_green", "lamp_green", "#15171c", "#3dff7a"),
    ("branco_azul", "Branco + azul", "comum", 2000, "deco_white", "deco_navy", "lamp_blue", "lamp_blue", "#e9eef5", "#2f7bff"),
    ("prata_marinho", "Prata + azul-marinho", "comum", 2000, "deco_silver", "deco_navy", "lamp_green", "lamp_blue", "#b9c2d0", "#1d2f6b"),
    ("cromo_ciano", "Cromo + ciano", "metalica", 6000, "chrome", "deco_black", "lamp_green", "lamp_cyan", "#e6ebf2", "#21e6ff"),
    ("cromo_rosa", "Cromo + rosa", "metalica", 6000, "chrome", "deco_black", "lamp_pink", "lamp_pink", "#e6ebf2", "#ff2e88"),
    ("dourado_ambar", "Dourado + âmbar", "metalica", 6000, "paint_gold", "deco_black", "lamp_amber", "lamp_amber", "#f0b83a", "#ffb347"),
    ("grafite_violeta", "Grafite + violeta", "metalica", 6000, "deco_gunmetal", "deco_black", "lamp_violet", "lamp_violet", "#4a505c", "#a35cff"),
    ("preto_rosa", "Preto + rosa neon", "neon", 8000, "deco_black", "deco_black", "lamp_pink", "lamp_pink", "#15171c", "#ff2e88"),
    ("vermelho_amarelo", "Vermelho + amarelo neon", "neon", 8000, "deco_red", "deco_black", "lamp_yellow", "lamp_yellow", "#c8202f", "#fff35c"),
]


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


def _col(hx):
    h = hx.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, 1)"


def color_tres(c):
    cid, name, tier, price, body, trim, led, neon, sw_a, sw_b = c
    return f'''[gd_resource type="Resource" script_class="DecoColorDef" format=3]

[ext_resource type="Script" path="{COLOR_SCRIPT}" id="1_dc"]

[resource]
script = ExtResource("1_dc")
id = &"{cid}"
display_key = "deco_color.{cid}"
tier = &"{tier}"
price = {price}
body = "{body}"
trim = "{trim}"
led = "{led}"
neon = "{neon}"
swatch_a = {_col(sw_a)}
swatch_b = {_col(sw_b)}
'''


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    keys = {}
    for rows, slot, zone in ((DECKS, "andon", "roof"), (VISORS, "visor", "front")):
        for pid, name, w, dur, fame, price, fmin, rar in rows:
            write(os.path.join(ROOT, "data", "parts", pid + ".tres"), part_tres(pid, slot, zone, w, dur, fame, price, fmin, rar))
            keys["part." + pid] = name
    for c in COLORS:
        write(os.path.join(ROOT, "data", "deco_colors", c[0] + ".tres"), color_tres(c))
        keys["deco_color." + c[0]] = c[1]
    path = os.path.join(ROOT, "data", "i18n", "pt-BR.json")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    d.update(keys)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"OK gen_t211_data: {len(DECKS) + len(VISORS)} pecas, {len(COLORS)} cores, {len(keys)} textos")


main()
