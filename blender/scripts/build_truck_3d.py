"""Caminhão 3D (PBR) para o Godot: chassi, baú e decoração NOSSOS + cabine vinda de modelo de arquivo (T-129).

Uso: blender -b --factory-startup -P blender/scripts/build_truck_3d.py -- [--out game/assets/vehicles/dekotora]
     [--variant base|leve|longo|carreta|canter] [--cab chata|jac|curta|americana] [--cab-src CAMINHO]
     [--box auto|premium|classic]
Saída: <out>/truck/dekotora_truck_<baú>_<cabine>.glb (a carreta e o Canter não têm sufixo), <out>/source_blend/,
<out>/previews/truck_<tag>_*.png

Cabines (todas de modelos de terceiros Royalty Free, marca apagada, materiais NOSSOS; créditos em game/assets/LICENCAS.md):
  chata     International CF500 (T-119, `cab_chata.py`), cara chata com dormitório: a padrão dos perfis novos;
  jac       JAC 1045 em escala 0,95 x 0,88 (T-129, `jac_cab.py`): cabine japonesa grande, escapamentos atrás dela;
  curta     JAC 1045 em escala 0,84 (T-125): cabine baixa, o baú cresce até as costas dela;
  americana Kenworth W990 (T-129, `kw_cab.py`): cabine "dia" de bico longo, eixo dianteiro mais à frente.
As 4 cabines feitas por código (padrao, classica, aero, alta) foram retiradas na T-129.

Baú premium (T-136, `truck3d/box_premium.py`): chapa ondulada de verdade, trilhos, montantes, portas com mapas de
normal/oclusão gravados da versão alta (`bake_box_premium.py`, rode antes uma vez) e ferragens reais. `--box auto`
(padrão) = premium no baú médio (base) e o baú antigo nos outros modelos; `premium`/`classic` forçam.

Convenções: metros, +Y frente, Z cima, traseira do baú em Y=0, X=0 no centro. As peças usam os pontos
de montagem (empties MOUNT_*) criados aqui; o glTF os exporta como nós.
"""
import argparse
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, pbr, preview, scene, shared_tex  # noqa: E402
from truck3d.body import BoxDims, build_body  # noqa: E402
from truck3d.box_premium import build_box_premium  # noqa: E402
from truck3d.chassis import build_chassis  # noqa: E402
from truck3d.deco import build_deco  # noqa: E402
from truck3d.cab_chata import build_cab_chata  # noqa: E402
from truck3d import canter as canter_mod, jac_cab, jac_src, kw_cab  # noqa: E402
from mathutils import Vector  # noqa: E402
from truck3d.dims import BODY_L, CAB_Y1, FRONT_AXLE_Y, MOUNTS, WHEEL_R  # noqa: E402
from truck3d.variants import LENGTH_DELTA, VARIANTS, apply_variant  # noqa: E402
from truck3d.wheels import make_wheel, tire_profile  # noqa: E402

CABS = ("chata", "jac", "curta", "americana")
DEFAULT_CAB = "chata"
FRONT_AXLE_PARTS = ("axle_f", "leaf_", "kingpin_", "drag_link")     # peças do eixo dianteiro do chassi (chassis.py)
STACK_Y = 8.3                                                         # escapamentos do chassi (chassis.py)


def build_canter(m: dict, jac_src_path=None):
    """Caminhão base Canter (T-125): cabine/chassi do JAC 1045 + baú e rodas nossos. Devolve como build_truck."""
    parts = []

    def add(o):
        parts.append(o)
        return o
    info = canter_mod.build_canter(m, add, jac_src_path)
    empties = []
    for n, (p, sc) in sorted(info.mounts.items()):
        e = M.empty(n, p)
        e.scale = (sc, sc, sc)                     # peças do caminhão grande encolhem junto (cabine 2,1 m)
        empties.append(e)
    return parts, info.wheels, empties


def _extend_box(parts, body_names, front, ext):
    """O baú cresce para a frente até perto das costas da cabine (curta, jac): mesmo comprimento total."""
    for o in parts:
        if o.name not in body_names or o.name.startswith("underglow"):     # neon do chassi fica onde está
            continue
        M.apply_transforms([o])
        ys = [v.co.y for v in o.data.vertices]
        lo, hi = min(ys), max(ys)
        if hi - lo > 2.6:
            for v in o.data.vertices:
                if v.co.y > front - 0.5:
                    v.co.y += ext
        elif (lo + hi) / 2 > front - 0.5:
            for v in o.data.vertices:
                v.co.y += ext
        o.data.update()


