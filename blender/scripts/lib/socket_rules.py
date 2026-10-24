"""Encaixes (caixas-limite) e zonas protegidas de um caminhão, a partir das medidas (`truck_measure.measure`). T-211.

Regras (docs/REFERENCIA_PECAS.md, seção 13, e decisão 12 do Marco):
- TODAS as peças podem ser instaladas juntas: as caixas de encaixes diferentes NÃO se cruzam;
- nenhuma peça pode cobrir farol, lanterna dianteira/traseira, placa, para-brisa, porta ou roda: essas são as ZONAS
  PROTEGIDAS (volume na frente de cada uma, até onde a câmera enxerga); a caixa de um encaixe também não pode
  cruzar uma zona, salvo isenção declarada (ex.: a placa da frente fica EM CIMA do para-choque);
- escala uniforme pela largura (0,85–1,15) para deque, viseira, para-choques e retrovisor.
Coordenadas do Godot (x direita, y cima, frente = -z). Caixa = [[x0, y0, z0], [x1, y1, z1]].
"""
from __future__ import annotations

# Altura do centro da placa da frente por cabine (igual a TruckPlateSpots.FRONT_Y no jogo).
FRONT_PLATE_Y = {"chata": 0.775, "jac": 0.70, "curta": 0.62, "americana": 0.50, "canter": 0.60}
PLATE_HALF = (0.30, 0.13)          # meia largura/altura da área da placa (placa 0,44 x 0,22 + folga)
SCALE_MIN, SCALE_MAX = 0.85, 1.15  # escala automática "uniform"
# Encaixes que só existem em baú fechado (a graneleira é aberta).
BOX_ONLY = ("rocket", "box_light_top", "box_light_r", "box_light_l", "ladder_r", "ladder_l", "roof_paint", "rear_paint")


def _box(x0, y0, z0, x1, y1, z1) -> list:
    return [[round(min(x0, x1), 3), round(min(y0, y1), 3), round(min(z0, z1), 3)],
            [round(max(x0, x1), 3), round(max(y0, y1), 3), round(max(z0, z1), 3)]]


def _mirror(b: list) -> list:
    return [[-b[1][0], b[0][1], b[0][2]], [-b[0][0], b[1][1], b[1][2]]]


def protected_zones(m: dict, cab: str, extra_stacks: list) -> dict:
    c = m["cab"]
    z = {}
    w0, w1 = c["windshield"]
    z["windshield"] = {"box": _box(w0[0], w0[1], w0[2] - 1.2, w1[0], w1[1] - 0.04, w1[2]), "exempt": []}
    for kind, key in (("headlights", "headlight"), ("front_lamps", "front_lamp")):
        for side, b in m[kind].items():
            z[f"{key}_{side}"] = {"box": _box(b[0][0], b[0][1], b[0][2] - 1.0, b[1][0], b[1][1], b[1][2]), "exempt": []}
    # setas da frente e de trás (lamparinas que o TruckNode cria: x ±1,22; 0,34 x 0,2 x 0,14)
    fz = c["front_z"]
    rz = m["box"]["rear_z"] if m.get("box") else 0.0
    for side, sx in (("l", -1), ("r", 1)):
        # a seta da frente fica na quina do para-choque: um para-choque novo leva a seta junto (ponto SIGNAL_* da peça)
        z[f"blinker_front_{side}"] = {"box": _box(sx * 1.05, 0.85, fz - 1.0, sx * 1.39, 1.05, fz + 0.07), "exempt": ["front_bumper"]}
        z[f"blinker_rear_{side}"] = {"box": _box(sx * 1.05, 0.95, max(0.05, rz + 0.01), sx * 1.39, 1.15, 0.9), "exempt": []}
    for side, b in m["rear_lamps"].items():
        z[f"rear_lamp_{side}"] = {"box": _box(b[0][0], b[0][1], max(b[0][2], rz + 0.01), b[1][0], b[1][1], b[1][2] + 0.8), "exempt": []}
    fy = FRONT_PLATE_Y.get(cab, 0.7)
    fb = m["mounts"].get("MOUNT_FRONT_BUMPER", [0, 0.5, fz])
    z["front_plate"] = {"box": _box(-PLATE_HALF[0], fy - PLATE_HALF[1], fb[2] - 0.6, PLATE_HALF[0], fy + PLATE_HALF[1], fb[2] - 0.12),
                        "exempt": ["front_bumper"]}
    ry = m["mounts"].get("MOUNT_REAR_PLATE", [0, 1.0, 0])[1]
    z["rear_plate"] = {"box": _box(-PLATE_HALF[0], ry - PLATE_HALF[1], 0.02, PLATE_HALF[0], ry + PLATE_HALF[1], 0.6),
                       "exempt": ["rear_bumper"]}
    d = c["door"]
    for side, sx in (("l", -1), ("r", 1)):
        z[f"door_{side}"] = {"box": _box(sx * (c["half_w"] - 0.02), d["y"][0], d["z"][0], sx * (c["half_w"] + 0.35), d["y"][1], d["z"][1]),
                             "exempt": []}
    for n, b in m["wheels"].items():
        sx = 1 if b[1][0] > 0 else -1
        out = b[1][0] + 0.25 if sx > 0 else b[0][0] - 0.25
        x0, x1 = (b[0][0] - 0.02, out) if sx > 0 else (out, b[1][0] + 0.02)
        z["wheel_" + n[6:]] = {"box": _box(x0, b[0][1], b[0][2] - 0.03, x1, b[1][1] + 0.03, b[1][2] + 0.03), "exempt": ["hubcaps"]}
    if "box" in m and not m.get("open_body"):
        bx = m["box"]
        z["rear_doors"] = {"box": _box(-(bx["half_w"] - 0.1), bx["bottom_y"] + 0.12, bx["rear_z"] + 0.01,
                                       bx["half_w"] - 0.1, bx["top_y"] - 0.1, bx["rear_z"] + 0.35), "exempt": []}
    return z


