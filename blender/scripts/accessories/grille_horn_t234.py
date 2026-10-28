"""Grades e buzinas da oficina, lote 5 (T-234): 3 + 3 peças (seção 19 de docs/REFERENCIA_PECAS.md).

Grade (refeita com a referência do Marco, docs/Referencias/grade_t234/: a "pintura geral" do original, com painel
pintado/aceso e emblema de asas no meio da grade): painel de acrílico ACESO com arte (atlas da T-211), barras ou
lâminas por cima, fileiras de LED (cor de luz separada da cor da peça, T-214) e emblema de asas com miolo aceso.
Origem = centro do encaixe `grille`, nas costas da peça (encosta no ponto mais à frente da cabine entre os faróis).
Tamanho nominal GW x GH; o jogo estica a largura e a altura até a caixa de cada cabine (fit "grille",
`game/scripts/truck/lot5_fit.gd`). O que tem prefixo CEN_ (o emblema) não deforma: fica com a menor das duas escalas.
Buzina (pedido do Marco: mais para a frente, perto do quebra-sol): origem = costas na testa da cabine, EM CIMA da
viseira (encaixe `horn`); cornetas deitadas apontando para a frente (+Y). Cabe em x +-0,30, até 0,62 m para a frente
e 0,26 m de altura.
Desenho nosso.
"""
from __future__ import annotations

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


def _emblem(m, name, scale=1.0, y=0.075, z=0.0, fill="neon", frame="chrome"):
    """Emblema de asas (asas cromadas/douradas com miolo aceso na cor de luz escolhida). Grupo CEN_: não deforma."""
    k = scale
    wing = [(0.0, 0.085), (0.09, 0.035), (0.30, 0.075), (0.36, 0.055), (0.21, -0.02), (0.07, -0.05), (0.0, -0.095),
            (-0.07, -0.05), (-0.21, -0.02), (-0.36, 0.055), (-0.30, 0.075), (-0.09, 0.035)]
    inner = [(0.0, 0.05), (0.07, 0.02), (0.24, 0.045), (0.15, -0.005), (0.05, -0.03), (0.0, -0.06), (-0.05, -0.03),
             (-0.15, -0.005), (-0.24, 0.045), (-0.07, 0.02)]
    o = [M.plane_extrude(name + "_frame", [(x * k, zz * k + z) for x, zz in wing], 0.03, (0, y, 0), m[frame], bevel=0.006),
         M.plane_extrude(name + "_fill", [(x * k, zz * k + z) for x, zz in inner], 0.03, (0, y + 0.012, 0), m[fill], bevel=0.0)]
    return Z.tag(o, "CEN")


RING = 0.03        # m: largura do contorno de LED por fora da moldura (T-256)


def _led_ring(m):
    """T-256 (pedido do Marco): contorno de LED em volta da grade inteira, numa moldura fina por fora (cor dos LEDs
    separada da cor da peça, como as outras luzes). Fica dentro da folga de 3 cm que o jogo deixa em cada lado."""
    o = []
    W2, H2, d = GW / 2 + RING, GH / 2 + RING, 0.03
    for k, (sx, sz, x, z) in enumerate(((2 * W2, RING, 0, H2 - RING / 2), (2 * W2, RING, 0, -H2 + RING / 2),
                                        (RING, 2 * H2 - 2 * RING, W2 - RING / 2, 0), (RING, 2 * H2 - 2 * RING, -W2 + RING / 2, 0))):
        o.append(M.box(f"ring_{k}", (sx, d, sz), (x, d / 2, z), m["trim"], bevel=0.004, seg=1))
    rows = ((W2 - 0.005, H2 - RING, 2 * W2 - 0.01, 30, 1), (W2 - 0.005, -H2, 2 * W2 - 0.01, 30, 1))
    for k, (x0, z0, w, cols, _r) in enumerate(rows):
        face = K.Face((x0, d, z0), (-w, 0, 0), (0, 0, RING))
        o.append(K.led_grid(f"ring_led_h{k}", face, 0.0, 0.1, 1.0, 0.9, cols, 1, m["led"], fill=0.6, off=0.004, depth=0.008))
    for k, sx in enumerate((1, -1)):
        face = K.Face((sx * W2 - (RING if sx > 0 else 0.0), d, -H2 + RING), (RING, 0, 0), (0, 0, 2 * H2 - 2 * RING))
        if sx > 0:
            face = K.Face((W2, d, -H2 + RING), (-RING, 0, 0), (0, 0, 2 * H2 - 2 * RING))
        else:
            face = K.Face((-W2 + RING, d, -H2 + RING), (-RING, 0, 0), (0, 0, 2 * H2 - 2 * RING))
        o.append(K.led_grid(f"ring_led_v{k}", face, 0.1, 0.0, 0.9, 1.0, 1, 18, m["led"], fill=0.6, off=0.004, depth=0.008))
    return o


