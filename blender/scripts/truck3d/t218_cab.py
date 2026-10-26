"""Cabines de homenagem (T-218), modeladas DO ZERO por código (nenhuma malha de terceiros): cab-over japonesa
grande "cara chata", quadrada, com dormitório, no estilo dos caminhões dos anos 80/90 do jogo de referência.
Marca e emblema FICTÍCIOS ("HAYATE"); nada de nome real em malha, textura ou arquivo.

Dois estilos de frente (o resto da casca é igual):
  wide  grade preta larga com faixa cromada horizontal no meio (emblema), faróis retangulares embutidos logo acima
        do para-choque cromado largo, setas âmbar nas quinas;
  quad  grade cromada grande com 4 faróis redondos (2 por lado) e barras verticais no meio, para-choque cromado.

Medidas (m): largura 2,49 · costas em y = 8,45 · frente em y = 11,5 (embaixo) com 5° de inclinação · teto 3,32 ·
eixo dianteiro y = 10,2 (o mesmo do caminhão padrão: chassi, rodas e pontos de montagem continuam valendo).
Materiais com os nomes que o jogo e `lib/truck_measure.py` reconhecem: casca `paint_white_panel` (tingível),
para-brisa `glass_wind`, vidro lateral `glass`, faróis `lamp_white`/`glass_lens`, setas `lamp_amber`.
"""
from __future__ import annotations

import math
import os

import bmesh
import bpy
from mathutils import Vector

from lib import mesh3d as M
from lib import mesh_adv as A

from .dims import CAB_Y0, FRONT_AXLE_Y

HW = 1.245                 # meia largura da casca
Y_FRONT = 11.5             # frente da casca em Z_FRONT
Z_FRONT = 1.0
RAKE = 0.088               # quanto a frente recua por metro de subida (~5°)
Z0 = 1.02                  # base da casca (logo acima do pneu dianteiro)
ROOF = 3.10                # teto (T-218: baixo como a chata, para o deque de 2 niveis caber em 4,55 m)
WZ0, WZ1 = 2.02, 2.87      # para-brisa
BRAND = "HAYATE"           # marca FICTÍCIA (registrada em docs/DECISOES.md, T-218)
FONT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "game", "assets", "fonts", "NotoSansJP.ttf"))
STYLES = ("wide", "quad")


class CabInfo:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def yf(z: float) -> float:
    """Y da frente plana da casca na altura z."""
    return Y_FRONT - (z - Z_FRONT) * RAKE


NORMAL = Vector((0.0, 1.0, RAKE)).normalized()
_TH_Z = (Z0, 1.9, 2.3, 2.75, 2.93)                 # "tumblehome": a lateral fecha um pouco acima da cintura
_TH_W = (HW, HW, 1.238, 1.224, 1.218)


def hw_at(z: float) -> float:
    """Meia largura da casca na altura z (lateral levemente inclinada para dentro acima da cintura)."""
    if z <= _TH_Z[0]:
        return _TH_W[0]
    for (za, wa), (zb, wb) in zip(zip(_TH_Z, _TH_W), zip(_TH_Z[1:], _TH_W[1:])):
        if z <= zb:
            return wa + (wb - wa) * (z - za) / (zb - za)
    return _TH_W[-1]


def _slab(name, pts, depth, mat, to3d, uv=False):
    """Polígono `pts` (2D) levado para 3D por `to3d(a, b, off)` e engrossado `depth` para trás (off -depth..0)."""
    bm = bmesh.new()
    front = [bm.verts.new(to3d(a, b, 0.0)) for a, b in pts]
    back = [bm.verts.new(to3d(a, b, -depth)) for a, b in pts]
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    o = M._link(name, bm, mat)
    if uv:
        M.uv_planar(o)
        o["has_uv"] = True
    return o


def front_slab(name, pts_xz, off, depth, mat, uv=False):
    """Placa na frente inclinada da casca: pts em (x, z); `off` = quanto fica na frente da chapa."""
    def to3d(x, z, d):
        p = Vector((x, yf(z), z)) + NORMAL * (off + d)
        return tuple(p)
    return _slab(name, pts_xz, depth, mat, to3d, uv)


