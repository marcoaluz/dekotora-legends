"""Geometria 3D de jogo: caixas chanfradas, cilindros, perfis extrudados, tubos e exportação .glb.

Tudo por bmesh (sem bpy.ops de modelagem, que quebra em modo sem tela). Convenções do projeto:
metros, frente = +Y, chão Z=0. A exportação glTF converte para Y-up (frente = -Z no Godot).
"""
from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def _link(name: str, bm: bmesh.types.BMesh, mat=None, collection=None) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    if mat is not None:
        ob.data.materials.append(mat)
    return ob


def _bevel(bm, width: float, segments: int) -> None:
    if width > 0:
        bmesh.ops.bevel(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                        offset=width, segments=segments, profile=0.6, affect="EDGES")


def box(name, size, loc, mat=None, bevel=0.03, seg=2, collection=None, rot=(0, 0, 0)):
    """Caixa chanfrada. `loc` = CENTRO. size = (x, y, z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    _bevel(bm, min(bevel, min(size) * 0.45), seg)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob


def cylinder(name, radius, depth, loc, mat=None, axis="Z", seg=24, bevel=0.0, bevel_seg=2, collection=None,
             radius2=None):
    """Cilindro/cone. axis: X, Y ou Z (direção do comprimento). `loc` = CENTRO."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=depth)
    _bevel(bm, min(bevel, radius * 0.45, depth * 0.45), bevel_seg)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    if axis == "X":
        ob.rotation_euler = (0, math.radians(90), 0)
    elif axis == "Y":
        ob.rotation_euler = (math.radians(90), 0, 0)
    return ob


def sphere(name, radius, loc, mat=None, seg=16, rings=10, scale=(1, 1, 1), collection=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    return ob


def profile_extrude(name, pts_yz, width, loc, mat=None, bevel=0.05, seg=2, collection=None):
    """Perfil lateral (lista de (y, z)) extrudado em X por `width` (centrado). Para cabines e saias."""
    bm = bmesh.new()
    verts = [bm.verts.new((-width / 2, y, z)) for y, z in pts_yz]
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    ext = [v for v in res["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(width, 0, 0), verts=ext)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    _bevel(bm, bevel, seg)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    return ob


def plate(name, size, loc, mat=None, bevel=0.01, collection=None, rot=(0, 0, 0)):
    """Chapa fina (alias de box com chanfro pequeno)."""
    return box(name, size, loc, mat, bevel=bevel, seg=1, collection=collection, rot=rot)


def tube(name, points, radius, mat=None, seg=12, collection=None):
    """Tubo por segmentos retos ligando pontos (X,Y,Z); junções esféricas. Devolve um objeto único."""
    bm = bmesh.new()
    for a, b in zip(points[:-1], points[1:]):
        va, vb = Vector(a), Vector(b)
        d = vb - va
        mid = (va + vb) / 2
        m = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=radius, radius2=radius,
                                  depth=d.length)
        verts = m["verts"]
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation(mid) @ rot, verts=verts)
    for p in points[1:-1]:
        s = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=radius)
        bmesh.ops.translate(bm, vec=Vector(p), verts=s["verts"])
    return _link(name, bm, mat, collection)


def smooth(objs, angle_deg: float = 35.0) -> None:
    """Sombreamento suave só onde o ângulo é pequeno (arestas vivas ficam vivas)."""
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in objs if o.type == "MESH"]
    for o in meshes:
        o.select_set(True)
    if not meshes:
        return
    bpy.context.view_layer.objects.active = meshes[0]
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle_deg))
    except Exception:
        for o in meshes:
            for p in o.data.polygons:
                p.use_smooth = True


def join_by_material(objs, prefix: str = "") -> list:
    """Junta objetos que usam o mesmo material (menos draw calls no jogo). Devolve os novos objetos."""
    groups: dict = {}
    for o in objs:
        if o.type != "MESH" or not o.data.materials:
            continue
        groups.setdefault(o.data.materials[0].name, []).append(o)
    out = []
    for matname, lst in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in lst:
            o.select_set(True)
        bpy.context.view_layer.objects.active = lst[0]
        if len(lst) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = f"{prefix}{matname}"
        ob.data.name = ob.name
        out.append(ob)
    return out


def empty(name: str, loc, size: float = 0.15, collection=None) -> bpy.types.Object:
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = size
    e.location = loc
    (collection or bpy.context.scene.collection).objects.link(e)
    return e


def count_tris(objs) -> int:
    n = 0
    for o in objs:
        if o.type == "MESH":
            n += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return n


def export_glb(path: str, objs) -> None:
    """Exporta apenas `objs` (e seus filhos) para .glb com materiais embutidos (Y-up)."""
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_extras=True)
