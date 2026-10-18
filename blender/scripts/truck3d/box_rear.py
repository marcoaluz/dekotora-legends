"""Ferragens do baú premium (T-136): dobradiças, barras de trava com mancais e alavancas, borracha de vedação das
portas, escada, lanternas com aro cromado, faixa refletiva, frisos cromados, piso e travessas sob o baú.

São malhas de verdade nas duas versões (alta e leve): no jogo usam os materiais do conjunto padrão (cromo por matcap,
borracha, luzes animadas); na gravação dos mapas entram só como "sombra" (oclusão) sobre as portas e a chapa.
"""
from __future__ import annotations

from lib import mesh3d as M

from . import box_layout as BL
from .body import STD, BoxDims

HINGE_T = (0.1, 0.37, 0.63, 0.9)          # dobradiças: fração da altura da porta
BAR_X = (0.22, 0.66)                      # barras de trava (m, em cada folha; baú padrão)
LADDER_X = (0.8, 1.08)


def build_hardware(m, add, b: BoxDims = STD, seg: int = 8):
    lay = BL.Layout(b)
    k, w2 = lay.k, lay.w2
    zd0, zd1 = lay.z_door0, lay.z_door1
    hd = zd1 - zd0
    yd = BL.REAR_Y
    ch, rub = m["chrome"], m["rubber"]
    add(M.box("boxp_floor", (b.w - 0.06, b.l - 0.05, 0.04), (0, b.l / 2, b.z0 - 0.02), m["plastic"], bevel=0.0, seg=1))
    n = max(4, int((b.l - 0.6) / 0.42))
    for i in range(n + 1):                                # travessas do piso (aparecem entre as rodas)
        y = 0.3 + i * (b.l - 0.6) / n
        add(M.box(f"boxp_cross_{i}", (b.w - 0.1, 0.06, 0.09), (0, y, b.z0 - 0.085), m["plastic"], bevel=0.0, seg=1))
    # --- borracha de vedação: contorno das duas folhas e junta do meio
    add(M.box("boxp_seal_mid", (0.03, 0.012, hd), (0, yd - 0.004, (zd0 + zd1) / 2), rub, bevel=0.0, seg=1))
    for sx in (-1, 1):
        add(M.box(f"boxp_seal_side_{sx}", (0.02, 0.012, hd), (sx * (lay.door_x - 0.01), yd - 0.004, (zd0 + zd1) / 2), rub, bevel=0.0, seg=1))
    for z in (zd0 + 0.01, zd1 - 0.01):
        add(M.box(f"boxp_seal_h_{z:.2f}", (2 * lay.door_x, 0.012, 0.02), (0, yd - 0.004, z), rub, bevel=0.0, seg=1))
    for sx in (-1, 1):
        x_out = sx * lay.door_x
        # dobradiças: chapa na porta, articulação (pino) e chapa na coluna
        for t in HINGE_T:
            z = zd0 + t * hd
            add(M.box(f"boxp_hinge_leaf_{sx}_{t}", (0.26 * k, 0.012, 0.075), (x_out - sx * 0.15 * k, yd - 0.01, z), ch, bevel=0.004, seg=1))
            add(M.cylinder(f"boxp_hinge_pin_{sx}_{t}", 0.021, 0.11, (x_out + sx * 0.012, yd - 0.03, z), ch, axis="Z", seg=seg))
            add(M.box(f"boxp_hinge_post_{sx}_{t}", (0.07, 0.012, 0.075), (x_out + sx * 0.06, -0.086, z), ch, bevel=0.004, seg=1))
        # barras de trava: tubo do chão ao teto, mancais na travessa e na soleira, guias na porta, alavanca
        for j, bx in enumerate(BAR_X):
            x = sx * bx * k
            add(M.cylinder(f"boxp_bar_{sx}_{j}", 0.019, b.top - b.z0 - 0.06, (x, yd - 0.04, (b.z0 + b.top) / 2), ch, axis="Z", seg=seg))
            for z in (b.z0 + 0.06, b.top - 0.07):
                add(M.box(f"boxp_keeper_{sx}_{j}_{z:.2f}", (0.075, 0.05, 0.085), (x, -0.095, z), ch, bevel=0.01, seg=1))
            for t in (0.3, 0.75):
                add(M.box(f"boxp_guide_{sx}_{j}_{t}", (0.06, 0.035, 0.035), (x, yd - 0.025, zd0 + t * hd), ch, bevel=0.006, seg=1))
            zh = b.kz(2.1)                                            # acima das lanternas
            add(M.box(f"boxp_cam_{sx}_{j}", (0.055, 0.05, 0.07), (x, yd - 0.045, zh), ch, bevel=0.008, seg=1))
            lx = x + sx * 0.16 * k                                    # alavanca deitada, apontando para fora
            add(M.box(f"boxp_lever_{sx}_{j}", (0.3 * k, 0.022, 0.04), (lx, yd - 0.07, zh), ch, bevel=0.008, seg=1))
            add(M.box(f"boxp_lever_keep_{sx}_{j}", (0.045, 0.04, 0.075), (x + sx * 0.31 * k, yd - 0.035, zh), ch, bevel=0.006, seg=1))
        # lanternas: caixa cromada, aro e três lentes abauladas (âmbar, vermelha, branca)
        lx, lz = sx * 1.0 * k, b.kz(1.55)
        add(M.box(f"tail_house_{sx}", (0.4, 0.06, 0.7), (lx, -0.11, lz), ch, bevel=0.03, seg=2))
        for i, (mat, dz) in enumerate((("lamp_amber", 0.22), ("lamp_red", 0.0), ("lamp_white", -0.22))):
            add(M.cylinder(f"tail_rim_{sx}_{i}", 0.098, 0.016, (lx, -0.146, lz + dz), ch, axis="Y", seg=12))
            add(M.cylinder(f"tail_{sx}_{i}", 0.084, 0.03, (lx, -0.158, lz + dz), m[mat], axis="Y", seg=12, bevel=0.012, bevel_seg=1))
        # frisos cromados nos trilhos de baixo e de cima
        x = sx * (w2 + BL.RAIL_OUT + 0.004)
        add(M.box(f"boxp_trim_lo_{sx}", (0.012, b.l - 0.12, 0.024), (x, b.l / 2, b.kz(1.135)), ch, bevel=0.005, seg=1))
        add(M.box(f"boxp_trim_hi_{sx}", (0.012, b.l - 0.12, 0.024), (x, b.l / 2, b.kz(3.115)), ch, bevel=0.005, seg=1))
    add(M.box("boxp_trim_rear", (2 * lay.door_x, 0.012, 0.024), (0, -0.086, b.top - 0.05), ch, bevel=0.005, seg=1))
    # escada (lado direito, na frente da lanterna e da folha direita)
    lz0, lz1 = b.kz(1.25), b.top - 0.05
    for x in LADDER_X:
        add(M.cylinder(f"boxp_ladder_rail_{x}", 0.021, lz1 - lz0, (x * k, -0.21, (lz0 + lz1) / 2), ch, axis="Z", seg=seg))
        for z in (lz0 + 0.12, (lz0 + lz1) / 2, lz1 - 0.1):
            add(M.box(f"boxp_ladder_br_{x}_{z:.2f}", (0.03, 0.13, 0.035), (x * k, -0.15, z), ch, bevel=0.005, seg=1))
    nr = 7
    for i in range(nr):
        z = lz0 + 0.2 + i * (lz1 - lz0 - 0.35) / (nr - 1)
        add(M.cylinder(f"boxp_ladder_rung_{i}", 0.016, (LADDER_X[1] - LADDER_X[0]) * k, (sum(LADDER_X) / 2 * k, -0.21, z), ch, axis="X", seg=seg))
    # faixa refletiva vermelho/branco na soleira
    for i in range(10):
        x = (-1.0 + i * (2.0 / 9)) * lay.door_x / 1.12
        add(M.box(f"refl_{i}", (0.2 * k, 0.012, 0.09), (x, -0.087, b.z0 + 0.07), m["paint_red"] if i % 2 == 0 else m["paint_white"], bevel=0.004, seg=1))
