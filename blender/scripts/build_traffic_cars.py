"""Carros de trânsito a partir de modelos de terceiros (T-124): Ascona, Falcon, SUV, Fumi SC e ônibus Jetset;
(T-143) viatura de polícia (Camry, padrão japonês fictício, barra de luzes "beacon"), jipe (Samurai) e o carro
batido do acidente (picape amassada, parada: sem nós de roda).

Os originais ficam em docs/Modelos Melhorados/ (FORA do Git; licenças e autores em game/assets/LICENCAS.md).
Este script só LÊ os originais e grava o .glb final, reduzido e re-texturizado com cores lisas
(nenhuma textura/logotipo do autor vai para o jogo; emblemas soltos são apagados).

Uso:
  blender -b --factory-startup -P blender/scripts/build_traffic_cars.py -- --model all \
      [--src-dir "docs/Modelos Melhorados"] [--out game/assets/vehicles/traffic] [--preview <pasta absoluta>]
  --model: ascona | falcon | suv | fumi | bus | police | jeep | wreck | all
  (o jipe vem de docs/Novos modelos/ (--new-dir); o carro batido de docs/Novas Melhorias/ (--wreck-dir))

Saída: game/assets/vehicles/traffic/car_<modelo>.glb, cada um com:
  - "body": pintura "paint_white" (o Godot troca a cor) + atlas "<tag>_trim" (vidro, cromo, plástico, luzes);
  - "wheel_f" / "wheel_r": um objeto por eixo, pivô no centro do eixo (altura = raio);
  - frente para +Y, traseira em Y = 0, chão em Z = 0, escala real. Determinístico.
"""
import argparse
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, scene  # noqa: E402
from lib import traffic_classify as C  # noqa: E402
from lib import traffic_jeep as J  # noqa: E402
from lib import traffic_kit as K  # noqa: E402
from lib import traffic_police as PO  # noqa: E402
from lib import traffic_preview as P  # noqa: E402
from lib import traffic_wreck as WR  # noqa: E402


# ---------------------------------------------------------------- receitas por modelo
def prep_painted(spec, objs, dims, to_final):
    """Malha única com textura pintada (illustros): rodas = peças soltas dentro do cilindro de cada roda;
    interior (bancos, volante) e peças miúdas saem; cores pela textura."""
    L, W, H = dims
    o = K.join(objs, "body")      # sem soldar aqui: pneu e aro encostam no mesmo vértice e virariam uma peça só
    axles = []
    for y, z, r in spec["axles_src"]:
        p = to_final @ Vector((0.0, y, z))
        axles.append((p.y, p.z, r * spec["_scale"]))

    def is_wheel(P):
        if np.abs(P[:, 0]).min() < W * 0.5 * spec.get("wheel_inner", 0.45):
            return False
        return any(np.hypot(P[:, 1] - ya, P[:, 2] - za).max() <= r * 1.08 for ya, za, r in axles)

    def is_interior(P):
        lo, hi = P.min(0), P.max(0)
        return (np.abs(P[:, 0]).max() < W * 0.5 * 0.72 and lo[2] > H * 0.3 and lo[1] > L * 0.2 and hi[1] < L * 0.8)

    small, wheel = K.part_masks(o, keep_min=0.03, inside=is_wheel)
    _s2, inner = K.part_masks(o, inside=is_interior)
    inner &= ~wheel
    body_cls = C.classify_painted(o, dims, vinyl=spec.get("vinyl", False), grille=spec.get("grille"))
    wheel_cls = C.classify_by_value(o, "rubber", "rim_dark", "rim", lo=0.2, hi=0.5)
    K.assign_classes(o, [w if wm else b for b, w, wm in zip(body_cls, wheel_cls, wheel)])
    drop = small | inner
    keep = ~drop
    K.delete_faces(o, drop)
    wheels = K.split_faces(o, wheel[keep], "wheels")
    print(f"[{spec['tag']}] peças: rodas={int(wheel.sum())} faces, interior={int(inner.sum())}, miúdas={int(small.sum())}")
    return [o], [wheels]


