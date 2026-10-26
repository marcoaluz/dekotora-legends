"""Foguete (2 tubos nas bordas do teto do baú, capturas 095–101) e contorno de LED do baú (102–104), T-231.

FOGUETE: uma peça por lado (a do lado esquerdo é espelhada no jogo). Origem = encaixe "rocket_r": borda de FORA da
faixa livre do teto, no teto, na ponta de TRÁS. A peça cresce para a frente (+Y) e para dentro (-X). Vem em 3 grupos de
objetos que o jogo monta pelo comprimento do baú (`game/scripts/truck/strip_fit.gd`, fit "stretch"):
  HEAD_  ponta de trás (y de 0 a HEAD), com a ponta de neon virada para trás;
  MID_   módulo do meio (y de HEAD a HEAD + MOD), repetido até o comprimento do baú (sem deformar as tampas);
  TAIL_  ponta da frente (y de HEAD + MOD a HEAD + MOD + TAIL).
Largura nominal da faixa BAND (0,17 m): o jogo encolhe a seção (até 0,70) onde a faixa é mais estreita.

CONTORNO: um módulo só (MID_, 0,30 m: trilho fino + traço de LED) que o jogo repete ao longo das faixas medidas nas
bordas de cada face do baú (fit "strips"). Local: comprimento em +Y, largura em X (centrado), para fora da face = +Z.
Desenho nosso, inspirado nas formas das capturas (nada copiado).
"""
from __future__ import annotations

import math

from lib import mesh3d as M

from . import t211_kit as K

BAND = 0.17
HEAD = 0.10
MOD = 1.00
TAIL = 0.24
CX = -BAND / 2                     # centro da seção (a peça cresce para dentro, -X)
STRIP_MOD = 0.30


def _base(o, m, y0, y1, w=0.15, h=0.02, name="base"):
    """Trilho de apoio no teto (assenta a peça inteira; o jogo não precisa de pés)."""
    o.append(M.box(f"{name}", (w, y1 - y0, h), (CX, (y0 + y1) / 2, h / 2), m["trim"], bevel=0.005, seg=1))


def _tube(name, r, y0, y1, z, mat, x=CX, seg=10):
    o = M.cylinder(name, r, y1 - y0, (x, (y0 + y1) / 2, z), mat, axis="Y", seg=seg, bevel=0.0)
    o.rotation_euler.y = math.radians(180.0 / seg)       # face chata embaixo
    return o


def _cone(name, r0, r1, y0, y1, z, mat, x=CX, seg=10):
    o = M.cylinder(name, r0, y1 - y0, (x, (y0 + y1) / 2, z), mat, axis="Y", seg=seg, bevel=0.0, radius2=r1)
    o.rotation_euler.y = math.radians(180.0 / seg)
    return o


def _neon_disc(name, r, y, z, mat, x=CX, seg=10, depth=0.03):
    return _tube(name, r, y - depth, y, z, mat, x=x, seg=seg)


def _box(name, size, ctr, mat, bevel=0.008):
    return M.box(name, size, ctr, mat, bevel=bevel, seg=1)


def _at_cx(o):
    """Peça feita centrada em x = 0 (wedge_box): leva para o centro da seção."""
    o.location.x += CX
    return o


def _tag(objs, group):
    for ob in objs:
        ob.name = group + "_" + ob.name
    return objs


# ----------------------------------------------------------------------------- foguetes

def rocket_round(m):
    r, z = 0.068, 0.02 + 0.068
    head, mid, tail = [], [], []
    _base(head, m, 0.0, HEAD, name="base_h")
    head += [_tube("tube_h", r, 0.03, HEAD, z, m["body"]), _tube("ring_h", r * 1.08, 0.02, 0.045, z, m["chrome"]),
             _neon_disc("tip", r * 0.86, 0.03, z, m["neon"])]
    _base(mid, m, HEAD, HEAD + MOD, name="base_m")
    mid += [_tube("tube_m", r, HEAD, HEAD + MOD, z, m["body"]), _tube("clamp", r * 1.07, HEAD + 0.02, HEAD + 0.05, z, m["chrome"])]
    y0 = HEAD + MOD
    _base(tail, m, y0, y0 + TAIL, name="base_t")
    tail += [_tube("tube_t", r, y0, y0 + 0.06, z, m["body"]), _cone("nose", r, r * 0.35, y0 + 0.06, y0 + TAIL, z, m["chrome"])]
    return _tag(head, "HEAD") + _tag(mid, "MID") + _tag(tail, "TAIL")


