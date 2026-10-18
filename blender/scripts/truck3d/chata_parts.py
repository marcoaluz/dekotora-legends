"""Cabine "chata" (T-119): classifica cada peça solta da CF500 em um material NOSSO (ou descarta).

O STL não tem nomes nem cores; a classificação é por geometria: posição do centro (|x| = `ax`, y, z em coordenada
local de `chata_src`), tamanho, área e normal média. Onde a regra geral não basta, há "caixas de seleção" ajustadas
olhando os renders de conferência (blender/renders/t119/). A primeira regra que casa vence.

Categorias -> material (pbr.truck_set):
  paint   pintura (paint_white_panel: o jogo tinge pelo nome "paint_white")    drop  descartada
  wind    para-brisa (glass_wind)          glass  vidros laterais (glass)       trim  plástico texturizado (plastic_trim)
  black   plástico preto liso (plastic)    chrome cromo                          rubber borracha
  lamp_w  farol aceso (lamp_white)         lamp_a pisca/lanterna âmbar          lens  fundo do farol (glass_lens)
"""
from __future__ import annotations

MATERIAL = {"paint": "paint_white_panel", "wind": "glass_wind", "glass": "glass", "trim": "plastic_trim",
            "black": "plastic", "chrome": "chrome", "rubber": "rubber", "lamp_w": "lamp_white",
            "lamp_a": "lamp_amber", "lens": "glass_lens"}


def _in(v, r):
    return r[0] <= v <= r[1]


def box(ax=(-1, 9), y=(-9, 9), z=(-1, 9), dmax=99.0, amax=99.0, amin=0.0):
    """Centro dentro da caixa (|x|, y, z), maior dimensão <= dmax, área entre amin e amax."""
    def f(p):
        return (_in(p.ax, ax) and _in(float(p.c[1]), y) and _in(float(p.c[2]), z) and float(p.d.max()) <= dmax
                and amin <= p.area <= amax)
    return f


