"""Cabine "chata" (T-119): o que é NOSSO em volta da casca importada.

- extensão traseira (dormitório) de CAB_Y0 até as costas da CF500, com o mesmo perfil das costas (medido na
  malha), janela pequena, faixa rosa, caixa lateral e painel de trás: a cabine fica com o comprimento das outras;
- defletor de teto (loft, como o de `cab_roof.py`): leva o teto de 2,8 m até a altura do baú;
- espelhos no estilo das outras cabines (cabeça grande + pequena na haste, espelho de canto do lado esquerdo);
- emblema redondo da grade no lugar do losango apagado;
- pontos de montagem das peças compráveis (frente, visor, teto) para esta cabine.
"""
from __future__ import annotations

import math

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import mesh3d as M
from lib import mesh_adv as A

from .dims import CAB_Y0

WZ0 = 1.72                  # base do para-brisa (z); a "sobrancelha" de luzes da decoração fica em WZ0 - 0,15
STRIPE_Z, STRIPE_H = 1.46, 0.08     # faixa rosa: entre o para-lama (topo 1,37) e a maçaneta (base 1,50)
FAIR_H = 0.4                # altura do defletor acima do teto
FAIR_FRONT = 10.5           # y onde o defletor começa (atrás das 5 lanternas de teto)
FAIR_BACK = 0.72            # quanto o topo do defletor recua


def measure(shell, dy):
    """Medidas da casca já no caminhão: costas, teto, perfil das costas (meia-largura por altura)."""
    co = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in shell])
    hi_part = co[co[:, 2] > 1.3]
    y_back = float(hi_part[:, 1].min())
    roof = float(co[:, 2].max())
    back = co[co[:, 1] < y_back + 0.25]
    zs = np.linspace(0.95, roof - 0.12, 10)
    hw = []
    for z in zs:
        sel = back[np.abs(back[:, 2] - z) < 0.05]
        hw.append(float(np.abs(sel[:, 0]).max()) if len(sel) else 1.18)
    top = co[co[:, 2] > roof - 0.03]
    return {"y_back": y_back, "roof": roof, "zs": [float(z) for z in zs], "hw": hw,
            "roof_front": float(top[:, 1].max()), "wz0": WZ0, "fair_top": roof + FAIR_H, "dy": dy}


def _hw(geo, z):
    return float(np.interp(z, geo["zs"], geo["hw"]))


def _extension(m, add, geo):
    y0, y1 = CAB_Y0, geo["y_back"] + 0.02
    roof = geo["roof"]
    r_roof = 0.1
    rings = []
    zb = 0.92
    for z, ins in ((zb, 0.03), (zb + 0.03, 0.0)):
        rings.append(A.rounded_rect_ring(_hw(geo, 1.0) - ins, y0 + ins, y1, z, 0.02, 0.1, n=4))
    for z in np.linspace(1.0, roof - r_roof, 7):
        rings.append(A.rounded_rect_ring(_hw(geo, z), y0, y1, float(z), 0.02, 0.1, n=4))
    hw_top = _hw(geo, roof - r_roof)
    for k in range(1, 4):                                       # arredondado do teto
        th = math.radians(30 * k)
        ins = r_roof * (1 - math.cos(th))
        rings.append(A.rounded_rect_ring(hw_top - ins, y0 + ins, y1, roof - r_roof + r_roof * math.sin(th), 0.02, max(0.1 - ins, 0.03), n=4))
    add(A.loft("chata_ext", rings, m["paint_white_panel"]))
    add(M.box("chata_ext_rear_panel", (2.0, 0.04, 1.4), (0, y0 - 0.005, 1.9), m["plastic"], bevel=0.02, seg=1))
    for sx in (-1, 1):
        x = sx * (_hw(geo, 2.25) + 0.004)
        add(M.box(f"chata_sleeper_frame_{sx}", (0.01, 0.62, 0.42), (x, 8.98, 2.25), m["plastic_trim"], bevel=0.004, seg=1))
        add(M.box(f"chata_sleeper_glass_{sx}", (0.014, 0.54, 0.34), (x, 8.98, 2.25), m["glass"], bevel=0.004, seg=1))
        xs = sx * (_hw(geo, STRIPE_Z) + 0.004)
        add(M.box(f"chata_stripe_{sx}", (0.01, y1 - y0 - 0.06, STRIPE_H), (xs, (y0 + y1) / 2 - 0.01, STRIPE_Z), m["paint_pink"], bevel=0.0, seg=1))
        hw = _hw(geo, 1.0)
        add(M.box(f"chata_sidebox_{sx}", (0.34, y1 - y0 - 0.2, 0.3), (sx * (hw - 0.19), (y0 + y1) / 2, 0.76), m["plastic_trim"], bevel=0.02, seg=1))
        add(M.box(f"chata_sidebox_trim_{sx}", (0.02, y1 - y0 - 0.24, 0.035), (sx * (hw - 0.015), (y0 + y1) / 2, 0.88), m["chrome"], bevel=0.005, seg=1))
    return y0, y1


