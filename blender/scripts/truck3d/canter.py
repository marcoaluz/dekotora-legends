"""Caminhão base "Canter" (T-125): caminhão leve japonês de ~7 m feito com a cabine, o chassi, o motor, a suspensão,
o tanque/caixa de ferramentas e a barra das lanternas do JAC 1045 (CGTrader, Royalty Free; marca apagada), mais o
NOSSO baú (mais alto e um pouco mais largo que a cabine, como nos caminhões leves japoneses), as nossas rodas
(o TruckNode gira os nós wheel_*) e a decoração Dekotora V7 (mural, fileiras de luzes, andons).

Medidas (m): comprimento 6,9 · cabine 2,1 de largura e 2,3 de altura · baú 2,3 x 5,0, piso 0,95, teto 3,0 ·
eixos em y = 1,77 (traseiro, rodado duplo) e 5,73 (dianteiro) · rodas de raio 0,45/0,43.
Os pontos de montagem das peças compráveis têm ESCALA (0,88 na cabine e nas rodas, 0,92 no baú): as peças feitas
para o caminhão grande (cabine de 2,4 m) encolhem junto e cabem no Canter sem modelo próprio.
"""
from __future__ import annotations

from lib import mesh3d as M

from . import jac_cab, jac_src
from .body import BoxDims, build_body
from .deco import build_deco
from .wheels import make_wheel

BOX_W, BOX_Z0, BOX_TOP = 2.3, 0.95, 3.0
GAP = 0.12                         # folga entre as costas da cabine e a frente do baú
FRONT_AXLE, REAR_AXLE = 5.73, 1.77
FRONT_R, REAR_R = 0.45, 0.43
FRONT_X, REAR_TX = 0.92, (0.725, 0.955)
FRONT_W, REAR_W = 0.28, 0.21
LENGTH = 6.9                       # do fim do baú (y = 0) até o para-choque (TruckNode.LENGTH_DELTA = LENGTH - 11,5)


class CanterInfo:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def build_canter(m, add, src=None) -> CanterInfo:
    jac = jac_cab.build_jac(m, add, jac_src.CANTER, groups=("cab", "chassis"), src=src)
    box = BoxDims(w=BOX_W, l=round(jac.y_back - GAP, 2), z0=BOX_Z0, top=BOX_TOP, rear_under=False)
    build_body(m, add, box)
    for sx in (-1, 1):                                    # neon sob o chassi (no caminhão grande vem com o baú)
        add(M.box(f"underglow_{sx}", (0.05, 4.6, 0.05), (sx * 0.86, 3.3, 0.3), m["lamp_cyan"], bevel=0.01, seg=1))
    wheels = []
    for sx in (-1, 1):
        side = "L" if sx < 0 else "R"
        wheels.append(make_wheel(f"wheel_f_{side}", (sx * FRONT_X, FRONT_AXLE, FRONT_R), m, rim=True, radius=FRONT_R, width=FRONT_W, seg=36))
        for tx in REAR_TX:
            wheels.append(make_wheel(f"wheel_r_{side}_{REAR_AXLE}_{tx}", (sx * tx, REAR_AXLE, REAR_R), m, rim=(tx > 0.9),
                                     radius=REAR_R, width=REAR_W, seg=36))
    build_deco(m, add, box.l, max(jac.top, BOX_TOP - 0.2), (jac.y_front, jac.wz0, jac.surf, jac.half_w / 1.2), box=box)
    return CanterInfo(jac=jac, box=box, wheels=wheels, mounts=_mounts(jac, box))


def _mounts(jac, b: BoxDims) -> dict:
    """{nome: (posição, escala)}: todos os nomes de dims.MOUNTS, nas posições do Canter."""
    s_cab = jac.mount_scale
    s_box = b.w / 2.5
    w2 = b.w / 2
    center = {
        "MOUNT_BODY_ROOF": ((0.0, b.l / 2, b.top), s_box),
        "MOUNT_REAR": ((0.0, 0.0, b.z0 - 0.4), s_box),
        "MOUNT_REAR_LAMPS": ((0.0, 0.0, b.kz(1.6)), s_box),
        "MOUNT_REAR_PLATE": ((0.0, 0.0, b.kz(1.0)), s_box),
        "MOUNT_REAR_PANEL": ((0.0, 0.0, b.kz(2.2)), s_box),
        "MOUNT_REAR_ROOF": ((0.0, 0.0, b.top), s_box),
    }
    side_r = {
        "MOUNT_SIDE_R": ((w2, (FRONT_AXLE + REAR_AXLE) / 2, b.z0 - 0.15), s_box),
        "MOUNT_FENDER_R": ((1.1, REAR_AXLE, REAR_R), s_cab),
        "MOUNT_SIDE_TRIM_R": ((w2, b.ky(1.2), b.kz(2.45)), s_box),
        "MOUNT_SIDE_BOX_R": ((w2, 2.85, 0.4), s_box),
        "MOUNT_SIDE_ORNAMENT_R": ((w2, b.ky(5.0), b.kz(2.3)), s_box),
        "MOUNT_SIDE_PANEL_R": ((w2, b.ky(4.1), b.kz(2.35)), s_box),
        "MOUNT_WHEEL_FRONT_R": ((FRONT_X, FRONT_AXLE, FRONT_R), s_cab),
        "MOUNT_WHEEL_FRONT_FACE_R": ((FRONT_X + FRONT_W / 2 + 0.015, FRONT_AXLE, FRONT_R), s_cab),
        "MOUNT_WHEEL_REAR_FACE_R": ((REAR_TX[1] + REAR_W / 2 + 0.015, REAR_AXLE, REAR_R), s_cab),
        "MOUNT_WHEEL_REAR_R": ((REAR_TX[1], REAR_AXLE, REAR_R), s_cab),
        "MOUNT_MUDFLAP_R": ((0.85, REAR_AXLE - 0.75, 0.6), s_cab),
    }
    out = dict(center)
    for n, (p, s) in side_r.items():
        out[n] = (p, s)
        out[n[:-1] + "L"] = ((-p[0], p[1], p[2]), s)
    for n, p in jac.mounts.items():                       # frente, teto, degrau e lateral da cabine
        out[n] = (p, s_cab)
    return out
