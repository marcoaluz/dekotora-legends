"""Peças tiradas de modelos de terceiros (T-126), todos Royalty Free (confirmado pelo Marco em 2026-10-18):
Kenworth W990 (Sketchfab, Henry S), Fumi SC (Sketchfab, T3STAR) e JAC 1045 (CGTrader). Os arquivos originais ficam em
`docs/Modelos Melhorados/` (fora do Git); aqui só copiamos ILHAS de malha escolhidas por caixas (`lib/extract.py`),
trocamos os materiais pelos NOSSOS, apagamos letreiros/emblemas (ilhas pequenas ou caixas de exclusão), reduzimos e
levamos para a convenção dos acessórios (origem = ponto de montagem, +Y frente, +X para fora no lado direito, metros).

O Kenworth olha para -Y: `rot_z_deg=180` vira a frente para +Y (e o lado esquerdo dele vira o nosso direito).
Para gerar: blender -b --factory-startup -P blender/scripts/build_accessories.py -- --only kw_exhaust_stacks,...
(ou `-- --thirdparty` para todas). Sem os arquivos originais o build para com uma mensagem clara.
"""
from __future__ import annotations

import os

import bpy

from lib import extract

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "docs", "Modelos Melhorados"))
KW = os.path.join(ROOT, "kenworth_w990_truck.glb")
FUMI = os.path.join(ROOT, "2025_fumi_sc.glb")
JAC = os.path.join(ROOT, "JAC+1045+Truck.blend")

KW_MATS = {"chrome": "chrome", "chrome_bumpB": "chrome", "chromedark": "steel", "metal_black": "plastic",
           "plastic_rough_black": "plastic", "plastic_shiny_black": "plastic", "glass_orange": "lamp_amber",
           "glass_orange_bumpA": "lamp_amber", "glass_red": "lamp_red", "light_white": "lamp_white",
           "carpaint-black_piano": "paint_white"}
CHROMES = ["chrome", "steel", "paint_gold"]


def _need(path):
    if not os.path.isfile(path):
        raise SystemExit(f"ERRO peca de terceiros: arquivo nao encontrado: {path}\n"
                         "  Os modelos originais ficam em docs/Modelos Melhorados/ (fora do Git; baixados pelo Marco).")


def _finish(m, objs, budget):
    """Redução por ilha (as peças simples ficam inteiras) e material nosso."""
    objs = extract.decimate_islands(objs, budget)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(m[o["our_mat"]])
    return objs


def _snapshot():
    return {"im": set(bpy.data.images), "mt": set(bpy.data.materials), "me": set(bpy.data.meshes)}


def _purge(before, keep_meshes=()):
    """Apaga malhas, materiais e TEXTURAS que vieram do original (o .blend salvo não leva nada do arquivo de terceiros)."""
    keep = {o.data for o in keep_meshes}
    for me in [x for x in bpy.data.meshes if x not in before["me"] and x not in keep and x.users == 0]:
        bpy.data.meshes.remove(me)
    for mt in [x for x in bpy.data.materials if x not in before["mt"]]:
        bpy.data.materials.remove(mt)
    for im in [x for x in bpy.data.images if x not in before["im"]]:
        bpy.data.images.remove(im)


def _from_glb(path, boxes, mats, origin, scale=1.0, rot=0.0, budget=3000, max_size=99.0, min_size=0.0, exclude=(),
              keep_box=None, objects=None, mat_override=None):
    def build(m):
        _need(path)
        before = set(bpy.data.objects)
        snap = _snapshot()
        src = extract.load_glb(path)
        objs = extract.take(src, boxes, mats, "src", max_size=max_size, min_size=min_size, exclude=exclude, objects=objects)
        for o in [o for o in bpy.data.objects if o not in before and o not in objs]:
            bpy.data.objects.remove(o, do_unlink=True)
        for o in objs:
            o.data.materials.clear()
        _purge(snap, objs)
        extract.place(objs, origin, scale=scale, rot_z_deg=rot)
        if keep_box:
            extract.clip(objs, *keep_box)
        objs = [o for o in objs if len(o.data.polygons) > 0]
        if mat_override:
            for o in objs:
                o["our_mat"] = mat_override.get(o["our_mat"], o["our_mat"])
        return _finish(m, objs, budget)
    return build