def side_slab(name, pts_yz, sx, off, depth, mat, uv=False):
    """Placa na lateral da casca (lado sx = +1 direita / -1 esquerda): pts em (y, z)."""
    def to3d(y, z, d):
        return (sx * (hw_at(z) + off + d), y, z)
    pts = pts_yz if sx > 0 else pts_yz[::-1]
    return _slab(name, pts, depth, mat, to3d, uv)


def rrect(x0, z0, x1, z1, r, n=3):
    """Retângulo de cantos arredondados (anti-horário) em 2D."""
    r = min(r, (x1 - x0) / 2 - 1e-4, (z1 - z0) / 2 - 1e-4)
    out = []
    for (cx, cz), a0 in (((x1 - r, z0 + r), -90), ((x1 - r, z1 - r), 0), ((x0 + r, z1 - r), 90), ((x0 + r, z0 + r), 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            out.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return out


def _rr_x(sx, a, b, z0, z1, r):
    """rrect entre |x| = a e b do lado sx."""
    x0, x1 = sorted((sx * a, sx * b))
    return rrect(x0, z0, x1, z1, r)


def _shell(m, add):
    rings = []
    prof = [(Z0, 0.0, 0.0), (Z0 + 0.04, 0.0, 0.0), (1.4, 0.0, 0.0), (1.9, 0.0, 0.0), (2.4, 0.0, 0.0),
            (2.75, 0.0, 0.0), (2.93, 0.0, 0.0), (3.0, 0.012, 0.04), (3.06, 0.04, 0.12), (ROOF, 0.09, 0.24)]
    for z, din, dfront in prof:
        rings.append(A.rounded_rect_ring(hw_at(min(z, 2.93)) - din, CAB_Y0 + din * 0.5, yf(z) - dfront, z, 0.14, 0.07, n=4))
    shell = A.loft("cab_shell", rings, m["paint_white_panel"])
    # cortes ao longo do comprimento (a cada 10 cm): a medição dos encaixes (lib/truck_measure.py) lê VÉRTICES por
    # fatias de 5 cm; uma chapa grande sem vértices no meio parecia não ter teto.
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    y = CAB_Y0 + 0.1
    while y < Y_FRONT - 0.05:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, y, 0), plane_no=(0, 1, 0))
        y += 0.1
    bm.to_mesh(shell.data)
    bm.free()
    add(shell)
    # cantos de baixo da frente e laterais embaixo da porta (a casca termina em Z0)
    add(M.box("cab_apron", (2 * HW, 0.42, 0.18), (0, yf(0.95) - 0.21, 0.95), m["paint_white_panel"], bevel=0.04, seg=2))
    for sx in (-1, 1):
        add(M.box(f"cab_corner_low_{sx}", (0.06, 0.4, 0.56), (sx * (HW - 0.03), 10.98, 0.77), m["paint_white_panel"], bevel=0.02, seg=1))
        add(M.box(f"cab_step_panel_{sx}", (0.08, 0.62, 0.6), (sx * (HW - 0.04), 9.33, 0.74), m["paint_white_panel"], bevel=0.02, seg=1))
        for k, z in enumerate((0.55, 0.86)):
            add(M.box(f"cab_step_{sx}_{k}", (0.26, 0.5, 0.04), (sx * (HW - 0.13), 9.33, z), m["diamond"], bevel=0.01, seg=1))
        add(A.arch_shell(f"cab_arch_{sx}", (FRONT_AXLE_Y, 0.5), 0.55, 0.6, *((0.86, HW + 0.02) if sx > 0 else (-HW - 0.02, -0.86)),
                         m["plastic_trim"], seg=18))
        add(M.box(f"cab_mudguard_{sx}", (0.36, 0.03, 0.34), (sx * 1.03, FRONT_AXLE_Y - 0.62, 0.62), m["rubber"], bevel=0.01, seg=1))


