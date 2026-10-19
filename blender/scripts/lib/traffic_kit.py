"""Kit comum dos carros de trânsito feitos a partir de modelos de terceiros (T-124).

Mesma receita da van01 (build_traffic_van01.py), em forma de biblioteca:
  - só 2 materiais por carro: "paint_white" (o Godot troca a cor por carro) e "<tag>_trim", um atlas 4x4 de
    cores lisas (cor + rugosidade/metal + emissão). Cada face aponta para o centro da célula da sua "classe"
    (vidro, cromo, pneu, lanterna...). Cores lisas = nenhum logotipo/textura do autor sobra no carro;
  - durante o trabalho, cada classe é um material provisório "cls_<classe>" (assim a redução respeita as
    bordas entre classes); `finalize()` troca tudo pelos 2 materiais finais;
  - rodas em um objeto por eixo ("wheel_f", "wheel_r"), pivô no centro do eixo (altura = raio), para o
    Traffic3D girar pela distância andada.
"""
from __future__ import annotations

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

from . import mesh3d as M
from .palette import hex_to_rgb, lin

# nome: (cor sRGB, rugosidade, metal, emissão sRGB ou None). Máximo 16 (GRID x GRID).
CELLS = {
    "plastic": ("#141416", 0.60, 0.0, None),
    "rubber": ("#1b1b1d", 0.92, 0.0, None),
    "chrome": ("#dfe5ee", 0.12, 1.0, None),
    "grille": ("#5c626b", 0.30, 1.0, None),
    "glass": ("#101823", 0.05, 0.5, None),
    "lamp_white": ("#ffe9c2", 0.30, 0.0, "#ffe9c2"),
    "lamp_red": ("#c81818", 0.30, 0.0, "#ff2a2a"),
    "rim": ("#b9c0ca", 0.25, 1.0, None),
    "rim_dark": ("#2a2c30", 0.50, 0.6, None),
    "tail_dark": ("#3a0c0c", 0.20, 0.0, None),
    "lamp_amber": ("#e08a1a", 0.30, 0.0, "#ff9a20"),
    "plate": ("#d8dcd2", 0.50, 0.0, None),
    "vinyl": ("#1e1a19", 0.70, 0.0, None),
    "grey": ("#3a3d42", 0.55, 0.2, None),
    "under": ("#0c0c0d", 0.90, 0.0, None),
}
GRID = 4
CELL_PX = 32
EMISSION_STRENGTH = 3.0
PAINT = "paint"


# ---------------------------------------------------------------- materiais
def build_atlas(tag: str, cells: dict | None = None):
    """3 imagens 128x128 empacotadas no .glb: cor, ORM (G = rugosidade, B = metal) e emissão.
    `cells`: outra tabela de células (máx. 16), ex. a da viatura (T-143); padrão CELLS."""
    cells = cells or CELLS
    assert len(cells) <= GRID * GRID, "atlas do trânsito: no máximo 16 células"
    size = GRID * CELL_PX
    col = np.zeros((size, size, 4), np.float32)
    orm = np.zeros((size, size, 4), np.float32)
    emi = np.zeros((size, size, 4), np.float32)
    col[..., 3] = orm[..., 3] = emi[..., 3] = 1.0
    uv = {}
    for i, (name, (c, rough, metal, e)) in enumerate(cells.items()):
        cx, cy = i % GRID, i // GRID
        sl = (slice(cy * CELL_PX, (cy + 1) * CELL_PX), slice(cx * CELL_PX, (cx + 1) * CELL_PX))
        col[sl][..., :3] = hex_to_rgb(c)
        orm[sl][..., 0] = 1.0
        orm[sl][..., 1] = rough
        orm[sl][..., 2] = metal
        if e:
            emi[sl][..., :3] = hex_to_rgb(e)
        uv[name] = ((cx + 0.5) / GRID, (cy + 0.5) / GRID)
    imgs = []
    for nm, arr, cs in ((f"{tag}_col", col, "sRGB"), (f"{tag}_orm", orm, "Non-Color"), (f"{tag}_emi", emi, "sRGB")):
        im = bpy.data.images.new(nm, size, size, alpha=False)
        im.colorspace_settings.name = cs
        im.pixels.foreach_set(arr.ravel())
        im.update()
        im.pack()
        imgs.append(im)
    return imgs, uv


