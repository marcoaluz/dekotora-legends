"""Categoria D — Traseira e decoração (8 peças). Origem = ponto de montagem; a traseira do baú fica em
Y=0 e as peças saem para -Y (para trás). Peças laterais usam o lado direito (+X) e são espelhadas."""
import math
import os

from lib import mesh3d as M

CHROMES = ["chrome", "steel", "paint_gold"]
FONT = os.path.abspath("game/assets/fonts/NotoSansJP.ttf")


def rb_decorative(m):
    """Para-choque traseiro decorativo: barra com degraus, pontas cromadas, nicho de placa e refletores."""
    o = []
    add = o.append
    add(M.box("bar", (2.5, 0.3, 0.28), (0, -0.2, 0.0), m["chrome"], bevel=0.07, seg=3))
    add(M.box("top_step", (2.2, 0.22, 0.08), (0, -0.16, 0.18), m["chrome"], bevel=0.03, seg=2))
    for sx in (-1, 1):
        add(M.cylinder(f"cap_{sx}", 0.16, 0.32, (sx * 1.25, -0.2, 0.0), m["chrome"], axis="Y", seg=18, bevel=0.03))
        add(M.box(f"reflector_{sx}", (0.18, 0.03, 0.1), (sx * 1.0, -0.37, 0.0), m["lamp_red"], bevel=0.01, seg=1))
        add(M.box(f"strut_{sx}", (0.16, 0.3, 0.45), (sx * 0.8, 0.12, 0.05), m["plastic"], bevel=0.03))
        add(M.box(f"fin_{sx}", (0.06, 0.12, 0.2), (sx * 0.5, -0.37, 0.0), m["paint_pink"], bevel=0.01, seg=1))
    add(M.box("plate_niche", (0.62, 0.03, 0.22), (0, -0.365, 0.0), m["plastic"], bevel=0.01, seg=1))
    return o


def rear_panel_frame(m):
    """Painel traseiro com moldura: moldura cromada com cantos ornamentais e placa interna pintada."""
    o = []
    add = o.append
    w, h = 2.2, 1.7
    add(M.box("plate", (w - 0.1, 0.03, h - 0.1), (0, -0.015, 0.0), m["paint_blue"], bevel=0.01, seg=1))
    add(M.box("top", (w, 0.07, 0.1), (0, -0.03, h / 2), m["chrome"], bevel=0.02, seg=2))
    add(M.box("bottom", (w, 0.07, 0.1), (0, -0.03, -h / 2), m["chrome"], bevel=0.02, seg=2))
    for sx in (-1, 1):
        add(M.box(f"side_{sx}", (0.1, 0.07, h), (sx * w / 2, -0.03, 0.0), m["chrome"], bevel=0.02, seg=2))
        for sz in (-1, 1):
            add(M.cylinder(f"corner_{sx}_{sz}", 0.11, 0.1, (sx * w / 2, -0.04, sz * h / 2), m["paint_gold"], axis="Y", seg=18, bevel=0.015, bevel_seg=1))
            add(M.cylinder(f"gem_{sx}_{sz}", 0.04, 0.12, (sx * w / 2, -0.05, sz * h / 2), m["lamp_pink"], axis="Y", seg=10))
    add(M.torus("center_ring", 0.3, 0.025, (0, -0.04, 0.0), m["chrome"], axis="Y"))
    add(M.cylinder("center_disc", 0.26, 0.03, (0, -0.035, 0.0), m["paint_gold"], axis="Y", seg=24))
    return o


def rear_lamp_cluster(m):
    """Conjunto de lanternas traseiras: dois blocos com 3 lanternas redondas (vermelha, âmbar, branca)."""
    o = []
    add = o.append
    for sx in (-1, 1):
        x = sx * 1.0
        add(M.box(f"housing_{sx}", (0.42, 0.1, 1.0), (x, -0.05, 0.0), m["chrome"], bevel=0.05, seg=2))
        for k, (mat, z) in enumerate((("lamp_red", 0.32), ("lamp_amber", 0.0), ("lamp_white", -0.32))):
            add(M.torus(f"ring_{sx}_{k}", 0.135, 0.02, (x, -0.1, z), m["chrome"], axis="Y"))
            add(M.cylinder(f"lens_{sx}_{k}", 0.125, 0.04, (x, -0.1, z), m[mat], axis="Y", seg=20))
    return o


