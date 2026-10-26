"""Carrocerias dos caminhões de homenagem (T-218), modeladas do zero por código, no chassi do baú médio (12 m).

| id      | carroceria                                                                  | cabine       |
| alubox  | baú de alumínio reto e liso, porta lateral e traseira de duas folhas        | wide (cinza) |
| tarp    | plataforma com guardas de alumínio, cabeceira e lona verde-azulada esticada | quad (marinho)|
| pinkbox | baú rosa com o mural grande (gueixa e ondas) e a decoração Dekotora V7      | wide (rosa)  |
| tanker  | tanque elíptico cromado, passarela, corrimão, escada, caixa de válvulas     | wide (branca)|
| dump    | caçamba basculante de inox, estrutura traseira polida, escapamento com protetor | quad (vermelha) |

Todas: traseira em y = 0, frente da carroceria em y = 8,2 (costas da cabine em 8,45). Cada função devolve um dicionário
com `top` (altura do teto da carga), `mounts` (pontos de montagem que mudam) e `box` (BoxDims, só nos baús).
"""
from __future__ import annotations

import math
import os

import bmesh
from mathutils import Vector

from lib import mesh3d as M

from .body import BoxDims
from .deco import LAMP, build_deco

L = 8.2                    # comprimento da carroceria
W2 = 1.25                  # meia largura
FONT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "game", "assets", "fonts", "NotoSansJP.ttf"))
COMPANY = "銀河運輸"         # empresa FICTÍCIA do caminhão de lona ("Ginga Unyu", T-218)


# ----------------------------------------------------------------------------- comum

def rear_end(m, add, z_bar=0.62, lamp_z=0.8):
    """Para-choque de segurança com lanternas japonesas (âmbar, vermelha, vermelha, ré), placa, abas de lama,
    neon sob o chassi e grade lateral de proteção entre os eixos."""
    add(M.box("underrun", (2.3, 0.14, 0.16), (0, -0.1, z_bar), m["steel"], bevel=0.03))
    add(M.box("lamp_bar", (2.36, 0.1, 0.2), (0, -0.08, lamp_z), m["chrome"], bevel=0.03, seg=2))
    for sx in (-1, 1):
        for k, (x, mat) in enumerate(((1.04, "lamp_amber"), (0.82, "lamp_red"), (0.6, "lamp_red"), (0.4, "lamp_white"))):
            add(M.cylinder(f"tail_{sx}_{k}", 0.075, 0.04, (sx * x, -0.14, lamp_z), m[mat], axis="Y", seg=14))
        add(M.box(f"underrun_refl_{sx}", (0.3, 0.02, 0.06), (sx * 0.95, -0.18, z_bar), m["lamp_red"], bevel=0.01, seg=1))
        add(M.box(f"mudflap_{sx}", (0.5, 0.04, 0.5), (sx * 0.95, 0.45, 0.8), m["rubber"], bevel=0.01, seg=1))
        add(M.box(f"underglow_{sx}", (0.05, 9.6, 0.05), (sx * 0.98, 5.9, 0.36), m["lamp_cyan"], bevel=0.01, seg=1))
        for z in (0.62, 0.86):                                 # grade lateral (obrigatória no Japão) entre os eixos
            add(M.box(f"side_guard_{sx}_{z}", (0.04, 4.0, 0.07), (sx * 1.2, 5.75, z), m["chrome"], bevel=0.015, seg=1))
        for y in (3.9, 5.75, 7.6):
            add(M.box(f"side_guard_post_{sx}_{y}", (0.05, 0.05, 0.36), (sx * 1.17, y, 0.74), m["steel"], bevel=0.01, seg=1))
    add(M.box("plate", (0.5, 0.03, 0.24), (0, -0.14, 1.0), m["paint_white"], bevel=0.01, seg=1))


def guard_lamps(m, add, z=0.74, y0=3.9, y1=7.6, n=9):
    """Fileira de luzinhas âmbar/amarelas na grade lateral (decoração das carrocerias abertas)."""
    lamps = (m["lamp_amber"], m["lamp_yellow"])
    for sx in (-1, 1):
        for i in range(n):
            y = y0 + i * (y1 - y0) / (n - 1)
            add(M.box(f"mk_guard_{sx}_{i}", (0.03, LAMP, LAMP), (sx * 1.235, y, z), lamps[i % 2], bevel=0.0, seg=1))


