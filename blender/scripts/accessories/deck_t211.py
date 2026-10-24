"""Deque frontal (parte de cima da cabine), 17 peças do catálogo da T-210 (capturas 001–028), T-211.

Origem = encaixe "andon" do caminhão (no teto, atrás, no centro); a peça cresce para a frente (+Y) e para cima.
Tamanho nominal: largura 2,10 m, fundo <= 1,00 m, altura <= 0,90 m (cabe em todas as cabines com a escala 0,85–1,15;
ver `game/assets/vehicles/dekotora/truck/sockets/`). Desenho nosso, inspirado nas formas das capturas (nada copiado).
"""
from __future__ import annotations

from lib import mesh3d as M

from . import t211_kit as K

W = 2.10


def hh(H):
    """Rodada 2 da comparação: os deques das capturas são altos (quase a altura do baú); as caixas sobem até 0,88 m."""
    return H if H < 0.5 else min(0.88, H * 1.22)


def _shell(m, D, H, inset, name="shell", W_=W, bevel=0.012, side_inset=0.0):
    """Caixa do deque + as faces (frente inclinada, lados) para pendurar LED, letreiros e neon."""
    H = hh(H)
    o = K.wedge_box(name, W_, D, H, inset, m["body"], bevel=bevel, side_inset=side_inset)
    w = W_ / 2
    front = K.Face((w, D, 0), (-W_, 0, 0), (0, -inset, H))
    right = K.Face((w, 0, 0), (0, D - inset, 0), (0, 0, H))
    left = K.Face((-w, D - inset, 0), (0, -(D - inset), 0), (0, 0, H))
    return [o, K.wedge_box(name + "_base", W_ + 0.04, D + 0.02, 0.05, 0.0, m["trim"], y0=-0.01, z0=-0.0, bevel=0.008)], front, right, left


def _side_leds(o, m, right, left, t0, t1, cols=8, rows=3):
    for f, n in ((right, "r"), (left, "l")):
        o.append(K.led_grid(f"led_side_{n}", f, 0.06, t0, 0.94, t1, cols, rows, m["led"]))


def _gap(c, r):          # LEDs falhados (padrão das capturas 004/011: alguns apagados em quadriculado)
    return (c * 7 + r * 3) % 11 == 0


def deck_cap_trio(m):
    o, f, r, l = _shell(m, 0.92, 0.30, 0.26, bevel=0.07)
    for k, s in enumerate((0.36, 0.5, 0.64)):
        o.append(K.bar_on(f"lamp_{k}", f, s - 0.045, 0.42, s + 0.045, 0.72, m["led"], depth=0.025))
    o.append(K.bar_on("lip", f, 0.05, 0.04, 0.95, 0.12, m["chrome"], depth=0.015))
    return o


def deck_kanji_rail(m):
    o, f, r, l = _shell(m, 0.90, 0.55, 0.05)
    for k in range(34):                                   # grade de barras cromadas no alto da frente
        s = 0.03 + k * (0.94 / 33)
        o.append(K.bar_on(f"rail_{k}", f, s - 0.006, 0.74, s + 0.006, 0.97, m["chrome"], depth=0.02))
    o.append(K.bar_on("rail_top", f, 0.02, 0.96, 0.98, 1.0, m["chrome"], depth=0.025))
    o.extend(K.sign("sign", f, 0.30, 0.14, 0.70, 0.62, m, cell=0, frame_mat=m["trim"]))
    for side, n in ((r, "r"), (l, "l")):
        o.append(K.bar_on(f"side_rail_{n}", side, 0.04, 0.80, 0.96, 0.9, m["chrome"], depth=0.015))
    return o


def deck_led_box(m):
    o, f, r, l = _shell(m, 0.95, 0.68, 0.12)
    o.append(K.led_grid("led_front", f, 0.04, 0.64, 0.96, 0.96, 22, 3, m["led"], skip=_gap))
    _side_leds(o, m, r, l, 0.64, 0.96)
    o.extend(K.sign("sign", f, 0.32, 0.10, 0.68, 0.50, m, cell=1, frame_mat=m["chrome"]))
    return o


def deck_led_panel(m):
    o, f, r, l = _shell(m, 0.95, 0.68, 0.12)
    o.append(K.led_grid("led_front", f, 0.04, 0.66, 0.96, 0.96, 22, 3, m["led"]))
    _side_leds(o, m, r, l, 0.66, 0.96)
    o.append(K.quad_panel("panel", f, 0.16, 0.10, 0.84, 0.54, m["trim"], off=0.012, depth=0.02))
    for k, (s0, s1) in enumerate(((0.05, 0.14), (0.86, 0.95))):
        o.append(K.quad_panel(f"panel_end_{k}", f, s0, 0.16, s1, 0.48, m["trim"], off=0.012, depth=0.02))
    o.extend(K.frame_on("panel_fr", f, 0.16, 0.10, 0.84, 0.54, 0.01, 0.02, m["chrome"], depth=0.025))
    return o


