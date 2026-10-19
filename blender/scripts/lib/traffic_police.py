"""Viatura de polícia do trânsito (T-143) a partir do Camry de viatura (docs/Modelos Melhorados/nypd_toyota_camry_.blend).

O original tem 1,5 milhão de triângulos por causa dos modificadores (Subdivision nível 2, Solidify, Bevel):
aqui cada peça é avaliada com Subdivision no máximo 1 e sem Solidify, e só então reduzida.
Nada do arquivo original que tenha marca ou texto vem junto:
  - a pintura do autor (textura `policebody2.png`, com NYPD, brasão, número, 'TRAFFIC') é trocada por um padrão
    fictício de viatura japonesa de rodovia: metade de baixo preta, de cima branca (classes do atlas, sem textura);
  - as placas (`0cce...`, foto de placa real de Nova York), os emblemas `toyota`/`toyota_2`, a grade de colmeia com o
    logotipo (`front_grill`), o interior (volante com emblema, bancos) e o painel saem.
A barra de luzes (`roof_lights` + `lightsholher`) vira um objeto à parte, "beacon", com o material "beacon": lentes
vermelhas à esquerda, azuis à direita, brancas no meio, carcaça escura (atlas 4 x 1). No Godot o material é trocado
pelo giroflex animado (`road3d/police_beacon.gd`).
"""
from __future__ import annotations

import os

import bpy
import numpy as np

from . import traffic_kit as K

# atlas da viatura: as células comuns que ela usa + preto/branco da pintura (sem "paint_white": a cor não muda)
POLICE_CELLS = {k: v for k, v in K.CELLS.items() if k not in ("vinyl", "plate")}
POLICE_CELLS["police_white"] = ("#eceeef", 0.28, 0.1, None)
POLICE_CELLS["police_black"] = ("#111214", 0.30, 0.25, None)
WHITE, BLACK = "police_white", "police_black"
BELT_SRC = 0.78            # altura (m no original) da divisa preto/branco: logo abaixo das maçanetas

# barra de luzes: colunas do atlas do material "beacon" (u = coluna); o shader do Godot lê só a coluna
BEACON_COLS = ("b_red", "b_blue", "b_white", "b_house")
BEACON_RGB = {"b_red": ("#ff2418", "#ff2418"), "b_blue": ("#2050ff", "#2050ff"), "b_white": ("#f4f4ff", "#9a9aa4"),
              "b_house": ("#16171a", None)}

DROP = ("interior", "seats", "doors_inside", "bottom_interior", "Cover", "Brake_disc", "brake_disc", "breakes",
        "rear_brakes", "toyota", "0cce", "front_grill", "exhaust", "chassis_2", "wipers", "windshield_cover",
        "Window_cover", "Door_holders", "mirrors.001", "roof_window")
BEACON_OBJS = ("roof_lights", "lightsholher")


# ---------------------------------------------------------------- importação do .blend com modificadores avaliados
def load_blend(path: str, subsurf_max: int = 1) -> list:
    """Anexa os objetos do .blend, avalia cada malha com Subdivision <= `subsurf_max` e sem Solidify, aplica a
    posição no mundo e devolve objetos novos (mesmos nomes, sem pais nem modificadores)."""
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = list(src.objects)
    col = bpy.data.collections.new("blend_src")
    bpy.context.scene.collection.children.link(col)
    for o in dst.objects:
        if o is not None:
            col.objects.link(o)
    meshes = sorted((o for o in dst.objects if o is not None and o.type == "MESH"), key=lambda o: o.name)
    for o in meshes:
        for m in o.modifiers:
            if m.type == "SUBSURF":
                m.levels = min(m.levels, subsurf_max)
                m.render_levels = min(m.render_levels, subsurf_max)
            elif m.type == "SOLIDIFY":
                m.show_viewport = False
                m.show_render = False
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    made = []
    for o in meshes:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        mw = o.matrix_world.copy()
        me.transform(mw)
        if mw.to_3x3().determinant() < 0:
            me.flip_normals()
        made.append((o.name, me))
    for o in [o for o in dst.objects if o is not None]:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(col)
    out = []
    for name, me in made:
        ob = bpy.data.objects.new(name, me)
        me.name = name
        bpy.context.scene.collection.objects.link(ob)
        out.append(ob)
    return out


# ---------------------------------------------------------------- classes
def _mat_names(o) -> list:
    mi = np.zeros(len(o.data.polygons), np.int32)
    o.data.polygons.foreach_get("material_index", mi)
    names = [m.name.split(".")[0] if m else "" for m in o.data.materials]
    return [names[i] if i < len(names) else "" for i in mi]


