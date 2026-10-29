"""Hastes de retrovisor (ミラーステー), 6 peças do catálogo da T-210 (capturas 105–110), T-233.

Uma peça por lado (a do lado esquerdo é espelhada no jogo). Origem = encaixe "mirror_stay_r": lateral da cabine na
coluna do para-brisa, na altura da borda de BAIXO do vidro (ver `lib/socket_rules.py`). A peça cresce para FORA (+X),
para a FRENTE (+Y) e para CIMA (+Z). Altura nominal do vidro HN = 0,85 m: o jogo estica a altura pelo vidro de cada
cabine (0,75–1,30) e escala o resto pela largura (fit "stay", `game/scripts/truck/frame_fit.gd`).
Cada haste traz o espelho dela (cabeça com vidro virado para trás); o espelho de fábrica some quando a haste está
montada (caixa `hide` do encaixe). Decisão da T-233: no máximo 0,50 m para fora da cabine (a largura com a haste fica
na ordem da dos espelhos de fábrica) e 0,60 m à frente.
Desenho nosso, inspirado só na forma das capturas.
"""
from __future__ import annotations

from lib import mesh3d as M

from . import t233_kit as Q

HN = 0.85
NOMINAL_W = 2.30
R = 0.016                         # raio do tubo cromado
HX, HY, HZ = 0.36, 0.30, 0.44     # centro da cabeça do espelho
HW, HH = 0.19, 0.34


XA = 0.04                         # m: os braços começam aqui (por fora da lataria); o jogo liga cada braço à chapa
FLANGE_T = 0.012                  # m: espessura da chapa de fixação (= StayFit.FLANGE_T)


def _pad_parts(m):
    """T-263: chapa de fixação (grupo PADF_, centrada na origem, virada para +X, de x = 0 a FLANGE_T) com 2 parafusos e
    espaçador (grupo PADS_, tubo de comprimento 1 ao longo de +X). O jogo põe uma chapa encostada na lataria em cada
    ponto de fixação (`pads`) e estica o espaçador até o braço (game/scripts/truck/stay_fit.gd)."""
    o = [M.box("PADF_plate", (FLANGE_T, 0.04, 0.07), (FLANGE_T / 2, 0.0, 0.0), m["trim"], bevel=0.003, seg=1)]
    for k, z in enumerate((-0.022, 0.022)):
        o.append(M.cylinder(f"PADF_bolt{k}", 0.007, 0.006, (FLANGE_T + 0.003, 0.0, z), m["chrome"], axis="X", seg=6))
    o.append(Q.tubes("PADS_stem", [((0.0, 0.0, 0.0), (1.0, 0.0, 0.0))], R * 1.15, m["chrome"], seg=8, ext=0.0))
    return o


def _mounts(m, zs=(0.10, HN * 0.82)):
    """Pontos de fixação (altura de cada braço) + as peças da chapa/espaçador."""
    return _pad_parts(m), [[XA, round(z, 4)] for z in zs]


def _head(m, c=(HX, HY, HZ), w=HW, h=HH, name="head"):
    return Q.mirror_head(name, c, w, h, 0.07, m)


def mirror_stay_l(m):
    top = HN * 0.82
    segs = Q.path([(XA, 0.0, top), (HX, HY, top), (HX, HY, HZ + HH / 2)])
    segs += Q.path([(XA, 0.0, 0.10), (HX, HY, 0.10), (HX, HY, HZ - HH / 2)])
    pads, pts = _mounts(m)
    return [Q.tubes("arms", segs, R, m["chrome"], seg=8)] + pads + _head(m), pts


def mirror_stay_truss(m):
    top = HN * 0.82
    segs = Q.truss((XA, 0.0, top + 0.03), (HX, HY, top + 0.03), (XA, 0.0, top - 0.04), (HX, HY, top - 0.04), 6)
    segs += [((HX, HY, top + 0.03), (HX, HY, HZ + HH / 2))]
    segs += Q.truss((XA, 0.0, 0.13), (HX, HY, 0.13), (XA, 0.0, 0.06), (HX, HY, 0.06), 6)
    segs += [((HX, HY, 0.06), (HX, HY, HZ - HH / 2))]
    pads, pts = _mounts(m, (0.095, HN * 0.82))
    return [Q.tubes("truss", segs, R * 0.75, m["chrome"], seg=6)] + pads + _head(m), pts


def _rect_pts(y_front=0.42, x_out=HX + 0.10, top=HN * 0.86, low=0.06):
    return [(XA, 0.0, low), (XA, 0.0, top), (x_out, y_front, top), (x_out, y_front, low), (XA, 0.0, low)]


