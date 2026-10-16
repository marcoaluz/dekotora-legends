"""Categoria A — Frente (8 peças). Origem = ponto de montagem; +Y para frente."""
import math

from lib import mesh3d as M

CHROMES = ["chrome", "steel", "paint_gold"]


_LAMP_CYCLE = ["lamp_cyan", "lamp_pink", "lamp_amber", "lamp_blue", "lamp_green", "lamp_orange", "lamp_white"]


def _light_row(add, m, y, z, n, span, h, offset=0, depth=0.05):
    """Fileira de painéis luminosos coloridos com moldura cromada (visual dekotora)."""
    w = span / n
    for i in range(n):
        x = -span / 2 + w * (i + 0.5)
        add(M.box(f"pframe_{z:.2f}_{i}", (w * 0.96, depth, h + 0.04), (x, y, z), m["chrome"], bevel=0.012, seg=1))
        add(M.box(f"panel_{z:.2f}_{i}", (w * 0.8, depth + 0.02, h), (x, y + 0.012, z), m[_LAMP_CYCLE[(i + offset) % len(_LAMP_CYCLE)]], bevel=0.01, seg=1))


def fb_ornate_steps(m):
    """Para-choque ornamentado: 3 degraus cromados, aletas laterais, medalhão central e neon."""
    o = []
    add = o.append
    add(M.box("step1", (2.7, 0.5, 0.32), (0, 0.28, -0.1), m["chrome"], bevel=0.07, seg=3))
    add(M.box("step2", (2.5, 0.38, 0.28), (0, 0.2, 0.2), m["chrome"], bevel=0.06, seg=3))
    add(M.box("step3", (2.3, 0.3, 0.26), (0, 0.15, 0.46), m["chrome"], bevel=0.06, seg=3))
    for sx in (-1, 1):
        # aleta lateral varrida para trás (vista de cima)
        fin = [(sx * 1.2, -0.05), (sx * 1.48, 0.25), (sx * 1.44, 0.58), (sx * 1.1, 0.5)]
        if sx < 0:
            fin = fin[::-1]
        add(M.plane_extrude(f"fin_{sx}", fin, 0.26, (0, 0, -0.04), m["chrome"], plane="XY", bevel=0.04, seg=2))
        add(M.box(f"blinker_{sx}", (0.2, 0.06, 0.1), (sx * 1.0, 0.55, -0.12), m["lamp_amber"], bevel=0.015, seg=1))
        add(M.box(f"strut_{sx}", (0.18, 0.2, 0.55), (sx * 0.7, 0.0, 0.0), m["plastic"], bevel=0.03))
    # medalhão central
    add(M.torus("medal_ring", 0.34, 0.045, (0, 0.46, 0.2), m["chrome"], axis="Y"))
    add(M.cylinder("medal_disc", 0.3, 0.05, (0, 0.44, 0.2), m["paint_gold"], axis="Y", seg=32, bevel=0.01, bevel_seg=1))
    add(M.cylinder("medal_gem", 0.09, 0.07, (0, 0.5, 0.2), m["lamp_pink"], axis="Y", seg=16))
    add(M.box("neon_under", (2.5, 0.03, 0.04), (0, 0.55, -0.27), m["lamp_pink"], bevel=0.008, seg=1))
    _light_row(add, m, 0.54, -0.1, 9, 2.5, 0.2)
    _light_row(add, m, 0.4, 0.2, 7, 2.2, 0.18, offset=3)
    for sx in (-1, 1):                                  # painéis inclinados nas pontas, como nas referências
        add(M.box(f"wing_frame_{sx}", (0.36, 0.08, 0.5), (sx * 1.3, 0.38, 0.1), m["chrome"], bevel=0.02, seg=1, rot=(0, 0, -sx * 14)))
        add(M.box(f"wing_lamp_{sx}", (0.26, 0.09, 0.4), (sx * 1.3, 0.4, 0.1), m["lamp_blue" if sx < 0 else "lamp_orange"], bevel=0.015, seg=1, rot=(0, 0, -sx * 14)))
    for i in range(9):   # rebites
        add(M.cylinder(f"rivet_{i}", 0.025, 0.04, (-1.0 + i * 0.25, 0.4, 0.2), m["steel"], axis="Y", seg=8))
    return o