def _led_row(m, name, face_y, zc, cols=26, h=0.034, x_in=0.05):
    face = K.Face((GW / 2 - x_in, face_y, zc - h / 2), (-(GW - 2 * x_in), 0, 0), (0, 0, h))
    return K.led_grid(name, face, 0.0, 0.0, 1.0, 1.0, cols, 1, m["led"], fill=0.72, off=0.004, depth=0.010)


def _art(m, cell, inset=0.07, y=0.014):
    """Painel de acrílico aceso por dentro com arte (atlas da T-211: 12 ondas, 13 sakura, 14 raios, 15 nuvens)."""
    face = K.Face((GW / 2 - inset, y, -GH / 2 + inset), (-(GW - 2 * inset), 0, 0), (0, 0, GH - 2 * inset))
    return K.art_panel("art", face, 0.0, 0.0, 1.0, 1.0, m, cell)


def grille_bars_led(m):
    """Barras cromadas sobre painel aceso de ondas, fileiras de LED em cima e embaixo e emblema de asas."""
    o = [_back(m), _art(m, 12)] + _frame(m, m["body"], bar=0.07, depth=0.065)
    n = 7
    for k in range(n):
        z = -GH / 2 + 0.12 + k * (GH - 0.24) / (n - 1)
        o.append(Z.Q.tubes(f"bar_{k}", [((-GW / 2 + 0.07, 0.045, z), (GW / 2 - 0.07, 0.045, z))], 0.014, m["chrome"], seg=8))
    for sx in (-1, 1):
        o.append(M.box(f"post_{sx}", (0.03, 0.035, GH - 0.14), (sx * GW / 4, 0.045, 0), m["chrome"], bevel=0.008, seg=1))
    o.append(_led_row(m, "led_top", 0.066, GH / 2 - 0.035))
    o.append(_led_row(m, "led_bot", 0.066, -GH / 2 + 0.035))
    o += _emblem(m, "emb", 1.0, y=0.08)
    o += _led_ring(m)
    return o


def grille_honey_sun(m):
    """Painel aceso de sakura numa moldura dourada cravejada de LED (4 lados), com emblema de asas grande."""
    o = [_back(m, m["trim"]), _art(m, 13, inset=0.075)] + _frame(m, m["gold"], bar=0.075, depth=0.07)
    o.append(_led_row(m, "led_top", 0.071, GH / 2 - 0.0375, cols=22))
    o.append(_led_row(m, "led_bot", 0.071, -GH / 2 + 0.0375, cols=22))
    for sx in (-1, 1):
        x0 = sx * (GW / 2 - 0.0375) + 0.017
        face = K.Face((x0, 0.071, -GH / 2 + 0.08), (-0.034, 0, 0), (0, 0, GH - 0.16))
        o.append(K.led_grid(f"led_col_{sx}", face, 0.0, 0.0, 1.0, 1.0, 1, 12, m["led"], fill=0.72, off=0.004, depth=0.010))
    face = K.Face((GW / 2 - 0.075, 0.03, -GH / 2 + 0.075), (-(GW - 0.15), 0, 0), (0, 0, GH - 0.15))
    o += K.frame_on("inner", face, 0.0, 0.0, 1.0, 1.0, 0.012 / (GW - 0.15), 0.012 / (GH - 0.15), m["chrome"], off=0.0, depth=0.02)
    o += _emblem(m, "emb", 1.25, y=0.085, fill="neon", frame="gold")
    o += _led_ring(m)
    return o


def grille_slats_neon(m):
    """Lâminas douradas inclinadas sobre painel aceso de raios, colunas de neon e fileira de LED embaixo."""
    o = [_back(m), _art(m, 14, inset=0.06)] + _frame(m, m["body"], bar=0.05, depth=0.05)
    n = 8
    inner = GH - 0.14
    for k in range(n):
        z = -inner / 2 + 0.04 + k * (inner - 0.08) / (n - 1)
        o.append(M.box(f"slat_{k}", (GW - 0.30, 0.045, 0.022), (0, 0.04, z), m["gold"], bevel=0.006, seg=1, rot=(32, 0, 0)))
    for sx in (-1, 1):
        x = sx * (GW / 2 - 0.09)
        o.append(M.box(f"col_{sx}", (0.06, 0.03, GH - 0.12), (x, 0.03, 0), m["trim"], bevel=0.006, seg=1))
        o.append(Z.Q.tubes(f"neon_{sx}", [((x, 0.05, -GH / 2 + 0.08), (x, 0.05, GH / 2 - 0.08))], 0.016, m["neon"], seg=8))
    o.append(_led_row(m, "led_bot", 0.052, -GH / 2 + 0.025, cols=20, x_in=0.16))
    o += _led_ring(m)
    return o


