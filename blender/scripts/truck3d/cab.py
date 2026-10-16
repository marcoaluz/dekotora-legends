"""Cabines do caminhão (cab-over): casca arredondada por loft + detalhes, em 4 estilos.

`build_cab(m, add, style)` cria tudo e entrega cada objeto para `add(obj)`. Todos os estilos mantêm a largura,
a frente (CAB_Y1), a grade e o para-choque nos mesmos lugares (as peças frontais servem em qualquer cabine);
o que muda é altura do teto, inclinação do para-brisa, arredondado, faróis, grade, viseira e laterais.

| estilo   | ideia                                                                          |
| padrao   | cab-over arredondada (Volvo FH da 1ª rodada)                                   |
| classica | quadrada e baixa (Volvo F7 / Mercedes Accelo): faróis redondos, grade com diagonal |
| aero     | aerodinâmica (Actros): para-brisa bem inclinado, faróis LED finos, aletas laterais |
| alta     | teto alto (sleeper): faixa de vidro superior, janela de dormitório, grande defletor |
"""
import math
from dataclasses import dataclass

from lib import mesh3d as M
from lib import mesh_adv as A

from .dims import CAB_W, CAB_Y0, CAB_Y1, CAB_Z0, FRONT_AXLE_Y

STYLES = {
    "padrao": dict(top=3.35, roof_r=0.15, inset=0.13, wz0=2.1, setback=0.38, rf0=0.22, rf1=0.18, taper=0.05),
    "classica": dict(top=3.2, roof_r=0.09, inset=0.05, wz0=2.1, setback=0.14, rf0=0.12, rf1=0.08, taper=0.02),
    "aero": dict(top=3.45, roof_r=0.32, inset=0.24, wz0=1.9, setback=0.78, rf0=0.3, rf1=0.34, taper=0.12),
    "alta": dict(top=3.9, roof_r=0.2, inset=0.15, wz0=2.2, setback=0.5, rf0=0.22, rf1=0.2, taper=0.07),
}
CAB_STYLES = tuple(STYLES)


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

    @property
    def wz1(self) -> float:                     # fim do trecho inclinado do para-brisa (começa o arredondado do teto)
        return self.top - self.roof_r

    @property
    def slope_deg(self) -> float:
        return math.degrees(math.atan2(self.setback, self.wz1 - self.wz0))

    def yf(self, z: float) -> float:
        """Y da face frontal na altura z (antes do arredondado do teto)."""
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


def _shell(m, c):
    lv = [(CAB_Z0, 0.07), (CAB_Z0 + 0.04, 0.025), (1.0, 0.0)]
    z = 1.4
    while z < c.wz1 - 0.15:
        lv.append((z, 0.0))
        z += 0.3 if c.name != "alta" else 0.4
    lv.append((c.wz1, 0.0))
    for k in range(1, 6):
        th = math.radians(18 * k)
        lv.append((c.wz1 + c.roof_r * math.sin(th), c.inset * (1 - math.cos(th))))
    rings = []
    for z, inset in lv:
        zc = min(z, c.wz1)
        rf = c.rf0 + c.rf1 * max(0.0, min(1.0, (zc - 2.1) / 1.1))
        rings.append(A.rounded_rect_ring(c.hw(zc) - inset, CAB_Y0 + inset, c.yf(zc) - inset, z,
                                         max(rf - inset, 0.06), max(0.12 - inset, 0.04), n=6))
    return A.loft("cab", rings, m["paint_white_panel"])


# ---------------------------------------------------------------- faróis

