"""Para-choque traseiro com lanternas, 11 peças do catálogo da T-210 (capturas 063–084), T-231.

Origem = encaixe "rear_bumper" do caminhão: topo, centro, encostado atrás de tudo o que fica embaixo do baú (ver
`lib/socket_rules.py`). A peça cresce para TRÁS (-Y no Blender = +Z no Godot) e para BAIXO. Tamanho nominal: largura
2,40 m, altura <= 0,62 m, fundo do corpo 0,22 m (+ lanternas). O jogo escala pela largura do baú (0,85–1,15).
Como no original, a peça TRAZ as lanternas (substitui as de fábrica de baixo; acendem à noite: material `lamp_tail`) e a
CAIXA DA PLACA (`deco_plate`: o jogo põe a placa do caminhão nela). Desenho nosso, inspirado nas formas das capturas.
"""
from __future__ import annotations

import math

from . import t211_kit as K
from . import t231_kit as T

W = 2.40
D = 0.22


def _body(m, H, name="body", d=D, z_top=0.0, mat=None):
    """Corpo do para-choque (caixa) e a face de trás (vista por quem vem atrás)."""
    o = [K.wedge_box(name, W, d, H, 0.0, mat or m["body"], y0=-d, z0=z_top - H, bevel=0.014)]
    f = K.Face((-W / 2, -d, z_top - H), (W, 0, 0), (0, 0, H))
    return o, f


def _lip(o, m, H, name="lip"):
    """Friso cromado embaixo e em cima (acabamento comum a todos)."""
    o.append(M_box(name + "_low", (W + 0.02, D + 0.02, 0.022), (0, -D / 2, -H + 0.011), m["chrome"]))
    o.append(M_box(name + "_top", (W + 0.02, D + 0.02, 0.018), (0, -D / 2, -0.009), m["chrome"]))


def M_box(name, size, loc, mat):
    from lib import mesh3d as M
    return M.box(name, size, loc, mat, bevel=0.006, seg=1)


def rb_square_row(m):
    H = 0.50
    o, f = _body(m, H)
    _lip(o, m, H)
    o += T.plate_box("plate", f, 0.02, 0.10, 0.22, 0.90, m)
    o += T.square_lamps("lamps", f, 0.25, 0.30, 0.975, 0.96, 9, 1, m, fill=0.80)
    o.append(T.chrome_bar("bar", -W / 2 - 0.01, W / 2 + 0.01, -D - 0.045, -H + 0.06, 0.05, m))
    for k, s in enumerate((0.30, 0.62, 0.92)):                     # suportes da barra
        x = -W / 2 + W * s
        o.append(M_box(f"bar_post_{k}", (0.05, 0.06, 0.08), (x, -D - 0.02, -H + 0.08), m["chrome"]))
    return o


def rb_round_twin(m):
    H = 0.58
    o, f = _body(m, H)
    _lip(o, m, H)
    o += T.plate_box("plate", f, 0.02, 0.10, 0.22, 0.90, m, neon=True)
    o += T.round_lamps("upper", f, T.grid_pts(0.245, 0.845, 0.60, 0.92, 7, 1), 0.058, m)
    o += T.round_lamps("lower", f, T.grid_pts(0.245, 0.845, 0.16, 0.48, 7, 1), 0.058, m)
    o.append(K.bar_on("mid_friso", f, 0.24, 0.535, 0.85, 0.555, m["chrome"], depth=0.012))
    o += T.step_box("step", f, 0.86, 0.10, 0.98, 0.90, m)
    o += T.end_caps("caps", f, m, m["neon"])
    return o


def rb_square_grid(m):
    H = 0.60
    o, f = _body(m, H)
    _lip(o, m, H)
    o += T.plate_box("plate", f, 0.02, 0.10, 0.22, 0.90, m)
    o += T.square_lamps("block_a", f, 0.25, 0.08, 0.49, 0.60, 3, 2, m, fill=0.82)
    o += T.square_lamps("block_b", f, 0.52, 0.08, 0.76, 0.60, 3, 2, m, fill=0.82)
    o += T.square_lamps("top", f, 0.25, 0.70, 0.975, 0.95, 10, 1, m, fill=0.72)
    o += T.step_box("step", f, 0.79, 0.08, 0.975, 0.60, m, slats=4)
    o += T.end_caps("caps", f, m, m["neon"])
    return o


def rb_round_grid(m):
    H = 0.60
    o, f = _body(m, H)
    _lip(o, m, H)
    o += T.plate_box("plate", f, 0.02, 0.10, 0.22, 0.90, m)
    o += T.round_lamps("grid", f, T.grid_pts(0.25, 0.77, 0.10, 0.62, 6, 2), 0.06, m)
    o += T.round_lamps("top", f, T.grid_pts(0.25, 0.975, 0.72, 0.96, 10, 1), 0.042, m, seg=10)
    o += T.step_box("step", f, 0.79, 0.08, 0.975, 0.62, m, slats=4)
    return o


