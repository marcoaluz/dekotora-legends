"""Frente da cabine: para-brisa curvo com borracha e limpadores, grelha da caixa de ar, grade, faróis
que acompanham o canto e para-choque envolvente (perfil varrido ao longo da frente).

Tudo que encosta na casca usa `cab_surface.patch/ribbon` (coordenada q ao redor da frente)."""
import math

import bmesh
from mathutils import Vector

from lib import mesh3d as M
from lib.mesh3d import _link

from .cab_surface import patch, ribbon, rounded_poly
from .dims import CAB_Y1


def _yaw_obj(o, n):
    """Gira um objeto criado com eixo Y (cilindro) para apontar na normal horizontal n."""
    o.rotation_euler = (math.radians(90), 0.0, -math.atan2(n.x, n.y))
    return o


# ---------------------------------------------------------------- para-brisa

def _windshield(add, m, c, sh):
    ev = sh.front_ev()
    zb, zt = c.wz0 + 0.05, c.wz1 - 0.05
    if c.name == "alta":
        zt = c.zm(3.05)
    wrap = {"padrao": (1.5, 1.38), "classica": (1.25, 1.2), "aero": (1.62, 1.45), "alta": (1.5, 1.4)}[c.name]
    glass = rounded_poly([(-wrap[0], zb), (wrap[0], zb), (wrap[1], zt), (-wrap[1], zt)], 0.09, 4)
    frame = rounded_poly([(-wrap[0] - 0.07, zb - 0.05), (wrap[0] + 0.07, zb - 0.05), (wrap[1] + 0.07, zt + 0.045),
                          (-wrap[1] - 0.07, zt + 0.045)], 0.12, 4)
    add(patch("windshield_frame", ev, frame, 0.0, 0.009, m["plastic_trim"], nz=6, nu=16))
    add(patch("windshield", ev, glass, 0.0, 0.014, m["glass_wind"], nz=6, nu=16))
    if c.name == "alta":                                       # faixa de vidro superior (teto alto)
        za, zb2 = c.zm(3.2), c.wz1 - 0.06
        up = rounded_poly([(-1.25, za), (1.25, za), (1.2, zb2), (-1.2, zb2)], 0.06, 3)
        add(patch("upper_glass_frame", ev, rounded_poly([(-1.3, za - 0.03), (1.3, za - 0.03), (1.25, zb2 + 0.03), (-1.25, zb2 + 0.03)], 0.08, 3),
                  0.0, 0.008, m["plastic_trim"], nz=3, nu=10))
        add(patch("upper_glass", ev, up, 0.0, 0.013, m["glass"], nz=3, nu=10))
    # limpadores estacionados na base do vidro (braço + palheta), pivôs na grelha da caixa de ar
    for k, q0 in enumerate((-0.92, 0.08)):
        arm = [ev(q0 + 0.06 * i, zb + 0.03 + 0.012 * i, 0.03) for i in range(0, 13, 4)]
        add(M.tube(f"wiper_arm_{k}", arm, 0.011, m["plastic"], seg=6))
        add(ribbon(f"wiper_blade_{k}", ev, [(q0 + 0.1 + 0.07 * i, zb + 0.07) for i in range(11)], 0.024, 0.022, m["rubber"]))
        p = ev(q0, zb - 0.025, 0.02)
        add(_yaw_obj(M.cylinder(f"wiper_pivot_{k}", 0.028, 0.04, p, m["plastic"], axis="Y", seg=10), sh.normal(q0, zb)))
    # grelha da caixa de ar (entrada de ar do aquecedor) logo abaixo do para-brisa
    zc0, zc1 = c.wz0 - 0.1, c.wz0 - 0.015
    add(patch("cowl_vent", ev, rounded_poly([(-1.05, zc0), (1.05, zc0), (1.05, zc1), (-1.05, zc1)], 0.03, 2), 0.0, 0.007,
              m["vent_slots"], nz=2, nu=12))


# ---------------------------------------------------------------- grade

