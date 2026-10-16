"""Cabine do caminhão (inspirada em cabine cab-over europeia): casca arredondada por loft + detalhes.

`build_cab(m, add)` cria tudo e entrega cada objeto para `add(obj)`.
"""
import math

from lib import mesh3d as M
from lib import mesh_adv as A

from .dims import (CAB_W, CAB_Y0, CAB_Y1, CAB_Z0, CAB_TOP, FRONT_AXLE_Y, ROOF_INSET, ROOF_R, SLOPE_DEG,
                   cab_hw, cab_yf)


def _levels():
    lv = [(CAB_Z0, 0.07), (CAB_Z0 + 0.04, 0.025), (1.0, 0.0)]
    lv += [(z, 0.0) for z in (1.4, 1.9, 2.1, 2.4, 2.7, 3.0, 3.2)]
    for k in range(1, 6):
        th = math.radians(18 * k)
        lv.append((3.2 + ROOF_R * math.sin(th), ROOF_INSET * (1 - math.cos(th))))
    return lv


def _shell(m):
    rings = []
    for z, inset in _levels():
        zc = min(z, 3.2)
        rf = 0.22 + 0.18 * max(0.0, min(1.0, (zc - 2.1) / 1.1))
        rings.append(A.rounded_rect_ring(cab_hw(zc) - inset, CAB_Y0 + inset, cab_yf(zc) - inset, z,
                                         max(rf - inset, 0.06), max(0.12 - inset, 0.04), n=6))
    return A.loft("cab", rings, m["paint_white"])


def _headlight(add, m, sx):
    x, y, z = sx * 0.9, CAB_Y1 + 0.012, 1.32
    add(M.box(f"hl_house_{sx}", (0.46, 0.1, 0.36), (x, y, z), m["plastic"], bevel=0.05))
    add(M.box(f"hl_rim_{sx}", (0.5, 0.03, 0.4), (x, y + 0.035, z), m["chrome"], bevel=0.05, seg=1))
    add(M.box(f"hl_lens_{sx}", (0.4, 0.05, 0.3), (x, y + 0.05, z), m["glass"], bevel=0.04))
    add(M.cylinder(f"hl_proj_ring_{sx}", 0.095, 0.03, (x + sx * 0.04, y + 0.075, z + 0.02), m["chrome"], axis="Y", seg=20))
    add(M.cylinder(f"hl_proj_{sx}", 0.075, 0.03, (x + sx * 0.04, y + 0.085, z + 0.02), m["lamp_white"], axis="Y", seg=20))
    for k, s2 in enumerate((-1, 1)):           # luz diurna em V (apontando para baixo, ao centro)
        add(M.box(f"hl_drl_{sx}_{k}", (0.15, 0.02, 0.022), (x + s2 * 0.075, y + 0.08, z - 0.12),
                  m["lamp_white"], bevel=0.008, seg=1, rot=(0, -s2 * 25, 0)))
    add(M.box(f"hl_blinker_{sx}", (0.22, 0.045, 0.06), (x, y + 0.045, z - 0.2), m["lamp_amber"], bevel=0.02, seg=1))


def _grille(add, m):
    y = CAB_Y1
    add(M.box("grille_frame", (1.3, 0.07, 0.64), (0, y + 0.02, 1.22), m["chrome"], bevel=0.04))
    add(M.box("grille", (1.18, 0.08, 0.52), (0, y + 0.025, 1.22), m["plastic"], bevel=0.03))
    for i in range(7):
        add(M.box(f"grille_bar_{i}", (1.16, 0.045, 0.022), (0, y + 0.06, 0.99 + i * 0.075), m["chrome"], bevel=0.008, seg=1))
    for i in range(-3, 4):
        add(M.box(f"grille_div_{i}", (0.018, 0.04, 0.5), (i * 0.17, y + 0.056, 1.22), m["steel"], bevel=0.005, seg=1))
    add(M.cylinder("badge_ring", 0.115, 0.04, (0, y + 0.075, 1.22), m["chrome"], axis="Y", seg=28))
    add(M.cylinder("badge_core", 0.085, 0.04, (0, y + 0.082, 1.22), m["paint_blue"], axis="Y", seg=28))