# (nome, categoria, condição). Medidas em metros, coordenada local (eixo da roda original em y = 0).
RULES = [
    # --- rodas originais (usamos as nossas) e tudo que é do cubo/porcas
    ("wheel", "drop", box(ax=(0.95, 1.6), y=(-0.15, 0.15), z=(0.35, 0.8), dmax=1.1)),
    # --- marca: letreiro na porta e losango na grade (apagados)
    ("logo_door", "drop", box(ax=(1.1, 1.25), y=(-0.35, 0.15), z=(1.62, 1.8), dmax=0.1)),
    ("logo_grille", "drop", box(ax=(0.0, 0.1), y=(1.15, 1.25), z=(1.17, 1.4), dmax=0.2)),
    ("logo_grille_tip", "drop", box(ax=(0.0, 0.05), y=(1.12, 1.2), z=(1.0, 1.17), dmax=0.1)),
    # --- interior escondido: piso da cabine e vidro de trás (fica dentro da extensão traseira)
    ("floor", "drop", lambda p: p.d[2] < 0.01 and p.area > 1.0 and _in(float(p.c[2]), (1.3, 1.5))),
    ("rear_window", "drop", box(ax=(0, 0.1), y=(-0.5, -0.4), z=(2.2, 2.5))),
    ("rear_lower", "paint", box(ax=(0, 0.1), y=(-0.5, -0.3), z=(0.8, 1.4), amin=1.0)),
    # --- retrovisores americanos (trocados pelos nossos) e seus braços
    ("mirror_us", "drop", box(ax=(1.2, 1.8), y=(0.6, 1.3), z=(1.8, 2.7))),
    ("mirror_arm_roof", "drop", box(ax=(0.9, 1.1), y=(0.1, 0.9), z=(2.6, 2.9))),
    ("mirror_arm_low", "drop", box(ax=(0.95, 1.12), y=(1.1, 1.2), z=(1.7, 1.9))),
    ("mirror_post", "drop", box(ax=(1.0, 1.15), y=(0.7, 0.9), z=(1.9, 2.5), amax=0.15)),
    # --- lanternas de teto (5): lente âmbar alta, base preta
    ("roof_lamp", "lamp_a", lambda p: box(ax=(0, 0.8), y=(0.4, 0.6), z=(2.7, 2.9), dmax=0.15)(p) and p.d[2] > 0.05),
    ("roof_lamp_plate", "drop", box(ax=(0, 0.1), y=(0.4, 0.6), z=(2.65, 2.75), amin=0.5)),
    ("roof_lamp_base", "black", box(ax=(0, 0.8), y=(0.4, 0.6), z=(2.7, 2.9))),
    # --- faróis: carcaça cromada, refletor escuro (o disco aceso é nosso: chata_extras), tampa descartada
    ("hl_cover", "drop", box(ax=(0.75, 1.0), y=(1.13, 1.17), z=(1.1, 1.32), amin=0.04)),
    ("hl_bulb", "lens", box(ax=(0.75, 1.0), y=(1.05, 1.13), z=(1.1, 1.32), dmax=0.2, amin=0.01, amax=0.1)),
    ("hl_glass", "drop", box(ax=(0.8, 0.95), y=(1.05, 1.12), z=(1.15, 1.25), amin=0.2, amax=0.3)),
    ("hl_house", "chrome", box(ax=(0.75, 1.0), y=(1.0, 1.15), z=(1.1, 1.32))),
    ("corner_amber", "lamp_a", box(ax=(1.05, 1.18), y=(1.05, 1.16), z=(1.05, 1.2))),
    ("corner_white", "lamp_w", box(ax=(1.05, 1.18), y=(1.05, 1.16), z=(1.2, 1.32))),
    # --- grade: barras e moldura cromadas, fundo preto
    ("grille_bar", "chrome", box(ax=(0.0, 0.65), y=(1.12, 1.18), z=(1.1, 1.3), dmax=0.2, amax=0.02)),
    ("grille_back", "black", box(ax=(0.0, 0.8), y=(1.0, 1.18), z=(1.1, 1.32), amin=0.14, amax=0.2)),
    ("grille_frame", "chrome", box(ax=(0.0, 0.1), y=(1.12, 1.2), z=(1.15, 1.25), amin=0.003)),
    ("grille_misc", "black", box(ax=(0.0, 0.8), y=(1.0, 1.18), z=(1.1, 1.32), dmax=1.6)),
    # --- limpadores
    ("wiper", "black", box(ax=(0.0, 1.0), y=(1.05, 1.16), z=(1.8, 2.05), dmax=0.6)),
    # --- para-brisa (vidro grande) e moldura preta
    ("windshield", "wind", box(ax=(0, 0.1), y=(0.85, 1.0), z=(2.1, 2.3), amin=1.0)),
    ("windshield_frame", "black", box(ax=(0, 0.1), y=(0.85, 1.0), z=(2.1, 2.3))),
    # --- para-choque, painel de baixo, frisos
    ("bumper", "trim", box(ax=(0, 0.1), y=(1.05, 1.25), z=(0.6, 1.0), amin=1.0)),
    ("front_lower", "black", box(ax=(0, 0.1), y=(0.95, 1.1), z=(0.7, 1.0))),
    ("seam", "black", lambda p: p.ax < 0.1 and p.d[0] > 2.0 and p.d[2] < 0.05 and p.area < 0.2),
    # --- para-lama, forro, degrau, protetor de lama
    ("fender", "trim", box(ax=(1.0, 1.2), y=(0.0, 0.4), z=(0.8, 1.3), amin=0.5)),
    ("wheel_liner", "black", box(ax=(0.6, 0.95), y=(-0.5, 0.5), z=(0.6, 1.2))),
    ("step", "trim", box(ax=(0.9, 1.2), y=(0.6, 1.0), z=(0.5, 1.0))),
    ("mudflap", "rubber", box(ax=(0.8, 1.2), y=(-0.7, -0.4), z=(0.3, 0.7))),
    # --- portas: vidro de fora, canaleta preta, chapa da porta (peça própria) pintada
    ("door_glass", "glass", box(ax=(1.05, 1.12), y=(0.3, 0.42), z=(2.1, 2.22), amin=0.6, amax=0.8)),
    ("door_channel", "black", box(ax=(1.05, 1.12), y=(0.3, 0.42), z=(2.1, 2.22), amin=0.3, amax=0.6)),
    ("door_panel", "paint", box(ax=(1.05, 1.15), y=(0.3, 0.42), z=(1.95, 2.1))),
    # --- porta: maçaneta preta
    ("door_handle", "black", box(ax=(1.08, 1.2), y=(-0.3, 0.0), z=(1.45, 1.65))),
]


def classify(parts) -> dict:
    """Preenche `p.cat`/`p.rule` em cada peça. Sem regra: área grande = pintura, pequena = plástico preto."""
    count = {}
    for p in parts:
        for name, cat, cond in RULES:
            if cond(p):
                p.cat, p.rule = cat, name
                break
        else:
            p.cat, p.rule = ("paint", "default_big") if p.area > 0.25 else ("black", "default_small")
        count[p.cat] = count.get(p.cat, 0) + 1
    return count