def prep_suv(spec, objs, dims, _to_final):
    bodies, wheels = [], []
    for o in objs:
        lo, hi = M.bounds([o])
        if hi.z < 0.85 and (hi.y - lo.y) < 0.9 and "orher" in o.name:      # pneu + aro (um objeto por roda)
            K.assign_classes(o, C.classify_by_value(o, "rubber", "rim_dark", "rim", lo=0.12, hi=0.45))
            wheels.append(o)
        elif "_body" in o.name:
            K.assign_classes(o, C.classify_by_value(o, "plastic", K.PAINT, K.PAINT, lo=0.22))
            bodies.append(o)
        elif "_gl_" in o.name:
            K.assign_classes(o, C.classify_glass_lights(o, dims))
            bodies.append(o)
        else:
            K.assign_classes(o, C.classify_by_value(o, "plastic", "grey", "chrome", lo=0.1, hi=0.4))
            bodies.append(o)
    return bodies, wheels


FUMI_DROP = ("int.", "engine.", "eng.", "door.interior", "radio.", "light.climatelabels", "light.hazardlabel",
             "light.radioknob", "axle_", "car.frame", "frunk.underneath", "hood.underneath", "frunk.badge",
             "Circle.013_", "Circle.022_", "car_tvr_griffith:chassis_details_LOD2_UV1_Untitled_032_Defa.002",
             "car_tvr_griffith:wheelBR_rims_LOD2_UV1_Untitled_121_Default.001",     # volante
             "car_tvr_griffith:wheelBR_rims_LOD2_UV1_Untitled_121_Default.003")     # letreiro da traseira
FUMI_MAT = {"material": K.PAINT, "material_12": K.PAINT, "material.001": "lamp_amber", "glass": "glass",
            "windowthingy": "glass", "material_4": "grille", "black.001": "plastic", "chrome.001": "chrome",
            "UCB_BOTTOM": "under", "lights.001": None}


def prep_fumi(spec, objs, dims, _to_final):
    bodies, wheels = [], []
    for o in objs:
        mat = o.data.materials[0].name if o.data.materials else ""
        if o.name.startswith("wheel.tire.001"):
            K.assign_classes(o, ["rubber"] * len(o.data.polygons))
            wheels.append(o)
            continue
        if o.name.startswith("wheel.tire.002"):
            K.assign_classes(o, C.classify_by_value(o, "rim_dark", "rim_dark", "rim", hi=0.42))
            wheels.append(o)
            continue
        if o.name.startswith("light.frontDRLS"):
            cls = ["lamp_white"] * len(o.data.polygons)
        elif o.name.startswith("light.rearneons"):
            cls = ["lamp_red"] * len(o.data.polygons)
        elif mat == "lights":
            cls = C.classify_lights(o, dims)
        elif mat in ("trim", "chrome.006"):
            cls = C.classify_by_value(o, "plastic", "grey", "chrome", lo=0.15, hi=0.6)
        elif mat in FUMI_MAT and FUMI_MAT[mat]:
            cls = [FUMI_MAT[mat]] * len(o.data.polygons)
        else:
            cls = ["grey"] * len(o.data.polygons)
        if o.name.startswith("car.exhausts"):
            cls = ["chrome"] * len(o.data.polygons)
        K.assign_classes(o, cls)
        bodies.append(o)
    return bodies, wheels


BUS_DROP = ("Cube", "DASRBOARD", "dek", "kursi", "kursi_supir", "tangga", "slap")
BUS_CLS = {"BODI": K.PAINT, "ac.001": K.PAINT, "KACA": "glass", "LIS": "plastic", "PART_ITEM": "plastic",
           "slap": "plastic", "WIPPER": "plastic", "BAN": "rubber", "BAN_PELEK": "rim"}


def prep_bus(spec, objs, dims, _to_final):
    bodies, wheels = [], []
    for o in objs:
        if o.name == "LAMPU":
            K.assign_classes(o, C.classify_by_position(o, dims, "lamp_white", "lamp_red", "lamp_amber", 0.9, 0.08))
        else:
            K.assign_classes(o, [BUS_CLS[o.name]] * len(o.data.polygons))
        (wheels if o.name.startswith("BAN") else bodies).append(o)
    return bodies, wheels