def fb_standard_chrome(m):
    """Para-choque cromado padrão: barra larga com tampas arredondadas, placa e 2 degraus."""
    o = []
    add = o.append
    add(M.box("bar", (2.6, 0.32, 0.3), (0, 0.18, 0.0), m["chrome"], bevel=0.08, seg=3))
    add(M.box("top_lip", (2.4, 0.2, 0.1), (0, 0.12, 0.2), m["chrome"], bevel=0.04, seg=2))
    for sx in (-1, 1):
        add(M.cylinder(f"cap_{sx}", 0.17, 0.34, (sx * 1.3, 0.18, 0.0), m["chrome"], axis="Y", seg=20, bevel=0.03))
        add(M.box(f"blinker_{sx}", (0.22, 0.05, 0.1), (sx * 1.0, 0.35, 0.02), m["lamp_amber"], bevel=0.015, seg=1))
        add(M.box(f"step_{sx}", (0.5, 0.3, 0.05), (sx * 0.6, 0.25, 0.17), m["steel"], bevel=0.01, seg=1))
        add(M.box(f"strut_{sx}", (0.16, 0.3, 0.4), (sx * 0.7, -0.08, 0.0), m["plastic"], bevel=0.03))
    _light_row(add, m, 0.35, 0.0, 6, 1.1, 0.14, offset=1)
    add(M.box("plate", (0.55, 0.03, 0.16), (0, 0.36, -0.02), m["paint_white"], bevel=0.008, seg=1))
    add(M.box("plate_frame", (0.6, 0.025, 0.21), (0, 0.345, -0.02), m["steel"], bevel=0.008, seg=1))
    return o


def grille_frame_chrome(m):
    """Grade frontal com moldura metálica: moldura, 9 barras verticais, emblema genérico e aletas."""
    o = []
    add = o.append
    w, h = 1.5, 0.62
    add(M.box("frame_top", (w + 0.2, 0.08, 0.1), (0, 0.04, h / 2 + 0.05), m["chrome"], bevel=0.02, seg=2))
    add(M.box("frame_bottom", (w + 0.2, 0.08, 0.1), (0, 0.04, -h / 2 - 0.05), m["chrome"], bevel=0.02, seg=2))
    for sx in (-1, 1):
        add(M.box(f"frame_side_{sx}", (0.1, 0.08, h + 0.2), (sx * (w / 2 + 0.05), 0.04, 0), m["chrome"], bevel=0.02, seg=2))
    for i in range(9):
        add(M.box(f"bar_{i}", (0.045, 0.06, h), (-w / 2 + 0.1 + i * (w - 0.2) / 8, 0.05, 0), m["chrome"], bevel=0.01, seg=1))
    add(M.box("backing", (w, 0.02, h), (0, 0.0, 0), m["plastic"], bevel=0.005, seg=1))
    add(M.box("emblem", (0.28, 0.05, 0.28), (0, 0.1, 0), m["paint_gold"], bevel=0.02, seg=2, rot=(0, 45, 0)))
    for sx in (-1, 1):
        add(M.plane_extrude(f"fin_{sx}", [(sx * (w / 2 + 0.1), -0.34), (sx * (w / 2 + 0.28), -0.1), (sx * (w / 2 + 0.28), 0.34), (sx * (w / 2 + 0.1), 0.34)][::(-1 if sx < 0 else 1)],
                            0.06, (0, 0.04, 0), m["chrome"], plane="XZ", bevel=0.015, seg=1))
    return o


