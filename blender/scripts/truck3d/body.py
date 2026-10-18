"""Baú de tábuas + traseira (lanternas, escada, para-choque de segurança). Os modelos curto/longo/carreta
são esticados a partir deste em `variants.py`; o Canter (T-125) usa um baú menor (`BoxDims`)."""
from dataclasses import dataclass

from lib import mesh3d as M

from .dims import BODY_L, BODY_TOP, BODY_W, BODY_Z0


@dataclass(frozen=True)
class BoxDims:
    """Medidas do baú (m): largura, comprimento (traseira em y = 0), piso e teto. Os detalhes acompanham."""
    w: float = BODY_W
    l: float = BODY_L
    z0: float = BODY_Z0
    top: float = BODY_TOP
    rear_under: bool = True        # para-choque de segurança, abas de lama e neon sob o chassi (o Canter tem os do JAC)

    def kz(self, z: float) -> float:
        """Altura do baú padrão (1,1 a 3,2 m) -> altura neste baú (mesma fração da parede)."""
        return self.z0 + (z - BODY_Z0) * (self.top - self.z0) / (BODY_TOP - BODY_Z0)

    def ky(self, y: float) -> float:
        """Posição ao longo do baú padrão (0 a 8,2 m) -> neste baú."""
        return y * self.l / BODY_L


STD = BoxDims()


def build_body(m, add, box: BoxDims = STD, shell: bool = True):
    """`shell=False` (baú premium, T-136): só o que fica embaixo/atrás do baú (placa, para-choque de segurança,
    abas de lama, neon, luzes laterais); a casca, a traseira e as lanternas vêm de `truck3d/box_premium.py`."""
    if shell:
        _box(m, add, box)
    else:
        _rear_under(m, add, box)


def _rear_common(m, add, b: BoxDims):
    """Lanternas em 3 lentes, faixa refletiva, placa, para-choque de segurança, abas de lama e neon sob o chassi."""
    k = b.w / BODY_W
    for sx in (-1, 1):
        add(M.box(f"tail_house_{sx}", (0.4, 0.07, 0.68), (sx * 1.0 * k, -0.035, b.kz(1.55)), m["chrome"], bevel=0.035, seg=1))
        for i, (mat, dz) in enumerate((("lamp_amber", 0.22), ("lamp_red", 0.0), ("lamp_white", -0.22))):
            add(M.box(f"tail_{sx}_{i}", (0.32, 0.06, 0.18), (sx * 1.0 * k, -0.06, b.kz(1.55) + dz), m[mat], bevel=0.03))
    for i in range(10):                               # faixa refletiva vermelho/branco
        x = (-1.1 + i * 0.245) * k
        add(M.box(f"refl_{i}", (0.235 * k, 0.03, 0.14), (x, -0.025, b.kz(1.12)), m["paint_red"] if i % 2 == 0 else m["paint_white"], bevel=0.008, seg=1))
    _rear_under(m, add, b)


def _rear_under(m, add, b: BoxDims):
    """Placa, para-choque de segurança, abas de lama, neon sob o chassi e luzes laterais de posição."""
    w2 = b.w / 2
    add(M.box("plate", (0.5, 0.03, 0.22), (0, -0.04, b.kz(1.0) if b.rear_under else b.z0 + 0.25), m["paint_white"], bevel=0.01, seg=1))
    if not b.rear_under:
        for sx in (-1, 1):                            # luzes laterais de posição
            for i in range(5):
                y = 0.7 + i * (b.l - 1.4) / 4
                add(M.box(f"side_marker_{sx}_{i}", (0.04, 0.16, 0.07), (sx * (w2 + 0.025), y, b.kz(1.18)), m["lamp_amber"], bevel=0.015, seg=1))
        return
    add(M.box("underrun", (2.2, 0.12, 0.14), (0, -0.12, 0.42), m["plastic"], bevel=0.03))
    for sx in (-1, 1):
        add(M.box(f"underrun_refl_{sx}", (0.3, 0.02, 0.06), (sx * 0.95, -0.19, 0.42), m["lamp_red"], bevel=0.01, seg=1))
        add(M.box(f"mudflap_{sx}", (0.5, 0.04, 0.5), (sx * 0.95, 0.45, 0.8), m["rubber"], bevel=0.01, seg=1))
        add(M.box(f"underglow_{sx}", (0.05, 10.0, 0.05), (sx * 0.98, 6.0, 0.36), m["lamp_cyan"], bevel=0.01, seg=1))
        for y in (0.7, 2.4, 4.1, 5.8, 7.5):           # luzes laterais de posição
            add(M.box(f"side_marker_{sx}_{y}", (0.04, 0.16, 0.07), (sx * (w2 + 0.025), y, 1.18), m["lamp_amber"], bevel=0.015, seg=1))


