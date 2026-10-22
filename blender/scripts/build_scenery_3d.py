"""Carros de transito e objetos de beira de estrada em 3D (P46): .glb PBR para o Godot.

Uso: blender -b --factory-startup -P blender/scripts/build_scenery_3d.py -- [--out game/assets/vehicles/dekotora]
Saída:
  game/assets/vehicles/traffic/<id>.glb         carros genéricos (sem marca): car_hatch, car_sedan, car_van, car_kei_truck
  game/assets/scenery/<id>.glb                  lamp_post, tree_pine, tree_round, sign_green, guardrail, toll_gate
Origem: no chão, no centro de TRÁS do carro / na base do objeto. Frente = +Y (Blender) = -Z (Godot).
A pintura usa o material "paint_white" para o Godot trocar a cor por instância.
"""
import argparse
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, pbr, preview, scene  # noqa: E402

FONT = os.path.abspath("game/assets/fonts/NotoSansJP.ttf")


def finish(objs, name, out_path, extra_roots=()):
    """Aplica transformações, suaviza, junta por material e exporta."""
    M.apply_transforms(objs)
    M.smooth(objs, 35.0)
    tris = M.count_tris(objs)
    merged = M.join_by_material(objs, prefix="")
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged:
        o.parent = root
    M.export_glb(out_path, [root] + merged)
    print(f"[cenario] {name:14s} tris={tris}")
    return merged


# ----------------------------------------------------------------------------- carros

def _wheels(m, o, xs, ys, r=0.32, w=0.22):
    for x in xs:
        for y in ys:
            o.append(M.cylinder(f"wheel_{x}_{y}", r, w, (x, y, r), m["rubber"], axis="X", seg=18, bevel=0.05, bevel_seg=2))
            o.append(M.cylinder(f"rim_{x}_{y}", r * 0.6, w + 0.02, (x, y, r), m["steel"], axis="X", seg=14))


def car_hatch(m):
    o = []
    body = [(0.0, 0.3), (0.0, 0.95), (0.9, 1.1), (1.6, 1.5), (2.9, 1.5), (3.5, 1.05), (3.95, 0.95), (3.95, 0.4), (3.7, 0.3)]
    o.append(M.profile_extrude("body", body, 1.7, (0, 0, 0), m["paint_white"], bevel=0.07, seg=2))
    o.append(M.box("glass", (1.62, 1.9, 0.5), (0, 2.1, 1.25), m["glass"], bevel=0.04, seg=1))
    _wheels(m, o, (-0.78, 0.78), (0.8, 3.1))
    for sx in (-1, 1):
        o.append(M.box(f"tail_{sx}", (0.35, 0.05, 0.14), (sx * 0.6, 0.0, 0.85), m["lamp_red"], bevel=0.02, seg=1))
        o.append(M.box(f"head_{sx}", (0.35, 0.05, 0.16), (sx * 0.6, 3.95, 0.75), m["lamp_white"], bevel=0.02, seg=1))
    o.append(M.box("bumper_r", (1.74, 0.1, 0.2), (0, -0.02, 0.38), m["plastic"], bevel=0.03, seg=1))
    return o


def car_sedan(m):
    o = []
    body = [(0.0, 0.35), (0.0, 0.95), (0.6, 1.0), (1.2, 1.0), (1.6, 1.4), (3.0, 1.42), (3.5, 1.05), (4.6, 0.95), (4.6, 0.4), (4.3, 0.33)]
    o.append(M.profile_extrude("body", body, 1.8, (0, 0, 0), m["paint_white"], bevel=0.07, seg=2))
    o.append(M.box("glass", (1.72, 1.9, 0.5), (0, 2.35, 1.22), m["glass"], bevel=0.04, seg=1))
    _wheels(m, o, (-0.82, 0.82), (0.95, 3.6), r=0.34)
    for sx in (-1, 1):
        o.append(M.box(f"tail_{sx}", (0.4, 0.05, 0.14), (sx * 0.65, 0.0, 0.85), m["lamp_red"], bevel=0.02, seg=1))
        o.append(M.box(f"head_{sx}", (0.4, 0.05, 0.15), (sx * 0.65, 4.6, 0.78), m["lamp_white"], bevel=0.02, seg=1))
    o.append(M.box("trim", (1.84, 4.5, 0.05), (0, 2.3, 0.62), m["chrome"], bevel=0.01, seg=1))
    return o


