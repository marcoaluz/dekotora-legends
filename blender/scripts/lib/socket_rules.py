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
FRONT_PLATE_Y = {"chata": 0.775, "jac": 0.70, "curta": 0.62, "americana": 0.50, "canter": 0.60,
                 "flat_wide": 0.66, "flat_quad": 0.66}
PLATE_HALF = (0.30, 0.13)          # meia largura/altura da área da placa (placa 0,44 x 0,22 + folga)
SCALE_MIN, SCALE_MAX = 0.85, 1.15  # escala automática "uniform"
ROCKET_H = 0.38                    # m: altura máxima do foguete acima do teto do baú (T-231)
RB_DEPTH = 0.55                    # m: fundo máximo do para-choque traseiro com as lanternas (T-231)
STRIP_W, STRIP_T = 0.025, 0.03     # m: largura e espessura reservadas ao contorno de LED (T-231)
LADDER_OUT = 0.16                  # m: (T-233, antigo) quanto a escada saía da lateral do baú
TM_LADDER_DEPTH = 0.085            # = truck_measure.LADDER_DEPTH (escada na frente do baú, T-263)
TM_LADDER_HALF = 0.17              # = truck_measure.LADDER_HALF
LEDBOX_H = 0.16                    # = accessories/ladder_t233.LEDBOX_H (caixa com LED no alto da escada, T-263)
LADDER_STEP = 0.165                # m: o estribo embaixo sai até isto da lataria (accessories/ladder_t233.STEP_OUT + folga)
TM_FB_DEPTH = 0.62                 # = truck_measure.FB_DEPTH (para-choque da frente, T-233)
WRAP_T = 0.10                      # m: espessura nominal da aba lateral do para-choque grande (accessories/front_t264.WT)
WRAP_GAP = 0.004                   # m: folga entre a aba e a lataria (T-264)
CAP_T = 0.018                      # m: espessura da tampa que fecha o vão da quina (= BumperWrap.CAP_T no jogo)
TM_MIRROR_REACH = 0.50            # = truck_measure.MIRROR_REACH (haste do retrovisor, T-233)
PAD_BELOW, PAD_ABOVE = 0.06, 0.11  # m: o que a haste passa abaixo da chapa de baixo / acima da de cima (T-263)
PAD_TOP = 0.10                     # m: a chapa de cima fica pelo menos isto abaixo do topo do para-brisa
SKIRT_MIN = 0.40                   # = truck_measure.SKIRT_MIN (T-265; T-233: 0,60)
# Encaixes que só existem em baú fechado (a graneleira é aberta).
# T-232: o mural também (a graneleira/lona/tanque/caçamba não têm lateral de baú fechado)
BOX_ONLY = ("rocket_r", "rocket_l", "box_light_top", "box_light_r", "box_light_l", "roof_paint", "rear_paint",
            "mural_r", "mural_l")


def _box(x0, y0, z0, x1, y1, z1) -> list:
    return [[round(min(x0, x1), 3), round(min(y0, y1), 3), round(min(z0, z1), 3)],
            [round(max(x0, x1), 3), round(max(y0, y1), 3), round(max(z0, z1), 3)]]


def _mirror(b: list) -> list:
    return [[-b[1][0], b[0][1], b[0][2]], [-b[0][0], b[1][1], b[1][2]]]


