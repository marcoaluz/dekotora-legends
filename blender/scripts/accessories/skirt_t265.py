"""Saias laterais GRANDES (T-265, capturas 085–094; antes T-233 só entre as rodas e baixa).

Pedido do Marco: "saias maiores, quase no chão, contornando as rodas e também atrás da roda traseira". A saia é montada
pelo jogo em cada caminhão (`game/scripts/truck/skirt_fit.gd`): painel da frente do baú até a traseira, de embaixo do
baú até quase o chão, com o recorte em ARCO em volta de cada roda (medido por raios: `lib/truck_measure.skirt_band`).
Aqui ficam:
  - o DESENHO de cada peça (`skirt` no catálogo): fileiras de neon/LED (faixa, traços, enfeite repetido, trilho),
    neon que acompanha o arco da roda, postes; `t` = altura em fração da saia (0 = fundo, 1 = topo);
  - os ENFEITES modelados (`MOTIF_<forma>_<material>`: losango, pedra, seta, marcador, trilho de 1 m, poste de 1 m),
    em tamanho real, centrados, base em x = 0 saindo para +X (fora), +Y = frente, +Z = cima;
  - uma amostra de cada material (`MAT_<material>`): o jogo pega os materiais do .glb.
Desenho nosso, inspirado só na forma das capturas.
"""
from __future__ import annotations

import bmesh

from lib import mesh3d as M

from . import t233_kit as Q