def mirror_stay_frame(m):
    pts = _rect_pts()
    segs = Q.path(pts)
    segs += [((HX + 0.10, 0.42, HZ), (HX + 0.02, HY - 0.02, HZ))]          # braço curto até a cabeça
    pads, pp = _mounts(m, (0.06, HN * 0.86))
    return [Q.tubes("frame", segs, R, m["chrome"], seg=8)] + pads + _head(m, c=(HX - 0.02, HY - 0.06, HZ)), pp


def mirror_stay_box(m):
    pts = _rect_pts(y_front=0.40, x_out=HX + 0.09)
    segs = Q.path(pts)
    segs += [((HX + 0.09, 0.40, HZ), (HX + 0.0, HY - 0.06, HZ))]
    pads, pp = _mounts(m, (0.06, HN * 0.86))
    return [Q.tubes("frame", segs, 0.0, m["chrome"], rect=(0.05, 0.05), ext=0.025)] + pads + \
        _head(m, c=(HX - 0.03, HY - 0.10, HZ)), pp


def mirror_stay_chain(m):
    top, low = HN * 0.86, 0.06
    xo, yf = HX + 0.06, 0.42
    segs = Q.chain((XA, 0.0, top), (xo, yf, top), 0.05, 7, (0.0, 0.0, 1.0))
    segs += Q.chain((xo, yf, top), (xo, yf, low), 0.05, 6, (0.7, -0.7, 0.0))
    segs += Q.path([(XA, 0.0, low), (xo, yf, low)])
    segs += [((xo, yf, HZ), (HX + 0.02, HY - 0.02, HZ))]
    pads, pp = _mounts(m, (0.06, HN * 0.86))
    return [Q.tubes("chain", segs, R * 0.6, m["chrome"], seg=6)] + pads + _head(m, c=(HX - 0.02, HY - 0.06, HZ)), pp


def mirror_stay_grand(m):
    """Moldura gigante treliçada até a frente da cabine, com 2 espelhos (o grande e o de baixo) e um friso de neon."""
    top, low = HN * 0.90, 0.02
    xo, yf = HX + 0.11, 0.56
    segs = Q.truss((XA, -0.02, top + 0.035), (xo, yf, top + 0.035), (XA, -0.02, top - 0.035), (xo, yf, top - 0.035), 9)
    segs += Q.truss((xo, yf + 0.0, top), (xo, yf, low), (xo - 0.06, yf - 0.06, top), (xo - 0.06, yf - 0.06, low), 7)
    segs += Q.truss((XA, -0.02, low + 0.035), (xo, yf, low + 0.035), (XA, -0.02, low - 0.0), (xo, yf, low - 0.0), 9)
    o = [Q.tubes("truss", segs, R * 0.7, m["chrome"], seg=6)]
    o.append(Q.tubes("neon", [((0.06, 0.03, top + 0.075), (xo - 0.02, yf - 0.02, top + 0.075))], 0.011, m["neon"], seg=6))
    pads, pts = _mounts(m, (0.02, top))
    o += pads
    o += _head(m, c=(HX - 0.04, HY - 0.02, HZ + 0.06), w=0.21, h=0.38)
    o += _head(m, c=(HX - 0.06, yf - 0.08, 0.16), w=0.15, h=0.14, name="head_low")
    o.append(Q.tubes("head_low_arm", [((xo - 0.06, yf - 0.06, 0.16), (HX - 0.05, yf - 0.08, 0.16))], R * 0.7, m["chrome"]))
    return o, pts


def _p(pid, name, build, caps, color="cromo_ciano"):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": False, "default_color": color,
            "slot": "mirror_stay", "socket": "mirror_stay_r", "socket_left": "mirror_stay_l", "nominal_w": NOMINAL_W,
            "fit": "stay", "vfit": {"nominal_h": HN}, "folder": "mirror_t233", "pads_from_build": True}


PARTS = [
    _p("mirror_stay_l", "Haste em L", mirror_stay_l, "105"),
    _p("mirror_stay_truss", "Haste treliçada", mirror_stay_truss, "106"),
    _p("mirror_stay_frame", "Moldura retangular", mirror_stay_frame, "107"),
    _p("mirror_stay_box", "Moldura grossa", mirror_stay_box, "108", color="preto_ciano"),
    _p("mirror_stay_chain", "Treliça vazada", mirror_stay_chain, "109"),
    _p("mirror_stay_grand", "Moldura gigante", mirror_stay_grand, "110"),
]