def protected_zones(m: dict, cab: str, extra_stacks: list) -> dict:
    c = m["cab"]
    z = {}
    w0, w1 = c["windshield"]
    # T-263: a base da haste do retrovisor encosta na coluna, ao lado do vidro (a caixa do vidro passa da coluna nas
    # quinas arredondadas); o teste do jogo confere que a haste não fica na frente do vidro (FrameContact)
    z["windshield"] = {"box": _box(w0[0], w0[1], w0[2] - 1.2, w1[0], w1[1] - 0.04, w1[2]), "exempt": ["mirror_stay"]}
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
        # T-231: o para-choque traseiro novo SUBSTITUI as lanternas de fábrica de baixo (fica atrás delas e leva
        # lanternas próprias, que acendem): isento desta zona, como o da frente é isento da seta
        z[f"rear_lamp_{side}"] = {"box": _box(b[0][0], b[0][1], max(b[0][2], rz + 0.01), b[1][0], b[1][1], b[1][2] + 0.8),
                                  "exempt": ["rear_bumper"]}
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
        # T-265: `round` = cilindro do pneu + 3 cm (o eixo é X): a saia com arco contorna a roda e usa os cantos da caixa
        r = max(b[1][2] - b[0][2], b[1][1] - b[0][1]) / 2 + 0.03
        z["wheel_" + n[6:]] = {"box": _box(x0, b[0][1], b[0][2] - 0.03, x1, b[1][1] + 0.03, b[1][2] + 0.03), "exempt": ["hubcaps"],
                               "round": [round((b[0][2] + b[1][2]) / 2, 3), round((b[0][1] + b[1][1]) / 2, 3), round(r, 3)]}
    if "box" in m and not m.get("open_body"):
        bx = m["box"]
        z["rear_doors"] = {"box": _box(-(bx["half_w"] - 0.1), bx["bottom_y"] + 0.12, bx["rear_z"] + 0.01,
                                       bx["half_w"] - 0.1, bx["top_y"] - 0.1, bx["rear_z"] + 0.35), "exempt": ["rear_paint"]}   # T-232: tinta na porta
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
    # retrovisor (haste): T-233 medido nos .glb (truck_measure.front_side): da lateral da cabine junto à coluna do
    # para-brisa até MIRROR_REACH para fora, da borda de baixo do vidro - 0,25 até a de cima + 0,20, da frente da
    # cabine - MIRROR_AHEAD até a porta; o espelho de fábrica (caixa `hide`) some quando a haste nova está montada
    d = c["door"]
    fs = m.get("front")
    for side, sx in (("r", 1), ("l", -1)):
        if fs:
            mr = fs["mirror_" + side]
            xs = mr["x_side"]
            pl = mr.get("pillar")
            ok = [(round(pl["y0"] + i * pl["dy"], 3), p) for i, p in enumerate(pl["pts"]) if p] if pl else []
            ok = [q for q in ok if q[0] <= w1[1] - PAD_TOP]
            if ok:
                # T-263: a base da haste encosta na coluna medida (chapa + espaçador). Duas caixas: a da base (junto da
                # lataria, entre a coluna e a porta) e a dos braços/espelho (por fora). `pad_y` = faixa de altura onde as
                # chapas podem ficar (`clear_mirror` encolhe as caixas na altura em vez de empurrá-las para fora)
                x_in = min(abs(p[0]) for _, p in ok) - 0.02
                x_top = max(abs(p[0]) for _, p in ok)
                ylo, yhi = ok[0][0], ok[-1][0]
                zp = min(p[1] for _, p in ok)
                base = _box(sx * x_in, ylo - PAD_BELOW, zp - 0.06, sx * (x_top + 0.09), yhi + PAD_ABOVE, mr["z"][1])
                arms = _box(sx * (x_top + 0.03), ylo - PAD_BELOW, mr["z"][0], sx * (max(xs, x_top) + TM_MIRROR_REACH),
                            yhi + PAD_ABOVE, mr["z"][1])
                zc = round(sum(p[1] for _, p in ok) / len(ok), 3)
                s["mirror_stay_" + side] = {"boxes": [base, arms], "anchor": [round(sx * x_top, 3), mr["anchor"][1], zc],
                                            "width": round(2 * hw, 3), "fit": "stay", "window_h": mr["window_h"],
                                            "hide": mr["stock"], "hide_parts": mr.get("stock_parts", []),
                                            "pillar": pl, "pad_y": [ylo, yhi],
                                            "box": [[min(base[0][i], arms[0][i]) for i in range(3)],
                                                    [max(base[1][i], arms[1][i]) for i in range(3)]]}
                continue
            b = _box(sx * (xs + 0.004), mr["y"][0], mr["z"][0], sx * (xs + TM_MIRROR_REACH), mr["y"][1], mr["z"][1])
            s["mirror_stay_" + side] = {"box": b, "anchor": mr["anchor"], "width": round(2 * hw, 3), "fit": "stay",
                                        "window_h": mr["window_h"], "hide": mr["stock"]}
        else:
            b = _box(sx * (hw + 0.02), w0[1] - 0.25, c["front_z"] - 0.9, sx * (hw + 0.75), w1[1] + 0.25, d["z"][0] - 0.02)
            s["mirror_stay_" + side] = {"box": b, "anchor": [sx * round(hw + 0.02, 3), round(w0[1], 3), round(c["front_z"], 3)],
                                        "width": round(2 * hw, 3), "fit": "uniform"}
    # para-choque da frente: T-233 encosta na FRENTE do nariz de fábrica (que ele cobre), embaixo dos faróis e lanternas;
    # ponto = topo, centro, costas (a peça cresce para a frente e para baixo e encolhe a altura do meio onde o farol é baixo)
    lamp_y = min([b[0][1] for k in ("headlights", "front_lamps") for b in m[k].values()] or [0.85])
    fz = c["front_z"]
    fb = m["mounts"].get("MOUNT_FRONT_BUMPER", [0, 0.5, fz])
    if fs:
        ns = fs["nose"]
        back = round(ns["z"] - 0.004, 3)
        s["front_bumper"] = {"box": _box(-ns["half_w"], ns["floor_y"], back - TM_FB_DEPTH, ns["half_w"], ns["top_y"], back),
                             "anchor": [0.0, ns["top_y"], back], "width": round(2 * hw, 3), "fit": "bumper",
                             "height": round(ns["top_y"] - ns["floor_y"], 3)}
        # T-264: abas laterais do para-choque grande (capturas 054–062): da costa do para-choque até a roda da frente,
        # coladas na lateral da cabine (`truck_measure._wrap`, raios). `wrap.<lado>` = x do lado de dentro da aba (lataria
        # + WRAP_GAP) e comprimento atrás das costas; uma caixa por aba. Os para-choques da T-233 não usam (ficam na 1ª caixa).
        wrap, boxes = {}, []
        for side, sx in (("r", 1), ("l", -1)):
            w = fs.get("wrap_" + side) or {}
            if w.get("len", 0.0) <= 0.0:
                continue
            xin = round(w["x"] + WRAP_GAP, 3)
            ln = round(w["z1"] - back, 3)
            # perfil da quina arredondada da cabine (dz atrás das costas, x da lataria): o jogo fecha o vão entre a quina e
            # a aba com uma tampa no topo do para-choque (BumperWrap.corner_cap), na caixa `corner`
            prof = [[round(p[0] + (ns["z"] - back), 3), max(p[1], round(xin - 0.40, 3))] for p in w.get("prof", [])]
            wrap[side] = {"x": xin, "len": ln, "prof": prof}
            boxes.append(_box(sx * (w["x"] + 0.001), ns["floor_y"], back, sx * (xin + WRAP_T * SCALE_MAX + 0.012),
                              ns["top_y"], w["z1"]))
            if prof:
                boxes.append(_box(sx * (min(p[1] for p in prof) - 0.006), ns["top_y"] - CAP_T - 0.006, back,
                                  sx * (xin + 0.002), ns["top_y"], back + max(p[0] for p in prof) + 0.006))
        if wrap:
            fb_ = s["front_bumper"]
            hx = max([ns["half_w"]] + [v["x"] + WRAP_T * SCALE_MAX + 0.012 for v in wrap.values()])
            fb_["box"] = _box(-hx, ns["floor_y"], back - TM_FB_DEPTH, hx, ns["top_y"], back)
            fb_["boxes"] = [fb_["box"]] + boxes
            fb_["wrap"] = wrap
    else:
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
    # escada (T-263, capturas 111–113; correção do Marco: "do lado da cabine, tipo do lado da porta"): em pé na lateral
    # da cabine logo atrás da porta e do vidro dela, virada para fora, do alto da roda da frente até acima do teto
    # (truck_measure.ladder_side). Ponto = lataria, embaixo, no meio da largura (a peça cresce para fora e para cima).
    # Antes: T-233 na lateral do baú; 1ª versão da T-263 na frente do baú.
    for side, sx in (("r", 1), ("l", -1)):
        ld = m.get("ladder_" + side)
        if not ld:
            continue
        lx, lz, hw2 = ld["x"], ld["z"], ld["w"] / 2
        top = ld["top"]
        xlo = lx + min(0.0, ld["lean"] * (top - ld["y0"])) - max(ld["gaps"] + [0.0]) - 0.004
        for _ in range(3):                                   # (o deque do teto passa por cima: a escada para embaixo dele)
            lb = _box(sx * xlo, ld["y0"] - 0.005, lz - hw2 - 0.02, sx * (lx + LADDER_STEP), top + LEDBOX_H + 0.01, lz + hw2 + 0.02)
            hit = [ob for ob in boxes_of(s.get("andon", {})) if overlap(lb, ob)]
            if not hit:
                break
            top = min(top, round(min(ob[0][1] for ob in hit) - 0.016 - LEDBOX_H, 3))
        ld = dict(ld, top=top)
        s["ladder_" + side] = {"box": _box(sx * xlo, ld["y0"] - 0.005, lz - hw2 - 0.02, sx * (lx + LADDER_STEP),
                                           ld["top"] + LEDBOX_H + 0.01, lz + hw2 + 0.02),
                               "anchor": [round(sx * lx, 3), ld["y0"], lz], "fit": "ladder", "face_x": round(sx * lx, 3),
                               "width": ld["w"], "height": round(ld["top"] - ld["y0"], 3), "lean": ld["lean"],
                               "gap_dy": ld["dy"], "gaps": ld["gaps"]}
        if ld.get("on") == "cargo":
            # T-267 (americana e Canter): na lateral da carga, por FORA do contorno de LED do baú. Duas partes: a escada
            # (de 4 mm antes da linha dela para fora) e, só nas faixas de altura livres entre as faixas do contorno, os
            # espaçadores até a lataria (o jogo só põe espaçador dentro de `sp_free`)
            sk_ = s["ladder_" + side]
            outer = _box(sx * (lx - 0.004), ld["y0"] - 0.005, lz - hw2 - 0.02, sx * (lx + LADDER_STEP),
                         ld["top"] + LEDBOX_H + 0.01, lz + hw2 + 0.02)
            inner = [_box(sx * xlo, f[0], lz - 0.03, sx * (lx - 0.004), f[1], lz + 0.03) for f in ld["sp_free"]]
            sk_.pop("box")
            sk_["boxes"] = [outer] + inner
            sk_["box"] = outer          # (a peça inteira: PartFit.part_problems lê "box"; os vértices usam "boxes")
            sk_["on"] = "cargo"
            sk_["sp_free"] = ld["sp_free"]
    bx = m.get("box")
    if bx:
        bh, top, bot, bf, rz = bx["half_w"], bx["top_y"], bx["bottom_y"], bx["front_z"], bx["rear_z"]
        ed = m.get("edges", {})
        if not m.get("open_body"):
            # T-231: foguete = uma faixa em cada borda do teto (entre o andon de fábrica do teto e a borda), medida por
            # raios; a peça estica no comprimento (fit "stretch") e encolhe na largura da faixa
            for side, sx in (("r", 1), ("l", -1)):
                rk = ed.get("rocket_" + side)
                if not rk:
                    continue
                xa, xb = sx * rk["inner"], sx * rk["outer"]
                # ponto na borda de FORA da faixa (a peça cresce para dentro; a do lado esquerdo é espelhada)
                s["rocket_" + side] = {"box": _box(xa, rk["top"] - 0.005, rk["z0"], xb, rk["top"] + ROCKET_H, rk["z1"]),
                                       "anchor": [round(xb, 3), rk["top"], rk["z1"]],
                                       "length": round(rk["z1"] - rk["z0"], 3), "band": round(rk["outer"] - rk["inner"], 3),
                                       "fit": "stretch"}
            # T-231: contorno de LED = faixas nas bordas de cada face, só onde a lataria está livre (raios)
            for k, segs in ed.get("strips", {}).items():
                if not segs:
                    continue
                s[k] = {"anchor": [0.0, 0.0, 0.0], "strips": segs, "boxes": [strip_box(g) for g in segs], "fit": "strips"}
        # saia lateral (T-265, antes T-233 só entre as rodas e baixa): embaixo do baú, na faixa da lateral do baú para
        # dentro, da frente do baú (atrás dos escapamentos) até a traseira, de embaixo do baú até quase o chão, com um
        # ARCO em volta de cada roda (`arcs`: [zc, yc, raio]); só nos trechos livres (tanque, bateria e degraus de fábrica
        # ficam de fora: medido por raios). Caixas em degraus em volta dos arcos (`skirt_boxes`). Ponto = lado de fora,
        # topo, z = 0; o jogo monta a saia em cada trecho (fit "skirt", SkirtFit) recortando os mesmos arcos.
        for side, sx in (("r", 1), ("l", -1)):
            sk = (fs or {}).get("skirt_" + side)
            runs = [[max(r[0], round(stack_zmax + 0.03, 3)), r[1]] for r in (sk or {}).get("runs", [])]
            runs = [r for r in runs if r[1] - r[0] >= SKIRT_MIN]       # (atrás dos escapamentos e da cabine)
            if not runs:
                continue
            boxes = []
            for r in runs:
                boxes += skirt_boxes(sk, r, sx)
            s["side_skirts_" + side] = {"anchor": [sx * sk["x_out"], sk["y"][1], 0.0], "boxes": boxes,
                                        "runs": runs, "arcs": sk["arcs"], "floor_y": sk["y"][0],
                                        "depth": round(sk["x_out"] - sk["x_in"], 3),
                                        "height": round(sk["y"][1] - sk["y"][0], 3), "fit": "skirt"}
        # para-choque de trás (T-231): largura do baú, atrás de tudo o que fica embaixo dele (substitui o para-choque e
        # as lanternas de fábrica, levando lanternas próprias), topo abaixo das setas de trás; a placa vai na caixa da
        # placa da peça. Antes (T-211) a caixa ficava entre as lanternas de fábrica (1,5 m; 8 cm no Canter).
        rr = ed.get("rear")
        if rr:
            hwr = rr["half_w"] - 0.01
            s["rear_bumper"] = {"box": _box(-(hwr + 0.03), 0.12, rr["back_z"] - 0.005, hwr + 0.03, rr["top_y"] + 0.005,
                                            rr["back_z"] + RB_DEPTH),
                                "anchor": [0.0, rr["top_y"], rr["back_z"]], "width": round(2 * hwr, 3), "fit": "uniform"}
    # superfícies (sem volume: textura do material) e itens sem lugar físico
    for k in ("mural_r", "mural_l", "roof_paint", "rear_paint"):
        s[k] = {"fit": "face"}
        if k in m.get("paint", {}):                  # T-232: retângulo medido por raios no plano real da face
            s[k]["rect"] = m["paint"][k]
    for k in ("hubcaps", "decals"):
        s[k] = {"fit": "none"}
    if m.get("open_body"):
        for k in BOX_ONLY:
            s.pop(k, None)
    return s