def _frustum(name, poly, top_poly, d, mat):
    """Polígono `poly` (y, z) em x = 0 e `top_poly` em x = d (lados + tampa de fora)."""
    bm = bmesh.new()
    a = [bm.verts.new((0.0, y, z)) for y, z in poly]
    b = [bm.verts.new((d, y, z)) for y, z in top_poly]
    n = len(poly)
    for k in range(n):
        bm.faces.new([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def diamond(name, w, h, d, mat):
    """Losango de luz (capturas 089): w ao longo do baú, h na altura, borda chanfrada."""
    p = [(w / 2, 0.0), (0.0, h / 2), (-w / 2, 0.0), (0.0, -h / 2)]
    q = [(w * 0.40, 0.0), (0.0, h * 0.34), (-w * 0.40, 0.0), (0.0, -h * 0.34)]
    return _frustum(name, p, q, d, mat)


def gem(name, s, d, mat):
    """Pedra lapidada (capturas 093): losango com o miolo pontudo (8 facetas)."""
    bm = bmesh.new()
    ring = [(s / 2, 0.0), (0.0, s / 2), (-s / 2, 0.0), (0.0, -s / 2)]
    mid = [(s * 0.30, 0.0), (0.0, s * 0.30), (-s * 0.30, 0.0), (0.0, -s * 0.30)]
    a = [bm.verts.new((0.0, y, z)) for y, z in ring]
    b = [bm.verts.new((d * 0.55, y, z)) for y, z in mid]
    tip = bm.verts.new((d, 0.0, 0.0))
    for k in range(4):
        bm.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
        bm.faces.new([b[k], b[(k + 1) % 4], tip])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def arrow(name, w, h, th, d, mat):
    """Seta dupla ">" apontando para a frente (+Y, capturas 094): dois braços chanfrados."""
    bm = bmesh.new()
    for sg in (1, -1):
        p0 = (-w / 2, sg * h / 2)
        ring = [p0, (w / 2, 0.0), (w / 2 - th, 0.0), (p0[0] - th, p0[1])]
        if sg < 0:
            ring = list(reversed(ring))
        a = [bm.verts.new((0.0, y, z)) for y, z in ring]
        b = [bm.verts.new((d, y, z)) for y, z in ring]
        for k in range(4):
            bm.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
        bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def arrow_bar(name, ln, h, head, hw, d, mat):
    """Seta comprida (capturas 094): barra de `ln` com a ponta de `head` (largura `hw`) na frente (+Y) e o rabo em V."""
    t = h / 2
    p = [(ln / 2, 0.0), (ln / 2 - head, hw / 2), (ln / 2 - head, t), (-ln / 2, t), (-ln / 2 + head * 0.45, 0.0),
         (-ln / 2, -t), (ln / 2 - head, -t), (ln / 2 - head, -hw / 2)]
    bm = bmesh.new()
    a = [bm.verts.new((0.0, y, z)) for y, z in p]
    b = [bm.verts.new((d, y, z)) for y, z in p]
    n = len(p)
    for k in range(n):
        bm.faces.new([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
    # (face de fora em leque a partir da ponta: o polígono é côncavo no rabo, mas a ponta enxerga todos os cantos)
    for k in range(1, n - 1):
        bm.faces.new([b[0], b[k], b[k + 1]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def lozenge(name, ln, h, d, mat):
    """Losango alongado (capturas 089): hexágono pontudo nas duas pontas, borda chanfrada."""
    p = [(ln / 2, 0.0), (ln / 2 - h * 0.6, h / 2), (-ln / 2 + h * 0.6, h / 2), (-ln / 2, 0.0),
         (-ln / 2 + h * 0.6, -h / 2), (ln / 2 - h * 0.6, -h / 2)]
    q = [(x * 0.94, z * 0.6) for x, z in p]
    return _frustum(name, p, q, d, mat)


def marker(name, w, h, d, mat):
    """Marcador de LED (quadradinho com a face de fora menor)."""
    p = [(w / 2, h / 2), (-w / 2, h / 2), (-w / 2, -h / 2), (w / 2, -h / 2)]
    q = [(w * 0.38, h * 0.36), (-w * 0.38, h * 0.36), (-w * 0.38, -h * 0.36), (w * 0.38, -h * 0.36)]
    return _frustum(name, p, q, d, mat)


def rail(name, r, mat):
    """Trilho cromado de 1 m ao longo do baú (o jogo estica no comprimento do trecho), eixo em x = 0."""
    return Q.tubes(name, [((0.0, -0.5, 0.0), (0.0, 0.5, 0.0))], r, mat, seg=10, ext=0.0)


def post(name, w, mat):
    """Poste de 1 m de altura (o jogo estica até o recorte)."""
    return M.box(name, (w, w, 1.0), (0.0, 0.0, 0.0), mat, bevel=0.004, seg=1)


# --- desenho de cada peça. Fileiras: k = bar | dash | motif | rail; t = [baixo, cima] (ou centro, para motif/rail);
# m = material (deco_neon, deco_led, deco_trim, chrome); d = quanto sai da face; o = enfeite (MOTIF_<o>).
def _p(pid, name, caps, motifs, skirt, color="preto_ciano"):
    return {"id": pid, "name": name, "captures": caps, "motifs": motifs, "skirt": skirt, "default_color": color,
            "slot": "side_skirts", "socket": "side_skirts_r", "socket_left": "side_skirts_l", "folder": "skirt_t265",
            "fit": "skirt"}


NEON, LED, TRIM, CHROME = "deco_neon", "deco_led", "deco_trim", "chrome"

PARTS = [
    _p("skirt_chrome_rails", "Trilhos cromados", "086-087",
       {"rail_chrome": lambda m, n: rail(n, 0.019, m["chrome"]), "post_chrome": lambda m, n: post(n, 0.04, m["chrome"])},
       {"panel": False, "trim": CHROME,
        "rows": [{"k": "rail", "t": t, "h": 0.038, "o": "rail_chrome", "m": CHROME, "x": -0.034, "gap_arch": 0.03,
                  "end": 0.0} for t in (0.80, 0.55, 0.30)],
        "posts": {"o": "post_chrome", "m": CHROME, "pitch": 1.0, "w": 0.04, "x": -0.034, "bottom": 0.10}},
       color="cromo_ciano"),
    _p("skirt_neon_twin", "Neon de 2 linhas", "088", {},
       {"rows": [{"k": "bar", "t": [0.60, 0.665], "m": NEON}, {"k": "bar", "t": [0.38, 0.445], "m": NEON}]}),
    _p("skirt_neon_diamond", "Corrente de losangos", "089",
       {"diamond_neon": lambda m, n: lozenge(n, 0.30, 0.085, 0.012, m["neon"])},
       {"rows": [{"k": "bar", "t": [0.555, 0.57], "m": TRIM, "d": 0.006},
                 {"k": "motif", "t": 0.56, "h": 0.085, "w": 0.30, "pitch": 0.36, "shrink": 0.5, "o": "diamond_neon", "m": NEON}]}),
    _p("skirt_neon_dash", "Neon tracejado duplo", "090", {},
       {"rows": [{"k": "dash", "t": [0.60, 0.665], "len": 0.34, "gap": 0.10, "m": NEON},
                 {"k": "dash", "t": [0.39, 0.455], "len": 0.34, "gap": 0.10, "shift": 0.5, "m": NEON}]}),
    _p("skirt_neon_arch", "Neon com arco da roda", "091", {},
       {"rows": [{"k": "bar", "t": [0.66, 0.70], "m": NEON, "gap_arch": 0.115},
                 {"k": "bar", "t": [0.46, 0.50], "m": NEON, "gap_arch": 0.115}],
        "arch": {"m": NEON, "w": 0.032, "off": 0.06}}),
    _p("skirt_neon_green", "Traços verdes e ciano", "092",
       {"marker_led": lambda m, n: marker(n, 0.15, 0.045, 0.010, m["led"])},
       {"rows": [{"k": "motif", "t": 0.70, "h": 0.045, "w": 0.15, "pitch": 0.25, "o": "marker_led", "m": LED},
                 {"k": "bar", "t": [0.36, 0.50], "m": NEON}]}),
    _p("skirt_neon_gems", "Pedras de luz", "093",
       {"gem_neon": lambda m, n: gem(n, 0.17, 0.018, m["neon"]), "marker_led": lambda m, n: marker(n, 0.13, 0.035, 0.009, m["led"])},
       {"rows": [{"k": "motif", "t": 0.72, "h": 0.035, "w": 0.13, "pitch": 0.24, "o": "marker_led", "m": LED},
                 {"k": "motif", "t": 0.53, "h": 0.17, "w": 0.17, "pitch": 0.32, "o": "gem_neon", "m": NEON},
                 {"k": "motif", "t": 0.34, "h": 0.035, "w": 0.13, "pitch": 0.24, "o": "marker_led", "m": LED}]}),
    _p("skirt_neon_arrows", "Setas duplas", "094",
       {"arrow_neon": lambda m, n: arrow_bar(n, 0.86, 0.05, 0.12, 0.10, 0.011, m["neon"]),
        "marker_led": lambda m, n: marker(n, 0.07, 0.03, 0.008, m["led"])},
       {"rows": [{"k": "motif", "t": 0.80, "h": 0.03, "w": 0.07, "pitch": 0.26, "o": "marker_led", "m": LED},
                 {"k": "motif", "t": 0.62, "h": 0.10, "w": 0.86, "pitch": 0.95, "shrink": 0.35, "o": "arrow_neon", "m": NEON},
                 {"k": "motif", "t": 0.44, "h": 0.10, "w": 0.86, "pitch": 0.95, "shrink": 0.35, "o": "arrow_neon", "m": NEON}]}),
]
