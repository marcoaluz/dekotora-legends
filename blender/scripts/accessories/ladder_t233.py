"""Escadas da cabine, 3 peças do catálogo da T-210 (capturas 111–113). T-233; refeitas na T-263 pela referência.

Onde (T-263, correção do Marco): em pé na LATERAL DA CABINE, ao lado (logo atrás) da porta, virada para fora, da
soleira até passar do teto da cabine; embaixo um ESTRIBO junto da soleira e em cima uma CAIXA COM LED (cor dos LEDs
separada da cor da peça), como nas capturas 111–113. Antes: T-233 na lateral do baú; 1ª versão da T-263 na frente do baú.
Origem = encaixe "ladder_r" (`lib/socket_rules.py`, medido por `truck_measure.ladder_side`): lataria, embaixo, no meio
da largura; o jogo vira a peça para fora e inclina com a lateral (`game/scripts/truck/side_ladder.gd`). A peça cresce
para FORA (+Y local) e para CIMA (+Z); a largura fica em ±X (ao longo do caminhão). 3 grupos (fit "ladder"):
  BOT_  pé (z de 0 a BOT) com o estribo e os suportes;
  MID_  um módulo (z de BOT a BOT + MOD), repetido até o topo (sem deformar);
  TOP_  topo (z de 0 a TOP) com os suportes e a caixa de LED por cima (TOP a TOP + LEDBOX_H).
Formas da referência (desenho nosso, nada copiado):
  111 neon    chapa preta em U com furos redondos e 2 neons ciano em trechos (um trecho por módulo);
  112 verde   treliça preta de anéis encostados entre 2 trilhos chatos, com um par de LEDs verdes em cada junta;
  113 cromo   chapa de grade cromada (quadriculado vazado) sobre fundo escuro, mais larga.
"""
from __future__ import annotations

from lib import mesh3d as M

from . import t233_kit as Q

DEPTH = 0.075                      # m: quanto a escada sai da lateral (suporte + chapa) = truck_measure.LADDER_DEPTH
BR = 0.025                         # m: comprimento do suporte (do baú até as costas da chapa)
NOMINAL_W = 0.30


def _brackets(m, z, wx, name):
    """Par de suportes (encostam na lataria em y = 0; o jogo põe espaçadores onde ela recua)."""
    return [M.box(f"{name}_br{k}", (0.04, BR, 0.045), (sx * (wx - 0.03), BR / 2, z), m["trim"], bevel=0.004, seg=1)
            for k, sx in enumerate((-1, 1))]


LEDBOX_H = 0.16                    # m: caixa com LED no alto da escada (passa do teto da cabine, como nas capturas 111–113)
STEP_OUT = 0.15                    # m: estribo embaixo, junto da soleira (sai da lateral)


def _ledbox(m, wx, z0, name="ledbox"):
    """T-263: caixa com LED no topo (cor dos LEDs separada da cor da peça: papel deco_led)."""
    from . import t211_kit as K
    o = [M.box(f"{name}_body", (2 * wx + 0.02, 0.09, LEDBOX_H), (0.0, BR + 0.045, z0 + LEDBOX_H / 2), m["body"], bevel=0.008, seg=1)]
    face = K.Face((wx - 0.01, BR + 0.09, z0 + 0.02), (-(2 * wx - 0.02), 0, 0), (0, 0, LEDBOX_H - 0.04))
    o.append(K.led_grid(f"{name}_led", face, 0.0, 0.0, 1.0, 1.0, 4, 3, m["led"], fill=0.66, off=0.012, depth=0.010))
    return o


def _step(m, wx, name="step"):
    """T-263: estribo (degrau) embaixo da escada, junto da soleira, saindo da lateral."""
    return [M.box(f"{name}_plate", (2 * wx + 0.04, STEP_OUT, 0.02), (0.0, STEP_OUT / 2, 0.01), m["checker"], bevel=0.004, seg=1),
            M.box(f"{name}_lip", (2 * wx + 0.04, 0.02, 0.05), (0.0, STEP_OUT - 0.01, 0.025), m["chrome"], bevel=0.004, seg=1)]


