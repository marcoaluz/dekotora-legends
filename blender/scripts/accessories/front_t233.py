"""Para-choque da frente, 11 peças do catálogo da T-210 (capturas 044–062), T-233.

Origem = encaixe "front_bumper" do caminhão: TOPO, centro, COSTAS encostadas na frente do nariz de fábrica (que a peça
cobre; ver `lib/socket_rules.py`). A peça cresce para a FRENTE (+Y) e para BAIXO (-Z). Largura nominal da cabine 2,30 m
(a peça tem 2,50: passa 0,10 m de cada lado); o jogo escala pela largura da cabine (0,85–1,15).
Altura: 3 faixas empilhadas (`vfit`):
  TOP_  faixa de cima (fixa no topo): lâmpadas de cima e as SETAS (pontos SIGNAL_L/SIGNAL_R: a seta da frente do caminhão
        vai para a peça, como no original);
  MID_  faixa do meio (lisa: chapa e faixas): o jogo ESTICA/ENCOLHE só ela para a peça caber entre o chão e o farol mais
        baixo de cada cabine (o Canter e as cabines HAYATE têm farol baixo) e cobrir o para-choque de fábrica;
  BOT_  faixa de baixo (sobe junto quando o meio encolhe);
  CEN_  caixa da placa e caixas de lâmpadas centradas no meio (sobem metade). A placa do caminhão vai para a caixa da
        placa (`deco_plate`), como a da traseira (T-231).
Desenho nosso, inspirado só na forma e cor das capturas (leque baixo, caixa alta, deque de chapa xadrez).
"""
from __future__ import annotations

from lib import mesh3d as M

from . import t211_kit as K
from . import t231_kit as T
from . import t233_kit as Q

W = 2.50
NOMINAL_W = 2.30


def _grow(poly, d):
    """Contorno um pouco maior (frisos cromados de cima e de baixo); as costas (y = 0) ficam no lugar."""
    out = []
    for x, y in poly:
        out.append((x + (d if x > 0 else -d), y if y <= 1e-6 else y + d))
    return out


class Fan:
    """Corpo de 3 faixas com a mesma planta. `t`, `mm`, `b` = alturas de cima, do meio e de baixo."""

    def __init__(self, m, poly, t, mm, b, body=None, faces=None):
        self.m, self.poly, self.t, self.mm, self.b = m, poly, t, mm, b
        self.H = t + mm + b
        body = body or m["body"]
        self.top = [Q.prism("top", poly, -t, -0.006, body, top=False, bottom=False),
                    Q.prism("lip_t", _grow(poly, 0.014), -0.024, 0.0, m["chrome"])]
        self.mid = [Q.prism("mid", poly, -t - mm, -t, body, top=False, bottom=False)]
        self.bot = [Q.prism("bot", poly, -self.H + 0.006, -t - mm, body, top=False, bottom=False),
                    Q.prism("lip_b", _grow(poly, 0.014), -self.H, -self.H + 0.026, m["chrome"])]
        self.cen = []
        self.extra = []                      # pontos SIGNAL_*
        self.faces = faces                   # função (z0, z1) -> (direita, meio, esquerda)

    def band(self, which):
        z = {"top": (-self.t, 0.0), "mid": (-self.t - self.mm, -self.t), "bot": (-self.H, -self.t - self.mm)}[which]
        return self.faces(*z)

    def center_face(self, h):
        """Face do meio, centrada no meio da faixa do meio, com altura `h` (caixa da placa, caixas de lâmpadas)."""
        zc = -self.t - self.mm / 2
        return self.faces(zc - h / 2, zc + h / 2)

    def signals(self, s0=0.03, s1=0.17, t0=0.20, t1=0.78):
        """Lentes da seta nas pontas da faixa de cima + pontos SIGNAL_R (asa +X) e SIGNAL_L."""
        r, _, l = self.band("top")
        for nm, f, (a, b) in (("R", r, (s0, s1)), ("L", l, (1 - s1, 1 - s0))):
            o, c, size = Q.signal_lens("signal_" + nm.lower(), f, a, t0, b, t1, self.m)
            self.top += o
            self.extra.append(Q.signal("SIGNAL_" + nm, c, size))

    def plate(self, h=0.25, s0=0.20, s1=0.80, neon=False):
        _, mid, _ = self.center_face(h)
        self.cen += T.plate_box("plate", mid, s0, 0.0, s1, 1.0, self.m, neon=neon)

    def objects(self):
        return Q.tag(self.top, "TOP") + Q.tag(self.mid, "MID") + Q.tag(self.bot, "BOT") + Q.tag(self.cen, "CEN") + self.extra