def _headlight(add, m, sx, c):
    x, y, z = sx * 0.9, CAB_Y1 + 0.012, 1.32
    if c.name == "classica":                              # dois faróis redondos em moldura cromada
        add(M.box(f"hl_house_{sx}", (0.5, 0.1, 0.4), (x, y, z), m["plastic"], bevel=0.05))
        for k, dx in enumerate((-0.1, 0.1)):
            add(M.cylinder(f"hl_ring_{sx}_{k}", 0.108, 0.04, (x + dx, y + 0.06, z), m["chrome"], axis="Y", seg=24))
            add(M.cylinder(f"hl_lens_{sx}_{k}", 0.088, 0.04, (x + dx, y + 0.075, z), m["glass"], axis="Y", seg=24))
            add(M.cylinder(f"hl_bulb_{sx}_{k}", 0.055, 0.03, (x + dx, y + 0.092, z), m["lamp_white"], axis="Y", seg=18))
        add(M.box(f"hl_blinker_{sx}", (0.22, 0.045, 0.06), (x, y + 0.045, z - 0.23), m["lamp_amber"], bevel=0.02, seg=1))
        return
    if c.name == "aero":                                  # farol LED fino e largo
        add(M.box(f"hl_house_{sx}", (0.62, 0.1, 0.22), (x - sx * 0.04, y, z + 0.02), m["plastic"], bevel=0.05))
        add(M.box(f"hl_lens_{sx}", (0.58, 0.05, 0.18), (x - sx * 0.04, y + 0.05, z + 0.02), m["glass"], bevel=0.05))
        for k in range(3):
            add(M.box(f"hl_led_{sx}_{k}", (0.15, 0.02, 0.055), (x - sx * 0.04 + (k - 1) * 0.19, y + 0.078, z + 0.02), m["lamp_white"], bevel=0.015, seg=1))
        add(M.box(f"hl_drl_{sx}", (0.56, 0.02, 0.02), (x - sx * 0.04, y + 0.075, z - 0.115), m["lamp_white"], bevel=0.008, seg=1))
        add(M.box(f"hl_blinker_{sx}", (0.3, 0.045, 0.05), (x - sx * 0.04, y + 0.045, z - 0.2), m["lamp_amber"], bevel=0.02, seg=1))
        return
    add(M.box(f"hl_house_{sx}", (0.46, 0.1, 0.36), (x, y, z), m["plastic"], bevel=0.05))
    add(M.box(f"hl_rim_{sx}", (0.5, 0.03, 0.4), (x, y + 0.035, z), m["chrome"], bevel=0.05, seg=1))
    add(M.box(f"hl_lens_{sx}", (0.4, 0.05, 0.3), (x, y + 0.05, z), m["glass"], bevel=0.04))
    add(M.cylinder(f"hl_proj_ring_{sx}", 0.095, 0.03, (x + sx * 0.04, y + 0.075, z + 0.02), m["chrome"], axis="Y", seg=20))
    add(M.cylinder(f"hl_proj_{sx}", 0.075, 0.03, (x + sx * 0.04, y + 0.085, z + 0.02), m["lamp_white"], axis="Y", seg=20))
    add(M.box(f"hl_drl_{sx}", (0.38, 0.02, 0.025), (x, y + 0.075, z - 0.135), m["lamp_white"], bevel=0.01, seg=1))
    add(M.box(f"hl_drl_v_{sx}", (0.025, 0.02, 0.2), (x - sx * 0.19, y + 0.075, z), m["lamp_white"], bevel=0.01, seg=1))
    add(M.box(f"hl_blinker_{sx}", (0.22, 0.045, 0.06), (x, y + 0.045, z - 0.2), m["lamp_amber"], bevel=0.02, seg=1))


# ---------------------------------------------------------------- grade e para-choque