def rear_frame_lamps(m, add, y, z0, z1, hw):
    """Moldura de luzes vermelho/âmbar na traseira (cantos e linha de cima), como no baú V7."""
    n = max(4, int((z1 - z0) / 0.27))
    for sx in (-1, 1):
        for k in range(n + 1):
            z = z0 + k * (z1 - z0) / n
            add(M.box(f"mk_rear_v_{sx}_{k}", (LAMP, 0.03, LAMP), (sx * hw, y, z), m["lamp_red"] if k % 2 == 0 else m["lamp_amber"],
                      bevel=0.0, seg=1))
    for k in range(9):
        x = -hw + k * 2 * hw / 8
        add(M.box(f"mk_rear_h_{k}", (LAMP, 0.03, LAMP), (x, y, z1 + 0.06), m["lamp_red"] if k % 2 == 0 else m["lamp_amber"], bevel=0.0, seg=1))


def _side_markers(m, add, z, top=None):
    for sx in (-1, 1):
        for i in range(6):
            y = 0.5 + i * (L - 1.0) / 5
            add(M.box(f"side_marker_{sx}_{i}", (0.04, 0.16, 0.07), (sx * (W2 + 0.025), y, z), m["lamp_amber"], bevel=0.015, seg=1))


def _text_side(m, add, name, text, size, y, z, sx, mat, x_off=0.012):
    """Texto (kanji) na lateral, lendo certo dos dois lados (nunca espelhado)."""
    t = M.text3d(f"{name}_{sx}", text, size, (sx * (W2 + x_off), y, z), mat, font_path=FONT, extrude=0.004,
                 rot=(90, 0, 90 if sx > 0 else -90), resolution=4, offset=0.012)
    M.apply_transforms([t])
    add(t)
    return t


# ----------------------------------------------------------------------------- baús (alumínio e rosa)

def _box_shell(m, add, mat, top, trim):
    add(M.box("box_sill", (2.42, L, 0.12), (0, L / 2, 1.04), m["steel"], bevel=0.02, seg=1))
    for y in (0.9, 2.3, 3.7, 5.1, 6.5, 7.8):                   # travessas do assoalho
        add(M.box(f"box_cross_{y}", (2.36, 0.08, 0.1), (0, y, 0.96), m["plastic"], bevel=0.01, seg=1))
    add(M.box("body", (2 * W2, L, top - 1.1), (0, L / 2, (1.1 + top) / 2), mat, bevel=0.035, seg=2))
    for sx in (-1, 1):                                          # perfis de canto e trilhos de cima/baixo
        for y in (0.04, L - 0.04):
            add(M.box(f"box_corner_{sx}_{y}", (0.08, 0.08, top - 1.08), (sx * (W2 - 0.02), y, (1.08 + top) / 2), trim, bevel=0.015, seg=1))
        for z in (1.14, top - 0.05):
            add(M.box(f"box_rail_{sx}_{z}", (0.05, L, 0.09), (sx * (W2 + 0.01), L / 2, z), trim, bevel=0.012, seg=1))
    add(M.box("box_front_rail", (2 * W2 + 0.04, 0.05, 0.09), (0, L + 0.01, top - 0.05), trim, bevel=0.012, seg=1))
    add(M.box("box_roof_cap", (2 * W2 + 0.02, L + 0.02, 0.03), (0, L / 2, top + 0.005), trim, bevel=0.01, seg=1))


