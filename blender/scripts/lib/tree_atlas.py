"""Pecas da arvore de cartoes (T-169, separado na T-186): k-medias, atlas de tufos renderizado do original,
cartoes cruzados da copa e a previa de cada variacao. Usado por build_tree_kit.py."""
from __future__ import annotations

import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

from . import export as EX

CELL = 256


def mat_images(m) -> tuple:
    """(imagem de cor, imagem de mascara) do material importado."""
    col = alpha = None
    if m is None or m.node_tree is None:
        return col, alpha
    for n in m.node_tree.nodes:
        if n.type != "TEX_IMAGE" or n.image is None:
            continue
        for l in n.outputs["Color"].links:
            if l.to_socket.name == "Base Color":
                col = n.image
            if l.to_socket.name == "Alpha":
                alpha = n.image
        for l in n.outputs["Alpha"].links:
            if l.to_socket.name == "Alpha":
                alpha = n.image
    return col, alpha


def emission_material(name: str, col_img, alpha_img) -> bpy.types.Material:
    """So a cor da textura (sem luz), recortada pela mascara: o que o tufo e de verdade, para o atlas."""
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    if col_img is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = col_img
        nt.links.new(t.outputs["Color"], em.inputs["Color"])
    else:
        em.inputs["Color"].default_value = (0.2, 0.18, 0.15, 1)
    if alpha_img is not None:
        a = nt.nodes.new("ShaderNodeTexImage")
        a.image = alpha_img
        a.image.colorspace_settings.name = "Non-Color"
        nt.links.new(a.outputs["Color"], mix.inputs["Fac"])
    else:
        mix.inputs["Fac"].default_value = 1.0
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def kmeans(p: np.ndarray, w: np.ndarray, k: int, iters: int = 25) -> tuple:
    """k-medias com inicio deterministico (ponto mais distante a cada passo, a partir do mais alto)."""
    cs = [p[int(np.argmax(p[:, 2]))]]
    d = np.linalg.norm(p - cs[0], axis=1)
    for _ in range(k - 1):
        cs.append(p[int(np.argmax(d))])
        d = np.minimum(d, np.linalg.norm(p - cs[-1], axis=1))
    c = np.array(cs)
    for _ in range(iters):
        lab = np.argmin(((p[:, None, :] - c[None, :, :]) ** 2).sum(-1), axis=1)
        for j in range(k):
            m = lab == j
            if m.any():
                c[j] = (p[m] * w[m, None]).sum(0) / w[m].sum()
    lab = np.argmin(((p[:, None, :] - c[None, :, :]) ** 2).sum(-1), axis=1)
    return c, lab


def _load_px(path: str) -> np.ndarray:
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = "Non-Color"
    w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()
    bpy.data.images.remove(im)
    return a