def _bumper(add, m):
    y = CAB_Y1
    add(M.box("bumper", (2.36, 0.3, 0.3), (0, y + 0.085, 0.74), m["paint_white"], bevel=0.09, seg=3))
    add(M.box("bumper_valance", (2.22, 0.24, 0.16), (0, y + 0.06, 0.5), m["plastic"], bevel=0.05))
    add(M.box("bumper_step", (0.9, 0.12, 0.05), (0, y + 0.2, 0.56), m["steel"], bevel=0.01, seg=1))
    add(M.box("plate_front", (0.52, 0.02, 0.13), (0, y + 0.24, 0.76), m["paint_white"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        add(M.cylinder(f"fog_ring_{sx}", 0.085, 0.03, (sx * 0.78, y + 0.235, 0.74), m["chrome"], axis="Y", seg=20))
        add(M.cylinder(f"fog_{sx}", 0.065, 0.03, (sx * 0.78, y + 0.245, 0.74), m["lamp_white"], axis="Y", seg=20))
        add(M.box(f"bumper_vent_{sx}", (0.5, 0.02, 0.07), (sx * 0.45, y + 0.235, 0.7), m["plastic"], bevel=0.01, seg=1))
        add(M.box(f"bumper_corner_{sx}", (0.1, 0.3, 0.34), (sx * 1.2, y + 0.04, 0.72), m["paint_white"], bevel=0.04))


def _wipers_mirrors_doors(add, m, sx):
    xs = lambda z: sx * cab_hw(z)
    # limpadores
    ywp = cab_yf(2.3) + 0.03
    add(M.box(f"wiper_{sx}", (0.78, 0.015, 0.03), (sx * 0.45, ywp, 2.28), m["plastic"], bevel=0.005, seg=1, rot=(SLOPE_DEG, 0, 0)))
    # porta: frestas
    for i, (y0, y1, z0, z1) in enumerate(((10.95, 10.95, 1.05, 3.1), (9.2, 9.2, 1.05, 3.1))):
        add(M.box(f"seam_v_{sx}_{i}", (0.02, 0.02, z1 - z0), (xs(2.0) + sx * 0.005, y0, (z0 + z1) / 2), m["plastic"], bevel=0.004, seg=1))
    add(M.box(f"seam_h_{sx}", (0.02, 1.75, 0.02), (xs(1.05) + sx * 0.005, 10.07, 1.05), m["plastic"], bevel=0.004, seg=1))
    add(M.box(f"seam_h2_{sx}", (0.02, 1.75, 0.02), (xs(3.08) - sx * 0.005, 10.07, 3.08), m["plastic"], bevel=0.004, seg=1))
    # janela
    add(M.box(f"win_frame_{sx}", (0.04, 1.42, 0.9), (xs(2.55) - sx * 0.01, 10.1, 2.58), m["plastic"], bevel=0.03))
    add(M.box(f"side_window_{sx}", (0.04, 1.34, 0.82), (xs(2.55) + sx * 0.005, 10.1, 2.58), m["glass"], bevel=0.03))
    # maçaneta e degrau da porta
    add(M.box(f"door_handle_{sx}", (0.045, 0.24, 0.045), (xs(1.9) + sx * 0.02, 9.5, 1.95), m["chrome"], bevel=0.012, seg=2))
    add(M.box(f"door_handle_bed_{sx}", (0.03, 0.3, 0.1), (xs(1.9) + sx * 0.008, 9.5, 1.95), m["plastic"], bevel=0.02))
    # espelho principal + braços + espelho de aproximação
    mx = sx * (cab_hw(2.4) + 0.4)
    add(M.box(f"mirror_{sx}", (0.1, 0.22, 0.62), (mx, 11.05, 2.38), m["plastic"], bevel=0.04))
    add(M.box(f"mirror_face_{sx}", (0.02, 0.19, 0.55), (mx + sx * 0.055, 11.05, 2.38), m["chrome"], bevel=0.01, seg=1))
    add(M.box(f"mirror_low_{sx}", (0.08, 0.2, 0.22), (mx, 11.05, 1.98), m["plastic"], bevel=0.03))
    add(M.box(f"mirror_low_face_{sx}", (0.02, 0.17, 0.18), (mx + sx * 0.045, 11.05, 1.98), m["chrome"], bevel=0.008, seg=1))
    for zz in (2.15, 2.75):
        add(M.tube(f"mirror_arm_{sx}_{zz}", [(sx * cab_hw(2.4), 10.95, zz), (mx - sx * 0.03, 11.03, zz)], 0.022, m["steel"], seg=8))
    # pisca lateral e marcador
    add(M.box(f"side_blinker_{sx}", (0.03, 0.14, 0.07), (xs(1.2) + sx * 0.005, 11.2, 1.25), m["lamp_amber"], bevel=0.015, seg=1))
    # degrau da porta (dois níveis)
    add(M.box(f"step_{sx}", (0.28, 0.75, 0.05), (sx * (CAB_W / 2 + 0.12), 9.55, 0.55), m["steel"], bevel=0.01, seg=1))
    for k in range(4):
        add(M.box(f"step_tread_{sx}_{k}", (0.24, 0.03, 0.012), (sx * (CAB_W / 2 + 0.12), 9.3 + k * 0.16, 0.58), m["plastic"], bevel=0.003, seg=1))
    add(M.box(f"step_bracket_{sx}", (0.05, 0.5, 0.18), (sx * (CAB_W / 2 + 0.02), 9.55, 0.7), m["steel"], bevel=0.01, seg=1))
    # recorte do arco da roda dianteira (meia-lua escura acima de z=0.9)
    pts = []
    for k in range(0, 13):
        a = math.radians(180 * k / 12)
        yy, zz = FRONT_AXLE_Y + 0.64 * math.cos(a), 0.5 + 0.64 * math.sin(a)
        if zz >= CAB_Z0 + 0.0:
            pts.append((yy, zz))
    pts.append((pts[0][0], pts[0][1]))
    poly = [(pts[i][0], pts[i][1]) for i in range(len(pts) - 1)]
    poly = sorted(poly, key=lambda p: -p[0])
    add(M.plane_extrude(f"front_arch_{sx}", poly, 0.03, (xs(1.0) + sx * 0.002, 0, 0), m["plastic"], plane="YZ", bevel=0.004))


def _roof(add, m):
    add(M.box("roof_hatch", (0.9, 0.9, 0.04), (0, 9.6, CAB_TOP + 0.005), m["plastic"], bevel=0.015, seg=1))
    add(M.box("roof_hatch_rim", (0.98, 0.98, 0.03), (0, 9.6, CAB_TOP - 0.005), m["steel"], bevel=0.012, seg=1))
    add(M.box("cab_rear_panel", (2.0, 0.06, 1.6), (0, CAB_Y0 - 0.005, 2.1), m["plastic"], bevel=0.03))


def build_cab(m, add):
    add(_shell(m))
    _grille(add, m)
    _bumper(add, m)
    for sx in (-1, 1):
        _headlight(add, m, sx)
        _wipers_mirrors_doors(add, m, sx)
    # para-brisa (largura limitada à parte plana da frente)
    yw = cab_yf(2.65) + 0.012
    add(M.box("windshield_frame", (1.9, 0.05, 1.2), (0, yw - 0.012, 2.65), m["plastic"], bevel=0.03, seg=2, rot=(SLOPE_DEG, 0, 0)))
    add(M.box("windshield", (1.8, 0.05, 1.1), (0, yw + 0.006, 2.65), m["glass"], bevel=0.025, seg=2, rot=(SLOPE_DEG, 0, 0)))
    add(M.box("stripe_cab", (CAB_W + 0.01, CAB_Y1 - CAB_Y0 - 0.5, 0.22), (0, (CAB_Y0 + CAB_Y1) / 2 - 0.2, 1.85), m["paint_pink"], bevel=0.02, seg=1))
    _roof(add, m)