SPECS = {
    # axles_src: (y, z, raio) de cada eixo no arquivo original (medidos; frente = -Y no original)
    "ascona": dict(src="stylized_opel_ascona.glb", rotz=180, length=4.32, prep=prep_painted, vinyl=True,
                   axles_src=[(-0.333, 0.0725, 0.0705), (0.246, 0.0725, 0.0705)], body_tris=4500, own_wheels=True,
                   grille=(0.40, 0.62, 0.6),
                   paint="#c8202f"),
    "falcon": dict(src="stylized_ford_falcon_gt_coupe.glb", rotz=180, length=4.45, prep=prep_painted,
                   axles_src=[(-0.3135, 0.0725, 0.072), (0.2725, 0.074, 0.072)], body_tris=4500, own_wheels=True,
                   grille=(0.40, 0.62, 0.6),
                   paint="#2c9a5a"),
    "suv": dict(src="carro/low_poly_vehicle_mini_pack_5.glb", rotz=180, length=4.45, prep=prep_suv,
                pick_x=(-0.45, 1.86), body_tris=3900, wheel_tris=800, paint="#aeb8c8"),
    "fumi": dict(src="2025_fumi_sc.glb", rotz=180, length=4.45, prep=prep_fumi, drop=FUMI_DROP,
                 body_tris=4700, wheel_tris=900, paint="#d29a2e", min_wheel_part=0.05),
    "bus": dict(src="BUS+JETSET.fbx", rotz=180, length=13.28, prep=prep_bus, drop=BUS_DROP,
                body_tris=7800, wheel_tris=1000, paint="#8a3fd0", min_wheel_part=0.08),
    # T-143: viatura (sem pintura trocável; atlas próprio preto/branco; barra de luzes à parte) e jipe
    "police": dict(src="nypd_toyota_camry_.blend", importer=PO.import_police, rotz=180, length=4.9, prep=PO.prep_police,
                   drop=PO.DROP, body_tris=6400, own_wheels=True, border_weight=PO.BORDER_WEIGHT, cells=PO.POLICE_CELLS, extra_tris={"beacon": 420},
                   paint="#ffffff"),
    "jeep": dict(src_new="Carro/obj/obj.obj", importer=J.import_jeep, rotz=0, length=4.0, prep=J.prep_jeep,
                 body_tris=4600, own_wheels=True, paint="#2c9a5a"),
    # T-143: carro batido (parado no acidente): rodas no corpo, só pintura + atlas
    "wreck": dict(src_wreck="Carro batido/model_download+(24).obj", importer=WR.import_wreck, rotz=-90, length=4.75,
                  prep=WR.prep_wreck, body_tris=6000, voxel=0.03, smooth=4, static=True, paint="#d8dce2"),
}


# ---------------------------------------------------------------- pipeline comum
def import_meshes(path):
    if path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def place_std(objs, rotz: float, length: float):
    """Gira (frente para +Y), escala pelo comprimento e põe traseira em Y=0, chão em Z=0, centro em X=0."""
    rot = Matrix.Rotation(math.radians(rotz), 4, "Z")
    K.place(objs, rot)
    lo, hi = M.bounds(objs)
    s = length / (hi.y - lo.y)
    lo, hi = lo * s, hi * s
    tr = Matrix.Translation((-(lo.x + hi.x) * 0.5, -lo.y, -lo.z))
    K.place(objs, tr @ Matrix.Scale(s, 4))
    lo, hi = M.bounds(objs)
    return (hi.y - lo.y, hi.x - lo.x, hi.z - lo.z), tr @ Matrix.Scale(s, 4) @ rot, s


def axle_pivot(w) -> tuple:
    """Centro do eixo pelas faces de pneu (bbox em Y/Z); X = 0."""
    cls = K.face_classes(w)
    co = np.zeros(len(w.data.vertices) * 3, np.float32)
    w.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    vids = sorted({v for p, c in zip(w.data.polygons, cls) if c == "rubber" for v in p.vertices}) or range(len(co))
    P = co[list(vids)]
    lo, hi = P.min(0), P.max(0)
    return (0.0, float(lo[1] + hi[1]) * 0.5, float(lo[2] + hi[2]) * 0.5)


def rubber_span(w) -> tuple:
    """(|x| máximo, |x| mínimo) das faces de pneu: face de fora e de dentro do pneu."""
    cls = K.face_classes(w)
    ctr = K.face_data(w)[0]
    ax = np.abs(ctr[np.array([c == "rubber" for c in cls])][:, 0])
    return float(ax.max()), float(ax.min())