def _box(m, add, b: BoxDims):
    w2 = b.w / 2
    k = b.w / BODY_W
    add(M.box("body", (b.w, b.l, b.top - b.z0), (0, b.l / 2, (b.z0 + b.top) / 2), m["paint_white_panel"], bevel=0.08, seg=3))
    # tábuas horizontais (frestas finas) + montantes verticais com trava, como no baú de madeira da referência
    hp = b.kz(3.15) - b.kz(1.15)                      # altura do montante (2,0 m no baú padrão)
    for sx in (-1, 1):                                # (as tabuas ficam por baixo do mural: truck3d/deco.py)
        for i, y in enumerate((0.35, 2.75, 5.45, 7.85)):
            add(M.box(f"post_{sx}_{i}", (0.07, 0.1, hp), (sx * (w2 + 0.03), b.ky(y) if i in (1, 2) else (y if i == 0 else b.l - 0.35), b.kz(2.15)), m["steel"], bevel=0.015, seg=1))
            add(M.box(f"post_latch_{sx}_{i}", (0.05, 0.07, 0.16), (sx * (w2 + 0.06), b.ky(y) if i in (1, 2) else (y if i == 0 else b.l - 0.35), b.kz(1.35)), m["chrome"], bevel=0.015, seg=1))
    for i in (0, 1, 2):                               # nervuras da frente do baú
        add(M.box(f"front_rib_{i}", (0.1, 0.05, hp - 0.1), ((-0.8 + i * 0.8) * k, b.l + 0.015, b.kz(2.15)), m["steel"], bevel=0.012, seg=1))
    for z in (1.3, 3.05):
        add(M.box(f"rail_h_{z}", (b.w + 0.05, b.l - 0.1, 0.06), (0, b.l / 2, b.kz(z)), m["chrome"], bevel=0.015, seg=1))
    add(M.box("trim_top", (b.w + 0.06, b.l + 0.02, 0.08), (0, b.l / 2, b.top - 0.02), m["chrome"], bevel=0.02, seg=1))
    add(M.box("roof_panel", (b.w - 0.2, b.l - 0.2, 0.03), (0, b.l / 2, b.top + 0.005), m["steel"], bevel=0.01, seg=1))
    hc = b.kz(3.2) - b.kz(1.1)
    for sx in (-1, 1):
        add(M.box(f"corner_post_{sx}", (0.1, 0.09, hc), (sx * (w2 - 0.01), -0.04, b.kz(2.15)), m["chrome"], bevel=0.02, seg=1))
    add(M.box("door_seam", (0.04, 0.05, hp), (0, -0.03, b.kz(2.15)), m["plastic"], bevel=0.01, seg=1))   # porta traseira
    for sx in (-1, 1):
        for z in (1.5, 2.3, 3.0):
            add(M.cylinder(f"hinge_{sx}_{z}", 0.05, 0.22, (sx * (w2 + 0.02), -0.05, b.kz(z)), m["steel"], axis="Z", seg=10))
        add(M.cylinder(f"lockbar_{sx}", 0.025, hp - 0.1, (sx * 0.45 * k, -0.07, b.kz(2.12)), m["chrome"], axis="Z", seg=10))
        add(M.box(f"lockhandle_{sx}", (0.08, 0.06, 0.18), (sx * 0.45 * k, -0.1, b.kz(2.0)), m["chrome"], bevel=0.015, seg=1))
    for x in (0.8, 1.12):                             # escada
        add(M.box(f"ladder_rail_{x}", (0.05, 0.06, hp), (x * k, -0.12, b.kz(2.15)), m["chrome"], bevel=0.01, seg=1))
    for i in range(6):
        add(M.box(f"ladder_rung_{i}", (0.37 * k, 0.05, 0.045), (0.96 * k, -0.14, b.kz(1.3) + i * 0.33 * hp / 2.0), m["chrome"], bevel=0.01, seg=1))
    _rear_common(m, add, b)