def _grille(add, m, c, sh):
    ev = sh.front_ev()
    y = CAB_Y1
    if c.name == "classica":                                   # grade alta com tela fina e diagonal (F7)
        g = rounded_poly([(-0.62, 0.98), (0.62, 0.98), (0.62, 1.74), (-0.62, 1.74)], 0.05, 2)
        add(patch("grille_surround", ev, rounded_poly([(-0.68, 0.94), (0.68, 0.94), (0.68, 1.78), (-0.68, 1.78)], 0.07, 2),
                  0.0, 0.03, m["chrome"], nz=3, nu=8))
        add(patch("grille_mesh_all", ev, g, 0.0, 0.034, m["grille_honeycomb"], nz=3, nu=8))
        add(M.tube("grille_diag", [(-0.56, y + 0.05, 1.02), (0.56, y + 0.05, 1.7)], 0.026, m["chrome"], seg=8))
        add(M.box("badge_plate", (0.3, 0.03, 0.1), (0.3, y + 0.06, 1.36), m["chrome"], bevel=0.012, seg=1))
        for k in range(3):                                     # 3 respiros acima da grade
            z = 1.9 + k * 0.05
            add(patch(f"front_slot_{k}", ev, [(-0.32, z), (0.32, z), (0.32, z + 0.022), (-0.32, z + 0.022)], 0.0, 0.006, m["plastic_trim"], nz=1, nu=4))
        return
    top = c.wz0 - 0.2
    if c.name == "aero":                                       # grade trapezoidal com lâminas cromadas
        outer = [(-0.56, 0.98), (0.56, 0.98), (0.66, top), (-0.66, top)]
        add(patch("grille", ev, rounded_poly(outer, 0.06, 3), 0.0, 0.012, m["plastic_trim"], nz=4, nu=10))
        n = 6
        for i in range(n):
            z = 1.04 + i * (top - 1.1) / (n - 1)
            hw = 0.54 + 0.1 * (z - 0.98) / (top - 0.98)
            add(patch(f"grille_slat_{i}", ev, [(-hw, z), (hw, z), (hw, z + 0.035), (-hw, z + 0.035)], 0.0, 0.03, m["chrome"], nz=1, nu=8))
        r = 0.16
    else:                                                      # padrao/alta: grade alta (FH) + grade baixa perfurada
        upper = rounded_poly([(-0.6, 1.5), (0.6, 1.5), (0.64, top), (-0.64, top)], 0.06, 3)
        add(patch("grille_upper", ev, upper, 0.0, 0.012, m["plastic_trim"], nz=4, nu=10))
        for i in range(4):
            z = 1.56 + i * (top - 1.62) / 3
            add(patch(f"grille_bar_{i}", ev, [(-0.6, z), (0.6, z), (0.6, z + 0.03), (-0.6, z + 0.03)], 0.0, 0.028, m["chrome"], nz=1, nu=8))
        lower = rounded_poly([(-0.55, 0.98), (0.55, 0.98), (0.55, 1.42), (-0.55, 1.42)], 0.05, 2)
        add(patch("grille_lower_frame", ev, rounded_poly([(-0.6, 0.94), (0.6, 0.94), (0.6, 1.46), (-0.6, 1.46)], 0.07, 2),
                  0.0, 0.02, m["chrome"], nz=3, nu=8))
        add(patch("grille_lower", ev, lower, 0.0, 0.024, m["grille_honeycomb"], nz=3, nu=8))
        r = 0.11
    zb = (1.5 + top) / 2 if c.name != "aero" else (0.98 + top) / 2      # no meio da grade alta
    add(M.cylinder("badge_ring", r, 0.04, (0, ev(0, zb).y + 0.03, zb), m["chrome"], axis="Y", seg=24))
    add(M.cylinder("badge_core", r - 0.03, 0.04, (0, ev(0, zb).y + 0.038, zb), m["paint_blue"], axis="Y", seg=24))
    # (a fileira de luzes da decoração V7 fica logo acima da grade, em wz0 - 0,15: ver deco.py)


# ---------------------------------------------------------------- faróis

