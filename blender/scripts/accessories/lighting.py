"""Categoria B — Teto e iluminação (8 peças). Origem = ponto de montagem sobre o teto; +Y para frente."""
import math
import os

from lib import mesh3d as M

CHROMES = ["chrome", "steel", "paint_gold"]
FONT = os.path.abspath("game/assets/fonts/NotoSansJP.ttf")


def _feet(m, xs, y=0.0):
    out = []
    for i, x in enumerate(xs):
        out.append(M.box(f"foot_{i}", (0.28, 0.2, 0.04), (x, y, 0.02), m["steel"], bevel=0.01, seg=1))
        out.append(M.cylinder(f"bolt_{i}", 0.02, 0.05, (x, y, 0.06), m["chrome"], axis="Z", seg=8))
    return out


def roof_light_bracket(m):
    """Suporte de iluminação para o teto: estrutura em U cromada com 4 pés, escoras e travessa."""
    o = []
    add = o.append
    w = 2.3
    add(M.box("base_rail", (w, 0.14, 0.1), (0, 0, 0.1), m["chrome"], bevel=0.025, seg=2))
    add(M.box("top_rail", (w, 0.12, 0.08), (0, 0, 0.62), m["chrome"], bevel=0.025, seg=2))
    for sx in (-1, 1):
        add(M.box(f"post_{sx}", (0.1, 0.12, 0.56), (sx * (w / 2 - 0.05), 0, 0.36), m["chrome"], bevel=0.025, seg=2))
        add(M.box(f"brace_{sx}", (0.05, 0.05, 0.55), (sx * (w / 2 - 0.35), 0, 0.36), m["steel"], bevel=0.01, seg=1, rot=(0, sx * 35, 0)))
    for x in (-0.55, 0.0, 0.55):
        add(M.box(f"strut_{x}", (0.06, 0.1, 0.5), (x, 0, 0.36), m["chrome"], bevel=0.015, seg=2))
        add(M.box(f"clip_{x}", (0.14, 0.14, 0.05), (x, 0, 0.67), m["steel"], bevel=0.01, seg=1))
    o += _feet(m, (-1.05, -0.35, 0.35, 1.05))
    return o


def roof_light_bar_rect(m):
    """Barra de luzes retangulares: 8 módulos âmbar em carcaça cromada com viseira."""
    o = []
    add = o.append
    add(M.box("housing", (2.3, 0.22, 0.3), (0, 0, 0.3), m["chrome"], bevel=0.04, seg=2))
    add(M.box("visor", (2.34, 0.2, 0.04), (0, 0.1, 0.5), m["chrome"], bevel=0.01, seg=1, rot=(-12, 0, 0)))
    for i in range(8):
        x = -0.98 + i * 0.28
        add(M.box(f"lamp_{i}", (0.22, 0.04, 0.2), (x, 0.12, 0.3), m["lamp_amber"], bevel=0.02, seg=1))
    o += _feet(m, (-1.0, 0.0, 1.0))
    return o


def roof_round_lamps_set(m):
    """Conjunto de faróis redondos: 5 faróis de tamanhos alternados sobre barra cromada."""
    o = []
    add = o.append
    add(M.box("rail", (2.3, 0.16, 0.08), (0, 0, 0.1), m["chrome"], bevel=0.02, seg=2))
    for i, (x, r) in enumerate(((-0.92, 0.17), (-0.46, 0.21), (0.0, 0.26), (0.46, 0.21), (0.92, 0.17))):
        z = 0.2 + r
        add(M.cylinder(f"housing_{i}", r, 0.2, (x, 0.04, z), m["chrome"], axis="Y", seg=18, bevel=0.015, bevel_seg=1))
        add(M.torus(f"ring_{i}", r * 0.95, 0.025, (x, 0.145, z), m["chrome"], axis="Y", seg=18, tube_seg=6))
        add(M.cylinder(f"lens_{i}", r * 0.86, 0.03, (x, 0.145, z), m["lamp_white"], axis="Y", seg=18))
        add(M.box(f"post_{i}", (0.07, 0.07, z - 0.1), (x, 0.0, 0.1 + (z - 0.1) / 2), m["steel"], bevel=0.01, seg=1))
    o += _feet(m, (-1.0, 1.0))
    return o