def _glass(m, add):
    # para-brisa inteiriço com moldura de borracha, limpadores estacionados
    wpts = rrect(-1.09, WZ0, 1.09, WZ1, 0.09)
    add(front_slab("cab_wind_frame", rrect(-1.13, WZ0 - 0.04, 1.13, WZ1 + 0.04, 0.11), 0.003, 0.02, m["plastic"]))
    add(front_slab("cab_windshield", wpts, 0.006, 0.012, m["glass_wind"], uv=True))   # quase rente: a viseira encosta
    for sx in (-1, 1):
        w = M.box(f"cab_wiper_{sx}", (0.85, 0.025, 0.025), (sx * 0.42 - 0.08, yf(WZ0 + 0.06) + 0.04, WZ0 + 0.07), m["plastic"],
                  bevel=0.0, seg=1, rot=(0, 4 * sx, 0))
        add(w)
    # janelas laterais: porta (com a quina da frente inclinada) e janelinha do dormitório
    for sx in (-1, 1):
        door = [(10.1, 1.98), (11.15, 1.98), (11.07, 2.8), (10.1, 2.8)]
        add(side_slab(f"cab_door_win_frame_{sx}", [(10.06, 1.94), (11.2, 1.94), (11.11, 2.84), (10.06, 2.84)], sx, 0.004, 0.012, m["plastic"]))
        add(side_slab(f"cab_door_win_{sx}", door, sx, 0.01, 0.01, m["glass"]))
        add(side_slab(f"cab_bunk_win_{sx}", rrect(8.85, 2.25, 9.55, 2.68, 0.05), sx, 0.008, 0.012, m["glass"]))
        # vincos da porta, maçaneta, pega-mão
        for name, pts in (("door_seam_b", [(9.96, 1.02), (9.975, 1.02), (9.975, 2.89), (9.96, 2.89)]),
                          ("door_seam_t", [(9.96, 2.89), (11.14, 2.89), (11.14, 2.905), (9.96, 2.905)]),
                          ("door_seam_f", [(11.19, 1.02), (11.205, 1.02), (11.145, 2.9), (11.13, 2.9)])):
            add(side_slab(f"cab_{name}_{sx}", pts, sx, 0.002, 0.006, m["plastic"]))
        add(M.box(f"cab_handle_{sx}", (0.035, 0.2, 0.05), (sx * (HW + 0.02), 10.25, 1.78), m["chrome"], bevel=0.012, seg=1))
        add(M.box(f"cab_grab_{sx}", (0.035, 0.04, 0.55), (sx * (HW + 0.025), 9.9, 1.6), m["chrome"], bevel=0.012, seg=1))
        # faixa fina na linha de cintura (acabamento cromado)
        add(side_slab(f"cab_belt_{sx}", [(8.5, 1.86), (11.18, 1.86), (11.18, 1.9), (8.5, 1.9)], sx, 0.003, 0.006, m["chrome"]))


def _mirrors(m, add):
    for sx in (-1, 1):
        add(M.tube(f"mirror_arm_{sx}", [(sx * 1.2, 11.18, 2.8), (sx * 1.42, 11.38, 2.84), (sx * 1.5, 11.42, 2.74)], 0.022, m["chrome"], seg=8))
        add(M.tube(f"mirror_arm_lo_{sx}", [(sx * 1.2, 11.24, 2.05), (sx * 1.44, 11.4, 2.1), (sx * 1.5, 11.42, 2.2)], 0.02, m["chrome"], seg=8))
        add(M.box(f"mirror_{sx}", (0.07, 0.24, 0.52), (sx * 1.52, 11.42, 2.48), m["plastic"], bevel=0.03, seg=2))
        add(M.box(f"mirror_glass_{sx}", (0.012, 0.2, 0.46), (sx * 1.52, 11.42 - 0.035, 2.48), m["chrome"], bevel=0.004, seg=1,
                  rot=(0, 0, 90)))
        add(M.box(f"mirror_wide_{sx}", (0.07, 0.2, 0.22), (sx * 1.5, 11.44, 2.16), m["plastic"], bevel=0.03, seg=2))
        # espelho de canto (frente, lado do passageiro e do motorista: costume japonês)
        add(M.tube(f"mirror_front_stalk_{sx}", [(sx * 1.05, yf(2.95) - 0.05, 2.97), (sx * 1.15, yf(2.95) + 0.22, 3.0)], 0.015, m["chrome"], seg=6))
        add(M.box(f"mirror_front_{sx}", (0.16, 0.06, 0.13), (sx * 1.17, yf(2.95) + 0.26, 2.98), m["plastic"], bevel=0.02, seg=1))