def sockets(m: dict, extra_stacks: list) -> dict:
    """Caixas-limite de TODOS os encaixes do catálogo novo (seção 13.1). `extra_stacks` = posições Godot dos
    escapamentos altos (TruckNode.extra_mounts), que ficam no vão entre a cabine e o baú."""
    c = m["cab"]
    s = {}
    w0, w1 = c["windshield"]
    hw = c["half_w"]
    if "surf" in m:                                   # T-214: apoio medido por raios na malha real
        s.update(seat_sockets(m))
    else:                                             # (sem grades: regra antiga da T-211)
        rhw = c["roof_half_w"]
        s["andon"] = {"box": _box(-rhw, c["roof_y"] + 0.01, c["slope_front_z"], rhw, c["roof_y"] + 1.05, c["roof_back_z"]),
                      "anchor": [0.0, round(c["roof_y"] + 0.012, 3), round(min(c["roof_back_z"] - 0.02, c["roof_front_z"] + 1.05), 3)],
                      "width": round(2 * rhw, 3), "fit": "uniform"}
        vb = c["visor_back_z"]
        vy0 = w1[1] - 0.03
        vhw = min(c["visor_half_w"], hw)
        s["visor"] = {"box": _box(-vhw, vy0, vb - 0.6, vhw, min(c["roof_y"], w1[1] + 0.45), vb + 0.06),
                      "anchor": [0.0, round(vy0 + 0.005, 3), round(vb + 0.03, 3)], "width": round(2 * vhw, 3), "fit": "uniform"}
    # retrovisor (haste): quina da frente, para fora da cabine, na frente da porta
    d = c["door"]
    for side, sx in (("r", 1), ("l", -1)):
        b = _box(sx * (hw + 0.02), w0[1] - 0.25, c["front_z"] - 0.9, sx * (hw + 0.75), w1[1] + 0.25, d["z"][0] - 0.02)
        s["mirror_stay_" + side] = {"box": b, "anchor": [sx * round(hw + 0.02, 3), round(w0[1], 3), round(c["front_z"], 3)],
                                    "width": round(2 * hw, 3), "fit": "uniform"}
    # para-choque da frente: embaixo dos faróis e lanternas
    lamp_y = min([b[0][1] for k in ("headlights", "front_lamps") for b in m[k].values()] or [0.85])
    fz = c["front_z"]
    fb = m["mounts"].get("MOUNT_FRONT_BUMPER", [0, 0.5, fz])
    s["front_bumper"] = {"box": _box(-(hw + 0.15), 0.16, fb[2] - 0.65, hw + 0.15, lamp_y - 0.03, fb[2] + 0.12),
                         "anchor": [0.0, round(fb[1], 3), round(fb[2], 3)], "width": round(2 * hw, 3), "fit": "uniform"}
    # grade: entre os faróis, do para-choque até embaixo do para-brisa
    inner = min([abs(b[1][0]) if b[1][0] < 0 else abs(b[0][0]) for b in m["headlights"].values()] + [0.8])
    s["grille"] = {"box": _box(-(inner - 0.04), lamp_y, fz - 0.11, inner - 0.04, w0[1] - 0.05, fz + 0.12),
                   "anchor": [0.0, round((lamp_y + w0[1]) / 2, 3), round(fz, 3)], "width": round(2 * (inner - 0.04), 3), "fit": "uniform"}
    # escapamentos altos (vão entre a cabine e o baú): caixa em volta do ponto de cada lado
    stack_zmax = -99.0
    bf_lim = m["box"]["front_z"] - 0.01 if m.get("box") else 99.0
    for side, p in (("r", extra_stacks[0]), ("l", extra_stacks[1])):
        b = _box(p[0] - 0.17, p[1] - 0.10, p[2] - 0.15, p[0] + 0.17, p[1] + 3.0, min(p[2] + 0.15, bf_lim))
        s["exhaust_stacks_" + side] = {"box": b, "anchor": [round(p[0], 3), round(p[1], 3), round(p[2], 3)], "fit": "point"}
        stack_zmax = max(stack_zmax, b[1][2])
    bx = m.get("box")
    if bx:
        bh, top, bot, bf, rz = bx["half_w"], bx["top_y"], bx["bottom_y"], bx["front_z"], bx["rear_z"]
        # escada: na lateral do baú, logo atrás da quina da frente (e atrás dos escapamentos)
        lz0 = max(bf + 0.08, stack_zmax + 0.03)
        for side, sx in (("r", 1), ("l", -1)):
            s["ladder_" + side] = {"box": _box(sx * (bh + 0.04), bot, lz0, sx * (bh + 0.32), top, lz0 + 0.34),
                                   "anchor": [sx * round(bh + 0.04, 3), round(bot, 3), round(lz0 + 0.17, 3)], "fit": "stretch_y"}
        if not m.get("open_body"):
            s["rocket"] = {"box": _box(-(bh + 0.03), top + 0.025, bf + 0.05, bh + 0.03, top + 0.40, rz - 0.05),
                           "anchor": [0.0, round(top + 0.025, 3), round(rz - 0.05, 3)], "length": round(rz - bf - 0.10, 3), "fit": "stretch9"}
            s["box_light_top"] = {"box": _box(-bh, top, bf, bh, top + 0.02, rz), "fit": "face"}
            for side, sx in (("r", 1), ("l", -1)):
                s["box_light_" + side] = {"box": _box(sx * bh, bot, bf, sx * (bh + 0.03), top, rz), "fit": "face"}
        # saia lateral: embaixo do baú, entre a roda da frente e a 1ª de trás
        fw = [b for n, b in m["wheels"].items() if n.startswith("wheel_f")]
        rw = [b for n, b in m["wheels"].items() if n.startswith("wheel_r")]
        z0 = max(max(b[1][2] for b in fw) + 0.08, stack_zmax + 0.03)
        z1 = min(b[0][2] for b in rw) - 0.08
        for side, sx in (("r", 1), ("l", -1)):
            s["side_skirts_" + side] = {"box": _box(sx * (bh - 0.40), 0.22, z0, sx * (bh + 0.02), bot - 0.02, z1),
                                        "anchor": [sx * round(bh, 3), 0.22, round(z0, 3)], "length": round(z1 - z0, 3), "fit": "stretch9"}
        # para-choque de trás: embaixo das portas, atrás do baú, sem cobrir as lanternas
        # (sem cobrir as lanternas de fábrica e as setas: a parte do meio, entre as lanternas)
        rl = [min(abs(b[0][0]), abs(b[1][0])) for b in m["rear_lamps"].values()] or [0.8]
        rbx = min(rl) - 0.03
        s["rear_bumper"] = {"box": _box(-rbx, 0.15, rz + 0.01, rbx, bot + 0.10, rz + 0.55),
                            "anchor": [0.0, 0.15, round(rz + 0.01, 3)], "width": round(2 * rbx, 3), "fit": "uniform"}
    # superfícies (sem volume: textura do material) e itens sem lugar físico
    for k in ("mural_r", "mural_l", "roof_paint", "rear_paint"):
        s[k] = {"fit": "face"}
    for k in ("hubcaps", "horn", "interior", "decals"):
        s[k] = {"fit": "none"}
    if m.get("open_body"):
        for k in BOX_ONLY:
            s.pop(k, None)
    return s