def _squash_x(objs, k):
    """Achata em X (lado de fora = x 0): o prato fundo da roda vira uma calota que não entra no pneu."""
    for o in objs:
        for v in o.data.vertices:
            v.co.x *= k
        o.data.update()


def _from_jac(parts: dict, origin, scale=1.0, budget=2000, keep_box=None, squash_x=1.0):
    """Peças do JAC pelo NOME (`jac_src`, quadro do Canter): {nome: material nosso}."""
    def build(m):
        from truck3d import jac_src
        _need(JAC)
        snap = _snapshot()
        objs = list(jac_src.load(jac_src.CANTER, JAC, keep=lambda n: n in parts).items())
        out = []
        for name, o in objs:
            o["our_mat"] = parts[name]
            out.append(o)
        extract.place(out, origin, scale=scale)
        if squash_x != 1.0:
            _squash_x(out, squash_x)
        if keep_box:
            extract.clip(out, *keep_box)
        out = [o for o in out if len(o.data.polygons) > 0]
        _purge(snap, out)
        return _finish(m, out, budget)
    return build


# ---------------------------------------------------------------- Kenworth W990 (frente em -Y no original)

kw_exhaust_stacks = _from_glb(
    KW, [((-1.45, 0.95, 0.6), (-0.3, 1.55, 4.0))], {**KW_MATS, "carpaint-black_piano": None},
    origin=(-1.09, 1.2, 0.9), rot=180.0, budget=2600, min_size=0.12,
    keep_box=((-0.15, -0.2, -0.3), (0.4, 0.2, 3.2)))

kw_fuel_tank = _from_glb(
    KW, [((-1.2, 1.25, 0.4), (-0.45, 2.95, 1.1))], KW_MATS, origin=(-1.14, 1.48, 0.45), rot=180.0, budget=2200,
    max_size=1.7, min_size=0.05)

kw_visor = _from_glb(
    KW, [((-1.2, -0.15, 2.55), (1.2, 0.5, 2.95))], {**KW_MATS, "carpaint-black_piano": None},
    origin=(0.0, 0.38, 2.64), rot=180.0, budget=2400, min_size=0.03, objects=None)

kw_bumper = _from_glb(
    KW, [((-1.3, -2.15, 0.2), (1.3, -1.9, 0.85))], KW_MATS, origin=(0.0, -1.93, 0.49), rot=180.0, budget=2400,
    min_size=0.5)

kw_grille = _from_glb(
    KW, [((-0.7, -2.1, 0.75), (0.7, -1.8, 2.0))], KW_MATS, origin=(0.0, -1.92, 1.38), rot=180.0, budget=3600,
    min_size=0.25, exclude=[((-0.3, -2.1, 1.62), (0.3, -1.8, 2.05))])

kw_steps = _from_glb(
    KW, [((-1.3, 0.0, 0.3), (-0.7, 1.35, 1.05))], KW_MATS, origin=(-1.12, 0.03, 0.72), rot=180.0, scale=0.7, budget=1600,
    min_size=0.05)

# ---------------------------------------------------------------- Fumi SC (frente em -Y no original, y = 0 no para-choque)

fumi_wing = _from_glb(
    FUMI, [((-0.9, 4.0, 1.0), (0.9, 4.6, 1.3))], {"material": "paint_white", "material_4": "plastic"},
    origin=(0.0, 4.31, 1.05), rot=180.0, scale=1.45, budget=1400, objects=["hood.wing_p2_0"])

fumi_sport_rims = _from_glb(
    FUMI, [((0.7, 0.4, 0.0), (1.2, 1.2, 0.8))], {"UCB_BOTTOM": "plastic"},
    origin=(1.02, 0.82, 0.38), rot=0.0, scale=1.22, budget=4000, min_size=0.3, objects=["wheel.tire.002_UCB_BOTTOM_0"],
    keep_box=((-0.07, -0.5, -0.5), (0.05, 0.5, 0.5)), mat_override={"plastic": "paint_gold"})