def roof_marker_small_lamps(m):
    """Conjunto de lanternas pequenas: fileira de 9 lanternas em domo, cores alternadas."""
    o = []
    add = o.append
    add(M.box("rail", (2.2, 0.1, 0.05), (0, 0, 0.07), m["steel"], bevel=0.01, seg=1))
    for i in range(9):
        x = -1.0 + i * 0.25
        col = m["lamp_amber"] if i % 2 == 0 else m["lamp_white"]
        add(M.cylinder(f"base_{i}", 0.075, 0.05, (x, 0, 0.12), m["chrome"], axis="Z", seg=14))
        add(M.sphere(f"dome_{i}", 0.07, (x, 0, 0.17), col, seg=14, rings=8, scale=(1, 1, 0.9)))
    o += _feet(m, (-1.0, 1.0))
    return o


def antenna_decor_mount(m):
    """Suporte de antena decorativa: base, 2 antenas com mola, flâmula e ponta luminosa."""
    o = []
    add = o.append
    add(M.box("plate", (0.9, 0.35, 0.05), (0, 0, 0.025), m["steel"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        x = sx * 0.28
        add(M.cylinder(f"mount_{sx}", 0.07, 0.14, (x, 0, 0.12), m["chrome"], axis="Z", seg=16, bevel=0.02))
        add(M.cylinder(f"spring_{sx}", 0.045, 0.22, (x, 0, 0.3), m["steel"], axis="Z", seg=12))
        add(M.cylinder(f"whip_{sx}", 0.012, 1.55, (x, 0, 1.15), m["chrome"], axis="Z", seg=8))
        add(M.sphere(f"tip_{sx}", 0.045, (x, 0, 1.95), m["lamp_pink"], seg=12, rings=6))
        add(M.box(f"flag_{sx}", (0.012, 0.32, 0.18), (x, -0.17, 1.7), m["paint_red"], bevel=0.003, seg=1))
    add(M.cylinder("center_post", 0.02, 0.9, (0, 0, 0.5), m["steel"], axis="Z", seg=8))
    add(M.torus("center_ring", 0.1, 0.015, (0, 0, 0.9), m["chrome"], axis="Z"))
    return o


def roof_sign_lightbox(m):
    """Placa luminosa personalizável: caixa com face emissiva e texto (objeto SIGN_TEXT editável)."""
    o = []
    add = o.append
    add(M.box("box", (1.9, 0.2, 0.62), (0, 0, 0.38), m["chrome"], bevel=0.05, seg=2))
    face = M.box("SIGN_FACE", (1.74, 0.03, 0.46), (0, 0.105, 0.38), m["lamp_yellow"], bevel=0.01, seg=1)
    add(face)
    txt = M.text3d("SIGN_TEXT", "一番星", 0.38, (0, 0.13, 0.38), m["plastic"], font_path=FONT, rot=(90, 0, 180))
    add(txt)
    for sx in (-1, 1):
        add(M.box(f"leg_{sx}", (0.1, 0.12, 0.2), (sx * 0.7, 0, 0.1), m["steel"], bevel=0.015, seg=1))
    return o


def roof_light_frame_halo(m):
    """Moldura luminosa para o teto: tubo neon retangular em volta do teto com presilhas."""
    o = []
    add = o.append
    w, l = 2.2, 2.6
    pts = [(-w / 2, -l / 2), (w / 2, -l / 2), (w / 2, l / 2), (-w / 2, l / 2), (-w / 2, -l / 2)]
    path = [(x, y - 0.15, 0.07) for x, y in pts]
    add(M.tube("neon_loop", path, 0.035, m["lamp_cyan"], seg=10))
    for i, (x, y) in enumerate(pts[:-1]):
        add(M.box(f"clamp_{i}", (0.12, 0.12, 0.07), (x, y - 0.15, 0.035), m["chrome"], bevel=0.015, seg=1))
    for sx in (-1, 1):
        add(M.box(f"clamp_mid_{sx}", (0.1, 0.12, 0.07), (sx * w / 2, -0.15, 0.035), m["chrome"], bevel=0.015, seg=1))
    return o


def roof_torii_ornament(m):
    """Ornamento superior original: arco inspirado em torii com lanterna de papel luminosa."""
    o = []
    add = o.append
    for sx in (-1, 1):
        add(M.cylinder(f"pillar_{sx}", 0.06, 0.8, (sx * 0.55, 0, 0.42), m["paint_red"], axis="Z", seg=14))
        add(M.cylinder(f"base_{sx}", 0.09, 0.07, (sx * 0.55, 0, 0.04), m["chrome"], axis="Z", seg=14))
    add(M.box("kasagi", (1.55, 0.14, 0.09), (0, 0, 0.88), m["paint_red"], bevel=0.02, seg=2))
    for sx in (-1, 1):
        add(M.box(f"kasagi_tip_{sx}", (0.22, 0.14, 0.09), (sx * 0.75, 0, 0.93), m["paint_red"], bevel=0.02, seg=2, rot=(0, sx * -14, 0)))
    add(M.box("nuki", (1.3, 0.09, 0.07), (0, 0, 0.7), m["paint_gold"], bevel=0.015, seg=2))
    add(M.sphere("lantern", 0.13, (0, 0, 0.5), m["lamp_red"], seg=16, rings=10, scale=(1, 1, 1.25)))
    add(M.cylinder("lantern_cap", 0.05, 0.04, (0, 0, 0.67), m["paint_gold"], axis="Z", seg=12))
    add(M.cylinder("lantern_cap_b", 0.05, 0.04, (0, 0, 0.33), m["paint_gold"], axis="Z", seg=12))
    add(M.box("plate", (1.4, 0.3, 0.04), (0, 0, 0.02), m["steel"], bevel=0.01, seg=1))
    return o


ACCESSORIES = [
    dict(id="roof_light_bracket", name="Suporte de iluminação para o teto", category="lighting", mount="MOUNT_ROOF_LIGHTS", mirror=False,
         build=roof_light_bracket, materials={"main": CHROMES, "accent": ["steel"]}),
    dict(id="roof_light_bar_rect", name="Barra de luzes retangulares", category="lighting", mount="MOUNT_ROOF_LIGHTS", mirror=False,
         build=roof_light_bar_rect, materials={"main": CHROMES, "accent": ["lamp_amber", "lamp_white", "lamp_cyan"]}),
    dict(id="roof_round_lamps_set", name="Conjunto de faróis redondos de teto", category="lighting", mount="MOUNT_ROOF_LIGHTS", mirror=False,
         build=roof_round_lamps_set, materials={"main": CHROMES, "accent": ["lamp_white", "lamp_amber"]}),
    dict(id="roof_marker_small_lamps", name="Conjunto de lanternas pequenas", category="lighting", mount="MOUNT_ROOF_LIGHTS", mirror=False,
         build=roof_marker_small_lamps, materials={"main": CHROMES, "accent": ["lamp_amber", "lamp_white", "lamp_pink"]}),
    dict(id="antenna_decor_mount", name="Suporte de antena decorativa", category="lighting", mount="MOUNT_ROOF", mirror=False,
         build=antenna_decor_mount, materials={"main": CHROMES, "accent": ["lamp_pink", "lamp_cyan"]}),
    dict(id="roof_sign_lightbox", name="Placa luminosa personalizável", category="lighting", mount="MOUNT_ROOF", mirror=False,
         build=roof_sign_lightbox, customizable={"text_node": "SIGN_TEXT", "face_node": "SIGN_FACE"},
         materials={"main": CHROMES, "accent": ["lamp_yellow", "lamp_pink", "lamp_cyan", "lamp_white"]}),
    dict(id="roof_light_frame_halo", name="Moldura luminosa para teto", category="lighting", mount="MOUNT_ROOF", mirror=False,
         build=roof_light_frame_halo, materials={"main": ["lamp_cyan", "lamp_pink", "lamp_yellow"], "accent": CHROMES}),
    dict(id="roof_torii_ornament", name="Ornamento superior torii com lanterna", category="lighting", mount="MOUNT_BODY_ROOF", mirror=False,
         build=roof_torii_ornament, materials={"main": ["paint_red", "paint_gold", "paint_pink"], "accent": ["lamp_red", "lamp_amber"]}),
]
