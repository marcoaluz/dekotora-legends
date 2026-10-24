"""Viseira frontal (aba sobre o para-brisa), 14 peças do catálogo da T-210 (capturas 029–042), T-211.

4 bases (aba reta, aba em V, cromada de lâminas, moldura) + desenhos de neon na face da frente (mesma malha da aba,
faixas emissivas diferentes). Origem = encaixe "visor" (borda de cima do para-brisa, encostado na testa da cabine);
a aba cresce para a frente (+Y). T-214: o jogo inclina as costas junto com o para-brisa e fecha a folga até a
testa com um enchimento feito pela grade medida de cada cabine (`game/scripts/truck/socket_seat.gd`). Nominal: largura 2,10 m, fundo 0,46 m, altura 0,17 m (a menor testa, do Canter,
deixa 0,17 m entre o vidro e o teto).
"""
from __future__ import annotations

import bmesh

from lib import mesh3d as M

from . import t211_kit as K

W, D, H = 2.10, 0.46, 0.17
FZ0, FZ1 = 0.02, 0.13          # faixa de altura da face da frente (onde vai o neon)
N = 24                           # estações ao longo de x (a aba em V dobra no meio)


def _front_y(x, v):
    """Fundo da aba no ponto x: na aba em V o meio avança um pouco (v/3)."""
    return D + v / 3 * (1.0 - abs(x) / (W / 2))


def _lift(x, v):
    """Aba em V vista de frente (rodada 2 da comparação): as PONTAS sobem e o meio fica embaixo (o meio não pode
    descer: cobriria o para-brisa, zona protegida). Sobe até 0,50 x v nas pontas (rodada 3)."""
    return 0.50 * v * abs(x) / (W / 2)