def side_panel_decor(m):
    """Painel lateral decorativo: quadro cromado com relevo de raios (original) em rosa e dourado."""
    o = []
    add = o.append
    L, H = 4.6, 1.0
    add(M.box("plate", (0.03, L, H), (0.015, 0, 0), m["paint_blue"], bevel=0.008, seg=1))
    add(M.box("frame_top", (0.06, L + 0.1, 0.07), (0.03, 0, H / 2), m["chrome"], bevel=0.015, seg=2))
    add(M.box("frame_bot", (0.06, L + 0.1, 0.07), (0.03, 0, -H / 2), m["chrome"], bevel=0.015, seg=2))
    for sy in (-1, 1):
        add(M.box(f"frame_end_{sy}", (0.06, 0.07, H), (0.03, sy * L / 2, 0), m["chrome"], bevel=0.015, seg=2))
    # raios (zigue-zague) repetidos
    for i in range(6):
        y = -1.9 + i * 0.76
        bolt = [(y - 0.2, 0.36), (y + 0.05, 0.36), (y - 0.02, 0.06), (y + 0.2, 0.06), (y - 0.12, -0.36), (y - 0.08, -0.06), (y - 0.3, -0.06)]
        mat = m["paint_pink"] if i % 2 == 0 else m["paint_gold"]
        add(M.plane_extrude(f"bolt_{i}", bolt, 0.03, (0.03, 0, 0), mat, plane="YZ", bevel=0.006, seg=1))
    return o


def rear_plate_custom(m):
    """Placa decorativa personalizável: moldura, face e texto editável (objeto PLATE_TEXT)."""
    o = []
    add = o.append
    add(M.box("frame", (0.62, 0.05, 0.3), (0, -0.025, 0.0), m["chrome"], bevel=0.02, seg=2))
    add(M.box("PLATE_FACE", (0.54, 0.03, 0.22), (0, -0.05, 0.0), m["paint_white"], bevel=0.008, seg=1))
    add(M.text3d("PLATE_TEXT", "一番星", 0.15, (0, -0.07, 0.0), m["plastic"], font_path=FONT, rot=(90, 0, 0), extrude=0.005))
    for sx in (-1, 1):
        add(M.cylinder(f"lamp_{sx}", 0.04, 0.05, (sx * 0.22, -0.04, 0.2), m["lamp_white"], axis="Y", seg=10))
        add(M.cylinder(f"bolt_{sx}", 0.015, 0.03, (sx * 0.27, -0.06, -0.1), m["steel"], axis="Y", seg=8))
    add(M.box("light_bar", (0.5, 0.05, 0.04), (0, -0.04, 0.2), m["chrome"], bevel=0.01, seg=1))
    return o