def _face_class(obj: str, mat: str, z: float, nz: float, belt: float) -> str:
    if mat == "Carpaint":
        return BLACK if z < belt and nz < 0.6 else WHITE
    if obj.startswith("front_lights"):
        return {"orangeglass": "lamp_amber", "light": "lamp_white"}.get(mat, "chrome")
    if obj.startswith("light_glass"):
        return "lamp_white"
    if obj.startswith("back_lights_glass"):
        return "lamp_red" if mat == "Red_Glass" else "tail_dark"
    if obj.startswith("back_light"):
        return {"orangeglass": "lamp_amber", "Red__light": "lamp_red"}.get(mat, "chrome")
    if obj.startswith("Lower_lights"):
        return "lamp_white" if mat == "Widows" else "chrome"
    if mat == "Widows":
        return "glass"
    if mat == "Chrome":
        return "plastic" if obj.startswith(("Roof_plastic", "door_chrome")) else "chrome"
    if mat == "Metal":
        return "grille"
    if mat == "Mirror":
        return "chrome"
    if obj.startswith("bottom"):
        return "under"
    if mat in ("bamper", "Black", "interior"):
        return "plastic"
    return "grey"


def _beacon_class(mat: str, x: float) -> str:
    if mat in ("blue_glass", "blue_light", "Red_Glass", "Red__light"):
        return "b_red" if x < 0.0 else "b_blue"          # esquerda vermelha, direita azul (frente = +Y)
    if mat in ("white_glass", "light"):
        return "b_white"
    return "b_house"


def prep_police(spec, objs, dims, _to_final):
    """Classes por peça/material; a pintura vira o padrão preto/branco; rodas = pneus (o build põe rodas nossas
    no lugar exato); a barra de luzes vai para spec["_extras"]["beacon"]."""
    belt = BELT_SRC * spec["_scale"]
    bodies, wheels, beacon = [], [], []
    for o in objs:
        n = len(o.data.polygons)
        if o.name.startswith(("tire", "wheel_disc")):
            K.assign_classes(o, ["rubber" if o.name.startswith("tire") else "rim"] * n)
            wheels.append(o)
            continue
        ctr, nrm, _a, _uv = K.face_data(o)
        mats = _mat_names(o)
        if o.name.startswith(BEACON_OBJS):
            K.assign_classes(o, [_beacon_class(m, float(c[0])) for m, c in zip(mats, ctr)])
            beacon.append(o)
            continue
        K.assign_classes(o, [_face_class(o.name, m, float(c[2]), float(nn[2]), belt) for m, c, nn in zip(mats, ctr, nrm)])
        bodies.append(o)
    spec["_extras"] = {"beacon": beacon}
    return bodies, wheels


# ---------------------------------------------------------------- material da barra de luzes
def beacon_material(tag: str):
    """Material "beacon": atlas 4 x 1 (vermelho, azul, branco, carcaça) com emissão; o Godot troca pelo giroflex."""
    from .palette import hex_to_rgb
    w = len(BEACON_COLS) * 8
    col = np.zeros((8, w, 4), np.float32)
    emi = np.zeros((8, w, 4), np.float32)
    col[..., 3] = emi[..., 3] = 1.0
    for i, name in enumerate(BEACON_COLS):
        c, e = BEACON_RGB[name]
        col[:, i * 8:(i + 1) * 8, :3] = hex_to_rgb(c)
        if e:
            emi[:, i * 8:(i + 1) * 8, :3] = hex_to_rgb(e)
    m = bpy.data.materials.new("beacon")
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for nm, arr, sock in ((f"{tag}_beacon_col", col, "Base Color"), (f"{tag}_beacon_emi", emi, "Emission Color")):
        im = bpy.data.images.new(nm, w, 8, alpha=False)
        im.pixels.foreach_set(arr.ravel())
        im.update()
        im.pack()
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = im
        t.interpolation = "Closest"
        nt.links.new(t.outputs["Color"], b.inputs[sock])
    b.inputs["Emission Strength"].default_value = 2.0
    b.inputs["Roughness"].default_value = 0.2
    return m


def finalize_beacon(o, mat) -> None:
    """Um material só; UV de cada face = centro da coluna da classe (v = 0,5: o giro do glTF não importa)."""
    cls = K.face_classes(o)
    me = o.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    layer = me.uv_layers.new(name="UVMap")
    me.materials.clear()
    me.materials.append(mat)
    for p, c in zip(me.polygons, cls):
        u = (BEACON_COLS.index(c) + 0.5) / len(BEACON_COLS) if c in BEACON_COLS else 0.875
        for li in p.loop_indices:
            layer.data[li].uv = (u, 0.5)
        p.material_index = 0


def import_police(path: str) -> list:
    if not os.path.isfile(path):
        raise SystemExit(f"original não encontrado: {path}")
    return load_blend(path, 1)