def _fairing(m, add, geo):
    z0 = geo["roof"] - 0.04
    y_rear = CAB_Y0 + 0.04
    hw0 = _hw(geo, geo["roof"] - 0.12) - 0.08
    taper = 0.1
    rings = []
    n = 9
    for k in range(n + 1):
        t = k / n
        z = z0 + FAIR_H * math.sin(t * math.pi / 2)
        yf = FAIR_FRONT - FAIR_BACK * t ** 1.3
        rings.append(A.rounded_rect_ring(hw0 - taper * t, y_rear, yf, z, 0.25 + 0.2 * t, 0.12, n=5))
    zt, y_top = z0 + FAIR_H, FAIR_FRONT - FAIR_BACK
    for ins, dz in ((0.05, 0.02), (0.13, 0.035)):
        hw = hw0 - taper - ins
        rings.append(A.rounded_rect_ring(hw, y_rear + ins, y_top - ins, zt + dz, max(0.45 - ins, 0.05), max(0.12 - ins, 0.04), n=5))
    fair = A.loft("chata_fairing", rings, m["paint_white_panel"])
    add(fair)
    add(M.box("chata_fairing_rear_trim", (2 * hw0 - 0.1, 0.03, FAIR_H * 0.9), (0, y_rear - 0.005, z0 + FAIR_H * 0.48), m["plastic_trim"], bevel=0.01, seg=1))
    geo["fair_top"] = zt + 0.035
    return fair


def _mirrors(m, add, geo):
    """Espelho grande + pequeno numa haste que sai do canto de baixo do para-brisa (como nas outras cabines)."""
    for sx in (-1, 1):
        mx, my, zm = sx * 1.56, 11.02, 2.27
        zl = zm - 0.4
        add(M.box(f"mirror_{sx}", (0.21, 0.11, 0.46), (mx, my, zm), m["plastic"], bevel=0.045, seg=3))
        add(M.box(f"mirror_face_{sx}", (0.18, 0.012, 0.41), (mx, my - 0.056, zm), m["chrome"], bevel=0.005, seg=1))
        add(M.box(f"mirror_low_{sx}", (0.18, 0.1, 0.2), (mx, my, zl), m["plastic"], bevel=0.04, seg=3))
        add(M.box(f"mirror_low_face_{sx}", (0.15, 0.012, 0.16), (mx, my - 0.051, zl), m["chrome"], bevel=0.005, seg=1))
        base = (sx * 1.13, 11.24, 1.9)
        arm = [base, (sx * 1.3, 11.24, 1.95), (sx * 1.47, 11.1, 2.0), (mx - sx * 0.02, my, zm - 0.18)]
        add(M.tube(f"mirror_arm_{sx}", arm, 0.022, m["plastic"], seg=8))
        add(M.tube(f"mirror_stay_{sx}", [(mx, my + 0.02, zm - 0.2), (mx, my + 0.02, zl + 0.08)], 0.015, m["steel"], seg=6))
        add(M.tube(f"mirror_brace_{sx}", [(sx * 1.12, 10.98, 2.62), (mx - sx * 0.03, my, zm + 0.2)], 0.012, m["steel"], seg=6))
        add(M.box(f"mirror_foot_{sx}", (0.06, 0.08, 0.1), base, m["plastic"], bevel=0.015, seg=1))
    # espelho de canto (lado do passageiro, costume japonês): olha a frente do para-choque
    base, tip = (-1.1, 11.3, 1.98), (-1.24, 11.56, 2.1)
    add(M.tube("corner_mirror_arm", [base, tip], 0.012, m["chrome"], seg=6))
    add(M.box("corner_mirror", (0.16, 0.06, 0.11), (tip[0], tip[1] + 0.02, tip[2] + 0.06), m["plastic"], bevel=0.025, seg=2))
    add(M.box("corner_mirror_face", (0.13, 0.01, 0.085), (tip[0], tip[1] + 0.052, tip[2] + 0.06), m["chrome"], bevel=0.005, seg=1))


