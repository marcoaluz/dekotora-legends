"""Inspeciona um modelo de terceiros SEM alterar o original (T-159).

Importa um .fbx / .obj / .blend / .stl / .abc numa cena vazia, grava as medidas (triangulos, tamanho, materiais,
texturas e resolucao) num .json, miniaturas das texturas e uma folha de contato 2x2 (vistas 3/4, lado, cima e
"do motorista") com uma caixa vermelha do tamanho de um caminhao (2,5 x 12 x 3,8 m) para dar a escala.
Nada e salvo de volta nos arquivos de origem (o .blend e lido por `libraries.load`, sem abrir).

Uso:
  blender -b --factory-startup -P blender/scripts/inspect_model.py -- --file CAMINHO --out PASTA --name NOME
      [--hide REGEX] [--only REGEX] [--truck X,Y,Z] [--truck-yaw GRAUS] [--no-truck] [--res 800x560] [--no-render]
      [--views "34;side;top;driver"] [--driver X,Y,Z,TX,TY,TZ] [--texdir PASTA] [--sheet-name NOME]
  --views: 4 vistas separadas por ";": 34 (3/4 de cima), side, front, top (ortograficas), driver (na ponta, na
           altura do motorista) ou uma camera livre "x,y,z,alvo_x,alvo_y,alvo_z[,lente_mm]".
  --texdir: liga (so na memoria, para a previa) texturas soltas "<material>_diffuse*" a materiais sem imagem.
Comandos usados na T-159: ver docs/ANALISE_ROAD_PONTES.md (anexo).
"""
from __future__ import annotations

import json
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Vector


def _args() -> dict:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out: dict = {"hide": "", "only": "", "res": "800x560", "render": True, "truck": None, "truck_yaw": None,
                 "driver": None, "sheet_name": "", "texdir": "", "views": "34;side;top;driver", "no_truck": ""}
    i = 0
    while i < len(a):
        k = a[i]
        if k == "--no-render":
            out["render"] = False
            i += 1
            continue
        if k == "--no-truck":
            out["no_truck"] = "1"
            i += 1
            continue
        out[k[2:].replace("-", "_")] = a[i + 1]
        i += 2
    return out


ARGS = _args()
OUT = os.path.abspath(ARGS["out"])
NAME = ARGS["name"]
os.makedirs(OUT, exist_ok=True)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_file(path: str) -> list:
    before = set(bpy.data.objects)
    ext = os.path.splitext(path)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path, use_image_search=True)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif ext == ".stl":
        bpy.ops.wm.stl_import(filepath=path)
    elif ext == ".abc":
        bpy.ops.wm.alembic_import(filepath=path, as_background_job=False)
    elif ext in (".blend", ".blend1"):
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = list(src.objects)
        for o in dst.objects:
            if o is not None and o.name not in bpy.context.scene.collection.objects:
                bpy.context.scene.collection.objects.link(o)
    else:
        raise SystemExit("formato nao suportado: " + ext)
    return [o for o in bpy.data.objects if o not in before]


def world_bbox(objs: list) -> tuple:
    lo = Vector((1e18, 1e18, 1e18))
    hi = Vector((-1e18, -1e18, -1e18))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    return lo, hi


def mesh_stats(objs: list) -> list:
    dg = bpy.context.evaluated_depsgraph_get()
    rows = []
    for o in objs:
        if o.type != "MESH":
            rows.append({"name": o.name, "type": o.type})
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        lo, hi = world_bbox([o])
        rows.append({
            "name": o.name, "type": "MESH", "tris": len(me.loop_triangles), "verts": len(me.vertices),
            "size_m": [round(v, 3) for v in (hi - lo)], "min": [round(v, 3) for v in lo],
            "max": [round(v, 3) for v in hi],
            "materials": [s.material.name if s.material else None for s in o.material_slots],
            "uv_layers": len(me.uv_layers), "hidden_render": bool(o.hide_render), "hidden": bool(o.hide_get()),
            "parent": o.parent.name if o.parent else None,
        })
        ev.to_mesh_clear()
    return rows