def trim_material(tag: str, imgs):
    m = bpy.data.materials.new(f"{tag}_trim")
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t_col, t_orm, t_emi = (nt.nodes.new("ShaderNodeTexImage") for _ in range(3))
    for t, im in zip((t_col, t_orm, t_emi), imgs):
        t.image = im
        t.interpolation = "Closest"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(t_col.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t_orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], b.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], b.inputs["Metallic"])
    nt.links.new(t_emi.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = EMISSION_STRENGTH
    return m


def paint_material():
    m = bpy.data.materials.new("paint_white")
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(hex_to_rgb("#d6dce6")) + (1.0,)
    b.inputs["Metallic"].default_value = 0.35
    b.inputs["Roughness"].default_value = 0.32
    b.inputs["Coat Weight"].default_value = 0.8
    b.inputs["Coat Roughness"].default_value = 0.04
    return m


def class_mat(name: str):
    """Material provisório de uma classe (some no finalize)."""
    key = "cls_" + name
    return bpy.data.materials.get(key) or bpy.data.materials.new(key)


def assign_classes(o, classes) -> None:
    """Uma classe por face (lista na ordem dos polígonos)."""
    names = sorted(set(classes))
    me = o.data
    me.materials.clear()
    for n in names:
        me.materials.append(class_mat(n))
    idx = {n: i for i, n in enumerate(names)}
    me.polygons.foreach_set("material_index", np.array([idx[c] for c in classes], np.int32))


def face_classes(o) -> list:
    names = [m.name[4:] if m and m.name.startswith("cls_") else PAINT for m in o.data.materials]
    mi = np.zeros(len(o.data.polygons), np.int32)
    o.data.polygons.foreach_get("material_index", mi)
    return [names[i] if i < len(names) else PAINT for i in mi]


def finalize(o, m_paint, m_trim, uv) -> None:
    """Troca os materiais de classe por pintura + atlas; UV de cada face = centro da célula da classe."""
    cls = face_classes(o)
    me = o.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    layer = me.uv_layers.new(name="UVMap")
    has_paint = any(c == PAINT for c in cls)
    me.materials.clear()
    if has_paint:
        me.materials.append(m_paint)
    me.materials.append(m_trim)
    trim_idx = 1 if has_paint else 0
    for p, c in zip(me.polygons, cls):
        u = (0.0, 0.0) if c == PAINT else uv[c]
        for li in p.loop_indices:
            layer.data[li].uv = u
        p.material_index = 0 if c == PAINT else trim_idx


# ---------------------------------------------------------------- malha
def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def unparent_apply(objs) -> None:
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    select_only(objs)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def place(objs, mat: Matrix) -> None:
    """Aplica `mat` (giro/escala/translação) na malha de todos, com as normais personalizadas junto."""
    for o in objs:
        o.matrix_world = mat @ o.matrix_world
    select_only(objs)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def join(objs, name: str):
    objs = [o for o in objs if o is not None and len(o.data.polygons) > 0]
    select_only(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = o.data.name = name
    return o


def weld(o, dist: float) -> None:
    """Junta vértices coincidentes (o importador separa nas costuras de UV); a redução fica sem rachaduras."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(o.data)
    bm.free()


def face_data(o):
    """Por face: centro (N,3), normal (N,3), área (N), UV médio (N,2) da camada ativa (ou zeros)."""
    me = o.data
    n = len(me.polygons)
    ctr = np.zeros(n * 3, np.float32)
    nrm = np.zeros(n * 3, np.float32)
    area = np.zeros(n, np.float32)
    me.polygons.foreach_get("center", ctr)
    me.polygons.foreach_get("normal", nrm)
    me.polygons.foreach_get("area", area)
    uvm = np.zeros((n, 2), np.float32)
    if me.uv_layers.active is not None and n:
        uv = np.zeros(len(me.loops) * 2, np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
        start = np.zeros(n, np.int32)
        tot = np.zeros(n, np.int32)
        me.polygons.foreach_get("loop_start", start)
        me.polygons.foreach_get("loop_total", tot)
        uvm = np.add.reduceat(uv, start, axis=0) / tot[:, None]
    return ctr.reshape(-1, 3), nrm.reshape(-1, 3), area, uvm


def loose_parts(o) -> list:
    """Listas de índices de face por peça solta (ligadas por vértice)."""
    me = o.data
    n = len(me.vertices)
    parent = np.arange(n)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    ev = np.zeros(len(me.edges) * 2, np.int32)
    me.edges.foreach_get("vertices", ev)
    for a, b in ev.reshape(-1, 2):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)
    groups = {}
    for p in me.polygons:
        groups.setdefault(find(p.vertices[0]), []).append(p.index)
    return [groups[k] for k in sorted(groups)]


def part_masks(o, keep_min: float = 0.0, inside=None):
    """Por peça solta: máscara de faces das peças menores que `keep_min` (diagonal, m) e das peças cujos
    vértices satisfazem `inside(P) -> bool` (P = vértices (n,3) da peça). Devolve (pequenas, dentro)."""
    me = o.data
    co = np.zeros(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    small = np.zeros(len(me.polygons), bool)
    hit = np.zeros(len(me.polygons), bool)
    for faces in loose_parts(o):
        vids = sorted({v for f in faces for v in me.polygons[f].vertices})
        P = co[vids]
        if np.linalg.norm(P.max(0) - P.min(0)) < keep_min:
            small[faces] = True
        elif inside is not None and inside(P):
            hit[faces] = True
    return small, hit


def split_faces(o, mask, name: str):
    """Move as faces com mask=True para um objeto novo `name` (devolve None se nenhuma)."""
    mask = np.asarray(mask, bool)
    if not mask.any():
        return None
    new = o.copy()
    new.data = o.data.copy()
    new.name = new.data.name = name
    bpy.context.scene.collection.objects.link(new)
    delete_faces(new, ~mask)
    delete_faces(o, mask)
    return new


def delete_faces(o, mask) -> None:
    mask = np.asarray(mask, bool)
    if not mask.any():
        return
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    dead = [bm.faces[i] for i in np.nonzero(mask)[0]]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(o.data)
    bm.free()


def decimate(o, target: int) -> None:
    """Reduz para `target` triângulos e copia as normais da peça ORIGINAL (Data Transfer): a lataria
    continua lisa em vez de ficar 'amassada' pelos triângulos longos da redução."""
    cur = M.count_tris([o])
    if cur <= target:
        return
    src = o.copy()
    src.data = o.data.copy()
    bpy.context.scene.collection.objects.link(src)
    md = o.modifiers.new("dec", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = target / cur
    md.use_collapse_triangulate = True
    select_only([o])
    bpy.ops.object.modifier_apply(modifier=md.name)
    for p in o.data.polygons:
        p.use_smooth = True
    dt = o.modifiers.new("nrm", "DATA_TRANSFER")
    dt.object = src
    dt.use_loop_data = True
    dt.data_types_loops = {"CUSTOM_NORMAL"}
    dt.loop_mapping = "NEAREST_POLYNOR"
    bpy.ops.object.modifier_apply(modifier=dt.name)
    bpy.data.objects.remove(src, do_unlink=True)


def make_wheel_axle(name: str, y: float, r: float, x_out: float, tire_w: float, seg: int = 16):
    """Dois pneus simples num objeto só (um eixo), pivô no centro do eixo (x=0, y, z=r). Banda e flanco de
    borracha, aro com raios claros/escuros alternados (dá para ver o giro). Mesmo desenho da van01."""
    bm = bmesh.new()
    faces = []

    def ring(xp, rad):
        return [bm.verts.new((xp, rad * math.cos(a), rad * math.sin(a))) for a in (math.tau * i / seg for i in range(seg))]

    for side in (-1, 1):
        xo, xi = side * x_out, side * (x_out - tire_w)
        outer_o, outer_i = ring(xo, r), ring(xi, r)
        side_o = ring(xo, r * 0.66)
        rim_o = ring(xo - side * 0.03, r * 0.62)
        hub = bm.verts.new((xo - side * 0.01, 0, 0))
        cap_i = bm.verts.new((xi, 0, 0))
        for i in range(seg):
            j = (i + 1) % seg
            for q, c in (([outer_o[i], outer_o[j], outer_i[j], outer_i[i]], "rubber"),
                         ([outer_o[i], side_o[i], side_o[j], outer_o[j]], "rubber"),
                         ([side_o[i], rim_o[i], rim_o[j], side_o[j]], "rim_dark"),
                         ([rim_o[i], hub, rim_o[j]], "rim" if i % 2 == 0 else "rim_dark"),
                         ([outer_i[j], cap_i, outer_i[i]], "rubber")):
                faces.append((bm.faces.new(q if side > 0 else q[::-1]), c))
    bmesh.ops.recalc_face_normals(bm, faces=[f for f, _ in faces])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    assign_classes(o, [c for _, c in faces])
    for p in me.polygons:
        p.use_smooth = False
    o.location = (0.0, y, r)
    return o


def set_pivot(o, pivot) -> None:
    """Origem do objeto em `pivot` (a malha não sai do lugar)."""
    pv = Vector(pivot)
    o.data.transform(Matrix.Translation(-pv))
    o.location = pv


def export(name: str, body, wheels, out_dir: str) -> str:
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    objs = [body] + list(wheels)
    for o in objs:
        o.parent = root
    path = os.path.join(os.path.abspath(out_dir), name + ".glb")
    M.export_glb(path, [root] + objs)
    return path