def overlap(a: list, b: list, eps: float = 0.001) -> bool:
    """Caixas se cruzam (mais que `eps` em todos os eixos)? Encostar não conta."""
    return all(min(a[1][i], b[1][i]) - max(a[0][i], b[0][i]) > eps for i in range(3))


def check(sk: dict, zones: dict) -> list:
    """Problemas de projeto: encaixes que se cruzam e encaixes que entram numa zona protegida (sem isenção)."""
    probs = []
    vol = [(k, v["box"]) for k, v in sk.items() if "box" in v]
    for i, (ka, a) in enumerate(vol):
        for kb, b in vol[i + 1:]:
            if overlap(a, b):
                probs.append(f"encaixes {ka} x {kb} se cruzam")
        for zk, zv in zones.items():
            base = ka[:-2] if ka[-2:] in ("_r", "_l") else ka
            if base in zv["exempt"] or ka in zv["exempt"]:
                continue
            if overlap(a, zv["box"]):
                probs.append(f"encaixe {ka} entra na zona {zk}")
    return probs


# ----------------------------------------------------------------------------- apoio real do deque e da viseira (T-214)
# Iguais a game/scripts/truck/socket_seat.gd (o jogo assenta cada peça pela mesma grade).
NOMINAL_W = 2.10                   # largura nominal do deque e da viseira (Blender: deck_t211.W, visor_t211.W)
VISOR_H = 0.17                     # altura nominal da viseira
VISOR_DMAX = 0.62                  # fundo máximo de uma viseira (aba + dentes), nominal
DECK_DMAX = 1.00                   # fundo máximo de um deque, nominal
FILL_MAX = 0.55                    # m: o enchimento atrás da viseira vai no máximo até aqui (senão a coluna fica de fora)
CROWN = 0.05                       # m: queda do teto (abaulado) que ainda conta como "largura útil" do deque
MISS = -99.0
STACK_H = 1.45                     # m: altura máxima do deque de 2 níveis acima do ponto mais alto do teto (T-215)
STACK_Y = 4.55                     # m: e nunca mais alto que isto do chão


