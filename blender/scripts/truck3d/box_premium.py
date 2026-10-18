"""Baú premium (T-136), versão LEVE do jogo: chapa ondulada de verdade nas laterais (o mural é pintado nela),
trilhos, montantes, colunas, travessa, soleira, portas, teto e parede da frente com UV de atlas (os detalhes finos
- rebites, juntas, borracha de vedação, vincos das portas, desgaste - vêm dos mapas gravados da versão alta,
`bake_box_premium.py`). Ferragens (dobradiças, barras de trava, escada, lanternas, frisos) ficam em `box_rear.py`.

Materiais: paint_white_box (pintura, tingida pela cor do rival), box_metal (alumínio, mesmo atlas), mural (lados),
cromo/borracha/luzes do conjunto padrão. Uso: `build_box_premium(m, add, BoxDims(...))` depois de saber o
comprimento final do baú (cabines curta/jac esticam o baú; o Canter tem outro baú).
"""
from __future__ import annotations

from lib.meshbuild import MeshBuilder, Rect, extrude_profile, mirror_x

from . import box_layout as BL
from . import box_rear
from .body import STD, BoxDims


def side_sheet(lay: BL.Layout, z_a: float, z_b: float, rect: Rect | None, hi_res: int = 0, rows: int = 1) -> MeshBuilder:
    """Faixa de chapa ondulada do lado direito entre as alturas z_a e z_b. `rect` = retângulo do atlas; None = UV
    0..1 do mural."""
    mb = MeshBuilder()
    prof = lay.rib_points(hi_res)
    w2 = lay.w2
    zs = [z_a + (z_b - z_a) * i / rows for i in range(rows + 1)]
    lines = [[(w2 + off, y, z) for y, off in prof] for z in zs]

    def uv(i, j):
        s = lay.side_u(prof[j][0])
        t = i / rows
        return rect.at(s, t) if rect else (s, (zs[i] - lay.z_m0) / (lay.z_m1 - lay.z_m0))
    mb.strip(lines, uv)
    return mb


def rail_profiles(lay: BL.Layout):
    """Perfis (x, z) dos trilhos de baixo e de cima do lado direito (sentido anti-horário)."""
    w2, o, b = lay.w2, BL.RAIL_OUT, lay.b
    lo = [(w2 - 0.03, b.z0), (w2 + o, b.z0), (w2 + o, lay.z_rail_lo - 0.012), (w2 + 0.014, lay.z_rail_lo), (w2 - 0.03, lay.z_rail_lo)]
    hi = [(w2 - 0.03, lay.z_rail_hi), (w2 + 0.014, lay.z_rail_hi), (w2 + o, lay.z_rail_hi + 0.012), (w2 + o, b.top - 0.008),
          (w2 + 0.012, b.top + 0.012), (w2 - 0.07, b.top + 0.012), (w2 - 0.07, b.top)]
    return lo, hi


def post_profile(lay: BL.Layout, yc: float):
    """Montante em chapéu (x, y), apoiado na crista da chapa."""
    w2 = lay.w2
    return [(w2, yc - 0.065), (w2 + 0.016, yc - 0.065), (w2 + 0.016, yc - 0.035), (w2 + 0.055, yc - 0.03),
            (w2 + 0.055, yc + 0.03), (w2 + 0.016, yc + 0.035), (w2 + 0.016, yc + 0.065), (w2, yc + 0.065)]


def rear_post_profile(lay: BL.Layout):
    w2, dx = lay.w2, lay.door_x
    return [(dx, -0.08), (w2 + 0.03, -0.08), (w2 + 0.03, 0.10), (w2, 0.10), (w2, BL.REAR_Y), (dx, BL.REAR_Y)]


def front_post_profile(lay: BL.Layout):
    w2, L = lay.w2, lay.b.l
    return [(w2, L - 0.08), (w2 + 0.03, L - 0.08), (w2 + 0.03, L + 0.03), (w2 - 0.08, L + 0.03), (w2 - 0.08, L), (w2, L)]


def metal_right(lay: BL.Layout) -> MeshBuilder:
    """Peças de alumínio do lado direito (trilhos, montantes, colunas): o lado esquerdo é o espelho (mesmo UV)."""
    b = lay.b
    mb = MeshBuilder()
    lo, hi = rail_profiles(lay)
    caps = BL.pad(BL.R_CAPS)
    extrude_profile(mb, lo, 0.0, b.l, "y", BL.pad(BL.R_RAIL_LO), cap_rect=caps)
    extrude_profile(mb, hi, 0.0, b.l, "y", BL.pad(BL.R_RAIL_HI), cap_rect=caps)
    for yc in lay.post_ys():
        extrude_profile(mb, post_profile(lay, yc), lay.z_rail_lo, lay.z_rail_hi, "z", BL.pad(BL.R_POST), cap_rect=caps)
    extrude_profile(mb, rear_post_profile(lay), b.z0 - 0.02, b.top + 0.012, "z", BL.pad(BL.R_REAR_POST), cap_rect=caps)
    extrude_profile(mb, front_post_profile(lay), b.z0 - 0.02, b.top + 0.012, "z", BL.pad(BL.R_FRONT_POST), cap_rect=caps)
    return mb