def _fan(m, t=0.13, mm=0.20, b=0.09, D=0.42, De=0.22, c=0.42, w=W, body=None):
    poly = Q.fan_poly(w, D, De, c)
    return Fan(m, poly, t, mm, b, body, lambda z0, z1: Q.fan_faces(w, D, De, c, z0, z1))


def _box(m, t=0.16, mm=0.30, b=0.12, D=0.38, ch=0.10, w=W, body=None):
    poly = Q.box_poly(w, D, ch)

    def faces(z0, z1):
        h = (0, 0, z1 - z0)
        right = K.Face((w / 2, D - ch, z0), (-ch, ch, 0), h)
        mid = K.Face((w / 2 - ch, D, z0), (-(w - 2 * ch), 0, 0), h)
        left = K.Face((-w / 2 + ch, D, z0), (-ch, -ch, 0), h)
        return right, mid, left
    return Fan(m, poly, t, mm, b, body, faces)


def _stripes(f: Fan, mat, ts=((0.18, 0.42), (0.58, 0.82)), s0=0.10, s1=0.92, depth=0.012, which="mid", wings=True,
             middle=False):
    """Faixas (painel/neon) nas asas (e no meio) de uma faixa do corpo."""
    r, mid, l = f.band(which)
    out = []
    for k, (a, b) in enumerate(ts):
        if wings:
            out.append(K.bar_on(f"stripe_r{k}", r, s0, a, s1, b, mat, depth=depth))
            out.append(K.bar_on(f"stripe_l{k}", l, 1 - s1, a, 1 - s0, b, mat, depth=depth))
        if middle:
            out.append(K.bar_on(f"stripe_m{k}", mid, 0.04, a, 0.96, b, mat, depth=depth))
    return out


# ----------------------------------------------------------------------------- leque baixo (044–053)

def fb_fan_plate(m):
    f = _fan(m)
    f.signals()
    r, _, l = f.band("top")
    f.top += Q.round_amber("amber_r", r, [(0.36, 0.5), (0.62, 0.5)], 0.034, m)
    f.top += Q.round_amber("amber_l", l, [(0.38, 0.5), (0.64, 0.5)], 0.034, m)
    f.mid += _stripes(f, m["trim"], ts=((0.15, 0.40), (0.60, 0.85)), s0=0.06, s1=0.95)
    f.plate()
    return f.objects()


def fb_fan_amber(m):
    f = _fan(m, mm=0.22)
    f.signals()
    f.mid += _stripes(f, m["trim"], ts=((0.08, 0.20), (0.80, 0.92)), s0=0.04, s1=0.97)
    r, mid, l = f.center_face(0.17)
    for nm, face, (a, b) in (("r", r, (0.22, 0.80)), ("l", l, (0.20, 0.78))):
        f.cen.append(K.quad_panel(f"lampbox_{nm}", face, a, 0.0, b, 1.0, m["trim"], off=0.010, depth=0.014))
        f.cen += K.frame_on(f"lampbox_fr_{nm}", face, a, 0.0, b, 1.0, 0.012 / face.u.length, 0.012 / 0.17, m["chrome"], depth=0.02)
        f.cen += Q.square_amber(f"amb_{nm}", face, a + 0.03, 0.12, b - 0.03, 0.88, 3, 2, m, fill=0.78)
    f.plate(h=0.22)
    return f.objects()


