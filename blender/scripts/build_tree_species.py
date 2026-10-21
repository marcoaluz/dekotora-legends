"""T-186: especies de arvore FEITAS POR CODIGO (nao ha arquivo delas em docs/Modelos) e o 2o nivel (LOD1) das antigas.

docs/Modelos so tem UMA especie de arvore (Gleditsia, 6 variacoes: build_tree_kit.py). Para misturar especies por
bioma, como o Marco pediu, estas saem no mesmo estilo low-poly da P46 (build_scenery_3d.py):
  tree_cedar      cedro japones (sugi): tronco reto e copa estreita em 5 cones, verde escuro, ~12 m (montanha)
  palm_tall       coqueiro alto e quase reto, 11 folhas, ~10 m (litoral)
  palm_bent       coqueiro baixo e bem curvado para o mar, 8 folhas, ~6 m (litoral)
  <nome>_lod1     versao de longe (menos lados e folhas) de: palm, palm_tall, palm_bent, tree_pine, tree_round,
                  tree_cedar, bush (as originais palm/tree_pine/tree_round/bush NAO sao regravadas)
Origem na base, frente = +Y (Blender). Materiais "wood" e "leaf"/"leaf_dark" com cor (o Godot le do .glb).

Uso: blender -b --factory-startup -P blender/scripts/build_tree_species.py -- [--only nome1,nome2] [--preview]
Deterministico. --preview grava blender/renders/t186/species_sheet.png.
"""
from __future__ import annotations

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import mesh3d as M, pbr, preview, scene  # noqa: E402

OUT = os.path.join(ROOT, "game", "assets", "scenery")
WORK = os.path.join(ROOT, "blender", "renders", "t186")


def _palm(m, pts, fronds: int, frond_len: float, seg: int, frond_seg: int, nuts: bool, rings: bool) -> list:
    o = []
    for i in range(len(pts) - 1):
        (x0, y0, z0), (x1, y1, z1) = pts[i], pts[i + 1]
        r = 0.24 - i * 0.03 * (4.0 / (len(pts) - 1))
        o.append(M.tube(f"trunk{i}", [pts[i], pts[i + 1]], r, m["wood"], seg=seg))
        if rings:
            o.append(M.torus(f"ring{i}", r + 0.01, 0.035, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), m["wood"],
                             axis="Z", seg=10, tube_seg=4))
    top = pts[-1]
    for k in range(fronds):
        a = k * math.tau / fronds + 0.3
        d = (math.cos(a), math.sin(a))
        droop = 1.6 + 0.4 * ((k * 7) % 3) / 2.0           # folhas caem diferente (sem sorteio: deterministico)
        pf = [top]
        for j in range(1, 5):
            t = j / 4
            pf.append((top[0] + d[0] * frond_len * t, top[1] + d[1] * frond_len * t, top[2] + 0.5 * t - droop * t * t))
        o.append(M.tube(f"frond{k}", pf, 0.16, m["leaf"], seg=frond_seg))
    if nuts:
        for k in range(3):
            a = k * math.tau / 3
            o.append(M.sphere(f"coco{k}", 0.13, (top[0] + 0.2 * math.cos(a), top[1] + 0.2 * math.sin(a), top[2] - 0.25),
                              m["wood"], seg=8, rings=5))
    return o


PALM_PTS = [(0.0, 0.0, 0.0), (0.25, 0.0, 2.0), (0.7, 0.0, 4.0), (1.3, 0.0, 5.8), (1.9, 0.0, 7.2)]   # = palm.glb (P46)
TALL_PTS = [(0.0, 0.0, 0.0), (0.1, 0.0, 2.6), (0.3, 0.0, 5.2), (0.6, 0.0, 7.6), (0.95, 0.0, 9.8)]
BENT_PTS = [(0.0, 0.0, 0.0), (0.6, 0.0, 1.5), (1.6, 0.0, 2.9), (2.8, 0.0, 4.2), (3.9, 0.0, 5.6)]


def palm_tall(m, lod: int = 0) -> list:
    return _palm(m, TALL_PTS if lod == 0 else TALL_PTS[::2], 11 if lod == 0 else 6, 2.8, 8 if lod == 0 else 5,
                 4 if lod == 0 else 3, lod == 0, lod == 0)


def palm_bent(m, lod: int = 0) -> list:
    return _palm(m, BENT_PTS if lod == 0 else BENT_PTS[::2], 8 if lod == 0 else 5, 2.4, 8 if lod == 0 else 5,
                 4 if lod == 0 else 3, lod == 0, lod == 0)


def palm(m, lod: int = 1) -> list:
    return _palm(m, PALM_PTS[::2], 6, 2.6, 5, 3, False, False)


