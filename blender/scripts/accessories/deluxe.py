"""Peças DELUXE (T-172): amostras com acabamento bem acima das 32 originais, pedidas pelo Marco ("muito detalhe: neon,
pisca, estribo/estrutura, baú/andon em cima da cabine igual ao Bakusou Dekotora Densetsu").

O que muda em relação às peças antigas (caixas chanfradas):
- cromo com espessura e perfil (moldura varrida com coroa e bisel: `deluxe_geo.frame`), parafusos sextavados;
- lâmpadas por revolução (copo cromado + lente com degraus de Fresnel), lanterna de ônibus japonesa;
- acrílico leitoso iluminado (textura na cor e na emissão), inox "uroko" em mapa de normais;
- brilho do neon no chão (quadrado `glow_floor_*`: o jogo troca por um shader aditivo que acende à noite).

Origem = ponto de montagem; +Y frente, +X direita (peças de lado: modeladas para a DIREITA), +Z cima, metros.
Orçamento: até 6.000 triângulos por peça (`tier = "deluxe"` no catálogo); as antigas continuam com 4.500.
"""
import math
import os

from lib import deluxe_geo as G
from lib import mesh3d as M

CHROMES = ["chrome", "steel", "paint_gold"]
## Altura do brilho no chão acima do chão do caminhão: 11 cm (a plataforma giratória da garagem tem 10 cm e cobriria o
## brilho; na pista a diferença não aparece porque o quadrado fica embaixo do chassi).
GLOW_LIFT = 0.11
LAMPS = ["lamp_amber", "lamp_yellow", "lamp_pink", "lamp_cyan"]
FONT = os.path.abspath("game/assets/fonts/NotoSansJP.ttf")


def _mats(m):
    if "acrylic_andon" not in m:
        G.deluxe_set(m)
    return m