def rocket_square(m):
    s, z = 0.13, 0.02 + 0.065
    head, mid, tail = [], [], []
    _base(head, m, 0.0, HEAD, name="base_h")
    head.append(_box("tube_h", (s, HEAD - 0.03, s), (CX, 0.03 + (HEAD - 0.03) / 2, z), m["body"]))
    head.append(_box("cap_h", (s + 0.01, 0.02, s + 0.01), (CX, 0.035, z), m["chrome"], bevel=0.004))
    for k, dx in enumerate((-0.033, 0.033)):
        head.append(_box(f"tip_{k}", (0.05, 0.03, 0.08), (CX + dx, 0.015, z), m["neon"], bevel=0.004))
    _base(mid, m, HEAD, HEAD + MOD, name="base_m")
    mid.append(_box("tube_m", (s, MOD, s), (CX, HEAD + MOD / 2, z), m["body"]))
    mid.append(_box("seam", (s + 0.006, 0.012, s + 0.006), (CX, HEAD + 0.01, z), m["chrome"], bevel=0.002))
    y0 = HEAD + MOD
    _base(tail, m, y0, y0 + TAIL, name="base_t")
    tail.append(_at_cx(K.wedge_box("nose", s, TAIL, s, TAIL * 0.6, m["body"], y0=y0, z0=z - s / 2, bevel=0.008)))
    return _tag(head, "HEAD") + _tag(mid, "MID") + _tag(tail, "TAIL")


def rocket_twin(m):
    r = 0.046
    xs = (CX - 0.040, CX + 0.040)
    z = 0.02 + r
    head, mid, tail = [], [], []
    _base(head, m, 0.0, HEAD, name="base_h")
    _base(mid, m, HEAD, HEAD + MOD, name="base_m")
    y0 = HEAD + MOD
    _base(tail, m, y0, y0 + TAIL, name="base_t")
    for k, x in enumerate(xs):
        head += [_tube(f"tube_h{k}", r, 0.03, HEAD, z, m["body"], x=x, seg=6),
                 _tube(f"ring_h{k}", r * 1.1, 0.02, 0.045, z, m["chrome"], x=x, seg=6),
                 _neon_disc(f"tip{k}", r * 0.84, 0.03, z, m["neon"], x=x, seg=6)]
        mid += [_tube(f"tube_m{k}", r, HEAD, HEAD + MOD, z, m["body"], x=x, seg=6)]
        tail += [_tube(f"tube_t{k}", r, y0, y0 + 0.08, z, m["body"], x=x, seg=6),
                 _cone(f"nose{k}", r, r * 0.4, y0 + 0.08, y0 + TAIL, z, m["chrome"], x=x, seg=6)]
    mid.append(_box("clamp", (0.17, 0.03, 0.025), (CX, HEAD + 0.03, z + r + 0.006), m["chrome"], bevel=0.004))
    return _tag(head, "HEAD") + _tag(mid, "MID") + _tag(tail, "TAIL")


def _led_dots(name, face, n, m, fill=0.62, off=0.004):
    """LEDs da fita: n quadradinhos chatos (1 quadrado cada, UV 0..1 para a lente) um pouco à frente da face."""
    import bmesh
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for k in range(n):
        s0, s1 = (k + 0.5 - fill / 2) / n, (k + 0.5 + fill / 2) / n
        t0, t1 = 0.5 - fill / 2, 0.5 + fill / 2
        vs = [bm.verts.new(face.at(a, b, off)) for a, b in ((s0, t0), (s1, t0), (s1, t1), (s0, t1))]
        f = bm.faces.new(vs)
        for lp, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            lp[uvl].uv = uv
    return M._link(name, bm, m["led"])