def tree_cedar(m, lod: int = 0) -> list:
    seg = 8 if lod == 0 else 5
    o = [M.cylinder("trunk", 0.3, 3.2, (0, 0, 1.6), m["wood"], axis="Z", seg=seg, radius2=0.2)]
    tiers = ((1.7, 2.4, 3.0), (1.45, 4.3, 2.8), (1.2, 6.1, 2.6), (0.9, 7.8, 2.4), (0.55, 9.4, 2.4))
    if lod:
        tiers = ((1.6, 2.4, 4.0), (1.1, 5.6, 4.0), (0.6, 8.8, 3.2))
    for i, (r, z, h) in enumerate(tiers):
        o.append(M.cylinder(f"cone{i}", r, h, (0, 0, z + h / 2), m["leaf_dark"], axis="Z", seg=seg, radius2=0.08))
    return o


def tree_pine(m, lod: int = 1) -> list:          # = tree_pine.glb (P46) com menos lados e 2 cones
    o = [M.cylinder("trunk", 0.25, 2.0, (0, 0, 1.0), m["wood"], axis="Z", seg=5, radius2=0.18)]
    for i, (r, z, h) in enumerate(((1.9, 1.6, 2.6), (1.25, 3.6, 2.8))):
        o.append(M.cylinder(f"cone{i}", r, h, (0, 0, z + h / 2), m["leaf"], axis="Z", seg=6, radius2=0.05))
    return o


def tree_round(m, lod: int = 1) -> list:         # = tree_round.glb (P46) com 2 esferas de poucos lados
    return [M.cylinder("trunk", 0.22, 2.4, (0, 0, 1.2), m["wood"], axis="Z", seg=5, radius2=0.16),
            M.sphere("crown0", 1.6, (0, 0, 3.5), m["leaf"], seg=7, rings=5),
            M.sphere("crown1", 1.0, (0.5, 0.4, 3.9), m["leaf"], seg=6, rings=4)]


def bush(m, lod: int = 1) -> list:
    return [M.sphere("b0", 0.85, (0, 0, 0.5), m["leaf"], seg=6, rings=4),
            M.sphere("b1", 0.6, (0.7, 0.2, 0.4), m["leaf"], seg=5, rings=4)]


BUILD = {   # nome no jogo -> (funcao, lod)
    "tree_cedar": (tree_cedar, 0), "palm_tall": (palm_tall, 0), "palm_bent": (palm_bent, 0),
    "tree_cedar_lod1": (tree_cedar, 1), "palm_tall_lod1": (palm_tall, 1), "palm_bent_lod1": (palm_bent, 1),
    "palm_lod1": (palm, 1), "tree_pine_lod1": (tree_pine, 1), "tree_round_lod1": (tree_round, 1),
    "bush_lod1": (bush, 1),
}


def materials() -> dict:
    m = pbr.standard_set()
    m["wood"] = pbr.pbr("wood", "#5a3a1a", roughness=0.9)
    m["leaf"] = pbr.pbr("leaf", "#1c5a3c", roughness=0.85)
    m["leaf_dark"] = pbr.pbr("leaf_dark", "#173d2b", roughness=0.9)
    return m


def main() -> None:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = a[a.index("--only") + 1].split(",") if "--only" in a else list(BUILD)
    os.makedirs(WORK, exist_ok=True)
    report = []
    shots = []
    for name in only:
        fn, lod = BUILD[name]
        scene.reset_scene()
        m = materials()
        objs = fn(m, lod)
        M.apply_transforms(objs)
        M.smooth(objs, 35.0)
        tris = M.count_tris(objs)
        merged = M.join_by_material(objs, prefix="")
        root = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(root)
        for o in merged:
            o.parent = root
        M.export_glb(os.path.join(OUT, name + ".glb"), [root] + merged)
        mn, mx = M.bounds(merged)
        report.append({"name": name, "lod": lod, "tris": tris, "size_m": [round(v, 2) for v in (mx - mn)]})
        print("SPECIES", json.dumps(report[-1]))
        if "--preview" in a:
            ctr = (mn + mx) / 2
            base = os.path.join(WORK, "species_" + name)
            preview.render_views(base, merged, size=(360, 360), center=tuple(ctr), views={"34": (25, 12)},
                                 dist=max((mx - mn).length * 1.4, 4.0), lens=50.0)
            shots += [p for p in (base + "_34.png",) if os.path.isfile(p)]
    with open(os.path.join(WORK, "species.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=1)
    if shots:
        preview.contact_sheet(shots, os.path.join(WORK, "species_sheet.png"), cols=5)
    print("OK species")


main()
