"""T-186: inventario de UM arquivo de modelo de docs/Modelos (nao altera o original).

Importa o arquivo numa cena vazia e grava um .json com: objetos de malha (nome, triangulos, tamanho em metros,
materiais), total de triangulos, tamanho do conjunto, texturas (imagens usadas e resolucao), esqueletos (armatures),
animacoes (actions), shape keys e as "pecas" de primeiro nivel (raizes da hierarquia) com triangulos e tamanho de
cada uma, para achar varios modelos dentro do mesmo arquivo.

Uso: blender -b --factory-startup -P blender/scripts/inventory_models.py -- --file ARQ --out ARQ.json
Formatos: .glb .gltf .fbx .obj .stl .abc .usd/.usdc/.usdz .blend (lido por libraries.load, sem abrir).
Formato que o Blender 5 nao abre (.dae, .3ds, .max, .ma/.mb, .3dm, .stp): grava {"error": ...}.
"""
from __future__ import annotations

import json
import os
import sys

import bpy
from mathutils import Vector


def _args() -> dict:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return {"file": a[a.index("--file") + 1], "out": a[a.index("--out") + 1]}


def import_file(path: str) -> None:
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path, use_image_search=True)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif ext == ".stl":
        bpy.ops.wm.stl_import(filepath=path)
    elif ext == ".abc":
        bpy.ops.wm.alembic_import(filepath=path, as_background_job=False)
    elif ext in (".usd", ".usdc", ".usdz", ".usda"):
        bpy.ops.wm.usd_import(filepath=path)
    elif ext in (".blend", ".blend1"):
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = list(src.objects)
            dst.actions = list(src.actions)
        for o in dst.objects:
            if o is not None and o.name not in bpy.context.scene.collection.objects:
                bpy.context.scene.collection.objects.link(o)
    else:
        raise RuntimeError("formato que o Blender 5 nao importa: " + ext)


def bbox(objs: list) -> tuple:
    lo = Vector((1e18, 1e18, 1e18))
    hi = Vector((-1e18, -1e18, -1e18))
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    return lo, hi


def tris_of(o, cache: dict) -> int:
    if o.type != "MESH":
        return 0
    if o.data.name not in cache:
        cache[o.data.name] = sum(max(len(p.vertices) - 2, 0) for p in o.data.polygons)
    return cache[o.data.name]


def subtree(o) -> list:
    out = [o]
    for c in o.children:
        out += subtree(c)
    return out


def main() -> None:
    a = _args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    res: dict = {"file": a["file"]}
    try:
        import_file(a["file"])
    except Exception as e:  # noqa: BLE001 (queremos registrar qualquer falha de importacao)
        res["error"] = str(e).splitlines()[0][:200]
        _save(a["out"], res)
        return
    objs = list(bpy.context.scene.objects)
    cache: dict = {}
    meshes = [o for o in objs if o.type == "MESH"]
    lo, hi = bbox(meshes)
    res["mesh_objects"] = len(meshes)
    res["tris"] = sum(tris_of(o, cache) for o in meshes)
    res["size_m"] = [round(v, 3) for v in (hi - lo)] if meshes else None
    res["min"] = [round(v, 3) for v in lo] if meshes else None
    res["armatures"] = [o.name for o in objs if o.type == "ARMATURE"]
    res["actions"] = [{"name": ac.name, "frames": [round(f, 1) for f in ac.frame_range]} for ac in bpy.data.actions]
    res["shape_keys"] = sum(1 for o in meshes if o.data.shape_keys is not None)
    imgs = []
    for im in bpy.data.images:
        if im.type == "IMAGE" and im.source in ("FILE", "PACKED"):
            imgs.append({"name": im.name, "size": list(im.size), "packed": im.packed_file is not None,
                         "path": os.path.basename(im.filepath) if im.filepath else ""})
    res["images"] = imgs
    res["materials"] = sorted({s.material.name for o in meshes for s in o.material_slots if s.material})
    roots = [o for o in objs if o.parent is None]
    parts = []
    for r in roots:
        sub = subtree(r)
        t = sum(tris_of(o, cache) for o in sub)
        if t == 0:
            continue
        l2, h2 = bbox(sub)
        parts.append({"name": r.name, "tris": t, "size_m": [round(v, 2) for v in (h2 - l2)],
                      "min": [round(v, 2) for v in l2], "objects": len(sub)})
    parts.sort(key=lambda p: -p["tris"])
    res["roots"] = len(parts)
    res["parts"] = parts[:80]
    _save(a["out"], res)


def _save(path: str, res: dict) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)
    print("INVENTORY", path, res.get("tris"), res.get("error", ""))


main()