def rb_target(m):
    H = 0.60
    o, f = _body(m, H)
    _lip(o, m, H)
    o += T.plate_box("plate", f, 0.02, 0.10, 0.22, 0.90, m)
    o.append(T.chrome_bar("top_bar", -W / 2 + W * 0.42, W / 2 - W * 0.17, -D - 0.035, -0.07, 0.035, m))
    o += T.round_lamps("cluster_l", f, T.grid_pts(0.24, 0.40, 0.52, 0.96, 3, 2), 0.05, m, seg=10)
    o += T.round_lamps("cluster_r", f, T.grid_pts(0.83, 0.985, 0.52, 0.96, 3, 2), 0.05, m, seg=10)
    o += T.target_lamps("targets", f, T.grid_pts(0.43, 0.80, 0.14, 0.58, 3, 1), 0.085, m)
    o += T.step_box("step", f, 0.83, 0.06, 0.985, 0.46, m, slats=3)
    o.append(K.quad_panel("target_panel", f, 0.42, 0.06, 0.81, 0.66, m["trim"], off=0.008, depth=0.01))
    return o


def rb_double_deck(m):
    H = 0.62
    lo_h = 0.32
    o = [K.wedge_box("body_low", W, D, lo_h, 0.0, m["body"], y0=-D, z0=-H, bevel=0.014),
         K.wedge_box("body_up", W - 0.06, D - 0.07, H - lo_h, 0.0, m["body"], y0=-(D - 0.07), z0=-(H - lo_h), bevel=0.014)]
    fl = K.Face((-W / 2, -D, -H), (W, 0, 0), (0, 0, lo_h))
    fu = K.Face((-(W - 0.06) / 2, -(D - 0.07), -(H - lo_h)), (W - 0.06, 0, 0), (0, 0, H - lo_h))
    o.append(M_box("friso_mid", (W + 0.01, D + 0.015, 0.03), (0, -D / 2, -H + lo_h), m["chrome"]))
    o.append(M_box("lip_low", (W + 0.02, D + 0.02, 0.022), (0, -D / 2, -H + 0.011), m["chrome"]))
    o.append(M_box("lip_top", (W - 0.04, D - 0.05, 0.018), (0, -(D - 0.07) / 2, -0.009), m["chrome"]))
    o += T.plate_box("plate", fl, 0.02, 0.10, 0.21, 0.92, m)
    o += T.round_lamps("lower", fl, T.grid_pts(0.24, 0.84, 0.18, 0.86, 8, 1), 0.06, m)
    o += T.step_box("step", fl, 0.86, 0.10, 0.98, 0.90, m, slats=3)
    o += T.round_lamps("upper", fu, T.grid_pts(0.03, 0.97, 0.18, 0.84, 11, 1), 0.058, m)
    return o


def rb_neon_rows(m):
    H = 0.60
    o, f = _body(m, H)
    _lip(o, m, H)
    o += T.plate_box("plate", f, 0.02, 0.10, 0.22, 0.90, m, neon=True)
    o.append(K.bar_on("neon_top", f, 0.24, 0.925, 0.985, 0.965, m["neon"], depth=0.014))
    o.append(K.bar_on("neon_mid", f, 0.24, 0.50, 0.985, 0.535, m["neon"], depth=0.014))
    o += T.square_lamps("row", f, 0.24, 0.57, 0.985, 0.90, 11, 1, m, fill=0.76)
    o += T.square_lamps("block_a", f, 0.24, 0.06, 0.46, 0.46, 4, 2, m, fill=0.80)
    o += T.square_lamps("block_b", f, 0.765, 0.06, 0.985, 0.46, 4, 2, m, fill=0.80)
    o += T.step_box("step", f, 0.49, 0.06, 0.735, 0.46, m, slats=3)
    o += T.end_caps("caps", f, m, m["neon"])
    return o


def rb_neon_plate(m):
    H = 0.58
    o, f = _body(m, H)
    _lip(o, m, H)
    o.append(K.quad_panel("plate_glow", f, 0.015, 0.06, 0.30, 0.94, m["neon"], off=0.009, depth=0.006))
    o += T.plate_box("plate", f, 0.045, 0.16, 0.27, 0.84, m, neon=False)
    o += T.square_lamps("top", f, 0.33, 0.68, 0.985, 0.95, 11, 1, m, fill=0.74)
    o += T.square_lamps("mid", f, 0.33, 0.10, 0.58, 0.58, 3, 2, m, fill=0.80)
    o.append(K.bar_on("cross_h", f, 0.60, 0.32, 0.80, 0.36, m["neon"], depth=0.014))
    o.append(K.bar_on("cross_v", f, 0.69, 0.16, 0.71, 0.52, m["neon"], depth=0.014))
    o += T.step_box("step", f, 0.82, 0.08, 0.985, 0.58, m, slats=4)
    return o