def material_info() -> list:
    rows = []
    for m in bpy.data.materials:
        imgs = []
        base = None
        emit = None
        if m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image is not None:
                    links = [l.to_socket.name for l in m.node_tree.links if l.from_node == n]
                    imgs.append({"image": n.image.name, "to": links})
                if n.type == "BSDF_PRINCIPLED":
                    base = [round(v, 3) for v in n.inputs["Base Color"].default_value[:3]]
                    es = n.inputs.get("Emission Strength")
                    emit = round(es.default_value, 2) if es is not None else None
        rows.append({"name": m.name, "users": m.users, "base_color": base, "emission": emit, "textures": imgs})
    return rows


def image_info(thumb_dir: str) -> list:
    rows = []
    os.makedirs(thumb_dir, exist_ok=True)
    for img in bpy.data.images:
        if img.type != "IMAGE":
            continue
        fp = bpy.path.abspath(img.filepath) if img.filepath else ""
        w, h = img.size[0], img.size[1]
        row = {"name": img.name, "filepath": img.filepath, "packed": img.packed_file is not None,
               "found": bool(w and h), "size": [w, h], "file_exists": bool(fp) and os.path.exists(fp)}
        if w and h:
            row["thumb"] = _thumb(img, thumb_dir)
        rows.append(row)
    return rows


def _thumb(img, thumb_dir: str, max_px: int = 512) -> str:
    w, h = img.size
    arr = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(arr)
    arr = arr.reshape(h, w, 4)
    step = max(1, math.ceil(max(w, h) / max_px))
    small = np.ascontiguousarray(arr[::step, ::step])
    sh, sw = small.shape[:2]
    new = bpy.data.images.new("thumb_" + img.name, sw, sh, alpha=True)
    new.pixels.foreach_set(small.ravel())
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", img.name)
    p = os.path.join(thumb_dir, os.path.splitext(safe)[0] + ".png")
    new.filepath_raw = p
    new.file_format = "PNG"
    new.save()
    bpy.data.images.remove(new)
    return p


def link_loose_textures(texdir: str) -> None:
    """So para a previa (na memoria): material sem imagem ganha a textura '<nome>_diffuse*' achada em texdir."""
    files = []
    for dp, _dn, fn in os.walk(texdir):
        files += [os.path.join(dp, f) for f in fn]
    for m in bpy.data.materials:
        if not m.node_tree or any(n.type == "TEX_IMAGE" for n in m.node_tree.nodes):
            continue
        hit = [f for f in files if os.path.basename(f).lower().startswith(m.name.lower() + "_diffuse")]
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if not hit or bsdf is None:
            continue
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(hit[0], check_existing=True)
        tex.projection = "BOX"
        tex.projection_blend = 0.3
        coord = m.node_tree.nodes.new("ShaderNodeTexCoord")
        m.node_tree.links.new(coord.outputs["Object"], tex.inputs["Vector"])
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        m.node_tree.nodes.active = tex
        print("TEX ligada (previa):", m.name, "->", os.path.basename(hit[0]))


def color_tex_active() -> None:
    """O Workbench mostra a imagem ATIVA do material: deixa ativa a que vai na cor (nao o mapa de normais)."""
    for m in bpy.data.materials:
        if not m.node_tree:
            continue
        done = False
        for l in m.node_tree.links:
            if l.from_node.type == "TEX_IMAGE" and l.to_socket.name in ("Base Color", "Color") \
                    and l.to_node.type == "BSDF_PRINCIPLED":
                m.node_tree.nodes.active = l.from_node
                done = True
                break
        if not done:  # cor ligada por um no intermediario: escolhe pelo nome da imagem
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and re.search(r"(?i)color|albedo|diffuse", n.image.name) \
                        and not re.search(r"(?i)normal", n.image.name):
                    m.node_tree.nodes.active = n
                    break


# ---------------------------------------------------------------- render

def _mat(name: str, rgb: tuple):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgb + (1.0,)
    if m.node_tree:
        b = m.node_tree.nodes.get("Principled BSDF")
        if b:
            b.inputs["Base Color"].default_value = rgb + (1.0,)
    return m