# ---------------------------------------------------------------- JAC 1045 (quadro do Canter: frente +Y, metros)

jac_steel_rims = _from_jac(
    {"Llantas_delantera_derecha.001": "chrome", "Llantas_delantera_derecha": "steel"},
    origin=(1.17, 5.73, 0.45), scale=1.29, budget=3500, squash_x=0.2)

jac_toolbox = _from_jac(
    {"Tanque_y_caja.001": "steel", "Tanque_y_caja": "chrome"},
    origin=(0.92, 4.64, 0.3), scale=1.1, budget=900, keep_box=((-0.8, -1.6, -0.2), (0.2, 0.2, 1.0)))


# pontos de montagem que os .glb do caminhão ainda não têm (o TruckNode cria no jogo; ver EXTRA_MOUNTS lá)
EXTRA_MOUNTS = {"MOUNT_STACK_R": (1.3, 8.3, 0.9), "MOUNT_STACK_L": (-1.3, 8.3, 0.9)}

LIC = {"kw": "Kenworth W990 Truck (Sketchfab, Henry S), Royalty Free/Sketchfab Standard; reduzida, sem marca",
       "fumi": "2025 Fumi SC (Sketchfab, T3STAR), Royalty Free/Sketchfab Standard; reduzida, sem marca",
       "jac": "JAC 1045 Truck (CGTrader), Royalty Free; reduzida, sem marca"}

ACCESSORIES = [
    dict(id="kw_exhaust_stacks", name="Escapamentos altos cromados", category="sides", mount="MOUNT_STACK_R", mirror=True,
         build=kw_exhaust_stacks, materials={"main": CHROMES}, license=LIC["kw"]),
    dict(id="kw_fuel_tank", name="Tanque cromado americano", category="sides", mount="MOUNT_SIDE_BOX_R", mirror=True,
         build=kw_fuel_tank, materials={"main": CHROMES}, license=LIC["kw"]),
    dict(id="kw_steps", name="Degraus cromados", category="sides", mount="MOUNT_STEP_R", mirror=True,
         build=kw_steps, materials={"main": CHROMES}, license=LIC["kw"]),
    dict(id="kw_visor", name="Para-sol cromado com lanternas", category="front", mount="MOUNT_VISOR", mirror=False,
         build=kw_visor, materials={"main": CHROMES}, license=LIC["kw"]),
    dict(id="kw_bumper", name="Para-choque americano", category="front", mount="MOUNT_FRONT_BUMPER", mirror=False,
         build=kw_bumper, materials={"main": CHROMES}, license=LIC["kw"]),
    dict(id="kw_grille", name="Grade cromada americana", category="front", mount="MOUNT_FRONT_GRILLE", mirror=False,
         build=kw_grille, materials={"main": CHROMES}, license=LIC["kw"]),
    dict(id="fumi_wing", name="Aerofólio de teto", category="lighting", mount="MOUNT_ROOF", mirror=False,
         build=fumi_wing, materials={"main": ["paint_white", "chrome", "paint_gold"]}, license=LIC["fumi"]),
    dict(id="fumi_sport_rims", name="Rodas esportivas", category="sides", mount="MOUNT_WHEEL_FRONT_FACE_R", mirror=True,
         build=fumi_sport_rims, materials={"main": ["paint_gold", "chrome", "plastic"]}, license=LIC["fumi"]),
    dict(id="jac_steel_rims", name="Rodas de aço cromadas", category="sides", mount="MOUNT_WHEEL_FRONT_FACE_R", mirror=True,
         build=jac_steel_rims, materials={"main": CHROMES}, license=LIC["jac"]),
    dict(id="jac_toolbox", name="Caixa de ferramentas", category="sides", mount="MOUNT_SIDE_BOX_R", mirror=True,
         build=jac_toolbox, materials={"main": CHROMES}, license=LIC["jac"]),
]