def build_file_cab(m, add, cab: str, src=None):
    """Monta a cabine de arquivo e devolve as medidas que o caminhão usa. Campos comuns: top, wz0, surf(x, z),
    mounts, tris; e mais: gap (None = baú no lugar; senão o baú cresce até `gap` das costas `y_back`),
    stacks ("keep" | "move" | "drop": escapamentos do chassi), front_axle/front_r (eixo e roda dianteira)."""
    if cab == "chata":
        info = build_cab_chata(m, add, src)
        info.gap, info.stacks = None, "keep"
    elif cab == "curta":
        info = jac_cab.build_jac(m, add, jac_src.CURTA, ("cab",), src)
        info.gap, info.stacks = canter_mod.GAP, "drop"            # sem escapamentos (o baú ocupa o lugar)
    elif cab == "jac":
        info = jac_cab.build_jac(m, add, jac_src.JAC, ("cab",), src)
        info.gap, info.stacks, info.front_r = 0.6, "move", 0.55   # vão com os escapamentos; o arco do JAC pede roda maior
    elif cab == "americana":
        info = kw_cab.build_kw(m, add, src)
        info.gap, info.stacks = None, "keep"                     # costas em CAB_Y0: o baú fica onde está
    else:
        raise SystemExit(f"ERRO: cabine desconhecida: {cab} (use {', '.join(CABS)})")
    info.front_axle = getattr(info, "front_axle", FRONT_AXLE_Y)
    info.front_r = getattr(info, "front_r", 0.5)
    return info


def _front_wheel_mounts(mounts, info):
    """Pontos das calotas/rodas dianteiras seguem o eixo e o raio da cabine (bico longo, roda maior)."""
    for n in ("MOUNT_WHEEL_FRONT_R", "MOUNT_WHEEL_FRONT_FACE_R"):
        x = abs(mounts[n][0]) + (0.03 if "FACE" in n and info.front_r > 0.52 else 0.0)
        mounts[n] = (x, info.front_axle, info.front_r)
        mounts[n[:-1] + "L"] = (-x, info.front_axle, info.front_r)


PREMIUM_VARIANTS = ("base",)                                          # piloto T-136: só o baú médio


def use_premium(box: str, variant: str) -> bool:
    if box == "auto":
        return variant in PREMIUM_VARIANTS
    if box == "premium" and variant in ("canter", "carreta"):
        raise SystemExit("ERRO: o baú premium ainda não existe para canter/carreta (use --box classic)")
    return box == "premium"


