"""Deque frontal (parte de cima da cabine), 17 peças do catálogo da T-210 (capturas 001–028), T-211; refino T-214/T-215.

Origem = encaixe "andon" do caminhão (no teto, atrás, no centro); a peça cresce para a frente (+Y) e para cima.
Tamanho nominal: largura 2,10 m, fundo <= 1,00 m, altura <= 0,90 m. O jogo assenta a peça no teto REAL de cada cabine
(`game/scripts/truck/socket_seat.gd`: inclinação, altura e um "assento" que fecha a folga do teto abaulado).
T-214: mais detalhe (caixas dos LEDs com parafusos, cantoneiras cromadas, rebites, frisos) e os canhões SEM base: cada
canhão é um grupo `POD<k>_*` (vira o nó POD<k> no .glb) que o jogo apoia sozinho no teto.
T-215: dados de empilhamento (`stack`): caixa em cima de canhões e canhões em cima de caixa.
Desenho nosso, inspirado nas formas das capturas (nada copiado).
"""
from __future__ import annotations

from lib import mesh3d as M

from . import t211_kit as K

W = 2.10


def hh(H):
    """Rodada 2 da comparação: os deques das capturas são altos (quase a altura do baú); as caixas sobem até 0,88 m."""
    return H if H < 0.5 else min(0.88, H * 1.22)


def _shell(m, D, H, inset, name="shell", W_=W, bevel=0.012, side_inset=0.0, rim=True, grooves=True):
    """Caixa do deque + as faces (frente inclinada, lados) para pendurar LED, letreiros e neon.
    T-214: cantoneiras cromadas nas quinas da frente, friso cromado no alto da frente, rebites no rodapé e frisos nos
    lados (detalhe barato: poucas dezenas de triângulos)."""
    H = hh(H)
    o = K.wedge_box(name, W_, D, H, inset, m["body"], bevel=bevel, side_inset=side_inset)
    w = W_ / 2
    front = K.Face((w, D, 0), (-W_, 0, 0), (0, -inset, H))
    right = K.Face((w, 0, 0), (0, D - inset, 0), (0, 0, H))
    left = K.Face((-w, D - inset, 0), (0, -(D - inset), 0), (0, 0, H))
    out = [o, K.wedge_box(name + "_base", W_ + 0.04, D + 0.02, 0.05, 0.0, m["trim"], y0=-0.01, z0=-0.0, bevel=0.008)]
    for s0, s1 in ((0.0, 0.016), (0.984, 1.0)):
        out.append(K.bar_on(f"{name}_guard_{s0}", front, s0, 0.10, s1, 0.97, m["chrome"], depth=0.010))
    if rim:
        out.append(K.bar_on(f"{name}_rim", front, 0.02, 0.982, 0.98, 0.997, m["chrome"], depth=0.008))
    n = max(6, int(W_ / 0.16))
    out.append(K.bolts(f"{name}_rivets", front, [(0.04 + 0.92 * k / (n - 1), 0.085) for k in range(n)], m["chrome"], r=0.008, h=0.005))
    if grooves and H >= 0.5:
        for side, sn in ((right, "r"), (left, "l")):
            out += K.grooves(f"{name}_groove_{sn}", side, (0.10, 0.16), m["trim"])
    return out, front, right, left


def _side_leds(o, m, right, left, t0, t1, cols=8, rows=3):
    for f, n in ((right, "r"), (left, "l")):
        o.extend(K.led_panel(f"led_side_{n}", f, 0.07, t0, 0.93, t1, cols, rows, m, screws=False))


def _gap(c, r):          # LEDs falhados (padrão das capturas 004/011: alguns apagados em quadriculado)
    return (c * 7 + r * 3) % 11 == 0


def deck_cap_trio(m):
    o, f, r, l = _shell(m, 0.92, 0.30, 0.26, bevel=0.07, rim=False, grooves=False)
    for k, s in enumerate((0.36, 0.5, 0.64)):
        o.append(K.bar_on(f"lamp_rim_{k}", f, s - 0.058, 0.38, s + 0.058, 0.76, m["chrome"], depth=0.015))
        o.append(K.bar_on(f"lamp_{k}", f, s - 0.045, 0.42, s + 0.045, 0.72, m["led"], depth=0.028))
    o.append(K.bar_on("lip", f, 0.05, 0.04, 0.95, 0.12, m["chrome"], depth=0.015))
    return o