def deck_led_cyan(m):
    o, f, r, l = _shell(m, 0.95, 0.70, 0.12)
    o.append(K.led_grid("led_front", f, 0.08, 0.68, 0.92, 0.96, 18, 3, m["led"], skip=_gap))
    _side_leds(o, m, r, l, 0.68, 0.96, cols=7)
    o.append(K.bar_on("screen", f, 0.22, 0.10, 0.78, 0.56, m["neon"], depth=0.02))
    for k, (s0, s1) in enumerate(((0.07, 0.19), (0.81, 0.93))):
        o.append(K.bar_on(f"screen_end_{k}", f, s0, 0.18, s1, 0.56, m["neon"], depth=0.02))
    return o


def deck_art_band(m):
    o, f, r, l = _shell(m, 0.95, 0.75, 0.12)
    o.append(K.bar_on("band", f, 0.02, 0.66, 0.98, 0.72, m["neon"], depth=0.02))
    o.extend(K.sign("sign", f, 0.29, 0.20, 0.71, 0.58, m, cell=2, frame_mat=m["trim"]))
    o.append(K.art_panel("art_l", f, 0.03, 0.06, 0.24, 0.60, m, 12))
    o.append(K.art_panel("art_r", f, 0.76, 0.06, 0.97, 0.60, m, 13))
    for side, n in ((r, "r"), (l, "l")):
        o.append(K.art_panel(f"art_side_{n}", side, 0.30, 0.08, 0.90, 0.58, m, 14))
        o.append(K.bar_on(f"band_side_{n}", side, 0.03, 0.66, 0.97, 0.72, m["neon"], depth=0.02))
        o.append(K.bar_on(f"chev_{n}", side, 0.06, 0.20, 0.22, 0.46, m["neon"], depth=0.02))
    return o


def deck_led_columns(m):
    o, f, r, l = _shell(m, 0.95, 0.72, 0.12)
    o.append(K.led_grid("led_front", f, 0.04, 0.66, 0.96, 0.96, 22, 3, m["led"]))
    _side_leds(o, m, r, l, 0.66, 0.96)
    o.extend(K.sign("sign", f, 0.31, 0.12, 0.69, 0.54, m, cell=3, frame_mat=m["trim"]))
    for k, (s0, s1) in enumerate(((0.21, 0.28), (0.72, 0.79))):
        o.append(K.bar_on(f"col_{k}", f, s0, 0.06, s1, 0.60, m["neon"], depth=0.03))
    o.append(K.bar_on("top_bar", f, 0.21, 0.58, 0.79, 0.62, m["neon"], depth=0.025))
    return o


def deck_lace(m):
    o, f, r, l = _shell(m, 0.95, 0.74, 0.12)
    o.append(K.led_grid("led_front", f, 0.04, 0.70, 0.96, 0.97, 22, 3, m["led"], skip=_gap))
    _side_leds(o, m, r, l, 0.70, 0.97)
    o.extend(K.sign("sign", f, 0.30, 0.28, 0.70, 0.64, m, cell=4, frame_mat=m["chrome"]))
    for k, (s0, s1) in enumerate(((0.20, 0.27), (0.73, 0.80))):
        o.append(K.bar_on(f"col_{k}", f, s0, 0.26, s1, 0.66, m["neon"], depth=0.03))
    o.append(K.quad_panel("lace_strip", f, 0.02, 0.04, 0.98, 0.22, m["trim"], off=0.01, depth=0.015))
    for k in range(26):                                  # friso vazado tipo renda: losangos cromados
        s = 0.04 + k * (0.92 / 25)
        o.append(K.bar_on(f"lace_{k}", f, s - 0.012, 0.08, s + 0.012, 0.18, m["chrome"], off=0.02, depth=0.012))
    for side, n in ((r, "r"), (l, "l")):
        o.append(K.quad_panel(f"lace_side_{n}", side, 0.04, 0.04, 0.96, 0.22, m["trim"], off=0.01, depth=0.015))
    return o


def deck_triple_sign(m):
    o, f, r, l = _shell(m, 0.95, 0.80, 0.12)
    for k, (t0, t1) in enumerate(((0.70, 0.77), (0.80, 0.87), (0.90, 0.97))):
        o.append(K.led_grid(f"led_row_{k}", f, 0.04, t0, 0.96, t1, 24, 1, m["led"], fill=0.7))
    _side_leds(o, m, r, l, 0.70, 0.97)
    o.extend(K.sign("sign_a", f, 0.10, 0.42, 0.48, 0.64, m, cell=5, frame_mat=m["trim"]))
    o.extend(K.sign("sign_b", f, 0.52, 0.42, 0.90, 0.64, m, cell=6, frame_mat=m["trim"]))
    o.extend(K.sign("sign_c", f, 0.30, 0.10, 0.70, 0.34, m, cell=7, frame_mat=m["trim"]))
    return o


