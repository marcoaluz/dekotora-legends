"""T-217: expressway lamp posts with the LONG CURVED ARM over the road (as in the original game), made by code.

Uso: blender -b --factory-startup -P blender/scripts/build_t217_lamps.py -- [--out game/assets/scenery] [--preview PASTA_ABS]
Saida:
  lamp_arc.glb       poste conico de aco galvanizado, 10 m, braco curvo de 4,6 m para -X, luminaria chata de sodio
  lamp_arc_twin.glb  o mesmo com dois bracos (+X e -X): fica no canteiro central e ilumina as duas pistas
Origem no pe do poste, chao em Z = 0; o braco aponta para -X (o Roadside3D gira para a pista, como o lamp_post).
Materiais: "steel" (galvanizado), "plastic" (carcaca) e "lamp_amber" (emissivo; o jogo apaga de dia).
"""
import argparse
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, pbr, preview, scene  # noqa: E402

POLE_H = 9.6
REACH = 4.6
BEND_R = 1.5


def arm_points(sign: float):
    """Centre line of the arm: up the pole top, a quarter bend, then a long arm rising a little (5 degrees)."""
    pts = [(0.0, 0.0, POLE_H - 0.4)]
    for k in range(0, 7):
        a = math.radians(90.0 * k / 6.0)
        pts.append((sign * BEND_R * (1.0 - math.cos(a)), 0.0, POLE_H + BEND_R * math.sin(a) - 0.4))
    end_x = sign * REACH
    x0 = sign * BEND_R
    z0 = POLE_H + BEND_R - 0.4
    for k in range(1, 5):
        t = k / 4.0
        x = x0 + (end_x - x0) * t
        pts.append((x, 0.0, z0 + abs(x - x0) * math.tan(math.radians(5.0))))
    return pts


def lamp(m, twin: bool):
    o = [M.cylinder("pole", 0.14, POLE_H, (0, 0, POLE_H / 2), m["steel"], axis="Z", seg=12, radius2=0.085),
         M.box("plate", (0.5, 0.5, 0.05), (0, 0, 0.025), m["steel"], bevel=0.01, seg=1),
         M.box("footing", (0.7, 0.7, 0.35), (0, 0, -0.12), m["concrete"], bevel=0.03, seg=1),
         M.cylinder("door", 0.145, 0.45, (0, 0, 1.1), m["steel_dark"], axis="Z", seg=12)]
    for sign in ((-1.0, 1.0) if twin else (-1.0,)):
        pts = arm_points(sign)
        o.append(M.tube(f"arm{int(sign)}", pts, 0.065, m["steel"], seg=8))
        ex, _ey, ez = pts[-1]
        tilt = math.radians(5.0) * (1 if sign < 0 else -1)
        o.append(M.box(f"head{int(sign)}", (0.95, 0.38, 0.16), (ex + sign * 0.35, 0, ez - 0.02), m["plastic"], bevel=0.05,
                       rot=(0, math.degrees(tilt), 0)))
        o.append(M.box(f"lens{int(sign)}", (0.8, 0.3, 0.05), (ex + sign * 0.35, 0, ez - 0.11), m["lamp_amber"], bevel=0.015,
                       seg=1, rot=(0, math.degrees(tilt), 0)))
    return o


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/scenery")
    ap.add_argument("--preview", default="")
    a = ap.parse_args(argv)
    for name, twin in (("lamp_arc", False), ("lamp_arc_twin", True)):
        scene.reset_scene()
        m = pbr.standard_set()
        m["concrete"] = pbr.pbr("concrete", "#8d8b85", roughness=0.9)
        m["steel_dark"] = pbr.pbr("steel_dark", "#6d737a", metallic=0.6, roughness=0.45)
        objs = lamp(m, twin)
        M.apply_transforms(objs)
        M.smooth(objs, 35.0)
        tris = M.count_tris(objs)
        merged = M.join_by_material(objs, prefix="")
        root = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(root)
        for o in merged:
            o.parent = root
        M.export_glb(os.path.join(os.path.abspath(a.out), name + ".glb"), [root] + merged)
        print(f"OK {name} tris={tris}")
        if a.preview:
            mn, mx = M.bounds(merged)
            ctr = (mn + mx) / 2
            preview.render_views(os.path.join(a.preview, name), merged, size=(640, 480), center=tuple(ctr),
                                 views={"34": (30, 16)}, dist=max((mx - mn).length * 1.4, 4.0), lens=50.0)


main()
