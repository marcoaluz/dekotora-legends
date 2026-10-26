"""Dragão (ryū) da T-232: corpo em tubo de raio variável com escamas, barriga em placas e crista; cabeça com chifres,
juba de chamas, bigodes, boca aberta; garras de 3 dedos e a pérola flamejante. Desenho nosso por código; a pose
segue a tradição dos dragões nas nuvens (Hokusai, Kyōsai), sem copiar nenhuma obra.
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from .paint2d import hexc
from .t232_kit import Local, neon_line, paint

GREEN = {"back": "#0e4a3a", "side": "#1fa36a", "light": "#7ff0b0", "belly": "#f3dc8a", "belly_line": "#9a6a1e",
         "line": "#06221a", "spike": "#d8352a", "mane": "#e8452e", "mane2": "#ffb347", "horn": "#f6e7b8", "glow": "#3ff0a0"}
BLUE = {"back": "#0c2a6b", "side": "#2f7fe0", "light": "#a8e4ff", "belly": "#e9f0ff", "belly_line": "#3f5f9a",
        "line": "#050f2e", "spike": "#3ff0ff", "mane": "#f4f8ff", "mane2": "#8fd8ff", "horn": "#ffe9a8", "glow": "#3ff0ff"}
GOLD = {"back": "#7a3a06", "side": "#e8a21a", "light": "#fff1a8", "belly": "#fff4d6", "belly_line": "#a0601a",
        "line": "#2a1200", "spike": "#d8352a", "mane": "#d8352a", "mane2": "#ffd25c", "horn": "#fffbe8", "glow": "#ffd25c"}


def body(cv, spine, R, pal, seed=1):
    """Corpo do dragão ao longo de `spine` (pontos na tela, da cauda para o pescoço). Devolve (pontos, normais, raios)
    reamostrados, para pôr as patas e a cabeça."""
    pts = p.resample(p.spline(spine, 14), 160)
    n = len(pts)
    t = np.linspace(0, 1, n)
    radii = R * np.clip(0.08 + 1.25 * np.sin(np.clip(t, 0, 1) * math.pi * 0.62) ** 0.9, 0.06, 1.0)
    radii[-12:] *= np.linspace(1.0, 0.82, 12)
    nrm = p.normals(pts)
    # crista (espinhos) no lado das costas (-normal)
    spikes = []
    for i in range(6, n - 8, 5):
        r = radii[i]
        bx, by = pts[i][0] - nrm[i][0] * r * 0.85, pts[i][1] - nrm[i][1] * r * 0.85
        d = np.array(pts[min(i + 2, n - 1)]) - np.array(pts[max(i - 2, 0)])
        d /= max(np.hypot(*d), 1e-9)
        h = r * 0.9
        tip = (bx - nrm[i][0] * h - d[0] * h * 0.6, by - nrm[i][1] * h - d[1] * h * 0.6)
        spikes.append([(bx - d[0] * r * 0.45, by - d[1] * r * 0.45), tip, (bx + d[0] * r * 0.4, by + d[1] * r * 0.4)])
    sp_layers = [p.P(cv, s) for s in spikes]
    sp = p.union(cv, sp_layers)
    cv.fill(p.outline(cv, sp, 0.004), hexc(pal["line"]))
    cv.fill(sp, hexc(pal["spike"]))
    lay, (S, W) = p.SV(cv, pts, radii.tolist(), need_uv=True)
    cv.fill(p.outline(cv, lay, 0.0065), hexc(pal["line"]))
    a, win = lay
    # cor: costas escuras -> lado claro -> barriga em placas
    col = p.grad_t((W + 1) * 0.5, [(0, pal["back"]), (0.45, pal["side"]), (0.62, pal["light"]), (0.7, pal["side"])])
    cell = R * 0.42
    u = S / cell
    row = np.floor((W + 1) * 3.2)
    uu = (u + 0.5 * (row % 2)) % 1.0 - 0.5
    vv = ((W + 1) * 3.2) % 1.0
    arc_d = np.abs(np.hypot(uu, (vv - 0.0) * 0.9) - 0.48)
    scale_line = np.clip(1 - arc_d / 0.09, 0, 1) * (W < 0.4)
    col = col * (1 - 0.55 * scale_line[..., None])
    hi = np.clip(1 - np.abs(W + 0.35) / 0.18, 0, 1) * 0.35
    col = col + hi[..., None] * (hexc(pal["light"]) - col)
    belly = W > 0.42
    plate = (S / (R * 0.38)) % 1.0
    bcol = p.mix(hexc(pal["belly"]), hexc(pal["belly_line"]), (np.clip(1 - np.abs(plate - 0.05) / 0.08, 0, 1))[..., None])
    bcol = bcol * (1 - 0.25 * np.clip((W - 0.42) / 0.58, 0, 1))[..., None]
    col = np.where(belly[..., None], bcol, col)
    edge = np.clip((np.abs(W) - 0.8) / 0.2, 0, 1)
    col = col * (1 - 0.35 * edge[..., None])
    cv.fill(lay, col.astype(np.float32))
    return pts, nrm, radii


def leg(cv, base, knee, foot, R, pal, flip=False, pearl=None):
    """Pata: coxa + canela (tubos), tufo de chamas no cotovelo e 3 garras."""
    a = p.SV(cv, [base, knee], [R * 0.55, R * 0.4])[0]
    b = p.SV(cv, [knee, foot], [R * 0.4, R * 0.28])[0]
    lay = p.union(cv, [a, b])
    cv.fill(p.outline(cv, lay, 0.005), hexc(pal["line"]))
    paint(cv, lay, pal["side"], pal["back"], width=R * 0.25)
    # tufo no cotovelo
    d = np.array(knee) - np.array(base)
    d /= max(np.hypot(*d), 1e-9)
    nx, ny = -d[1], d[0]
    for k in range(3):
        tip = (knee[0] - d[0] * R * (0.9 + 0.25 * k) + nx * R * (0.2 * k - 0.2), knee[1] - d[1] * R * (0.9 + 0.25 * k) + ny * R * (0.2 * k - 0.2))
        tf = p.P(cv, [(knee[0] + nx * R * 0.25, knee[1] + ny * R * 0.25), tip, (knee[0] - nx * R * 0.25, knee[1] - ny * R * 0.25)])
        cv.fill(tf, hexc(pal["mane"]))
    # garras
    d2 = np.array(foot) - np.array(knee)
    ang = math.atan2(d2[1], d2[0])
    for k, da in enumerate((-0.6, 0.0, 0.6)):
        aa = ang + da
        p0 = (foot[0], foot[1])
        p1 = (foot[0] + math.cos(aa) * R * 0.55, foot[1] + math.sin(aa) * R * 0.55)
        hook = aa + (1.3 if not flip else -1.3)
        p2 = (p1[0] + math.cos(hook) * R * 0.3, p1[1] + math.sin(hook) * R * 0.3)
        toe = p.SV(cv, [p0, p1], [R * 0.16, R * 0.12])[0]
        cv.fill(p.outline(cv, toe, 0.003), hexc(pal["line"]))
        cv.fill(toe, hexc(pal["side"]))
        claw = p.SV(cv, [p1, p2], [R * 0.09, R * 0.01])[0]
        cv.fill(p.outline(cv, claw, 0.002), hexc(pal["line"]))
        cv.fill(claw, hexc(pal["horn"]))


def pearl(cv, x, y, r, color="#bfe8ff", flame="#3ff0ff"):
    """Pérola flamejante (tama): esfera clara com chamas em volta (neon)."""
    L = Local(cv, x, y, r)
    for k in range(3):
        a0 = k * 120
        pts = [(math.cos(math.radians(a)) * (1.3 + 0.25 * math.sin(math.radians(a * 3))),
                math.sin(math.radians(a)) * (1.3 + 0.25 * math.sin(math.radians(a * 3)))) for a in np.linspace(a0, a0 + 300, 40)]
        neon_line(cv, L.pts(pts), flame, r * 0.06)
    lay = L.E(0, 0, 1, 1)
    cv.add(p.glow(cv, lay, r * 0.8), hexc(flame), 0.8, neon=1.0)
    X, Y = cv.coords(lay)
    lx, ly = L.to_local(X, Y)
    t = np.clip(np.hypot(lx + 0.35, ly + 0.35) / 1.5, 0, 1)
    cv.fill(lay, p.grad_t(t, [(0, "#ffffff"), (0.5, color), (1, "#3a6fd0")]), neon=0.9)


def head(cv, x, y, s, angle, pal, flip=False, mouth=0.25):
    """Cabeça olhando na direção `angle` (graus; 0 = direita). Quadro local: pescoço em (0, 0), focinho em x ~ 1,1."""
    flip = math.cos(math.radians(angle)) < 0          # olhando para a esquerda: espelha (a cabeça fica de pé)
    L = Local(cv, x, y, s, flip=flip, rot=(angle - 180) if flip else angle)
    line = pal["line"]
    # juba de chamas para trás
    mane = []
    for k in range(13):
        a = math.radians(-160 + k * 22)
        root = (0.05 + 0.25 * math.cos(a), -0.02 + 0.32 * math.sin(a))
        tipd = (-0.95 - 0.25 * math.sin(k * 1.7), 0.95 * math.sin(a) - 0.05)
        mid = ((root[0] + tipd[0]) / 2 + 0.05, (root[1] + tipd[1]) / 2 - 0.12)
        poly = p.spline([(root[0], root[1] - 0.09), mid, tipd], 8) + p.spline([tipd, (mid[0] + 0.05, mid[1] + 0.1), (root[0], root[1] + 0.09)], 8)
        mane.append(L.P(poly))
    mm = p.union(cv, mane)
    cv.fill(p.outline(cv, mm, 0.005), hexc(line))
    X, Y = cv.coords(mm)
    lx, ly = L.to_local(X, Y)
    cv.fill(mm, p.grad_t(np.clip(-lx / 0.9, 0, 1), [(0, pal["mane"]), (1, pal["mane2"])]))
    # chifres (2, com galho)
    for k, (dy, ln) in enumerate(((-0.28, 1.0), (-0.18, 0.85))):
        hp = p.spline([(0.15, dy), (-0.15, dy - 0.25 * ln), (-0.55 * ln, dy - 0.35 * ln), (-0.85 * ln, dy - 0.62 * ln)], 8)
        hl = L.SV(hp, [0.07, 0.06, 0.045, 0.012])[0]
        br = L.SV([(-0.35 * ln, dy - 0.33 * ln), (-0.42 * ln, dy - 0.6 * ln)], [0.035, 0.008])[0]
        hh = p.union(cv, [hl, br])
        cv.fill(p.outline(cv, hh, 0.004), hexc(line))
        paint(cv, hh, pal["horn"], "#b08a3a", width=0.02 * s)
    # mandíbula de baixo (aberta) e boca
    jaw_rot = 12 + mouth * 40
    mouth_poly = [(0.25, 0.02), (1.0, -0.02), (0.95, 0.1 + mouth * 0.5), (0.3, 0.22)]
    cv.fill(L.P(mouth_poly), hexc("#7a0a1a"))
    cv.fill(L.S(p.spline([(0.35, 0.12), (0.7, 0.1 + mouth * 0.25), (1.05, 0.12 + mouth * 0.45), (1.2, 0.02 + mouth * 0.5)], 8), 0.035),
            hexc("#e8325a"))
    jaw = L.sdf((0.1, -0.1, 1.2, 0.7), lambda lx, ly: p.smin(
        p.sd_ellipse(lx, ly, 0.6, 0.2 + mouth * 0.28, 0.42, 0.075, math.radians(jaw_rot)),
        p.sd_circle(lx, ly, 0.28, 0.16, 0.13), 0.06))
    cv.fill(p.outline(cv, jaw, 0.005), hexc(line))
    paint(cv, jaw, pal["side"], pal["back"], width=0.03 * s)
    # dentes de baixo
    for k in range(5):
        tx = 0.45 + k * 0.11
        ty = 0.13 + mouth * 0.28 * (tx - 0.25) / 0.75 + 0.0
        cv.fill(L.P([(tx - 0.025, ty + 0.03), (tx, ty - 0.05), (tx + 0.025, ty + 0.03)]), hexc("#fffaf0"))
    # crânio + focinho
    skull = L.sdf((-0.3, -0.45, 1.25, 0.2), lambda lx, ly: p.smin(p.smin(
        p.sd_ellipse(lx, ly, 0.22, -0.08, 0.3, 0.26),
        p.sd_ellipse(lx, ly, 0.68, -0.08, 0.42, 0.12, math.radians(4)), 0.12),
        p.sd_circle(lx, ly, 1.0, -0.12, 0.12), 0.05))
    cv.fill(p.outline(cv, skull, 0.006), hexc(line))
    X, Y = cv.coords(skull)
    lx, ly = L.to_local(X, Y)
    col = p.grad_t(np.clip((ly + 0.35) / 0.4, 0, 1), [(0, pal["back"]), (0.6, pal["side"]), (1, pal["light"])])
    cv.fill(skull, col)
    # dentes de cima e presas
    for k in range(6):
        tx = 0.38 + k * 0.1
        cv.fill(L.P([(tx - 0.025, 0.0), (tx, 0.075), (tx + 0.025, 0.0)]), hexc("#fffaf0"))
    for fx in (0.42, 0.92):
        f = L.P([(fx - 0.035, -0.01), (fx + 0.01, 0.16), (fx + 0.03, -0.01)])
        cv.fill(p.outline(cv, f, 0.002), hexc(line))
        cv.fill(f, hexc("#ffffff"))
    # narina e sobrancelha, olho
    cv.fill(L.E(1.02, -0.14, 0.05, 0.035, -20), hexc(line))
    cv.fill(L.E(0.98, -0.2, 0.08, 0.05, -10), hexc(pal["light"]))
    brow = L.P([(0.12, -0.28), (0.52, -0.3), (0.62, -0.2), (0.5, -0.22), (0.2, -0.18)])
    cv.fill(p.outline(cv, brow, 0.003), hexc(line))
    cv.fill(brow, hexc(pal["mane"]))
    eye = L.E(0.4, -0.14, 0.085, 0.055, -8)
    cv.fill(p.outline(cv, eye, 0.003), hexc(line))
    cv.fill(eye, hexc("#ffe14a"), neon=0.8)
    cv.fill(L.E(0.42, -0.14, 0.018, 0.048), hexc("#120808"))
    cv.fill(L.E(0.385, -0.16, 0.014, 0.01), hexc("#ffffff"))
    # bigodes compridos
    for k, pts in enumerate((
            [(1.05, -0.1), (1.3, -0.25), (1.2, -0.55), (0.8, -0.75), (0.4, -0.7)],
            [(1.0, 0.0), (1.35, 0.15), (1.45, 0.45), (1.2, 0.75), (0.9, 0.85)])):
        sp = p.spline(pts, 10)
        rr = list(np.linspace(0.028, 0.006, len(sp)))
        w = L.SV(sp, rr)[0]
        cv.fill(p.outline(cv, w, 0.003), hexc(line))
        cv.fill(w, hexc(pal["mane2"]))
    # barba
    for k in range(4):
        b0 = (0.35 + k * 0.07, 0.28 + mouth * 0.3)
        tip = (0.15 + k * 0.05, 0.62 + mouth * 0.3 + 0.05 * (k % 2))
        bb = L.P([(b0[0] - 0.05, b0[1]), tip, (b0[0] + 0.05, b0[1])])
        cv.fill(bb, hexc(pal["mane"]))
    return L


def dragon(cv, spine, R, pal, head_angle, head_scale=None, legs=((0.3, 1), (0.42, -1), (0.72, 1), (0.8, -1)), flip=False,
           mouth=0.3, pearl_at=None):
    """Dragão completo. `spine` da cauda para o pescoço (tela). `legs` = (fração do corpo, sentido)."""
    pts, nrm, rad = body(cv, spine, R, pal)
    n = len(pts)
    for frac, sgn in legs:
        i = int(frac * (n - 1))
        bx, by = pts[i]
        nx, ny = nrm[i]
        base = (bx + nx * rad[i] * 0.5, by + ny * rad[i] * 0.5)
        d = np.array(pts[min(i + 3, n - 1)]) - np.array(pts[i])
        d /= max(np.hypot(*d), 1e-9)
        knee = (base[0] + nx * R * 0.95 - d[0] * R * 0.35 * sgn, base[1] + ny * R * 0.95 - d[1] * R * 0.35 * sgn)
        foot = (knee[0] + d[0] * R * 0.85 * sgn + nx * R * 0.25, knee[1] + d[1] * R * 0.85 * sgn + ny * R * 0.25)
        leg(cv, base, knee, foot, R, pal, flip=sgn < 0)
    hs = head_scale or R * 4.2
    hx, hy = pts[-1]
    head(cv, hx, hy, hs, head_angle, pal, flip=flip, mouth=mouth)
    if pearl_at is not None:
        pearl(cv, pearl_at[0], pearl_at[1], R * 0.75, flame=pal["glow"])
