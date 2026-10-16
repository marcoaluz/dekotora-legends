"""Categoria C — Laterais e rodas (8 peças). Modeladas para o lado DIREITO (+X para fora); o lado
esquerdo é o mesmo modelo espelhado (scale.x = -1 no Godot). Origem = ponto de montagem lateral."""
import math

from lib import mesh3d as M

CHROMES = ["chrome", "steel", "paint_gold"]


def skirt_chrome_panel(m):
    """Saia lateral metálica: painel cromado com nervuras, aba inferior, tampas e refletores."""
    o = []
    add = o.append
    L = 4.2
    add(M.box("panel", (0.07, L, 0.5), (0.06, L / 2, -0.05), m["chrome"], bevel=0.025, seg=3))
    add(M.box("lip", (0.14, L, 0.07), (0.09, L / 2, -0.32), m["chrome"], bevel=0.02, seg=2))
    for i, z in enumerate((0.12, -0.05, -0.2)):
        add(M.box(f"rib_{i}", (0.03, L - 0.4, 0.03), (0.105, L / 2, z), m["steel"], bevel=0.008, seg=1))
    for y in (0.05, L - 0.05):
        add(M.cylinder(f"cap_{y}", 0.25, 0.09, (0.07, y, -0.05), m["chrome"], axis="Y", seg=20, bevel=0.015, bevel_seg=1))
    for i in range(5):
        y = 0.4 + i * (L - 0.8) / 4
        add(M.box(f"bracket_{i}", (0.18, 0.1, 0.34), (-0.05, y, 0.0), m["plastic"], bevel=0.02, seg=1))
        add(M.cylinder(f"rivet_{i}", 0.022, 0.04, (0.115, y, -0.25), m["steel"], axis="X", seg=8))
    add(M.box("reflector", (0.03, 0.22, 0.09), (0.095, L - 0.35, 0.2), m["lamp_amber"], bevel=0.008, seg=1))
    return o


def skirt_lit_neon(m):
    """Saia lateral com iluminação: painel escovado com tira neon embutida e luzes de posição."""
    o = []
    add = o.append
    L = 4.2
    add(M.box("panel", (0.07, L, 0.48), (0.06, L / 2, -0.06), m["steel"], bevel=0.025, seg=3))
    add(M.box("neon_main", (0.03, L - 0.5, 0.06), (0.1, L / 2, -0.06), m["lamp_pink"], bevel=0.01, seg=1))
    add(M.box("neon_low", (0.03, L - 0.9, 0.025), (0.1, L / 2, -0.24), m["lamp_cyan"], bevel=0.006, seg=1))
    add(M.box("frame_top", (0.1, L, 0.04), (0.08, L / 2, 0.19), m["chrome"], bevel=0.01, seg=2))
    add(M.box("frame_bot", (0.1, L, 0.04), (0.08, L / 2, -0.31), m["chrome"], bevel=0.01, seg=2))
    for i in range(4):
        y = 0.3 + i * (L - 0.6) / 3
        add(M.cylinder(f"pos_light_{i}", 0.04, 0.04, (0.11, y, 0.09), m["lamp_amber"], axis="X", seg=10))
        add(M.box(f"bracket_{i}", (0.18, 0.1, 0.34), (-0.05, y, 0.0), m["plastic"], bevel=0.02, seg=1))
    return o


def fender_extension(m):
    """Extensão de para-lama: arco largo sobre o conjunto traseiro, borda cromada e abas."""
    o = []
    add = o.append
    # arco elíptico (y = 1,5 R sen a; z = R cos a) feito de chapas curtas tangentes
    n = 11
    R = 0.6
    for i in range(n):
        a0 = math.radians(-78 + i * 156 / n)
        a1 = math.radians(-78 + (i + 1) * 156 / n)
        am = (a0 + a1) / 2
        y = 1.5 * R * math.sin(am)
        z = R * math.cos(am)
        tang = math.atan2(-math.sin(am), 1.5 * math.cos(am))
        seglen = math.hypot(1.5 * R * (math.sin(a1) - math.sin(a0)), R * (math.cos(a1) - math.cos(a0))) + 0.02
        add(M.box(f"arc_{i}", (0.34, seglen, 0.05), (0.2, y, z), m["paint_pink"], bevel=0.012, seg=1, rot=(math.degrees(tang), 0, 0)))
        add(M.box(f"trim_{i}", (0.045, seglen, 0.06), (0.38, y, z + 0.005), m["chrome"], bevel=0.012, seg=1, rot=(math.degrees(tang), 0, 0)))
    for sy in (-1, 1):
        add(M.box(f"flap_{sy}", (0.34, 0.08, 0.2), (0.2, sy * 0.93, 0.12), m["paint_pink"], bevel=0.015, seg=1))
    return o


