"""Baú premium (T-136): medidas e mapa do atlas, comuns à versão ALTA (só para gravar mapas) e à LEVE (jogo).

Tudo ao longo do baú é FRAÇÃO do comprimento (e as alturas, fração da parede via BoxDims.kz): o mesmo atlas gravado no
baú de referência (2,5 x 8,2 m, piso 1,1, teto 3,2) serve para o baú esticado das cabines curta/jac e para o Canter.
O número de nervuras da chapa ondulada é fixo (N_RIB); o passo acompanha o comprimento.

Atlas 1024 x 1024 (texturas tex_box_*.png; v para cima, convenção do Blender):
  v 0.00-0.25  teto                      v 0.25-0.30  faixas de chapa abaixo/acima do mural (L e R compartilham)
  v 0.30-0.37  trilhos de baixo e de cima v 0.37-0.47  montantes, colunas, travessa de cima e soleira
  u 0.0-0.6 x v 0.5-1.0  portas traseiras  u 0.6-0.85 x v 0.75-1.0  parede da frente
O mural (lados) tem mapas próprios (tex_box_mural_*.png, 1024 x 256), em UV 0..1 do mural.
"""
from __future__ import annotations

from lib.meshbuild import Rect

from .body import STD, BoxDims

N_RIB = 66                    # nervuras por lado (passo 0,12 m no baú de 8,2 m)
RIB_OUT, RIB_IN = 0.012, -0.010   # crista e vale em relação à face do baú (x = w/2)
RIB_T = (0.15, 0.30, 0.70, 0.85)  # dentro de cada passo: fim do vale, início da crista, fim da crista, início do vale
SIDE_Y0, SIDE_Y1 = 0.075, 0.055   # a chapa começa depois da coluna traseira e para antes da coluna da frente
Z_RAIL_LO, Z_MURAL0, Z_MURAL1, Z_RAIL_HI = 1.27, 1.365, 2.985, 3.04   # alturas no baú padrão (kz converte)
RAIL_OUT = 0.026              # quanto os trilhos saem da face
POST_FRAC = (1 / 3, 2 / 3)    # montantes laterais
DOOR_INSET = 0.13             # colunas traseiras: as portas ficam entre x = +-(w/2 - DOOR_INSET)
SILL_H, HEADER_H = 0.16, 0.17
REAR_Y = 0.0                  # plano das portas

ATLAS = 1024
MURAL_SIZE = (1024, 256)
_PAD = 4 / ATLAS
R_ROOF = Rect(0.0, 0.0, 1.0, 0.25)
R_SIDE_LO = Rect(0.0, 0.25, 1.0, 0.03)
R_SIDE_HI = Rect(0.0, 0.28, 1.0, 0.02)
R_RAIL_LO = Rect(0.0, 0.30, 1.0, 0.035)
R_RAIL_HI = Rect(0.0, 0.335, 1.0, 0.035)
R_POST = Rect(0.0, 0.37, 0.25, 0.05)
R_FRONT_POST = Rect(0.25, 0.37, 0.25, 0.05)
R_REAR_POST = Rect(0.5, 0.37, 0.25, 0.05)
R_HEADER = Rect(0.0, 0.42, 0.5, 0.025)
R_SILL = Rect(0.5, 0.42, 0.5, 0.025)
R_CAPS = Rect(0.75, 0.37, 0.25, 0.05)
R_DOORS = Rect(0.0, 0.5, 0.6, 0.5)
R_FRONT = Rect(0.6, 0.75, 0.25, 0.25)
R_CROSS = Rect(0.6, 0.5, 0.4, 0.05)


def pad(r: Rect) -> Rect:
    return Rect(r.u0 + _PAD, r.v0 + _PAD, r.w - 2 * _PAD, r.h - 2 * _PAD)


class Layout:
    """Posições do baú `b` (BoxDims). `k` = largura relativa ao baú padrão (Canter 0,92)."""

    def __init__(self, b: BoxDims = STD):
        self.b = b
        self.w2 = b.w / 2
        self.k = b.w / STD.w
        self.y0 = SIDE_Y0
        self.y1 = b.l - SIDE_Y1
        self.z_rail_lo = b.kz(Z_RAIL_LO)
        self.z_m0, self.z_m1 = b.kz(Z_MURAL0), b.kz(Z_MURAL1)
        self.z_rail_hi = b.kz(Z_RAIL_HI)
        self.door_x = self.w2 - DOOR_INSET * self.k
        self.z_door0 = b.z0 + SILL_H
        self.z_door1 = b.top - HEADER_H

    def rib_points(self, hi_res: int = 0):
        """Perfil da chapa ondulada ao longo de y: lista de (y, deslocamento em x). `hi_res` > 0 = versão alta
        (transições arredondadas com `hi_res` pontos por passo)."""
        p = (self.y1 - self.y0) / N_RIB
        pts = [(self.y0, RIB_IN)]
        for i in range(N_RIB):
            base = self.y0 + i * p
            if hi_res:
                for s in range(1, hi_res + 1):
                    t = s / hi_res
                    pts.append((base + t * p, _rib_round(t)))
            else:
                for t, off in zip(RIB_T, (RIB_IN, RIB_OUT, RIB_OUT, RIB_IN)):
                    pts.append((base + t * p, off))
                pts.append((base + p, RIB_IN))
        out = []
        for q in pts:                                     # sem pontos repetidos
            if not out or abs(q[0] - out[-1][0]) > 1e-6:
                out.append(q)
        return out

    def side_u(self, y: float) -> float:
        return (y - self.y0) / (self.y1 - self.y0)

    def post_ys(self):
        return [self.y0 + f * (self.y1 - self.y0) for f in POST_FRAC]


def _rib_round(t: float) -> float:
    """Perfil arredondado de uma nervura (0..1 dentro do passo): vale, subida suave, crista, descida."""
    a0, a1, b0, b1 = RIB_T
    if t <= a0 or t >= b1:
        return RIB_IN
    if a1 <= t <= b0:
        return RIB_OUT
    s = (t - a0) / (a1 - a0) if t < a1 else (b1 - t) / (b1 - b0)
    s = s * s * (3 - 2 * s)                               # smoothstep: canto arredondado
    return RIB_IN + (RIB_OUT - RIB_IN) * s