SK_BAND = 0.03                     # m: altura de cada degrau das caixas da saia em volta do arco (T-265)
SK_DZ = 0.005                      # m: passo ao longo do trecho para achar onde o arco corta cada degrau
SK_PAD = 0.006                     # m: folga das caixas em z (o jogo faz o arco com segmentos retos)


def skirt_col_lo(z: float, sk: dict) -> float:
    """Fundo da saia na coluna z: o chão da saia ou o arco da roda (= SkirtShape.col_lo no jogo)."""
    top = sk["y"][0]
    for zc, yc, ra in sk["arcs"]:
        d = z - zc
        if abs(d) < ra:
            top = max(top, yc + (ra * ra - d * d) ** 0.5)
    return top


def skirt_boxes(sk: dict, run: list, sx: int) -> list:
    """Caixas da saia num trecho (T-265): degraus de SK_BAND na altura; em cada degrau, os pedaços do trecho onde a saia
    chega àquela altura (fora do arco da roda), com SK_PAD de folga. Degraus iguais seguidos viram uma caixa só. A
    primeira caixa é a maior (o teste do jogo procura nela primeiro)."""
    z0, z1 = run
    y_lo, y_hi = sk["y"]
    n = max(1, int(round((z1 - z0) / SK_DZ)))
    zs = [z0 + (z1 - z0) * i / n for i in range(n + 1)]
    lows = [skirt_col_lo(z, sk) for z in zs]
    bands, yb = [], y_hi
    while yb > y_lo + 1e-6:
        ya = max(y_lo, round(yb - SK_BAND, 4))
        segs, cur = [], None
        for z, lo in zip(zs, lows):
            if lo <= yb + 1e-9:
                cur = [z, z] if cur is None else [cur[0], z]
            elif cur is not None:
                segs.append(cur)
                cur = None
        if cur is not None:
            segs.append(cur)
        segs = [(round(max(z0, a - SK_PAD), 3), round(min(z1, b + SK_PAD), 3)) for a, b in segs]
        if bands and bands[-1][2] == segs:
            bands[-1][0] = ya
        else:
            bands.append([ya, yb, segs])
        yb = ya
    boxes = [_box(sx * sk["x_in"], ya, a, sx * sk["x_out"], yb, b) for ya, yb, segs in bands for a, b in segs]
    vol = lambda b: (b[1][0] - b[0][0]) * (b[1][1] - b[0][1]) * (b[1][2] - b[0][2])   # noqa: E731
    return sorted(boxes, key=lambda b: -vol(b))


