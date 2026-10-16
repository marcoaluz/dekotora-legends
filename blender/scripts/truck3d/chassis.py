"""Chassi, eixos, tanques, escapamentos e para-lamas."""
from lib import mesh3d as M
from lib import mesh_adv as A

from .dims import FRONT_AXLE_Y, REAR_AXLES_Y


def build_chassis(m, add):
    # longarinas em C (alma + abas) e travessas
    for sx in (-1, 1):
        add(M.box(f"rail_web_{sx}", (0.05, 10.8, 0.28), (sx * 0.5, 5.9, 0.68), m["plastic"], bevel=0.01, seg=1))
        for z in (0.55, 0.81):
            add(M.box(f"rail_flange_{sx}_{z}", (0.16, 10.8, 0.035), (sx * 0.55, 5.9, z), m["plastic"], bevel=0.008, seg=1))
    for y in (1.2, 2.3, 3.8, 5.0, 6.2, 7.4, 8.6, 9.5, 11.0):
        add(M.box(f"cross_{y}", (1.0, 0.1, 0.2), (0, y, 0.68), m["plastic"], bevel=0.02, seg=1))
    add(M.box("subframe", (2.1, 8.0, 0.26), (0, 4.15, 0.97), m["plastic"], bevel=0.03))
    # tanques (formato D) + cintas
    for sx, (y, ln) in ((-1, (6.5, 2.0)), (1, (5.9, 1.5))):
        add(M.box(f"tank_{sx}", (0.74, ln, 0.58), (sx * 1.0, y, 0.53), m["steel"], bevel=0.14, seg=4))
        for dy in (-ln * 0.3, ln * 0.3):
            add(M.box(f"tank_strap_{sx}_{dy:.2f}", (0.78, 0.05, 0.62), (sx * 1.0, y + dy, 0.53), m["chrome"], bevel=0.01, seg=1))
        add(M.cylinder(f"tank_cap_{sx}", 0.06, 0.06, (sx * 1.39, y - ln * 0.25, 0.6), m["chrome"], axis="X", seg=14))
    add(M.cylinder("adblue", 0.19, 0.7, (1.0, 7.2, 0.5), m["plastic"], axis="Y", seg=18, bevel=0.03))
    add(M.cylinder("adblue_cap", 0.05, 0.05, (1.0, 7.1, 0.7), m["paint_blue"], axis="Z", seg=12))
    add(M.box("battery_box", (0.5, 0.62, 0.4), (-1.0, 8.0, 0.55), m["plastic"], bevel=0.04))
    add(M.box("battery_lid", (0.46, 0.58, 0.04), (-1.0, 8.0, 0.76), m["steel"], bevel=0.01, seg=1))
    for i, y in enumerate((7.0, 7.45)):
        add(M.cylinder(f"air_tank_{i}", 0.13, 0.7, (0.0, y, 0.5), m["steel"], axis="X", seg=16, bevel=0.02))
    # eixos traseiros: tubo, diferencial, molas a ar, amortecedores
    for y in REAR_AXLES_Y:
        add(M.cylinder(f"axle_r_{y}", 0.07, 2.0, (0, y, 0.52), m["steel"], axis="X", seg=14))
        add(M.sphere(f"diff_{y}", 0.2, (0, y, 0.52), m["steel"], seg=16, rings=10, scale=(1.3, 1.0, 1.0)))
        for sx in (-1, 1):
            add(M.cylinder(f"airspring_{y}_{sx}", 0.13, 0.3, (sx * 0.55, y, 0.88), m["plastic"], axis="Z", seg=12, bevel=0.02))
            add(M.tube(f"shock_{y}_{sx}", [(sx * 0.78, y + 0.18, 0.5), (sx * 0.8, y + 0.22, 0.98)], 0.03, m["steel"], seg=8))
    add(M.tube("driveshaft", [(0, 3.0, 0.5), (0, 5.4, 0.55), (0, 8.2, 0.6)], 0.045, m["steel"], seg=10))
    # eixo dianteiro: viga, molas, pino mestre, barra de direção
    add(M.cylinder("axle_f", 0.07, 2.0, (0, FRONT_AXLE_Y, 0.5), m["steel"], axis="X", seg=14))
    for sx in (-1, 1):
        for k, h in enumerate((0.66, 0.7, 0.74)):
            add(M.box(f"leaf_{sx}_{k}", (0.09, 1.3 - k * 0.2, 0.025), (sx * 0.55, FRONT_AXLE_Y, h), m["steel"], bevel=0.005, seg=1))
        add(M.cylinder(f"kingpin_{sx}", 0.05, 0.28, (sx * 0.86, FRONT_AXLE_Y, 0.5), m["steel"], axis="Z", seg=10))
    add(M.tube("drag_link", [(-0.86, FRONT_AXLE_Y - 0.25, 0.42), (0.86, FRONT_AXLE_Y - 0.25, 0.42)], 0.02, m["steel"], seg=8))
    # arcos dos para-lamas traseiros e escapamentos verticais atrás da cabine
    for y in REAR_AXLES_Y:
        for sx in (-1, 1):
            x0, x1 = (0.52, 1.28) if sx > 0 else (-1.28, -0.52)
            add(A.arch_shell(f"fender_arch_{sx}_{y}", (y, 0.52), 0.56, 0.62, x0, x1, m["plastic"], seg=20))
    for sx in (-1, 1):
        add(M.cylinder(f"stack_{sx}", 0.1, 2.9, (sx * 1.3, 8.3, 2.05), m["chrome"], axis="Z", seg=18, bevel=0.01))
        add(M.cylinder(f"stack_cap_{sx}", 0.12, 0.1, (sx * 1.3, 8.3, 3.5), m["chrome"], axis="Z", seg=18))
        add(M.cylinder(f"stack_base_{sx}", 0.13, 0.12, (sx * 1.3, 8.3, 0.7), m["steel"], axis="Z", seg=14))
        for z in (1.2, 1.9, 2.6, 3.2):
            add(M.cylinder(f"stack_band_{sx}_{z}", 0.118, 0.07, (sx * 1.3, 8.3, z), m["steel"], axis="Z", seg=18))
        add(M.box(f"stack_brace_{sx}", (0.18, 0.1, 0.06), (sx * 1.22, 8.3, 2.9), m["steel"], bevel=0.01, seg=1))
        add(M.tube(f"side_rail_{sx}", [(sx * 1.23, 4.1, 0.7), (sx * 1.23, 8.0, 0.7)], 0.025, m["steel"], seg=8))
    add(M.box("cab_back_gap", (2.0, 0.3, 0.4), (0, 8.3, 0.9), m["plastic"], bevel=0.03))
