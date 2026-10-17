"""Laterais da cabine: porta (vinco, borracha da janela, vidro, maçaneta, fechadura, dobradiças), espelhos
com haste, espelho de canto (frente), pega-mão, pisca lateral, faixa decorativa, degraus de acesso,
para-lama com arco, forro da caixa de roda e protetor de lama.

A lateral tem afunilamento para cima (tumblehome); tudo usa `Shell.side_ev(sx)` (u = y em metros) para
encostar na chapa de verdade."""
import math

from lib import mesh3d as M
from lib import mesh_adv as A

from .cab_surface import patch, ribbon, rounded_poly
from .dims import CAB_W, CAB_Y0, FRONT_AXLE_Y

DOOR_REAR = 9.2           # y da borda traseira da porta
DOOR_BOTTOM = 1.03
ARCH_GAP = 0.78           # raio do vinco da porta em volta do arco da roda


def _door_poly(c, sh):
    """Contorno (y, z) da porta: traseira reta, base contornando o arco, frente vertical subindo junto à coluna A."""
    zt = c.zm(3.06)
    y_front_low = sh.c.yf(1.5) - c.bow - sh.rf(1.5) - 0.17
    y_front_top = c.yf(zt) - c.bow - sh.rf(zt) - 0.13
    pts = [(DOOR_REAR, DOOR_BOTTOM)]
    th0 = math.degrees(math.asin((DOOR_BOTTOM - 0.5) / ARCH_GAP))
    for k in range(11):                                       # arco por cima da roda
        th = math.radians(180 - th0 - (180 - 2 * th0) * k / 10)
        pts.append((FRONT_AXLE_Y + ARCH_GAP * math.cos(th), 0.5 + ARCH_GAP * math.sin(th)))
    pts += [(y_front_low, DOOR_BOTTOM), (y_front_low, c.zm(2.0)), (y_front_top, zt), (DOOR_REAR, zt)]
    return pts


def _window_poly(c, sh):
    belt = c.zm(2.02)
    wt = c.zm(2.94)
    yf_top = c.yf(wt) - c.bow - sh.rf(wt) - 0.2
    yf_low = c.yf(belt) - c.bow - sh.rf(belt) - 0.3
    if c.name == "classica":
        return [(9.36, belt), (yf_low, belt), (yf_top, wt), (9.36, wt)], belt, wt
    return [(9.36, belt), (yf_low, belt - 0.08), (yf_top, wt), (9.36, wt)], belt, wt