def _rear_doors(m, add, top, trim):
    """Traseira de duas folhas: moldura, junta do meio, 4 barras de trava com alavanca, dobradiças."""
    hz = top - 1.2
    add(M.box("rear_header", (2 * W2, 0.06, 0.14), (0, -0.03, top - 0.08), trim, bevel=0.015, seg=1))
    add(M.box("rear_sill", (2 * W2, 0.06, 0.1), (0, -0.03, 1.15), trim, bevel=0.015, seg=1))
    add(M.box("door_seam", (0.03, 0.04, hz), (0, -0.02, (1.2 + top) / 2 - 0.02), m["plastic"], bevel=0.005, seg=1))
    for sx in (-1, 1):
        for x in (0.32, 0.88):
            add(M.cylinder(f"lockbar_{sx}_{x}", 0.022, hz - 0.08, (sx * x, -0.05, (1.2 + top) / 2 - 0.02), m["chrome"], axis="Z", seg=10))
            add(M.box(f"lockhandle_{sx}_{x}", (0.06, 0.05, 0.22), (sx * (x + 0.05), -0.085, 1.75), m["chrome"], bevel=0.015, seg=1))
            for z in (1.3, top - 0.25):
                add(M.box(f"lockcam_{sx}_{x}_{z}", (0.07, 0.05, 0.08), (sx * x, -0.05, z), m["steel"], bevel=0.01, seg=1))
        for z in (1.45, (1.2 + top) / 2, top - 0.35):
            add(M.cylinder(f"hinge_{sx}_{z:.2f}", 0.04, 0.2, (sx * (W2 - 0.02), -0.06, z), m["steel"], axis="Z", seg=10))
            add(M.box(f"hinge_leaf_{sx}_{z:.2f}", (0.32, 0.02, 0.1), (sx * (W2 - 0.18), -0.045, z), m["steel"], bevel=0.005, seg=1))


def _side_door(m, add, top):
    """Porta lateral de baú (só no lado direito, como no caminhão de referência): vincos, dobradiças, trava."""
    y0, y1, z0, z1 = 5.55, 6.85, 1.24, top - 0.16
    seams = [("sd_seam_b", (y0, (z0 + z1) / 2), (0.025, 0.012, z1 - z0)), ("sd_seam_f", (y1, (z0 + z1) / 2), (0.025, 0.012, z1 - z0)),
             ("sd_seam_t", ((y0 + y1) / 2, z1), (y1 - y0, 0.012, 0.025)), ("sd_seam_m", ((y0 + y1) / 2, z0), (y1 - y0, 0.012, 0.025))]
    for name, (y, z), (ly, _, lz) in seams:
        add(M.box(name, (0.012, ly, lz), (W2 + 0.004, y, z), m["plastic"], bevel=0.0, seg=1))
    for z in (1.5, (z0 + z1) / 2, z1 - 0.25):
        add(M.cylinder(f"sd_hinge_{z:.2f}", 0.035, 0.18, (W2 + 0.03, y1 - 0.02, z), m["steel"], axis="Z", seg=10))
    add(M.cylinder("sd_lockbar", 0.02, z1 - z0 - 0.1, (W2 + 0.04, y0 + 0.15, (z0 + z1) / 2), m["chrome"], axis="Z", seg=10))
    add(M.box("sd_handle", (0.05, 0.2, 0.06), (W2 + 0.06, y0 + 0.25, 1.8), m["chrome"], bevel=0.015, seg=1))


def build_alubox(m, add):
    """1) Baú de alumínio reto e liso (cinza-claro), porta lateral e traseira de duas folhas."""
    top = 3.45
    _box_shell(m, add, m["box_alu"], top, m["steel"])
    for sx in (-1, 1):                                          # juntas finas entre as chapas do alumínio
        for y in (1.37, 2.73, 4.1, 5.47, 6.83):
            if sx > 0 and 5.5 < y < 6.9:
                continue
            add(M.box(f"panel_seam_{sx}_{y}", (0.008, 0.012, top - 1.32), (sx * (W2 + 0.003), y, (1.2 + top) / 2), m["steel"], bevel=0.0, seg=1))
    _side_door(m, add, top)
    _rear_doors(m, add, top, m["steel"])
    rear_end(m, add)
    _side_markers(m, add, 1.25)
    box = BoxDims(l=L, top=top)
    return {"top": top, "box": box, "mounts": _box_mounts(box), "deco": "brow", "drop_stacks": True}