JUMP = 0.15                        # m: degrau entre vizinhos da grade = borda (não interpola através dela)


def grid_roof(g: dict, x: float, z: float) -> float:
    """Altura do teto em (x, z) (bilinear; numa borda vale o vizinho MAIS ALTO; fora da grade = MISS)."""
    return _bilinear(g["h"], g["x0"], g["dx"], g["nx"], g["z0"], g["dz"], g["nz"], x, z, max)


def grid_front(g: dict, x: float, y: float) -> float:
    """z da superfície da frente em (x, y) (bilinear; numa borda vale o vizinho MAIS À FRENTE)."""
    return _bilinear(g["z"], g["x0"], g["dx"], g["nx"], g["y0"], g["dy"], g["ny"], x, y, min)


def _bilinear(vals, x0, dx, nx, r0, dr, nr, x, r, pick=max):
    fx, fr = (x - x0) / dx, (r - r0) / dr
    if fx < 0 or fr < 0 or fx > nx - 1 or fr > nr - 1:
        return MISS
    i, j = min(int(fx), nx - 2), min(int(fr), nr - 2)
    tx, tr = fx - i, fr - j
    v = [vals[(j + b) * nx + i + a] for b in (0, 1) for a in (0, 1)]
    good = [q for q in v if q > MISS + 1]
    if not good:
        return MISS
    if len(good) < 4 or max(good) - min(good) > JUMP:
        return pick(good)
    return (v[0] * (1 - tx) + v[1] * tx) * (1 - tr) + (v[2] * (1 - tx) + v[3] * tx) * tr


def _scale(w: float) -> float:
    return max(SCALE_MIN, min(SCALE_MAX, w / NOMINAL_W))