def _door(add, m, sx, c, sh):
    ev = sh.side_ev(sx)
    door = _door_poly(c, sh)
    seam = rounded_poly(door, [0.1] + [0.0] * 11 + [0.12, 0.0, 0.15, 0.12], 3)
    add(ribbon(f"door_seam_{sx}", ev, seam, 0.004, 0.012, m["plastic"], closed=True))
    win, belt, wt = _window_poly(c, sh)
    def keep(y, z):                                           # não deixa a moldura dobrar o canto (a placa afundaria)
        return min(y, c.yf(z) - c.bow - sh.rf(z) - 0.03)
    frame = [(win[0][0] - 0.06, win[0][1] - 0.05), (win[1][0] + 0.14, win[1][1] - 0.05),
             (win[2][0] + 0.08, win[2][1] + 0.05), (win[3][0] - 0.06, win[3][1] + 0.05)]
    frame = rounded_poly([(keep(y, z), z) for (y, z) in frame], 0.1, 3)
    add(patch(f"win_frame_{sx}", ev, frame, 0.0, 0.007, m["plastic_trim"], nz=5, nu=8))
    add(patch(f"side_window_{sx}", ev, rounded_poly(win, 0.07, 3), 0.0, 0.012, m["glass"], nz=5, nu=8))
    # maçaneta: concha preta + alavanca cromada + fechadura, abaixo do canto traseiro da janela
    zh = belt - 0.13
    add(patch(f"door_handle_bed_{sx}", ev, rounded_poly([(9.38, zh - 0.05), (9.66, zh - 0.05), (9.66, zh + 0.05), (9.38, zh + 0.05)], 0.04, 2),
              0.0, 0.006, m["plastic_trim"], nz=2, nu=3))
    p = ev(9.52, zh, 0.02)
    add(M.box(f"door_handle_{sx}", (0.035, 0.24, 0.04), p, m["chrome"], bevel=0.012, seg=2))
    add(M.cylinder(f"door_lock_{sx}", 0.016, 0.02, tuple(ev(9.72, zh, 0.01)), m["chrome"], axis="X", seg=10))
    # dobradiças (só a clássica mostra as dobradiças por fora)
    if c.name == "classica":
        yh = door[-3][0] - 0.04
        for zz in (1.35, c.zm(2.55)):
            add(M.box(f"hinge_{sx}_{zz:.2f}", (0.04, 0.09, 0.16), tuple(ev(yh, zz, 0.015)), m["chrome"], bevel=0.012, seg=1))
            add(M.cylinder(f"hinge_pin_{sx}_{zz:.2f}", 0.016, 0.2, tuple(ev(yh + 0.045, zz, 0.02)), m["steel"], axis="Z", seg=8))
    # pega-mão vertical atrás da porta
    ys = DOOR_REAR - 0.12
    pts = [tuple(ev(ys, 1.45, 0.0)), tuple(ev(ys, 1.45, 0.05)), tuple(ev(ys, 2.05, 0.05)), tuple(ev(ys, 2.05, 0.0))]
    add(M.tube(f"grab_{sx}", pts, 0.016, m["chrome"], seg=8))
    # faixa decorativa (rosa) que passa pela porta e dobra o canto até a frente
    zs = 1.62                                                 # abaixo da maçaneta, na linha de cintura
    path = [(y, zs) for y in (8.6, 9.2, 9.8, 10.4)] + [(c.yf(zs) - c.bow - sh.rf(zs), zs)]
    add(ribbon(f"stripe_side_{sx}", ev, path, 0.005, 0.11, m["paint_pink"]))
    fev = sh.front_ev()
    # pisca lateral no canto de baixo
    add(patch(f"side_blinker_{sx}", fev, rounded_poly([(sx * 2.0, 1.2), (sx * 2.16, 1.2), (sx * 2.16, 1.28), (sx * 2.0, 1.28)], 0.02, 2),
              0.0, 0.014, m["lamp_amber"], nz=2, nu=2))
    if c.name == "alta":                                      # janela do dormitório atrás da porta
        zz0, zz1 = c.zm(2.55), c.zm(3.0)
        add(patch(f"sleeper_frame_{sx}", ev, rounded_poly([(8.62, zz0 - 0.04), (9.08, zz0 - 0.04), (9.08, zz1 + 0.04), (8.62, zz1 + 0.04)], 0.08, 3),
                  0.0, 0.007, m["plastic_trim"], nz=4, nu=4))
        add(patch(f"sleeper_window_{sx}", ev, rounded_poly([(8.66, zz0), (9.04, zz0), (9.04, zz1), (8.66, zz1)], 0.06, 3),
                  0.0, 0.012, m["glass"], nz=4, nu=4))


def _mirrors(add, m, sx, c, sh):
    ev = sh.side_ev(sx)
    win, belt, wt = _window_poly(c, sh)
    y_base = win[1][0] + 0.06
    z_m = c.zm(2.45)
    hw = c.hw(z_m)
    mx = sx * (hw + 0.36)
    my = y_base + 0.12
    add(M.box(f"mirror_{sx}", (0.21, 0.11, 0.46), (mx, my, z_m), m["plastic"], bevel=0.045, seg=3))
    add(M.box(f"mirror_face_{sx}", (0.18, 0.012, 0.41), (mx, my - 0.056, z_m), m["chrome"], bevel=0.005, seg=1))
    z_l = z_m - 0.36
    add(M.box(f"mirror_low_{sx}", (0.18, 0.1, 0.2), (mx, my, z_l), m["plastic"], bevel=0.04, seg=3))
    add(M.box(f"mirror_low_face_{sx}", (0.15, 0.012, 0.16), (mx, my - 0.051, z_l), m["chrome"], bevel=0.005, seg=1))
    # haste: sai da base preta da janela, desce em curva e segura as duas cabeças
    p0 = ev(y_base, belt + 0.06, 0.01)
    arm = [tuple(p0), (p0.x + sx * 0.12, p0.y + 0.06, p0.z + 0.04), (mx - sx * 0.02, my, z_m - 0.05)]
    add(M.tube(f"mirror_arm_{sx}", arm, 0.022, m["plastic"], seg=8))
    add(M.tube(f"mirror_stay_{sx}", [(mx, my + 0.02, z_m - 0.2), (mx, my + 0.02, z_l + 0.08)], 0.015, m["steel"], seg=6))
    p1 = ev(y_base + 0.1, c.zm(2.85), 0.01)
    add(M.tube(f"mirror_brace_{sx}", [tuple(p1), (mx - sx * 0.02, my, z_m + 0.2)], 0.012, m["steel"], seg=6))
    if sx < 0:                                                # espelho de canto (lado do passageiro, Japão): olha a frente
        fev = sh.front_ev()
        q = -1.55
        base = fev(q, c.wz0 + 0.25, 0.0)
        tip = base + sh.normal(q, c.wz0 + 0.25) * 0.28
        tip.z += 0.08
        add(M.tube("corner_mirror_arm", [tuple(base), tuple(tip)], 0.012, m["chrome"], seg=6))
        add(M.box("corner_mirror", (0.16, 0.06, 0.11), (tip.x, tip.y + 0.02, tip.z + 0.06), m["plastic"], bevel=0.025, seg=2))
        add(M.box("corner_mirror_face", (0.13, 0.01, 0.085), (tip.x, tip.y - 0.012, tip.z + 0.06), m["chrome"], bevel=0.005, seg=1))


