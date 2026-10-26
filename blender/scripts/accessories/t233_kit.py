"""Kit de geometria da T-233 (para-choque da frente, retrovisor, escada e saias): prisma em leque, tubos leves (sem
esferas nas juntas), treliça, seta (ponto SIGNAL_*), cabeça de espelho e materiais novos.

Materiais (além dos papéis da T-211, `t211_kit.materials`, e da lanterna/placa da T-231, `t231_kit.materials`):
  deco_signal   lente da seta da frente (âmbar escuro; o jogo põe a seta que pisca em cima dela, ponto SIGNAL_L/R)
  deco_checker  chapa xadrez (o jogo põe a textura de chapa xadrez que já existe, tex_diamond_plate)
  deco_mirror   vidro do espelho (reflexo escuro)
  lamp_amber    lâmpadas âmbar (luzinhas de fábrica: acendem à noite e seguem o padrão de pisca)
  paint_gold    caixas douradas
Convenção (Blender): +Y frente, +X direita, +Z cima, metros. Grupos de objetos pelo prefixo do nome (TOP_, MID_, BOT_,
CEN_, HEAD_, TAIL_): o jogo estica/repete o grupo MID_ (`game/scripts/truck/frame_fit.gd`).
"""
from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Vector

from lib import mesh3d as M

from . import t211_kit as K
from . import t231_kit as T


def materials(atlas=None) -> dict:
    m = T.materials(atlas)
    m["signal"] = K._mat("deco_signal", "#8a4a10", 0.0, 0.3)
    m["checker"] = K._mat("deco_checker", "#9aa3b2", 0.85, 0.35)
    m["mirror"] = K._mat("deco_mirror", "#2a3442", 0.9, 0.05)
    m["amber"] = K._mat("lamp_amber", "#ffb347", 0.0, 0.35, 2.5)
    m["gold"] = K._mat("paint_gold", "#f0b83a", 1.0, 0.22)
    m["pink"] = K._mat("paint_pink", "#ff2e88", 0.35, 0.32)
    return m


def tag(objs, group):
    for ob in objs:
        ob.name = group + "_" + ob.name
    return objs


# ----------------------------------------------------------------------------- prisma (planta) e faces

