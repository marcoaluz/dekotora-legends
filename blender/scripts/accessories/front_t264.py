"""Para-choques GRANDES da frente (T-264, capturas 054–062): dobram a quina da cabine e correm pela lateral até a roda.

Origem = encaixe "front_bumper" (TOPO, centro, COSTAS na frente do nariz de fábrica, como a T-233). +Y frente, +X
direita, +Z cima. Planta em "U": corpo na frente (até y = D) e uma ABA de cada lado, de espessura WT, atrás das costas
(y de 0 até -WL). O jogo (`game/scripts/truck/bumper_wrap.gd`):
  - encosta o lado de dentro da aba (x = ±XB) na lateral medida de cada cabine (estica só a faixa |x| de XA a XB);
  - estica a aba até a roda (ou até a porta) e só DESLOCA os últimos `end` m da aba (faixa da ponta não deforma);
  - estica a faixa do meio (MID_) na altura como a T-233 (TOP_/MID_/BOT_/CEN_), até `target` m quando o farol deixa.
Grupos L* (LTOP_/LMID_/LBOT_/LCEN_) = malha simples (LOD) que o jogo mostra de longe.
Desenho nosso, a partir da FORMA e das cores das capturas (nada copiado): caixa alta de painéis (054–055), torre da placa
com faixas e colchetes (056–057), cromado envolvente (058), deque xadrez de 4 painéis (059–060) e de painéis largos
(061–062). Painéis/faixas = neon (cor do LED/neon separada da cor da peça), estrutura = cor da peça (L/R).
"""
from __future__ import annotations

import math

import bmesh

from lib import mesh3d as M

from . import t211_kit as K
from . import t231_kit as T
from . import t233_kit as Q

W = 2.56            # largura nominal do corpo (a aba fica de XB a W/2)
WT = 0.10           # espessura da aba (= socket_rules.WRAP_T)
XB = W / 2 - WT     # lado de dentro da aba (o jogo encosta na lataria)
WL = 0.60           # comprimento nominal da aba atrás das costas
NOMINAL_W = 2.30
LIP = 0.014


def u_poly(front, d=0.0, wl=WL):
    """Planta em U no sentido anti-horário (vista de cima). `front` = contorno da frente da direita (+X) para a
    esquerda, começando e terminando nas laterais (x = ±W/2). `d` = friso: só o lado de FORA cresce."""
    fr = []
    for x, y in front:
        fr.append((x + (d if x > 0.01 else (-d if x < -0.01 else 0.0)), y + d))
    return [(XB, -wl), (W / 2 + d, -wl)] + fr + [(-W / 2 - d, -wl), (-XB, -wl), (-XB, 0.0), (XB, 0.0)]


