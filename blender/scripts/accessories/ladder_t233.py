"""Escadas do baú, 3 peças do catálogo da T-210 (capturas 111–113), T-233.

Uma por lado (a do lado esquerdo é espelhada no jogo), na lateral do baú logo atrás da quina da frente (e atrás dos
escapamentos altos), por fora do contorno de LED. Origem = encaixe "ladder_r": lado de dentro (encostado no contorno),
no FUNDO do baú, no meio da escada (ver `lib/socket_rules.py`). A peça cresce para FORA (+X, no máximo 0,16 m) e para
CIMA (+Z). Vem em 3 grupos que o jogo monta pela altura do baú (`game/scripts/truck/frame_fit.gd`, fit "ladder"):
  BOT_  pé (z de 0 a BOT), com o suporte que encosta no baú;
  MID_  um degrau (z de BOT a BOT + MOD), repetido até o topo do baú (sem deformar os degraus);
  TOP_  topo (z de 0 a TOP acima do último degrau), com o suporte de cima.
Desenho nosso, inspirado só na forma das capturas.
"""
from __future__ import annotations

from lib import mesh3d as M

from . import t211_kit as K
from . import t233_kit as Q

BOT, MOD, TOP = 0.15, 0.30, 0.18
WY = 0.13                          # meia largura (trilhos em y = ±WY)
XR = 0.105                         # trilhos: centro em x
NOMINAL_W = 0.30


def _rails(m, z0, z1, name, mat=None, neon=False):
    o = []
    for k, y in enumerate((-WY, WY)):
        o.append(M.box(f"{name}_rail{k}", (0.04, 0.045, z1 - z0), (XR, y, (z0 + z1) / 2), mat or m["body"], bevel=0.0, seg=1))
        if neon:
            o.append(M.box(f"{name}_neon{k}", (0.008, 0.016, z1 - z0), (XR + 0.022, y, (z0 + z1) / 2), m["neon"], bevel=0.0, seg=1))
    return o


def _bracket(m, z, name):
    return [M.box(f"{name}_br{k}", (XR - 0.005, 0.03, 0.035), ((XR - 0.005) / 2, y, z), m["trim"], bevel=0.004, seg=1)
            for k, y in enumerate((-WY, WY))]


def _rung(m, z, name, mat=None):
    return Q.tubes(name, [((XR, -WY, z), (XR, WY, z))], 0.014, mat or m["chrome"], seg=6, ext=0.0)


def _groups(bot, mid, top):
    return Q.tag(bot, "BOT") + Q.tag(mid, "MID") + Q.tag(top, "TOP")


def ladder_neon(m):
    z1 = BOT + MOD
    bot = _rails(m, 0.0, BOT, "b", neon=True) + _bracket(m, 0.08, "b") + \
        [M.box("foot", (0.05, 2 * WY + 0.06, 0.02), (XR, 0.0, 0.01), m["chrome"], bevel=0.004, seg=1)]
    mid = _rails(m, BOT, z1, "m", neon=True) + [_rung(m, BOT + MOD * 0.5, "rung")]
    top = _rails(m, 0.0, TOP, "t", neon=True) + _bracket(m, TOP - 0.06, "t") + \
        [M.box("cap", (0.05, 2 * WY + 0.06, 0.02), (XR, 0.0, TOP - 0.01), m["chrome"], bevel=0.004, seg=1)]
    for o in top:
        o.location.z += z1
    return _groups(bot, mid, top)


def ladder_green(m):
    z1 = BOT + MOD
    bot = _rails(m, 0.0, BOT, "b") + _bracket(m, 0.08, "b")
    mid = _rails(m, BOT, z1, "m") + [M.box("rung", (0.035, 2 * WY, 0.03), (XR, 0.0, BOT + MOD * 0.5), m["trim"], bevel=0.004, seg=1)]
    face = K.Face((XR + 0.018, WY * 0.8, BOT + MOD * 0.5 - 0.012), (0, -2 * WY * 0.8, 0), (0, 0, 0.024))    # normal +X
    mid.append(K.led_grid("leds", face, 0.0, 0.0, 1.0, 1.0, 3, 1, m["led"], fill=0.7, off=0.004, depth=0.008))
    top = _rails(m, 0.0, TOP, "t") + _bracket(m, TOP - 0.06, "t")
    tf = K.Face((XR + 0.022, WY + 0.02, 0.04), (0, -(2 * WY + 0.04), 0), (0, 0, 0.05))
    top.append(K.led_grid("top_leds", tf, 0.0, 0.0, 1.0, 1.0, 4, 1, m["led"], fill=0.7, off=0.004, depth=0.008))
    for o in top:
        o.location.z += z1
    return _groups(bot, mid, top)


def ladder_chrome(m):
    z1 = BOT + MOD

    def rail_truss(za, zb, n):
        segs = []
        for y in (-WY, WY):
            segs += Q.truss((XR - 0.016, y, za), (XR - 0.016, y, zb), (XR + 0.016, y, za), (XR + 0.016, y, zb), n)
        return segs
    bot = [Q.tubes("b_truss", rail_truss(0.0, BOT, 1), 0.008, m["chrome"], seg=5)] + _bracket(m, 0.08, "b")
    mid = [Q.tubes("m_truss", rail_truss(BOT, z1, 2), 0.008, m["chrome"], seg=5), _rung(m, BOT + MOD * 0.5, "rung")]
    top = [Q.tubes("t_truss", rail_truss(0.0, TOP, 1), 0.008, m["chrome"], seg=5)] + _bracket(m, TOP - 0.06, "t") + \
        [Q.tubes("hoop", Q.path([(XR, -WY, TOP), (XR + 0.03, -WY * 0.5, TOP + 0.0), (XR + 0.03, WY * 0.5, TOP), (XR, WY, TOP)]),
                 0.010, m["chrome"], seg=6)]
    for o in top:
        o.location.z += z1
    return _groups(bot, mid, top)


def _p(pid, name, build, caps, color="preto_ciano"):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": False, "default_color": color,
            "slot": "ladder", "socket": "ladder_r", "socket_left": "ladder_l", "nominal_w": NOMINAL_W, "fit": "ladder",
            "stretch": {"head": BOT, "mid": MOD, "tail": TOP}, "folder": "ladder_t233"}


PARTS = [
    _p("ladder_neon", "Escada de neon", ladder_neon, "111"),
    _p("ladder_green", "Escada de luzes verdes", ladder_green, "112", color="preto_verde"),
    _p("ladder_chrome", "Escada cromada", ladder_chrome, "113", color="cromo_ciano"),
]