def build_pinkbox(m, add, mural_mat):
    """3) Baú rosa com mural grande (arte nossa: gueixa, ondas, sakura; trocado no jogo pelo PNG do modelo) e a
    decoração Dekotora completa (fileiras de luzes, andons)."""
    top = 3.45
    _box_shell(m, add, m["box_pink"], top, m["chrome"])
    _rear_doors(m, add, top, m["chrome"])
    rear_end(m, add)
    zm0, zm1 = 1.22, top - 0.14
    for sx in (-1, 1):                                          # mural grande: quase a parede inteira
        o = M.box(f"mural_{sx}", (0.01, L - 0.3, zm1 - zm0), (sx * (W2 + 0.012), L / 2, (zm0 + zm1) / 2), mural_mat, bevel=0.0, seg=1)
        M.uv_planar(o)
        if sx < 0:                                              # lado esquerdo: espelha a UV para ler igual (kanji certo)
            for d in o.data.uv_layers.active.data:
                d.uv = (1.0 - d.uv[0], d.uv[1])
        add(o)
        for z in (zm0 - 0.03, zm1 + 0.03):                      # molduras cromadas do mural
            add(M.box(f"mural_frame_{sx}_{z:.2f}", (0.03, L - 0.26, 0.04), (sx * (W2 + 0.02), L / 2, z), m["chrome"], bevel=0.01, seg=1))
    box = BoxDims(l=L, top=top)
    return {"top": top, "box": box, "mounts": _box_mounts(box), "deco": "full"}


def _box_mounts(b: BoxDims) -> dict:
    return {"MOUNT_BODY_ROOF": (0.0, b.l / 2, b.top), "MOUNT_REAR_ROOF": (0.0, 0.0, b.top)}


# ----------------------------------------------------------------------------- lona

