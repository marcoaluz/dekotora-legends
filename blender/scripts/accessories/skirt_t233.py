"""Saias laterais (para-choque lateral), 8 peças do catálogo da T-210 (capturas 086–094), T-233.

Uma por lado (a do lado esquerdo é espelhada no jogo), embaixo do baú, entre a roda da frente e a primeira de trás, só
nos trechos livres medidos por raios em cada caminhão (o tanque, a bateria e os degraus de fábrica ficam de fora: a
saia para antes deles e volta depois). Origem = encaixe "side_skirts_r": lado de FORA, logo embaixo do baú; a peça
cresce para DENTRO (-X), para BAIXO (-Z) e para a FRENTE (+Y). Vem em 3 grupos que o jogo monta em cada trecho
(`game/scripts/truck/frame_fit.gd`, fit "runs"):
  HEAD_  ponta de trás (y de 0 a HEAD);
  MID_   módulo de 0,50 m (y de HEAD a HEAD + MOD), repetido até o comprimento do trecho;
  TAIL_  ponta da frente.
Desenho nosso, inspirado só na forma das capturas.
"""
from __future__ import annotations

import math

import bmesh

from lib import mesh3d as M

from . import t211_kit as K
from . import t233_kit as Q

HEAD, MOD, TAIL = 0.05, 0.50, 0.05
DEPTH = 0.055                      # espessura nominal (o jogo encolhe onde a faixa medida é mais fina)
H = 0.36
XF = -0.012                        # face de fora do painel
Z0, Z1 = -0.37, -0.02              # painel: de baixo a cima


def _panel(m, y0, y1, name, mat=None):
    return M.box(name, (DEPTH - 0.012, y1 - y0, Z1 - Z0), (XF - (DEPTH - 0.012) / 2, (y0 + y1) / 2, (Z0 + Z1) / 2),
                 mat or m["body"], bevel=0.0, seg=1)


def _cap(m, y0, y1, name):
    """Friso cromado em cima do painel."""
    return M.box(name, (DEPTH, y1 - y0, 0.018), (-DEPTH / 2, (y0 + y1) / 2, Z1 + 0.006), m["chrome"], bevel=0.0, seg=1)


def _end(m, y, name, sgn):
    """Tampa da ponta (chapa cromada vertical)."""
    return M.box(name, (DEPTH, 0.03, Z1 - Z0 + 0.03), (-DEPTH / 2, y + sgn * 0.015, (Z0 + Z1) / 2 + 0.006), m["chrome"],
                 bevel=0.004, seg=1)


def _face(y0, y1):
    return K.Face((XF, y0, Z0), (0, y1 - y0, 0), (0, 0, Z1 - Z0))          # normal +X (para fora)


def _diamonds(name, face: K.Face, pts, w, h, mat, off=0.004, depth=0.010):
    """Losangos em relevo (s, t no centro; w, h em metros)."""
    bm = bmesh.new()
    U, V, N = face.u.normalized(), face.v.normalized(), face.n
    for (s, t) in pts:
        c = face.at(s, t, off)
        ring = [c + U * (w / 2), c + V * (h / 2), c - U * (w / 2), c - V * (h / 2)]
        a = [bm.verts.new(p) for p in ring]
        b = [bm.verts.new(p + N * depth) for p in ring]
        for k in range(4):
            bm.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
        bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def _arrows(name, face: K.Face, pts, w, h, mat, off=0.004, depth=0.010, th=0.022):
    """Setas (chevron ">" apontando para a frente, +Y) em relevo."""
    bm = bmesh.new()
    U, V, N = face.u.normalized(), face.v.normalized(), face.n
    for (s, t) in pts:
        c = face.at(s, t, off)
        tip = c + U * (w / 2)
        for sg in (1, -1):
            p0 = c - U * (w / 2) + V * (sg * h / 2)
            ring = [p0, tip, tip - U * th, p0 - U * th]
            a = [bm.verts.new(p) for p in ring]
            b = [bm.verts.new(p + N * depth) for p in ring]
            for k in range(4):
                bm.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
            bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def _base(m, panel=True, he=HEAD):
    """Ponta de trás (0..he), módulo (he..he+MOD) e ponta da frente (he+MOD..2he+MOD), com painel e friso."""
    y0, y1 = he, he + MOD
    head = [_end(m, 0.0, "end_h", 1)]
    mid = ([_panel(m, y0, y1, "panel_m")] if panel else []) + [_cap(m, y0, y1, "cap_m")]
    tail = [_end(m, y1 + he, "end_t", -1)]
    if panel:
        head.append(_panel(m, 0.0, he, "panel_h"))
        tail.append(_panel(m, y1, y1 + he, "panel_t"))
    head.append(_cap(m, 0.0, he, "cap_h"))
    tail.append(_cap(m, y1, y1 + he, "cap_t"))
    return head, mid, tail, _face(y0, y1)