def _fit_text(t, max_w, max_h):
    """Encolhe o texto (já com transformações aplicadas) para caber em max_w x max_h (no plano XZ)."""
    M.apply_transforms([t])
    xs = [v.co.x for v in t.data.vertices]
    zs = [v.co.z for v in t.data.vertices]
    if not xs:
        return
    cx, cz = (max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2
    k = min(max_w / max(max(xs) - min(xs), 1e-6), max_h / max(max(zs) - min(zs), 1e-6), 1.0)
    for v in t.data.vertices:
        v.co.x = cx + (v.co.x - cx) * k
        v.co.z = cz + (v.co.z - cz) * k


# ============================================================================ 1. andon da cabine (一番星)

def andon_ichiban_dx(m):
    """Andon de cabine "Ichibanboshi" deluxe: caixa de luz alta sobre o teto da cabine (a "caixa em cima da cabine"
    dos caminhões do Bakusou Dekotora Densetsu). Moldura cromada com perfil (coroa + bisel + degrau interno),
    acrílico leitoso aceso por dentro, letreiro trocável (SIGN_TEXT), 17 lâmpadas em copos cromados na moldura,
    chapéu cromado, chifres (tsuno) com bola de luz, pés tubulares com escoras e sapatas parafusadas."""
    m = _mats(m)
    o = []
    add = o.append
    ext = o.extend
    w, h, bar = 2.0, 0.56, 0.075             # abertura do acrílico e largura da moldura
    W, H = w + 2 * bar, h + 2 * bar
    yc, D = 0.42, 0.30                       # centro da caixa (à frente do meio do teto) e profundidade
    zb = 0.27                                # base da caixa acima do teto
    zc = zb + H / 2
    yf = yc + D / 2 - 0.04                   # plano da frente da moldura
    # caixa (costas e laterais em aço escovado) + friso cromado nas laterais
    add(M.box("shell", (W - 0.03, D - 0.06, H - 0.03), (0, yc - 0.03, zc), m["steel"], bevel=0.025, seg=2))
    for sx in (-1, 1):
        for k, dz in enumerate((-0.16, 0.0, 0.16)):
            add(M.box(f"side_strip_{sx}_{k}", (0.012, D - 0.12, 0.022), (sx * (W / 2 - 0.006), yc - 0.03, zc + dz), m["chrome"], bevel=0.0, seg=1))
    for k, x in enumerate((-0.62, 0.0, 0.62)):            # nervuras das costas
        add(M.box(f"back_rib_{k}", (0.05, 0.02, H - 0.12), (x, yc - D / 2 - 0.0, zc), m["steel"], bevel=0.008, seg=1))
    for k, (x, z) in enumerate(((-0.9, zc + 0.24), (0.9, zc + 0.24), (-0.9, zc - 0.24), (0.9, zc - 0.24), (-0.31, zc), (0.31, zc))):
        ext(G.hex_bolt(f"back_bolt_{k}", (x, yc - D / 2 + 0.005, z), 0.012, "Y", -1, m["chrome"]))
    # moldura da frente com espessura (perfil varrido) e degrau interno (linha de sombra)
    add(G.frame("frame", w, h, G.chrome_lip_profile(bar, 0.08, crown=0.02), (0, yf, zc), m["chrome"], r=0.035, n=3))
    add(G.frame("bezel", w - 0.02, h - 0.02, [(0.0, -0.03), (0.0, 0.0), (0.012, 0.006), (0.024, 0.0), (0.024, -0.03)],
                (0, yf - 0.012, zc), m["chrome"], r=0.025, n=2))
    for k, (x, z) in enumerate([(sx * (W / 2 - bar / 2), zc + sz * (H / 2 - bar / 2)) for sx in (-1, 1) for sz in (-1, 1)]):
        ext(G.hex_bolt(f"corner_bolt_{k}", (x, yf + 0.02, z), 0.014, "Y", 1, m["chrome"]))
    # acrílico leitoso (UV 0..1 na frente: a textura tem as faixas dos tubos e a sombra da moldura)
    face = M.box("SIGN_FACE", (w + 0.012, 0.012, h + 0.012), (0, yf - 0.02, zc), m["acrylic_andon"], bevel=0.0, seg=1)
    M.uv_planar(face)
    add(face)
    txt = M.text3d("SIGN_TEXT", "一番星", 1.0, (0, yf - 0.01, zc), m["andon_ink"], font_path=FONT, extrude=0.005,
                   rot=(90, 0, 180), resolution=4, offset=0.014)
    _fit_text(txt, w * 0.84, h * 0.8)
    add(txt)
    # lâmpadas na coroa da moldura: 11 em cima, 3 em cada lado (olham para a frente)
    zt = zc + h / 2 + bar / 2
    for k in range(11):
        x = -0.9 + k * 0.18
        ext(G.bulb(f"top_bulb_{k}", (x, yf + 0.016, zt), 0.021, m["chrome"], m["lamp_amber"], "Y", 1, seg=8))
    for sx in (-1, 1):
        for k in range(3):
            z = zc - 0.17 + k * 0.17
            ext(G.bulb(f"side_bulb_{sx}_{k}", (sx * (w / 2 + bar / 2), yf + 0.016, z), 0.021, m["chrome"], m["lamp_amber"], "Y", 1, seg=8))
    # chapéu cromado com aba na frente
    ztop = zc + H / 2
    add(M.box("cap", (W + 0.1, D + 0.08, 0.035), (0, yc + 0.01, ztop + 0.0175), m["chrome"], bevel=0.012, seg=2))
    add(M.box("cap_lip", (W + 0.06, 0.03, 0.05), (0, yc + D / 2 + 0.04, ztop + 0.0), m["chrome"], bevel=0.01, seg=2))
    # chifres (tsuno) nos cantos de cima, com bola de luz rosa
    for sx in (-1, 1):
        x0 = sx * (W / 2 - 0.04)
        pts = [(x0, yc + 0.05, ztop + 0.03), (x0 + sx * 0.05, yc + 0.06, ztop + 0.11), (x0 + sx * 0.12, yc + 0.08, ztop + 0.17),
               (x0 + sx * 0.2, yc + 0.1, ztop + 0.2)]
        add(M.tube(f"tsuno_{sx}", pts, 0.018, m["chrome"], seg=6))
        add(M.sphere(f"tsuno_tip_{sx}", 0.035, pts[-1], m["lamp_pink"], seg=8, rings=5))
        add(M.cylinder(f"tsuno_base_{sx}", 0.04, 0.03, (x0, yc + 0.05, ztop + 0.045), m["chrome"], axis="Z", seg=10))
    # pés: 4 colunas tubulares com sapatas parafusadas e 2 escoras para trás
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 0.82, yc + sy * 0.09
            add(M.cylinder(f"leg_{sx}_{sy}", 0.024, zb - 0.03, (x, y, 0.03 + (zb - 0.03) / 2), m["chrome"], axis="Z", seg=10))
            add(M.box(f"foot_{sx}_{sy}", (0.11, 0.1, 0.022), (x, y, 0.011), m["chrome"], bevel=0.006, seg=1))
            ext(G.hex_bolt(f"foot_bolt_{sx}_{sy}", (x + 0.035, y, 0.022), 0.009, "Z", 1, m["steel"]))
        add(M.tube(f"brace_{sx}", [(sx * 0.82, yc - 0.12, zb + 0.06), (sx * 0.82, yc - 0.62, 0.03)], 0.016, m["chrome"], seg=8))
        add(M.box(f"brace_foot_{sx}", (0.1, 0.12, 0.022), (sx * 0.82, yc - 0.64, 0.011), m["chrome"], bevel=0.006, seg=1))
        add(M.box(f"rail_{sx}", (0.05, D + 0.04, 0.04), (sx * 0.82, yc, zb - 0.0), m["chrome"], bevel=0.012, seg=2))
    return o


# ============================================================================ 2. coroa de lanternas de ônibus (pisca)

def marker_crown_dx(m):
    """Coroa de lanternas de ônibus (バスマーカー): barra cromada curva (pontas recuam) com 9 lanternas âmbar de
    corpo cromado e lente em degraus; abraçadeiras parafusadas. As lentes piscam com o padrão de luzes da garagem."""
    m = _mats(m)
    o = []
    add = o.append
    ext = o.extend
    hw = 1.1
    path = []
    for k in range(13):
        x = -hw + 2 * hw * k / 12
        path.append((x, -0.14 * (x / hw) ** 2, 0.1))
    add(G.sweep_open("bar", path, G.rounded_rect_profile(0.09, 0.07, 0.025, 2), m["chrome"]))
    for sx in (-1, 1):                                     # ponteiras arredondadas
        add(M.sphere(f"bar_end_{sx}", 0.042, (sx * hw, -0.14, 0.1), m["chrome"], seg=12, rings=6, scale=(1, 1.1, 0.85)))
    for k in range(9):
        x = -0.96 + k * 0.24
        y = -0.14 * (x / hw) ** 2
        ext(G.bus_marker(f"marker_{k}", (x, y, 0.135), m["chrome"], m["lamp_amber"], r=0.05, seg=12))
    for k, x in enumerate((-0.8, -0.27, 0.27, 0.8)):           # abraçadeiras e pés
        y = -0.14 * (x / hw) ** 2
        add(M.box(f"clamp_{k}", (0.07, 0.11, 0.09), (x, y, 0.1), m["steel"], bevel=0.01, seg=1))
        add(M.box(f"post_{k}", (0.04, 0.05, 0.06), (x, y - 0.0, 0.035), m["steel"], bevel=0.008, seg=1))
        add(M.box(f"pad_{k}", (0.1, 0.12, 0.016), (x, y, 0.008), m["steel"], bevel=0.005, seg=1))
        ext(G.hex_bolt(f"clamp_bolt_{k}", (x, y + 0.055, 0.1), 0.01, "Y", 1, m["chrome"]))
    return o


# ============================================================================ 3. neon de chão (underglow)

def underglow_neon_dx(m):
    """Neon de chão: tubo neon dentro de canaleta de alumínio presa por abraçadeiras sob o chassi, com tampas, cabo
    e o brilho no asfalto (quadrado glow_floor: aditivo, acende à noite e no túnel, quase some de dia)."""
    m = _mats(m)
    o = []
    add = o.append
    ext = o.extend
    x, z = -0.38, -0.53
    y0, y1 = 0.15, 4.05
    add(G.channel_y("channel", y0, y1, 0.07, 0.05, 0.008, (x, 0.0, z), m["chrome"]))
    add(M.cylinder("neon", 0.016, y1 - y0 - 0.06, (x, (y0 + y1) / 2, z - 0.032), m["lamp_cyan"], axis="Y", seg=10))
    for k, y in enumerate((y0, y1)):
        add(M.box(f"end_cap_{k}", (0.08, 0.05, 0.06), (x, y, z - 0.022), m["plastic"], bevel=0.012, seg=1))
    add(M.cylinder("gland", 0.012, 0.05, (x, y1 + 0.04, z - 0.02), m["plastic"], axis="Y", seg=8))
    add(M.tube("cable", [(x, y1 + 0.06, z - 0.02), (x, y1 + 0.18, z + 0.02), (x - 0.06, y1 + 0.24, z + 0.22)], 0.007, m["plastic"], seg=6))
    for k in range(6):
        y = y0 + 0.25 + k * (y1 - y0 - 0.5) / 5
        add(M.box(f"clip_{k}", (0.09, 0.035, 0.012), (x, y, z + 0.006), m["chrome"], bevel=0.004, seg=1))
        add(M.box(f"clip_arm_{k}", (0.02, 0.03, 0.16), (x - 0.03, y, z + 0.09), m["plastic"], bevel=0.004, seg=1))
        ext(G.hex_bolt(f"clip_bolt_{k}", (x + 0.03, y, z + 0.012), 0.008, "Z", 1, m["chrome"]))
    # brilho no chão (Z do chão = -0,95 no ponto de montagem do baú, que fica a 0,95 m)
    add(G.floor_glow("glow", 1.7, (y1 - y0) + 0.9, (x + 0.12, (y0 + y1) / 2, -0.95 + GLOW_LIFT), m["glow_floor_cyan"]))
    return o


# ============================================================================ 4. estrutura lateral cromada (side bumper)

SIDE_OUT = 0.18


def side_bumper_dx(m):
    """Estrutura lateral cromada (サイドバンパー): trilho de cima arredondado com 10 lâmpadas, painel de inox com escama
    "uroko" (mapa de normais), trilho de baixo com 6 lanternas retangulares em molduras parafusadas, ponteiras
    arredondadas e suportes pretos. Mesmo comprimento das saias (4,2 m à frente do ponto)."""
    m = _mats(m)
    o = []
    add = o.append
    ext = o.extend
    L0, L1 = 0.05, 4.15
    Lm = (L0 + L1) / 2
    top = [(0.0, 0.0), (0.075, 0.0), (0.105, -0.016), (0.118, -0.042), (0.105, -0.068), (0.075, -0.084), (0.0, -0.084)]
    add(M.plane_extrude("rail_top", top, L1 - L0, (0.0, Lm, -0.06), m["chrome"], plane="XZ", bevel=0.004, seg=1))
    low = [(0.0, 0.0), (0.11, 0.0), (0.135, -0.02), (0.14, -0.06), (0.135, -0.1), (0.11, -0.12), (0.0, -0.12)]
    add(M.plane_extrude("rail_low", low, L1 - L0, (0.0, Lm, -0.47), m["chrome"], plane="XZ", bevel=0.005, seg=1))
    panel = M.box("panel", (0.025, L1 - L0 - 0.02, 0.33), (0.075, Lm, -0.31), m["steel_uroko"], bevel=0.006, seg=1, rot=(0, -6, 0))
    M.apply_transforms([panel])
    G.uv_box_meters(panel, 0.24)
    add(panel)
    for k, y in enumerate((L0, L1)):                      # ponteiras arredondadas (frente e trás)
        add(M.box(f"end_{k}", (0.15, 0.07, 0.56), (0.065, y, -0.33), m["chrome"], bevel=0.035, seg=3))
    for k in range(10):                                   # lâmpadas no trilho de cima (olham para fora)
        y = L0 + 0.25 + k * (L1 - L0 - 0.5) / 9
        ext(G.bulb(f"top_bulb_{k}", (0.112, y, -0.102), 0.019, m["chrome"], m["lamp_amber"], "X", 1, seg=8))
    for k in range(6):                                    # lanternas retangulares no trilho de baixo
        y = L0 + 0.4 + k * (L1 - L0 - 0.8) / 5
        add(G.frame(f"marker_bezel_{k}", 0.17, 0.05, [(0.0, -0.012), (0.0, 0.0), (0.008, 0.007), (0.018, 0.0), (0.018, -0.012)],
                    (0.14, y, -0.53), m["chrome"], r=0.012, n=2, plane="YZ"))
        add(M.box(f"marker_lens_{k}", (0.016, 0.172, 0.052), (0.138, y, -0.53), m["lamp_amber"], bevel=0.006, seg=1))
        for sy in (-1, 1):
            ext(G.hex_bolt(f"marker_bolt_{k}_{sy}", (0.142, y + sy * 0.11, -0.53), 0.008, "X", 1, m["chrome"]))
    for k in range(4):                                    # suportes até o chassi
        y = L0 + 0.35 + k * (L1 - L0 - 0.7) / 3
        add(M.box(f"bracket_{k}", (0.34, 0.06, 0.05), (-0.15, y, -0.12), m["plastic"], bevel=0.01, seg=1))
        add(M.box(f"bracket_low_{k}", (0.34, 0.06, 0.05), (-0.15, y, -0.5), m["plastic"], bevel=0.01, seg=1))
        add(M.box(f"bracket_v_{k}", (0.04, 0.06, 0.42), (-0.3, y, -0.31), m["plastic"], bevel=0.01, seg=1))
    for ob in o:                                          # para fora: cobre o tanque de fábrica (que sai ~0,15 m do baú)
        ob.location.x += SIDE_OUT
    return o


# ============================================================================ 5. estribo cromado iluminado

def step_lit_dx(m):
    """Estribo cromado de 2 degraus: laterais de chapa cromada com borda, pisos de chapa xadrez, bocel cromado,
    fita de LED sob cada degrau e luz de cortesia no chão (glow_floor). Parafusos aparentes."""
    m = _mats(m)
    o = []
    add = o.append
    ext = o.extend
    ya, yb = -0.38, 0.22                      # longe da roda da frente (o ponto fica 0,3 m antes dela)
    yc = (ya + yb) / 2
    wy = yb - ya - 0.06
    side = [(-0.04, 0.05), (0.3, 0.05), (0.34, -0.06), (0.36, -0.33), (0.0, -0.33), (-0.04, -0.2)]
    for k, y in enumerate((ya, yb)):
        add(M.plane_extrude(f"stringer_{k}", side, 0.022, (0.0, y, 0.0), m["chrome"], plane="XZ", bevel=0.006, seg=1))
        for j, (x, z) in enumerate(((0.04, 0.0), (0.2, -0.04), (0.08, -0.26), (0.28, -0.27))):
            ext(G.hex_bolt(f"str_bolt_{k}_{j}", (x, y + (0.011 if y > 0 else -0.011), z), 0.009, "Y", 1 if y > 0 else -1, m["steel"]))
    for k, (x0, x1, z) in enumerate(((-0.02, 0.29, 0.0), (0.02, 0.35, -0.27))):
        tread = M.box(f"tread_{k}", (x1 - x0, wy, 0.03), ((x0 + x1) / 2, yc, z), m["diamond"], bevel=0.004, seg=1)
        M.apply_transforms([tread])
        G.uv_box_meters(tread, 0.2)
        add(tread)
        add(M.cylinder(f"nosing_{k}", 0.02, wy, (x1 - 0.005, yc, z + 0.002), m["chrome"], axis="Y", seg=10))
        add(M.box(f"led_{k}", (0.012, wy - 0.06, 0.014), (x1 - 0.03, yc, z - 0.025), m["lamp_cyan"], bevel=0.003, seg=1))
    for k, y in enumerate((ya + 0.08, yb - 0.08)):          # braços até a cabine
        add(M.box(f"arm_{k}", (0.14, 0.05, 0.05), (-0.09, y, -0.05), m["plastic"], bevel=0.01, seg=1))
    add(G.floor_glow("glow", 0.9, 0.95, (0.32, yc, -0.55 + GLOW_LIFT), m["glow_floor_cyan"]))
    return o


# ============================================================================ 6. barra traseira de lanternas (pisca)

def rear_tail_bar_dx(m):
    """Barra traseira de 16 lanternas redondas (連結テール): chapa cromada com moldura de perfil, fileira de cima âmbar
    (pisca com o padrão de luzes), de baixo vermelha (lanterna), aros cromados com degrau e lentes com anéis."""
    m = _mats(m)
    o = []
    add = o.append
    ext = o.extend
    w, h = 1.86, 0.46
    yb = -0.07                                             # costas da chapa (folga das ferragens da porta do baú)
    add(M.box("plate", (w, 0.035, h), (0, yb - 0.0175, 0.0), m["chrome"], bevel=0.012, seg=2))
    prof = [(o_, -d) for o_, d in G.chrome_lip_profile(0.05, 0.03, crown=0.016)]
    add(G.frame("plate_frame", w, h, prof, (0, yb - 0.035, 0.0), m["chrome"], r=0.04, n=3))
    for k in range(8):
        x = -0.84 + k * 0.24
        ext(G.round_tail(f"amber_{k}", (x, yb - 0.035, 0.115), 0.075, m["chrome"], m["lamp_amber"], seg=12))
        ext(G.round_tail(f"red_{k}", (x, yb - 0.035, -0.115), 0.075, m["chrome"], m["lamp_red"], seg=12))
    for k, (x, z) in enumerate([(sx * (w / 2 - 0.0), sz * (h / 2 - 0.0)) for sx in (-1, 1) for sz in (-1, 1)]):
        ext(G.hex_bolt(f"plate_bolt_{k}", (x * 0.985, yb - 0.06, z * 0.93), 0.012, "Y", -1, m["chrome"], washer=True))
    return o


ACCESSORIES = [
    dict(id="andon_ichiban_dx", name="Andon de cabine 一番星 deluxe", category="lighting", mount="MOUNT_ROOF", mirror=False, tier="deluxe",
         build=andon_ichiban_dx, customizable={"text_node": "SIGN_TEXT", "face_node": "SIGN_FACE"},
         materials={"main": CHROMES, "accent": LAMPS, "ink": ["andon_ink", "plastic", "paint_blue"]}),
    dict(id="marker_crown_dx", name="Coroa de lanternas de ônibus deluxe", category="lighting", mount="MOUNT_ROOF_LIGHTS", mirror=False,
         tier="deluxe", build=marker_crown_dx, materials={"main": CHROMES, "accent": LAMPS}),
    dict(id="underglow_neon_dx", name="Neon de chão deluxe", category="sides", mount="MOUNT_SIDE_R", mirror=True, tier="deluxe",
         build=underglow_neon_dx, materials={"main": CHROMES, "accent": LAMPS}),
    dict(id="side_bumper_dx", name="Estrutura lateral cromada deluxe", category="sides", mount="MOUNT_SIDE_R", mirror=True, tier="deluxe",
         build=side_bumper_dx, materials={"main": CHROMES, "accent": LAMPS}),
    dict(id="step_lit_dx", name="Estribo cromado iluminado deluxe", category="sides", mount="MOUNT_STEP_R", mirror=True, tier="deluxe",
         build=step_lit_dx, materials={"main": CHROMES, "accent": LAMPS}),
    dict(id="rear_tail_bar_dx", name="Barra traseira de 16 lanternas deluxe", category="rear", mount="MOUNT_REAR_LAMPS", mirror=False,
         tier="deluxe", build=rear_tail_bar_dx, materials={"main": CHROMES, "accent": LAMPS}),
]