def hubcap_decorative(m):
    """Calota decorativa: disco cromado com 10 raios em estrela, anel e tampa central. Eixo = X."""
    o = []
    add = o.append
    add(M.cylinder("disc", 0.34, 0.04, (0.02, 0, 0), m["chrome"], axis="X", seg=32, bevel=0.01, bevel_seg=1))
    add(M.torus("rim", 0.33, 0.03, (0.04, 0, 0), m["chrome"], axis="X"))
    for k in range(10):
        a = math.tau * k / 10
        add(M.box(f"spoke_{k}", (0.03, 0.05, 0.27), (0.05, math.sin(a) * 0.17, math.cos(a) * 0.17), m["steel"], bevel=0.008, seg=1, rot=(math.degrees(-a), 0, 0)))
    add(M.cylinder("cap", 0.1, 0.06, (0.07, 0, 0), m["paint_gold"], axis="X", seg=20, bevel=0.015, bevel_seg=1))
    add(M.cylinder("gem", 0.04, 0.07, (0.085, 0, 0), m["lamp_pink"], axis="X", seg=12))
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        add(M.cylinder(f"nut_{k}", 0.016, 0.04, (0.06, math.sin(a) * 0.24, math.cos(a) * 0.24), m["plastic"], axis="X", seg=6))
    return o


def step_metal(m):
    """Degrau metálico: chapa com relevo antiderrapante, suportes e frente cromada."""
    o = []
    add = o.append
    add(M.box("plate", (0.28, 0.75, 0.05), (0.14, 0.0, 0.0), m["steel"], bevel=0.012, seg=1))
    add(M.box("front_lip", (0.05, 0.75, 0.1), (0.29, 0.0, 0.02), m["chrome"], bevel=0.015, seg=2))
    for i in range(7):
        for j in range(3):
            add(M.box(f"tread_{i}_{j}", (0.04, 0.06, 0.012), (0.07 + j * 0.08, -0.3 + i * 0.1, 0.03), m["chrome"], bevel=0.003, seg=1, rot=(0, 0, 45)))
    for sy in (-1, 1):
        add(M.box(f"bracket_{sy}", (0.06, 0.06, 0.3), (0.0, sy * 0.3, 0.14), m["plastic"], bevel=0.01, seg=1))
        add(M.box(f"brace_{sy}", (0.04, 0.05, 0.3), (0.1, sy * 0.3, 0.1), m["plastic"], bevel=0.01, seg=1, rot=(0, 35, 0)))
    return o


def side_trim_set(m):
    """Conjunto de frisos laterais: 3 frisos cromados de comprimentos diferentes com rebites."""
    o = []
    add = o.append
    for i, (L, z) in enumerate(((5.2, 0.35), (4.4, 0.18), (3.4, 0.01))):
        add(M.box(f"trim_{i}", (0.035, L, 0.07), (0.03, L / 2, z), m["chrome"], bevel=0.015, seg=2))
        add(M.cylinder(f"cap_{i}", 0.04, 0.045, (0.03, 0.0, z), m["chrome"], axis="X", seg=10))
        add(M.cylinder(f"cap_b_{i}", 0.04, 0.045, (0.03, L, z), m["chrome"], axis="X", seg=10))
    for i in range(10):
        add(M.cylinder(f"rivet_{i}", 0.014, 0.03, (0.05, 0.4 + i * 0.4, -0.14), m["steel"], axis="X", seg=6))
    add(M.box("accent", (0.03, 3.8, 0.025), (0.035, 1.9, -0.06), m["lamp_pink"], bevel=0.005, seg=1))
    return o