def build(key: str, spec: dict, args) -> None:
    tag = key
    spec["tag"] = tag
    name = "car_" + key
    if "src_new" in spec:
        src = os.path.join(os.path.abspath(args.new_dir), spec["src_new"])
    elif "src_wreck" in spec:
        src = os.path.join(os.path.abspath(args.wreck_dir), spec["src_wreck"])
    else:
        src = os.path.join(os.path.abspath(args.src_dir), spec["src"])
    if not os.path.isfile(src):
        raise SystemExit(f"original não encontrado: {src} (fica fora do Git, ver LICENCAS.md)")
    scene.reset_scene()
    C._IMG_CACHE.clear()          # as imagens de cada modelo têm os mesmos nomes (Image_0...)
    objs = spec.get("importer", import_meshes)(src)
    K.unparent_apply(objs)
    drop = spec.get("drop", ())
    if "pick_x" in spec:
        a, b = spec["pick_x"]
        drop_objs = [o for o in objs if not (a <= sum(M.bounds([o])[k].x for k in (0, 1)) * 0.5 <= b)]
    else:
        drop_objs = [o for o in objs if o.name.startswith(drop) or o.name in drop]
    tris_src = M.count_tris(objs)
    for o in drop_objs:
        bpy.data.objects.remove(o, do_unlink=True)
    objs = sorted((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: o.name)
    dims, to_final, s = place_std(objs, spec["rotz"], spec["length"])
    spec["_scale"] = s
    bodies, wheels = spec["prep"](spec, objs, dims, to_final)

    body = K.join(bodies, "body")
    K.weld(body, 1e-5)
    K.decimate(body, spec["body_tris"], spec.get("border_weight", 0.0))
    if spec.get("static"):                     # parado (carro batido): sem rodas separadas
        imgs, uv = K.build_atlas(tag, spec.get("cells"))
        K.finalize(body, K.paint_material(), K.trim_material(tag, imgs), uv)
        path = K.export(name, body, [], args.out)
        print(f"[{tag}] origem={tris_src} tris, escala={s:.3f}")
        print(P.stats_line(tag, body, [], path))
        if args.preview:
            P.render_preview([body], os.path.abspath(args.preview), tag, spec["paint"])
        return
    wall = K.join(wheels, "wheel_r")
    K.weld(wall, 1e-5)
    if spec.get("min_wheel_part"):
        small, _ = K.part_masks(wall, keep_min=spec["min_wheel_part"])
        K.delete_faces(wall, small)
    ctr = K.face_data(wall)[0]
    wf = K.split_faces(wall, ctr[:, 1] > dims[0] * 0.5, "wheel_f")
    wr = wall
    if spec.get("own_wheels"):
        # rodas nossas (redondas, 16 lados) no lugar exato das originais: as do autor ficam "estreladas" na redução
        made = []
        for w in (wf, wr):
            nm = w.name
            pv = axle_pivot(w)
            x_out, x_in = rubber_span(w)
            bpy.data.objects.remove(w, do_unlink=True)
            made.append(K.make_wheel_axle(nm, pv[1], pv[2], x_out, min(max(x_out - x_in, 0.15), 0.3)))
        wf, wr = made
    else:
        for w in (wf, wr):
            K.decimate(w, spec["wheel_tris"] // 2)
            K.set_pivot(w, axle_pivot(w))

    extras = []
    for ename, eobjs in spec.get("_extras", {}).items():      # T-143: barra de luzes da viatura ("beacon")
        e = K.join(eobjs, ename)
        K.weld(e, 1e-5)
        K.decimate(e, spec["extra_tris"][ename])
        PO.finalize_beacon(e, PO.beacon_material(tag))
        extras.append(e)

    imgs, uv = K.build_atlas(tag, spec.get("cells"))
    m_trim = K.trim_material(tag, imgs)
    m_paint = K.paint_material()
    for o in (body, wf, wr):
        K.finalize(o, m_paint, m_trim, uv)
    path = K.export(name, body, [wf, wr] + extras, args.out)
    print(f"[{tag}] origem={tris_src} tris, escala={s:.3f}")
    print(P.stats_line(tag, body, [wf, wr] + extras, path))
    if args.preview:
        P.render_preview([body, wf, wr] + extras, os.path.abspath(args.preview), tag, spec["paint"])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="all")
    ap.add_argument("--src-dir", default="docs/Modelos Melhorados")
    ap.add_argument("--new-dir", default="docs/Novos modelos")
    ap.add_argument("--wreck-dir", default="docs/Novas Melhorias")
    ap.add_argument("--out", default="game/assets/vehicles/traffic")
    ap.add_argument("--preview", default="", help="pasta ABSOLUTA para os renders de conferência (opcional)")
    args = ap.parse_args(argv)
    keys = list(SPECS) if args.model == "all" else args.model.split(",")
    for k in keys:
        build(k, dict(SPECS[k]), args)
    print("OK build_traffic_cars", keys)


main()