def zone_hit(box: list, zv: dict) -> bool:
    """A caixa entra na zona? T-265: zona da roda com `round` ([zc, yc, r]) = cilindro (o arco da saia contorna o
    pneu; os cantos da caixa da roda ficam livres)."""
    if not overlap(box, zv["box"]):
        return False
    rd = zv.get("round")
    if not rd:
        return True
    zc, yc, r = rd
    cz = min(max(zc, box[0][2]), box[1][2])
    cy = min(max(yc, box[0][1]), box[1][1])
    return (cz - zc) ** 2 + (cy - yc) ** 2 < (r - 0.001) ** 2


def strip_box(g: dict) -> list:
    """Caixa reservada a um segmento do contorno de LED: largura STRIP_W em volta da linha (+1 cm nas pontas), de 4 mm
    para dentro da face até STRIP_T para fora."""
    a, b, n, w = g["a"], g["b"], g["n"], g["w"]
    lo, hi = [0.0] * 3, [0.0] * 3
    for i in range(3):
        if n[i] > 0.5:
            lo[i], hi[i] = a[i] - 0.004, a[i] + STRIP_T
        elif n[i] < -0.5:
            lo[i], hi[i] = a[i] - STRIP_T, a[i] + 0.004
        elif abs(w[i]) > 0.5:
            lo[i], hi[i] = min(a[i], b[i]) - STRIP_W * 0.6, max(a[i], b[i]) + STRIP_W * 0.6
        else:
            lo[i], hi[i] = min(a[i], b[i]) - 0.01, max(a[i], b[i]) + 0.01
    return _box(lo[0], lo[1], lo[2], hi[0], hi[1], hi[2])