def flap(name, mat, v=0.0, depth_scale=1.0, z_off=0.0, saw=0.0, saw_n=6, thick=1.0):
    """Aba: perfil (costas altas, frente fina e inclinada) varrido ao longo de x. `saw` = zigue-zague na borda."""
    bm = bmesh.new()
    rows = []
    for i in range(N + 1):
        x = -W / 2 + W * i / N
        dy = _front_y(x, v) * depth_scale
        if saw:
            ph = (x + W / 2) / W * saw_n
            dy += saw * (1.0 - 2.0 * abs(ph - int(ph) - 0.5))
        lz = _lift(x, v)
        prof = [(0.0, 0.0 + z_off), (0.0, H * thick + z_off), (dy, min((FZ1 + 0.005) * thick + z_off + lz, H)),
                (dy, FZ0 * thick + z_off + lz), (dy - 0.03, 0.0 + z_off + lz * 0.6)]
        rows.append([bm.verts.new((x, y, z)) for y, z in prof])
    for a, b in zip(rows[:-1], rows[1:]):
        for k in range(len(a)):
            bm.faces.new([a[k], a[(k + 1) % len(a)], b[(k + 1) % len(a)], b[k]])
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def front_strip(name, x0, x1, z0, z1, mat, v=0.0, off=0.006, depth=0.012):
    """Faixa de neon na face da frente de x0 a x1 (segue a dobra da aba em V)."""
    bm = bmesh.new()
    xs = [x0] + ([0.0] if v and x0 < 0.0 < x1 else []) + [x1]
    ring = []
    for x in xs:
        y = _front_y(x, v) + off
        lz = _lift(x, v)
        ring.append([bm.verts.new((x, y, z0 + lz)), bm.verts.new((x, y, min(z1 + lz, H))), bm.verts.new((x, y - depth, min(z1 + lz, H))),
                     bm.verts.new((x, y - depth, z0 + lz))])
    for a, b in zip(ring[:-1], ring[1:]):
        for k in range(4):
            bm.faces.new([a[k], b[k], b[(k + 1) % 4], a[(k + 1) % 4]])
    bm.faces.new(ring[0])
    bm.faces.new(ring[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def top_strip(name, x0, x1, back, width, mat, v=0.0):
    """Faixa no tampo da aba, `back` m atrás da borda da frente (chevrons)."""
    bm = bmesh.new()
    xs = [x0] + ([0.0] if v and x0 < 0.0 < x1 else []) + [x1]
    ring = []
    for x in xs:
        yf = _front_y(x, v) - back
        t = yf / _front_y(x, v)
        z = min(H + (FZ1 + 0.005 + _lift(x, v) - H) * t + 0.006, H - 0.002)
        ring.append([bm.verts.new((x, yf, z)), bm.verts.new((x, yf - width, z + 0.004)), bm.verts.new((x, yf - width, z - 0.006)),
                     bm.verts.new((x, yf, z - 0.008))])
    for a, b in zip(ring[:-1], ring[1:]):
        for k in range(4):
            bm.faces.new([a[k], b[k], b[(k + 1) % 4], a[(k + 1) % 4]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def _dashes(o, m, n, frac, z0=FZ0 + 0.015, z1=FZ1 - 0.015, v=0.0, margin=0.08):
    span = W - 2 * margin
    step = span / n
    for k in range(n):
        x0 = -W / 2 + margin + k * step + step * (1 - frac) / 2
        o.append(front_strip(f"dash_{k}", x0, x0 + step * frac, z0, z1, m["neon"], v=v))


def visor_lamp_row(m):
    o = [flap("flap", m["body"])]
    for k in range(8):
        x = -0.84 + k * 0.24
        o.append(front_strip(f"lamp_{k}", x - 0.05, x + 0.05, FZ0 + 0.012, FZ1 - 0.012, m["neon"], depth=0.02))
        o.append(front_strip(f"lamp_rim_{k}", x - 0.065, x + 0.065, FZ0 + 0.004, FZ1 - 0.004, m["chrome"], off=0.002, depth=0.01))
    return o


def visor_dash_short(m):
    o = [flap("flap", m["body"])]
    _dashes(o, m, 9, 0.30)
    return o


def visor_dash_long(m):
    o = [flap("flap", m["body"])]
    _dashes(o, m, 11, 0.72)
    return o


def visor_twin_line(m):
    o = [flap("flap", m["body"])]
    o.append(front_strip("line_a", -0.98, 0.98, FZ0 + 0.004, FZ0 + 0.03, m["neon"]))
    o.append(front_strip("line_b", -0.98, 0.98, FZ1 - 0.03, FZ1 - 0.004, m["neon"]))
    return o


def visor_morse(m):
    o = [flap("flap", m["body"])]
    z0, z1 = FZ0 + 0.018, FZ1 - 0.018
    segs = [(-0.98, -0.42), (-0.32, -0.20), (-0.08, 0.08), (0.20, 0.32), (0.42, 0.98)]
    for k, (a, b) in enumerate(segs):
        o.append(front_strip(f"seg_{k}", a, b, z0, z1, m["neon"]))
    return o


def visor_single_line(m):
    o = [flap("flap", m["body"])]
    o.append(front_strip("line", -0.98, 0.98, FZ0 + 0.02, FZ1 - 0.02, m["neon"]))
    return o


def _steps(o, m, v, gap=0.0):
    """Neon em degraus: cada degrau desce um pouco em direção ao meio (captura 035/037)."""
    n = 7
    for side in (-1, 1):
        for k in range(n):
            a = gap + k * (0.98 - gap) / n
            b = gap + (k + 1) * (0.98 - gap) / n - 0.012
            dz = 0.006 * (n - 1 - k)
            x0, x1 = (a, b) if side > 0 else (-b, -a)
            o.append(front_strip(f"step_{side}_{k}", x0, x1, FZ0 + 0.012 - dz * 0.4, FZ1 - 0.02 - dz, m["neon"], v=v))


def visor_v_step(m):
    v = 0.10
    o = [flap("flap", m["body"], v=v)]
    _steps(o, m, v)
    return o


def visor_v_band(m):
    v = 0.10
    o = [flap("flap", m["body"], v=v)]
    o.append(front_strip("band", -0.99, 0.99, FZ0 + 0.003, FZ1 - 0.003, m["neon"], v=v))
    return o


def visor_v_split(m):
    v = 0.10
    o = [flap("flap", m["body"], v=v)]
    _steps(o, m, v, gap=0.05)
    return o


def visor_v_chevron(m):
    v = 0.12
    o = [flap("flap", m["body"], v=v)]
    o.append(front_strip("edge", -0.99, 0.99, FZ0 + 0.02, FZ1 - 0.02, m["neon"], v=v))
    for k in range(3):
        o.append(top_strip(f"chev_{k}", -0.97 + k * 0.05, 0.97 - k * 0.05, 0.05 + k * 0.07, 0.025, m["neon"], v=v))
    return o


def visor_split_bars(m):
    o = [flap("flap", m["body"])]
    o.append(front_strip("bar_l", -0.92, -0.06, FZ0 + 0.008, FZ1 - 0.008, m["neon"]))
    o.append(front_strip("bar_r", 0.06, 0.92, FZ0 + 0.008, FZ1 - 0.008, m["neon"]))
    return o


def visor_chrome_v(m):
    v = 0.10
    o = [flap("flap", m["body"], v=v)]
    o.append(front_strip("lip", -1.0, 1.0, FZ0, FZ0 + 0.02, m["chrome"], v=v, off=0.008, depth=0.02))
    o.append(front_strip("lip_top", -1.0, 1.0, FZ1 - 0.012, FZ1 + 0.004, m["chrome"], v=v, off=0.004, depth=0.015))
    return o


def slat(name, mat, depth, z0, saw=0.035, saw_n=6, t=0.03):
    """Lâmina cromada inclinada; a borda da frente desce em zigue-zague (dentes para baixo, captura 041)."""
    bm = bmesh.new()
    rows = []
    for i in range(N * 2 + 1):
        x = -W / 2 + W * i / (N * 2)
        ph = (x + W / 2) / W * saw_n
        dz = saw * (1.0 - 2.0 * abs(ph - int(ph) - 0.5))
        prof = [(0.0, z0 + t + 0.03), (0.0, z0 + t + 0.06), (depth, z0 + t), (depth + 0.005, z0 + saw - dz),
                (depth - 0.02, z0 + saw - dz)]
        rows.append([bm.verts.new((x, y, z)) for y, z in prof])
    for a, b in zip(rows[:-1], rows[1:]):
        for k in range(5):
            bm.faces.new([a[k], a[(k + 1) % 5], b[(k + 1) % 5], b[k]])
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def visor_chrome_louver(m):
    o = [M.box("back", (W, 0.05, H), (0, 0.025, H / 2), m["body"], bevel=0.01, seg=1)]
    for k in range(3):                                   # 3 lâminas em degrau: a de baixo avança mais
        o.append(slat(f"blade_{k}", m["chrome"], 0.26 + 0.08 * k, 0.07 - 0.035 * k))
    return o


def visor_neon_frame(m):
    o = [flap("flap", m["body"])]
    y = D + 0.01
    pts = [(-W / 2 + 0.02, y, 0.02), (-W / 2 + 0.02, y, FZ1 + 0.01), (W / 2 - 0.02, y, FZ1 + 0.01), (W / 2 - 0.02, y, 0.02)]
    o.append(M.tube("frame", pts, 0.016, m["neon"], seg=6))
    for k in range(13):                                  # pontos verdes ao longo da face
        x = -0.9 + k * 0.15
        o.append(front_strip(f"dot_{k}", x - 0.018, x + 0.018, FZ0 + 0.02, FZ0 + 0.05, m["led"]))
    return o


def _detail(m, v=0.0, louver=False):
    """T-214: acabamento comum a todas as viseiras: fileira de parafusos no tampo (perto das costas, onde a aba é
    presa na testa) e friso cromado na borda de baixo da frente (as lâminas cromadas não precisam do friso)."""
    top = K.Face((-W / 2, 0.035, H + 0.0005), (W, 0, 0), (0, 0.03, 0))
    o = [K.bolts("bolts_top", top, [(0.05 + 0.9 * k / 9, 0.5) for k in range(10)], m["chrome"], r=0.009, h=0.005, off=0.0)]
    if not louver:
        o.append(front_strip("lip_low", -W / 2 + 0.02, W / 2 - 0.02, FZ0 - 0.014, FZ0 - 0.002, m["chrome"], v=v, off=0.003,
                             depth=0.008))
    return o


def _p(pid, name, build, caps, color="preto_ciano", base="reta", v=0.0):
    louver = base == "laminas"
    return {"id": pid, "name": name, "build": lambda m, b=build: b(m) + _detail(m, v, louver), "captures": caps,
            "has_sign": False, "default_color": color, "slot": "visor", "socket": "visor", "nominal_w": W, "base": base}


PARTS = [
    _p("visor_lamp_row", "Viseira com 8 lanternas", visor_lamp_row, "029", color="branco_azul"),
    _p("visor_dash_short", "Viseira neon pontilhada", visor_dash_short, "030"),
    _p("visor_dash_long", "Viseira neon tracejada", visor_dash_long, "031"),
    _p("visor_twin_line", "Viseira de 2 linhas", visor_twin_line, "032"),
    _p("visor_morse", "Viseira traço-ponto", visor_morse, "033"),
    _p("visor_single_line", "Viseira de 1 linha", visor_single_line, "034"),
    _p("visor_v_step", "Viseira em V com degraus", visor_v_step, "035", base="v", v=0.10),
    _p("visor_v_band", "Viseira em V larga", visor_v_band, "036", base="v", v=0.10),
    _p("visor_v_split", "Viseira em V partida", visor_v_split, "037", base="v", v=0.10),
    _p("visor_v_chevron", "Viseira de 3 chevrons", visor_v_chevron, "038", base="v", v=0.12),
    _p("visor_split_bars", "Viseira de 2 barras", visor_split_bars, "039"),
    _p("visor_chrome_v", "Viseira cromada em V", visor_chrome_v, "040", color="cromo_ciano", base="v", v=0.10),
    _p("visor_chrome_louver", "Viseira cromada de lâminas", visor_chrome_louver, "041", color="cromo_ciano", base="laminas"),
    _p("visor_neon_frame", "Moldura neon da cabine", visor_neon_frame, "042", base="moldura"),
]