def fb_fan_red(m):
    f = _fan(m, w=2.36, D=0.36, De=0.20, c=0.38)
    f.signals(s0=0.03, s1=0.15)
    r, mid, l = f.band("top")
    f.top += Q.round_amber("red_r", r, T.grid_pts(0.22, 0.98, 0.5, 0.5, 5, 1), 0.030, m, mat=m["tail"], seg=10)
    f.top += Q.round_amber("red_l", l, T.grid_pts(0.02, 0.78, 0.5, 0.5, 5, 1), 0.030, m, mat=m["tail"], seg=10)
    f.mid += _stripes(f, m["trim"], ts=((0.25, 0.75),), s0=0.05, s1=0.96)
    f.plate(h=0.22, s0=0.16, s1=0.84)
    return f.objects()


def fb_fan_gold(m):
    f = _fan(m, mm=0.22)
    f.signals()
    f.mid += _stripes(f, m["trim"], ts=((0.05, 0.30), (0.70, 0.95)), s0=0.03, s1=0.97)
    r, mid, l = f.center_face(0.19)
    for nm, face, (a, b) in (("r", r, (0.24, 0.84)), ("l", l, (0.16, 0.76))):
        f.cen.append(K.quad_panel(f"goldbox_{nm}", face, a, 0.0, b, 1.0, m["gold"], off=0.012, depth=0.03))
        f.cen += Q.round_amber(f"gold_lamps_{nm}", face, T.grid_pts(a + 0.04, b - 0.04, 0.5, 0.5, 3, 1), 0.045, m, seg=12)
    f.plate(h=0.22)
    return f.objects()


def fb_fan_stripe(m):
    f = _fan(m)
    f.signals()
    r, mid, l = f.band("mid")
    for k, (a, b) in enumerate(((0.12, 0.34), (0.42, 0.64), (0.72, 0.94))):
        f.mid.append(K.bar_on(f"pink_r{k}", r, 0.05, a, 0.42, b, m["pink"], depth=0.012))
        f.mid.append(K.bar_on(f"pink_l{k}", l, 0.58, a, 0.95, b, m["pink"], depth=0.012))
        f.mid.append(K.bar_on(f"blue_r{k}", r, 0.48, a, 0.95, b, m["trim"], depth=0.012))
        f.mid.append(K.bar_on(f"blue_l{k}", l, 0.05, a, 0.52, b, m["trim"], depth=0.012))
    rt, _, lt = f.band("top")
    f.top.append(K.led_grid("led_r", rt, 0.30, 0.3, 0.95, 0.7, 8, 1, m["led"], fill=0.6, off=0.012, depth=0.01))
    f.top.append(K.led_grid("led_l", lt, 0.05, 0.3, 0.70, 0.7, 8, 1, m["led"], fill=0.6, off=0.012, depth=0.01))
    f.plate()
    return f.objects()


def fb_fan_chrome(m):
    f = _fan(m, mm=0.22, body=m["chrome"])
    f.signals()
    f.mid += _stripes(f, m["trim"], ts=((0.20, 0.38), (0.62, 0.80)), s0=0.08, s1=0.80)
    r, mid, l = f.center_face(0.20)
    f.cen.append(K.quad_panel("grille_back", mid, 0.04, 0.0, 0.96, 1.0, m["trim"], off=0.008, depth=0.012))
    for k in range(5):
        tt = 0.1 + 0.8 * k / 4
        f.cen.append(K.bar_on(f"grille_{k}", mid, 0.05, tt - 0.035, 0.95, tt + 0.035, m["chrome"], off=0.010, depth=0.016))
    rt, _, lt = f.band("top")
    f.top += Q.round_amber("amber_r", rt, [(0.45, 0.5), (0.70, 0.5)], 0.032, m)
    f.top += Q.round_amber("amber_l", lt, [(0.30, 0.5), (0.55, 0.5)], 0.032, m)
    rb, mb, lb = f.band("bot")
    f.bot.append(K.bar_on("plate_mount", mb, 0.25, 0.25, 0.75, 0.75, m["trim"], depth=0.01))
    f.cen += T.plate_box("plate", K.Face(mid.at(0.27, 0.0, 0.05), mid.u * 0.46, mid.v), 0.0, 0.0, 1.0, 1.0, m)
    return f.objects()


