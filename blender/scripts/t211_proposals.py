"""Folha de PROPOSTA (T-211, item C): rodas, escapamento, grade, buzina, interior e adesivos no estilo das capturas
da oficina (cromo, neon, LED, dia/noite). São esboços rápidos de forma e cor (blocos simples), NÃO os modelos finais:
servem para o Marco escolher antes de modelar. 3 ideias por categoria, numeradas como em docs/REFERENCIA_PECAS.md
(seção 19).

Uso: blender -b --factory-startup -P blender/scripts/t211_proposals.py -- --out PASTA_ABS
Saída: PASTA/proposta_<categoria>.png e PASTA/proposta_lacunas.png (folha com as 6).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from accessories import t211_kit as K  # noqa: E402
from lib import mesh3d as M, preview as P, scene  # noqa: E402

FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fonts", "YujiSyuku-Regular.ttf")


def mats():
    m = K.materials(None, night=True)
    m["gold"] = K._mat("gold", "#f0b83a", 1.0, 0.2)
    m["pink"] = K._mat("lamp_pink", "#ff2e88", 0.0, 0.5, 3.0)
    m["amber"] = K._mat("lamp_amber", "#ffb347", 0.0, 0.5, 3.0)
    m["red"] = K._mat("velvet_red", "#9a0f2a", 0.0, 0.8)
    m["white"] = K._mat("paint_white", "#e9eef5", 0.3, 0.3)
    m["rubber"] = K._mat("rubber", "#18181b", 0.0, 0.9)
    return m


# ----------------------------------------------------------------------------- rodas
def _tire(m, x):
    return M.cylinder("tire", 0.5, 0.3, (x, 0, 0.5), m["rubber"], axis="Y", seg=32)


def wheel_holes(m, x):
    o = [_tire(m, x), M.cylinder("disc", 0.36, 0.05, (x, -0.15, 0.5), m["chrome"], axis="Y", seg=32)]
    for k in range(10):
        a = k * math.tau / 10
        o.append(M.cylinder(f"hole{k}", 0.045, 0.06, (x + math.cos(a) * 0.24, -0.17, 0.5 + math.sin(a) * 0.24), m["trim"], axis="Y", seg=10))
    o.append(M.torus("led_ring", 0.40, 0.018, (x, -0.16, 0.5), m["neon"], axis="Y"))
    return o


def wheel_star(m, x):
    o = [_tire(m, x), M.cylinder("rim", 0.37, 0.04, (x, -0.15, 0.5), m["gold"], axis="Y", seg=32)]
    for k in range(8):
        a = k * math.tau / 8
        o.append(M.box(f"spoke{k}", (0.06, 0.04, 0.34), (x + math.cos(a) * 0.17, -0.18, 0.5 + math.sin(a) * 0.17), m["chrome"],
                       bevel=0.01, rot=(0, math.degrees(a) + 90, 0)))
    o.append(M.cylinder("hub", 0.08, 0.08, (x, -0.2, 0.5), m["chrome"], axis="Y"))
    return o


def wheel_deep(m, x):
    o = [_tire(m, x), M.cylinder("dish", 0.38, 0.12, (x, -0.12, 0.5), m["chrome"], axis="Y", seg=32, radius2=0.28)]
    o.append(M.torus("neon_lip", 0.38, 0.02, (x, -0.17, 0.5), m["pink"], axis="Y"))
    o.append(M.cylinder("spinner", 0.12, 0.05, (x, -0.2, 0.5), m["gold"], axis="Y", seg=6))
    return o


# ----------------------------------------------------------------------------- escapamento
def stack_twin(m, x):
    o = []
    for dx in (-0.12, 0.12):
        o.append(M.cylinder("pipe", 0.07, 2.2, (x + dx, 0, 1.1), m["chrome"], seg=16))
        o.append(M.cylinder("tip", 0.085, 0.12, (x + dx, 0, 2.25), m["neon"], seg=16))
        o.append(M.box("guard", (0.17, 0.17, 0.7), (x + dx, 0.03, 1.0), m["gold"], bevel=0.02))
    return o


def stack_j(m, x):
    pts = [(x, 0, 0.2), (x, 0, 1.6), (x, 0.05, 1.9), (x, 0.25, 2.05), (x, 0.42, 2.0)]
    o = [M.tube("pipe", pts, 0.08, m["chrome"], seg=14)]
    o.append(M.box("guard", (0.2, 0.2, 0.9), (x, 0.0, 0.9), m["trim"], bevel=0.03))
    for k in range(6):
        o.append(M.box(f"slot{k}", (0.21, 0.04, 0.06), (x, 0.0, 0.55 + k * 0.12), m["amber"], bevel=0.0))
    return o


def side_triple(m, x):
    o = [M.box("box", (0.5, 0.3, 0.25), (x, 0, 0.45), m["chrome"], bevel=0.03)]
    for k in range(3):
        o.append(M.cylinder(f"out{k}", 0.05, 0.25, (x - 0.15 + k * 0.15, -0.25, 0.45), m["chrome"], axis="Y"))
        o.append(M.cylinder(f"glow{k}", 0.04, 0.02, (x - 0.15 + k * 0.15, -0.38, 0.45), m["neon"], axis="Y"))
    return o


# ----------------------------------------------------------------------------- grade
def grille_bars(m, x):
    o = [M.box("frame", (1.2, 0.08, 0.6), (x, 0, 0.8), m["chrome"], bevel=0.02)]
    for k in range(13):
        o.append(M.box(f"bar{k}", (0.03, 0.06, 0.52), (x - 0.54 + k * 0.09, -0.05, 0.8), m["chrome"], bevel=0.008))
    o.append(M.box("led", (1.22, 0.02, 0.03), (x, -0.06, 1.12), m["led"], bevel=0.0))
    return o


def grille_comb(m, x):
    o = [M.box("frame", (1.2, 0.08, 0.6), (x, 0, 0.8), m["gold"], bevel=0.02)]
    for r in range(4):
        for c in range(9):
            o.append(M.cylinder(f"h{r}_{c}", 0.055, 0.04, (x - 0.48 + c * 0.12 + (0.06 if r % 2 else 0), -0.05, 0.62 + r * 0.12),
                                m["trim"], axis="Y", seg=6))
    o.append(M.cylinder("sun", 0.12, 0.05, (x, -0.08, 0.8), m["amber"], axis="Y", seg=20))
    return o


def grille_louver(m, x):
    o = [M.box("frame", (1.2, 0.08, 0.6), (x, 0, 0.8), m["chrome"], bevel=0.02)]
    for k in range(6):
        o.append(M.box(f"lam{k}", (1.1, 0.07, 0.035), (x, -0.06, 0.58 + k * 0.09), m["gold"], bevel=0.008, rot=(20, 0, 0)))
    o.append(M.box("neon_l", (0.03, 0.03, 0.6), (x - 0.62, -0.06, 0.8), m["neon"], bevel=0.0))
    o.append(M.box("neon_r", (0.03, 0.03, 0.6), (x + 0.62, -0.06, 0.8), m["neon"], bevel=0.0))
    return o


# ----------------------------------------------------------------------------- buzina
def horn_triple(m, x):
    o = []
    for k, (ln, z) in enumerate(((0.55, 0.6), (0.7, 0.78), (0.85, 0.96))):
        o.append(M.cylinder(f"trumpet{k}", 0.04, ln, (x, -ln / 2, z), m["chrome"], axis="Y", radius2=0.11, seg=18))
    o.append(M.box("base", (0.18, 0.3, 0.5), (x, 0.15, 0.78), m["trim"], bevel=0.02))
    return o


def horn_twin_long(m, x):
    return [M.cylinder("t1", 0.04, 1.2, (x - 0.1, -0.5, 0.8), m["gold"], axis="Y", radius2=0.13, seg=18),
            M.cylinder("t2", 0.04, 1.0, (x + 0.12, -0.4, 0.8), m["gold"], axis="Y", radius2=0.12, seg=18),
            M.box("valve", (0.4, 0.2, 0.18), (x, 0.15, 0.8), m["chrome"], bevel=0.03)]


def horn_ship(m, x):
    return [M.cylinder("bell", 0.08, 0.6, (x, 0, 1.0), m["chrome"], radius2=0.28, seg=24),
            M.cylinder("stem", 0.05, 0.6, (x, 0, 0.45), m["chrome"], seg=12),
            M.torus("ring", 0.28, 0.015, (x, 0, 1.3), m["amber"], axis="Z")]


# ----------------------------------------------------------------------------- interior
def interior_curtain(m, x):
    o = [M.box("dash", (1.3, 0.4, 0.3), (x, 0.3, 0.5), m["trim"], bevel=0.03)]
    for k in range(9):
        o.append(M.box(f"fold{k}", (0.12, 0.05, 0.55), (x - 0.6 + k * 0.15, 0.6 + (k % 2) * 0.04, 1.25), m["red"], bevel=0.03))
    o.append(M.box("tassel_bar", (1.35, 0.05, 0.05), (x, 0.55, 1.55), m["gold"], bevel=0.01))
    return o


def interior_chandelier(m, x):
    o = [M.box("roof", (1.3, 0.8, 0.05), (x, 0.4, 1.7), m["trim"], bevel=0.01)]
    o.append(M.cylinder("stem", 0.015, 0.25, (x, 0.4, 1.55), m["gold"], seg=8))
    for k in range(8):
        a = k * math.tau / 8
        o.append(M.sphere(f"crystal{k}", 0.05, (x + math.cos(a) * 0.22, 0.4 + math.sin(a) * 0.22, 1.38), m["amber"], seg=8, rings=5))
    o.append(M.torus("ring", 0.22, 0.012, (x, 0.4, 1.42), m["gold"], axis="Z"))
    return o


def interior_tufted(m, x):
    o = [M.box("seat_back", (0.9, 0.2, 0.8), (x, 0.4, 0.9), m["red"], bevel=0.06)]
    for r in range(3):
        for c in range(4):
            o.append(M.sphere(f"btn{r}{c}", 0.025, (x - 0.3 + c * 0.2, 0.29, 0.65 + r * 0.25), m["gold"], seg=8, rings=4))
    o.append(M.box("panel_neon", (0.95, 0.02, 0.03), (x, 0.28, 1.33), m["pink"], bevel=0.0))
    return o


# ----------------------------------------------------------------------------- adesivos
def _decal_text(m, x, text, mat, z=0.9, size=0.35):
    t = M.text3d("txt", text, size, (x, -0.06, z), mat, font_path=FONT, extrude=0.004, rot=(90, 0, 0), resolution=4, offset=0.0)
    return t


def decal_kanji(m, x):
    return [M.box("panel", (1.1, 0.05, 0.7), (x, 0, 0.9), m["white"], bevel=0.01), _decal_text(m, x, "天下御免", m["red"], size=0.26)]


def decal_flames(m, x):
    o = [M.box("panel", (1.1, 0.05, 0.7), (x, 0, 0.9), m["trim"], bevel=0.01)]
    for k in range(5):
        o.append(M.cylinder(f"flame{k}", 0.08, 0.5, (x - 0.4 + k * 0.2, -0.04, 0.75 + (k % 2) * 0.08), m["amber"], radius2=0.0, seg=6))
    return o


def decal_sun(m, x):
    o = [M.box("panel", (1.1, 0.05, 0.7), (x, 0, 0.9), m["white"], bevel=0.01)]
    for k in range(8):
        a = k * math.tau / 16 * 2
        o.append(M.box(f"ray{k}", (0.05, 0.02, 0.6), (x, -0.04, 0.9), m["red"], bevel=0.0, rot=(0, math.degrees(a), 0)))
    o.append(M.cylinder("sun", 0.13, 0.03, (x, -0.06, 0.9), m["red"], axis="Y", seg=20))
    return o


CATS = [
    ("rodas", [wheel_holes, wheel_star, wheel_deep]),
    ("escapamento", [stack_twin, stack_j, side_triple]),
    ("grade", [grille_bars, grille_comb, grille_louver]),
    ("buzina", [horn_triple, horn_twin_long, horn_ship]),
    ("interior", [interior_curtain, interior_chandelier, interior_tufted]),
    ("adesivos", [decal_kanji, decal_flames, decal_sun]),
]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    out = os.path.abspath(ap.parse_args(argv).out)
    os.makedirs(out, exist_ok=True)
    paths = []
    for cat, builds in CATS:
        scene.reset_scene()
        m = mats()
        objs = []
        for i, b in enumerate(builds):
            x = (i - 1) * 1.6
            parts = b(m, x)
            objs += parts
            lab = M.text3d("label", str(i + 1), 0.22, (x, -0.6, 0.05), m["white"], extrude=0.0, rot=(60, 0, 0), resolution=4, offset=0.0)
            objs.append(lab)
        M.apply_transforms([o for o in objs])
        prefix = os.path.join(out, f"proposta_{cat}")
        P.render_views(prefix, objs, size=(720, 405), center=(0.0, 0.0, 0.85), views={"v": (162, 14, 5.4)}, lens=45, night=True)
        os.replace(prefix + "_v.png", prefix + ".png")
        paths.append(prefix + ".png")
        print("[proposta]", cat)
    P.contact_sheet(paths, os.path.join(out, "proposta_lacunas.png"), cols=2)
    print("OK t211_proposals")


main()