def _stripe(m, add, geo, tree):
    """Faixa rosa na casca importada (a lateral da CF500 é plana): raios vindos de fora acham o x da chapa e
    até onde ela vai antes do canto da frente; a faixa é uma régua reta (buracos sob o para-lama são ignorados)."""
    for sx in (-1, 1):
        xs, ys = [], []
        y = geo["y_back"]
        while y < geo["dy"] + 1.3:
            hit = tree.ray_cast(Vector((sx * 3.0, y, STRIPE_Z)), Vector((-sx, 0, 0)))
            if hit[0] is not None and abs(hit[1].x) > 0.85:
                xs.append(abs(hit[0].x))
                ys.append(y)
            y += 0.05
        if len(ys) < 2:
            continue
        x = float(np.median(xs)) + 0.004
        y0, y1 = min(ys), max(ys) - 0.02
        add(M.box(f"chata_stripe_cab_{sx}", (0.01, y1 - y0, STRIPE_H), (sx * x, (y0 + y1) / 2, STRIPE_Z), m["paint_pink"], bevel=0.0, seg=1))


def _lamps(m, add, geo):
    """Disco aceso no centro de cada farol redondo (o refletor da CF500 fica escuro: farol legível de dia)."""
    for x, y, z, r in geo.get("lamps", []):
        add(M.cylinder(f"hl_disc_{x:+.2f}", r * 0.55, 0.012, (x, y + 0.004, z), m["lamp_white"], axis="Y", seg=16))


def _badge(m, add, geo):
    y = geo["dy"] + 1.17
    add(M.cylinder("badge_ring", 0.1, 0.04, (0, y + 0.02, 1.22), m["chrome"], axis="Y", seg=24))
    add(M.cylinder("badge_core", 0.07, 0.04, (0, y + 0.028, 1.22), m["paint_blue"], axis="Y", seg=24))


def build(m, add, geo, surf, tree):
    """Monta as peças extras; devolve quantos triângulos acrescentou."""
    made = []

    def add2(o):
        made.append(o)
        add(o)
        return o
    _extension(m, add2, geo)
    geo["fairing"] = _fairing(m, add2, geo)
    _mirrors(m, add2, geo)
    _badge(m, add2, geo)
    _stripe(m, add2, geo, tree)
    _lamps(m, add2, geo)
    return M.count_tris(made)


def mounts(geo, surf, tree):
    """Pontos de montagem próprios da cabine chata (os outros ficam como em dims.MOUNTS)."""
    dy = geo["dy"]
    fair = geo["fairing"]
    ft = BVHTree.FromPolygons([v.co.copy() for v in fair.data.vertices], [list(p.vertices) for p in fair.data.polygons])
    hit = ft.ray_cast(Vector((0, 10.0, 6.0)), Vector((0, 0, -1)))
    roof_z = hit[0].z if hit[0] is not None else geo["fair_top"]
    face = surf(0.0, 1.55)[0]
    return {
        "MOUNT_FRONT_BUMPER": (0.0, dy + 1.0, 0.5),
        "MOUNT_FRONT_GRILLE": (0.0, dy + 1.17, 1.22),
        "MOUNT_FRONT_ORNAMENT": (0.0, face.y, 1.55),
        "MOUNT_VISOR": (0.0, geo["roof_front"] + 0.03, geo["roof"] - 0.01),
        "MOUNT_ROOF": (0.0, 10.0, roof_z),
        "MOUNT_ROOF_LIGHTS": (0.0, geo["roof_front"] - 0.2, geo["roof"]),
    }