def _grille(add, m, c):
    y = CAB_Y1
    add(M.box("grille_frame", (1.3, 0.07, 0.64), (0, y + 0.02, 1.22), m["chrome"], bevel=0.04))
    add(M.box("grille", (1.18, 0.08, 0.52), (0, y + 0.025, 1.22), m["plastic"], bevel=0.03))
    if c.name == "classica":                              # tela fina + diagonal cromada (assinatura do F7)
        add(M.box("grille_mesh_all", (1.12, 0.012, 0.46), (0, y + 0.066, 1.22), m["mesh_perf_grille"], bevel=0.002, seg=1))
        add(M.tube("grille_diag", [(-0.55, y + 0.085, 0.99), (0.55, y + 0.085, 1.45)], 0.028, m["chrome"], seg=10))
        add(M.box("badge_plate", (0.3, 0.03, 0.12), (0.3, y + 0.09, 1.3), m["chrome"], bevel=0.015, seg=1))
        return
    for i in range(5):
        add(M.box(f"grille_mesh_{i}", (1.12, 0.012, 0.075), (0, y + 0.066, 1.0 + i * 0.1), m["mesh_perf"], bevel=0.002, seg=1))
    for i in range(6):
        add(M.box(f"grille_bar_{i}", (1.16, 0.045, 0.02), (0, y + 0.06, 0.95 + i * 0.1), m["chrome"], bevel=0.008, seg=1))
    r = 0.17 if c.name == "aero" else 0.115
    add(M.cylinder("badge_ring", r, 0.04, (0, y + 0.075, 1.22), m["chrome"], axis="Y", seg=28))
    add(M.cylinder("badge_core", r - 0.03, 0.04, (0, y + 0.082, 1.22), m["paint_blue"], axis="Y", seg=28))