def deck_kanji_rail(m):
    o, f, r, l = _shell(m, 0.90, 0.55, 0.05, rim=False)
    for k in range(34):                                   # grade de barras cromadas no alto da frente
        s = 0.03 + k * (0.94 / 33)
        o.append(K.bar_on(f"rail_{k}", f, s - 0.006, 0.74, s + 0.006, 0.97, m["chrome"], depth=0.02))
    o.append(K.bar_on("rail_top", f, 0.02, 0.96, 0.98, 1.0, m["chrome"], depth=0.025))
    o.append(K.bar_on("rail_low", f, 0.02, 0.72, 0.98, 0.745, m["chrome"], depth=0.022))
    o.extend(K.sign("sign", f, 0.30, 0.14, 0.70, 0.62, m, cell=0, frame_mat=m["trim"]))
    for side, n in ((r, "r"), (l, "l")):
        o.append(K.bar_on(f"side_rail_{n}", side, 0.04, 0.80, 0.96, 0.9, m["chrome"], depth=0.015))
    return o


def deck_led_box(m):
    o, f, r, l = _shell(m, 0.95, 0.68, 0.12)
    o.extend(K.led_panel("led_front", f, 0.05, 0.64, 0.95, 0.95, 22, 3, m, skip=_gap))
    _side_leds(o, m, r, l, 0.64, 0.95)
    o.extend(K.sign("sign", f, 0.32, 0.12, 0.68, 0.50, m, cell=1, frame_mat=m["chrome"]))
    return o


def deck_led_panel(m):
    o, f, r, l = _shell(m, 0.95, 0.68, 0.12)
    o.extend(K.led_panel("led_front", f, 0.05, 0.66, 0.95, 0.95, 22, 3, m))
    _side_leds(o, m, r, l, 0.66, 0.95)
    o.append(K.quad_panel("panel", f, 0.16, 0.12, 0.84, 0.54, m["trim"], off=0.012, depth=0.02))
    for k, (s0, s1) in enumerate(((0.05, 0.14), (0.86, 0.95))):
        o.append(K.quad_panel(f"panel_end_{k}", f, s0, 0.16, s1, 0.48, m["trim"], off=0.012, depth=0.02))
        o.append(K.bolts(f"panel_end_bolts_{k}", f, [((s0 + s1) / 2, 0.20), ((s0 + s1) / 2, 0.44)], m["chrome"], off=0.012))
    o.extend(K.frame_on("panel_fr", f, 0.16, 0.12, 0.84, 0.54, 0.01, 0.02, m["chrome"], depth=0.025))
    return o


def deck_led_cyan(m):
    o, f, r, l = _shell(m, 0.95, 0.70, 0.12)
    o.extend(K.led_panel("led_front", f, 0.08, 0.68, 0.92, 0.95, 18, 3, m, skip=_gap))
    _side_leds(o, m, r, l, 0.68, 0.95, cols=7)
    o.append(K.bar_on("screen", f, 0.22, 0.12, 0.78, 0.56, m["neon"], depth=0.02))
    o.extend(K.frame_on("screen_fr", f, 0.22, 0.12, 0.78, 0.56, 0.008, 0.016, m["chrome"], depth=0.024))
    for k, (s0, s1) in enumerate(((0.07, 0.19), (0.81, 0.93))):
        o.append(K.bar_on(f"screen_end_{k}", f, s0, 0.18, s1, 0.56, m["neon"], depth=0.02))
    return o


