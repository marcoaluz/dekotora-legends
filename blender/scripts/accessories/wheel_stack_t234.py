"""Rodas (calotas) e escapamentos da oficina, lote 5 (T-234): 3 + 3 peças, pelas propostas da seção 19 de
docs/REFERENCIA_PECAS.md (folha docs/capturas_t211/proposta_lacunas.png).

Calota: origem = ponto MOUNT_WHEEL_*_FACE_* (face de fora do pneu), eixo do pneu = X (+X para fora). Tamanho para a
roda de raio WHEEL_R; o jogo escala pela roda de cada caminhão (Canter 0,44) e põe uma em cada roda de fora (gira com
o pneu, `TruckWheels.attach_part`). Orçamento: 6 rodas de fora x triângulos <= 4.500.
Escapamento: origem = encaixe `exhaust_stacks_r` (vão entre a cabine e a carga, na altura do chassi); o esquerdo é
espelhado. Caixa nominal: x +-0,15, y +-0,09 (frente/trás), até 2,85 m de altura; o jogo encolhe a seção onde o vão
é mais estreito (baú de alumínio) e encosta a peça no meio do vão (fit "stack", `lot5_fit.gd`).
Desenho nosso.
"""
from __future__ import annotations

import math

from lib import mesh3d as M

from . import t234_kit as Z

WHEEL_R = 0.52
CAP_R = 0.34
STACK_H = 2.85
STACK_W, STACK_D = 0.30, 0.18


# ----------------------------------------------------------------------------- calotas

def hub_led_ring(m):
    """Disco cromado de 10 furos com anel de LED na borda."""
    o = [M.cylinder("disc", CAP_R, 0.035, (0.018, 0, 0), m["chrome"], axis="X", seg=18)]
    o.append(M.torus("rim", CAP_R - 0.005, 0.018, (0.036, 0, 0), m["chrome"], axis="X", seg=18, tube_seg=4))
    o += Z.ring_of("hole", 8, 0.20, 0.034, m["trim"], x=0.037, depth=0.006, seg=6)
    o += Z.ring_of("led", 16, CAP_R - 0.045, 0.012, m["led"], x=0.042, depth=0.012, phase=0.5, round_=False)
    o.append(M.cylinder("cap", 0.10, 0.05, (0.055, 0, 0), m["body"], axis="X", seg=12))
    o.append(M.cylinder("cap_top", 0.055, 0.02, (0.085, 0, 0), m["chrome"], axis="X", seg=8))
    return o


def hub_star_gold(m):
    """Estrela de 8 raios cromados sobre aro dourado."""
    o = [M.cylinder("back", CAP_R - 0.01, 0.02, (0.01, 0, 0), m["trim"], axis="X", seg=18)]
    o.append(M.torus("rim", CAP_R - 0.02, 0.03, (0.03, 0, 0), m["gold"], axis="X", seg=18, tube_seg=4))
    for k in range(8):
        a = 2 * math.pi * k / 8
        ln = CAP_R - 0.06
        o.append(M.box(f"spoke_{k}", (0.03, 0.055, ln), (0.045, math.sin(a) * ln / 2, math.cos(a) * ln / 2), m["chrome"],
                       bevel=0.0, seg=1, rot=(math.degrees(-a), 0, 0)))
    o.append(M.cylinder("hub", 0.09, 0.06, (0.06, 0, 0), m["gold"], axis="X", seg=8))
    o.append(M.cylinder("hub_top", 0.05, 0.02, (0.095, 0, 0), m["body"], axis="X", seg=8))
    o += Z.ring_of("nut", 8, 0.13, 0.014, m["chrome"], x=0.06, depth=0.03, phase=0.5, seg=6)
    return o


def hub_neon_spinner(m):
    """Calota funda cromada com lábio de neon e "spinner" dourado de 3 pás."""
    prof = [(CAP_R, 0.0), (CAP_R - 0.01, 0.025), (CAP_R - 0.05, 0.03), (0.22, 0.012), (0.12, 0.004), (0.0, 0.004)]
    o = [Z.lathe("dish", prof, m["chrome"], axis="X", seg=20)]
    o.append(M.torus("lip", CAP_R - 0.012, 0.014, (0.03, 0, 0), m["neon"], axis="X", seg=18, tube_seg=4))
    for k in range(3):
        a = 2 * math.pi * k / 3
        o.append(M.box(f"blade_{k}", (0.025, 0.07, 0.24), (0.05, math.sin(a) * 0.13, math.cos(a) * 0.13), m["gold"],
                       bevel=0.0, seg=1, rot=(math.degrees(-a) - 18, 0, 0)))
    o.append(M.cylinder("hub", 0.07, 0.05, (0.06, 0, 0), m["gold"], axis="X", seg=10))
    o.append(M.cylinder("gem", 0.03, 0.02, (0.09, 0, 0), m["neon"], axis="X", seg=8))
    return o


# ----------------------------------------------------------------------------- escapamentos

def _clamp(m, z, h=0.05, x=-0.13):
    """Abraçadeira de fixação (lado de dentro, na direção da cabine/carga)."""
    return M.box(f"clamp_{z:.2f}", (0.05, 0.12, h), (x, 0, z), m["body"], bevel=0.008, seg=1)


