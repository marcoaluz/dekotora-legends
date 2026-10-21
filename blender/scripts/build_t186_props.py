"""T-186: o 2o poste de luz e a pessoa, tirados dos pacotes do Marco em docs/Modelos (pasta FORA do Git).

  lamp   docs/Modelos/Road_pontes/Ponte/bridge_model.FBX, bloco "Block:den" (poste de luz da ponte, 9,4 m, braco
         de 1,9 m, 509 triangulos) -> game/assets/scenery/lamp_bridge.glb
         base no chao (0,0,0), braco apontando para -X (igual ao lamp_post.glb), materiais "steel_lamp" e
         "lamp_amber" (a lampada; o jogo apaga de dia, como no poste antigo).
  person docs/Modelos/Novas Melhorias/Placas/ROAD+SIGNS.blend, objeto "Polygon.002" (homem em pe escaneado, 1,66 m,
         3.000 triangulos, sem textura nem esqueleto) -> game/assets/scenery/people/person.glb (~800 tri) e
         person_lod1.glb (~200 tri), frente = +Y no Blender (-Z no Godot), pe em Z = 0.
         Cor por vertice = REGIAO (canal R): 0 pele, 0,25 cabelo, 0,5 camisa, 0,75 calca, 1 sapato. O shader do
         jogo (PeopleKit) pinta cada regiao com a cor de cada copia (camisa/calca variam por pessoa).
         + game/assets/textures/people/bust_base.png e bust_shirt.png (256 px): busto 3/4 para o retrato dos
         rivais na abertura (a camisa sai separada, em branco, para pintar com a cor do caminhao).

Uso: blender -b --factory-startup -P blender/scripts/build_t186_props.py -- [--root PASTA_DO_PROJETO_PRINCIPAL]
     [--only lamp,person] [--preview]
Deterministico. --preview grava blender/renders/t186/props_sheet.png.
"""
from __future__ import annotations

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import pbr  # noqa: E402
from lib import export as EX  # noqa: E402
import build_roadside_kit as RK  # noqa: E402

OUT = os.path.join(ROOT, "game", "assets", "scenery")
OUT_PEOPLE = os.path.join(OUT, "people")
OUT_TEX = os.path.join(ROOT, "game", "assets", "textures", "people")
WORK = os.path.join(ROOT, "blender", "renders", "t186")
BRIDGE = os.path.join("docs", "Modelos", "Road_pontes", "Ponte", "bridge_model.FBX")
SIGNS = os.path.join("docs", "Modelos", "Novas Melhorias", "Placas", "ROAD+SIGNS.blend")
PERSON_TRIS = (800, 200)
# regioes (altura em m, pessoa de 1,66 m) -> valor no canal R da cor por vertice
SKIN, HAIR, SHIRT, PANTS, SHOES = 0.0, 0.25, 0.5, 0.75, 1.0


def args() -> dict:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"root": ROOT, "only": ["lamp", "person"], "preview": "--preview" in a}
    if "--root" in a:
        out["root"] = a[a.index("--root") + 1]
    if "--only" in a:
        out["only"] = a[a.index("--only") + 1].split(",")
    return out


def export(objs: list, path: str, colors: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
              export_cameras=False, export_lights=False, export_image_format="NONE", export_materials="EXPORT")
    if colors:
        kw.update(export_vertex_color="NAME", export_vertex_color_name="Col", export_all_vertex_colors=False)
    bpy.ops.export_scene.gltf(**kw)