def boxes_of(v: dict) -> list:
    """Caixas de um encaixe: a única ("box") ou as várias ("boxes", T-231: contorno de LED)."""
    return v["boxes"] if "boxes" in v else ([v["box"]] if "box" in v else [])


def overlap(a: list, b: list, eps: float = 0.001) -> bool:
    """Caixas se cruzam (mais que `eps` em todos os eixos)? Encostar não conta."""
    return all(min(a[1][i], b[1][i]) - max(a[0][i], b[0][i]) > eps for i in range(3))


def check(sk: dict, zones: dict) -> list:
    """Problemas de projeto: encaixes que se cruzam e encaixes que entram numa zona protegida (sem isenção)."""
    probs = []
    vol = [(k, b) for k, v in sk.items() for b in boxes_of(v)]
    for i, (ka, a) in enumerate(vol):
        for kb, b in vol[i + 1:]:
            if ka != kb and overlap(a, b):
                probs.append(f"encaixes {ka} x {kb} se cruzam")
        for zk, zv in zones.items():
            base = ka[:-2] if ka[-2:] in ("_r", "_l") else ka
            if base in zv["exempt"] or ka in zv["exempt"]:
                continue
            if zone_hit(a, zv):
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


def clear_mirror(sk: dict, zones: dict) -> None:
    """T-233: a caixa da haste do retrovisor começa logo por fora do que já ocupa a quina (viseira, lanterna da quina,
    farol): empurra a borda de dentro para fora até não cruzar nenhuma caixa nem zona sem isenção."""
    for side, sx in (("r", 1), ("l", -1)):
        k = "mirror_stay_" + side
        if k not in sk:
            continue
        if "pillar" in sk[k]:                    # T-263: com a coluna medida, encolhe na altura (a base fica na lataria)
            _clear_pads(sk, zones, k)
            continue
        if "box" not in sk[k]:
            continue
        for _ in range(4):
            b = sk[k]["box"]
            others = [v for kk, v in sk.items() if kk != k for v in boxes_of(v)]
            others += [z["box"] for z in zones.values() if k[:-2] not in z["exempt"] and k not in z["exempt"]]
            push = 0.0
            for o in others:
                if overlap(b, o):
                    edge = o[1][0] if sx > 0 else -o[0][0]
                    push = max(push, edge + 0.002)
            if push <= 0.0:
                break
            if sx > 0:
                b[0][0] = round(max(b[0][0], push), 3)
            else:
                b[1][0] = round(min(b[1][0], -push), 3)
            sk[k]["anchor"][0] = round(sx * max(abs(sk[k]["anchor"][0]), push), 3)