def _groups(bot, mid, top, z1):
    for o in top:
        o.location.z += z1
    return Q.tag(bot, "BOT") + Q.tag(mid, "MID") + Q.tag(top, "TOP")


# ----------------------------------------------------------------------------- 111: chapa preta com furos e neon
N_WX, N_BOT, N_MOD, N_TOP = 0.13, 0.12, 0.62, 0.12


def _channel(m, z0, z1, name):
    h = z1 - z0
    zc = (z0 + z1) / 2
    o = [M.box(f"{name}_plate", (2 * N_WX - 0.02, 0.016, h), (0.0, BR + 0.008, zc), m["body"], bevel=0.0, seg=1)]
    for k, sx in enumerate((-1, 1)):
        o.append(M.box(f"{name}_lip{k}", (0.02, 0.045, h), (sx * (N_WX - 0.01), BR + 0.0225, zc), m["body"], bevel=0.0, seg=1))
    return o


def _neon_run(m, z0, z1, name):
    return [M.box(f"{name}_neon{k}", (0.014, 0.012, z1 - z0), (sx * 0.072, BR + 0.022, (z0 + z1) / 2), m["neon"], bevel=0.0, seg=1)
            for k, sx in enumerate((-1, 1))]


def _hole(m, z, name):
    return M.cylinder(name, 0.03, 0.006, (0.0, BR + 0.017, z), m["trim"], axis="Y", seg=12)


def ladder_neon(m):
    z1 = N_BOT + N_MOD
    bot = _channel(m, 0.0, N_BOT, "b") + _brackets(m, 0.06, N_WX, "b") + \
        [M.box("foot", (2 * N_WX + 0.02, DEPTH, 0.02), (0.0, DEPTH / 2, 0.01), m["chrome"], bevel=0.004, seg=1)]
    mid = _channel(m, N_BOT, z1, "m") + _neon_run(m, N_BOT + 0.03, z1 - 0.03, "m") + \
        [_hole(m, N_BOT + N_MOD * 0.3, "hole0"), _hole(m, N_BOT + N_MOD * 0.7, "hole1")]
    top = _channel(m, 0.0, N_TOP, "t") + _brackets(m, N_TOP - 0.06, N_WX, "t") + \
        [M.box("cap", (2 * N_WX + 0.02, DEPTH, 0.02), (0.0, DEPTH / 2, N_TOP - 0.01), m["chrome"], bevel=0.004, seg=1)]
    return _groups(bot + _step(m, N_WX), mid, top + _ledbox(m, N_WX, N_TOP), z1)


# ----------------------------------------------------------------------------- 112: treliça de anéis com LEDs verdes
G_WX, G_BOT, G_MOD, G_TOP = 0.13, 0.10, 0.21, 0.10
G_RAIL = 0.026


def _flat_rails(m, z0, z1, name):
    return [M.box(f"{name}_rail{k}", (G_RAIL, 0.045, z1 - z0), (sx * (G_WX - G_RAIL / 2), BR + 0.0225, (z0 + z1) / 2),
                  m["body"], bevel=0.0, seg=1) for k, sx in enumerate((-1, 1))]


def ladder_green(m):
    z1 = G_BOT + G_MOD
    inner = G_WX - G_RAIL
    bot = _flat_rails(m, 0.0, G_BOT, "b") + _brackets(m, 0.05, G_WX, "b") + \
        [M.box("foot", (2 * G_WX, 0.045, 0.018), (0.0, BR + 0.0225, 0.009), m["body"], bevel=0.0, seg=1)]
    ring = M.torus("ring", inner - 0.008, 0.008, (0.0, BR + 0.03, G_BOT + G_MOD / 2), m["body"], axis="Y", seg=12, tube_seg=4)
    mid = _flat_rails(m, G_BOT, z1, "m") + [ring]
    for k, sx in enumerate((-1, 1)):                        # par de LEDs verdes na junta de baixo do anel
        for j, dz in enumerate((0.012, 0.042)):
            mid.append(M.box(f"led{k}{j}", (0.02, 0.008, 0.022), (sx * (G_WX - G_RAIL / 2), BR + 0.046, G_BOT + dz),
                             m["led"], bevel=0.0, seg=1))
    top = _flat_rails(m, 0.0, G_TOP, "t") + _brackets(m, G_TOP - 0.05, G_WX, "t") + \
        [M.box("cap", (2 * G_WX, 0.045, 0.018), (0.0, BR + 0.0225, G_TOP - 0.009), m["body"], bevel=0.0, seg=1)]
    for k, sx in enumerate((-1, 1)):
        top.append(M.box(f"top_led{k}", (0.02, 0.008, 0.022), (sx * (G_WX - G_RAIL / 2), BR + 0.046, 0.03), m["led"],
                         bevel=0.0, seg=1))
    return _groups(bot + _step(m, G_WX), mid, top + _ledbox(m, G_WX, G_TOP), z1)