def stack_neon_twin(m):
    """Chaminé dupla cromada com ponta de neon e protetor dourado."""
    o = []
    for k, x in enumerate((-0.06, 0.06)):
        o.append(M.cylinder(f"pipe_{k}", 0.05, STACK_H - 0.05, (x, 0, (STACK_H - 0.05) / 2), m["chrome"], axis="Z", seg=12))
        o.append(Z.lathe(f"tip_{k}", [(0.05, STACK_H - 0.06), (0.058, STACK_H - 0.02), (0.058, STACK_H), (0.045, STACK_H - 0.005)],
                         m["chrome"], axis="Z", seg=12, loc=(x, 0, 0)))
        o.append(M.torus(f"neon_{k}", 0.058, 0.010, (x, 0, STACK_H - 0.035), m["neon"], axis="Z", seg=14, tube_seg=4))
    o.append(M.box("guard", (0.02, 0.15, 0.80), (0.125, 0, 1.95), m["gold"], bevel=0.008, seg=1))
    for k in range(7):
        o.append(M.box(f"slot_{k}", (0.006, 0.10, 0.035), (0.137, 0, 1.68 + k * 0.09), m["trim"], bevel=0.002, seg=1))
    o += [_clamp(m, z, x=-0.10) for z in (0.6, 1.5, 2.3)]
    o.append(M.box("base", (0.28, 0.14, 0.05), (0.0, 0, 0.025), m["body"], bevel=0.01, seg=1))
    return o


def stack_j_amber(m):
    """Chaminé em J com protetor perfurado e fendas de luz âmbar."""
    r, bend = 0.062, 0.08
    h = STACK_H - 0.20
    o = [M.cylinder("pipe", r, h, (0.0, 0, h / 2), m["chrome"], axis="Z", seg=12)]
    pts = [(bend - bend * math.cos(a), 0.0, h + bend * math.sin(a)) for a in [math.pi / 2 * k / 5 for k in range(6)]]
    pts.append((pts[-1][0] + 0.03, 0.0, pts[-1][2]))
    o.append(Z.Q.tubes("bend", Z.Q.path(pts), r, m["chrome"], seg=12))
    o.append(M.cylinder("guard", 0.085, 0.80, (0, 0, 1.6), m["body"], axis="Z", seg=14))
    for k in range(5):
        a = math.radians(-60 + k * 30)                    # fendas só no lado de fora (+X)
        o.append(M.box(f"slit_{k}", (0.012, 0.022, 0.60), (math.cos(a) * 0.088, math.sin(a) * 0.088, 1.6), m["amber"],
                       bevel=0.003, seg=1, rot=(0, 0, math.degrees(a))))
    for z in (1.18, 2.02):
        o.append(M.cylinder(f"band_{z}", 0.092, 0.03, (0, 0, z), m["chrome"], axis="Z", seg=14))
    o += [_clamp(m, z, x=-0.10) for z in (0.6, 2.3)]
    o.append(M.box("base", (0.22, 0.14, 0.05), (0.0, 0, 0.025), m["body"], bevel=0.01, seg=1))
    return o


def stack_side_triple(m):
    """Saída lateral tripla com ponta acesa (baixa, atrás da cabine, apontando para fora)."""
    o = [M.box("plate", (0.03, 0.14, 0.40), (-0.12, 0, 0.20), m["body"], bevel=0.01, seg=1)]
    for k, z in enumerate((0.08, 0.20, 0.32)):
        o.append(M.cylinder(f"pipe_{k}", 0.035, 0.24, (0.01, 0, z), m["chrome"], axis="X", seg=12))
        o.append(Z.lathe(f"tip_{k}", [(0.035, 0.12), (0.045, 0.15), (0.045, 0.16), (0.03, 0.155)], m["chrome"],
                         axis="X", seg=12, loc=(0, 0, z)))
        o.append(M.cylinder(f"glow_{k}", 0.03, 0.006, (0.152, 0, z), m["neon"], axis="X", seg=12))
    o.append(M.box("heat_plate", (0.012, 0.12, 0.36), (-0.10, 0, 0.20), m["gold"], bevel=0.004, seg=1))
    return o


def _w(pid, name, build, color="cromo_ciano"):
    return {"id": pid, "name": name, "build": build, "kind": "wheel", "slot": "hubcaps", "mount": "MOUNT_WHEEL_FRONT_FACE_R",
            "mount_left": "MOUNT_WHEEL_FRONT_FACE_L", "fit": "wheel", "default_color": color, "folder": "wheel_t234",
            "wheel_r": WHEEL_R}


def _s(pid, name, build, color="cromo_ciano"):
    return {"id": pid, "name": name, "build": build, "kind": "stack", "slot": "exhaust_stacks", "socket": "exhaust_stacks_r",
            "socket_left": "exhaust_stacks_l", "fit": "stack", "default_color": color, "folder": "stack_t234",
            "nominal": [STACK_W, STACK_H, STACK_D]}


PARTS = [
    _w("hub_led_ring", "Disco cromado com anel de LED", hub_led_ring),
    _w("hub_star_gold", "Estrela cromada no aro dourado", hub_star_gold, "preto_ciano"),
    _w("hub_neon_spinner", "Calota funda com neon e spinner", hub_neon_spinner, "cromo_rosa"),
    _s("stack_neon_twin", "Chaminé dupla com ponta neon", stack_neon_twin),
    _s("stack_j_amber", "Chaminé em J com fendas âmbar", stack_j_amber, "preto_ciano"),
    _s("stack_side_triple", "Saída lateral tripla acesa", stack_side_triple, "cromo_rosa"),
]