def mudflap_designed(m):
    """Para-barro com desenho original: borracha com estrela em relevo, barra cromada e suportes."""
    o = []
    add = o.append
    add(M.box("flap", (0.5, 0.04, 0.55), (0, -0.02, -0.28), m["rubber"], bevel=0.012, seg=1))
    star = []
    for k in range(10):
        a = math.tau * k / 10 + math.pi / 2
        r = 0.14 if k % 2 == 0 else 0.06
        star.append((math.cos(a) * r, math.sin(a) * r))
    add(M.plane_extrude("star", star, 0.015, (0, -0.045, -0.26), m["paint_pink"], plane="XZ", bevel=0.003, seg=1))
    add(M.box("weight_bar", (0.5, 0.06, 0.07), (0, -0.03, -0.55), m["chrome"], bevel=0.02, seg=2))
    add(M.box("top_bar", (0.56, 0.05, 0.05), (0, -0.01, 0.0), m["steel"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        add(M.box(f"stripe_{sx}", (0.03, 0.012, 0.4), (sx * 0.2, -0.045, -0.28), m["lamp_cyan"], bevel=0.003, seg=1))
    return o


def rear_ornament_metal(m):
    """Ornamento traseiro metálico: leque de aletas cromadas sobre a porta, com medalhão central."""
    o = []
    add = o.append
    add(M.box("base", (1.2, 0.12, 0.1), (0, -0.06, 0.05), m["chrome"], bevel=0.025, seg=2))
    for k in range(7):
        a = math.radians(-60 + k * 20)
        ln = 0.75 - abs(k - 3) * 0.08
        add(M.box(f"fin_{k}", (0.1, 0.04, ln), (math.sin(a) * (ln / 2 + 0.1), -0.08, 0.1 + math.cos(a) * (ln / 2 + 0.1)), m["chrome"], bevel=0.015, seg=2, rot=(0, math.degrees(a), 0)))
        add(M.box(f"fin_core_{k}", (0.03, 0.045, ln * 0.7), (math.sin(a) * (ln * 0.35 + 0.1), -0.085, 0.1 + math.cos(a) * (ln * 0.35 + 0.1)), m["paint_pink"], bevel=0.005, seg=1, rot=(0, math.degrees(a), 0)))
    add(M.cylinder("medal", 0.14, 0.06, (0, -0.1, 0.18), m["paint_gold"], axis="Y", seg=20, bevel=0.01, bevel_seg=1))
    add(M.cylinder("gem", 0.05, 0.07, (0, -0.12, 0.18), m["lamp_red"], axis="Y", seg=12))
    return o


def panel_japanese_theme(m):
    """Painel decorativo temático (original): sol vermelho, ondas e montanha dourada em moldura."""
    o = []
    add = o.append
    W, H = 2.0, 1.4
    add(M.box("bg", (W, 0.03, H), (0, -0.015, 0.0), m["paint_blue"], bevel=0.01, seg=1))
    add(M.cylinder("sun", 0.38, 0.03, (0.0, -0.04, 0.22), m["paint_red"], axis="Y", seg=32))
    add(M.plane_extrude("mountain", [(-0.9, -0.1), (-0.3, 0.45), (0.0, 0.1), (0.4, 0.55), (0.9, -0.1)], 0.025, (0, -0.045, -0.05), m["paint_gold"], plane="XZ", bevel=0.004, seg=1))
    for row in range(3):
        for i in range(6):
            x = -0.85 + i * 0.34 + (0.17 if row % 2 else 0.0)
            add(M.torus(f"wave_{row}_{i}", 0.14, 0.012, (x, -0.06 - row * 0.002, -0.35 - row * 0.12), m["paint_white"], axis="Y", seg=18, tube_seg=5))
    for z in (H / 2, -H / 2):
        add(M.box(f"frame_{z}", (W + 0.12, 0.06, 0.08), (0, -0.03, z), m["chrome"], bevel=0.015, seg=2))
    for sx in (-1, 1):
        add(M.box(f"frame_side_{sx}", (0.08, 0.06, H), (sx * W / 2, -0.03, 0), m["chrome"], bevel=0.015, seg=2))
    return o


ACCESSORIES = [
    dict(id="rb_decorative", name="Para-choque traseiro decorativo", category="rear", mount="MOUNT_REAR", mirror=False,
         build=rb_decorative, materials={"main": CHROMES, "accent": ["paint_pink", "lamp_red"]}),
    dict(id="rear_panel_frame", name="Painel traseiro com moldura", category="rear", mount="MOUNT_REAR_PANEL", mirror=False,
         build=rear_panel_frame, materials={"main": CHROMES, "accent": ["paint_blue", "paint_red", "paint_pink"]}),
    dict(id="rear_lamp_cluster", name="Conjunto de lanternas traseiras", category="rear", mount="MOUNT_REAR_LAMPS", mirror=False,
         build=rear_lamp_cluster, materials={"main": CHROMES, "accent": ["lamp_red", "lamp_amber", "lamp_white"]}),
    dict(id="side_panel_decor", name="Painel lateral decorativo", category="rear", mount="MOUNT_SIDE_PANEL_R", mirror=True,
         build=side_panel_decor, materials={"main": ["paint_blue", "paint_red", "paint_white"], "accent": ["paint_pink", "paint_gold"]}),
    dict(id="rear_plate_custom", name="Placa decorativa personalizável", category="rear", mount="MOUNT_REAR_PLATE", mirror=False,
         build=rear_plate_custom, customizable={"text_node": "PLATE_TEXT", "face_node": "PLATE_FACE"},
         materials={"main": CHROMES, "accent": ["paint_white", "paint_gold", "paint_pink"]}),
    dict(id="mudflap_designed", name="Para-barro com desenho original", category="rear", mount="MOUNT_MUDFLAP_R", mirror=True,
         build=mudflap_designed, materials={"main": ["rubber"], "accent": ["paint_pink", "paint_gold", "lamp_cyan"]}),
    dict(id="rear_ornament_metal", name="Ornamento traseiro metálico (leque)", category="rear", mount="MOUNT_REAR_ROOF", mirror=False,
         build=rear_ornament_metal, materials={"main": CHROMES, "accent": ["paint_pink", "lamp_red"]}),
    dict(id="panel_japanese_theme", name="Painel decorativo tema japonês", category="rear", mount="MOUNT_REAR_PANEL", mirror=False,
         build=panel_japanese_theme, materials={"main": ["paint_blue", "paint_white"], "accent": ["paint_red", "paint_gold"]}),
]
