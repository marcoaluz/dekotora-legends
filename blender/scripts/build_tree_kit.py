"""T-169: arvore de folhas (Gleditsia triacanthos, `docs/Modelos/Arvore/`, liberada pelo Marco; a pasta fica FORA do
Git) reduzida para o celular: 436 mil -> ~300 triangulos.

  Gledista_Triacanthos.fbx (o menor dos 6; unidades em decimetros: x 0,1 = ~9 m de altura)
      -> game/assets/scenery/tree_leafy.glb
         - tronco e galhos grossos (Material__5) reduzidos a ~TRUNK_TRIS triangulos, cor por vertice de casca;
         - copa: os triangulos de folha/galhinho/vagem viram CARDS grupos (k-medias deterministico dos centros) e
           cada grupo vira 2 cartoes cruzados (4 triangulos) do tamanho do grupo, com as normais apontando para fora
           da copa (luz "de volume"), cor por vertice mais escura no miolo e embaixo;
      -> game/assets/textures/backdrop/tree_leafy_leaves.png (512 x 512, 2 x 2 tufos): 4 pedacos da copa ORIGINAL
         renderizados (Cycles, so a cor das texturas, fundo transparente), cada um visto de fora.
  O jogo cria os materiais pelo nome (TreeKit): "tree_bark" (cor por vertice) e "tree_leaves" (recorte por alfa).

Deterministico. Com --preview: blender/renders/t169/tree_sheet.png.
Uso: blender -b --factory-startup -P blender/scripts/build_tree_kit.py -- [--src "PASTA/docs/Modelos/Arvore"] [--preview]
"""
from __future__ import annotations

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import export as EX  # noqa: E402
import build_roadside_kit as RK  # noqa: E402

OUT_GLB = os.path.join(ROOT, "game", "assets", "scenery")
OUT_TEX = os.path.join(ROOT, "game", "assets", "textures", "backdrop")
WORK = os.path.join(ROOT, "blender", "renders", "t169")
REL = os.path.join("Gledista_Triacanthos_FBX", "Gledista_Triacanthos_FBX", "Gledista_Triacanthos.fbx")

SCALE = 0.1
CARDS = 20
TRUNK_TRIS = 200
CELL = 256
BARK = (0.30, 0.27, 0.24)


def args() -> dict:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"src": os.path.join(ROOT, "docs", "Modelos", "Arvore"), "preview": "--preview" in a}
    if "--src" in a:
        out["src"] = a[a.index("--src") + 1]
    return out


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