def add_truck(lo: Vector, hi: Vector):
    """Caixa 2,5 x 12 x 3,8 m (caminhao) para escala."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    t = bpy.context.active_object
    t.name = "_TRUCK_SCALE"
    t.scale = (2.5, 12.0, 3.8)
    size = hi - lo
    long_x = size.x > size.y
    if ARGS["truck"]:
        x, y, z = [float(v) for v in ARGS["truck"].split(",")]
    else:
        x = (lo.x + hi.x) * 0.5
        y = (lo.y + hi.y) * 0.5
        z = lo.z
        if long_x:
            y = hi.y + 4.0
        else:
            x = hi.x + 4.0
    yaw = float(ARGS["truck_yaw"]) if ARGS["truck_yaw"] is not None else (90.0 if long_x else 0.0)
    t.rotation_euler = (0.0, 0.0, math.radians(yaw))
    t.location = (x, y, z + 1.9)
    t.data.materials.append(_mat("_truck_red", (0.85, 0.05, 0.05)))
    return t


def _cam(name: str, loc: Vector, target: Vector, ortho: float = 0.0, lens: float = 35.0):
    cd = bpy.data.cameras.new(name)
    if ortho > 0:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_start = 0.05
    cd.clip_end = 5000.0
    co = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(co)
    co.location = loc
    d = target - loc
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return co


def setup_render(w: int, h: int) -> None:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.display_settings.display_device = "sRGB"
    sc.view_settings.view_transform = "Standard"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_shadows = True
    sh.show_cavity = True
    sh.cavity_type = "WORLD"
    sc.render.film_transparent = True      # o fundo claro entra na folha (contact_sheet)
    sc.render.image_settings.color_mode = "RGBA"


def render_views(objs: list, lo: Vector, hi: Vector) -> list:
    w, h = [int(v) for v in ARGS["res"].split("x")]
    setup_render(w, h)
    c = (lo + hi) * 0.5
    size = hi - lo
    long_x = size.x >= size.y
    L = Vector((1, 0, 0)) if long_x else Vector((0, 1, 0))
    S = Vector((0, 1, 0)) if long_x else Vector((1, 0, 0))
    long_len = size.x if long_x else size.y
    side_len = size.y if long_x else size.x
    R = 0.5 * size.length
    aspect = w / h
    fov = 2 * math.atan(36.0 / 2 / 35.0)  # lente 35 mm, sensor 36 mm (horizontal)
    dist = R / math.sin(min(fov, fov / aspect * 1.0) / 2) * 0.62
    views = []
    for i, v in enumerate(ARGS["views"].split(";")):
        if v == "34":
            v0 = c + (-L * 0.75 + S * 0.85).normalized() * dist + Vector((0, 0, dist * 0.45))
            views.append(_cam("cam_34", v0, c))
        elif v == "side":
            views.append(_cam("cam_side", c + S * (side_len + R * 2), c, ortho=max(long_len, size.z * aspect) * 1.08))
        elif v == "front":
            views.append(_cam("cam_front", c - L * (long_len + R * 2), c, ortho=max(side_len, size.z * aspect) * 1.08))
        elif v == "top":
            cam = _cam("cam_top", c + Vector((0, 0, size.z + R * 2)), c, ortho=max(long_len, side_len * aspect) * 1.08)
            if not long_x:
                cam.rotation_euler.z += math.radians(90)
            views.append(cam)
        elif v == "driver" and not ARGS["driver"]:
            start = c - L * (long_len * 0.5 + 6.0) + Vector((0, 0, lo.z - c.z + 3.0))
            views.append(_cam("cam_driver", start + S * 2.0, start + L * 40.0 + Vector((0, 0, -0.8)), lens=24.0))
        else:  # "driver" com --driver, ou "x,y,z,tx,ty,tz[,lente]"
            p = [float(t) for t in (ARGS["driver"] if v == "driver" else v).split(",")]
            views.append(_cam("cam_%d" % i, Vector(p[0:3]), Vector(p[3:6]), lens=p[6] if len(p) > 6 else 24.0))
    paths = []
    for i, cam in enumerate(views):
        bpy.context.scene.camera = cam
        p = os.path.join(OUT, "%s_v%d.png" % (NAME, i))
        bpy.context.scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    return paths


def contact_sheet(paths: list, out_path: str) -> None:
    tiles = []
    for p in paths:
        im = bpy.data.images.load(p)
        im.colorspace_settings.name = "Non-Color"
        a = np.empty(im.size[0] * im.size[1] * 4, np.float32)
        im.pixels.foreach_get(a)
        a = a.reshape(im.size[1], im.size[0], 4)
        # fundo: degrade azul-acinzentado claro (ceu) atras do que e transparente
        hgt = a.shape[0]
        sky = np.linspace(0.58, 0.80, hgt, dtype=np.float32)[:, None, None] * np.array([0.92, 0.97, 1.05], np.float32)
        al = a[..., 3:4]
        a[..., :3] = a[..., :3] * al + sky * (1.0 - al)
        a[..., 3] = 1.0
        tiles.append(a)
        bpy.data.images.remove(im)
    th, tw = tiles[0].shape[:2]
    gap = 6
    sheet = np.ones((th * 2 + gap, tw * 2 + gap, 4), np.float32) * 0.1
    sheet[..., 3] = 1.0
    # pixels do Blender: linha 0 = baixo. Topo-esquerda = vista 0.
    pos = [(1, 0), (1, 1), (0, 0), (0, 1)]
    for t, (r, cidx) in zip(tiles, pos):
        y0 = r * (th + gap)
        x0 = cidx * (tw + gap)
        sheet[y0:y0 + th, x0:x0 + tw] = t
    img = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out_path
    img.file_format = "PNG"
    img.save()


def main() -> None:
    reset()
    path = os.path.abspath(ARGS["file"])
    objs = import_file(path)
    meshes = [o for o in objs if o.type == "MESH"]
    stats = mesh_stats(objs)
    lo, hi = world_bbox(meshes)
    info = {
        "file": path, "file_mb": round(os.path.getsize(path) / 1e6, 2), "blender": bpy.app.version_string,
        "objects": len(objs), "mesh_objects": len(meshes),
        "tris_total": sum(r.get("tris", 0) for r in stats),
        "bbox_size_m": [round(v, 2) for v in (hi - lo)], "bbox_min": [round(v, 2) for v in lo],
        "bbox_max": [round(v, 2) for v in hi],
        "unit_scale": bpy.context.scene.unit_settings.scale_length,
        "materials": material_info(),
        "images": image_info(os.path.join(OUT, NAME + "_tex")),
        "objects_list": sorted(stats, key=lambda r: -r.get("tris", 0)),
    }
    with open(os.path.join(OUT, NAME + "_stats.json"), "w", encoding="utf-8") as fh:
        json.dump(info, fh, indent=1, ensure_ascii=False)
    print("STATS %s: %d objetos, %d triangulos, caixa %s m" % (NAME, len(objs), info["tris_total"], info["bbox_size_m"]))
    if not ARGS["render"]:
        print("OK")
        return
    keep = meshes
    if ARGS["hide"]:
        rx = re.compile(ARGS["hide"])
        for o in objs:
            if rx.search(o.name):
                o.hide_render = True
        keep = [o for o in meshes if not o.hide_render]
    if ARGS["only"]:
        rx = re.compile(ARGS["only"])
        for o in objs:
            if not rx.search(o.name):
                o.hide_render = True
        keep = [o for o in meshes if not o.hide_render]
    for o in meshes:
        if o.hide_render and o in keep:
            keep.remove(o)
    lo, hi = world_bbox(keep)
    if ARGS["texdir"]:
        link_loose_textures(ARGS["texdir"])
    color_tex_active()
    if not ARGS["no_truck"]:
        add_truck(lo, hi)
    paths = render_views(keep, lo, hi)
    sheet = os.path.join(OUT, (ARGS["sheet_name"] or NAME) + "_folha.png")
    contact_sheet(paths, sheet)
    print("SHEET", sheet)
    print("OK")


main()