def visor_sunshade(m):
    """Quebra-sol superior: aba larga curva, borda cromada, tira LED e suportes laterais."""
    o = []
    add = o.append
    # perfil lateral: aba que sobe para a frente
    prof = [(0.0, 0.0), (0.0, 0.1), (0.55, 0.2), (0.6, 0.14), (0.35, 0.02)]
    add(M.profile_extrude("visor", prof, 2.5, (0, 0, 0), m["paint_pink"], bevel=0.02, seg=2))
    add(M.box("edge", (2.54, 0.05, 0.08), (0, 0.58, 0.16), m["chrome"], bevel=0.02, seg=2))
    add(M.box("led", (2.3, 0.04, 0.03), (0, 0.4, 0.02), m["lamp_cyan"], bevel=0.008, seg=1))
    for sx in (-1, 1):
        add(M.box(f"bracket_{sx}", (0.1, 0.22, 0.14), (sx * 1.15, 0.12, -0.02), m["steel"], bevel=0.02, seg=1))
        add(M.box(f"tip_{sx}", (0.1, 0.12, 0.14), (sx * 1.27, 0.5, 0.1), m["chrome"], bevel=0.03))
    return o


def bumper_extension_lip(m):
    """Extensão decorativa de para-choque: lábio inferior (chin) com asas e luzes âmbar."""
    o = []
    add = o.append
    prof = [(0.0, 0.0), (0.0, 0.2), (0.55, 0.05), (0.55, -0.05), (0.15, -0.1), (0.0, -0.1)]
    add(M.profile_extrude("chin", prof, 2.2, (0, 0, -0.35), m["chrome"], bevel=0.03, seg=2))
    for sx in (-1, 1):
        wing = [(sx * 1.1, 0.0), (sx * 1.45, 0.3), (sx * 1.45, 0.55), (sx * 1.1, 0.45)]
        if sx < 0:
            wing = wing[::-1]
        add(M.plane_extrude(f"wing_{sx}", wing, 0.1, (0, 0, -0.35), m["chrome"], plane="XY", bevel=0.02, seg=2))
        add(M.cylinder(f"lamp_{sx}", 0.07, 0.06, (sx * 0.75, 0.58, -0.35), m["lamp_amber"], axis="Y", seg=14))
    add(M.box("splitter", (2.0, 0.1, 0.03), (0, 0.5, -0.42), m["plastic"], bevel=0.01, seg=1))
    return o


def aux_round_lamps_pair(m):
    """Par de faróis auxiliares redondos em hastes: aro cromado, lente emissiva e refletor."""
    o = []
    add = o.append
    for sx in (-1, 1):
        x = sx * 0.78
        add(M.cylinder(f"housing_{sx}", 0.24, 0.22, (x, 0.2, 0.0), m["chrome"], axis="Y", seg=28, bevel=0.03))
        add(M.torus(f"ring_{sx}", 0.225, 0.03, (x, 0.32, 0.0), m["chrome"], axis="Y"))
        add(M.cylinder(f"lens_{sx}", 0.205, 0.04, (x, 0.32, 0.0), m["lamp_white"], axis="Y", seg=28))
        add(M.cylinder(f"core_{sx}", 0.08, 0.06, (x, 0.34, 0.0), m["steel"], axis="Y", seg=16))
        add(M.box(f"stalk_{sx}", (0.08, 0.2, 0.34), (x, 0.0, -0.22), m["steel"], bevel=0.02, seg=1))
        add(M.box(f"visor_{sx}", (0.5, 0.18, 0.04), (x, 0.28, 0.28), m["chrome"], bevel=0.015, seg=1))
    add(M.box("cross_bar", (1.6, 0.06, 0.06), (0, 0.0, -0.36), m["steel"], bevel=0.015, seg=1))
    return o


def front_trim_set(m):
    """Conjunto de frisos frontais: 4 frisos cromados com tampas e linha neon."""
    o = []
    add = o.append
    for i, (w, z) in enumerate(((2.2, 0.3), (2.0, 0.1), (2.2, -0.1), (1.6, -0.3))):
        add(M.box(f"trim_{i}", (w, 0.05, 0.06), (0, 0.03, z), m["chrome"], bevel=0.015, seg=2))
        for sx in (-1, 1):
            add(M.cylinder(f"cap_{i}_{sx}", 0.04, 0.06, (sx * w / 2, 0.03, z), m["chrome"], axis="Y", seg=10))
    add(M.box("neon", (1.9, 0.03, 0.025), (0, 0.04, 0.0), m["lamp_pink"], bevel=0.006, seg=1))
    return o