def side_box_decor(m):
    """Caixa lateral decorativa: caixa chanfrada com tampa, fecho, quinas e relevo central."""
    o = []
    add = o.append
    add(M.box("box", (0.34, 1.3, 0.55), (0.17, 0, 0), m["chrome"], bevel=0.06, seg=3))
    add(M.box("lid_line", (0.01, 1.28, 0.02), (0.345, 0, 0.12), m["plastic"], bevel=0.003, seg=1))
    add(M.box("emboss", (0.02, 0.9, 0.22), (0.35, 0, -0.1), m["paint_blue"], bevel=0.01, seg=1))
    add(M.box("emboss_frame", (0.025, 0.96, 0.28), (0.345, 0, -0.1), m["steel"], bevel=0.01, seg=1))
    add(M.box("latch", (0.04, 0.12, 0.1), (0.36, 0, 0.12), m["steel"], bevel=0.015, seg=2))
    for sy in (-1, 1):
        for sz in (-1, 1):
            add(M.cylinder(f"bolt_{sy}_{sz}", 0.022, 0.03, (0.35, sy * 0.58, sz * 0.22), m["steel"], axis="X", seg=8))
    add(M.box("back_plate", (0.06, 1.4, 0.65), (0.03, 0, 0), m["plastic"], bevel=0.02, seg=1))
    return o


def side_ornament_wave(m):
    """Ornamento lateral original: ondas concêntricas douradas (inspirado em padrão de ondas)."""
    o = []
    add = o.append
    add(M.cylinder("plate", 0.5, 0.04, (0.02, 0, 0), m["paint_blue"], axis="X", seg=40, bevel=0.01, bevel_seg=1))
    add(M.torus("rim", 0.5, 0.03, (0.04, 0, 0), m["chrome"], axis="X", seg=40))
    for k, r in enumerate((0.38, 0.26, 0.14)):
        add(M.torus(f"wave_{k}", r, 0.02, (0.05 + k * 0.004, 0, -0.04 * k), m["paint_gold"], axis="X", seg=32, tube_seg=6))
    for k, r in enumerate((0.2, 0.1)):
        add(M.torus(f"wave_b_{k}", r, 0.018, (0.055, 0, -0.26 + k * 0.0), m["chrome"], axis="X", seg=28, tube_seg=6))
    add(M.cylinder("pearl", 0.05, 0.05, (0.07, 0, 0.02), m["lamp_pink"], axis="X", seg=14))
    return o


ACCESSORIES = [
    dict(id="skirt_chrome_panel", name="Saia lateral metálica", category="sides", mount="MOUNT_SIDE_R", mirror=True,
         build=skirt_chrome_panel, materials={"main": CHROMES, "accent": ["lamp_amber"]}),
    dict(id="skirt_lit_neon", name="Saia lateral com iluminação", category="sides", mount="MOUNT_SIDE_R", mirror=True,
         build=skirt_lit_neon, materials={"main": ["steel", "chrome", "paint_blue"], "accent": ["lamp_pink", "lamp_cyan", "lamp_yellow"]}),
    dict(id="fender_extension", name="Extensão de para-lama", category="sides", mount="MOUNT_FENDER_R", mirror=True,
         build=fender_extension, materials={"main": ["paint_pink", "paint_blue", "paint_red", "paint_white"], "accent": CHROMES}),
    dict(id="hubcap_decorative", name="Calota decorativa", category="sides", mount="MOUNT_WHEEL_FRONT_FACE_R", mirror=True,
         build=hubcap_decorative, materials={"main": CHROMES, "accent": ["paint_gold", "lamp_pink", "lamp_cyan"]}),
    dict(id="step_metal", name="Degrau metálico", category="sides", mount="MOUNT_STEP_R", mirror=True,
         build=step_metal, materials={"main": ["steel", "chrome"], "accent": ["chrome"]}),
    dict(id="side_trim_set", name="Conjunto de frisos laterais", category="sides", mount="MOUNT_SIDE_TRIM_R", mirror=True,
         build=side_trim_set, materials={"main": CHROMES, "accent": ["lamp_pink", "lamp_cyan"]}),
    dict(id="side_box_decor", name="Caixa lateral decorativa", category="sides", mount="MOUNT_SIDE_BOX_R", mirror=True,
         build=side_box_decor, materials={"main": CHROMES, "accent": ["paint_blue", "paint_pink", "paint_red"]}),
    dict(id="side_ornament_wave", name="Ornamento lateral (ondas)", category="sides", mount="MOUNT_SIDE_ORNAMENT_R", mirror=True,
         build=side_ornament_wave, materials={"main": ["paint_blue", "paint_red", "paint_pink"], "accent": ["paint_gold", "chrome"]}),
]