# ----------------------------------------------------------------------------- buzinas (em cima da viseira)

def _bracket(m, w=0.44):
    """Suporte na testa da cabine (costas da peça) e trilho embaixo das cornetas."""
    return [M.box("bracket", (w, 0.035, 0.12), (0, 0.018, 0.06), m["body"], bevel=0.008, seg=1),
            M.box("rail", (w - 0.06, 0.40, 0.025), (0, 0.22, 0.0125), m["trim"], bevel=0.005, seg=1)]


def horn_triple(m):
    """Corneta tripla cromada (3 notas), deitada em cima da viseira apontando para a frente."""
    o = _bracket(m)
    for k, (x, ln, rb) in enumerate(((-0.13, 0.42, 0.05), (0.0, 0.52, 0.06), (0.13, 0.60, 0.07))):
        o.append(Z.trumpet(f"horn_{k}", ln - 0.03, 0.02, rb, m["chrome"], loc=(x, 0.03, 0.09), seg=14))
        o.append(M.box(f"clip_{k}", (0.05, 0.04, 0.07), (x, 0.16, 0.045), m["chrome"], bevel=0.006, seg=1))
    o.append(M.box("valve", (0.34, 0.06, 0.05), (0, 0.06, 0.09), m["chrome"], bevel=0.012, seg=1))
    return o


def horn_twin_long(m):
    """Par de cornetas longas douradas."""
    o = _bracket(m, w=0.40)
    for k, x in enumerate((-0.11, 0.11)):
        o.append(Z.trumpet(f"horn_{k}", 0.57, 0.022, 0.075, m["gold"], loc=(x, 0.03, 0.10), seg=16))
        for y in (0.14, 0.34):
            o.append(M.box(f"clip_{k}_{y}", (0.045, 0.035, 0.08), (x, y, 0.045), m["chrome"], bevel=0.006, seg=1))
    return o


def horn_ship(m):
    """Buzina de navio: um sino grande apontando para a frente com aro âmbar aceso."""
    o = _bracket(m, w=0.36)
    prof = [(0.04, 0.0), (0.04, 0.14), (0.05, 0.24), (0.075, 0.34), (0.10, 0.42), (0.125, 0.50), (0.12, 0.515), (0.08, 0.48)]
    o.append(Z.lathe("bell", prof, m["chrome"], axis="Y", seg=18, loc=(0, 0.04, 0.135), cap0=True))
    o.append(M.torus("amber_ring", 0.123, 0.013, (0, 0.555, 0.135), m["amber"], axis="Y", seg=20, tube_seg=5))
    o.append(M.box("post", (0.06, 0.20, 0.07), (0, 0.22, 0.04), m["body"], bevel=0.01, seg=1))
    o.append(M.cylinder("cap", 0.055, 0.04, (0, 0.05, 0.135), m["gold"], axis="Y", seg=14))
    return o


def _g(pid, name, build, color="cromo_ciano"):
    return {"id": pid, "name": name, "build": build, "kind": "grille", "slot": "grille", "socket": "grille", "fit": "grille",
            "default_color": color, "folder": "grille_t234", "nominal": [GW, GH, GD]}


def _h(pid, name, build, horn, color="cromo_ciano"):
    return {"id": pid, "name": name, "build": build, "kind": "horn", "slot": "horn", "socket": "horn_r",
            "socket_left": "horn_l", "fit": "horn",
            "default_color": color, "folder": "horn_t234", "horn": horn}


PARTS = [
    _g("grille_bars_led", "Barras cromadas sobre painel aceso", grille_bars_led),
    _g("grille_honey_sun", "Painel de sakura com moldura de LED", grille_honey_sun, "preto_ciano"),
    _g("grille_slats_neon", "Lâminas douradas sobre painel de raios", grille_slats_neon, "preto_rosa"),
    _h("horn_triple", "Corneta tripla cromada", horn_triple, "horn_musical_dekotora"),
    _h("horn_twin_long", "Par de cornetas douradas", horn_twin_long, "horn_dual_tone", "preto_ciano"),
    _h("horn_ship", "Buzina de navio com aro âmbar", horn_ship, "horn_ship_deep"),
]
