"""Cabines do caminhão (cab-over): casca arredondada por loft + detalhes, em 4 estilos.

`build_cab(m, add, style)` cria tudo e entrega cada objeto para `add(obj)`. Todos os estilos mantêm a largura,
a frente (CAB_Y1), a grade e o para-choque nos mesmos lugares (as peças frontais servem em qualquer cabine);
o que muda é altura do teto, inclinação do para-brisa, arredondado, faróis, grade, para-choque e laterais.

| estilo   | ideia                                                                          |
| padrao   | cab-over arredondada (Volvo FH): grade alta, faróis envolventes, para-choque pintado |
| classica | quadrada e baixa (Volvo F7 / Mercedes Accelo): faróis redondos, grade com diagonal, para-choque cromado |
| aero     | aerodinâmica (Actros): para-brisa bem inclinado, faróis LED finos, aletas laterais |
| alta     | teto alto (sleeper): faixa de vidro superior, janela de dormitório, grande defletor |

Módulos (T-106): `cab_surface` (superfície e adesivos 3D que seguem a curva), `cab_front` (para-brisa, grade,
faróis, para-choque), `cab_doors` (portas, janelas, espelhos, degraus, para-lamas), `cab_roof` (teto e defletor).
"""
import math
from dataclasses import dataclass

from lib import mesh_adv as A

from .cab_doors import build_sides
from .cab_front import build_front
from .cab_roof import build_roof
from .cab_surface import Shell
from .dims import CAB_W, CAB_Y0, CAB_Y1, CAB_Z0, FRONT_AXLE_Y

# rf0/rf1 = raio do canto vertical da frente (embaixo / acréscimo em cima); bow = quanto as pontas da frente
# recuam (frente levemente curva vista de cima); rr = raio dos cantos de trás.
STYLES = {
    "padrao": dict(top=3.35, roof_r=0.2, inset=0.17, wz0=2.05, setback=0.36, rf0=0.3, rf1=0.1, taper=0.06, bow=0.05, rr=0.14),
    "classica": dict(top=3.2, roof_r=0.1, inset=0.06, wz0=2.05, setback=0.12, rf0=0.14, rf1=0.04, taper=0.03, bow=0.015, rr=0.08),
    "aero": dict(top=3.45, roof_r=0.34, inset=0.26, wz0=1.9, setback=0.75, rf0=0.36, rf1=0.16, taper=0.12, bow=0.08, rr=0.16),
    "alta": dict(top=3.9, roof_r=0.22, inset=0.17, wz0=2.15, setback=0.48, rf0=0.3, rf1=0.12, taper=0.07, bow=0.05, rr=0.14),
}
CAB_STYLES = tuple(STYLES)
ARCH_R = 0.66            # raio do recorte do arco da roda dianteira na casca
SIDE_STEPS = 32          # pontos ao longo de cada lateral (densos para o recorte do arco ficar redondo)


@dataclass
class Ctx:
    """Medidas derivadas do estilo: perfil da frente/lateral e mapeamento das alturas da parte alta."""
    name: str
    top: float
    roof_r: float
    inset: float
    wz0: float
    setback: float
    rf0: float
    rf1: float
    taper: float
    bow: float
    rr: float

    @property
    def wz1(self) -> float:                     # fim do trecho inclinado do para-brisa (começa o arredondado do teto)
        return self.top - self.roof_r

    @property
    def slope_deg(self) -> float:
        return math.degrees(math.atan2(self.setback, self.wz1 - self.wz0))

    def yf(self, z: float) -> float:
        """Y da face frontal (no centro) na altura z (antes do arredondado do teto)."""
        if z <= self.wz0:
            return CAB_Y1
        t = min(1.0, (z - self.wz0) / (self.wz1 - self.wz0))
        return CAB_Y1 - self.setback * t

    def hw(self, z: float) -> float:
        """Meia-largura na altura z (leve afunilamento para cima)."""
        if z <= 2.4:
            return CAB_W / 2
        return CAB_W / 2 - self.taper * min(1.0, (z - 2.4) / 0.8)

    def zm(self, z: float) -> float:
        """Mapeia alturas do desenho original (teto 3,35) para este teto: acima de 2,0 estica/encolhe."""
        return z if z <= 2.0 else 2.0 + (z - 2.0) * (self.top - 2.0) / 1.35