def car_van(m):
    o = []
    body = [(0.0, 0.35), (0.0, 1.9), (3.6, 1.95), (4.3, 1.3), (4.5, 0.9), (4.5, 0.4), (4.2, 0.33)]
    o.append(M.profile_extrude("body", body, 1.85, (0, 0, 0), m["paint_white"], bevel=0.08, seg=2))
    o.append(M.box("glass_front", (1.7, 0.08, 0.7), (0, 4.15, 1.55), m["glass"], bevel=0.03, seg=1, rot=(-35, 0, 0)))
    for sx in (-1, 1):
        o.append(M.box(f"side_glass_{sx}", (0.05, 1.2, 0.6), (sx * 0.93, 3.4, 1.5), m["glass"], bevel=0.02, seg=1))
    _wheels(m, o, (-0.8, 0.8), (0.9, 3.5), r=0.35)
    for sx in (-1, 1):
        o.append(M.box(f"tail_{sx}", (0.3, 0.05, 0.4), (sx * 0.75, 0.0, 1.0), m["lamp_red"], bevel=0.02, seg=1))
        o.append(M.box(f"head_{sx}", (0.35, 0.05, 0.16), (sx * 0.62, 4.5, 0.75), m["lamp_white"], bevel=0.02, seg=1))
    o.append(M.box("stripe", (1.87, 4.4, 0.12), (0, 2.2, 0.9), m["paint_blue"], bevel=0.01, seg=1))
    return o


def car_kei_truck(m):
    o = []
    cab = [(2.0, 0.35), (2.0, 1.45), (2.6, 1.5), (3.15, 1.3), (3.4, 0.9), (3.4, 0.4), (3.1, 0.33)]
    o.append(M.profile_extrude("cab", cab, 1.4, (0, 0, 0), m["paint_white"], bevel=0.06, seg=2))
    o.append(M.box("bed", (1.42, 2.0, 0.45), (0, 1.0, 0.75), m["paint_white"], bevel=0.04, seg=1))
    o.append(M.box("bed_floor", (1.3, 1.9, 0.05), (0, 1.0, 0.55), m["steel"], bevel=0.01, seg=1))
    o.append(M.box("glass", (1.32, 0.9, 0.5), (0, 2.5, 1.2), m["glass"], bevel=0.03, seg=1))
    _wheels(m, o, (-0.62, 0.62), (0.6, 2.7), r=0.28, w=0.18)
    for sx in (-1, 1):
        o.append(M.box(f"tail_{sx}", (0.22, 0.05, 0.12), (sx * 0.55, 0.0, 0.9), m["lamp_red"], bevel=0.02, seg=1))
        o.append(M.box(f"head_{sx}", (0.28, 0.05, 0.14), (sx * 0.45, 3.4, 0.75), m["lamp_white"], bevel=0.02, seg=1))
    return o


CARS = {"car_hatch": car_hatch, "car_sedan": car_sedan, "car_van": car_van, "car_kei_truck": car_kei_truck}


# ----------------------------------------------------------------------------- cenário

def lamp_post(m):
    o = [M.cylinder("pole", 0.09, 7.2, (0, 0, 3.6), m["steel"], axis="Z", seg=12),
         M.cylinder("base", 0.17, 0.6, (0, 0, 0.3), m["steel"], axis="Z", seg=12, radius2=0.1),
         M.tube("arm", [(0, 0, 7.0), (0, 0.0, 7.5), (-1.0, 0.0, 7.6), (-1.6, 0.0, 7.45)], 0.05, m["steel"], seg=8),
         M.box("head", (0.85, 0.34, 0.14), (-1.65, 0, 7.4), m["plastic"], bevel=0.04),
         M.box("lamp", (0.7, 0.26, 0.06), (-1.65, 0, 7.32), m["lamp_amber"], bevel=0.02, seg=1)]
    return o


def tree_pine(m):
    o = [M.cylinder("trunk", 0.25, 2.0, (0, 0, 1.0), m["wood"], axis="Z", seg=8, radius2=0.18)]
    for i, (r, z, h) in enumerate(((1.9, 1.6, 2.2), (1.5, 3.0, 2.0), (1.0, 4.3, 1.8))):
        o.append(M.cylinder(f"cone{i}", r, h, (0, 0, z + h / 2), m["leaf"], axis="Z", seg=9, radius2=0.05))
    return o