def prism(name, poly, z0, z1, mat, top=True, bottom=True):
    """Polígono da planta (x, y) no sentido anti-horário visto de cima, extrudado de z0 a z1. `top`/`bottom` = tampas
    (as fatias do meio de uma peça empilhada ficam sem tampa: nunca aparecem)."""
    bm = bmesh.new()
    a = [bm.verts.new((x, y, z0)) for x, y in poly]
    b = [bm.verts.new((x, y, z1)) for x, y in poly]
    n = len(poly)
    for k in range(n):
        bm.faces.new([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
    if bottom:
        bm.faces.new(list(reversed(a)))
    if top:
        bm.faces.new(b)
    return M._link(name, bm, mat)


def fan_poly(W, D, De, c):
    """Planta em leque: costas retas (y = 0), frente com o meio reto (|x| <= c, y = D) e as asas recuando até
    y = De nas pontas."""
    return [(-W / 2, 0.0), (W / 2, 0.0), (W / 2, De), (c, D), (-c, D), (-W / 2, De)]


def box_poly(W, D, ch):
    """Planta retangular com as quinas da frente chanfradas `ch`."""
    return [(-W / 2, 0.0), (W / 2, 0.0), (W / 2, D - ch), (W / 2 - ch, D), (-W / 2 + ch, D), (-W / 2, D - ch)]


def fan_faces(W, D, De, c, z0, z1):
    """Faces da frente do leque entre z0 e z1: asa direita (+X), meio e asa esquerda. Quem olha de frente vê o +X à
    esquerda: u vai do +X para o -X (letreiro/desenho nunca espelhado)."""
    h = (0, 0, z1 - z0)
    right = K.Face((W / 2, De, z0), (c - W / 2, D - De, 0), h)
    mid = K.Face((c, D, z0), (-2 * c, 0, 0), h)
    left = K.Face((-c, D, z0), (-W / 2 + c, De - D, 0), h)
    return right, mid, left


# ----------------------------------------------------------------------------- tubos e treliça

def _tube_bm(bm, a, b, r, seg=6, ext=0.0, rect=None):
    """Tubo reto de a a b (sem tampas), estendido `ext` nas pontas (esconde a emenda nas juntas). `rect` = (w, h):
    seção retangular em vez de redonda."""
    va, vb = Vector(a), Vector(b)
    d = vb - va
    ln = d.length
    if ln < 1e-6:
        return
    d /= ln
    va, vb = va - d * ext, vb + d * ext
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = d.cross(up).normalized()
    v = u.cross(d).normalized()
    if rect:
        pts = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        ring = [u * (px * rect[0] / 2) + v * (py * rect[1] / 2) for px, py in pts]
    else:
        ring = [u * (math.cos(2 * math.pi * k / seg) * r) + v * (math.sin(2 * math.pi * k / seg) * r) for k in range(seg)]
    ra = [bm.verts.new(va + q) for q in ring]
    rb = [bm.verts.new(vb + q) for q in ring]
    n = len(ring)
    for k in range(n):
        bm.faces.new([ra[k], ra[(k + 1) % n], rb[(k + 1) % n], rb[k]])


def tubes(name, segs, r, mat, seg=6, ext=None, rect=None):
    """Vários tubos retos num objeto só. `segs` = [(a, b), ...]."""
    bm = bmesh.new()
    for a, b in segs:
        _tube_bm(bm, a, b, r, seg, r * 0.9 if ext is None else ext, rect)
    return M._link(name, bm, mat)


def path(points):
    """Pontos de uma polilinha -> segmentos."""
    return list(zip(points[:-1], points[1:]))


def truss(a0, a1, b0, b1, n):
    """Treliça entre duas barras paralelas (a0-a1 e b0-b1): as 2 barras + zigue-zague com n vãos."""
    A0, A1, B0, B1 = Vector(a0), Vector(a1), Vector(b0), Vector(b1)
    segs = [(a0, a1), (b0, b1)]
    for k in range(n):
        p = A0.lerp(A1, k / n)
        q = B0.lerp(B1, (k + 0.5) / n)
        p2 = A0.lerp(A1, (k + 1) / n)
        segs += [(tuple(p), tuple(q)), (tuple(q), tuple(p2))]
    return segs


def chain(a, b, w, n, plane_n):
    """Corrente vazada de losangos de a até b (largura w), no plano de normal `plane_n`."""
    A, B = Vector(a), Vector(b)
    d = (B - A)
    s = d.normalized().cross(Vector(plane_n)).normalized() * (w / 2)
    segs = []
    for k in range(n):
        p0 = A.lerp(B, k / n)
        p1 = A.lerp(B, (k + 1) / n)
        mid = (p0 + p1) / 2
        segs += [(tuple(p0), tuple(mid + s)), (tuple(mid + s), tuple(p1)), (tuple(p1), tuple(mid - s)), (tuple(mid - s), tuple(p0))]
    return segs


# ----------------------------------------------------------------------------- seta, espelho e lâmpadas

def signal(name, loc, size):
    """Ponto SIGNAL_L/SIGNAL_R: o jogo põe a seta que pisca aqui (o tamanho vai na escala do ponto)."""
    e = M.empty(name, loc, size=0.1)
    e.scale = size
    return e


def signal_lens(name, face: K.Face, s0, t0, s1, t1, m, off=0.004):
    """Lente da seta (âmbar escuro) em relevo na face; devolve (objetos, centro, tamanho) para o ponto SIGNAL."""
    W, Hh = face.u.length, face.v.length
    o = [K.quad_panel(name + "_back", face, s0, t0, s1, t1, m["chrome"], off=off, depth=0.008),
         K.quad_panel(name + "_lens", face, s0 + 0.01 / W, t0 + 0.012 / Hh, s1 - 0.01 / W, t1 - 0.012 / Hh, m["signal"],
                      off=off + 0.012, depth=0.010)]
    c = face.at((s0 + s1) / 2, (t0 + t1) / 2, off + 0.024)
    size = (abs(s1 - s0) * W * 0.9, 0.03, abs(t1 - t0) * Hh * 0.8)
    return o, c, size


def mirror_head(name, c, w, h, d, m, back_mat=None):
    """Cabeça do espelho: caixa (cor da peça) com o vidro virado para TRÁS (-Y) e aro cromado. `c` = centro."""
    cx, cy, cz = c
    out = [M.box(name + "_body", (w, d, h), (cx, cy, cz), back_mat or m["body"], bevel=min(0.02, d * 0.4), seg=1)]
    face = K.Face((cx + w / 2, cy - d / 2, cz - h / 2), (-w, 0, 0), (0, 0, h))      # normal -Y
    out.append(K.quad_panel(name + "_glass", face, 0.06, 0.05, 0.94, 0.95, m["mirror"], off=0.004, depth=0.004))
    out += K.frame_on(name + "_rim", face, 0.05, 0.04, 0.95, 0.96, 0.015 / w, 0.015 / h, m["chrome"], off=0.002, depth=0.012)
    return out


def round_amber(name, face: K.Face, pts, r, m, mat=None, seg=12, rim=True, depth=0.03):
    """Lâmpadas redondas âmbar (ou `mat`) com aro cromado, como as lanternas da T-231."""
    return T.round_lamps(name, face, pts, r, m, seg=seg, rim=rim, depth=depth, lens_mat=mat or m["amber"])


def square_amber(name, face: K.Face, s0, t0, s1, t1, cols, rows, m, mat=None, fill=0.8, frame=True):
    return T.square_lamps(name, face, s0, t0, s1, t1, cols, rows, m, fill=fill, frame=frame, lens_mat=mat or m["amber"])
