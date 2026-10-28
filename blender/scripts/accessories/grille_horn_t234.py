"""Grades e buzinas da oficina, lote 5 (T-234): 3 + 3 peças, pelas propostas da seção 19 de docs/REFERENCIA_PECAS.md.

Grade: origem = centro do encaixe `grille`, nas costas da peça (encosta no ponto mais à frente da cabine entre os
faróis). Tamanho nominal GW x GH; o jogo estica a largura e a altura até a caixa de cada cabine (1,0–1,5 m x
0,5–1,4 m; fit "grille", `game/scripts/truck/lot5_fit.gd`). O que tem prefixo CEN_ (o sol do meio) não deforma:
fica com a menor das duas escalas. A colmeia é textura (`deco_honey`), repetida pelo tamanho real (favo não estica).
Buzina: origem = topo da carga logo atrás da frente (encaixe `horn`), cornetas apontando para a frente (+Y). Cabe em
x +-0,30, y +-0,30, até 0,40 m de altura; a base desce 6 cm (topo de tanque redondo).
Desenho nosso.
"""
from __future__ import annotations

import math

from lib import mesh3d as M

from . import t211_kit as K
from . import t234_kit as Z

GW, GH, GD = 1.30, 0.80, 0.09


def _frame(m, mat, bar=0.05, depth=0.05):
    """Moldura retangular (4 barras) na borda da grade."""
    o = []
    for k, (sx, sz, x, z) in enumerate(((GW, bar, 0, GH / 2 - bar / 2), (GW, bar, 0, -GH / 2 + bar / 2),
                                        (bar, GH - 2 * bar, GW / 2 - bar / 2, 0), (bar, GH - 2 * bar, -GW / 2 + bar / 2, 0))):
        o.append(M.box(f"frame_{k}", (sx, depth, sz), (x, depth / 2, z), mat, bevel=0.01, seg=1))
    return o


def _back(m, mat=None):
    return M.box("back", (GW - 0.02, 0.012, GH - 0.02), (0, 0.006, 0), mat or m["trim"], bevel=0.004, seg=1)


def grille_bars_led(m):
    """Barras verticais cromadas com friso de LED em cima."""
    o = [_back(m)] + _frame(m, m["body"], bar=0.06, depth=0.055)
    n = 15
    for k in range(n):
        x = -GW / 2 + 0.10 + k * (GW - 0.20) / (n - 1)
        o.append(M.box(f"bar_{k}", (0.032, 0.05, GH - 0.20), (x, 0.03, -0.02), m["chrome"], bevel=0.012, seg=2))
    face = K.Face((GW / 2 - 0.06, 0.056, GH / 2 - 0.055), (-(GW - 0.12), 0, 0), (0, 0, 0.05))
    o.append(K.quad_panel("led_back", face, 0.0, 0.0, 1.0, 1.0, m["trim"], off=0.002, depth=0.004))
    o.append(K.led_grid("led", face, 0.01, 0.12, 0.99, 0.88, 22, 1, m["led"], fill=0.7, off=0.016, depth=0.012))
    return o


def grille_honey_sun(m):
    """Colmeia dourada com sol aceso no meio."""
    o = [_back(m, m["trim"])] + _frame(m, m["gold"], bar=0.055, depth=0.06)
    # colmeia: placa com a textura de favos (UV em repetições de HONEY_CELL; o jogo ajusta à escala real)
    hw, hh = GW / 2 - 0.055, GH / 2 - 0.055
    honey = M.box("honey", (2 * hw, 0.008, 2 * hh), (0, 0.03, 0), m["honey"], bevel=0.0, seg=1)
    _uv_box_front(honey, 2 * hw / Z.HONEY_CELL, 2 * hh / Z.HONEY_CELL)
    o.append(honey)
    # sol (não estica: CEN_)
    sun = [M.cylinder("sun_disc", 0.13, 0.03, (0, 0.065, 0), m["amber"], axis="Y", seg=20),
           M.torus("sun_rim", 0.14, 0.014, (0, 0.07, 0), m["gold"], axis="Y", seg=20, tube_seg=5)]
    for k in range(12):
        a = 2 * math.pi * k / 12
        ln = 0.10 if k % 2 == 0 else 0.07
        r0 = 0.16 + ln / 2
        sun.append(M.box(f"ray_{k}", (0.025, 0.02, ln), (math.sin(a) * r0, 0.065, math.cos(a) * r0), m["gold"],
                         bevel=0.006, seg=1, rot=(0, math.degrees(a), 0)))
    o += Z.tag(sun, "CEN")
    return o


def _uv_box_front(o, su, sv):
    """UV da caixa: (x, z) -> (0..su, 0..sv) (a textura se repete su x sv vezes no tamanho nominal)."""
    me = o.data
    if not me.uv_layers:
        me.uv_layers.new()
    uv = me.uv_layers.active.data
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = ((v.x - x0) / (x1 - x0) * su, (v.z - z0) / (z1 - z0) * sv)


