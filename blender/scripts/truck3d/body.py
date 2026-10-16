"""Carrocerias sobre o mesmo chassi e a mesma cabine (pontos de montagem iguais):
`box` = baú de tábuas, `flat` = carroceria aberta de tábuas com carga, `tank` = tanque cilíndrico."""
import math

from lib import mesh3d as M
from lib import mesh_adv as A

from .dims import BODY_L, BODY_TOP, BODY_W, BODY_Z0

KINDS = ("box", "flat", "tank")
W2 = BODY_W / 2


def build_body(m, add, kind="box"):
    {"box": _box, "flat": _flat, "tank": _tank}[kind](m, add)


def _rear_common(m, add):
    """Lanternas em 3 lentes, faixa refletiva, placa, para-choque de segurança, abas de lama e neon sob o chassi."""
    for sx in (-1, 1):
        add(M.box(f"tail_house_{sx}", (0.4, 0.07, 0.68), (sx * 1.0, -0.035, 1.55), m["chrome"], bevel=0.035, seg=1))
        for k, (mat, dz) in enumerate((("lamp_amber", 0.22), ("lamp_red", 0.0), ("lamp_white", -0.22))):
            add(M.box(f"tail_{sx}_{k}", (0.32, 0.06, 0.18), (sx * 1.0, -0.06, 1.55 + dz), m[mat], bevel=0.03))
    for i in range(10):                               # faixa refletiva vermelho/branco
        x = -1.1 + i * 0.245
        add(M.box(f"refl_{i}", (0.235, 0.03, 0.14), (x, -0.025, 1.12), m["paint_red"] if i % 2 == 0 else m["paint_white"], bevel=0.008, seg=1))
    add(M.box("plate", (0.5, 0.03, 0.22), (0, -0.04, 1.0), m["paint_white"], bevel=0.01, seg=1))
    add(M.box("underrun", (2.2, 0.12, 0.14), (0, -0.12, 0.42), m["plastic"], bevel=0.03))
    for sx in (-1, 1):
        add(M.box(f"underrun_refl_{sx}", (0.3, 0.02, 0.06), (sx * 0.95, -0.19, 0.42), m["lamp_red"], bevel=0.01, seg=1))
        add(M.box(f"mudflap_{sx}", (0.5, 0.04, 0.5), (sx * 0.95, 0.45, 0.8), m["rubber"], bevel=0.01, seg=1))
        add(M.box(f"underglow_{sx}", (0.05, 10.0, 0.05), (sx * 0.98, 6.0, 0.36), m["lamp_cyan"], bevel=0.01, seg=1))
        for y in (0.7, 2.4, 4.1, 5.8, 7.5):           # luzes laterais de posição
            add(M.box(f"side_marker_{sx}_{y}", (0.04, 0.16, 0.07), (sx * (W2 + 0.025), y, 1.18), m["lamp_amber"], bevel=0.015, seg=1))


def _deck(m, add):
    """Plataforma sob a carga (chassi de carga): usada por carroceria aberta e tanque."""
    add(M.box("deck", (BODY_W, BODY_L, 0.2), (0, BODY_L / 2, BODY_Z0 + 0.1), m["plastic"], bevel=0.03, seg=2))
    add(M.box("deck_plate", (BODY_W - 0.1, BODY_L - 0.1, 0.03), (0, BODY_L / 2, BODY_Z0 + 0.215), m["diamond"], bevel=0.008, seg=1))
    add(M.box("rear_beam", (BODY_W, 0.2, 0.9), (0, 0.0, 1.55), m["plastic"], bevel=0.04, seg=2))   # base das lanternas
    for sx in (-1, 1):
        add(M.box(f"deck_edge_{sx}", (0.05, BODY_L, 0.08), (sx * (W2 + 0.01), BODY_L / 2, BODY_Z0 + 0.15), m["chrome"], bevel=0.015, seg=1))