def metal_center(lay: BL.Layout) -> MeshBuilder:
    """Travessa de cima e soleira da traseira (entre as colunas)."""
    b = lay.b
    mb = MeshBuilder()
    caps = BL.pad(BL.R_CAPS)
    header = [(-0.08, lay.z_door1), (0.0, lay.z_door1), (0.0, b.top + 0.012), (-0.08, b.top + 0.012)]
    sill = [(-0.08, b.z0 - 0.02), (0.0, b.z0 - 0.02), (0.0, lay.z_door0), (-0.08, lay.z_door0)]
    extrude_profile(mb, header, -lay.door_x, lay.door_x, "x", BL.pad(BL.R_HEADER), cap_rect=caps)
    extrude_profile(mb, sill, -lay.door_x, lay.door_x, "x", BL.pad(BL.R_SILL), cap_rect=caps)
    return mb


def paint_panels(lay: BL.Layout, rows_side: int = 1) -> MeshBuilder:
    """Teto, parede da frente e portas (planos com UV de atlas) + faixas de chapa abaixo/acima do mural (dir.)."""
    b, w2 = lay.b, lay.w2
    mb = MeshBuilder()
    rx = w2 - 0.05
    r = BL.pad(BL.R_ROOF)
    z = b.top + 0.004
    mb.quad((-rx, 0.0, z), (rx, 0.0, z), (rx, b.l, z), (-rx, b.l, z),
            (r.at(0, 0), r.at(0, 1), r.at(1, 1), r.at(1, 0)))
    f = BL.pad(BL.R_FRONT)
    fx, y = w2 - 0.08, b.l
    mb.quad((fx, y, b.z0), (-fx, y, b.z0), (-fx, y, b.top), (fx, y, b.top), (f.at(0, 0), f.at(1, 0), f.at(1, 1), f.at(0, 1)))
    d = BL.pad(BL.R_DOORS)
    dx, y = lay.door_x, BL.REAR_Y
    mb.quad((-dx, y, lay.z_door0), (dx, y, lay.z_door0), (dx, y, lay.z_door1), (-dx, y, lay.z_door1),
            (d.at(0, 0), d.at(1, 0), d.at(1, 1), d.at(0, 1)))
    return mb


def side_paint_right(lay: BL.Layout) -> MeshBuilder:
    mb = side_sheet(lay, lay.z_rail_lo, lay.z_m0, BL.pad(BL.R_SIDE_LO))
    mb.extend(side_sheet(lay, lay.z_m1, lay.z_rail_hi, BL.pad(BL.R_SIDE_HI)))
    return mb


def build_low_parts(m, b: BoxDims = STD):
    """Objetos com UV de atlas/mural do baú leve: [(objeto, alvo)], alvo = "atlas" | "mural" | None."""
    lay = BL.Layout(b)
    out = []
    paint = side_paint_right(lay)
    o = paint.build("boxp_paint_side_R", m["paint_white_box"])
    out += [(o, "atlas"), (mirror_x(o, "boxp_paint_side_L"), None)]
    out.append((paint_panels(lay).build("boxp_paint_panels", m["paint_white_box"]), "atlas"))
    met = metal_right(lay).build("boxp_metal_R", m["box_metal"])
    out += [(met, "atlas"), (mirror_x(met, "boxp_metal_L"), None)]
    out.append((metal_center(lay).build("boxp_metal_C", m["box_metal"]), "atlas"))
    mural = side_sheet(lay, lay.z_m0, lay.z_m1, None).build("boxp_mural_R", m["mural"])
    left = mirror_x(mural, "boxp_mural_L")
    uvl = left.data.uv_layers.active
    for d in uvl.data:                                    # lado esquerdo: o desenho lê igual (como no mural antigo)
        d.uv = (1.0 - d.uv[0], d.uv[1])
    out += [(mural, "mural"), (left, None)]
    return out


def build_box_premium(m, add, b: BoxDims = STD):
    """Baú premium completo para o jogo (malhas com UV + ferragens)."""
    for o, _target in build_low_parts(m, b):
        o["has_uv"] = True
        add(o)
    box_rear.build_hardware(m, add, b)