def _bumper(m, add, style):
    yb = yf(0.65) + 0.12
    add(M.box("bumper", (2 * HW + 0.04, 0.24, 0.46), (0, yb - 0.12, 0.65), m["chrome"], bevel=0.06, seg=3))
    add(M.box("bumper_lip", (2 * HW - 0.1, 0.2, 0.08), (0, yb - 0.14, 0.4), m["plastic"], bevel=0.02, seg=1))
    for sx in (-1, 1):
        add(M.box(f"bumper_wrap_{sx}", (0.05, 0.42, 0.42), (sx * (HW + 0.0), yb - 0.36, 0.65), m["chrome"], bevel=0.02, seg=1))
        add(M.box(f"bumper_fog_{sx}", (0.22, 0.02, 0.09), (sx * 0.78, yb + 0.002, 0.58), m["lamp_white" if style == "quad" else "glass_lens"],
                  bevel=0.01, seg=1))
    for k in (-1, 1):                                       # ganchos de reboque
        add(M.box(f"tow_{k}", (0.1, 0.05, 0.12), (k * 0.35, yb + 0.02, 0.5), m["steel"], bevel=0.01, seg=1))
    return yb


def _front_wide(m, add):
    # grade preta larga com fendas, faixa cromada no meio e o emblema (marca fictícia)
    add(front_slab("grille_frame", rrect(-1.05, 1.2, 1.05, 1.84, 0.05), 0.012, 0.03, m["chrome"]))
    add(front_slab("grille", rrect(-1.0, 1.24, 1.0, 1.8, 0.03), 0.02, 0.02, m["vent_slots"], uv=True))
    add(front_slab("grille_band", rrect(-1.02, 1.45, 1.02, 1.6, 0.02), 0.045, 0.03, m["chrome"]))
    _emblem(m, add, 1.525, 0.11, 0.09)
    # faróis retangulares embutidos (2 por lado) entre o para-choque e a grade, setas âmbar nas quinas
    for sx in (-1, 1):
        add(front_slab(f"hl_bezel_{sx}", _rr_x(sx, 0.5, 1.12, 0.92, 1.16, 0.025),
                       0.01, 0.03, m["chrome"]))
        for k, (a, b) in enumerate(((0.54, 0.8), (0.83, 1.08))):
            x0, x1 = sorted((sx * a, sx * b))
            add(front_slab(f"hl_{sx}_{k}", rrect(x0, 0.95, x1, 1.13, 0.015), 0.03, 0.02, m["glass_lens"]))
            add(front_slab(f"hl_bulb_{sx}_{k}", rrect(x0 + 0.05, 0.99, x1 - 0.05, 1.09, 0.03), 0.042, 0.015, m["lamp_white"]))
        x0, x1 = sorted((sx * 1.14, sx * 1.235))
        add(front_slab(f"sig_{sx}", rrect(x0, 0.93, x1, 1.15, 0.02), 0.01, 0.03, m["lamp_amber"]))
        add(side_slab(f"sig_side_{sx}", [(yf(1.0) - 0.16, 0.93), (yf(1.0) - 0.02, 0.93), (yf(1.0) - 0.02, 1.15), (yf(1.0) - 0.16, 1.15)],
                      sx, 0.004, 0.012, m["lamp_amber"]))


def _front_quad(m, add):
    # grade cromada grande com 4 faróis redondos e barras verticais no meio
    add(front_slab("grille_frame", rrect(-1.2, 0.9, 1.2, 1.86, 0.07), 0.008, 0.03, m["chrome"]))
    add(front_slab("grille", rrect(-1.14, 0.95, 1.14, 1.81, 0.05), 0.016, 0.02, m["vent_slots"], uv=True))
    for i in range(11):
        x = -0.5 + i * 0.1
        add(front_slab(f"grille_bar_{i}", [(x - 0.018, 0.98), (x + 0.018, 0.98), (x + 0.018, 1.76), (x - 0.018, 1.76)], 0.05, 0.035, m["chrome"]))
    for z in (1.3, 1.62):
        add(front_slab(f"grille_hbar_{z}", rrect(-1.12, z - 0.02, 1.12, z + 0.02, 0.01), 0.06, 0.03, m["chrome"]))
    _emblem(m, add, 1.69, 0.1, 0.07)
    for sx in (-1, 1):
        for k, x in enumerate((0.7, 0.96)):
            c = Vector((sx * x, yf(1.1), 1.1)) + NORMAL * 0.03
            ring = M.torus(f"hl_ring_{sx}_{k}", 0.115, 0.022, tuple(c), m["chrome"], axis="Y", seg=20, tube_seg=6)
            ring.rotation_euler.x = -math.atan(RAKE)
            add(ring)
            lens = M.cylinder(f"hl_{sx}_{k}", 0.11, 0.05, tuple(c - NORMAL * 0.005), m["glass_lens"], axis="Y", seg=20)
            lens.rotation_euler.x += -math.atan(RAKE)
            add(lens)
            bulb = M.cylinder(f"hl_bulb_{sx}_{k}", 0.075, 0.03, tuple(c + NORMAL * 0.012), m["lamp_white"], axis="Y", seg=16)
            bulb.rotation_euler.x += -math.atan(RAKE)
            add(bulb)
        add(front_slab(f"sig_{sx}", _rr_x(sx, 1.0, 1.2, 1.33, 1.5, 0.02), 0.07, 0.03, m["lamp_amber"]))
        add(side_slab(f"sig_side_{sx}", [(yf(1.0) - 0.16, 0.93), (yf(1.0) - 0.02, 0.93), (yf(1.0) - 0.02, 1.12), (yf(1.0) - 0.16, 1.12)],
                      sx, 0.004, 0.012, m["lamp_amber"]))