def front_crest_ornament(m):
    """Ornamento frontal original: sol dourado com raios e asas cromadas em leque."""
    o = []
    add = o.append
    add(M.cylinder("sun", 0.22, 0.06, (0, 0.05, 0.0), m["paint_gold"], axis="Y", seg=28, bevel=0.01, bevel_seg=1))
    add(M.torus("sun_ring", 0.24, 0.025, (0, 0.06, 0.0), m["chrome"], axis="Y"))
    add(M.cylinder("sun_gem", 0.08, 0.07, (0, 0.09, 0.0), m["lamp_red"], axis="Y", seg=16))
    for k in range(9):
        a = math.radians(-80 + k * 20)
        ln = 0.36 if k % 2 == 0 else 0.26
        add(M.box(f"ray_{k}", (0.05, 0.04, ln), (math.sin(a) * (0.27 + ln / 2), 0.04, math.cos(a) * (0.27 + ln / 2)), m["paint_gold"], bevel=0.01, seg=1, rot=(0, math.degrees(a), 0)))
    for sx in (-1, 1):
        for k in range(5):
            ln = 0.5 - k * 0.07
            add(M.box(f"feather_{sx}_{k}", (ln, 0.035, 0.07), (sx * (0.3 + ln / 2), 0.03, -0.05 - k * 0.075), m["chrome"], bevel=0.012, seg=1, rot=(0, sx * 8, 0)))
    add(M.box("base", (0.5, 0.1, 0.08), (0, 0.0, -0.3), m["steel"], bevel=0.02, seg=1))
    return o


ACCESSORIES = [
    dict(id="fb_standard_chrome", name="Para-choque cromado padrão", category="front", mount="MOUNT_FRONT_BUMPER", mirror=False,
         build=fb_standard_chrome, materials={"main": CHROMES, "accent": ["lamp_amber", "lamp_white"]}),
    dict(id="fb_ornate_steps", name="Para-choque ornamentado em degraus", category="front", mount="MOUNT_FRONT_BUMPER", mirror=False,
         build=fb_ornate_steps, materials={"main": CHROMES, "accent": ["paint_gold", "paint_pink"]}),
    dict(id="grille_frame_chrome", name="Grade frontal com moldura metálica", category="front", mount="MOUNT_FRONT_GRILLE", mirror=False,
         build=grille_frame_chrome, materials={"main": CHROMES, "accent": ["paint_gold"]}),
    dict(id="visor_sunshade", name="Quebra-sol superior", category="front", mount="MOUNT_VISOR", mirror=False,
         build=visor_sunshade, materials={"main": ["paint_pink", "paint_blue", "paint_red", "paint_white"], "accent": ["chrome", "lamp_cyan"]}),
    dict(id="bumper_extension_lip", name="Extensão decorativa de para-choque", category="front", mount="MOUNT_FRONT_BUMPER", mirror=False,
         build=bumper_extension_lip, materials={"main": CHROMES, "accent": ["lamp_amber"]}),
    dict(id="aux_round_lamps_pair", name="Par de faróis auxiliares redondos", category="front", mount="MOUNT_FRONT_BUMPER", mirror=False,
         build=aux_round_lamps_pair, materials={"main": CHROMES, "accent": ["lamp_white", "lamp_amber"]}),
    dict(id="front_trim_set", name="Conjunto de frisos frontais", category="front", mount="MOUNT_FRONT_GRILLE", mirror=False,
         build=front_trim_set, materials={"main": CHROMES, "accent": ["lamp_pink", "lamp_cyan"]}),
    dict(id="front_crest_ornament", name="Ornamento frontal (sol e asas)", category="front", mount="MOUNT_FRONT_ORNAMENT", mirror=False,
         build=front_crest_ornament, materials={"main": ["paint_gold", "chrome"], "accent": ["lamp_red", "lamp_pink"]}),
]
