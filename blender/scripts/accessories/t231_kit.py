"""Kit de geometria da T-231 (traseira, foguete e contorno do baú): lanternas com lente (redonda, quadrada, alvo, bala,
torpedo), caixa da placa, caixa de degrau e materiais novos.

Materiais (além dos papéis da T-211, `t211_kit.materials`):
  lamp_tail   lanterna vermelha de verdade (não muda com a cor L/R; acende à noite, fica vermelho-escuro de dia)
  deco_plate  fundo branco da caixa da placa (o jogo põe a placa do caminhão em cima dele)
As lentes têm UV 0..1 na frente (o shader das luzes desenha a lente: centro forte, borda mais escura).
Convenção (Blender): +Y frente, +X direita, +Z cima, metros.
"""
from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from lib import mesh3d as M

from . import t211_kit as K


def materials(atlas=None) -> dict:
    m = K.materials(atlas)
    m["tail"] = K._mat("lamp_tail", "#ff2a2a", 0.0, 0.35, 2.5)
    m["plate"] = K._mat("deco_plate", "#e9eef5", 0.0, 0.5)
    return m


def _ring(bm, c, u, v, r_u, r_v, seg):
    return [bm.verts.new(c + (u * math.cos(2 * math.pi * k / seg) * r_u + v * math.sin(2 * math.pi * k / seg) * r_v))
            for k in range(seg)]


def lens_disc(bm, uvl, c, u, v, n, r, depth, seg=12, dome=0.25, stretch=1.0):
    """Lente redonda (ou oval: `stretch` > 1 alonga em v) saindo da face: anel de trás, anel da frente e um centro um
    pouco abaulado. UV 0..1 na frente (centro = 0,5)."""
    back = _ring(bm, c, u, v, r, r * stretch, seg)
    front = _ring(bm, c + n * depth, u, v, r * 0.92, r * 0.92 * stretch, seg)
    mid = bm.verts.new(c + n * (depth + r * dome * 0.4))
    for k in range(seg):
        k1 = (k + 1) % seg
        f = bm.faces.new([back[k], back[k1], front[k1], front[k]])
        for lp in f.loops:
            lp[uvl].uv = (0.5, 0.02)
    for k in range(seg):
        k1 = (k + 1) % seg
        f = bm.faces.new([front[k], front[k1], mid])
        a0, a1 = 2 * math.pi * k / seg, 2 * math.pi * k1 / seg
        for lp, uv in zip(f.loops, ((0.5 + 0.5 * math.cos(a0), 0.5 + 0.5 * math.sin(a0)),
                                    (0.5 + 0.5 * math.cos(a1), 0.5 + 0.5 * math.sin(a1)), (0.5, 0.5))):
            lp[uvl].uv = uv


def ring_tube(bm, c, u, v, n, r0, r1, depth, seg=12, stretch=1.0):
    """Aro (anel com espessura) de raio interno r0 e externo r1, saindo `depth` da face."""
    o0 = _ring(bm, c, u, v, r1, r1 * stretch, seg)
    o1 = _ring(bm, c + n * depth, u, v, r1, r1 * stretch, seg)
    i1 = _ring(bm, c + n * depth, u, v, r0, r0 * stretch, seg)
    i0 = _ring(bm, c + n * (depth * 0.3), u, v, r0, r0 * stretch, seg)
    for k in range(seg):
        k1 = (k + 1) % seg
        bm.faces.new([o0[k], o0[k1], o1[k1], o1[k]])
        bm.faces.new([o1[k], o1[k1], i1[k1], i1[k]])
        bm.faces.new([i1[k], i1[k1], i0[k1], i0[k]])


def round_lamps(name, face: K.Face, pts, r, m, seg=12, rim=True, depth=0.03, stretch=1.0, tilt=None, lens_mat=None):
    """Lanternas redondas nos pontos (s, t) da face: aro cromado + lente com UV. `tilt(s, t)` -> ângulo (rad) para
    girar a lente no plano da face (lanternas em leque). Devolve [lentes, aros]."""
    lens_bm, rim_bm = bmesh.new(), bmesh.new()
    uvl = lens_bm.loops.layers.uv.new("UVMap")
    U, V, N = face.u.normalized(), face.v.normalized(), face.n
    for (s, t) in pts:
        u, v = U, V
        if tilt is not None:
            a = tilt(s, t)
            u, v = U * math.cos(a) + V * math.sin(a), -U * math.sin(a) + V * math.cos(a)
        c = face.at(s, t, 0.004)
        if rim:
            ring_tube(rim_bm, c, u, v, N, r * 0.98, r * 1.22, depth * 0.8, seg, stretch)
        lens_disc(lens_bm, uvl, c, u, v, N, r, depth, seg, stretch=stretch)
    out = [M._link(name + "_lens", lens_bm, lens_mat or m["tail"])]
    if rim:                                   # (sem recalc: casca aberta, a ordem dos vértices já aponta para fora)
        out.append(M._link(name + "_rim", rim_bm, m["chrome"]))
    else:
        rim_bm.free()
    return out