def build_tarp(m, add):
    """2) Plataforma com guardas de alumínio (faixa com o nome da empresa fictícia), cabeceira cromada e lona
    verde-azulada esticada sobre arcos, com cordas cruzadas."""
    z_deck = 1.22
    add(M.box("deck_sill", (2.42, L, 0.12), (0, L / 2, 1.04), m["steel"], bevel=0.02, seg=1))
    add(M.box("deck", (2 * W2, L, 0.1), (0, L / 2, z_deck - 0.05), m["plastic_trim"], bevel=0.02, seg=1))
    gate_top = 1.66
    for sx in (-1, 1):
        add(M.box(f"gate_{sx}", (0.04, L - 0.04, gate_top - z_deck), (sx * (W2 - 0.02), L / 2, (z_deck + gate_top) / 2), m["box_alu"],
                  bevel=0.01, seg=1))
        for z in (z_deck + 0.04, gate_top - 0.03):
            add(M.box(f"gate_rib_{sx}_{z:.2f}", (0.03, L - 0.04, 0.04), (sx * (W2 + 0.005), L / 2, z), m["steel"], bevel=0.008, seg=1))
        for y in (0.06, 2.05, 4.1, 6.15, L - 0.06):
            add(M.box(f"gate_post_{sx}_{y}", (0.06, 0.08, gate_top - z_deck + 0.08), (sx * (W2 + 0.01), y, (z_deck + gate_top) / 2),
                      m["steel"], bevel=0.01, seg=1))
            add(M.box(f"gate_latch_{sx}_{y}", (0.04, 0.06, 0.1), (sx * (W2 + 0.04), y, gate_top - 0.12), m["chrome"], bevel=0.01, seg=1))
        # faixa branca com o nome da empresa (kanji, nunca espelhado) e filete vermelho
        add(M.box(f"band_{sx}", (0.006, 1.86, 0.34), (sx * (W2 + 0.006), 3.075, 1.45), m["band_white"], bevel=0.0, seg=1))
        add(M.box(f"band_line_{sx}", (0.006, 1.86, 0.03), (sx * (W2 + 0.008), 3.075, 1.265), m["paint_red"], bevel=0.0, seg=1))
        _text_side(m, add, "company", COMPANY, 0.5, 3.075, 1.45, sx, m["paint_blue"], x_off=0.011)
    # cabeceira (frente) cromada e grade traseira
    add(M.box("headboard", (2 * W2, 0.06, 3.28 - z_deck), (0, L - 0.05, (z_deck + 3.28) / 2), m["mesh_perf"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        add(M.box(f"headboard_post_{sx}", (0.1, 0.1, 3.36 - z_deck), (sx * (W2 - 0.05), L - 0.05, (z_deck + 3.36) / 2), m["chrome"], bevel=0.02, seg=1))
    add(M.box("headboard_top", (2 * W2 + 0.1, 0.12, 0.1), (0, L - 0.05, 3.36), m["chrome"], bevel=0.02, seg=1))
    add(M.box("rear_gate", (2 * W2, 0.04, gate_top - z_deck), (0, 0.02, (z_deck + gate_top) / 2), m["box_alu"], bevel=0.01, seg=1))
    # lona: casca com quinas de cima arredondadas, de cima das guardas até 3,2 m
    t0, t1 = gate_top - 0.06, 3.2
    rings = []
    for z, din in ((t0, 0.0), (t0 + 0.05, 0.0), (2.4, 0.0), (t1 - 0.1, 0.005), (t1 - 0.03, 0.03), (t1, 0.08)):
        rings.append(_ring_y(W2 - 0.02 - din, 0.08 + din * 0.4, L - 0.12 - din * 0.4, z, 0.06))
    from lib import mesh_adv as A
    add(A.loft("tarp", rings, m["tarp"]))
    # arcos da lona (faixas levemente salientes), cordas cruzadas nas laterais e na traseira
    for y in (0.6, 1.95, 3.3, 4.65, 6.0, 7.35):
        pts = [(-W2 - 0.005, y, t0 + 0.02), (-W2 - 0.005, y, t1 - 0.08), (-W2 + 0.1, y, t1 + 0.012), (W2 - 0.1, y, t1 + 0.012),
               (W2 + 0.005, y, t1 - 0.08), (W2 + 0.005, y, t0 + 0.02)]
        add(M.tube(f"tarp_bow_{y}", pts, 0.022, m["tarp_dark"], seg=6))
    hooks = [0.25 + i * (L - 0.5) / 6 for i in range(7)]
    for sx in (-1, 1):
        x = sx * (W2 + 0.012)
        for a, b in zip(hooks[:-1], hooks[1:]):
            add(M.tube(f"rope_{sx}_{a:.2f}_1", [(x, a, t0 + 0.03), (x, b, t1 - 0.12)], 0.011, m["rope"], seg=5))
            add(M.tube(f"rope_{sx}_{a:.2f}_2", [(x, b, t0 + 0.03), (x, a, t1 - 0.12)], 0.011, m["rope"], seg=5))
        for y in hooks:
            add(M.box(f"rope_hook_{sx}_{y:.2f}", (0.04, 0.05, 0.05), (sx * (W2 + 0.02), y, t0 + 0.0), m["chrome"], bevel=0.01, seg=1))
    for xa, xb in ((-1.1, 0.0), (0.0, 1.1), (-1.1, 1.1)):
        add(M.tube(f"rope_rear_{xa}_{xb}", [(xa, 0.065, t0 + 0.03), (xb, 0.065, t1 - 0.12)], 0.011, m["rope"], seg=5))
        add(M.tube(f"rope_rear_b_{xa}_{xb}", [(xb, 0.065, t0 + 0.03), (xa, 0.065, t1 - 0.12)], 0.011, m["rope"], seg=5))
    rear_end(m, add)
    guard_lamps(m, add)
    rear_frame_lamps(m, add, 0.0, 1.3, 1.62, W2 - 0.12)
    return {"top": t1, "mounts": {"MOUNT_BODY_ROOF": (0.0, L / 2, t1), "MOUNT_REAR_ROOF": (0.0, 0.0, t1)}, "deco": "brow"}


def _ring_y(hw, y0, y1, z, r, n=3):
    from lib import mesh_adv as A
    return A.rounded_rect_ring(hw, y0, y1, z, r, r, n=n)


# ----------------------------------------------------------------------------- tanque

def _ellipse_tube(name, ys_scales, a, b, zc, mat, seg=32, cap=True):
    """Casca elíptica ao longo de Y: anéis (y, escala) com semi-eixos a (x) e b (z)."""
    bm = bmesh.new()
    rings = []
    for y, s in ys_scales:
        ring = []
        for i in range(seg):
            t = math.tau * i / seg
            ring.append(bm.verts.new((a * s * math.cos(t), y, zc + b * s * math.sin(t))))
        rings.append(ring)
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    if cap:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def build_tanker(m, add):
    """4a) Tanque elíptico cromado com tampos abaulados, cintas, passarela com corrimão, bocas de visita, escada
    traseira, caixa de válvulas e mangueiras."""
    a, b, zc = 1.18, 0.8, 2.08
    y0, y1 = 0.22, 7.98
    prof = [(y0, 0.5), (y0 + 0.06, 0.8), (y0 + 0.16, 0.95), (y0 + 0.3, 1.0), (y1 - 0.3, 1.0), (y1 - 0.16, 0.95), (y1 - 0.06, 0.8), (y1, 0.5)]
    add(_ellipse_tube("tank", prof, a, b, zc, m["tank_shell"], seg=36))
    for y in (0.75, 2.6, 4.45, 6.3, 7.45):                      # cintas (anéis) do tanque
        add(_ellipse_tube(f"tank_band_{y}", [(y - 0.04, 1.012), (y + 0.04, 1.012)], a, b, zc, m["chrome"], seg=36, cap=False))
    for y in (1.0, 4.1, 7.2):                                   # berços (selas) sobre o chassi
        add(M.box(f"saddle_{y}", (1.7, 0.16, 0.36), (0, y, 1.26), m["steel"], bevel=0.03, seg=1))
    add(M.box("tank_sill", (1.2, L - 0.4, 0.12), (0, L / 2, 1.04), m["steel"], bevel=0.02, seg=1))
    ztop = zc + b
    add(M.box("walkway", (0.56, 7.0, 0.04), (0, 4.1, ztop + 0.08), m["diamond"], bevel=0.01, seg=1))
    for y in (1.0, 2.8, 4.6, 6.4, 7.5):
        add(M.box(f"walk_post_{y}", (0.4, 0.06, 0.1), (0, y, ztop + 0.03), m["steel"], bevel=0.01, seg=1))
    for k, y in enumerate((1.8, 4.1, 6.4)):                     # bocas de visita
        add(M.cylinder(f"manhole_{k}", 0.27, 0.12, (0, y, ztop + 0.12), m["chrome"], axis="Z", seg=20, bevel=0.02))
        add(M.cylinder(f"manhole_lid_{k}", 0.2, 0.04, (0, y, ztop + 0.2), m["steel"], axis="Z", seg=16))
    for sx in (-1, 1):                                          # corrimão rebatível
        rail = [(sx * 0.42, 0.9, ztop + 0.1), (sx * 0.45, 0.9, ztop + 0.5), (sx * 0.45, 7.3, ztop + 0.5), (sx * 0.42, 7.3, ztop + 0.1)]
        add(M.tube(f"handrail_{sx}", rail, 0.022, m["chrome"], seg=8))
        for y in (2.5, 4.1, 5.7):
            add(M.tube(f"handrail_post_{sx}_{y}", [(sx * 0.43, y, ztop + 0.1), (sx * 0.45, y, ztop + 0.5)], 0.018, m["chrome"], seg=6))
    for x in (-0.25, 0.25):                                     # escada traseira
        add(M.tube(f"ladder_rail_{x}", [(x, -0.02, 1.1), (x, 0.0, ztop - 0.25), (x, 0.3, ztop + 0.08)], 0.022, m["chrome"], seg=8))
    for i in range(6):
        add(M.cylinder(f"ladder_rung_{i}", 0.018, 0.5, (0, -0.02 + i * 0.004, 1.3 + i * 0.27), m["chrome"], axis="X", seg=8))
    add(M.box("valve_box", (1.5, 0.7, 0.42), (0, 0.55, 0.95), m["steel"], bevel=0.03))
    for k, x in enumerate((-0.45, 0.0, 0.45)):
        add(M.cylinder(f"valve_{k}", 0.07, 0.25, (x, 0.12, 0.95), m["chrome"], axis="Y", seg=12))
        add(M.cylinder(f"valve_cap_{k}", 0.09, 0.04, (x, -0.02, 0.95), m["lamp_red" if k == 1 else "steel"], axis="Y", seg=12))
    for sx in (-1, 1):                                          # porta-mangueira lateral (tubo)
        add(M.cylinder(f"hose_tube_{sx}", 0.13, 3.6, (sx * 0.98, 4.6, 1.12), m["chrome"], axis="Y", seg=14))
        add(M.cylinder(f"hose_cap_{sx}", 0.15, 0.06, (sx * 0.98, 2.8, 1.12), m["steel"], axis="Y", seg=14))
    rear_end(m, add)
    guard_lamps(m, add)
    rear_frame_lamps(m, add, y0 + 0.02, 1.4, 2.6, 0.7)
    return {"top": ztop + 0.22, "mounts": {"MOUNT_BODY_ROOF": (0.0, L / 2, ztop + 0.1), "MOUNT_REAR_ROOF": (0.0, 0.0, ztop),
                                            "MOUNT_SIDE_PANEL_R": (a, 4.1, zc), "MOUNT_SIDE_PANEL_L": (-a, 4.1, zc)}, "deco": "brow"}


# ----------------------------------------------------------------------------- caçamba

def build_dump(m, add):
    """4b) Caçamba basculante de inox (laterais com nervuras, protetor de cabine na frente), estrutura traseira
    polida (moldura, braços da tampa, barra de luzes), cilindro hidráulico e protetores perfurados cromados nos
    escapamentos verticais."""
    y0, y1 = 0.35, 6.55
    zf, zt = 1.36, 2.42
    add(M.box("dump_subframe", (1.3, y1 - y0 + 0.2, 0.2), (0, (y0 + y1) / 2, 1.18), m["steel"], bevel=0.02, seg=1))
    add(M.box("dump_floor", (2 * W2 - 0.06, y1 - y0, 0.08), (0, (y0 + y1) / 2, zf), m["dump_bed"], bevel=0.02, seg=1))
    for sx in (-1, 1):
        add(M.box(f"dump_side_{sx}", (0.05, y1 - y0, zt - zf), (sx * (W2 - 0.03), (y0 + y1) / 2, (zf + zt) / 2), m["dump_bed"], bevel=0.015, seg=1))
        for i in range(10):                                     # nervuras verticais
            y = y0 + 0.3 + i * (y1 - y0 - 0.6) / 9
            add(M.box(f"dump_rib_{sx}_{i}", (0.05, 0.07, zt - zf - 0.08), (sx * (W2 + 0.01), y, (zf + zt) / 2), m["dump_bed"], bevel=0.012, seg=1))
        add(M.box(f"dump_toprail_{sx}", (0.1, y1 - y0 + 0.1, 0.08), (sx * (W2 - 0.01), (y0 + y1) / 2, zt + 0.03), m["chrome"], bevel=0.02, seg=1))
        add(M.box(f"dump_botrail_{sx}", (0.08, y1 - y0 + 0.1, 0.1), (sx * (W2 + 0.0), (y0 + y1) / 2, zf - 0.02), m["chrome"], bevel=0.02, seg=1))
    # parede da frente mais alta + protetor de cabine (aba que avança sobre o vão)
    add(M.box("dump_front", (2 * W2, 0.08, 3.05 - zf), (0, y1, (zf + 3.05) / 2), m["dump_bed"], bevel=0.015, seg=1))
    add(M.box("dump_protector", (2 * W2 + 0.04, 0.9, 0.06), (0, y1 + 0.42, 3.08), m["chrome"], bevel=0.02, seg=1))
    for sx in (-1, 1):
        add(M.box(f"dump_protector_brace_{sx}", (0.06, 0.8, 0.06), (sx * (W2 - 0.1), y1 + 0.35, 2.85), m["chrome"], bevel=0.015, seg=1,
                  rot=(30, 0, 0)))
    for i in range(6):
        add(M.box(f"dump_front_rib_{i}", (0.06, 0.05, 3.0 - zf - 0.1), (-1.0 + i * 0.4, y1 + 0.05, (zf + 3.0) / 2), m["chrome"], bevel=0.012, seg=1))
    # tampa traseira com moldura polida e braços da articulação
    add(M.box("tailgate", (2 * W2 - 0.04, 0.07, zt - zf + 0.04), (0, y0 - 0.04, (zf + zt) / 2), m["dump_bed"], bevel=0.015, seg=1))
    add(M.box("tailgate_frame_top", (2 * W2 + 0.06, 0.1, 0.1), (0, y0 - 0.08, zt + 0.06), m["chrome"], bevel=0.02, seg=1))
    for sx in (-1, 1):
        add(M.box(f"rear_pillar_{sx}", (0.12, 0.12, zt - zf + 0.3), (sx * (W2 - 0.02), y0 - 0.08, (zf + zt) / 2 + 0.1), m["chrome"], bevel=0.02, seg=1))
        add(M.tube(f"tailgate_arm_{sx}", [(sx * (W2 + 0.03), y0 + 0.5, zt + 0.06), (sx * (W2 + 0.04), y0 + 0.1, zt + 0.25),
                                           (sx * (W2 + 0.03), y0 - 0.06, zt + 0.06)], 0.03, m["chrome"], seg=8))
        add(M.box(f"tailgate_latch_{sx}", (0.1, 0.1, 0.16), (sx * (W2 - 0.2), y0 - 0.1, zf + 0.04), m["chrome"], bevel=0.02, seg=1))
    for k in range(5):                                          # frisos polidos na tampa
        add(M.box(f"tailgate_bar_{k}", (2 * W2 - 0.3, 0.03, 0.05), (0, y0 - 0.085, zf + 0.15 + k * 0.2), m["chrome"], bevel=0.01, seg=1))
    # estrutura traseira polida embaixo da caçamba: quadro e barra de luzes
    add(M.box("rear_struct_beam", (2.2, 0.12, 0.12), (0, 0.18, 1.1), m["chrome"], bevel=0.03))
    for sx in (-1, 1):
        add(M.box(f"rear_struct_leg_{sx}", (0.1, 0.1, 0.5), (sx * 0.95, 0.12, 0.9), m["chrome"], bevel=0.02))
        add(M.tube(f"rear_struct_diag_{sx}", [(sx * 0.95, 0.2, 0.7), (sx * 0.4, 0.6, 1.08)], 0.03, m["chrome"], seg=8))
    # cilindro hidráulico (basculante de frente) e dobradiça traseira
    add(M.cylinder("dump_ram", 0.11, 1.3, (0, y1 + 0.32, 1.5), m["chrome"], axis="Z", seg=16))
    add(M.cylinder("dump_ram_base", 0.16, 0.3, (0, y1 + 0.32, 0.95), m["steel"], axis="Z", seg=16))
    add(M.cylinder("dump_hinge", 0.06, 1.4, (0, y0 + 0.1, 1.2), m["steel"], axis="X", seg=12))
    rear_end(m, add)
    guard_lamps(m, add)
    rear_frame_lamps(m, add, y0 - 0.14, zf + 0.1, zt - 0.05, W2 - 0.12)
    return {"top": zt, "mounts": {"MOUNT_BODY_ROOF": (0.0, (y0 + y1) / 2, zt), "MOUNT_REAR_ROOF": (0.0, 0.0, zt)}, "deco": "brow",
            "stack_guards": True}


def stack_guards(m, add, y=8.3, x=1.3):
    """Protetor perfurado cromado em volta do escapamento vertical (meia-cana do lado de fora) + ponta cortada."""
    for sx in (-1, 1):
        c = M.cylinder(f"stack_guard_{sx}", 0.16, 1.3, (sx * x, y, 2.1), m["mesh_perf"], axis="Z", seg=16)
        add(c)
        for z in (1.45, 2.75):
            add(M.cylinder(f"stack_guard_ring_{sx}_{z}", 0.17, 0.05, (sx * x, y, z), m["chrome"], axis="Z", seg=16))
        add(M.cylinder(f"stack_tip_{sx}", 0.125, 0.3, (sx * x, y, 3.6), m["chrome"], axis="Z", seg=16))


BUILDERS = {"alubox": build_alubox, "tarp": build_tarp, "pinkbox": build_pinkbox, "tanker": build_tanker, "dump": build_dump}