def _clear_pads(sk: dict, zones: dict, k: str) -> None:
    """T-263: as caixas da haste (base e braços) não cruzam outra caixa nem zona sem isenção: o que está acima corta o
    topo, o que está abaixo corta o fundo; `pad_y` (faixa das chapas) acompanha."""
    v = sk[k]
    others = [b for kk, vv in sk.items() if kk != k for b in boxes_of(vv)]
    others += [z["box"] for z in zones.values() if k[:-2] not in z["exempt"] and k not in z["exempt"]]
    for _ in range(6):
        hit = False
        for b in v["boxes"]:
            for o in others:
                if not overlap(b, o):
                    continue
                hit = True
                mid = (b[0][1] + b[1][1]) / 2
                if (o[0][1] + o[1][1]) / 2 >= mid:
                    top = round(o[0][1] - 0.002, 3)
                    for bb in v["boxes"]:
                        bb[1][1] = min(bb[1][1], top)
                else:
                    low = round(o[1][1] + 0.002, 3)
                    for bb in v["boxes"]:
                        bb[0][1] = max(bb[0][1], low)
        if not hit:
            break
    lo, hi = v["boxes"][0][0][1] + PAD_BELOW, v["boxes"][0][1][1] - PAD_ABOVE
    v["pad_y"] = [round(max(v["pad_y"][0], lo), 3), round(min(v["pad_y"][1], hi), 3)]
    if v["pad_y"][1] - v["pad_y"][0] < 0.25:
        v["problem"] = "coluna livre curta demais para a haste (%.2f m)" % (v["pad_y"][1] - v["pad_y"][0])
    v["box"] = [[min(b[0][i] for b in v["boxes"]) for i in range(3)], [max(b[1][i] for b in v["boxes"]) for i in range(3)]]