def rocket_led(m):
    s = 0.12
    z = 0.02 + s / 2
    head, mid, tail = [], [], []
    _base(head, m, 0.0, HEAD, name="base_h")
    head.append(_box("tube_h", (s, HEAD - 0.03, s), (CX, 0.03 + (HEAD - 0.03) / 2, z), m["body"]))
    for k, dx in enumerate((-0.03, 0.03)):
        head.append(_box(f"tip_{k}", (0.045, 0.03, 0.07), (CX + dx, 0.015, z), m["neon"], bevel=0.004))
    _base(mid, m, HEAD, HEAD + MOD, name="base_m")
    mid.append(_box("tube_m", (s, MOD, s), (CX, HEAD + MOD / 2, z), m["body"]))
    # fita de LED na face de fora (verde nas capturas 098): 2 fileiras, 8 LEDs por metro
    xo = CX + s / 2
    for row, (za, zb) in enumerate(((z + 0.008, z + 0.044), (z - 0.044, z - 0.008))):
        face = K.Face((xo, HEAD, za), (0, MOD, 0), (0, 0, zb - za))                   # normal +X (para fora)
        mid.append(_led_dots(f"led{row}", face, 8, m))
    y0 = HEAD + MOD
    _base(tail, m, y0, y0 + TAIL, name="base_t")
    tail.append(_at_cx(K.wedge_box("nose", s, TAIL, s, TAIL * 0.55, m["body"], y0=y0, z0=z - s / 2, bevel=0.008)))
    return _tag(head, "HEAD") + _tag(mid, "MID") + _tag(tail, "TAIL")


def rocket_flat_neon(m):
    w, h = 0.15, 0.06
    head, mid, tail = [], [], []
    head.append(_box("ch_h", (w, HEAD, h), (CX, HEAD / 2, h / 2), m["body"]))
    head.append(_box("tip", (w - 0.03, 0.03, h - 0.02), (CX, 0.012, h / 2), m["neon"], bevel=0.004))
    mid.append(_box("ch_m", (w, MOD, h), (CX, HEAD + MOD / 2, h / 2), m["body"]))
    mid.append(_box("lip", (w + 0.01, MOD, 0.012), (CX, HEAD + MOD / 2, h), m["trim"], bevel=0.003))
    for k in range(3):                                    # neon tracejado em cima (capturas 099)
        y = HEAD + MOD * (1 + 2 * k) / 6
        mid.append(_box(f"dash_{k}", (0.035, MOD * 0.20, 0.014), (CX - 0.02, y, h + 0.012), m["neon"], bevel=0.0))
    y0 = HEAD + MOD
    tail.append(_at_cx(K.wedge_box("nose", w, TAIL, h, TAIL * 0.7, m["body"], y0=y0, z0=0.0, bevel=0.006)))
    return _tag(head, "HEAD") + _tag(mid, "MID") + _tag(tail, "TAIL")


def rocket_neon_dash(m):
    r, z = 0.064, 0.02 + 0.064
    head, mid, tail = [], [], []
    _base(head, m, 0.0, HEAD, name="base_h")
    head += [_tube("tube_h", r, 0.03, HEAD, z, m["body"]), _neon_disc("tip", r * 0.9, 0.03, z, m["neon"]),
             _tube("ring_h", r * 1.08, 0.025, 0.05, z, m["chrome"])]
    _base(mid, m, HEAD, HEAD + MOD, name="base_m")
    mid.append(_tube("tube_m", r, HEAD, HEAD + MOD, z, m["body"]))
    for row, a in enumerate((25.0, 70.0)):               # 2 linhas de neon tracejado na lateral de fora (captura 100)
        ang = math.radians(a)
        x, zz = CX + math.cos(ang) * (r + 0.004), z + math.sin(ang) * (r + 0.004) - 0.01
        for k in range(3):
            y = HEAD + MOD * (1 + 2 * k) / 6 + (0.04 if row else 0.0)
            mid.append(_box(f"dash_{row}_{k}", (0.018, MOD * 0.17, 0.022), (x, y, zz), m["neon"], bevel=0.0))
    y0 = HEAD + MOD
    _base(tail, m, y0, y0 + TAIL, name="base_t")
    tail += [_tube("tube_t", r, y0, y0 + 0.06, z, m["body"]), _cone("nose", r, r * 0.3, y0 + 0.06, y0 + TAIL, z, m["body"])]
    return _tag(head, "HEAD") + _tag(mid, "MID") + _tag(tail, "TAIL")