def _groups(head, mid, tail):
    return Q.tag(head, "HEAD") + Q.tag(mid, "MID") + Q.tag(tail, "TAIL")


def _bars(face, rows, s0, s1, mat, name, depth=0.010):
    return [K.bar_on(f"{name}_{k}", face, s0, a, s1, b, mat, off=0.002, depth=depth) for k, (a, b) in enumerate(rows)]


def skirt_chrome_rails(m):
    head, mid, tail, f = _base(m, panel=False)
    y0, y1 = HEAD, HEAD + MOD
    xs = -0.032
    mid.append(Q.tubes("rails", [((xs, y0, z), (xs, y1, z)) for z in (-0.07, -0.18, -0.29)], 0.017, m["chrome"], seg=8, ext=0.0))
    mid.append(M.box("post", (0.035, 0.035, Z1 - Z0), (xs - 0.01, y0 + MOD * 0.5, (Z0 + Z1) / 2), m["trim"], bevel=0.004, seg=1))
    mid.append(M.box("post_back", (0.012, MOD, 0.06), (-DEPTH + 0.008, (y0 + y1) / 2, -0.33), m["trim"], bevel=0.0, seg=1))
    return _groups(head, mid, tail)


def skirt_neon_twin(m):
    head, mid, tail, f = _base(m)
    mid += _bars(f, ((0.66, 0.72), (0.30, 0.36)), 0.0, 1.0, m["neon"], "neon")
    return _groups(head, mid, tail)


def skirt_neon_diamond(m):
    head, mid, tail, f = _base(m)
    mid.append(_diamonds("dia", f, [(0.25, 0.5), (0.75, 0.5)], 0.20, 0.10, m["neon"]))
    mid += _bars(f, ((0.47, 0.53),), 0.0, 1.0, m["trim"], "line", depth=0.006)
    return _groups(head, mid, tail)


def skirt_neon_dash(m):
    head, mid, tail, f = _base(m)
    for r, (a, b) in enumerate(((0.62, 0.72), (0.30, 0.40))):
        for k in range(3):
            s = (k + 0.5) / 3 + (0.08 if r else 0.0)
            mid.append(K.bar_on(f"dash_{r}_{k}", f, s - 0.12, a, min(1.0, s + 0.12), b, m["neon"], off=0.002, depth=0.010))
    return _groups(head, mid, tail)


ARCH = 0.20                        # pontas mais compridas na saia com arco (o arco cabe na ponta)


def _arc(m, y_line, y_low, z_line, name):
    """Arco de neon na ponta: sai da linha de neon (y_line, z_line) e desce em quarto de círculo até y_low, como o
    arco da roda das capturas."""
    pts = []
    for k in range(7):
        a = math.radians(90 * k / 6)
        pts.append((XF + 0.008, y_line + (y_low - y_line) * math.sin(a), z_line - (z_line - Z0 - 0.04) * (1 - math.cos(a))))
    return Q.tubes(name, Q.path(pts), 0.010, m["neon"], seg=6)