# ---------------------------------------------------------------- poste de luz da ponte
def build_lamp(root: str) -> dict:
    RK.clear_scene()
    bpy.ops.import_scene.fbx(filepath=os.path.join(root, BRIDGE))
    block = bpy.data.objects["Block:den"]
    parts = [c for c in block.children_recursive if c.type == "MESH"]
    bm = bmesh.new()
    mats: list[str] = []
    for o in parts:
        b2 = RK.evaluated_copy(o, o.name)
        name = "lamp_amber" if any(s.material and s.material.name == "Light" for s in o.material_slots) else "steel_lamp"
        if name not in mats:
            mats.append(name)
        for f in b2.faces:
            f.material_index = mats.index(name)
        me = bpy.data.meshes.new("tmp")
        b2.to_mesh(me)
        b2.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    co = np.array([v.co[:] for v in bm.verts])
    zmin = co[:, 2].min()
    foot = co[co[:, 2] < zmin + 0.5][:, :2].mean(0)               # centro da base do poste
    head = co[co[:, 2] > co[:, 2].max() - 0.6][:, :2].mean(0)     # luminaria (ponta do braco)
    d = head - foot
    ang = math.atan2(d[1], d[0])
    bm.transform(Matrix.Translation(Vector((-foot[0], -foot[1], -zmin))))
    bm.transform(Matrix.Rotation(math.pi - ang, 4, "Z"))           # braco para -X
    o = bpy.data.objects.new("lamp_bridge", bpy.data.meshes.new("lamp_bridge"))
    bm.to_mesh(o.data)
    bm.free()
    bpy.context.scene.collection.objects.link(o)
    for n in mats:
        o.data.materials.append(pbr.emissive("lamp_amber", "#ffb347", 3.0) if n == "lamp_amber"
                                else pbr.pbr("steel_lamp", "#8c9096", metallic=0.6, roughness=0.45))
    export([o], os.path.join(OUT, "lamp_bridge.glb"))
    lo = np.array([v.co[:] for v in o.data.vertices])
    info = {"name": "lamp_bridge", "tris": RK.tri_count(o), "size_m": np.round(lo.max(0) - lo.min(0), 2).tolist(),
            "src": BRIDGE + " Block:den"}
    print("PROP", json.dumps(info))
    return {"obj": o, "info": info}


# ---------------------------------------------------------------- pessoa
def _region(p: Vector, axis_x: float) -> float:
    z = p.z
    if z < 0.09:
        return SHOES
    if z > 1.57:
        return HAIR
    if z > 1.42:
        return SKIN
    if z < 0.86:
        return PANTS
    if z < 1.18 and abs(p.x - axis_x) > 0.21:                      # antebraco de manga curta
        return SKIN
    return SHIRT


def build_person(root: str) -> dict:
    RK.clear_scene()
    objs = RK.load_objects(os.path.join(root, SIGNS), ["Polygon.002"])
    src = objs["Polygon.002"]
    bm = RK.evaluated_copy(src, "person")
    co = np.array([v.co[:] for v in bm.verts])
    zmin = co[:, 2].min()
    h = co[:, 2].max() - zmin
    feet = co[co[:, 2] < zmin + 0.06 * h][:, :2]
    ankle = co[(co[:, 2] > zmin + 0.08 * h) & (co[:, 2] < zmin + 0.12 * h)][:, :2]
    d = feet.mean(0) - ankle.mean(0)                               # a ponta do pe aponta para a frente
    ang = math.atan2(d[1], d[0])
    ctr = co[:, :2].mean(0)
    bm.transform(Matrix.Translation(Vector((-ctr[0], -ctr[1], -zmin))))
    bm.transform(Matrix.Rotation(math.pi / 2 - ang, 4, "Z"))       # frente = +Y
    bm.transform(Matrix.Scale(1.70 / h, 4))                        # 1,70 m (o jogo varia 0,92-1,06)
    out = {}
    for lod, target in enumerate(PERSON_TRIS):
        name = "person" if lod == 0 else "person_lod1"
        o = RK.mesh_obj(name, bm.copy(), ["person"])
        RK.decimate(o, target)
        _paint_regions(o)
        export([o], os.path.join(OUT_PEOPLE, name + ".glb"), colors=True)
        info = {"name": name, "tris": RK.tri_count(o), "height_m": round(max(v.co.z for v in o.data.vertices), 2)}
        print("PROP", json.dumps(info))
        out[name] = {"obj": o, "info": info}
        o.hide_render = True
    full = RK.mesh_obj("person_full", bm, ["person"])              # retrato: malha original (3.000 tri)
    _paint_regions(full)
    bust(full)
    return out