def tree_round(m):
    o = [M.cylinder("trunk", 0.22, 2.4, (0, 0, 1.2), m["wood"], axis="Z", seg=8, radius2=0.16)]
    for i, (x, y, z, r) in enumerate(((0, 0, 3.4, 1.5), (0.8, 0.3, 3.0, 1.0), (-0.8, -0.2, 3.1, 1.0), (0.1, 0.7, 4.0, 0.95))):
        o.append(M.sphere(f"crown{i}", r, (x, y, z), m["leaf"], seg=10, rings=6))
    return o


def sign_green(m):
    o = [M.box("post_l", (0.14, 0.14, 4.6), (-2.1, 0, 2.3), m["steel"], bevel=0.02, seg=1),
         M.box("post_r", (0.14, 0.14, 4.6), (2.1, 0, 2.3), m["steel"], bevel=0.02, seg=1),
         M.box("border", (4.9, 0.1, 2.5), (0, -0.02, 3.55), m["paint_white"], bevel=0.05, seg=1),
         M.box("panel", (4.7, 0.12, 2.3), (0, 0.0, 3.55), m["sign_green"], bevel=0.04, seg=1),
         M.text3d("text_main", "東京 TOKYO", 1.85, (0, 0.08, 4.02), m["paint_white"], font_path=FONT, rot=(90, 0, 180), resolution=2, offset=0.008),
         M.text3d("text_dist", "12 km", 1.5, (0, 0.08, 3.0), m["paint_white"], font_path=FONT, rot=(90, 0, 180), resolution=2, offset=0.012)]
    return o


def guardrail(m):
    o = []
    for i in range(5):
        o.append(M.box(f"post_{i}", (0.12, 0.12, 0.85), (-2.0 + i, 0, 0.42), m["steel"], bevel=0.02, seg=1))
    o.append(M.box("rail", (4.2, 0.08, 0.32), (0, -0.07, 0.62), m["chrome"], bevel=0.03, seg=2))
    o.append(M.box("rail_low", (4.2, 0.06, 0.12), (0, -0.07, 0.3), m["steel"], bevel=0.02, seg=1))
    return o


def toll_gate(m):
    """Pedágio decorativo: cobertura sobre 4 faixas, pilares nas bordas, ilha central com cabine e
    luzes de faixa (verde/vermelho). Vão livre nas 4 faixas do jogo (x = -5,4; -1,8; 1,8; 5,4 m)."""
    o = [M.box("canopy", (19.0, 6.0, 0.6), (0, 0, 5.9), m["paint_white"], bevel=0.08),
         M.box("canopy_stripe", (19.1, 6.05, 0.2), (0, 0, 5.55), m["paint_pink"], bevel=0.02, seg=1),
         M.box("island", (0.5, 6.0, 0.25), (0, 0, 0.12), m["steel"], bevel=0.03, seg=1),
         M.box("booth", (0.9, 2.8, 2.3), (0, 0, 1.4), m["paint_white"], bevel=0.06),
         M.box("booth_window", (0.95, 1.2, 0.8), (0, 0, 1.8), m["glass"], bevel=0.03, seg=1),
         M.box("booth_pillar", (0.4, 0.4, 3.6), (0, 0, 4.1), m["steel"], bevel=0.04)]
    for i, x in enumerate((-8.8, 8.8)):
        o.append(M.box(f"pillar_{i}", (0.6, 0.6, 5.8), (x, 0, 2.9), m["steel"], bevel=0.05))
    for i, x in enumerate((-5.4, -1.8, 1.8, 5.4)):
        o.append(M.box(f"lane_light_{i}", (0.9, 0.12, 0.35), (x, -3.02, 5.3), m["lamp_green"] if i in (0, 3) else m["lamp_red"], bevel=0.03, seg=1))
        o.append(M.box(f"lane_light_frame_{i}", (1.0, 0.08, 0.45), (x, -3.0, 5.3), m["plastic"], bevel=0.03, seg=1))
    return o