def _emblem(m, add, z, size, depth):
    """Emblema da marca fictícia (texto cromado em relevo) no centro da grade."""
    c = Vector((0.0, yf(z), z)) + NORMAL * depth
    add(M.box("emblem_plate", (size * 7.0, 0.02, size * 1.2), tuple(c - NORMAL * 0.012), m["plastic"], bevel=0.006, seg=1,
              rot=(-math.degrees(math.atan(RAKE)), 0, 0)))
    t = M.text3d("emblem", BRAND, size, tuple(c), m["chrome"], font_path=FONT, extrude=0.006,
                 rot=(90 - math.degrees(math.atan(RAKE)), 0, 180), resolution=3, offset=0.02)
    M.apply_transforms([t])
    add(t)


def _roof(m, add):
    # (sem luzes no teto: o deque da oficina assenta direto na chapa; as luzes ficam na "sobrancelha" e nas peças)
    for sx in (-1, 1):                                       # calha de chuva
        add(M.box(f"rain_gutter_{sx}", (0.03, 11.1 - CAB_Y0, 0.03), (sx * (HW - 0.04), (CAB_Y0 + 11.1) / 2, 3.02),
                  m["plastic"], bevel=0.0, seg=1))
    add(M.box("cab_back_panel", (2 * HW - 0.12, 0.03, 2.1), (0, CAB_Y0 - 0.01, 2.15), m["plastic_trim"], bevel=0.01, seg=1))


def surf(x: float, z: float):
    """(ponto, normal) na frente inclinada da casca (fileira de luzes da "sobrancelha", V7)."""
    return Vector((x, yf(z), z)), NORMAL.copy()


def build_cab(m, add, style: str = "wide") -> CabInfo:
    if style not in STYLES:
        raise SystemExit(f"ERRO: estilo de cabine desconhecido: {style} (use {', '.join(STYLES)})")
    objs = []

    def a(o):
        objs.append(o)
        add(o)
        return o
    _shell(m, a)
    _glass(m, a)
    _mirrors(m, a)
    yb = _bumper(m, a, style)
    (_front_wide if style == "wide" else _front_quad)(m, a)
    _roof(m, a)
    mounts = {
        "MOUNT_FRONT_BUMPER": (0.0, yb, 0.55),
        "MOUNT_FRONT_GRILLE": (0.0, yf(1.5) + 0.05, 1.5),
        "MOUNT_FRONT_ORNAMENT": (0.0, yf(1.92) + 0.03, 1.92),
        "MOUNT_VISOR": (0.0, yf(ROOF) - 0.1, ROOF - 0.01),
        "MOUNT_ROOF": (0.0, 10.0, ROOF),
        "MOUNT_ROOF_LIGHTS": (0.0, yf(ROOF) - 0.3, ROOF),
    }
    return CabInfo(top=ROOF + 0.02, wz0=WZ0, surf=surf, mounts=mounts, tris=M.count_tris(objs), y_back=CAB_Y0,
                   y_front=yb, front_axle=FRONT_AXLE_Y, front_r=0.5, half_w=HW, style=style)
