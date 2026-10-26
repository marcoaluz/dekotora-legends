"""Encaixes e zonas protegidas de TODOS os caminhões (T-211): mede cada .glb do jogo e grava
`game/assets/vehicles/dekotora/truck/sockets/<modelo>.json` (coordenadas do Godot).

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_sockets.py -- [--only base_chata,canter] [--preview PASTA_ABS]

- Caixa-limite de cada encaixe (deque, viseira, retrovisor, para-choques, grade, escapamentos, escada, foguete,
  contorno do baú, saias) e zonas protegidas (para-brisa, faróis, lanternas, setas, placas, portas, rodas).
- Confere as regras de projeto (encaixes não se cruzam; nenhum encaixe entra em zona protegida) e para com ERRO se
  falhar. O teste do jogo (`game/tests/test_part_fit.gd`) confere as PEÇAS dentro dessas caixas.
- `--preview`: desenha cada caminhão com as caixas (azul = encaixe, vermelho = zona protegida) para conferência.
Determinístico (só lê os vértices dos .glb).
"""
import argparse
import glob
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import socket_rules as R, truck_measure as TM  # noqa: E402

TRUCK_DIR = "game/assets/vehicles/dekotora/truck"
OUT_DIR = TRUCK_DIR + "/sockets"
# Iguais ao TruckNode do jogo (LENGTH_DELTA e extra_mounts): onde ficam os escapamentos altos.
LENGTH_DELTA = {"base": 0.0, "leve": -2.8, "longo": 1.6, "carreta": 5.5, "canter": -4.6, "graneleira": 0.0}
# Caminhões de homenagem (T-218): cabine fixa (igual a TruckNode.FIXED_CAB) e carrocerias abertas (sem baú fechado).
FIXED = {"alubox": "flat_wide", "tarp": "flat_quad", "pinkbox": "flat_wide", "tanker": "flat_wide", "dump": "flat_quad"}
OPEN_BODIES = ("graneleira", "tarp", "tanker", "dump")


def parse_name(stem: str):
    """dekotora_truck_<bau>_<cabine> | dekotora_truck_canter | dekotora_truck_carreta -> (bau, cabine)."""
    rest = stem.replace("dekotora_truck_", "")
    if rest in ("canter", "carreta"):
        return rest, ("canter" if rest == "canter" else "carreta")
    if rest in FIXED:
        return rest, FIXED[rest]
    body, cab = rest.split("_", 1)
    return body, cab


def stacks(body: str, cab: str) -> list:
    d = LENGTH_DELTA.get(body, 0.0)
    p = (1.3, 8.3 + d, 0.9)
    if body == "canter":
        p = (1.25, 5.09, 0.75)
    elif cab == "curta":
        p = (1.4, 9.47 + d, 0.9)
    elif cab == "jac":
        p = (1.3, 9.15 + d, 0.9)
    g = [p[0], p[2], -p[1]]
    return [g, [-g[0], g[1], g[2]]]