def palm(m):
    """Palmeira do litoral: tronco curvo em gomos, 9 folhas caídas (lâminas finas) e cocos."""
    import math
    o = []
    pts = [(0.0, 0.0, 0.0), (0.25, 0.0, 2.0), (0.7, 0.0, 4.0), (1.3, 0.0, 5.8), (1.9, 0.0, 7.2)]
    for i in range(len(pts) - 1):
        (x0, _, z0), (x1, _, z1) = pts[i], pts[i + 1]
        r = 0.24 - i * 0.03
        o.append(M.tube(f"trunk{i}", [pts[i], pts[i + 1]], r, m["wood"], seg=8))
        o.append(M.torus(f"ring{i}", r + 0.01, 0.035, ((x0 + x1) / 2, 0, (z0 + z1) / 2), m["wood"], axis="Z", seg=10, tube_seg=4))
    top = pts[-1]
    for k in range(9):
        a = k * math.tau / 9
        d = (math.cos(a), math.sin(a))
        pts_f = [top]
        for j in range(1, 5):
            t = j / 4
            pts_f.append((top[0] + d[0] * 2.6 * t, top[1] + d[1] * 2.6 * t, top[2] + 0.5 * t - 1.6 * t * t))
        o.append(M.tube(f"frond{k}", pts_f, 0.16, m["leaf"], seg=4))
    for k in range(3):
        a = k * math.tau / 3
        o.append(M.sphere(f"coco{k}", 0.13, (top[0] + 0.2 * math.cos(a), 0.2 * math.sin(a), top[2] - 0.25), m["wood"], seg=8, rings=5))
    return o


def rock(m):
    """Pedra da orla: esfera achatada com vértices deslocados (semente fixa)."""
    import random
    rnd = random.Random(5)
    o = M.sphere("rock", 1.0, (0, 0, 0.35), m["stone"], seg=10, rings=7, scale=(1.4, 1.0, 0.7))
    for v in o.data.vertices:
        v.co *= 0.82 + 0.3 * rnd.random()
    return [o, M.sphere("rock2", 0.55, (1.1, 0.5, 0.2), m["stone"], seg=8, rings=5, scale=(1.0, 0.9, 0.7))]


def bush(m):
    return [M.sphere(f"b{i}", r, (x, y, z), m["leaf"], seg=8, rings=5)
            for i, (x, y, z, r) in enumerate(((0, 0, 0.5, 0.8), (0.7, 0.2, 0.4, 0.6), (-0.6, -0.1, 0.4, 0.65), (0.1, 0.5, 0.6, 0.55)))]


SCENERY = {"palm": palm, "rock": rock, "bush": bush, "lamp_post": lamp_post, "tree_pine": tree_pine, "tree_round": tree_round, "sign_green": sign_green,
           "guardrail": guardrail, "toll_gate": toll_gate}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--traffic", default="game/assets/vehicles/traffic")
    ap.add_argument("--scenery", default="game/assets/scenery")
    ap.add_argument("--previews", default="game/assets/vehicles/dekotora/previews")
    ap.add_argument("--only", default="", help="lista separada por vírgula (ex.: palm,rock,bush)")
    args = ap.parse_args(argv)
    only = [x for x in args.only.split(",") if x]
    for kind, table, outdir in (("cars", CARS, args.traffic), ("scenery", SCENERY, args.scenery)):
        for name, fn in table.items():
            if only and name not in only:
                continue
            scene.reset_scene()
            m = pbr.standard_set()
            m["wood"] = pbr.pbr("wood", "#5a3a1a", roughness=0.9)
            m["leaf"] = pbr.pbr("leaf", "#1c5a3c", roughness=0.85)
            m["stone"] = pbr.pbr("stone", "#5a5650", roughness=0.9)
            m["sign_green"] = pbr.pbr("sign_green", "#1f7a4f", metallic=0.2, roughness=0.5)
            m["lamp_green"] = pbr.emissive("lamp_green", "#3fe67a", 3.0)
            objs = fn(m)
            merged = finish(objs, name, os.path.join(os.path.abspath(outdir), name + ".glb"))
            if name in ("car_sedan", "lamp_post", "toll_gate", "sign_green", "tree_pine"):
                mn, mx = M.bounds(merged)
                ctr = (mn + mx) / 2
                preview.render_views(os.path.join(os.path.abspath(args.previews), "scenery_" + name), merged, size=(640, 480),
                                     center=tuple(ctr), views={"34": (30, 16)}, dist=max((mx - mn).length * 1.5, 4.0), lens=50.0)
    print("OK build_scenery_3d")


main()