def _paint_regions(o) -> None:
    attr = o.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for poly in o.data.polygons:
        c = sum((o.data.vertices[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
        r = _region(c, 0.0)
        for li in poly.loop_indices:
            attr.data[li].color = (r, r, r, 1.0)


REGION_RGB = {SKIN: (0.78, 0.6, 0.48), HAIR: (0.06, 0.05, 0.05), SHIRT: (1.0, 1.0, 1.0), PANTS: (0.13, 0.14, 0.18),
              SHOES: (0.08, 0.08, 0.08)}


def _clay(name: str, flat_id: bool) -> bpy.types.Material:
    """Cor por regiao (lida da cor por vertice). flat_id: so a regiao em emissao pura (mascara da camisa)."""
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(vc.outputs["Color"], sep.inputs[0])
    if flat_id:
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(sep.outputs[0], em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        return m
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.interpolation = "CONSTANT"
    keys = sorted(REGION_RGB)
    while len(cr.elements) < len(keys):
        cr.elements.new(0.5)
    for el, k in zip(cr.elements, keys):
        el.position = max(0.0, k - 0.12)
        el.color = (*REGION_RGB[k], 1.0)
    nt.links.new(sep.outputs[0], ramp.inputs[0])
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.8
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return m


def bust(person) -> None:
    """Busto 3/4 (cabeca e ombros) em 2 camadas de 256 px: base (sem a camisa) e camisa em branco."""
    os.makedirs(OUT_TEX, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.cycles.seed = 7
    sc.cycles.device = "CPU"
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x = sc.render.resolution_y = 256
    sc.world = bpy.data.worlds.new("bust_w")
    bg = sc.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.35, 0.35, 0.38, 1)
        bg.inputs["Strength"].default_value = 0.6
    key = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    key.data.energy = 3.2
    key.rotation_euler = (math.radians(-50), 0, math.radians(-30))   # luz vindo da frente-esquerda (rosto aceso)
    sc.collection.objects.link(key)
    cam = bpy.data.objects.new("bcam", bpy.data.cameras.new("bcam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.78
    sc.collection.objects.link(cam)
    sc.camera = cam
    tgt = Vector((0.0, 0.0, 1.38))
    cam.location = tgt + Vector((-0.9, 2.2, 0.25))                  # 3/4 de frente (frente = +Y)
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    imgs = {}
    for layer, flat in (("lit", False), ("id", True)):
        person.data.materials.clear()
        person.data.materials.append(_clay("clay_" + layer, flat))
        p = os.path.join(WORK, "bust_%s.png" % layer)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        imgs[layer] = RK.load_px(p)
    person.data.materials.clear()
    lit, rid = imgs["lit"], imgs["id"]
    enc = ((1.055 * SHIRT ** (1 / 2.4)) - 0.055)                   # o PNG sai em sRGB: 0,5 linear = 0,735
    shirt = (np.abs(rid[..., 0] - enc) < 0.07) & (rid[..., 3] > 0.5)
    base = lit.copy()
    base[..., 3] = np.where(shirt, 0.0, lit[..., 3])
    top = lit.copy()                                               # camisa: so a luz (cinza), a cor vem do jogo
    top[..., 3] = np.where(shirt, lit[..., 3], 0.0)
    for name, arr in (("bust_base", base), ("bust_shirt", top)):
        p = os.path.join(OUT_TEX, name + ".png")
        EX.save_png(arr.astype(np.float32), p)
        RK.write_import(p)
    print("BUST", OUT_TEX)


def main() -> None:
    a = args()
    for d in (OUT, OUT_PEOPLE, WORK):
        os.makedirs(d, exist_ok=True)
    report = []
    if "lamp" in a["only"]:
        report.append(build_lamp(a["root"])["info"])
    if "person" in a["only"]:
        report += [v["info"] for v in build_person(a["root"]).values()]
    with open(os.path.join(WORK, "props.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=1)
    print("OK props")


main()