def build_truck(m: dict, paint_name: str = "paint_white", variant: str = "base", cab: str = DEFAULT_CAB, cab_src=None,
                premium: bool = False):
    """Devolve (meshes_estaticas, rodas, empties). `m` = dicionário de materiais (pbr.standard_set; com
    `premium`, também pbr.box_premium_set)."""
    if paint_name != "paint_white":
        m = dict(m)
        m["paint_white"] = m[paint_name]
    if variant == "canter":
        return build_canter(m, cab_src)
    parts = []
    wheels = []

    def add(o):
        parts.append(o)
        return o

    spec = VARIANTS[variant]
    build_chassis(m, add, spec["rear_axles"], spec["tanks"])
    n0 = len(parts)
    build_body(m, add, shell=not premium)
    body_names = {o.name for o in parts[n0:]}
    info = build_file_cab(m, add, cab, cab_src)
    stacks = [o for o in parts if o.name.startswith("stack_")]
    if info.stacks == "drop":
        for o in stacks:
            parts.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
        body_names |= {o.name for o in parts if o.name == "cab_back_gap"}
    elif info.stacks == "move":                    # escapamentos logo atrás das costas da cabine (jac)
        for o in stacks + [o for o in parts if o.name == "cab_back_gap"]:
            o.location.y += info.y_back - 0.3 - STACK_Y
    dy_axle = info.front_axle - FRONT_AXLE_Y
    if abs(dy_axle) > 1e-4:                        # bico longo: eixo dianteiro mais à frente (americana)
        for o in parts:
            if o.name.startswith(FRONT_AXLE_PARTS):
                o.location.y += dy_axle
    for sx in (-1, 1):
        side = "L" if sx < 0 else "R"
        for y in spec["rear_axles"]:
            for tx in (0.72, 1.06):
                wheels.append(make_wheel(f"wheel_r_{side}_{y}_{tx}", (sx * tx, y, WHEEL_R), m, rim=(tx > 1.0), seg=spec["seg"]))
        wheels.append(make_wheel(f"wheel_f_{side}", (sx * 1.0, info.front_axle, info.front_r), m, rim=True, radius=info.front_r))
    mounts = dict(MOUNTS)
    mounts.update(info.mounts)                     # frente, teto, degraus e lateral mudam com a cabine
    _front_wheel_mounts(mounts, info)
    empties = [M.empty(n, p) for n, p in mounts.items()]
    apply_variant(variant, m, parts, wheels, empties)
    dy = VARIANTS[variant]["delta"]
    ext = 0.0
    if info.gap is not None:
        front = BODY_L + dy
        ext = round(info.y_back + dy - info.gap - front, 2)
        _extend_box(parts, body_names, front, ext)
        bpy.context.view_layer.update()            # matrix_world volta a valer depois de aplicar as transformações
        for e in empties:
            if e.name == "MOUNT_BODY_ROOF":
                e.location.y = (front + ext) / 2
    if premium:                                     # baú premium no comprimento final (cabines curta/jac esticam)
        build_box_premium(m, add, BoxDims(l=round(BODY_L + dy + ext, 3)))
    if variant != "carreta":                        # decoracao Dekotora (V7): luzes, andons, murais
        body_l = BODY_L + dy + ext
        cab_z = info.top                            # altura real da cabine (com defletor de teto, se houver)
        for o in parts:
            mw = o.matrix_world
            for v in o.data.vertices:
                w = mw @ v.co
                if w.y > body_l + 0.3 and w.z > cab_z:
                    cab_z = w.z

        def surf(x, z):                                # ponto/normal na casca (fileira de luzes da "sobrancelha")
            p, n = info.surf(x, z)
            return p + Vector((0, dy, 0)), n
        build_deco(m, add, body_l, cab_z, (CAB_Y1 + dy, info.wz0, surf), mural_plates=not premium,
                   rear_y=-0.17 if premium else -0.11)
    print(f"cabine {cab}: {info.tris} triangulos; bau {ext:+.2f} m{' (premium)' if premium else ''}; eixo dianteiro y={info.front_axle + dy:.2f} r={info.front_r}")
    return parts, wheels, empties


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/vehicles/dekotora")
    ap.add_argument("--paint", default="paint_white")
    ap.add_argument("--cab", default=DEFAULT_CAB, choices=list(CABS), help="chata | jac | curta | americana")
    ap.add_argument("--cab-src", default=None, help="malha de terceiros: STL da chata (docs/Novos modelos/Cabine/CF_500_complete.stl), "
                    ".blend do JAC 1045 para jac/curta/canter (docs/Modelos Melhorados/JAC+1045+Truck.blend) ou "
                    ".glb do Kenworth W990 para americana (docs/Modelos Melhorados/kenworth_w990_truck.glb)")
    ap.add_argument("--no-preview", action="store_true")
    ap.add_argument("--box", default="auto", choices=("auto", "premium", "classic"),
                    help="auto = premium no baú médio (base), antigo nos outros; premium | classic forçam (T-136)")
    ap.add_argument("--night", action="store_true", help="previas de revisao a noite (luzes acesas)")
    ap.add_argument("--variant", default="base", choices=list(VARIANTS) + ["canter"], help="base | leve | longo | carreta | canter (cabine do JAC)")
    args = ap.parse_args(argv)
    if args.variant == "carreta":
        args.cab = "chata"                           # carreta guardada (fora da garagem): cavalo com a cara chata
    out = os.path.abspath(args.out)
    scene.reset_scene()
    m = pbr.truck_set(pbr.standard_set())
    m["rubber_tire"] = pbr.tire_material(tire_profile(WHEEL_R, 0.3), WHEEL_R)
    premium = use_premium(args.box, args.variant)
    if premium:
        pbr.box_premium_set(m, os.path.join(out, "textures"))
    parts, wheels, empties = build_truck(m, args.paint, args.variant, args.cab, args.cab_src, premium)
    for o in parts:                                  # texturas precisam de UV que cubra cada face
        name = o.active_material.name if o.active_material else ""
        if name in ("paint_white_panel", "plastic_trim"):
            M.uv_height(o)                           # sujeira por altura (lib/tex_truck.py)
        elif name == "diamond":
            M.uv_world(o, 0.45)
        elif name in ("mesh_perf", "mesh_perf_vent", "mesh_perf_grille") and not o.get("has_uv"):
            M.uv_planar(o)
    all_meshes = parts + [w for ws in wheels for w in ws]
    M.smooth(all_meshes, 35.0)
    tris = M.count_tris(all_meshes)
    # junta por material (poucos draw calls); cada roda vira um objeto para poder girar
    merged = M.join_by_material(parts, prefix="truck_")
    wheel_objs = []
    for ws in wheels:
        bpy.ops.object.select_all(action="DESELECT")
        for o in ws:
            o.select_set(True)
        bpy.context.view_layer.objects.active = ws[0]
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        base = o.name.replace("_tire", "")      # a origem já é o centro do pneu (eixo X)
        o.name = base
        o.data.name = base
        wheel_objs.append(o)
    root = bpy.data.objects.new("DekotoraTruckBase", None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged + wheel_objs + empties:
        o.parent = root
    final = [root] + merged + wheel_objs + empties
    print(f"triangulos: {tris}  objetos: {len(final)}  materiais: {len(bpy.data.materials)}")
    tag = args.variant if args.variant in ("canter", "carreta") else f"{args.variant}_{args.cab}"
    glb = os.path.join(out, "truck", f"dekotora_truck_{tag}.glb")
    mural_png = os.path.join(out, "murals", "mural_side.png")      # arte trocavel do mural (nunca sobrescreve)
    if not os.path.exists(mural_png):
        from lib import tex
        tex.save_png(tex.mural_geometric()[::-1], mural_png)
    # texturas grandes: uma cópia só em <out>/textures (o TruckNode aplica no jogo); o .glb leva miniaturas 4x4
    mats = {sl.material for o in final if o.type == "MESH" for sl in o.material_slots if sl.material}
    swaps = shared_tex.externalize(sorted(mats, key=lambda mt: mt.name), os.path.join(out, "textures"))
    M.export_glb(glb, final)
    shared_tex.restore(swaps)
    os.makedirs(os.path.join(out, "source_blend"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "source_blend", f"truck_{tag}.blend"))
    if args.no_preview:
        print("OK build_truck_3d ->", glb)
        return
    d = canter_mod.LENGTH - 11.5 if args.variant == "canter" else LENGTH_DELTA[args.variant]
    pdir = os.path.join(out, "previews")
    preview.render_views(os.path.join(pdir, f"truck_{tag}" + ("_night" if args.night else "")), merged + wheel_objs, size=(960, 540), night=args.night,
                         views={"34": (35, 14, 22.0 + d * 1.1, (0, 6.0 + d / 2, 1.6)), "rear": (180, 8, 22.0 + d, (0, 6.0 + d / 2, 1.6)),
                                "side": (90, 4, 22.0 + d * 1.1, (0, 6.0 + d / 2, 1.6)), "front": (0, 10, 22.0 + d, (0, 6.0 + d / 2, 1.6)),
                                "cab34": (38, 10, 9.0, (0, 10.0 + d, 1.8)), "cabside": (90, 3, 9.0, (0, 10.0 + d, 1.8)),
                                "wheel": (55, 6, 3.2, (1.0, 10.2 + d, 0.5)), "grille": (15, 8, 3.5, (0, 11.5 + d, 1.1)),
                                "cabfront": (8, 6, 7.5, (0, 11.0 + d, 1.9)), "cabrear34": (140, 14, 9.0, (0, 9.5 + d, 2.0)),
                                "door": (75, 4, 4.2, (1.2, 10.0 + d, 1.8))})
    pre = os.path.join(pdir, f"truck_{tag}" + ("_night" if args.night else ""))
    preview.contact_sheet([f"{pre}_{v}.png" for v in ("cabfront", "cab34", "cabside", "34", "front", "side", "cabrear34", "door", "grille")],
                          f"{pre}_sheet.png", cols=3)
    print("OK build_truck_3d ->", glb)


if __name__ == "__main__":
    main()
