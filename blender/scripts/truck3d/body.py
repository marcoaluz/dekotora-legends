"""Baú de carga + traseira: nervuras, quinas, portas, lanternas, escada, para-choque de segurança."""
from lib import mesh3d as M

from .dims import BODY_L, BODY_TOP, BODY_W, BODY_Z0


def build_body(m, add):
    W2 = BODY_W / 2
    add(M.box("body", (BODY_W, BODY_L, BODY_TOP - BODY_Z0), (0, BODY_L / 2, (BODY_Z0 + BODY_TOP) / 2), m["paint_white"], bevel=0.08, seg=3))
    for i in range(19):                               # nervuras verticais (chapa corrugada)
        y = 0.55 + i * 0.41
        add(M.box(f"rib_{i}", (BODY_W + 0.035, 0.045, 1.75), (0, y, 2.2), m["steel"], bevel=0.012, seg=1))
    for z in (1.3, 3.05):
        add(M.box(f"rail_h_{z}", (BODY_W + 0.05, BODY_L - 0.1, 0.06), (0, BODY_L / 2, z), m["chrome"], bevel=0.015, seg=1))
    add(M.box("stripe_body", (BODY_W + 0.05, BODY_L + 0.04, 0.22), (0, BODY_L / 2, 1.85), m["paint_pink"], bevel=0.02, seg=1))
    add(M.box("trim_top", (BODY_W + 0.06, BODY_L + 0.02, 0.08), (0, BODY_L / 2, BODY_TOP - 0.02), m["chrome"], bevel=0.02, seg=1))
    add(M.box("roof_panel", (BODY_W - 0.2, BODY_L - 0.2, 0.03), (0, BODY_L / 2, BODY_TOP + 0.005), m["steel"], bevel=0.01, seg=1))
    for sx in (-1, 1):                                # luzes laterais de posição e quinas traseiras
        for y in (0.7, 2.4, 4.1, 5.8, 7.5):
            add(M.box(f"side_marker_{sx}_{y}", (0.04, 0.16, 0.07), (sx * (W2 + 0.025), y, 1.18), m["lamp_amber"], bevel=0.015, seg=1))
        add(M.box(f"corner_post_{sx}", (0.1, 0.09, 2.1), (sx * (W2 - 0.01), -0.04, 2.15), m["chrome"], bevel=0.02, seg=1))
    # porta traseira
    add(M.box("door_seam", (0.04, 0.05, 2.0), (0, -0.03, 2.15), m["plastic"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        for z in (1.5, 2.3, 3.0):
            add(M.cylinder(f"hinge_{sx}_{z}", 0.05, 0.22, (sx * (W2 + 0.02), -0.05, z), m["steel"], axis="Z", seg=10))
        add(M.cylinder(f"lockbar_{sx}", 0.025, 1.9, (sx * 0.45, -0.07, 2.12), m["chrome"], axis="Z", seg=10))
        add(M.box(f"lockhandle_{sx}", (0.08, 0.06, 0.18), (sx * 0.45, -0.1, 2.0), m["chrome"], bevel=0.015, seg=1))
        # lanternas traseiras em 3 lentes
        add(M.box(f"tail_house_{sx}", (0.4, 0.07, 0.68), (sx * 1.0, -0.035, 1.55), m["chrome"], bevel=0.035, seg=1))
        for k, (mat, dz) in enumerate((("lamp_amber", 0.22), ("lamp_red", 0.0), ("lamp_white", -0.22))):
            add(M.box(f"tail_{sx}_{k}", (0.32, 0.06, 0.18), (sx * 1.0, -0.06, 1.55 + dz), m[mat], bevel=0.03))
    for i in range(10):                               # faixa refletiva vermelho/branco
        x = -1.1 + i * 0.245
        add(M.box(f"refl_{i}", (0.235, 0.03, 0.14), (x, -0.025, 1.12), m["paint_red"] if i % 2 == 0 else m["paint_white"], bevel=0.008, seg=1))
    add(M.box("plate", (0.5, 0.03, 0.22), (0, -0.04, 1.0), m["paint_white"], bevel=0.01, seg=1))
    for x in (0.8, 1.12):                             # escada
        add(M.box(f"ladder_rail_{x}", (0.05, 0.06, 2.0), (x, -0.12, 2.15), m["chrome"], bevel=0.01, seg=1))
    for i in range(6):
        add(M.box(f"ladder_rung_{i}", (0.37, 0.05, 0.045), (0.96, -0.14, 1.3 + i * 0.33), m["chrome"], bevel=0.01, seg=1))
    # para-choque de segurança, abas de lama e luz de neon sob o chassi
    add(M.box("underrun", (2.2, 0.12, 0.14), (0, -0.12, 0.42), m["plastic"], bevel=0.03))
    for sx in (-1, 1):
        add(M.box(f"underrun_refl_{sx}", (0.3, 0.02, 0.06), (sx * 0.95, -0.19, 0.42), m["lamp_red"], bevel=0.01, seg=1))
        add(M.box(f"mudflap_{sx}", (0.5, 0.04, 0.5), (sx * 0.95, 0.45, 0.8), m["rubber"], bevel=0.01, seg=1))
        add(M.box(f"underglow_{sx}", (0.05, 10.0, 0.05), (sx * 0.98, 6.0, 0.36), m["lamp_cyan"], bevel=0.01, seg=1))