def deck_art_band(m):
    o, f, r, l = _shell(m, 0.95, 0.75, 0.12)
    o.append(K.bar_on("band", f, 0.02, 0.66, 0.98, 0.72, m["neon"], depth=0.02))
    o.extend(K.sign("sign", f, 0.29, 0.20, 0.71, 0.58, m, cell=2, frame_mat=m["trim"]))
    o.append(K.art_panel("art_l", f, 0.03, 0.12, 0.24, 0.60, m, 12))
    o.append(K.art_panel("art_r", f, 0.76, 0.12, 0.97, 0.60, m, 13))
    o.extend(K.frame_on("art_fr_l", f, 0.03, 0.12, 0.24, 0.60, 0.006, 0.016, m["chrome"], depth=0.018))
    o.extend(K.frame_on("art_fr_r", f, 0.76, 0.12, 0.97, 0.60, 0.006, 0.016, m["chrome"], depth=0.018))
    for side, n in ((r, "r"), (l, "l")):
        o.append(K.art_panel(f"art_side_{n}", side, 0.30, 0.22, 0.90, 0.58, m, 14))
        o.append(K.bar_on(f"band_side_{n}", side, 0.03, 0.66, 0.97, 0.72, m["neon"], depth=0.02))
        o.append(K.bar_on(f"chev_{n}", side, 0.06, 0.22, 0.22, 0.46, m["neon"], depth=0.02))
    return o


def deck_led_columns(m):
    o, f, r, l = _shell(m, 0.95, 0.72, 0.12)
    o.extend(K.led_panel("led_front", f, 0.05, 0.66, 0.95, 0.95, 22, 3, m))
    _side_leds(o, m, r, l, 0.66, 0.95)
    o.extend(K.sign("sign", f, 0.31, 0.14, 0.69, 0.54, m, cell=3, frame_mat=m["trim"]))
    for k, (s0, s1) in enumerate(((0.21, 0.28), (0.72, 0.79))):
        o.append(K.bar_on(f"col_{k}", f, s0, 0.12, s1, 0.60, m["neon"], depth=0.03))
        o.append(K.bar_on(f"col_cap_{k}", f, s0 - 0.006, 0.10, s1 + 0.006, 0.125, m["chrome"], depth=0.036))
    o.append(K.bar_on("top_bar", f, 0.21, 0.58, 0.79, 0.62, m["neon"], depth=0.025))
    return o


def deck_lace(m):
    o, f, r, l = _shell(m, 0.95, 0.74, 0.12)
    o.extend(K.led_panel("led_front", f, 0.05, 0.70, 0.95, 0.96, 22, 3, m, skip=_gap))
    _side_leds(o, m, r, l, 0.70, 0.96)
    o.extend(K.sign("sign", f, 0.30, 0.30, 0.70, 0.64, m, cell=4, frame_mat=m["chrome"]))
    for k, (s0, s1) in enumerate(((0.20, 0.27), (0.73, 0.80))):
        o.append(K.bar_on(f"col_{k}", f, s0, 0.28, s1, 0.66, m["neon"], depth=0.03))
    o.append(K.quad_panel("lace_strip", f, 0.02, 0.10, 0.98, 0.26, m["trim"], off=0.01, depth=0.015))
    for k in range(26):                                  # friso vazado tipo renda: losangos cromados
        s = 0.04 + k * (0.92 / 25)
        o.append(K.bar_on(f"lace_{k}", f, s - 0.012, 0.13, s + 0.012, 0.23, m["chrome"], off=0.02, depth=0.012))
    for side, n in ((r, "r"), (l, "l")):
        o.append(K.quad_panel(f"lace_side_{n}", side, 0.04, 0.22, 0.96, 0.36, m["trim"], off=0.01, depth=0.015))
    return o


def deck_triple_sign(m):
    o, f, r, l = _shell(m, 0.95, 0.80, 0.12)
    for k, (t0, t1) in enumerate(((0.70, 0.765), (0.80, 0.865), (0.90, 0.965))):
        o.extend(K.led_panel(f"led_row_{k}", f, 0.05, t0, 0.95, t1, 24, 1, m, fill=0.7, screws=False))
    _side_leds(o, m, r, l, 0.70, 0.96)
    o.extend(K.sign("sign_a", f, 0.10, 0.42, 0.48, 0.64, m, cell=5, frame_mat=m["trim"]))
    o.extend(K.sign("sign_b", f, 0.52, 0.42, 0.90, 0.64, m, cell=6, frame_mat=m["trim"]))
    o.extend(K.sign("sign_c", f, 0.30, 0.13, 0.70, 0.34, m, cell=7, frame_mat=m["trim"]))
    return o


