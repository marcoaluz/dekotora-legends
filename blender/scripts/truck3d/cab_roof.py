"""Teto da cabine: defletor (carenagem) orgânico por loft, escotilha, lanternas de teto, quebra-sol da
clássica e painel de trás. O defletor sobe em curva a partir do teto, afina e arredonda no topo."""
import math

from lib import mesh3d as M
from lib import mesh_adv as A

from .cab_surface import patch, rounded_poly
from .dims import CAB_Y0

# (início do defletor na frente, altura, recuo do topo, afinamento das laterais)
FAIRING = {"padrao": (9.75, 0.34, 0.75, 0.1), "aero": (9.55, 0.4, 0.62, 0.14), "alta": (9.95, 0.58, 0.95, 0.1)}


def _fairing(add, m, c):
    spec = FAIRING.get(c.name)
    if spec is None:
        return
    y_front, h, back, taper = spec
    z0 = c.top - 0.04
    y_rear = CAB_Y0 + c.inset + 0.04
    hw0 = c.hw(c.top) - c.inset - 0.02
    rings = []
    n = 9
    for k in range(n + 1):
        t = k / n
        z = z0 + h * math.sin(t * math.pi / 2)                      # sobe rápido e achata em cima
        yf = y_front - back * t ** 1.3                                # a frente deita para trás em curva
        hw = hw0 - taper * t
        rf = 0.25 + 0.2 * t
        rings.append(A.rounded_rect_ring(hw, y_rear, yf, z, rf, 0.12, n=5))
    zt = z0 + h
    y_top = y_front - back
    for ins, dz in ((0.05, 0.02), (0.13, 0.035)):                       # arredondado do topo
        hw = hw0 - taper - ins
        rings.append(A.rounded_rect_ring(hw, y_rear + ins, y_top - ins, zt + dz, max(0.45 - ins, 0.05), max(0.12 - ins, 0.04), n=5))
    add(A.loft("roof_fairing", rings, m["paint_white_panel"]))
    # borda de trás do defletor (fechamento preto) e pequenas luzes de posição nos cantos do topo
    add(M.box("fairing_rear_trim", (2 * hw0 - 0.1, 0.03, h * 0.9), (0, y_rear - 0.005, z0 + h * 0.48), m["plastic_trim"], bevel=0.01, seg=1))


def _roof_items(add, m, c, sh):
    top = c.top
    yh = 9.45 if c.name != "classica" else 9.9
    add(M.box("roof_hatch", (0.8, 0.8, 0.05), (0, yh - 0.2, top + 0.01 if c.name == "classica" else top - 0.02), m["plastic"], bevel=0.02, seg=1))
    if c.name == "classica":                                   # quebra-sol externo + 5 lâmpadas âmbar
        ev = sh.front_ev()
        zt = c.wz1 - 0.02
        prof = rounded_poly([(-1.25, zt - 0.02), (1.25, zt - 0.02), (1.25, zt + 0.04), (-1.25, zt + 0.04)], 0.02, 2)
        add(patch("sun_visor_base", ev, prof, 0.0, 0.02, m["paint_white_panel"], nz=2, nu=10))
        y = c.yf(c.wz1)
        add(M.box("sun_visor", (2.3, 0.3, 0.035), (0, y + 0.13, zt + 0.06), m["paint_white_panel"], bevel=0.012, seg=1, rot=(-12, 0, 0)))
        for i in range(5):
            add(M.box(f"visor_lamp_{i}", (0.16, 0.08, 0.06), (-0.6 + i * 0.3, y + 0.05, top + 0.05), m["lamp_amber"], bevel=0.02, seg=1))
    else:                                                      # 2 lanternas âmbar nos cantos da frente do teto
        for sx in (-1, 1):
            q = sx * 1.25
            p = sh.ev(q, c.wz1 + 0.01, 0.015)
            add(M.box(f"roof_marker_{sx}", (0.1, 0.05, 0.05), tuple(p), m["lamp_amber"], bevel=0.015, seg=1))
    add(M.box("cab_rear_panel", (2.0, 0.04, 1.4), (0, CAB_Y0 - 0.005, 2.0), m["plastic"], bevel=0.02, seg=1))


def build_roof(m, add, c, sh):
    _fairing(add, m, c)
    _roof_items(add, m, c, sh)