# ----------------------------------------------------------------------------- caixa alta (054–058)

def fb_box_amber(m):
    f = _box(m)
    f.signals(s0=0.08, s1=0.92, t0=0.15, t1=0.75)
    _, mt, _ = f.band("top")
    f.top += Q.square_amber("amber4", mt, 0.10, 0.18, 0.90, 0.80, 4, 1, m, fill=0.62)
    f.mid += _stripes(f, m["neon"], ts=((0.08, 0.16),), s0=0.0, s1=1.0, middle=True, wings=False)
    f.mid += _stripes(f, m["trim"], ts=((0.25, 0.95),), s0=0.02, s1=0.20, middle=True, wings=False)
    f.mid += _stripes(f, m["trim"], ts=((0.25, 0.95),), s0=0.80, s1=0.98, middle=True, wings=False)
    _, cm, _ = f.center_face(0.24)
    f.cen += T.plate_box("plate", K.Face(cm.at(0.39, 0.0, 0.06), cm.u * 0.22, cm.v), 0.0, 0.0, 1.0, 1.0, m)
    f.cen.append(K.quad_panel("plate_post", cm, 0.40, 0.2, 0.60, 0.8, m["chrome"], off=0.0, depth=0.06))
    return f.objects()


def fb_box_steps(m):
    f = _box(m, t=0.14, mm=0.30, b=0.14, D=0.36)
    f.signals(s0=0.08, s1=0.92, t0=0.15, t1=0.78)
    # degraus nas pontas: blocos mais baixos e mais para a frente embaixo (faixa de baixo)
    for k, sx in enumerate((1, -1)):
        x = sx * (W / 2 - 0.22)
        f.bot.append(M.box(f"step_{k}", (0.40, 0.20, 0.10), (x, 0.36 + 0.09, -f.H + 0.06), m["body"], bevel=0.012, seg=1))
        f.bot.append(M.box(f"step_tread_{k}", (0.42, 0.21, 0.016), (x, 0.36 + 0.09, -f.H + 0.115), m["chrome"], bevel=0.004, seg=1))
    f.mid += _stripes(f, m["trim"], ts=((0.15, 0.35), (0.55, 0.75)), s0=0.03, s1=0.30, middle=True, wings=False)
    f.mid += _stripes(f, m["trim"], ts=((0.15, 0.35), (0.55, 0.75)), s0=0.70, s1=0.97, middle=True, wings=False)
    _, mt, _ = f.band("top")
    f.top += Q.square_amber("amber_t", mt, 0.12, 0.2, 0.88, 0.8, 8, 1, m, fill=0.6)
    f.plate(h=0.24, s0=0.37, s1=0.63)
    return f.objects()


def fb_smooth_chrome(m):
    f = _box(m, t=0.14, mm=0.26, b=0.12, D=0.34, ch=0.16, body=m["chrome"])
    f.signals(s0=0.10, s1=0.90, t0=0.2, t1=0.8)
    f.mid += _stripes(f, m["trim"], ts=((0.46, 0.54),), s0=0.0, s1=1.0, middle=True, wings=True, depth=0.006)
    f.plate(h=0.22, s0=0.38, s1=0.62)
    return f.objects()


# ----------------------------------------------------------------------------- deque de chapa xadrez (059–062)

def _deck(m, t=0.14, mm=0.24, b=0.10):
    D, De, c = 0.46, 0.26, 0.50
    f = _fan(m, t=t, mm=mm, b=b, D=D, De=De, c=c)
    # tampa de chapa xadrez (dá para pisar), um pouco saltada para a frente: por cima do friso de cima
    poly = Q.fan_poly(W - 0.04, D + 0.03, De + 0.02, c)
    deck = Q.prism("deck", poly, -0.004, 0.012, m["checker"])
    _uv_planar(deck, 0.30)
    f.top.append(deck)
    return f


def _uv_planar(o, tile):
    me = o.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (co.x / tile, co.y / tile)