def deck_eyebrow(m):
    o, f, r, l = _shell(m, 0.95, 0.70, 0.10, rim=False)
    o.extend(K.led_panel("led_front", f, 0.05, 0.46, 0.95, 0.92, 20, 4, m))
    _side_leds(o, m, r, l, 0.46, 0.92, rows=4)
    o.extend(K.sign("sign", f, 0.20, 0.12, 0.80, 0.38, m, cell=8, frame_mat=None))
    o.extend(K.frame_on("sign_neon", f, 0.20, 0.12, 0.80, 0.38, 0.012, 0.025, m["neon"], depth=0.02))
    H, D, ins = hh(0.70), 0.95, 0.10
    for sx in (-1, 1):                                    # sobrancelhas de neon em cima da frente
        o.append(K.arc_tube(f"brow_{sx}", sx * 0.10, sx * 0.88, D - ins - 0.04, H + 0.01, 0.045, 0.02, m["neon"]))
    return o


def deck_pillars(m):
    o, f, r, l = _shell(m, 0.95, 0.86, 0.10)
    o.extend(K.led_panel("led_front", f, 0.05, 0.78, 0.95, 0.96, 22, 2, m))
    _side_leds(o, m, r, l, 0.78, 0.96, rows=2)
    o.extend(K.sign("sign", f, 0.24, 0.16, 0.76, 0.66, m, cell=9, frame_mat=m["trim"]))
    for k, (s0, s1) in enumerate(((0.10, 0.19), (0.81, 0.90))):
        o.append(K.bar_on(f"pillar_{k}", f, s0, 0.12, s1, 0.74, m["neon"], depth=0.035))
        o.append(K.bar_on(f"pillar_foot_{k}", f, s0 - 0.008, 0.10, s1 + 0.008, 0.13, m["chrome"], depth=0.042))
    return o


def deck_cyan_frame(m):
    o, f, r, l = _shell(m, 0.95, 0.76, 0.12)
    o.extend(K.led_panel("led_front", f, 0.05, 0.72, 0.95, 0.96, 22, 3, m, skip=_gap))
    _side_leds(o, m, r, l, 0.72, 0.96)
    o.extend(K.sign("sign", f, 0.20, 0.20, 0.80, 0.58, m, cell=10, frame_mat=None))
    o.extend(K.frame_on("neon_fr", f, 0.17, 0.17, 0.83, 0.61, 0.04, 0.05, m["neon"], depth=0.025))
    o.append(K.bar_on("neon_low", f, 0.04, 0.11, 0.96, 0.15, m["neon"], depth=0.02))
    for side, n in ((r, "r"), (l, "l")):
        o.append(K.bar_on(f"neon_side_{n}", side, 0.04, 0.62, 0.96, 0.67, m["neon"], depth=0.02))
        o.append(K.bar_on(f"neon_side_low_{n}", side, 0.04, 0.20, 0.96, 0.25, m["neon"], depth=0.02))
    return o


def deck_painted_wings(m):
    o, f, r, l = _shell(m, 0.95, 0.78, 0.12)
    o.extend(K.led_panel("led_front", f, 0.05, 0.70, 0.95, 0.96, 22, 3, m))
    _side_leds(o, m, r, l, 0.70, 0.96)
    o.extend(K.sign("sign", f, 0.28, 0.18, 0.72, 0.58, m, cell=11, frame_mat=m["chrome"]))
    o.append(K.art_panel("art_l", f, 0.03, 0.12, 0.25, 0.64, m, 15))
    o.append(K.art_panel("art_r", f, 0.75, 0.12, 0.97, 0.64, m, 13))
    for side, n, cell in ((r, "r", 12), (l, "l", 14)):
        o.append(K.art_panel(f"art_side_{n}", side, 0.08, 0.22, 0.92, 0.64, m, cell))
    o.extend(K.frame_on("art_fr_l", f, 0.03, 0.12, 0.25, 0.64, 0.008, 0.02, m["chrome"], depth=0.02))
    o.extend(K.frame_on("art_fr_r", f, 0.75, 0.12, 0.97, 0.64, 0.008, 0.02, m["chrome"], depth=0.02))
    return o


# ----------------------------------------------------------------------------- canhões de luz (025–028)