def target_lamps(name, face: K.Face, pts, r, m, seg=14):
    """Lanterna "alvo": aro cromado largo, lente vermelha, anel cromado no meio e ponto vermelho no centro."""
    lens_bm, rim_bm = bmesh.new(), bmesh.new()
    uvl = lens_bm.loops.layers.uv.new("UVMap")
    U, V, N = face.u.normalized(), face.v.normalized(), face.n
    for (s, t) in pts:
        c = face.at(s, t, 0.004)
        ring_tube(rim_bm, c, U, V, N, r * 0.98, r * 1.30, 0.03, seg)
        lens_disc(lens_bm, uvl, c, U, V, N, r, 0.025, seg)
        ring_tube(rim_bm, c + N * 0.024, U, V, N, r * 0.42, r * 0.56, 0.018, seg)
        lens_disc(lens_bm, uvl, c + N * 0.024, U, V, N, r * 0.40, 0.022, seg, dome=0.5)
    return [M._link(name + "_lens", lens_bm, m["tail"]), M._link(name + "_rim", rim_bm, m["chrome"])]


def square_lamps(name, face: K.Face, s0, t0, s1, t1, cols, rows, m, fill=0.80, depth=0.03, frame=True, skip=None,
                 lens_mat=None):
    """Grade de lanternas quadradas (lente com UV 0..1, como os LEDs) com moldura cromada em cada uma."""
    out = [K.led_grid(name + "_lens", face, s0, t0, s1, t1, cols, rows, lens_mat or m["tail"], fill=fill, off=0.006 + depth,
                      depth=depth, skip=skip)]
    if frame:
        W, Hh = face.u.length, face.v.length
        du, dv = (s1 - s0) / cols, (t1 - t0) / rows
        bars = []
        for r in range(rows):
            for c in range(cols):
                if skip and skip(c, r):
                    continue
                sc, tc = s0 + du * (c + 0.5), t0 + dv * (r + 0.5)
                hu, hv = du * min(0.98, fill + 0.12) / 2, dv * min(0.98, fill + 0.12) / 2
                bars += K.frame_on(f"{name}_fr_{c}_{r}", face, sc - hu + 0.012 / W, tc - hv + 0.012 / Hh, sc + hu - 0.012 / W,
                                   tc + hv - 0.012 / Hh, 0.012 / W, 0.012 / Hh, m["chrome"], off=0.004, depth=depth * 0.7)
        out += bars
    return out


def plate_box(name, face: K.Face, s0, t0, s1, t1, m, neon=False, bezel=0.035):
    """Caixa da placa: moldura no papel "painel" (azul-marinho/preto), fundo branco `deco_plate` um pouco para dentro
    (o jogo põe a placa do caminhão em cima, ver TruckPlateSpots) e a capa cromada da lâmpada da placa em cima."""
    W, Hh = face.u.length, face.v.length
    bs, bt = bezel / W, bezel / Hh
    out = [K.quad_panel(name + "_back", face, s0, t0, s1, t1, m["trim"], off=0.010, depth=0.012),
           K.quad_panel(name + "_plate", face, s0 + bs, t0 + bt, s1 - bs, t1 - bt * 1.4, m["plate"], off=0.024, depth=0.012)]
    out += K.frame_on(name + "_fr", face, s0 + bs * 0.4, t0 + bt * 0.4, s1 - bs * 0.4, t1 - bt * 0.4, bs * 0.4, bt * 0.4,
                      m["neon"] if neon else m["chrome"], off=0.012, depth=0.02)
    out.append(K.bar_on(name + "_hood", face, (s0 + s1) / 2 - 0.06 / W, t1 - bt * 1.25, (s0 + s1) / 2 + 0.06 / W, t1 - bt * 0.6,
                        m["chrome"], off=0.026, depth=0.014))           # capa da lâmpada da placa
    out.append(K.bolts(name + "_bolts", face, [(s0 + bs * 1.6, t1 - bt * 2.0), (s1 - bs * 1.6, t1 - bt * 2.0)], m["chrome"],
                       r=0.009, off=0.036))
    return out


def step_box(name, face: K.Face, s0, t0, s1, t1, m, slats=5):
    """Caixa de degrau/grade na ponta (as capturas têm uma caixa clara com fendas de um lado): moldura cromada e lâminas."""
    W, Hh = face.u.length, face.v.length
    out = [K.quad_panel(name + "_back", face, s0, t0, s1, t1, m["trim"], off=0.010, depth=0.012)]
    out += K.frame_on(name + "_fr", face, s0, t0, s1, t1, 0.018 / W, 0.018 / Hh, m["chrome"], off=0.01, depth=0.022)
    for k in range(slats):
        t = t0 + (t1 - t0) * (k + 0.6) / (slats + 0.4)
        out.append(K.bar_on(f"{name}_slat_{k}", face, s0 + 0.03 / W, t - 0.012 / Hh, s1 - 0.03 / W, t + 0.012 / Hh, m["chrome"],
                            off=0.012, depth=0.016))
    return out


def chrome_bar(name, x0, x1, y, z, r, m, seg=10):
    """Barra cromada redonda ao longo de X (tubo do para-choque), com tampas."""
    return M.cylinder(name, r, x1 - x0, ((x0 + x1) / 2, y, z), m["chrome"], axis="X", seg=seg, bevel=0.004, bevel_seg=1)


def end_caps(name, face: K.Face, m, mat, t0=0.06, t1=0.94, w=0.014):
    """Barras verticais de neon nas 2 pontas (capturas 066/068)."""
    W = face.u.length
    return [K.bar_on(f"{name}_l", face, 0.004, t0, 0.004 + w / W * 1.0, t1, mat, off=0.004, depth=0.012),
            K.bar_on(f"{name}_r", face, 0.996 - w / W, t0, 0.996, t1, mat, off=0.004, depth=0.012)]


def grid_pts(s0, s1, t0, t1, cols, rows):
    return [(s0 + (s1 - s0) * (c + 0.5) / cols, t0 + (t1 - t0) * (r + 0.5) / rows) for r in range(rows) for c in range(cols)]