def loft(name, p0, z0, p1, z1, mat, top=True, bottom=True):
    """Como `t233_kit.prism`, mas com um polígono embaixo (p0, em z0) e outro em cima (p1, em z1): frente inclinada."""
    bm = bmesh.new()
    a = [bm.verts.new((x, y, z0)) for x, y in p0]
    b = [bm.verts.new((x, y, z1)) for x, y in p1]
    n = len(p0)
    for k in range(n):
        bm.faces.new([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
    if bottom:
        bm.faces.new(list(reversed(a)))
    if top:
        bm.faces.new(b)
    return M._link(name, bm, mat)


class Big:
    """Corpo em U de 3 faixas (`t`, `mm`, `b` = alturas de cima, do meio e de baixo). `lean` = quanto a frente recua
    por metro de descida (deque: a frente embaixo fica mais para trás que a chapa de cima)."""

    def __init__(self, m, front, t, mm, b, body=None, lod=False, deck=False, end=0.10, lean=0.0):
        self.m, self.front, self.t, self.mm, self.b, self.lod, self.end = m, front, t, mm, b, lod, end
        self.lean = lean
        self.H = t + mm + b
        body = body or m["body"]
        cap = -0.018 if deck else 0.0             # (deque: a chapa xadrez é a tampa de cima)
        P = self.poly

        def band(name, z0, z1, mat, d=0.0, top=False, bottom=False):
            return loft(name, P(z0, d), z0, P(z1, d), z1, mat, top, bottom)
        if lod:                                   # malha simples: um prisma por faixa, com tampas
            self.top = [band("top", -t, cap, body, top=not deck)]
            self.mid = [band("mid", -t - mm, -t, body)]
            self.bot = [band("bot", -self.H, -t - mm, body, bottom=True)]
        else:
            self.top = [band("top", -t, -0.006 if not deck else cap, body)]
            if not deck:
                self.top.append(band("lip_t", -0.024, 0.0, m["chrome"], LIP, True, True))
            self.mid = [band("mid", -t - mm, -t, body)]
            self.bot = [band("bot", -self.H + 0.006, -t - mm, body),
                        band("lip_b", -self.H, -self.H + 0.026, m["chrome"], LIP, True, True)]
        if deck:                                  # tampa de chapa xadrez (dá para pisar) por cima de tudo, abas inclusive
            dk = Q.prism("deck", u_poly(front, 0.022), cap, 0.0, m["checker"])
            _uv_planar(dk, 0.30)
            self.top.append(dk)
        self.cen = []
        self.extra = []

    def front_at(self, z):
        return [(x, y + self.lean * z) for x, y in self.front]

    def poly(self, z, d=0.0):
        return u_poly(self.front_at(z), d)

    # --- faixas e faces
    def z(self, which):
        return {"top": (-self.t, 0.0), "mid": (-self.t - self.mm, -self.t), "bot": (-self.H, -self.t - self.mm),
                "all": (-self.H, 0.0)}[which]

    def fronts(self, which, z=None):
        """Faces da frente (um segmento do contorno cada), da direita para a esquerda (u de +X para -X)."""
        z0, z1 = z or self.z(which)
        dy = self.lean * (z1 - z0)
        out = []
        for (xa, ya), (xb, yb) in zip(self.front_at(z0)[:-1], self.front_at(z0)[1:]):
            out.append(K.Face((xa, ya, z0), (xb - xa, yb - ya, 0), (0, dy, z1 - z0)))
        return out

    def wing(self, side, which, z=None):
        """Face de fora da aba (lado `side` = 1 direita / -1 esquerda), de trás (-WL) até a frente da lateral."""
        z0, z1 = z or self.z(which)
        fr = self.front_at(z0)
        if side > 0:
            y0 = fr[0][1]
            return K.Face((W / 2, -WL, z0), (0, WL + y0, 0), (0, 0, z1 - z0))
        y0 = fr[-1][1]
        return K.Face((-W / 2, y0, z0), (0, -(WL + y0), 0), (0, 0, z1 - z0))

    def wing_s(self, side, y, which="mid"):
        """s da face da aba (da faixa `which`) para um y (frente = +Y)."""
        fr = self.front_at(self.z(which)[0])
        if side > 0:
            return (y + WL) / (WL + fr[0][1])
        return (fr[-1][1] - y) / (WL + fr[-1][1])

    def end_y(self):
        """y no meio da ponta da aba (região que o jogo só desloca)."""
        return -WL + self.end / 2

    def signals(self, idx_r=0, idx_l=-1, s0=0.18, s1=0.82, t0=0.22, t1=0.80):
        """Lentes da seta nas faces das quinas (faixa de cima) + pontos SIGNAL_R / SIGNAL_L."""
        fs = self.fronts("top")
        # (a face da esquerda vai de dentro para fora: o mesmo lugar espelhado é 1 - s)
        for nm, f, (a, b) in (("R", fs[idx_r], (s0, s1)), ("L", fs[idx_l], (1.0 - s1, 1.0 - s0))):
            o, c, size = Q.signal_lens("signal_" + nm.lower(), f, a, t0, b, t1, self.m)
            self.top += [] if self.lod else o
            self.extra.append(Q.signal("SIGNAL_" + nm, c, size))

    def plate(self, face_idx, h=0.25, s0=0.30, s1=0.70, neon=False):
        f = self.fronts("mid")[face_idx]
        t0 = 0.5 - h / (2 * self.mm)
        f = K.Face(f.at(0, t0), f.u, f.v * (h / self.mm))
        if self.lod:
            self.cen.append(K.quad_panel("plate_back", f, s0, 0.0, s1, 1.0, self.m["trim"], off=0.006, depth=0.01))
            self.cen.append(K.quad_panel("plate", f, s0 + 0.04, 0.12, s1 - 0.04, 0.82, self.m["plate"], off=0.018, depth=0.008))
        else:
            self.cen += T.plate_box("plate", f, s0, 0.0, s1, 1.0, self.m, neon=neon)

    def objects(self):
        return Q.tag(self.top, "TOP") + Q.tag(self.mid, "MID") + Q.tag(self.bot, "BOT") + Q.tag(self.cen, "CEN") + self.extra


def _uv_planar(o, tile):
    me = o.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (co.x / tile, co.y / tile)


def _bolts(name, face, pts, m, r=0.014):
    """Parafusos cromados (cilindro de 6 lados) na face, nos pontos (s, t)."""
    out = []
    n = face.n
    axis = "Y" if abs(n.y) > 0.9 else ("X" if abs(n.x) > 0.9 else None)
    if axis is None:
        return out
    for k, (s, t) in enumerate(pts):
        c = face.at(s, t, 0.006)
        out.append(M.cylinder(f"{name}{k}", r, 0.014, tuple(c), m["chrome"], axis=axis, seg=6))
    return out


def _slash(name, face, s0, s1, t0, t1, lean, mat, off=0.016):
    """Faixa inclinada ("/") na face: paralelogramo de s0..s1 embaixo, deslocado `lean` em cima."""
    p = [face.at(s0, t0, off), face.at(s1, t0, off), face.at(s1 + lean, t1, off), face.at(s0 + lean, t1, off)]
    back = [q - face.n * 0.012 for q in p]
    return K.mesh_from(name, p + back, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], mat)


# ----------------------------------------------------------------------------- 054–055: caixa alta de painéis

def fb_wrap_lamps(m, lod=False):
    D, ch = 0.40, 0.07
    front = [(W / 2, D - ch), (W / 2 - ch, D), (-W / 2 + ch, D), (-W / 2, D - ch)]
    f = Big(m, front, 0.15, 0.40, 0.10, lod=lod)
    f.signals(0, 2)
    tr, tm, tl = f.fronts("top")
    mr, mm, ml = f.fronts("mid")
    panels = ((0.10, 0.36), (0.64, 0.90))          # metade direita e esquerda da face da frente (u de +X para -X)
    for k, (a, b) in enumerate(panels):
        # painel de luz (neon) na parte de baixo, com moldura cromada, e 2 lâmpadas âmbar quadradas em cima dele
        f.mid.append(K.quad_panel(f"panel_bg{k}", mm, a, 0.06, b, 0.62, m["trim"], off=0.006, depth=0.010))
        f.mid.append(K.bar_on(f"panel{k}", mm, a + 0.012, 0.12, b - 0.012, 0.56, m["neon"], off=0.004, depth=0.012))
        aa = a + 0.01 if k == 0 else b - 0.01 - 0.15
        f.mid.append(K.quad_panel(f"lampbox{k}", mm, aa, 0.70, aa + 0.15, 0.97, m["trim"], off=0.006, depth=0.010))
        if not lod:
            f.mid += K.frame_on(f"panel_fr{k}", mm, a, 0.06, b, 0.62, 0.008, 0.03, m["chrome"], off=0.008, depth=0.022)
            f.mid += Q.square_amber(f"amber{k}", mm, aa + 0.01, 0.73, aa + 0.14, 0.94, 2, 1, m, fill=0.82)
            f.top.append(K.quad_panel(f"lampbar{k}", tm, a, 0.20, b, 0.80, m["trim"], off=0.004, depth=0.008))
            f.top += _bolts(f"bolt_t{k}_", tm, [(a + 0.02, 0.5), ((a + b) / 2, 0.5), (b - 0.02, 0.5)], m, r=0.012)
            f.mid += _bolts(f"bolt_m{k}_", mm, [(a + 0.004, 0.66), (b - 0.004, 0.66)], m, r=0.011)
    # meio: grade de lâminas cromadas atrás da placa
    f.mid.append(K.quad_panel("grille_bg", mm, 0.40, 0.04, 0.60, 0.96, m["trim"], off=0.004, depth=0.010))
    if not lod:
        for k in range(6):
            s = 0.405 + 0.19 * k / 5
            f.mid.append(K.bar_on(f"slat{k}", mm, s - 0.004, 0.06, s + 0.004, 0.94, m["chrome"], off=0.008, depth=0.012))
        f.top += _bolts("bolt_c", tm, [(0.43, 0.5), (0.57, 0.5)], m)
    f.plate(1, h=0.24, s0=0.415, s1=0.585)
    # faixas verticais de neon: quina da frente e ponta da aba (perto da roda)
    for side, face in ((1, mr), (-1, ml)):
        f.mid.append(K.bar_on(f"corner_neon{side}", face, 0.30, 0.06, 0.70, 0.94, m["neon"], depth=0.012))
        wf = f.wing(side, "mid")
        sc_ = f.wing_s(side, f.end_y())
        dw = 0.035 / wf.u.length
        f.mid.append(K.bar_on(f"end_neon{side}", wf, sc_ - dw, 0.06, sc_ + dw, 0.94, m["neon"], depth=0.012))
        if not lod:
            # friso cromado ao longo da aba (topo do meio) e chapa de chute escura embaixo
            f.mid.append(K.bar_on(f"wing_trim{side}", wf, 0.0, 0.93, 1.0, 0.985, m["chrome"], off=0.004, depth=0.008))
            f.bot.append(K.quad_panel(f"kick{side}", f.wing(side, "bot"), 0.0, 0.25, 1.0, 0.75, m["trim"], off=0.004, depth=0.006))
    if not lod:
        f.bot.append(K.quad_panel("kick_front", f.fronts("bot")[1], 0.02, 0.25, 0.98, 0.75, m["trim"], off=0.004, depth=0.006))
        f.mid.append(K.bar_on("front_trim", mm, 0.0, 0.955, 1.0, 0.99, m["chrome"], off=0.004, depth=0.008))
    return f.objects()


# ----------------------------------------------------------------------------- 056–057: torre da placa com faixas

def fb_wrap_tower(m, lod=False):
    Ds, Dc, cw, ch = 0.28, 0.50, 0.30, 0.12
    front = [(W / 2, Ds - ch), (W / 2 - ch, Ds), (cw, Ds), (cw, Dc), (-cw, Dc), (-cw, Ds), (-W / 2 + ch, Ds), (-W / 2, Ds - ch)]
    f = Big(m, front, 0.12, 0.42, 0.10, lod=lod)
    f.signals(0, 6, t0=0.18, t1=0.82)
    mids = f.fronts("mid")
    tops = f.fronts("top")
    stripes = ((0.16, 0.38), (0.62, 0.84))
    # faixas de neon: blocos laterais, quinas chanfradas e abas (correm até a ponta, onde fecham num colchete)
    for k, (a, b) in enumerate(stripes):
        f.mid.append(K.bar_on(f"stripe_r{k}", mids[1], 0.0, a, 0.96, b, m["neon"], depth=0.012))
        f.mid.append(K.bar_on(f"stripe_l{k}", mids[5], 0.04, a, 1.0, b, m["neon"], depth=0.012))
        f.mid.append(K.bar_on(f"stripe_cr{k}", mids[0], 0.0, a, 1.0, b, m["neon"], depth=0.012))
        f.mid.append(K.bar_on(f"stripe_cl{k}", mids[6], 0.0, a, 1.0, b, m["neon"], depth=0.012))
        for side in (1, -1):
            wf = f.wing(side, "mid")
            se = f.wing_s(side, -WL + 0.07)
            s_a, s_b = (se, 1.0) if side > 0 else (0.0, se)
            f.mid.append(K.bar_on(f"stripe_w{side}_{k}", wf, s_a, a, s_b, b, m["neon"], depth=0.012))
    for side in (1, -1):                           # colchete vertical na ponta da aba
        wf = f.wing(side, "mid")
        se = f.wing_s(side, -WL + 0.05)
        dw = 0.025 / wf.u.length
        f.mid.append(K.bar_on(f"end_v{side}", wf, se - dw, 0.12, se + dw, 0.88, m["neon"], depth=0.012))
    # torre: placa no meio, grade em cima, laterais com faixa fina
    tf = mids[3]
    # (a frente da torre fica na cor da peça: caixa clara na prata/marinho, escura na preto/ciano, como 056/057)
    f.plate(3, h=0.24, s0=0.14, s1=0.86)
    if not lod:
        tt = tops[3]
        for k in range(5):
            s = 0.16 + 0.68 * k / 4
            f.top.append(K.bar_on(f"tower_slat{k}", tt, s - 0.012, 0.18, s + 0.012, 0.82, m["chrome"], off=0.006, depth=0.012))
        f.top.append(K.quad_panel("tower_grille_bg", tt, 0.10, 0.12, 0.90, 0.88, m["trim"], off=0.004, depth=0.008))
        for nm, fi in (("tside_r", 2), ("tside_l", 4)):
            f.mid.append(K.bar_on(nm, mids[fi], 0.25, 0.20, 0.75, 0.80, m["neon"], depth=0.010))
        # LED de marcação (cor do LED) na faixa de cima dos blocos laterais
        f.top.append(K.led_grid("led_r", tops[1], 0.10, 0.25, 0.90, 0.75, 7, 1, m["led"], fill=0.55, off=0.010, depth=0.010))
        f.top.append(K.led_grid("led_l", tops[5], 0.10, 0.25, 0.90, 0.75, 7, 1, m["led"], fill=0.55, off=0.010, depth=0.010))
        f.top += _bolts("bolt_tr", tops[1], [(0.04, 0.5), (0.96, 0.5)], m)
        f.top += _bolts("bolt_tl", tops[5], [(0.04, 0.5), (0.96, 0.5)], m)
        for side in (1, -1):
            f.bot.append(K.quad_panel(f"kick{side}", f.wing(side, "bot"), 0.0, 0.25, 1.0, 0.75, m["trim"], off=0.004, depth=0.006))
        for fi in (1, 3, 5):
            f.bot.append(K.quad_panel(f"kick_f{fi}", f.fronts("bot")[fi], 0.02, 0.25, 0.98, 0.75, m["trim"], off=0.004, depth=0.006))
    return f.objects()


# ----------------------------------------------------------------------------- 058: cromado envolvente

def _round_front(D, r, n=4, c=None):
    """Frente reta com as quinas arredondadas (raio r, n segmentos), da direita para a esquerda."""
    pts = [(W / 2, D - r)]
    for k in range(1, n):
        a = math.radians(90.0 * k / n)
        pts.append((W / 2 - r + r * math.cos(a), D - r + r * math.sin(a)))
    pts.append((W / 2 - r, D))
    if c:
        pts.append((c, D))
    return pts + [(-x, y) for x, y in reversed(pts)]


def fb_wrap_chrome(m, lod=False):
    D, r = 0.36, 0.16
    front = _round_front(D, r, 4, c=0.30)
    f = Big(m, front, 0.12, 0.44, 0.10, body=m["chrome"], lod=lod)
    n = len(front) - 1
    mid_idx = n // 2                               # segmento reto do meio (|x| <= c)
    f.signals(0, n - 1, s0=0.10, s1=0.90, t0=0.25, t1=0.80)
    # frisos (sulcos) na cor da peça ao longo de toda a frente e das abas
    grooves = ((0.22, 0.30), (0.50, 0.58), (0.78, 0.86))
    faces = f.fronts("mid")
    for k, (a, b) in enumerate(() if lod else grooves):
        for i, fc in enumerate(faces):
            if i == mid_idx:
                for nm, (s0, s1) in (("a", (0.0, 0.18)), ("b", (0.82, 1.0))):
                    f.mid.append(K.bar_on(f"groove{k}_{i}{nm}", fc, s0, a, s1, b, m["trim"], off=0.002, depth=0.006))
                continue
            f.mid.append(K.bar_on(f"groove{k}_{i}", fc, 0.0, a, 1.0, b, m["trim"], off=0.002, depth=0.006))
        for side in (1, -1):
            wf = f.wing(side, "mid")
            se = f.wing_s(side, -WL + 0.06)
            s_a, s_b = (se, 1.0) if side > 0 else (0.0, se)
            f.mid.append(K.bar_on(f"groove_w{side}_{k}", wf, s_a, a, s_b, b, m["trim"], off=0.002, depth=0.006))
    # placa no meio, numa caixa rebaixada; luz fina de neon embaixo (de dia/de noite)
    f.mid.append(K.quad_panel("plate_bay", faces[mid_idx], 0.04, 0.10, 0.96, 0.90, m["trim"], off=0.002, depth=0.008))
    f.plate(mid_idx, h=0.24, s0=0.12, s1=0.88)
    f.bot.append(K.bar_on("neon_low", f.fronts("bot")[mid_idx], 0.02, 0.40, 0.98, 0.60, m["neon"], off=0.002, depth=0.006))
    if not lod:
        tops = f.fronts("top")
        for i in (1, len(tops) - 2):
            f.top += Q.round_amber(f"marker{i}", tops[i], [(0.5, 0.5)], 0.03, m)
        # (sem lâmpada na lateral da aba: sairia da caixa do encaixe, que vai só até a espessura da aba)
    return f.objects()


# ----------------------------------------------------------------------------- 059–062: deques de chapa xadrez

def _deck_front(D=0.56, De=0.22, c=0.86):
    return [(W / 2, De), (c, D), (-c, D), (-W / 2, De)]


def fb_wrap_deck4(m, lod=False):
    front = _deck_front(D=0.52, De=0.20, c=0.66)
    f = Big(m, front, 0.10, 0.30, 0.08, lod=lod, deck=True, end=0.24, lean=0.24)
    f.signals(0, 2, s0=0.04, s1=0.20, t0=0.18, t1=0.82)
    cr, mm, cl = f.fronts("mid")
    # 2 painéis empilhados de cada lado (neon) em caixas da cor da peça, grade com a placa no meio
    for k, (a, b) in enumerate(((0.05, 0.36), (0.64, 0.95))):
        for j, (t0, t1) in enumerate(((0.10, 0.44), (0.56, 0.90))):
            f.mid.append(K.quad_panel(f"box{k}{j}", mm, a, t0, b, t1, m["trim"], off=0.004, depth=0.010))
            f.mid.append(K.bar_on(f"panel{k}{j}", mm, a + 0.012, t0 + 0.045, b - 0.012, t1 - 0.045, m["neon"], off=0.004, depth=0.012))
            if not lod:
                f.mid += K.frame_on(f"pfr{k}{j}", mm, a, t0, b, t1, 0.006, 0.025, m["chrome"], off=0.008, depth=0.020)
    f.mid.append(K.quad_panel("grille_bg", mm, 0.385, 0.04, 0.615, 0.96, m["trim"], off=0.004, depth=0.010))
    if not lod:
        for k in range(7):
            s = 0.39 + 0.22 * k / 6
            f.mid.append(K.bar_on(f"slat{k}", mm, s - 0.004, 0.06, s + 0.004, 0.94, m["chrome"], off=0.008, depth=0.014))
    f.plate(1, h=0.22, s0=0.40, s1=0.60)
    # quinas em ângulo: faixa vertical de neon na borda de fora; aba: barra "/" de neon perto da roda
    for side, face in ((1, cr), (-1, cl)):
        a, b = (0.04, 0.16) if side > 0 else (0.84, 0.96)
        f.mid.append(K.bar_on(f"corner_neon{side}", face, a, 0.06, b, 0.94, m["neon"], depth=0.012))
        wf = f.wing(side, "mid")
        sc_ = f.wing_s(side, -WL + 0.13)                          # (dentro da ponta, que o jogo só desloca)
        dw = 0.03 / wf.u.length
        lean = 0.16 / wf.u.length * (1 if side > 0 else -1)        # "/" bem inclinado (captura 060)
        f.mid.append(_slash(f"slash{side}", wf, sc_ - dw - lean / 2, sc_ + dw - lean / 2, 0.06, 0.94, lean, m["neon"]))
        if not lod:
            f.bot.append(K.quad_panel(f"kick{side}", f.wing(side, "bot"), 0.0, 0.2, 1.0, 0.8, m["trim"], off=0.004, depth=0.006))
            f.mid.append(K.bar_on(f"wing_trim{side}", wf, 0.0, 0.40, 1.0, 0.48, m["chrome"], off=0.002, depth=0.006))
    if not lod:
        f.bot.append(K.quad_panel("kick_front", f.fronts("bot")[1], 0.02, 0.2, 0.98, 0.8, m["trim"], off=0.004, depth=0.006))
        f.top += _bolts("bolt", f.fronts("top")[1], [(0.04, 0.5), (0.30, 0.5), (0.70, 0.5), (0.96, 0.5)], m, r=0.012)
    return f.objects()


def fb_wrap_deck_wide(m, lod=False):
    front = _deck_front(D=0.52, De=0.22, c=0.72)
    f = Big(m, front, 0.10, 0.30, 0.08, lod=lod, deck=True, end=0.10, lean=0.24)
    f.signals(0, 2, s0=0.04, s1=0.22, t0=0.18, t1=0.82)
    cr, mm, cl = f.fronts("mid")
    # um painel largo de neon de cada lado, que dobra a quina (continua na face em ângulo)
    for k, (a, b) in enumerate(((0.03, 0.37), (0.63, 0.97))):
        f.mid.append(K.quad_panel(f"box{k}", mm, a, 0.08, b, 0.92, m["trim"], off=0.004, depth=0.010))
        f.mid.append(K.bar_on(f"panel{k}", mm, a + 0.015, 0.16, b - 0.015, 0.84, m["neon"], off=0.004, depth=0.012))
        if not lod:
            f.mid += K.frame_on(f"pfr{k}", mm, a, 0.08, b, 0.92, 0.006, 0.025, m["chrome"], off=0.008, depth=0.020)
    for side, face in ((1, cr), (-1, cl)):
        a, b = (0.30, 0.94) if side > 0 else (0.06, 0.70)
        f.mid.append(K.quad_panel(f"cbox{side}", face, a, 0.08, b, 0.92, m["trim"], off=0.004, depth=0.010))
        f.mid.append(K.bar_on(f"cpanel{side}", face, a + 0.03, 0.16, b - 0.03, 0.84, m["neon"], off=0.004, depth=0.012))
        e0, e1 = (0.04, 0.14) if side > 0 else (0.86, 0.96)
        if not lod:
            f.mid.append(K.bar_on(f"edge{side}", face, e0, 0.06, e1, 0.94, m["neon"], depth=0.012))
            f.mid += K.frame_on(f"cfr{side}", face, a, 0.08, b, 0.92, 0.012, 0.025, m["chrome"], off=0.008, depth=0.020)
            f.top += _bolts(f"cbolt{side}", f.fronts("top")[0 if side > 0 else 2], [(0.2, 0.5), (0.5, 0.5), (0.8, 0.5)], m, r=0.011)
        # aba: 3 faixas de neon até a ponta, fechadas por uma barra vertical
        wf = f.wing(side, "mid")
        se = f.wing_s(side, -WL + 0.07)
        s_a, s_b = (se, 0.97) if side > 0 else (0.03, se)
        for j, (t0, t1) in enumerate(((0.12, 0.26), (0.43, 0.57), (0.74, 0.88))):
            f.mid.append(K.bar_on(f"wstripe{side}_{j}", wf, s_a, t0, s_b, t1, m["neon"], depth=0.012))
        sv = f.wing_s(side, -WL + 0.045)
        dw = 0.022 / wf.u.length
        if not lod:
            f.mid.append(K.bar_on(f"wend{side}", wf, sv - dw, 0.08, sv + dw, 0.92, m["neon"], depth=0.012))
            f.mid.append(K.quad_panel(f"wbg{side}", wf, min(s_a, s_b), 0.06, max(s_a, s_b), 0.94, m["trim"], off=0.003, depth=0.006))
        if not lod:
            f.bot.append(K.quad_panel(f"kick{side}", f.wing(side, "bot"), 0.0, 0.2, 1.0, 0.8, m["trim"], off=0.004, depth=0.006))
    f.mid.append(K.quad_panel("grille_bg", mm, 0.39, 0.04, 0.61, 0.96, m["trim"], off=0.004, depth=0.010))
    if not lod:
        for k in range(4):
            t = 0.12 + 0.76 * k / 3
            f.mid.append(K.bar_on(f"hslat{k}", mm, 0.395, t - 0.02, 0.605, t + 0.02, m["chrome"], off=0.008, depth=0.014))
        f.top += _bolts("bolt", f.fronts("top")[1], [(0.03, 0.5), (0.36, 0.5), (0.64, 0.5), (0.97, 0.5)], m, r=0.012)
        f.bot.append(K.quad_panel("kick_front", f.fronts("bot")[1], 0.02, 0.2, 0.98, 0.8, m["trim"], off=0.004, depth=0.006))
    f.plate(1, h=0.22, s0=0.405, s1=0.595)
    return f.objects()


def _p(pid, name, build, caps, vfit, end=0.10, color="prata_marinho"):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": False, "default_color": color,
            "slot": "front_bumper", "socket": "front_bumper", "nominal_w": NOMINAL_W, "fit": "bumper",
            "vfit": dict(vfit, wrap={"xb": round(XB, 3), "wl": WL, "end": end}), "folder": "front_t264"}


PARTS = [
    _p("fb_wrap_lamps", "Caixa alta de painéis de luz", fb_wrap_lamps, "054-055",
       {"top": 0.15, "mid": 0.40, "bot": 0.10, "target": 0.82}, color="preto_ciano"),
    _p("fb_wrap_tower", "Torre da placa com faixas", fb_wrap_tower, "056-057",
       {"top": 0.12, "mid": 0.42, "bot": 0.10, "target": 0.78}),
    _p("fb_wrap_chrome", "Cromado envolvente", fb_wrap_chrome, "058",
       {"top": 0.12, "mid": 0.44, "bot": 0.10, "target": 0.78}, color="cromo_ciano"),
    _p("fb_wrap_deck4", "Deque xadrez de 4 painéis", fb_wrap_deck4, "059-060",
       {"top": 0.10, "mid": 0.30, "bot": 0.08, "target": 0.62}, end=0.24, color="preto_ciano"),
    _p("fb_wrap_deck_wide", "Deque xadrez de painéis largos", fb_wrap_deck_wide, "061-062",
       {"top": 0.10, "mid": 0.30, "bot": 0.08, "target": 0.62}),
]