def deck_eyebrow(m):
    o, f, r, l = _shell(m, 0.95, 0.70, 0.10)
    o.append(K.led_grid("led_front", f, 0.05, 0.46, 0.95, 0.92, 20, 4, m["led"]))
    _side_leds(o, m, r, l, 0.46, 0.92, rows=4)
    o.extend(K.sign("sign", f, 0.20, 0.07, 0.80, 0.38, m, cell=8, frame_mat=None))
    o.extend(K.frame_on("sign_neon", f, 0.20, 0.07, 0.80, 0.38, 0.012, 0.025, m["neon"], depth=0.02))
    H, D, ins = hh(0.70), 0.95, 0.10
    for sx in (-1, 1):                                    # sobrancelhas de neon em cima da frente
        o.append(K.arc_tube(f"brow_{sx}", sx * 0.10, sx * 0.88, D - ins - 0.04, H + 0.01, 0.045, 0.02, m["neon"]))
    return o


def deck_pillars(m):
    o, f, r, l = _shell(m, 0.95, 0.86, 0.10)
    o.append(K.led_grid("led_front", f, 0.05, 0.78, 0.95, 0.97, 22, 2, m["led"]))
    _side_leds(o, m, r, l, 0.78, 0.97, rows=2)
    o.extend(K.sign("sign", f, 0.24, 0.14, 0.76, 0.66, m, cell=9, frame_mat=m["trim"]))
    for k, (s0, s1) in enumerate(((0.10, 0.19), (0.81, 0.90))):
        o.append(K.bar_on(f"pillar_{k}", f, s0, 0.04, s1, 0.74, m["neon"], depth=0.035))
    return o


def deck_cyan_frame(m):
    o, f, r, l = _shell(m, 0.95, 0.76, 0.12)
    o.append(K.led_grid("led_front", f, 0.05, 0.72, 0.95, 0.97, 22, 3, m["led"], skip=_gap))
    _side_leds(o, m, r, l, 0.72, 0.97)
    o.extend(K.sign("sign", f, 0.20, 0.18, 0.80, 0.58, m, cell=10, frame_mat=None))
    o.extend(K.frame_on("neon_fr", f, 0.17, 0.15, 0.83, 0.61, 0.04, 0.05, m["neon"], depth=0.025))
    o.append(K.bar_on("neon_low", f, 0.04, 0.03, 0.96, 0.08, m["neon"], depth=0.02))
    for side, n in ((r, "r"), (l, "l")):
        o.append(K.bar_on(f"neon_side_{n}", side, 0.04, 0.62, 0.96, 0.67, m["neon"], depth=0.02))
        o.append(K.bar_on(f"neon_side_low_{n}", side, 0.04, 0.03, 0.96, 0.08, m["neon"], depth=0.02))
    return o


def deck_painted_wings(m):
    o, f, r, l = _shell(m, 0.95, 0.78, 0.12)
    o.append(K.led_grid("led_front", f, 0.04, 0.70, 0.96, 0.97, 22, 3, m["led"]))
    _side_leds(o, m, r, l, 0.70, 0.97)
    o.extend(K.sign("sign", f, 0.28, 0.16, 0.72, 0.58, m, cell=11, frame_mat=m["chrome"]))
    o.append(K.art_panel("art_l", f, 0.03, 0.06, 0.25, 0.64, m, 15))
    o.append(K.art_panel("art_r", f, 0.75, 0.06, 0.97, 0.64, m, 13))
    for side, n, cell in ((r, "r", 12), (l, "l", 14)):
        o.append(K.art_panel(f"art_side_{n}", side, 0.08, 0.06, 0.92, 0.64, m, cell))
    o.extend(K.frame_on("art_fr_l", f, 0.03, 0.06, 0.25, 0.64, 0.008, 0.02, m["chrome"], depth=0.02))
    o.extend(K.frame_on("art_fr_r", f, 0.75, 0.06, 0.97, 0.64, 0.008, 0.02, m["chrome"], depth=0.02))
    return o


# ----------------------------------------------------------------------------- canhões de luz (025–028)

def _pod_base(m, wb=1.92, D=0.98):
    return [M.box("pod_base", (wb, D, 0.07), (0, D / 2, 0.035), m["trim"], bevel=0.015, seg=1)]