def _bumper(add, m):
    y = CAB_Y1
    add(M.box("bumper", (2.36, 0.3, 0.3), (0, y + 0.085, 0.74), m["paint_white"], bevel=0.09, seg=3))
    add(M.box("bumper_valance", (2.22, 0.24, 0.16), (0, y + 0.06, 0.5), m["plastic"], bevel=0.05))
    add(M.box("bumper_step", (0.9, 0.12, 0.05), (0, y + 0.2, 0.56), m["diamond"], bevel=0.01, seg=1))
    add(M.box("plate_front", (0.52, 0.02, 0.13), (0, y + 0.24, 0.76), m["paint_white"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        add(M.cylinder(f"fog_ring_{sx}", 0.085, 0.03, (sx * 0.78, y + 0.235, 0.74), m["chrome"], axis="Y", seg=20))
        add(M.cylinder(f"fog_{sx}", 0.065, 0.03, (sx * 0.78, y + 0.245, 0.74), m["lamp_white"], axis="Y", seg=20))
        add(M.box(f"bumper_vent_{sx}", (0.5, 0.02, 0.09), (sx * 0.45, y + 0.235, 0.7), m["mesh_perf_vent"], bevel=0.01, seg=1))
        add(M.box(f"bumper_corner_{sx}", (0.1, 0.3, 0.34), (sx * 1.2, y + 0.04, 0.72), m["paint_white"], bevel=0.04))


# ---------------------------------------------------------------- porta, vidros, espelhos

def _door_path(c):
    """Contorno (y, z) da porta: cantos arredondados, frente inclinada e borda inferior que contorna o arco da roda."""
    pts = []

    def arc(cy, cz, r, a0, a1, n=5):
        for k in range(n + 1):
            a = math.radians(a0 + (a1 - a0) * k / n)
            pts.append((cy + r * math.cos(a), cz + r * math.sin(a)))
    z_a, z_b, z_c = c.zm(2.85), c.zm(3.05), c.zm(2.0)
    pts.append((9.2, 1.0))
    pts.append((9.2, z_a))
    arc(9.4, z_a, 0.2, 180, 90)
    pts.append((10.55, z_b))
    arc(10.55, z_a, 0.2, 90, 40)
    pts.append((10.98, z_c))
    pts.append((10.98, 1.15))
    arc(10.86, 1.15, 0.12, 0, -90, 3)
    k = 0.76
    for a in range(0, 181, 15):
        yy = FRONT_AXLE_Y + k * math.cos(math.radians(a))
        zz = 0.5 + k * math.sin(math.radians(a))
        if zz >= 1.03:
            pts.append((yy, zz))
    pts.append((9.4, 1.0))
    pts.append((9.2, 1.0))
    return pts


def _side(add, m, sx, c):
    def xs(z):
        return sx * c.hw(z)
    ywp = c.yf(c.zm(2.3)) + 0.03
    add(M.box(f"wiper_{sx}", (0.78, 0.015, 0.03), (sx * 0.45, ywp, c.zm(2.28)), m["plastic"], bevel=0.005, seg=1, rot=(c.slope_deg, 0, 0)))
    door = _door_path(c)
    add(M.tube(f"door_seam_{sx}", [(xs(z) + sx * 0.004, y, z) for (y, z) in door], 0.009, m["plastic"], seg=6))
    wp = [(9.55, 2.08), (10.82, 2.08), (10.86, 2.62), (10.62, 2.96), (9.72, 2.96), (9.55, 2.82)]
    wpoly = [(y, c.zm(z)) for (y, z) in wp]
    if c.name == "classica":                              # janela mais quadrada
        wpoly = [(9.55, 2.08), (10.84, 2.08), (10.86, 2.9), (9.55, 2.9)]
    cy = sum(p[0] for p in wpoly) / len(wpoly)
    cz = sum(p[1] for p in wpoly) / len(wpoly)
    frame = [(cy + (p[0] - cy) * 1.07, cz + (p[1] - cz) * 1.1) for p in wpoly]
    zw = c.zm(2.5)
    add(M.plane_extrude(f"win_frame_{sx}", frame, 0.05, (xs(zw) - sx * 0.012, 0, 0), m["plastic"], plane="YZ", bevel=0.025))
    add(M.plane_extrude(f"side_window_{sx}", wpoly, 0.05, (xs(zw) + sx * 0.003, 0, 0), m["glass"], plane="YZ", bevel=0.02))
    add(M.box(f"win_divider_{sx}", (0.03, 0.04, (max(p[1] for p in wpoly) - 2.08) * 0.9), (xs(zw) + sx * 0.02, 9.56, zw), m["plastic"], bevel=0.01, seg=1))
    add(M.tube(f"belt_crease_{sx}", [(xs(1.62) + sx * 0.006, y, 1.62) for y in (8.6, 9.2, 10.2, 11.0, 11.3)], 0.016, m["paint_white"], seg=6))
    add(M.box(f"door_handle_{sx}", (0.045, 0.24, 0.045), (xs(1.9) + sx * 0.02, 9.5, 1.95), m["chrome"], bevel=0.012, seg=2))
    add(M.box(f"door_handle_bed_{sx}", (0.03, 0.3, 0.1), (xs(1.9) + sx * 0.008, 9.5, 1.95), m["plastic"], bevel=0.02))
    z_m, z_l = c.zm(2.45), c.zm(2.05)                     # espelhos
    mx = sx * (c.hw(2.4) + 0.38)
    add(M.box(f"mirror_{sx}", (0.09, 0.2, 0.46), (mx, 11.05, z_m), m["plastic"], bevel=0.04, seg=3))
    add(M.box(f"mirror_face_{sx}", (0.02, 0.17, 0.4), (mx + sx * 0.05, 11.05, z_m), m["chrome"], bevel=0.015, seg=2))
    add(M.box(f"mirror_low_{sx}", (0.08, 0.17, 0.17), (mx, 11.05, z_l), m["plastic"], bevel=0.04, seg=3))
    add(M.box(f"mirror_low_face_{sx}", (0.02, 0.14, 0.13), (mx + sx * 0.045, 11.05, z_l), m["chrome"], bevel=0.015, seg=2))
    for zz in (c.zm(2.2), c.zm(2.65)):
        add(M.tube(f"mirror_arm_{sx}_{zz:.2f}", [(sx * c.hw(2.4), 10.95, zz), (mx - sx * 0.03, 11.03, zz)], 0.022, m["steel"], seg=8))
    add(M.box(f"side_blinker_{sx}", (0.03, 0.14, 0.07), (xs(1.2) + sx * 0.005, 11.2, 1.25), m["lamp_amber"], bevel=0.015, seg=1))
    add(M.box(f"step_{sx}", (0.28, 0.75, 0.05), (sx * (CAB_W / 2 + 0.12), 9.55, 0.55), m["diamond"], bevel=0.01, seg=1))
    for k in range(4):
        add(M.box(f"step_tread_{sx}_{k}", (0.24, 0.03, 0.012), (sx * (CAB_W / 2 + 0.12), 9.3 + k * 0.16, 0.58), m["plastic"], bevel=0.003, seg=1))
    add(M.box(f"step_bracket_{sx}", (0.05, 0.5, 0.18), (sx * (CAB_W / 2 + 0.02), 9.55, 0.7), m["steel"], bevel=0.01, seg=1))
    x0, x1 = (0.8, 1.27) if sx > 0 else (-1.27, -0.8)
    add(A.arch_shell(f"front_fender_{sx}", (FRONT_AXLE_Y, 0.5), 0.55, 0.62, x0, x1, m["plastic"], seg=22))
    add(A.arch_shell(f"front_fender_lip_{sx}", (FRONT_AXLE_Y, 0.5), 0.62, 0.655, x0, x1, m["chrome"], seg=22))
    _style_side(add, m, sx, c, xs)


def _style_side(add, m, sx, c, xs):
    """Detalhes laterais exclusivos de cada estilo."""
    if c.name == "aero":
        for k, z in enumerate((c.zm(2.45), c.zm(2.75))):          # aletas defletoras atrás da coluna A
            add(M.box(f"fin_{sx}_{k}", (0.06, 0.5, 0.05), (xs(z) + sx * 0.03, 8.95, z), m["chrome"], bevel=0.01, seg=1))
        add(M.box(f"cab_skirt_{sx}", (0.05, 1.7, 0.28), (xs(0.95) + sx * 0.02, 9.9, 0.78), m["plastic"], bevel=0.02, seg=1))
    elif c.name == "alta":                                        # janela do dormitório atrás da porta
        frame = [(8.6, 2.6), (9.17, 2.6), (9.17, 3.4), (8.6, 3.4)]
        poly = [(8.65, 2.65), (9.12, 2.65), (9.12, 3.35), (8.65, 3.35)]
        add(M.plane_extrude(f"sleeper_frame_{sx}", frame, 0.05, (xs(3.0) - sx * 0.012, 0, 0), m["plastic"], plane="YZ", bevel=0.02))
        add(M.plane_extrude(f"sleeper_window_{sx}", poly, 0.05, (xs(3.0) + sx * 0.003, 0, 0), m["glass"], plane="YZ", bevel=0.015))
        add(M.box(f"deflector_{sx}", (0.1, 0.9, 0.22), (xs(c.top - 0.3) + sx * 0.05, 9.2, c.top - 0.28), m["paint_white"], bevel=0.04))
    elif c.name == "classica":
        add(M.box(f"side_vent_{sx}", (0.03, 0.4, 0.1), (xs(1.3) + sx * 0.01, 10.1, 1.3), m["mesh_perf_vent"], bevel=0.01, seg=1))
        add(M.tube(f"mirror_stay_{sx}", [(xs(2.0), 10.95, c.zm(2.1)), (xs(2.0) + sx * 0.36, 11.06, c.zm(2.1)), (xs(2.0) + sx * 0.36, 11.06, c.zm(2.6))], 0.016, m["chrome"], seg=8))


# ---------------------------------------------------------------- teto

def _roof(add, m, c):
    top = c.top
    if c.name == "alta":                                          # defletor grande
        fair, wing_h = [(9.75, top - 0.02), (8.6, top - 0.02), (8.6, top + 0.55), (9.1, top + 0.55)], 0.45
    elif c.name == "classica":                                    # apenas viseira baixa
        fair, wing_h = [(9.9, top - 0.02), (8.7, top - 0.02), (8.7, top + 0.1), (9.0, top + 0.1)], 0.05
    elif c.name == "aero":
        fair, wing_h = [(9.4, top - 0.02), (8.62, top - 0.02), (8.62, top + 0.35), (8.85, top + 0.35)], 0.25
    else:
        fair, wing_h = [(9.6, top - 0.02), (8.62, top - 0.02), (8.62, top + 0.3), (8.9, top + 0.3)], 0.2
    add(M.plane_extrude("roof_fairing", fair, 2.0, (0, 0, 0), m["paint_white"], plane="YZ", bevel=0.04, seg=2))
    for sx in (-1, 1):
        side = [(fair[0][0] - 0.1, top - 0.06), (8.55, top - 0.06), (8.55, top + wing_h), (fair[3][0] - 0.1, top + wing_h)]
        add(M.plane_extrude(f"roof_wing_{sx}", side, 0.05, (sx * 1.02, 0, 0), m["paint_white"], plane="YZ", bevel=0.01))
    add(M.box("roof_hatch", (0.9, 0.9, 0.04), (0, 9.6, top + 0.005), m["plastic"], bevel=0.015, seg=1))
    add(M.box("roof_hatch_rim", (0.98, 0.98, 0.03), (0, 9.6, top - 0.005), m["steel"], bevel=0.012, seg=1))
    add(M.box("cab_rear_panel", (2.0, 0.06, 1.6), (0, CAB_Y0 - 0.005, 2.1), m["plastic"], bevel=0.03))
    if c.name == "classica":                                      # fileira de lâmpadas âmbar na viseira
        y = c.yf(c.wz1) - 0.45
        for i in range(5):
            add(M.box(f"visor_lamp_{i}", (0.18, 0.1, 0.07), (-0.6 + i * 0.3, y, top + 0.13), m["lamp_amber"], bevel=0.02, seg=1))


def build_cab(m, add, style="padrao"):
    c = make_ctx(style)
    add(_shell(m, c))
    _grille(add, m, c)
    _bumper(add, m)
    for sx in (-1, 1):
        _headlight(add, m, sx, c)
        _side(add, m, sx, c)
    if style == "padrao":                                         # para-brisa (largura da parte plana da frente)
        zc, hgt = 2.65, 1.1
    else:
        z0 = c.zm(2.1)
        zc, hgt = (z0 + c.wz1) / 2 + 0.05, c.wz1 - z0 + 0.1
    yw = c.yf(zc) + 0.012
    add(M.box("windshield_frame", (1.9, 0.05, hgt + 0.1), (0, yw - 0.012, zc), m["plastic"], bevel=0.03, seg=2, rot=(c.slope_deg, 0, 0)))
    add(M.box("windshield", (1.8, 0.05, hgt), (0, yw + 0.006, zc), m["glass"], bevel=0.025, seg=2, rot=(c.slope_deg, 0, 0)))
    if style == "alta":                                           # faixa de vidro superior (teto alto)
        zt = c.top - 0.38
        add(M.box("upper_glass", (1.7, 0.04, 0.22), (0, c.yf(zt) + 0.004, zt), m["glass"], bevel=0.02, seg=2, rot=(c.slope_deg, 0, 0)))
    add(M.box("stripe_cab", (CAB_W + 0.01, CAB_Y1 - CAB_Y0 - 0.5, 0.22), (0, (CAB_Y0 + CAB_Y1) / 2 - 0.2, 1.85), m["paint_pink"], bevel=0.02, seg=1))
    for z in (1.78, 0.98):                                        # juntas de painel na frente
        add(M.tube(f"front_seam_{z}", [(s * (c.hw(z) - 0.12), c.yf(z) + 0.004, z) for s in (-1, 1)], 0.01, m["plastic"], seg=6))
    _roof(add, m, c)