def _headlight(add, m, sx, c, sh):
    ev = sh.front_ev()

    def P(pts):                                                # polígono do lado direito -> lado sx
        return [(sx * u, z) for (u, z) in (pts if sx > 0 else reversed(pts))]

    if c.name == "classica":                                   # caixa com dois faróis redondos + pisca que dobra o canto
        house = rounded_poly(P([(0.66, 1.16), (1.02, 1.16), (1.02, 1.5), (0.66, 1.5)]), 0.04, 2)
        add(patch(f"hl_house_{sx}", ev, house, 0.0, 0.05, m["plastic_trim"], nz=3, nu=4))
        for k, q in enumerate((0.75, 0.93)):
            n = sh.normal(sx * q, 1.33)
            p = ev(sx * q, 1.33, 0.06)
            add(_yaw_obj(M.cylinder(f"hl_ring_{sx}_{k}", 0.1, 0.03, p, m["chrome"], axis="Y", seg=20), n))
            add(_yaw_obj(M.cylinder(f"hl_lens_{sx}_{k}", 0.083, 0.03, p + n * 0.012, m["glass"], axis="Y", seg=20), n))
            add(_yaw_obj(M.cylinder(f"hl_bulb_{sx}_{k}", 0.05, 0.02, p + n * 0.022, m["lamp_white"], axis="Y", seg=14), n))
        add(patch(f"hl_blinker_{sx}", ev, rounded_poly(P([(1.05, 1.2), (1.75, 1.2), (1.75, 1.46), (1.05, 1.46)]), 0.04, 2),
                  0.0, 0.02, m["lamp_amber"], nz=2, nu=6))
        return
    if c.name == "aero":                                       # LED fino e longo, envolvendo o canto
        bez = P([(0.6, 1.24), (1.8, 1.24), (1.85, 1.46), (0.63, 1.42)])
        lens = P([(0.64, 1.27), (1.76, 1.27), (1.8, 1.43), (0.66, 1.39)])
    elif c.name == "alta":                                     # dois módulos quadrados com aro cromado
        bez = P([(0.6, 1.08), (1.66, 1.08), (1.7, 1.44), (0.6, 1.44)])
        lens = P([(0.64, 1.11), (1.62, 1.11), (1.66, 1.41), (0.64, 1.41)])
    else:                                                      # padrao: envolvente com o canto de fora mais alto
        bez = P([(0.62, 1.08), (1.72, 1.08), (1.8, 1.46), (0.64, 1.38)])
        lens = P([(0.66, 1.11), (1.68, 1.11), (1.75, 1.43), (0.68, 1.35)])
    add(patch(f"hl_bezel_{sx}", ev, rounded_poly(bez, 0.06, 3), 0.0, 0.02, m["plastic_trim"], nz=4, nu=10))
    # fundo da lente (refletor escuro); as lâmpadas ficam por cima (sem transparência: barato no celular)
    add(patch(f"hl_lens_{sx}", ev, rounded_poly(lens, 0.05, 3), 0.0, 0.026, m["glass_lens"], nz=4, nu=10))
    zc = sum(p[1] for p in lens) / 4
    if c.name == "aero":
        for k, q in enumerate((0.85, 1.12, 1.4)):              # 3 LEDs retangulares
            add(patch(f"hl_led_{sx}_{k}", ev, P([(q - 0.1, 1.33), (q + 0.1, 1.33), (q + 0.1, 1.38), (q - 0.1, 1.38)]),
                      0.0, 0.036, m["lamp_white"], nz=1, nu=3))
        add(ribbon(f"hl_drl_{sx}", ev, [(sx * (0.68 + 0.05 * i), 1.295 - 0.002 * i) for i in range(23)], 0.037, 0.02, m["lamp_white"]))
    else:
        for k, q in enumerate((0.88, 1.22) if c.name == "padrao" else (0.85, 1.35)):
            n = sh.normal(sx * q, zc)
            p = ev(sx * q, zc + 0.02, 0.03)
            add(_yaw_obj(M.cylinder(f"hl_proj_ring_{sx}_{k}", 0.085, 0.02, p, m["chrome"], axis="Y", seg=18), n))
            add(_yaw_obj(M.cylinder(f"hl_proj_{sx}_{k}", 0.062, 0.02, p + n * 0.008, m["lamp_white"], axis="Y", seg=18), n))
        # luz diurna em "L": embaixo da lente e subindo pelo lado de dentro
        drl = [(sx * 0.7, 1.32), (sx * 0.7, 1.15)] + [(sx * (0.76 + 0.07 * i), 1.145) for i in range(13)]
        add(ribbon(f"hl_drl_{sx}", ev, drl, 0.038, 0.022, m["lamp_white"]))
        bl = P([(1.5, 1.2), (1.7, 1.2), (1.74, 1.38), (1.52, 1.34)])
        add(patch(f"hl_blinker_{sx}", ev, bl, 0.0, 0.033, m["lamp_amber"], nz=2, nu=3))
        if c.name == "alta":
            add(ribbon(f"hl_trim_{sx}", ev, rounded_poly(bez, 0.06, 3), 0.024, 0.018, m["chrome"], closed=True))