def main() -> None:
    a = args()
    src = os.path.join(a["src"], REL)
    if not os.path.isfile(src):
        raise SystemExit("ERRO: arvore nao encontrada: %s (use --src)" % src)
    RK.clear_scene()
    for d in (OUT_GLB, OUT_TEX, WORK):
        os.makedirs(d, exist_ok=True)
    bpy.ops.import_scene.fbx(filepath=src, use_image_search=True)
    tree = [o for o in bpy.data.objects if o.type == "MESH"][0]
    bm = bmesh.new()
    bm.from_mesh(tree.data)
    bm.transform(tree.matrix_world)
    bm.transform(__import__("mathutils").Matrix.Scale(SCALE, 4))
    z0 = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= z0
    names = [m.name if m else "" for m in tree.data.materials]
    bark_i = names.index("Material__5")
    # ---- atlas: materiais so de cor, para renderizar os tufos
    emats = []
    for m in tree.data.materials:
        ci, ai = mat_images(m)
        emats.append(emission_material("em_" + m.name, ci, ai))
    bm.faces.ensure_lookup_table()
    fol = [f for f in bm.faces if f.material_index != bark_i]
    cen = np.array([f.calc_center_median() for f in fol])
    area = np.array([f.calc_area() for f in fol]) + 1e-6
    axis = np.array([np.average(cen[:, 0], weights=area), np.average(cen[:, 1], weights=area)])
    crown = np.array([axis[0], axis[1], np.average(cen[:, 2], weights=area)])
    c, lab = kmeans(cen[::7], area[::7], CARDS)
    lab_all = np.argmin(((cen[:, None, :] - c[None, :, :]) ** 2).sum(-1), axis=1)
    radii = np.array([np.percentile(np.linalg.norm(cen[lab_all == j] - c[j], axis=1), 80) if (lab_all == j).any()
                      else 0.5 for j in range(CARDS)])
    order = np.argsort(-np.bincount(lab_all, minlength=CARDS))
    clumps = [int(j) for j in order[:4]]
    # ---- render dos 4 tufos (Cycles, ortografico, fundo transparente)
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
        p = os.path.join(WORK, "tree_clump_%d.png" % k)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        img = RK.load_px(p)
        iy, ix = divmod(k, 2)
        atlas[iy * CELL:(iy + 1) * CELL, ix * CELL:(ix + 1) * CELL] = img
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.meshes.remove(me)
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
    atlas = np.concatenate([col, al[..., None].astype(np.float32)], -1)
    tex = os.path.join(OUT_TEX, "tree_leafy_leaves.png")
    EX.save_png(atlas, tex)
    RK.write_import(tex)
    # ---- tronco: so a casca grossa, reduzida
    trunk = bm.copy()
    trunk.faces.ensure_lookup_table()
    bmesh.ops.delete(trunk, geom=[f for f in trunk.faces if f.material_index != bark_i], context="FACES")
    tro = RK.mesh_obj("tree_trunk", trunk, ["tree_bark"])
    for p_ in tro.data.polygons:
        p_.material_index = 0
    RK.decimate(tro, TRUNK_TRIS)
    attr = tro.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for d in attr.data:
        d.color = (*BARK, 1.0)
    # ---- cartoes da copa
    cb = bmesh.new()
    lay = cb.loops.layers.color.new("Col")
    uvl = cb.loops.layers.uv.new("UVMap")
    zs = c[:, 2]
    zlo, zhi = float(zs.min()), float(zs.max())
    for j in range(CARDS):
        ctr = Vector(c[j])
        r = float(radii[j]) * 1.35
        out = Vector((ctr.x - axis[0], ctr.y - axis[1], 0.0))
        out = out.normalized() if out.length > 1e-3 else Vector((0, -1, 0))
        side = out.cross(Vector((0, 0, 1))).normalized()
        cell = j % 4
        iy, ix = divmod(cell, 2)
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
    leaves = RK.mesh_obj("tree_cards", cb, ["tree_leaves"])
    me = leaves.data
    vnorm = []                                           # normal "de volume": para fora do centro da copa
    crown_v = Vector(crown)
    for v in me.vertices:
        vnorm.append(tuple(((v.co - crown_v).normalized() * 0.7 + Vector((0, 0, 0.3))).normalized()))
    me.normals_split_custom_set_from_vertices(vnorm)
    # ---- juntar e exportar
    bpy.ops.object.select_all(action="DESELECT")
    for o in (tro, leaves):
        o.hide_render = False
        o.select_set(True)
    bpy.context.view_layer.objects.active = tro
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "tree_leafy"
    path = os.path.join(OUT_GLB, "tree_leafy.glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_image_format="NONE", export_materials="EXPORT",
                              export_vertex_color="NAME", export_vertex_color_name="Col",
                              export_all_vertex_colors=False)
    info = {"tris": RK.tri_count(obj), "trunk_target": TRUNK_TRIS, "cards": CARDS,
            "height_m": round(max(v.co.z for v in obj.data.vertices), 2), "src_tris": 435725}
    print("TREE", json.dumps(info))
    if a["preview"]:
        preview(obj, tex)
    print("OK tree")


def preview(obj, tex: str) -> None:
    """Folha: 2 vistas da arvore reduzida (cor da textura) + o atlas."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 16
    sc.render.film_transparent = False
    sc.render.resolution_x = sc.render.resolution_y = 360
    w = sc.world
    w.use_nodes = True if hasattr(w, "use_nodes") and not w.use_nodes else w.use_nodes
    bg = w.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.55, 0.62, 0.72, 1)
        bg.inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.7, 0.2, 0.8)
    sc.collection.objects.link(sun)
    img = bpy.data.images.load(tex)
    for m in obj.data.materials:
        nt = m.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
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
    cam = sc.camera
    cam.data.type = "PERSP"
    cam.data.lens = 40
    shots = []
    h = max(v.co.z for v in obj.data.vertices)
    for k, d in enumerate((Vector((0.2, -1, 0.15)), Vector((-1, -0.3, 0.45)))):
        cam.location = Vector((0, 0, h * 0.5)) + d.normalized() * h * 2.1
        cam.rotation_euler = (Vector((0, 0, h * 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        p = os.path.join(WORK, "tree_prev_%d.png" % k)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        shots.append(p)
    at = RK.load_px(tex)
    ys = (np.arange(360) * at.shape[0] / 360).astype(int)
    a2 = at[ys][:, ys].copy()
    a2[..., :3] = a2[..., :3] * a2[..., 3:4] + np.array([0.2, 0.2, 0.2]) * (1 - a2[..., 3:4])
    a2[..., 3] = 1.0
    p = os.path.join(WORK, "tree_atlas_prev.png")
    EX.save_png(a2.astype(np.float32), p)
    shots.append(p)
    from lib import preview as PV
    PV.contact_sheet(shots, os.path.join(WORK, "tree_sheet.png"), cols=3)
    print("folha:", os.path.join(WORK, "tree_sheet.png"))


main()