# ----------------------------------------------------------------------------- oficina lote 5 (T-234)
GRILLE_DEPTH = 0.11                # m: quanto a grade nova pode sair da frente da cabine
HORN_SET_W = 0.25                  # m: meia largura do conjunto de cornetas (T-256: um em cada ponta da viseira)


def lot5(sk: dict, zones: dict, m: dict, l5: dict) -> None:
    """T-234: grade encostada na frente real da cabine (fit "grille": a peça estica na largura e na altura da caixa),
    buzina no topo da carga (fit "horn"; carga sem topo plano = sem buzina) e o retângulo do interior no para-brisa
    (fit "face" com `rect`, como as pinturas; o para-brisa é isento só para ele: a arte fica 4 mm na frente do vidro)."""
    from . import t234_measure as T
    g = sk.get("grille")
    if g and "box" in g:
        b = g["box"]
        for _ in range(3):              # a grade fica ACIMA da placa/para-choque (cabines planas: farol baixo)
            seat = T.grille_seat(l5["tree"], g, m["cab"]["front_z"])
            if not seat:
                break
            hh0 = (b[1][1] - b[0][1]) / 2
            z0 = round(min(g["box"][0][2], seat["face_z"] - abs(seat["lean"]) * hh0 - GRILLE_DEPTH), 3)
            trial = [[b[0][0], b[0][1], z0], [b[1][0], b[1][1], round(max(b[1][2], seat["back_z"] + 0.01), 3)]]
            hit = [zv["box"] for zk, zv in zones.items() if "grille" not in zv["exempt"] and overlap(trial, zv["box"])]
            low = [zb for zb in hit if zb[1][1] < (b[0][1] + b[1][1]) / 2]
            if not low:
                break
            b[0][1] = round(max(zb[1][1] for zb in low) + 0.01, 3)
        if seat:
            g.update(seat)
            hh = (b[1][1] - b[0][1]) / 2
            front = seat["face_z"] - abs(seat["lean"]) * hh            # costas da grade no ponto mais à frente
            b[0][2] = round(min(b[0][2], front - GRILLE_DEPTH), 3)
            b[1][2] = round(max(b[1][2], seat["back_z"] + 0.01), 3)   # T-256: colar atrás da grade até a lataria
            g["anchor"] = [g["anchor"][0], round((b[0][1] + b[1][1]) / 2, 3), seat["face_z"]]
        g.update({"fit": "grille", "height": round(b[1][1] - b[0][1], 3)})
        g["band"] = T.front_band(l5["tree"], m, b, zones)        # T-259: faixa do adesivo na lataria da frente
    # buzina (pedido do Marco depois da 1a versão no topo da carga): EM CIMA da viseira, encostada na testa da cabine,
    # cornetas deitadas apontando para a frente. Fica na frente do deque (não cruza a caixa dele) e acima da viseira.
    # Teto curto (americana, `max_depth`): o deque começa no fim do capô e os canhões do deque de 2 níveis descem pela
    # testa até a viseira; a buzina bateria neles. Ali não há buzina (fica guardada, como o foguete na carga aberta).
    vi, an = sk.get("visor", {}).get("box"), sk.get("andon", {}).get("box")
    if vi and not (an and "max_depth" in sk["andon"]):
        zb = min(vi[1][2], an[0][2]) if an else vi[1][2]
        y0 = vi[1][1]
        y1 = y0 + T.HORN_H
        # T-256: um lugar em cada ponta da viseira (o jogador escolhe esquerda, direita ou os dois lados)
        xr = min(vi[1][0], m["cab"]["half_w"]) - 0.02
        xa = max(xr - HORN_SET_W, 0.0)
        for side, sx in (("r", 1), ("l", -1)):
            sk["horn_" + side] = {"box": _box(sx * max(xa - HORN_SET_W, 0.0), y0, zb - T.HORN_L, sx * xr, y1, zb),
                                  "anchor": [sx * round(xa, 3), round(y0, 3), round(zb - 0.004, 3)], "fit": "horn",
                                  "lift": 0.0, "length": T.HORN_L}
    it = l5.get("interior") or {}
    if it:
        sk["interior"] = {"fit": "face", "rect": it}
        if "windshield" in zones and "interior" not in zones["windshield"]["exempt"]:
            zones["windshield"]["exempt"].append("interior")