def grille_slats_neon(m):
    """Lâminas douradas inclinadas com colunas de neon nos lados."""
    o = [_back(m)] + _frame(m, m["body"], bar=0.05, depth=0.05)
    n = 9
    inner = GH - 0.14
    for k in range(n):
        z = -inner / 2 + 0.03 + k * (inner - 0.06) / (n - 1)
        o.append(M.box(f"slat_{k}", (GW - 0.26, 0.05, 0.035), (0, 0.035, z), m["gold"], bevel=0.008, seg=1, rot=(28, 0, 0)))
    for sx in (-1, 1):
        x = sx * (GW / 2 - 0.085)
        o.append(M.box(f"col_{sx}", (0.05, 0.03, GH - 0.12), (x, 0.03, 0), m["trim"], bevel=0.006, seg=1))
        o.append(Z.Q.tubes(f"neon_{sx}", [((x, 0.05, -GH / 2 + 0.08), (x, 0.05, GH / 2 - 0.08))], 0.014, m["neon"], seg=8))
    return o


# ----------------------------------------------------------------------------- buzinas

def _base(m, w=0.46, d=0.56):
    """Chapa da base (na cor da peça) com saia que desce 6 cm (encosta no topo curvo do tanque)."""
    return [M.box("base", (w, d, 0.04), (0, 0, 0.02), m["body"], bevel=0.01, seg=1),
            M.box("skirt", (w - 0.04, d - 0.04, 0.06), (0, 0, -0.03), m["trim"], bevel=0.006, seg=1)]


def horn_triple(m):
    """Corneta tripla cromada (3 notas): 3 cornetas de tamanhos diferentes lado a lado."""
    o = _base(m)
    for k, (x, ln, rb) in enumerate(((-0.13, 0.40, 0.055), (0.0, 0.50, 0.065), (0.13, 0.58, 0.075))):
        o.append(Z.trumpet(f"horn_{k}", ln, 0.022, rb, m["chrome"], loc=(x, -0.28, 0.17), seg=14))
        o.append(M.box(f"post_{k}", (0.04, 0.05, 0.11), (x, -0.16, 0.095), m["body"], bevel=0.008, seg=1))
    o.append(M.box("valve", (0.36, 0.08, 0.07), (0, -0.25, 0.10), m["chrome"], bevel=0.015, seg=1))
    return o


def horn_twin_long(m):
    """Par de cornetas longas douradas."""
    o = _base(m, w=0.44)
    for k, x in enumerate((-0.11, 0.11)):
        o.append(Z.trumpet(f"horn_{k}", 0.58, 0.024, 0.08, m["gold"], loc=(x, -0.29, 0.16), seg=16))
        for y in (-0.16, 0.08):
            o.append(M.box(f"post_{k}_{y}", (0.035, 0.04, 0.10), (x, y, 0.085), m["chrome"], bevel=0.008, seg=1))
    o.append(M.box("valve", (0.30, 0.07, 0.06), (0, -0.25, 0.10), m["chrome"], bevel=0.012, seg=1))
    return o


def horn_ship(m):
    """Buzina de navio: um sino grande apontando para a frente com aro âmbar aceso."""
    o = _base(m, w=0.40, d=0.50)
    prof = [(0.05, -0.26), (0.05, -0.12), (0.06, -0.05), (0.09, 0.05), (0.13, 0.13), (0.17, 0.19), (0.165, 0.205),
            (0.11, 0.17)]
    o.append(Z.lathe("bell", prof, m["chrome"], axis="Y", seg=18, loc=(0, 0.03, 0.22), cap0=True))
    o.append(M.torus("amber_ring", 0.168, 0.016, (0, 0.235, 0.22), m["amber"], axis="Y", seg=20, tube_seg=5))
    o.append(M.box("post", (0.06, 0.16, 0.16), (0, -0.10, 0.10), m["body"], bevel=0.01, seg=1))
    o.append(M.cylinder("cap", 0.07, 0.05, (0, -0.24, 0.22), m["gold"], axis="Y", seg=14, bevel=0.01, bevel_seg=1))
    return o


def _g(pid, name, build, color="cromo_ciano"):
    return {"id": pid, "name": name, "build": build, "kind": "grille", "slot": "grille", "socket": "grille", "fit": "grille",
            "default_color": color, "folder": "grille_t234", "nominal": [GW, GH, GD]}


def _h(pid, name, build, horn, color="cromo_ciano"):
    return {"id": pid, "name": name, "build": build, "kind": "horn", "slot": "horn", "socket": "horn", "fit": "horn",
            "default_color": color, "folder": "horn_t234", "horn": horn}


PARTS = [
    _g("grille_bars_led", "Barras cromadas com friso de LED", grille_bars_led),
    _g("grille_honey_sun", "Colmeia dourada com sol aceso", grille_honey_sun, "preto_ciano"),
    _g("grille_slats_neon", "Lâminas douradas com neon", grille_slats_neon, "preto_rosa"),
    _h("horn_triple", "Corneta tripla cromada", horn_triple, "horn_musical_dekotora"),
    _h("horn_twin_long", "Par de cornetas douradas", horn_twin_long, "horn_dual_tone", "preto_ciano"),
    _h("horn_ship", "Buzina de navio com aro âmbar", horn_ship, "horn_ship_deep"),
]