def seat_sockets(m: dict) -> dict:
    """Encaixes andon (deque) e visor (viseira) a partir das grades medidas por raios (T-214):
    - viseira: borda de baixo 3 cm abaixo do topo do vidro, costas no plano do vidro (inclinação `lean`) encostadas no
      ponto mais à frente da testa; o enchimento (feito no jogo) vai das costas até a testa, no máximo FILL_MAX e
      nunca além da frente do deque (`fill_max_z`);
    - deque: largura = parte do teto que cai menos que CROWN (o assento cobre o resto); frente 1,05 m à frente do fim
      do teto plano, sem passar das costas da viseira."""
    c, sf = m["cab"], m["surf"]
    roof, front, k = sf["roof"], sf["front"], sf["lean"]
    w1 = c["windshield"][1]
    out = {}
    # --- costas da viseira (o deque não pode passar delas)
    vhw = min(c["visor_half_w"], c["half_w"])
    sv = _scale(2 * vhw)
    vy0 = round(w1[1] - 0.03, 3)
    hs = VISOR_H * sv
    xs = [front["x0"] + front["dx"] * i for i in range(front["nx"]) if abs(front["x0"] + front["dx"] * i) <= vhw * 0.95]
    zmin = 1e9
    for x in xs:
        for jj in range(0, 11):
            yy = hs * jj / 10
            zf = grid_front(front, x, vy0 + yy)
            if zf > MISS + 1:
                zmin = min(zmin, zf - k * yy)
    vz0 = round(zmin + 0.004, 3)
    ztop = vz0 + k * VISOR_H * SCALE_MAX
    # --- deque
    rb = c["roof_front_z"]                     # fim do teto da cabine pela grade (os vértices podem cair no vão)
    while grid_roof(roof, 0.0, rb + 0.025) > c["roof_shell_y"] - 0.30 and rb < c["roof_back_z"] + 0.3:
        rb += 0.025
    front_lim = max(ztop + 0.03, w1[2] + 0.02)  # nem nas costas da viseira, nem na frente da borda de cima do vidro
    wd = 2 * c["roof_half_w"]
    max_depth = None
    for _ in range(3):                          # largura útil e posição dependem uma da outra: 3 voltas bastam
        sd = _scale(wd)
        dd = DECK_DMAX * sd
        az = min(rb - 0.02, max(c["roof_front_z"] + 1.05, front_lim + dd))
        if az - dd < front_lim:                 # teto curto (cabine americana): o deque fica menor (escala pelo fundo)
            max_depth = round(az - front_lim, 3)
            dd = max_depth
        zs = [az - dd * t / 8 for t in range(9)]
        usable = 0.0
        x = 0.0
        while x <= c["roof_half_w"] + 0.001:
            ok = True
            for z in zs:
                top = max(grid_roof(roof, xx, z) for xx in (-0.3, 0.0, 0.3))
                if min(grid_roof(roof, x, z), grid_roof(roof, -x, z)) < top - CROWN:
                    ok = False
                    break
            if not ok:
                break
            usable = x
            x += 0.025
        wd = min(2 * c["roof_half_w"], 2 * (usable + 0.03))
    sd = _scale(wd)
    dd = DECK_DMAX * sd
    if max_depth is not None and max_depth < dd:
        dd = max_depth
        sd = dd / DECK_DMAX
    deck_front = az - dd
    hx = max(wd / 2, NOMINAL_W * sd / 2) + 0.04
    lo, hi = 1e9, -1e9
    for t in range(9):
        z = az - dd * t / 8
        for q in range(-8, 9):
            h = grid_roof(roof, hx * q / 8, z)
            if h > MISS + 1:
                lo, hi = min(lo, h), max(hi, h)
    ay = grid_roof(roof, 0.0, az)
    stack_max = round(min(hi + STACK_H, STACK_Y), 3)    # T-215: topo do deque empilhado (2 níveis) neste caminhão
    out["andon"] = {"box": _box(-hx, lo - 0.03, deck_front - 0.012, hx, max(hi + 1.10, stack_max + 0.03), rb + 0.005),
                    "anchor": [0.0, round(ay, 3), round(az, 3)], "width": round(wd, 3), "fit": "seat",
                    "usable_half_w": round(usable, 3), "roof_end_z": round(rb, 3), "stack_max_y": stack_max}
    if max_depth is not None:
        out["andon"]["max_depth"] = max_depth
    if dd < 0.6:
        out["andon"]["problem"] = "deque nao cabe entre a viseira e o fim da cabine"
    # --- viseira: o enchimento vai até a testa, sem passar da frente do deque
    fill_max = round(deck_front - 0.02, 3)
    fill_end = ztop
    for x in xs:
        zf = grid_front(front, x, vy0 + VISOR_H * SCALE_MAX)
        if MISS + 1 < zf <= ztop + FILL_MAX:
            fill_end = max(fill_end, zf)
    fill_end = min(fill_end, fill_max)
    out["visor"] = {"box": _box(-(vhw + 0.03), vy0 - 0.01, vz0 - VISOR_DMAX * SCALE_MAX - 0.03, vhw + 0.03,
                                vy0 + VISOR_H * SCALE_MAX + 0.02, round(fill_end + 0.006, 3)),
                    "anchor": [0.0, vy0, vz0], "width": round(2 * vhw, 3), "fit": "seat", "lean": k,
                    "fill_max_z": fill_max}
    return out