def build_one(path: str) -> dict:
    stem = os.path.splitext(os.path.basename(path))[0]
    body, cab = parse_name(stem)
    data = TM.import_truck(path)
    m = TM.measure(data, body)
    m["open_body"] = body in OPEN_BODIES
    m["surf"] = TM.surfaces(m)                                  # T-214: teto e testa medidos por raios
    m["edges"] = TM.box_edges(data, m)                          # T-231: traseira, foguete e contorno do baú
    st = stacks(body, cab)
    sk = R.sockets(m, st)
    zones = R.protected_zones(m, cab, st)
    probs = R.check(sk, zones)
    probs += [f"{k}: {v['problem']}" for k, v in sk.items() if "problem" in v]
    out = {
        "model": stem, "body": body, "cab": cab, "version": 1,
        "units": "metros; Godot: x direita, y cima, frente = -z, traseira do bau em z = 0",
        "scale_limits": [R.SCALE_MIN, R.SCALE_MAX],
        "measure": {k: v for k, v in m.items() if k not in ("mounts", "surf", "edges")},
        "sockets": sk, "protected": zones, "design_problems": probs,
        "surfaces": stem + ".surf.json",
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, stem + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    # grades de apoio (T-214) num arquivo a parte, compacto (milhares de numeros)
    with open(os.path.join(OUT_DIR, stem + ".surf.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(m["surf"], f, ensure_ascii=False, separators=(",", ":"))
    c = m["cab"]
    an, vi = sk["andon"], sk["visor"]
    print(f"[sockets] {stem:34s} deque y {an['anchor'][1]:.3f} z {an['anchor'][2]:.3f} larg util {an['width']:.2f}"
          f" | viseira y {vi['anchor'][1]:.3f} z {vi['anchor'][2]:.3f} incl {vi.get('lean', 0):.3f}")
    print(f"[sockets] {stem:34s} cabine larg {2 * c['half_w']:.2f} teto y {c['roof_y']:.2f} z {c['roof_front_z']:.2f}..{c['roof_back_z']:.2f}"
          f" para-brisa topo {c['windshield'][1][1]:.2f} viseira z {c['visor_back_z']:.2f} | {len(sk)} encaixes, {len(zones)} zonas,"
          f" {len(probs)} problemas")
    rb = sk.get("rear_bumper", {})
    txt = f"para-choque tras larg {rb.get('width', 0):.2f} topo {rb.get('anchor', [0, 0])[1]:.2f} z {rb.get('anchor', [0, 0, 0])[2]:.2f}"
    for k in ("rocket_r", "rocket_l"):
        if k in sk:
            txt += f" | {k} faixa {sk[k]['band']:.2f} compr {sk[k]['length']:.2f}"
    for k in ("box_light_r", "box_light_l", "box_light_top"):
        if k in sk:
            tot = sum(sum((g["b"][i] - g["a"][i]) ** 2 for i in range(3)) ** 0.5 for g in sk[k]["strips"])
            txt += f" | {k} {len(sk[k]['strips'])} trechos {tot:.1f} m"
    print(f"[sockets] {stem:34s} {txt}")
    for p in probs:
        print("   PROBLEMA:", p)
    return out


def _box_obj(name, b, mat):
    (x0, y0, z0), (x1, y1, z1) = b
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = ((x1 - x0), (z1 - z0), (y1 - y0))                     # Godot -> Blender: (x, -z, y)
    o.location = ((x0 + x1) / 2, -(z0 + z1) / 2, (y0 + y1) / 2)
    o.data.materials.append(mat)
    return o


def _mat(name, rgba):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = rgba
    em.inputs["Strength"].default_value = 1.0
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = rgba[3]
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    return m


def preview(path: str, data: dict, out_dir: str) -> list:
    """Caminhão + caixas: frente 3/4 e lado. Azul = encaixe; vermelho = zona protegida."""
    from lib import preview as P
    TM.import_truck(path)
    blue, red = _mat("sock", (0.1, 0.5, 1.0, 0.35)), _mat("zone", (1.0, 0.1, 0.1, 0.30))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    for k, v in data["sockets"].items():
        for i, b in enumerate(R.boxes_of(v)):
            if v.get("fit") != "face":
                objs.append(_box_obj(f"S_{k}_{i}", b, blue))
    for k, v in data["protected"].items():
        objs.append(_box_obj("Z_" + k, v["box"], red))
    c = data["measure"]["cab"]
    cz = -(c["front_z"] + 1.6)
    views = {"frente34": (28, 14, 9.0, (0.0, cz, 2.0)), "lado": (90, 4, 9.5, (0.0, cz + 1.0, 1.7)),
             "topo": (8, 55, 8.0, (0.0, cz + 0.6, 2.6))}
    prefix = os.path.join(out_dir, data["model"])
    P.render_views(prefix, objs, size=(800, 520), views=views)
    return [f"{prefix}_{v}.png" for v in views]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="lista de modelos sem o prefixo, ex.: base_chata,canter")
    ap.add_argument("--preview", default="", help="pasta ABSOLUTA para as imagens de conferência")
    args = ap.parse_args(argv)
    files = sorted(glob.glob(os.path.join(TRUCK_DIR, "dekotora_truck_*.glb")))
    if args.only:
        want = {"dekotora_truck_" + s for s in args.only.split(",")}
        files = [f for f in files if os.path.splitext(os.path.basename(f))[0] in want]
    bad = 0
    sheets = []
    for f in files:
        d = build_one(f)
        if d["design_problems"] and d["body"] != "carreta":     # a carreta está guardada (não jogável): só avisa
            bad += 1
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            sheets += preview(f, d, args.preview)
    if args.preview and sheets:
        from lib import preview as P
        P.contact_sheet(sheets, os.path.join(args.preview, "sockets_sheet.png"), cols=3)
    if bad:
        raise SystemExit(f"ERRO: {bad} caminhao(oes) com problemas de projeto nos encaixes")
    print(f"OK build_sockets: {len(files)} caminhoes")


main()