def make_ctx(style: str) -> Ctx:
    return Ctx(style, **STYLES[style])


def cab_mounts(style: str) -> dict:
    """Pontos de montagem que dependem do teto/para-brisa (os demais ficam como em dims.MOUNTS)."""
    c = make_ctx(style)
    return {"MOUNT_VISOR": (0.0, c.yf(c.wz1) + 0.05, c.top - 0.01), "MOUNT_ROOF": (0.0, 10.0, c.top),
            "MOUNT_ROOF_LIGHTS": (0.0, c.yf(c.wz1) - 0.17, c.top)}


# ---------------------------------------------------------------- casca

def _arch_z(y: float) -> float:
    dy = y - FRONT_AXLE_Y
    return 0.5 + math.sqrt(ARCH_R * ARCH_R - dy * dy) if abs(dy) < ARCH_R else -1.0


def _ring(c, sh, z, inset, lift):
    """Anel da casca na altura z (anti-horário visto de cima). `inset` encolhe (arredondado do teto/da base);
    `lift` = quanto esta linha fica acima da borda de baixo (o recorte do arco sobe junto)."""
    zc = min(z, c.wz1)
    hw = c.hw(zc) - inset
    yf = c.yf(zc) - inset
    rf = max(sh.rf(zc) - inset, 0.05)
    rr = max(c.rr - inset, 0.04)
    y0 = CAB_Y0 + inset
    bow = c.bow
    xe = hw - rf
    pts = []

    def put(x, y, side=False):
        zz = z
        if side and lift is not None:
            a = _arch_z(y)
            if a > 0:
                zz = max(z, a + lift)
        pts.append((x, y, zz))
    nc = 8
    ys_start = yf - bow - rf
    side_ys = [ys_start - (ys_start - (y0 + rr)) * k / SIDE_STEPS for k in range(1, SIDE_STEPS)]
    for k in range(nc + 1):                                   # canto dianteiro direito: lateral -> frente
        a = math.radians(90 - 90 * k / nc)
        put(xe + rf * math.sin(a), yf - bow - rf + rf * math.cos(a))
    for k in range(1, 8):                                     # frente (curva leve)
        q = 1 - 2 * k / 8
        put(q * xe, yf - bow * q * q)
    for k in range(nc + 1):                                   # canto dianteiro esquerdo
        a = math.radians(90 * k / nc)
        put(-(xe + rf * math.sin(a)), yf - bow - rf + rf * math.cos(a))
    for y in side_ys:                                         # lateral esquerda, para trás
        put(-hw, y, True)
    for k in range(7):                                        # canto traseiro esquerdo
        a = math.radians(180 + 90 * k / 6)
        put(-hw + rr + rr * math.cos(a), y0 + rr + rr * math.sin(a))
    for k in range(1, 6):                                     # traseira
        put(-hw + rr + (2 * hw - 2 * rr) * k / 6, y0)
    for k in range(7):                                        # canto traseiro direito
        a = math.radians(270 + 90 * k / 6)
        put(hw - rr + rr * math.cos(a), y0 + rr + rr * math.sin(a))
    for y in reversed(side_ys):                               # lateral direita, para a frente
        put(hw, y, True)
    return pts


def _shell(m, c, sh):
    lv = [(CAB_Z0, 0.07, 0.0), (CAB_Z0 + 0.04, 0.025, 0.04), (CAB_Z0 + 0.1, 0.0, 0.1)]
    zs = {1.4, 2.1, 2.4, c.wz0, c.wz1}
    z = 1.4
    while z < c.wz1 - 0.1:
        zs.add(round(z, 3))
        z += 0.3
    for z in sorted(zs):
        if z <= c.wz1 + 1e-6:
            lv.append((z, 0.0, None))
    for k in range(1, 7):                                    # arredondado do teto
        th = math.radians(15 * k)
        lv.append((c.wz1 + c.roof_r * math.sin(th), c.inset * (1 - math.cos(th)), None))
    rings = [_ring(c, sh, z, inset, lift) for z, inset, lift in lv]
    return A.loft("cab", rings, m["paint_white_panel"])


def build_cab(m, add, style="padrao"):
    c = make_ctx(style)
    sh = Shell(c)
    add(_shell(m, c, sh))
    build_front(m, add, c, sh)
    build_sides(m, add, c, sh)
    build_roof(m, add, c, sh)
    return sh
