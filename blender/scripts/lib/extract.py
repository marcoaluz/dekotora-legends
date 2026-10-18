"""Tirar peças de modelos de terceiros (T-126): importa um .glb/.blend, acha as "ilhas" (pedaços de malha soltos)
de cada malha e copia só as que caem numa caixa, já com o NOSSO material.

Uso típico (acessórios em `accessories/thirdparty.py`):
    src = extract.load_glb(caminho)                       # {nome: objeto} (malhas originais, coordenadas do mundo)
    objs = extract.take(src, caixas, material_map, name)  # lista de objetos novos (um por material nosso)

Caixas: lista de (min, max) no espaço do ORIGINAL (metros, Z para cima); uma ilha entra se o CENTRO da caixa dela
estiver dentro de alguma caixa (e se o tamanho dela couber em `max_size`, para não pegar a carroceria inteira).
`material_map`: nome do material original -> nome do nosso (pbr.standard_set) ou None (descarta).
Determinístico: a ordem das ilhas e das faces segue a malha original.
"""
from __future__ import annotations

import bmesh
import bpy
import numpy as np

WELD = 1e-5          # solda vértices duplicados pelo glTF (costuras de UV/normais) antes de achar as ilhas


def load_glb(path: str) -> dict:
    before = set(bpy.data.objects)
    mats_before = {mt.name for mt in bpy.data.materials}
    new_before = set(bpy.data.materials)
    bpy.ops.import_scene.gltf(filepath=path)
    bpy.context.view_layer.update()
    for mt in bpy.data.materials:              # "chrome" do original vira "chrome.001" se já existe o nosso "chrome"
        if mt not in new_before:
            base = mt.name.rsplit(".", 1)[0] if "." in mt.name else mt.name
            mt["src_name"] = base if (base in mats_before and mt.name[len(base) + 1:].isdigit()) else mt.name
    out = {}
    for o in sorted((o for o in bpy.data.objects if o not in before), key=lambda o: o.name):
        if o.type == "MESH":
            out[o.name] = o
    return out


def load_blend(path: str) -> dict:
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = list(src.objects)
    col = bpy.data.collections.new("src_tmp")
    bpy.context.scene.collection.children.link(col)
    out = {}
    for o in dst.objects:
        if o is not None:
            col.objects.link(o)
            if o.type == "MESH":
                out[o.name] = o
    bpy.context.view_layer.update()
    return out


def _world_bmesh(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=WELD)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    return bm


def _islands(bm):
    """(rótulo por vértice, rótulo por face): propagação do menor índice pelas arestas (numpy)."""
    nv = len(bm.verts)
    lab = np.arange(nv)
    ea = np.array([[e.verts[0].index, e.verts[1].index] for e in bm.edges], dtype=np.int64).reshape(-1, 2)
    for _ in range(10000):
        if len(ea) == 0:
            break
        m = np.minimum(lab[ea[:, 0]], lab[ea[:, 1]])
        new = lab.copy()
        np.minimum.at(new, ea[:, 0], m)
        np.minimum.at(new, ea[:, 1], m)
        new = new[new]                                  # salto de ponteiro: converge rápido
        if np.array_equal(new, lab):
            break
        lab = new
    flab = np.array([lab[f.verts[0].index] for f in bm.faces], dtype=np.int64)
    return lab, flab


def _boxes(lab, co):
    """{rótulo: (min, max, n_vertices)} de cada ilha."""
    keys, inv = np.unique(lab, return_inverse=True)
    lo = np.full((len(keys), 3), np.inf)
    hi = np.full((len(keys), 3), -np.inf)
    np.minimum.at(lo, inv, co)
    np.maximum.at(hi, inv, co)
    cnt = np.bincount(inv)
    return {int(k): (lo[i], hi[i], int(cnt[i])) for i, k in enumerate(keys)}


def islands_info(o):
    """[(rótulo, n_vertices, min, max)] das ilhas de `o` (para descobrir as caixas olhando a lista)."""
    bm = _world_bmesh(o)
    lab, _flab = _islands(bm)
    co = np.array([v.co[:] for v in bm.verts]).reshape(-1, 3)
    out = [(k, n, lo, hi) for k, (lo, hi, n) in _boxes(lab, co).items()]
    bm.free()
    return out