def render_atlas(bm, bark_i: int, tree, c, radii, axis, counts, tex: str, work_prefix: str) -> None:
    """Os 4 maiores grupos da copa ORIGINAL, renderizados de fora (Cycles, so cor), num atlas 2 x 2 de 512 px."""
    emats = []
    for m in tree.data.materials:
        ci, ai = mat_images(m)
        emats.append(emission_material("em_" + m.name, ci, ai))
    clumps = [int(j) for j in np.argsort(-counts)[:4]]
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x = sc.render.resolution_y = CELL
    sc.world = bpy.data.worlds.new("w")
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    sc.collection.objects.link(cam)
    sc.camera = cam
    tree.hide_render = True
    atlas = np.zeros((CELL * 2, CELL * 2, 4), np.float32)
    for k, j in enumerate(clumps):
        ctr = Vector(c[j])
        r = float(radii[j]) * 1.35
        part = bm.copy()
        part.faces.ensure_lookup_table()
        drop = [f for f in part.faces if f.material_index == bark_i or (f.calc_center_median() - ctr).length > r]
        bmesh.ops.delete(part, geom=drop, context="FACES")
        me = bpy.data.meshes.new("clump")
        part.to_mesh(me)
        part.free()
        for m in emats:
            me.materials.append(m)
        ob = bpy.data.objects.new("clump", me)
        sc.collection.objects.link(ob)
        out = Vector((ctr.x - axis[0], ctr.y - axis[1], 0.0))
        out = out.normalized() if out.length > 1e-3 else Vector((0, -1, 0))
        cam.location = ctr + out * (r * 4.0) + Vector((0, 0, r * 0.4))
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.ortho_scale = r * 2.0
        p = "%s_clump_%d.png" % (work_prefix, k)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        img = _load_px(p)
        iy, ix = divmod(k, 2)
        atlas[iy * CELL:(iy + 1) * CELL, ix * CELL:(ix + 1) * CELL] = img
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.meshes.remove(me)
    bpy.data.objects.remove(cam, do_unlink=True)
    # alfa duro (recorte) e cor sangrada para fora do recorte (sem halo escuro nos mipmaps)
    al = atlas[..., 3] > 0.45
    col = atlas[..., :3].copy()
    known = al.copy()
    for _ in range(12):
        acc = np.zeros_like(col)
        cnt = np.zeros(al.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(np.where(known[..., None], col, 0), (dy, dx), (0, 1))
            cnt += np.roll(known, (dy, dx), (0, 1))
        new = (~known) & (cnt > 0)
        col[new] = acc[new] / cnt[new][:, None]
        known |= new
    EX.save_png(np.concatenate([col, al[..., None].astype(np.float32)], -1), tex)


def crown_cards(c, radii, axis, crown, name: str) -> bpy.types.Object:
    """Cada grupo vira 2 cartoes cruzados com UV num dos 4 tufos do atlas e normal "de volume"."""
    cb = bmesh.new()
    lay = cb.loops.layers.color.new("Col")
    uvl = cb.loops.layers.uv.new("UVMap")
    zs = c[:, 2]
    zlo, zhi = float(zs.min()), float(zs.max())
    for j in range(len(c)):
        ctr = Vector(c[j])
        r = float(radii[j]) * 1.35
        out = Vector((ctr.x - axis[0], ctr.y - axis[1], 0.0))
        out = out.normalized() if out.length > 1e-3 else Vector((0, -1, 0))
        side = out.cross(Vector((0, 0, 1))).normalized()
        iy, ix = divmod(j % 4, 2)
        u0, v0 = ix * 0.5 + 0.004, 1.0 - (iy + 1) * 0.5 + 0.004
        u1, v1 = u0 + 0.492, v0 + 0.492
        hf = (ctr.z - zlo) / max(zhi - zlo, 1e-3)
        dist = Vector((ctr.x - axis[0], ctr.y - axis[1], 0)).length / max(float(radii.max()) * 3, 1e-3)
        shade = max(0.55, min(1.0, 0.62 + 0.25 * hf + 0.25 * dist))
        for d in (side, out):                                # 2 cartoes cruzados por tufo
            up = Vector((0, 0, 1))
            q = [ctr - d * r - up * r, ctr + d * r - up * r, ctr + d * r + up * r, ctr - d * r + up * r]
            vs = [cb.verts.new(p) for p in q]
            f = cb.faces.new(vs)
            for lp, uv in zip(f.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))):
                lp[uvl].uv = uv
                lp[lay] = (shade, shade, shade, 1.0)
    bmesh.ops.triangulate(cb, faces=cb.faces[:])
    me = bpy.data.meshes.new(name)
    cb.to_mesh(me)
    cb.free()
    mat = bpy.data.materials.get("tree_leaves") or bpy.data.materials.new("tree_leaves")
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    vnorm = []                                           # normal "de volume": para fora do centro da copa
    crown_v = Vector(crown)
    for v in me.vertices:
        vnorm.append(tuple(((v.co - crown_v).normalized() * 0.7 + Vector((0, 0, 0.3))).normalized()))
    me.normals_split_custom_set_from_vertices(vnorm)
    return obj


def preview_variant(objs: list, tex: str, work: str, name: str) -> list:
    """Uma vista 3/4 de cada nivel (LOD0, LOD1) com a cor do atlas; devolve os PNG (360 x 360)."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 16
    sc.render.film_transparent = False
    sc.render.resolution_x = sc.render.resolution_y = 360
    w = sc.world
    bg = w.node_tree.nodes.get("Background") if w.node_tree else None
    if bg:
        bg.inputs["Color"].default_value = (0.55, 0.62, 0.72, 1)
        bg.inputs["Strength"].default_value = 1.0
    if bpy.data.objects.get("sun") is None:
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.0
        sun.rotation_euler = (0.7, 0.2, 0.8)
        sc.collection.objects.link(sun)
    img = bpy.data.images.load(tex)
    cam = bpy.data.objects.new("pcam", bpy.data.cameras.new("pcam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 40
    shots = []
    for o in objs:
        for m in o.data.materials:
            _preview_material(m, img)
    for i, o in enumerate(objs):
        for p in objs:
            p.hide_render = p is not o
        h = max(v.co.z for v in o.data.vertices)
        d = Vector((0.2, -1, 0.15)).normalized()
        cam.location = Vector((0, 0, h * 0.5)) + d * h * 2.1
        cam.rotation_euler = (Vector((0, 0, h * 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        p = os.path.join(work, "%s_lod%d.png" % (name, i))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        shots.append(p)
    for p in objs:
        p.hide_render = True
    return shots


def _preview_material(m, img) -> None:
    nt = m.node_tree
    if nt is None or nt.nodes.get("pv_done") is not None:
        return
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return
    nt.nodes.new("NodeFrame").name = "pv_done"
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    if m.name.startswith("tree_leaves"):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        nt.links.new(t.outputs["Color"], mul.inputs[1])
        nt.links.new(vc.outputs["Color"], mul.inputs[2])
        nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])
        nt.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
    else:
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