def _steps_and_fender(add, m, sx, c, sh):
    hw = CAB_W / 2
    # degraus de acesso: caixa preta atrás da roda, dois degraus de chapa xadrez rebaixados
    y0, y1 = 8.92, 9.5
    yc, ln = (y0 + y1) / 2, y1 - y0
    add(M.box(f"step_wall_f_{sx}", (0.3, 0.04, 0.68), (sx * (hw - 0.14), y1, 0.62), m["plastic_trim"], bevel=0.015, seg=1))
    add(M.box(f"step_wall_r_{sx}", (0.3, 0.04, 0.68), (sx * (hw - 0.14), y0, 0.62), m["plastic_trim"], bevel=0.015, seg=1))
    add(M.box(f"step_back_{sx}", (0.03, ln, 0.68), (sx * (hw - 0.28), yc, 0.62), m["plastic"], bevel=0.0, seg=1))
    for k, z in enumerate((0.36, 0.7)):
        add(M.box(f"step_tread_{sx}_{k}", (0.3, ln - 0.04, 0.04), (sx * (hw - 0.13), yc, z), m["diamond"], bevel=0.008, seg=1))
        add(M.box(f"step_nose_{sx}_{k}", (0.025, ln - 0.04, 0.06), (sx * (hw + 0.01), yc, z - 0.01), m["steel"], bevel=0.008, seg=1))
    # forro da caixa de roda, parede interna, aba alargada (para-lama) e protetor de lama
    xin, xout = (0.6, hw - 0.02)
    xa, xb = (xin, xout) if sx > 0 else (-xout, -xin)
    add(A.arch_shell(f"wheel_liner_{sx}", (FRONT_AXLE_Y, 0.5), 0.6, 0.63, xa, xb, m["plastic"], seg=20))
    add(M.box(f"wheel_well_wall_{sx}", (0.02, 1.3, 0.55), (sx * xin, FRONT_AXLE_Y, 0.88), m["plastic"], bevel=0.0, seg=1))
    fa, fb = (hw - 0.07, hw + 0.05) if sx > 0 else (-hw - 0.05, -hw + 0.07)
    add(A.arch_shell(f"front_fender_{sx}", (FRONT_AXLE_Y, 0.5), 0.63, 0.7, fa, fb, m["plastic_trim"], seg=24))
    add(M.box(f"mudflap_front_{sx}", (0.3, 0.025, 0.42), (sx * (hw - 0.17), FRONT_AXLE_Y - 0.67, 0.33), m["rubber"], bevel=0.008, seg=1))
    add(M.box(f"mudflap_bar_{sx}", (0.32, 0.04, 0.035), (sx * (hw - 0.17), FRONT_AXLE_Y - 0.67, 0.55), m["steel"], bevel=0.008, seg=1))


def _style_side(add, m, sx, c, sh):
    """Detalhes laterais exclusivos de cada estilo."""
    ev = sh.side_ev(sx)
    if c.name == "aero":
        for k, z in enumerate((c.zm(2.45), c.zm(2.75))):          # aletas defletoras atrás da coluna
            add(patch(f"fin_{sx}_{k}", ev, rounded_poly([(CAB_Y0 + 0.2, z), (CAB_Y0 + 0.75, z), (CAB_Y0 + 0.75, z + 0.05), (CAB_Y0 + 0.2, z + 0.05)], 0.02, 2),
                      0.0, 0.03, m["chrome"], nz=2, nu=3))
        add(M.box(f"cab_skirt_{sx}", (0.05, 1.0, 0.24), (sx * (CAB_W / 2 - 0.0), 9.1, 1.02), m["plastic_trim"], bevel=0.02, seg=1))
    elif c.name == "classica":
        add(patch(f"side_vent_{sx}", ev, rounded_poly([(10.55, 1.25), (10.95, 1.25), (10.95, 1.35), (10.55, 1.35)], 0.03, 2), 0.0, 0.008,
                  m["vent_slots"], nz=2, nu=3))


def build_sides(m, add, c, sh):
    for sx in (-1, 1):
        _door(add, m, sx, c, sh)
        _mirrors(add, m, sx, c, sh)
        _steps_and_fender(add, m, sx, c, sh)
        _style_side(add, m, sx, c, sh)