def rb_bullet(m):
    H = 0.62
    o, f = _body(m, H)
    _lip(o, m, H)
    o += T.plate_box("plate", f, 0.02, 0.24, 0.20, 0.94, m)
    o += T.round_lamps("bullet_l", f, T.grid_pts(0.225, 0.40, 0.30, 0.94, 2, 2), 0.042, m, seg=10, stretch=2.0, depth=0.05)
    o += T.round_lamps("bullet_r", f, T.grid_pts(0.72, 0.985, 0.30, 0.94, 4, 2), 0.042, m, seg=10, stretch=2.0, depth=0.05)
    o.append(K.quad_panel("center", f, 0.42, 0.30, 0.70, 0.92, m["trim"], off=0.008, depth=0.012))
    o.append(K.bar_on("center_neon", f, 0.44, 0.52, 0.68, 0.70, m["neon"], depth=0.014))
    o += K.frame_on("center_fr", f, 0.42, 0.30, 0.70, 0.92, 0.008, 0.02, m["chrome"], depth=0.02)
    o += T.square_lamps("low", f, 0.02, 0.05, 0.985, 0.19, 16, 1, m, fill=0.70, frame=False)
    return o


def rb_torpedo(m):
    H = 0.62
    o, f = _body(m, H)
    _lip(o, m, H)
    o += T.plate_box("plate", f, 0.02, 0.10, 0.20, 0.90, m, neon=True)
    pts = T.grid_pts(0.225, 0.585, 0.14, 0.92, 6, 2) + T.grid_pts(0.625, 0.985, 0.14, 0.92, 6, 2)
    # em leque: cada metade abre para os lados, mais nas pontas (como a bateria das capturas 081-082)
    def tilt(s, t):
        c = 0.405 if s < 0.605 else 0.805
        return math.radians(-38.0 * (s - c) / 0.18)
    o += T.round_lamps("torpedo", f, pts, 0.032, m, seg=10, stretch=3.4, depth=0.05, tilt=tilt)
    o.append(K.bar_on("neon_low", f, 0.22, 0.03, 0.99, 0.07, m["neon"], depth=0.014))
    o.append(K.bar_on("split", f, 0.60, 0.10, 0.61, 0.96, m["chrome"], depth=0.016))
    return o


def rb_grand_panel(m):
    H = 0.62
    o, f = _body(m, H, d=0.26)
    o.append(M_box("lip_low", (W + 0.03, 0.29, 0.03), (0, -0.13, -H + 0.015), m["chrome"]))
    o.append(M_box("lip_top", (W + 0.03, 0.29, 0.024), (0, -0.13, -0.012), m["chrome"]))
    o += T.round_lamps("top", f, T.grid_pts(0.02, 0.98, 0.80, 0.97, 13, 1), 0.044, m, seg=10)
    o += T.round_lamps("bottom", f, T.grid_pts(0.02, 0.98, 0.03, 0.20, 13, 1), 0.044, m, seg=10)
    o.append(K.quad_panel("center", f, 0.30, 0.24, 0.70, 0.76, m["trim"], off=0.008, depth=0.012))
    o += K.frame_on("center_fr", f, 0.30, 0.24, 0.70, 0.76, 0.01, 0.025, m["chrome"], depth=0.022)
    o += T.plate_box("plate", f, 0.41, 0.30, 0.59, 0.66, m)
    # 4 lanternas em volta da placa (nos cantos do painel do meio)
    o += T.round_lamps("arc", f, [(0.345, 0.34), (0.345, 0.64), (0.655, 0.34), (0.655, 0.64)], 0.045, m, seg=10)
    o += T.round_lamps("side_l", f, T.grid_pts(0.06, 0.27, 0.28, 0.72, 2, 2), 0.052, m)
    o += T.round_lamps("side_r", f, T.grid_pts(0.73, 0.94, 0.28, 0.72, 2, 2), 0.052, m)
    o += T.end_caps("caps", f, m, m["chrome"], 0.25, 0.75, w=0.02)
    return o


def _p(pid, name, build, caps, color="preto_ciano", tier="oficina"):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": False, "default_color": color,
            "slot": "rear_bumper", "socket": "rear_bumper", "nominal_w": W, "folder": "rear_t231"}


PARTS = [
    _p("rb_square_row", "Fileira de lanternas quadradas", rb_square_row, "064", color="prata_marinho"),
    _p("rb_round_twin", "Duas fileiras redondas", rb_round_twin, "065-066", color="prata_marinho"),
    _p("rb_square_grid", "Grade de quadradas", rb_square_grid, "067-068"),
    _p("rb_round_grid", "Grade de redondas", rb_round_grid, "069-070", color="prata_marinho"),
    _p("rb_target", "Lanternas alvo", rb_target, "071-072", color="prata_marinho"),
    _p("rb_double_deck", "Dois andares", rb_double_deck, "073-074"),
    _p("rb_neon_rows", "Fileiras com neon", rb_neon_rows, "075-076"),
    _p("rb_neon_plate", "Placa neon", rb_neon_plate, "077-078"),
    _p("rb_bullet", "Lanternas bala", rb_bullet, "079-080", color="prata_marinho"),
    _p("rb_torpedo", "Bateria torpedo", rb_torpedo, "081-082"),
    _p("rb_grand_panel", "Painel grande cromado", rb_grand_panel, "083-084", color="cromo_ciano"),
]