def _pods(m, xs, r, length, seg, lens_kind, strips):
    o = _pod_base(m, wb=max(abs(x) for x in xs) * 2 + 2 * r + 0.12, D=length)
    for k, x in enumerate(xs):
        zc = 0.07 + r * 0.92
        o.append(K.hex_pod(f"pod_{k}", length, r, (x, length / 2, zc), m["body"], seg=seg))
        o.append(M.box(f"pod_foot_{k}", (r * 1.2, length * 0.8, 0.05), (x, length / 2, 0.07 + 0.02), m["trim"], bevel=0.01, seg=1))
        if lens_kind == "hex":
            o.append(K.lens(f"lens_{k}", r * 0.82, (x, length + 0.005, zc), m["neon"], seg=6))
        else:                                                         # lente dupla quadrada
            for j, dx in enumerate((-r * 0.42, r * 0.42)):
                o.append(M.box(f"lens_{k}_{j}", (r * 0.62, 0.03, r * 0.62), (x + dx, length + 0.005, zc), m["neon"], bevel=0.004, seg=1))
        for j, (y0, y1, dz) in enumerate(strips):                      # faixas de neon na lateral de cima
            for sx in (-1, 1):
                o.append(M.box(f"strip_{k}_{j}_{sx}", (0.03, (y1 - y0) * length, r * 0.42),
                               (x + sx * r * 0.86, (y0 + y1) / 2 * length, zc + r * 0.12 + dz), m["neon"], bevel=0.004, seg=1))
    return o


def deck_pods_square(m):
    return _pods(m, (-0.55, 0.55), 0.22, 0.95, 4, "square", [(0.35, 0.92, 0.0)])


def deck_pods_round(m):
    return _pods(m, (-0.55, 0.55), 0.23, 0.95, 6, "hex", [(0.22, 0.50, 0.0), (0.58, 0.88, 0.0)])


def deck_pods_long(m):
    return _pods(m, (-0.55, 0.55), 0.23, 1.00, 6, "hex", [(0.18, 0.46, 0.0), (0.54, 0.86, 0.0), (0.18, 0.46, -0.12), (0.54, 0.86, -0.12)])


def deck_pods_five(m):
    xs = (-0.80, -0.40, 0.0, 0.40, 0.80)
    o = _pods(m, xs, 0.15, 0.95, 6, "hex", [])
    # painel de LED na ponta direita (como a captura 028)
    o.append(M.box("led_box", (0.06, 0.84, 0.30), (0.98, 0.52, 0.22), m["body"], bevel=0.01, seg=1))
    o.append(K.led_grid("led_end", K.Face((1.012, 0.12, 0.10), (0, 0.80, 0), (0, 0, 0.24)), 0.0, 0.0, 1.0, 1.0, 10, 2, m["led"]))
    return o


def _p(pid, name, build, caps, sign=True, color="preto_ciano", depth=0.95):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": sign, "default_color": color,
            "slot": "andon", "socket": "andon", "nominal_w": W, "depth": depth}


PARTS = [
    _p("deck_cap_trio", "Capa de teto com 3 luzes", deck_cap_trio, "001", sign=False, color="branco_azul"),
    _p("deck_kanji_rail", "Deque com letreiro e grade", deck_kanji_rail, "002-003", color="cromo_ciano"),
    _p("deck_led_box", "Deque LED com letreiro", deck_led_box, "004-005"),
    _p("deck_led_panel", "Deque LED com painel liso", deck_led_panel, "006", sign=False, color="prata_marinho"),
    _p("deck_led_cyan", "Deque LED com tela ciano", deck_led_cyan, "007", sign=False),
    _p("deck_art_band", "Deque com faixa e pinturas", deck_art_band, "008-009"),
    _p("deck_led_columns", "Deque LED com colunas", deck_led_columns, "010-011"),
    _p("deck_lace", "Deque com renda", deck_lace, "012-013"),
    _p("deck_triple_sign", "Deque de 3 letreiros", deck_triple_sign, "014-015"),
    _p("deck_eyebrow", "Deque com sobrancelhas neon", deck_eyebrow, "016-017"),
    _p("deck_pillars", "Deque de colunas neon", deck_pillars, "018-021"),
    _p("deck_cyan_frame", "Deque com moldura neon", deck_cyan_frame, "022-023"),
    _p("deck_painted_wings", "Deque com asas pintadas", deck_painted_wings, "024"),
    _p("deck_pods_square", "Par de canhões de luz quadrados", deck_pods_square, "025", sign=False),
    _p("deck_pods_round", "Par de canhões de luz redondos", deck_pods_round, "026", sign=False),
    _p("deck_pods_long", "Par de canhões longos", deck_pods_long, "027", sign=False, depth=1.0),
    _p("deck_pods_five", "Bateria de 5 canhões", deck_pods_five, "028", sign=False),
]