def fb_deck_checker(m):
    f = _deck(m)
    f.signals()
    f.mid += _stripes(f, m["trim"], ts=((0.12, 0.30), (0.42, 0.60), (0.72, 0.90)), s0=0.06, s1=0.55)
    r, mid, l = f.center_face(0.20)
    f.cen.append(K.quad_panel("grille_back", r, 0.62, 0.0, 0.97, 1.0, m["trim"], off=0.008, depth=0.012))
    f.cen.append(K.quad_panel("grille_back_l", l, 0.03, 0.0, 0.38, 1.0, m["trim"], off=0.008, depth=0.012))
    for k in range(4):
        tt = 0.14 + 0.72 * k / 3
        f.cen.append(K.bar_on(f"gr_r{k}", r, 0.63, tt - 0.04, 0.96, tt + 0.04, m["chrome"], off=0.010, depth=0.014))
        f.cen.append(K.bar_on(f"gr_l{k}", l, 0.04, tt - 0.04, 0.37, tt + 0.04, m["chrome"], off=0.010, depth=0.014))
    f.plate(h=0.22, s0=0.22, s1=0.78)
    return f.objects()


def fb_deck_neon(m):
    f = _deck(m, mm=0.26)
    f.signals()
    r, mid, l = f.band("mid")
    for k, (a, b) in enumerate(((0.10, 0.42), (0.58, 0.90))):
        f.mid.append(K.bar_on(f"neon_r{k}", r, 0.05, a, 0.40, b, m["neon"], depth=0.010))
        f.mid.append(K.bar_on(f"neon_l{k}", l, 0.60, a, 0.95, b, m["neon"], depth=0.010))
        f.mid.append(K.bar_on(f"neon_r2{k}", r, 0.48, a, 0.95, b, m["neon"], depth=0.010))
        f.mid.append(K.bar_on(f"neon_l2{k}", l, 0.05, a, 0.52, b, m["neon"], depth=0.010))
    rb, mb, lb = f.band("bot")
    f.bot.append(K.bar_on("neon_low", mb, 0.02, 0.35, 0.98, 0.65, m["neon"], depth=0.008))
    f.plate(h=0.22, neon=True)
    return f.objects()


def _p(pid, name, build, caps, vfit, color="prata_marinho"):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": False, "default_color": color,
            "slot": "front_bumper", "socket": "front_bumper", "nominal_w": NOMINAL_W, "fit": "bumper", "vfit": vfit,
            "folder": "front_t233"}


FAN = {"top": 0.13, "mid": 0.20, "bot": 0.09}
FAN22 = {"top": 0.13, "mid": 0.22, "bot": 0.09}
PARTS = [
    _p("fb_fan_plate", "Leque baixo com placa", fb_fan_plate, "044-045", FAN),
    _p("fb_fan_amber", "Leque com caixas âmbar", fb_fan_amber, "046-047", FAN22),
    _p("fb_fan_red", "Leque de luz vermelha", fb_fan_red, "048", FAN),
    _p("fb_fan_gold", "Leque de caixas douradas", fb_fan_gold, "049-050", FAN22),
    _p("fb_fan_stripe", "Leque de faixas rosa", fb_fan_stripe, "051, 053", FAN),
    _p("fb_fan_chrome", "Leque cromado", fb_fan_chrome, "052", FAN22, color="cromo_ciano"),
    _p("fb_box_amber", "Caixa alta âmbar", fb_box_amber, "054-055", {"top": 0.16, "mid": 0.30, "bot": 0.12}, color="preto_ciano"),
    _p("fb_box_steps", "Caixa alta com degraus", fb_box_steps, "056-057", {"top": 0.14, "mid": 0.30, "bot": 0.14}),
    _p("fb_smooth_chrome", "Cromado liso", fb_smooth_chrome, "058", {"top": 0.14, "mid": 0.26, "bot": 0.12}, color="cromo_ciano"),
    _p("fb_deck_checker", "Deque de chapa xadrez", fb_deck_checker, "059-060", {"top": 0.14, "mid": 0.24, "bot": 0.10}),
    _p("fb_deck_neon", "Deque xadrez com neon largo", fb_deck_neon, "061-062", {"top": 0.14, "mid": 0.26, "bot": 0.10},
       color="preto_ciano"),
]