def skirt_neon_arch(m):
    head, mid, tail, f = _base(m, he=ARCH)
    mid += _bars(f, ((0.70, 0.76), (0.42, 0.48)), 0.0, 1.0, m["neon"], "line")
    zl = Z0 + (Z1 - Z0) * 0.73
    head.append(_arc(m, ARCH, 0.04, zl, "arc_h"))
    head.append(K.bar_on("line_h", _face(ARCH * 0.5, ARCH), 0.0, 0.42, 1.0, 0.48, m["neon"], off=0.002, depth=0.010))
    tail.append(_arc(m, ARCH + MOD, ARCH * 2 + MOD - 0.04, zl, "arc_t"))
    tail.append(K.bar_on("line_t", _face(ARCH + MOD, ARCH * 1.5 + MOD), 0.0, 0.42, 1.0, 0.48, m["neon"], off=0.002, depth=0.010))
    return _groups(head, mid, tail)


def skirt_neon_green(m):
    head, mid, tail, f = _base(m)
    for k in range(4):
        s = (k + 0.5) / 4
        mid.append(K.bar_on(f"green_{k}", f, s - 0.08, 0.66, s + 0.08, 0.74, m["led"], off=0.002, depth=0.010))
    mid += _bars(f, ((0.26, 0.40),), 0.0, 1.0, m["neon"], "band")
    return _groups(head, mid, tail)


def skirt_neon_gems(m):
    head, mid, tail, f = _base(m)
    mid.append(_diamonds("gem", f, [(0.25, 0.48), (0.75, 0.48)], 0.13, 0.13, m["neon"], depth=0.014))
    for r, t in enumerate((0.80, 0.18)):
        for k in range(4):
            s = (k + 0.5) / 4
            mid.append(K.bar_on(f"g_{r}_{k}", f, s - 0.07, t - 0.035, s + 0.07, t + 0.035, m["led"], off=0.002, depth=0.008))
    return _groups(head, mid, tail)


def skirt_neon_arrows(m):
    head, mid, tail, f = _base(m)
    for r, t in enumerate((0.70, 0.32)):
        mid.append(_arrows(f"arrow_{r}", f, [(0.22, t), (0.52, t), (0.82, t)], 0.12, 0.10, m["neon"]))
    mid.append(K.bar_on("marker_a", f, 0.03, 0.47, 0.09, 0.55, m["led"], off=0.002, depth=0.010))
    mid.append(K.bar_on("marker_b", f, 0.91, 0.47, 0.97, 0.55, m["led"], off=0.002, depth=0.010))
    return _groups(head, mid, tail)


def _p(pid, name, build, caps, color="preto_ciano", he=HEAD):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": False, "default_color": color,
            "slot": "side_skirts", "socket": "side_skirts_r", "socket_left": "side_skirts_l", "nominal_w": DEPTH,
            "fit": "runs", "stretch": {"head": he, "mid": MOD, "tail": he}, "folder": "skirt_t233"}


PARTS = [
    _p("skirt_chrome_rails", "Trilhos cromados", skirt_chrome_rails, "086-087", color="cromo_ciano"),
    _p("skirt_neon_twin", "Neon de 2 linhas", skirt_neon_twin, "088"),
    _p("skirt_neon_diamond", "Corrente de losangos", skirt_neon_diamond, "089"),
    _p("skirt_neon_dash", "Neon tracejado duplo", skirt_neon_dash, "090"),
    _p("skirt_neon_arch", "Neon com arco da roda", skirt_neon_arch, "091", he=ARCH),
    _p("skirt_neon_green", "Traços verdes e ciano", skirt_neon_green, "092"),
    _p("skirt_neon_gems", "Pedras de luz", skirt_neon_gems, "093"),
    _p("skirt_neon_arrows", "Setas duplas", skirt_neon_arrows, "094"),
]