def rocket_frame(m):
    """Moldura do teto (captura 101): perfil inclinado para fora, retângulos de neon na face de fora e um bloco de
    luzes na ponta de trás. Não cruza o andon de fábrica do teto (fica na faixa da borda)."""
    w, h = 0.17, 0.12
    head, mid, tail = [], [], []
    # bloco de trás com 4 luzes viradas para trás
    head.append(_box("block", (w, HEAD - 0.02, h + 0.02), (CX, 0.02 + (HEAD - 0.02) / 2, (h + 0.02) / 2), m["body"]))
    for k in range(3):
        head.append(_box(f"light_{k}", (0.035, 0.03, 0.06), (CX - 0.05 + 0.05 * k, 0.012, h / 2 + 0.01), m["neon"], bevel=0.004))
    head.append(_box("rim", (w - 0.004, 0.016, h + 0.026), (CX, 0.024, (h + 0.02) / 2), m["chrome"], bevel=0.004))
    prof = [(0.0, 0.0), (0.0, h), (-w * 0.55, h), (-w, h * 0.35), (-w, 0.0)]       # (x, z) a partir da borda de fora
    mid.append(_extrude("wall_m", prof, HEAD, HEAD + MOD, m["body"]))
    for k in range(2):
        mid.append(_box(f"neon_m{k}", (0.012, MOD * 0.26, h * 0.42), (-0.002, HEAD + MOD * (0.25 + 0.5 * k), h * 0.5), m["neon"],
                        bevel=0.0))
    mid.append(_box("cap_m", (w * 0.55 + 0.01, MOD, 0.012), (-w * 0.275, HEAD + MOD / 2, h + 0.004), m["chrome"], bevel=0.003))
    y0 = HEAD + MOD
    tail.append(_extrude("wall_t", prof, y0, y0 + TAIL * 0.6, m["body"]))
    tail.append(_box("end_t", (w + 0.01, 0.03, h + 0.01), (CX, y0 + TAIL * 0.6, h / 2), m["chrome"], bevel=0.004))
    return _tag(head, "HEAD") + _tag(mid, "MID") + _tag(tail, "TAIL")


def _extrude(name, prof_xz, y0, y1, mat):
    """Perfil (x, z) extrudado de y0 a y1."""
    import bmesh
    bm = bmesh.new()
    a = [bm.verts.new((x, y0, z)) for x, z in prof_xz]
    b = [bm.verts.new((x, y1, z)) for x, z in prof_xz]
    n = len(prof_xz)
    for k in range(n):
        bm.faces.new([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


# ----------------------------------------------------------------------------- contorno de LED do baú

def boxlight_dash(m):
    """Módulo do contorno (0,30 m): trilho fino na cor da peça + traço de LED com lente (captura 102)."""
    rail = M.box("rail", (0.022, STRIP_MOD, 0.008), (0.0, STRIP_MOD / 2, 0.004), m["trim"], bevel=0.0, seg=1)
    face = K.Face((-0.008, 0.08, 0.008), (0.016, 0, 0), (0, 0.14, 0))
    led = K.led_grid("dash", face, 0.0, 0.0, 1.0, 1.0, 1, 1, m["led"], fill=1.0, off=0.006, depth=0.008)
    return _tag([rail, led], "MID")


def _p(pid, name, build, caps, color="preto_ciano", fit="stretch", socket="rocket_r", left="rocket_l", stretch=None):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": False, "default_color": color,
            "slot": "rocket", "socket": socket, "socket_left": left, "nominal_w": BAND, "fit": fit,
            "stretch": stretch or {"head": HEAD, "mid": MOD, "tail": TAIL}, "folder": "rocket_t231"}


PARTS = [
    _p("rocket_round", "Foguete redondo", rocket_round, "095"),
    _p("rocket_square", "Foguete quadrado", rocket_square, "096"),
    _p("rocket_twin", "Foguete duplo", rocket_twin, "097"),
    _p("rocket_led", "Foguete com LED", rocket_led, "098", color="preto_verde"),
    _p("rocket_flat_neon", "Calha neon", rocket_flat_neon, "099"),
    _p("rocket_neon_dash", "Foguete neon tracejado", rocket_neon_dash, "100"),
    _p("rocket_frame", "Moldura de teto", rocket_frame, "101"),
]
BOXLIGHT = {"id": "boxlight_dash", "build": boxlight_dash, "stretch": {"mid": STRIP_MOD}}
BOXLIGHT_PARTS = [
    ("boxlight_dash_r", "Contorno de luz – direita", "box_light_r", "102"),
    ("boxlight_dash_l", "Contorno de luz – esquerda", "box_light_l", "103"),
    ("boxlight_dash_top", "Contorno de luz – teto", "box_light_top", "104"),
]