# ---------------------------------------------------------------- para-choque (perfil varrido)

def _sweep(name, sh, qs, prof, mat, z_ref=1.0):
    """Perfil (d, z) varrido ao longo da frente: d = distância para fora da casca na altura z_ref."""
    bm = bmesh.new()
    grid = []
    for q in qs:
        base = sh.raw(q, z_ref)
        n = sh.normal(q, z_ref)
        n = Vector((n.x, n.y, 0)).normalized()
        grid.append([bm.verts.new((base.x + n.x * d, base.y + n.y * d, z)) for (d, z) in prof])
    m = len(prof)
    for i in range(len(qs) - 1):
        for j in range(m):
            j2 = (j + 1) % m
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j2], grid[i][j2]))
    bm.faces.new(grid[0])
    bm.faces.new(grid[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _link(name, bm, mat)


def _qs(end):
    """Amostras de q de -end a +end (mais densas nos cantos)."""
    out = []
    for q in [i / 4 for i in range(0, 4)] + [1 + i / 8 for i in range(0, 8)] + [2 + i * 0.12 for i in range(0, 20)]:
        if q <= end + 1e-6:
            out.append(q)
    if out[-1] < end - 1e-6:
        out.append(end)
    return [-q for q in reversed(out[1:])] + out


def _bumper(add, m, c, sh):
    qs = _qs(2.32)
    chrome = c.name == "classica"
    if c.name == "aero":                                       # inteiro pintado com lábio preto
        add(_sweep("bumper", sh, qs, [(-0.02, 0.5), (0.18, 0.5), (0.24, 0.6), (0.25, 0.8), (0.21, 0.93), (-0.02, 0.95)], m["paint_white_panel"]))
        add(_sweep("bumper_lip", sh, qs, [(-0.02, 0.4), (0.24, 0.4), (0.26, 0.45), (0.19, 0.51), (-0.02, 0.51)], m["plastic_trim"]))
    else:
        upper = [(-0.02, 0.62), (0.2, 0.62), (0.245, 0.68), (0.245, 0.84), (0.2, 0.92), (-0.02, 0.94)]
        add(_sweep("bumper", sh, qs, upper, m["chrome"] if chrome else m["paint_white_panel"]))
        add(_sweep("bumper_valance", sh, qs, [(-0.02, 0.4), (0.18, 0.4), (0.22, 0.46), (0.215, 0.63), (-0.02, 0.63)], m["plastic_trim"]))
        if chrome:
            add(_sweep("bumper_rub", sh, _qs(2.2), [(0.24, 0.73), (0.262, 0.74), (0.262, 0.79), (0.24, 0.8)], m["rubber"]))
    y = CAB_Y1
    add(M.box("plate_front", (0.52, 0.02, 0.13), (0, y + 0.255, 0.76), m["paint_white"], bevel=0.01, seg=1))
    add(M.box("plate_frame", (0.56, 0.015, 0.17), (0, y + 0.247, 0.76), m["plastic"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        q = sx * 0.88
        n = sh.normal(q, 1.0)
        n = Vector((n.x, n.y, 0)).normalized()
        b = sh.raw(q, 1.0)
        p = Vector((b.x, b.y, 0.52)) + n * 0.215
        add(_yaw_obj(M.cylinder(f"fog_ring_{sx}", 0.07, 0.03, p, m["chrome"], axis="Y", seg=18), n))
        add(_yaw_obj(M.cylinder(f"fog_{sx}", 0.055, 0.03, p + n * 0.008, m["lamp_white"], axis="Y", seg=18), n))
        add(M.box(f"bumper_vent_{sx}", (0.36, 0.02, 0.08), (sx * 0.42, y + 0.215, 0.5), m["mesh_perf_vent"], bevel=0.01, seg=1))
        add(M.box(f"tow_cover_{sx}", (0.1, 0.012, 0.06), (sx * 0.62, y + 0.25, 0.7), m["plastic"], bevel=0.01, seg=1))
    # degrau central de chapa xadrez (subir para limpar o para-brisa)
    add(M.box("bumper_step", (0.7, 0.14, 0.035), (0, y + 0.2, 0.935), m["diamond"], bevel=0.008, seg=1))


def build_front(m, add, c, sh):
    _windshield(add, m, c, sh)
    _grille(add, m, c, sh)
    _bumper(add, m, c, sh)
    for sx in (-1, 1):
        _headlight(add, m, sx, c, sh)