def take(src: dict, boxes, material_map: dict, name: str, max_size: float = 99.0, objects=None, exclude=(),
         min_size: float = 0.0):
    """Copia as ilhas cujo centro cai em `boxes`. Devolve objetos novos (um por material nosso), sem transformação."""
    per_mat = {}
    for oname in sorted(objects or src):
        o = src[oname]
        mats = [s.material.get("src_name", s.material.name) if s.material else "" for s in o.material_slots]
        if not any(material_map.get(mn) for mn in mats):
            continue
        bm = _world_bmesh(o)
        vlab, lab = _islands(bm)
        co = np.array([v.co[:] for v in bm.verts]).reshape(-1, 3)
        keep_lab = set()
        for k, (lo, hi, _n) in _boxes(vlab, co).items():
            c = (lo + hi) / 2
            if float((hi - lo).max()) > max_size or float((hi - lo).max()) < min_size:
                continue
            inside = any(all(b0[i] <= c[i] <= b1[i] for i in range(3)) for b0, b1 in boxes)
            out_ex = any(all(b0[i] <= c[i] <= b1[i] for i in range(3)) for b0, b1 in exclude)
            if inside and not out_ex:
                keep_lab.add(int(k))
        for fi, f in enumerate(bm.faces):
            if int(lab[fi]) not in keep_lab:
                continue
            ours = material_map.get(mats[f.material_index] if f.material_index < len(mats) else "")
            if not ours:
                continue
            per_mat.setdefault(ours, []).append([v.co.copy() for v in f.verts])
        bm.free()
    out = []
    for mat_name in sorted(per_mat):
        faces = per_mat[mat_name]
        bm = bmesh.new()
        for f in faces:
            vs = [bm.verts.new(c) for c in f]
            try:
                bm.faces.new(vs)
            except ValueError:
                pass
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=WELD)
        me = bpy.data.meshes.new(f"{name}_{mat_name}")
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(f"{name}_{mat_name}", me)
        bpy.context.scene.collection.objects.link(ob)
        ob["our_mat"] = mat_name
        out.append(ob)
    return out


def remove_sources(src: dict) -> None:
    """Apaga da cena os objetos originais (e o que mais o importador criou)."""
    for o in list(bpy.data.objects):
        if o.name in src or (o.type == "EMPTY" and o.get("our_mat") is None and o.name not in ("",)):
            if o.type in ("MESH", "EMPTY") and o.get("our_mat") is None:
                bpy.data.objects.remove(o, do_unlink=True)


def place(objs, origin, scale: float = 1.0, flip_y: bool = False, rot_z_deg: float = 0.0, flip_x: bool = False):
    """Leva do espaço do original ao do acessório: subtrai `origin`, gira em Z, espelha, escala (origem = montagem)."""
    import math
    a = math.radians(rot_z_deg)
    ca, sa = math.cos(a), math.sin(a)
    for o in objs:
        me = o.data
        n = len(me.vertices)
        co = np.empty(n * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3) - np.array(origin)
        x, y = co[:, 0] * ca - co[:, 1] * sa, co[:, 0] * sa + co[:, 1] * ca
        co[:, 0], co[:, 1] = x, y
        flips = 0
        if flip_y:
            co[:, 1] *= -1
            flips += 1
        if flip_x:
            co[:, 0] *= -1
            flips += 1
        co *= scale
        me.vertices.foreach_set("co", co.ravel())
        if flips % 2 == 1:
            me.flip_normals()
        me.update()


def decimate(o, target: int) -> None:
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tris <= target or tris == 0:
        return
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(0.003, target / tris)
    mod.use_collapse_triangulate = True
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)


def clip(objs, lo, hi) -> None:
    """Apaga as faces cujo centro sai da caixa (lo, hi) (no espaço do acessório): corta canos que entram no motor etc."""
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bad = [f for f in bm.faces if not all(lo[i] <= f.calc_center_median()[i] <= hi[i] for i in range(3))]
        bmesh.ops.delete(bm, geom=bad, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


def tris(objs) -> int:
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def decimate_islands(objs, budget: int, min_tris: int = 24) -> list:
    """Reduz cada ILHA conforme o peso raiz(área x triângulos) (como a cabine chata): peças pequenas e simples (um cano
    de 200 triângulos) ficam inteiras e as densas (uma grade perfurada de 70 mil) pagam a conta. Devolve os objetos
    (um por material, como entraram)."""
    out = []
    pieces = []
    for o in objs:
        mat = o["our_mat"]
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.separate(type="LOOSE")
        bpy.ops.object.mode_set(mode="OBJECT")
        parts = [x for x in bpy.context.selected_objects]
        for x in parts:
            x["our_mat"] = mat
        pieces.append((mat, parts))
    allp = [x for _m, ps in pieces for x in ps]
    info = {}
    for x in allp:
        t = tris([x])
        area = sum(p.area for p in x.data.polygons)
        info[x.name] = (t, (max(area, 1e-4) * max(t, 1)) ** 0.5)
    left = {x.name: info[x.name] for x in allp}
    rest = budget
    target = {}
    for _ in range(8):                                   # quem já cabe fica inteiro; o resto divide o que sobra
        wsum = sum(w for _t, w in left.values())
        if wsum <= 0:
            break
        fit = [n for n, (t, w) in left.items() if t <= rest * w / wsum]
        if not fit:
            for n, (t, w) in left.items():
                target[n] = max(min_tris, int(rest * w / wsum))
            break
        for n in fit:
            target[n] = left[n][0]
            rest -= left[n][0]
            left.pop(n)
    for x in allp:
        decimate(x, target.get(x.name, info[x.name][0]))
    for mat, parts in pieces:
        bpy.ops.object.select_all(action="DESELECT")
        for x in parts:
            x.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        if len(parts) > 1:
            bpy.ops.object.join()
        j = bpy.context.view_layer.objects.active
        j["our_mat"] = mat
        out.append(j)
    return out