# ----------------------------------------------------------------------------- 113: grade cromada (mais larga)
C_WX, C_BOT, C_MOD, C_TOP = 0.155, 0.10, 0.30, 0.10
C_CELL = 0.05


def _grate(m, z0, z1, name, rows=True):
    h = z1 - z0
    zc = (z0 + z1) / 2
    o = [M.box(f"{name}_back", (2 * C_WX - 0.03, 0.006, h), (0.0, BR + 0.003, zc), m["trim"], bevel=0.0, seg=1)]
    for k, sx in enumerate((-1, 1)):
        o.append(M.box(f"{name}_side{k}", (0.025, 0.045, h), (sx * (C_WX - 0.0125), BR + 0.0225, zc), m["chrome"], bevel=0.0, seg=1))
    for k, x in enumerate((-0.09, -0.045, 0.0, 0.045, 0.09)):
        o.append(M.box(f"{name}_v{k}", (0.008, 0.03, h), (x, BR + 0.03, zc), m["chrome"], bevel=0.0, seg=1))
    if rows:
        n = int(round(h / C_CELL))
        for k in range(n):
            z = z0 + (k + 0.5) * h / n
            o.append(M.box(f"{name}_h{k}", (2 * C_WX - 0.05, 0.022, 0.008), (0.0, BR + 0.034, z), m["chrome"], bevel=0.0, seg=1))
    return o


def ladder_chrome(m):
    z1 = C_BOT + C_MOD
    bot = _grate(m, 0.0, C_BOT, "b") + _brackets(m, 0.05, C_WX, "b") + \
        [M.box("foot", (2 * C_WX, 0.05, 0.016), (0.0, BR + 0.025, 0.008), m["chrome"], bevel=0.003, seg=1)]
    mid = _grate(m, C_BOT, z1, "m")
    top = _grate(m, 0.0, C_TOP, "t") + _brackets(m, C_TOP - 0.05, C_WX, "t") + \
        [M.box("cap", (2 * C_WX, 0.05, 0.016), (0.0, BR + 0.025, C_TOP - 0.008), m["chrome"], bevel=0.003, seg=1)]
    return _groups(bot + _step(m, C_WX), mid, top + _ledbox(m, C_WX, C_TOP), z1)


def _p(pid, name, build, caps, bot, mod, top, wx, color="preto_ciano"):
    return {"id": pid, "name": name, "build": build, "captures": caps, "has_sign": False, "default_color": color,
            "slot": "ladder", "socket": "ladder_r", "socket_left": "ladder_l", "nominal_w": round(2 * wx, 3), "fit": "ladder",
            "stretch": {"head": bot, "mid": mod, "tail": top}, "folder": "ladder_t233", "depth": DEPTH}


PARTS = [
    _p("ladder_neon", "Escada de neon", ladder_neon, "111", N_BOT, N_MOD, N_TOP, N_WX),
    _p("ladder_green", "Escada de luzes verdes", ladder_green, "112", G_BOT, G_MOD, G_TOP, G_WX, color="preto_verde"),
    _p("ladder_chrome", "Escada cromada", ladder_chrome, "113", C_BOT, C_MOD, C_TOP, C_WX, color="cromo_ciano"),
]