def _pod(m, k, x, r, length, seg, lens_kind, strips):
    """Um canhão (grupo POD<k>): tubo de face chata embaixo (encosta no teto), 2 abraçadeiras cromadas, tampa de trás
    com parafusos, aro cromado e lente na frente, faixas de neon dos lados. Sem base nem pé (pedido do Marco, T-214)."""
    pre = f"POD{k}_"
    fl = K.pod_flat(r, seg)
    zc = fl                                               # face de baixo em z = 0
    o = [K.hex_pod(pre + "tube", length, r, (x, length / 2, zc), m["body"], seg=seg)]
    for j, y in enumerate((0.17 * length, 0.80 * length)):  # abraçadeiras (não descem abaixo da face de baixo)
        band = K.hex_pod(f"{pre}band_{j}", 0.035, r * 1.02, (x, y, zc + r * 0.02 * (1 if seg == 6 else 1)), m["chrome"], seg=seg)
        o.append(band)
    o.append(K.lens(pre + "cap", r * 0.9, (x, -0.008, zc), m["trim"], seg=seg, depth=0.02))
    back = K.Face((x - r * 0.5, -0.02, zc - r * 0.5), (r, 0, 0), (0, 0, r))      # normal para trás (-Y)
    o.append(K.bolts(pre + "cap_bolts", back, [(0.15, 0.15), (0.85, 0.15), (0.85, 0.85), (0.15, 0.85)], m["chrome"], r=0.012,
                     off=0.0))
    o.append(K.lens(pre + "bezel", r * 0.94, (x, length + 0.004, zc), m["chrome"], seg=seg, depth=0.024))
    if lens_kind == "hex":
        o.append(K.lens(pre + "lens", r * 0.80, (x, length + 0.016, zc), m["neon"], seg=seg, depth=0.03))
    else:                                                 # lente dupla quadrada
        for j, dx in enumerate((-r * 0.40, r * 0.40)):
            o.append(M.box(f"{pre}lens_{j}", (r * 0.6, 0.03, r * 0.6), (x + dx, length + 0.018, zc), m["neon"], bevel=0.004, seg=1))
    for j, (y0, y1, dz) in enumerate(strips):             # faixas de neon na lateral de cima
        for sx in (-1, 1):
            o.append(M.box(f"{pre}strip_{j}_{sx}", (0.03, (y1 - y0) * length, r * 0.40),
                           (x + sx * r * 0.84, (y0 + y1) / 2 * length, zc + r * 0.10 + dz), m["neon"], bevel=0.004, seg=1))
    return o


def _pods(m, xs, r, length, seg, lens_kind, strips):
    o = []
    for k, x in enumerate(xs):
        o += _pod(m, k, x, r, length, seg, lens_kind, strips)
    return o


def deck_pods_square(m):
    return _pods(m, (-0.55, 0.55), 0.22, 0.95, 4, "square", [(0.35, 0.92, 0.0)])


def deck_pods_round(m):
    return _pods(m, (-0.55, 0.55), 0.23, 0.95, 6, "hex", [(0.22, 0.50, 0.0), (0.58, 0.88, 0.0)])


def deck_pods_long(m):
    return _pods(m, (-0.55, 0.55), 0.20, 0.95, 6, "hex", [(0.18, 0.46, 0.0), (0.54, 0.86, 0.0), (0.18, 0.46, -0.10), (0.54, 0.86, -0.10)])


def deck_pods_five(m):
    xs = (-0.80, -0.40, 0.0, 0.40, 0.80)
    r = 0.15
    o = _pods(m, xs, r, 0.95, 6, "hex", [])
    # painel de LED na ponta direita (como a captura 028): também apoia sozinho, mesma altura dos tubos
    top = 2 * K.pod_flat(r)
    o.append(M.box("POD5_led_box", (0.06, 0.84, top), (0.99, 0.52, top / 2), m["body"], bevel=0.01, seg=1))
    o.extend(K.led_panel("POD5_led_end", K.Face((1.022, 0.12, 0.04), (0, 0.80, 0), (0, 0, top - 0.08)), 0.03, 0.05, 0.97, 0.95,
                         10, 2, m, screws=False))
    return o


# ----------------------------------------------------------------------------- empilhamento (T-215)