def _box(m, add):
    add(M.box("body", (BODY_W, BODY_L, BODY_TOP - BODY_Z0), (0, BODY_L / 2, (BODY_Z0 + BODY_TOP) / 2), m["paint_white"], bevel=0.08, seg=3))
    # tábuas horizontais (frestas finas) + montantes verticais com trava, como no baú de madeira da referência
    for sx in (-1, 1):
        for k in range(11):
            z = 1.25 + k * 0.18
            add(M.box(f"plank_seam_{sx}_{k}", (0.012, BODY_L - 0.2, 0.014), (sx * (W2 + 0.004), BODY_L / 2, z), m["plastic"], bevel=0.003, seg=1))
        for i, y in enumerate((0.35, 2.75, 5.45, 7.85)):
            add(M.box(f"post_{sx}_{i}", (0.07, 0.1, 2.0), (sx * (W2 + 0.03), y, 2.15), m["steel"], bevel=0.015, seg=1))
            add(M.box(f"post_latch_{sx}_{i}", (0.05, 0.07, 0.16), (sx * (W2 + 0.06), y, 1.35), m["chrome"], bevel=0.015, seg=1))
    for i in (0, 1, 2):                               # nervuras da frente do baú
        add(M.box(f"front_rib_{i}", (0.1, 0.05, 1.9), (-0.8 + i * 0.8, BODY_L + 0.015, 2.15), m["steel"], bevel=0.012, seg=1))
    for z in (1.3, 3.05):
        add(M.box(f"rail_h_{z}", (BODY_W + 0.05, BODY_L - 0.1, 0.06), (0, BODY_L / 2, z), m["chrome"], bevel=0.015, seg=1))
    add(M.box("stripe_body", (BODY_W + 0.05, BODY_L + 0.04, 0.22), (0, BODY_L / 2, 1.85), m["paint_pink"], bevel=0.02, seg=1))
    add(M.box("trim_top", (BODY_W + 0.06, BODY_L + 0.02, 0.08), (0, BODY_L / 2, BODY_TOP - 0.02), m["chrome"], bevel=0.02, seg=1))
    add(M.box("roof_panel", (BODY_W - 0.2, BODY_L - 0.2, 0.03), (0, BODY_L / 2, BODY_TOP + 0.005), m["steel"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        add(M.box(f"corner_post_{sx}", (0.1, 0.09, 2.1), (sx * (W2 - 0.01), -0.04, 2.15), m["chrome"], bevel=0.02, seg=1))
    add(M.box("door_seam", (0.04, 0.05, 2.0), (0, -0.03, 2.15), m["plastic"], bevel=0.01, seg=1))   # porta traseira
    for sx in (-1, 1):
        for z in (1.5, 2.3, 3.0):
            add(M.cylinder(f"hinge_{sx}_{z}", 0.05, 0.22, (sx * (W2 + 0.02), -0.05, z), m["steel"], axis="Z", seg=10))
        add(M.cylinder(f"lockbar_{sx}", 0.025, 1.9, (sx * 0.45, -0.07, 2.12), m["chrome"], axis="Z", seg=10))
        add(M.box(f"lockhandle_{sx}", (0.08, 0.06, 0.18), (sx * 0.45, -0.1, 2.0), m["chrome"], bevel=0.015, seg=1))
    for x in (0.8, 1.12):                             # escada
        add(M.box(f"ladder_rail_{x}", (0.05, 0.06, 2.0), (x, -0.12, 2.15), m["chrome"], bevel=0.01, seg=1))
    for i in range(6):
        add(M.box(f"ladder_rung_{i}", (0.37, 0.05, 0.045), (0.96, -0.14, 1.3 + i * 0.33), m["chrome"], bevel=0.01, seg=1))
    _rear_common(m, add)


def _flat(m, add):
    """Carroceria aberta: laterais de tábuas até 2,3 m, cabeceira alta atrás da cabine, gaiola no topo, carga de tambores."""
    _deck(m, add)
    z_top = BODY_TOP
    for sx in (-1, 1):
        for k in range(6):                            # 6 tábuas por lado (a 3ª pintada de rosa)
            mat = m["paint_pink"] if k == 2 else m["paint_white"]
            add(M.box(f"board_{sx}_{k}", (0.05, BODY_L, 0.17), (sx * (W2 - 0.025), BODY_L / 2, 1.42 + k * 0.19), mat, bevel=0.015, seg=1))
        for i, y in enumerate((0.1, 2.1, 4.1, 6.1, 8.1)):   # estacas até o topo
            add(M.box(f"stake_{sx}_{i}", (0.08, 0.1, z_top - BODY_Z0 - 0.2), (sx * W2, y, (z_top + BODY_Z0 + 0.2) / 2), m["steel"], bevel=0.015, seg=1))
        add(M.tube(f"top_rail_{sx}", [(sx * W2, 0.1, z_top), (sx * W2, 8.1, z_top)], 0.035, m["chrome"], seg=8))
        add(M.box(f"corner_post_{sx}", (0.1, 0.09, 2.1), (sx * (W2 - 0.01), -0.04, 2.15), m["chrome"], bevel=0.02, seg=1))
    for y in (0.1, 2.1, 4.1, 6.1, 8.1):
        add(M.tube(f"top_cross_{y}", [(-W2, y, z_top), (W2, y, z_top)], 0.03, m["chrome"], seg=8))
    add(M.box("headboard", (BODY_W - 0.1, 0.08, 1.9), (0, BODY_L - 0.04, 2.15), m["paint_white"], bevel=0.03, seg=2))
    for i in range(5):
        add(M.box(f"headboard_slat_{i}", (BODY_W - 0.05, 0.03, 0.05), (0, BODY_L + 0.01, 1.5 + i * 0.35), m["steel"], bevel=0.008, seg=1))
    add(M.box("tailgate", (BODY_W - 0.1, 0.06, 0.55), (0, 0.03, 1.65), m["paint_white"], bevel=0.02, seg=2))
    n = 0                                             # carga: tambores coloridos
    for row, mat in enumerate(("paint_blue", "paint_red", "paint_blue", "paint_red")):
        for sx in (-0.55, 0.55):
            y = 1.3 + row * 1.7
            add(M.cylinder(f"barrel_{n}", 0.42, 1.0, (sx, y, BODY_Z0 + 0.73), m[mat], axis="Z", seg=18, bevel=0.03))
            for dz in (-0.3, 0.3):
                add(M.cylinder(f"barrel_ring_{n}_{dz}", 0.435, 0.05, (sx, y, BODY_Z0 + 0.73 + dz), m["steel"], axis="Z", seg=18))
            n += 1
    _rear_common(m, add)


def _tank(m, add):
    """Tanque cilíndrico (seção elíptica, largura = baú) com fundos abaulados, bocas de visita, anéis e escada."""
    _deck(m, add)
    L, cap, R = 8.0, 0.4, 1.05
    prof = [(0.0, 0.0)]
    for k in range(1, 7):
        t = math.radians(15 * k)
        prof.append((R * math.sin(t), cap * (1 - math.cos(t))))
    for k in range(5, 0, -1):
        t = math.radians(15 * k)
        prof.append((R * math.sin(t), L - cap * (1 - math.cos(t))))
    prof.append((0.0, L))
    zc = BODY_Z0 + 0.2 + R
    tank = A.lathe("tank_shell", prof, (0, 0.15, zc), m["paint_white"], axis="Y", seg=40)
    tank.scale = (W2 / R, 1.0, 1.0)
    M.apply_transforms([tank])
    add(tank)
    for y in (1.2, 2.9, 4.6, 6.3, 7.4):               # anéis de reforço
        ring = A.lathe(f"tank_band_{y}", [(R + 0.015, -0.04), (R + 0.04, -0.03), (R + 0.04, 0.03), (R + 0.015, 0.04)],
                       (0, y, zc), m["chrome"], axis="Y", seg=40)
        ring.scale = (W2 / R, 1.0, 1.0)
        M.apply_transforms([ring])
        add(ring)
    for sx in (-1, 1):
        add(M.box(f"tank_stripe_{sx}", (0.03, 7.0, 0.3), (sx * (W2 + 0.005), 4.15, zc), m["paint_pink"], bevel=0.01, seg=1))
        for y in (1.0, 4.1, 7.2):                     # berços do tanque
            add(M.box(f"cradle_{sx}_{y}", (0.08, 0.14, 0.45), (sx * (W2 - 0.1), y, BODY_Z0 + 0.35), m["steel"], bevel=0.02, seg=1))
    for i, y in enumerate((1.4, 3.4, 5.4)):           # bocas de visita
        add(M.cylinder(f"manhole_{i}", 0.26, 0.1, (0, y, zc + R + 0.02), m["chrome"], axis="Z", seg=20, bevel=0.015))
        add(M.cylinder(f"manhole_lid_{i}", 0.2, 0.06, (0, y, zc + R + 0.09), m["steel"], axis="Z", seg=20))
    for x in (-0.35, 0.35):
        add(M.tube(f"walkway_rail_{x}", [(x, 0.8, zc + R + 0.1), (x, 6.4, zc + R + 0.1)], 0.02, m["chrome"], seg=8))
    for x in (0.8, 1.12):                             # escada traseira
        add(M.box(f"ladder_rail_{x}", (0.05, 0.06, 2.0), (x, -0.12, 2.15), m["chrome"], bevel=0.01, seg=1))
    for i in range(6):
        add(M.box(f"ladder_rung_{i}", (0.37, 0.05, 0.045), (0.96, -0.14, 1.3 + i * 0.33), m["chrome"], bevel=0.01, seg=1))
    add(M.cylinder("outlet_valve", 0.07, 0.3, (0, 0.05, 1.3), m["steel"], axis="Y", seg=14))
    add(M.cylinder("outlet_cap", 0.1, 0.06, (0, -0.12, 1.3), m["chrome"], axis="Y", seg=14))
    _rear_common(m, add)