def _box_stack(D, H, inset, side_inset=0.0, base=True):
    """Caixa: em cima dela cabem canhões (face de cima plana do fundo até a borda da frente)."""
    H = hh(H)
    return {"kind": "box", "base": base, "top_y": round(H, 3),
            "top_rect": [round(-(W / 2 - side_inset - 0.03), 3), round(W / 2 - side_inset - 0.03, 3), round(-(D - inset - 0.03), 3), 0.0]}


def _pods_stack(xs, r, length, seg=6):
    fl = K.pod_flat(r, seg)
    # topo = topo das abraçadeiras (1,02 x raio, 2% acima do centro do tubo)
    return {"kind": "pods", "base": True, "top_y": round(2.02 * fl + 0.02 * r + 0.001, 3),
            "top_rect": [round(min(xs) - r * 0.5, 3), round(max(xs) + r * 0.5, 3), round(-length, 3), 0.0]}


def _p(pid, name, build, caps, sign=True, color="preto_ciano", depth=0.95, stack=None):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": sign, "default_color": color,
            "slot": "andon", "socket": "andon", "nominal_w": W, "depth": depth, "stack": stack}


PARTS = [
    # a capa baixa e arredondada não aguenta peça em cima, mas pode ir em cima dos canhões
    _p("deck_cap_trio", "Capa de teto com 3 luzes", deck_cap_trio, "001", sign=False, color="branco_azul",
       stack=_box_stack(0.92, 0.30, 0.26, base=False)),
    _p("deck_kanji_rail", "Deque com letreiro e grade", deck_kanji_rail, "002-003", color="cromo_ciano", stack=_box_stack(0.90, 0.55, 0.05)),
    _p("deck_led_box", "Deque LED com letreiro", deck_led_box, "004-005", stack=_box_stack(0.95, 0.68, 0.12)),
    _p("deck_led_panel", "Deque LED com painel liso", deck_led_panel, "006", sign=False, color="prata_marinho",
       stack=_box_stack(0.95, 0.68, 0.12)),
    _p("deck_led_cyan", "Deque LED com tela ciano", deck_led_cyan, "007", sign=False, stack=_box_stack(0.95, 0.70, 0.12)),
    _p("deck_art_band", "Deque com faixa e pinturas", deck_art_band, "008-009", stack=_box_stack(0.95, 0.75, 0.12)),
    _p("deck_led_columns", "Deque LED com colunas", deck_led_columns, "010-011", stack=_box_stack(0.95, 0.72, 0.12)),
    _p("deck_lace", "Deque com renda", deck_lace, "012-013", stack=_box_stack(0.95, 0.74, 0.12)),
    _p("deck_triple_sign", "Deque de 3 letreiros", deck_triple_sign, "014-015", stack=_box_stack(0.95, 0.80, 0.12)),
    # as sobrancelhas de neon ficam em cima: não aguenta peça em cima
    _p("deck_eyebrow", "Deque com sobrancelhas neon", deck_eyebrow, "016-017", stack=_box_stack(0.95, 0.70, 0.10, base=False)),
    _p("deck_pillars", "Deque de colunas neon", deck_pillars, "018-021", stack=_box_stack(0.95, 0.86, 0.10)),
    _p("deck_cyan_frame", "Deque com moldura neon", deck_cyan_frame, "022-023", stack=_box_stack(0.95, 0.76, 0.12)),
    _p("deck_painted_wings", "Deque com asas pintadas", deck_painted_wings, "024", stack=_box_stack(0.95, 0.78, 0.12)),
    _p("deck_pods_square", "Par de canhões de luz quadrados", deck_pods_square, "025", sign=False,
       stack=_pods_stack((-0.55, 0.55), 0.22, 0.95, seg=4)),
    _p("deck_pods_round", "Par de canhões de luz redondos", deck_pods_round, "026", sign=False, stack=_pods_stack((-0.55, 0.55), 0.23, 0.95)),
    _p("deck_pods_long", "Par de canhões longos", deck_pods_long, "027", sign=False, depth=0.95,
       stack=_pods_stack((-0.55, 0.55), 0.20, 0.95)),
    _p("deck_pods_five", "Bateria de 5 canhões", deck_pods_five, "028", sign=False,
       stack=_pods_stack((-0.80, -0.40, 0.0, 0.40, 0.80), 0.15, 0.95)),
]
