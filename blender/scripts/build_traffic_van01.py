"""Carro de trânsito "van01" (T-121): furgão de terceiros reduzido e re-texturizado para o jogo.

Fonte: "van 01" de foad3d (CGTrader, Royalty Free License), ver game/assets/LICENCAS.md.
O arquivo original NÃO vai para o Git; este script lê o FBX de fora e grava só o .glb final.

Uso:
  blender -b --factory-startup -P blender/scripts/build_traffic_van01.py -- \
      --src "docs/Novos modelos/Van+01/Export File/van.FBX" [--out game/assets/vehicles/traffic] [--preview <pasta>]

O que faz (determinístico: mesma entrada, mesmo .glb):
  1. importa o FBX, descarta pneus (235 mil triângulos cada), aros, eixos, faróis internos de um lado só
     e qualquer material/textura do autor (V-Ray);
  2. reduz cada peça para um orçamento próprio (Decimate) e põe em escala real (4,4 m, frente +Y, chão Z=0,
     origem no centro de TRÁS, como os outros carros de trânsito);
  3. só 2 materiais: "paint_white" (o Godot troca a cor por carro) e "van01_trim", um atlas 4x4 de cores
     lisas (cor + rugosidade/metal + emissão) para vidro, plástico, cromo, pneu e lanternas;
  4. rodas nossas, simples, em dois objetos por eixo ("wheel_f" e "wheel_r", pivô no eixo) para o jogo girar;
  5. exporta game/assets/vehicles/traffic/car_van01.glb (+ render de conferência opcional).
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, scene  # noqa: E402
from lib.palette import hex_to_rgb, lin  # noqa: E402

NAME = "car_van01"
LENGTH = 4.40            # m, para-choque a para-choque (cabe no CAR_LEN = 4,5 m da simulação)
TIRE_W = 0.20            # m, largura do pneu
WHEEL_SEG = 16

# ---------------------------------------------------------------- atlas (4x4 células de cor lisa)
# nome: (cor sRGB, rugosidade, metal, emissão sRGB ou None)
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
}
GRID = 4
CELL_PX = 32
EMISSION_STRENGTH = 3.0

# ---------------------------------------------------------------- o que fazer com cada objeto do FBX
# objeto: (destino, triângulos máximos). destino = "paint" ou nome de célula; "drop" = descartar.
PARTS = {
    "Plane002": ("paint", 2600),          # carroceria
    "Object004": ("paint", 420),          # portas traseiras
    "Object003": ("plastic", 460),        # para-choque dianteiro
    "Object007": ("plastic", 460),        # para-choque traseiro
    "Plane008": ("grille", 160),          # grade
    "Plane009": ("grille", 160),          # grade de baixo
    "Plane004": ("glass", 200),           # para-brisa
    "Plane010": ("glass", 200),           # vidros das portas
    "Plane005": ("lamp_white", 200),      # lente dos dois faróis
    "Plane003": ("TAIL", 400),            # lanternas (slot 0 = luz, slot 1 = acrílico preto)
    "Object008": ("plastic", 40),         # limpadores
    "Object009": ("plastic", 40),
    "Box001": ("chrome", 140),            # retrovisores
    "Object005": ("glass", 44),           # espelhos dos retrovisores
    "Box003": ("chrome", 40),             # maçanetas
    "Box004": ("chrome", 40),
    "Box002": ("plastic", 30),            # friso da porta traseira (sem texto)
    "Box016": ("plastic", 260),           # rack: base
    "Box005": ("plastic", 60),            # rack: trilhos
    "Box006": ("plastic", 60),
}
for k in range(7, 16):
    PARTS[f"Box{k:03d}"] = ("chrome", 12)  # rack: travessas
# todo o resto (Tire*, Cylinder*: aros e eixos; Front_light_*, Small_light_*, Object006, Plane007: miolo dos
# faróis só de um lado) é descartado; as rodas são refeitas abaixo.


def build_atlas():
    """3 imagens 128x128 empacotadas: cor, ORM (G = rugosidade, B = metal) e emissão."""
    size = GRID * CELL_PX
    col = np.zeros((size, size, 4), np.float32)
    orm = np.zeros((size, size, 4), np.float32)
    emi = np.zeros((size, size, 4), np.float32)
    col[..., 3] = orm[..., 3] = emi[..., 3] = 1.0
    uv = {}
    for i, (name, (c, rough, metal, e)) in enumerate(CELLS.items()):
        cx, cy = i % GRID, i // GRID
        sl = (slice(cy * CELL_PX, (cy + 1) * CELL_PX), slice(cx * CELL_PX, (cx + 1) * CELL_PX))
        col[sl][..., :3] = hex_to_rgb(c)                       # imagem sRGB: valor da paleta direto
        orm[sl][..., 0] = 1.0
        orm[sl][..., 1] = rough
        orm[sl][..., 2] = metal
        if e:
            emi[sl][..., :3] = hex_to_rgb(e)
        uv[name] = ((cx + 0.5) / GRID, (cy + 0.5) / GRID)    # centro da célula (pixels de baixo para cima)
    imgs = []
    for nm, arr, cs in (("van01_col", col, "sRGB"), ("van01_orm", orm, "Non-Color"), ("van01_emi", emi, "sRGB")):
        im = bpy.data.images.new(nm, size, size, alpha=False)
        im.colorspace_settings.name = cs
        im.pixels.foreach_set(arr.ravel())
        im.update()
        im.pack()
        imgs.append(im)
    return imgs, uv


def trim_material(imgs):
    m = bpy.data.materials.new("van01_trim")
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


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def decimate(o, target):
    """Reduz para `target` triângulos e copia as normais da peça ORIGINAL para a reduzida (Data Transfer):
    a lataria continua lisa em vez de ficar 'amassada' pelos triângulos longos da redução."""
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


def set_uv(o, per_face):
    """Uma camada de UV nova; cada face aponta para o centro da sua célula (per_face(poly) -> (u, v))."""
    me = o.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    layer = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        u = per_face(p)
        for li in p.loop_indices:
            layer.data[li].uv = u


def import_parts(src):
    bpy.ops.import_scene.fbx(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:                       # solta dos pais mantendo a posição
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH" or o.name not in PARTS:
            bpy.data.objects.remove(o, do_unlink=True)
    keep = sorted((o for o in bpy.context.scene.objects), key=lambda o: o.name)
    select_only(keep)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return keep


def make_wheel_axle(name, y, z, r, x_out, mat, uv):
    """Dois pneus simples num objeto só (um eixo), pivô no centro do eixo. Banda e flanco de borracha,
    aro cromado com 8 'raios' escuros alternados (dá para ver o giro)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    faces = []   # (face, célula)

    def ring(xp, rad):
        return [bm.verts.new((xp, rad * math.cos(a), rad * math.sin(a)))
                for a in (math.tau * i / WHEEL_SEG for i in range(WHEEL_SEG))]

    for side in (-1, 1):
        xo, xi = side * x_out, side * (x_out - TIRE_W)
        outer_o, outer_i = ring(xo, r), ring(xi, r)
        side_o = ring(xo, r * 0.66)                 # borda do aro na face de fora
        rim_o = ring(xo - side * 0.03, r * 0.62)    # aro um pouco afundado
        hub = bm.verts.new((xo - side * 0.01, 0, 0))
        cap_i = bm.verts.new((xi, 0, 0))
        for i in range(WHEEL_SEG):
            j = (i + 1) % WHEEL_SEG
            q = [outer_o[i], outer_o[j], outer_i[j], outer_i[i]]
            faces.append((bm.faces.new(q if side > 0 else q[::-1]), "rubber"))           # banda
            q = [outer_o[i], side_o[i], side_o[j], outer_o[j]]
            faces.append((bm.faces.new(q if side > 0 else q[::-1]), "rubber"))           # flanco
            q = [side_o[i], rim_o[i], rim_o[j], side_o[j]]
            faces.append((bm.faces.new(q if side > 0 else q[::-1]), "rim_dark"))         # degrau do aro
            t = [rim_o[i], hub, rim_o[j]]
            faces.append((bm.faces.new(t if side > 0 else t[::-1]), "rim" if i % 2 == 0 else "rim_dark"))
            t = [outer_i[j], cap_i, outer_i[i]]
            faces.append((bm.faces.new(t if side > 0 else t[::-1]), "rubber"))           # tampa de dentro
    for f, cell in faces:
        for lp in f.loops:
            lp[uvl].uv = uv[cell]
    bmesh.ops.recalc_face_normals(bm, faces=[f for f, _ in faces])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    o.location = (0, y, z)
    for p in me.polygons:
        p.use_smooth = False
    return o


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="docs/Novos modelos/Van+01/Export File/van.FBX")
    ap.add_argument("--out", default="game/assets/vehicles/traffic")
    ap.add_argument("--preview", default="", help="pasta para o render de conferência (opcional)")
    args = ap.parse_args(argv)
    src = os.path.abspath(args.src)
    if not os.path.isfile(src):
        raise SystemExit(f"FBX não encontrado: {src} (o original fica fora do Git, ver LICENCAS.md)")

    scene.reset_scene()
    parts = import_parts(src)
    # medidas no espaço do FBX (frente = -Y, Z para cima): chão = base dos pneus (raio medido nos aros/pneus)
    lo, hi = M.bounds(parts)
    length = hi.y - lo.y
    s = LENGTH / length
    z_axle_src, r_src = -0.2, 0.1025       # centro e raio do pneu original (Tire007/Tire008)
    y_front_src, y_rear_src = -0.398, 0.525
    x_out_src = 0.334
    ground = z_axle_src - r_src
    # escala, gira 180° (frente para +Y) e põe a traseira em Y=0, chão em Z=0, centro em X=0
    # (x, y, z) -> (-(x - cx)·s, (hi.y - y)·s, (z - chão)·s): giro de 180° em Z + escala + translação.
    # Feito com matriz + transform_apply para as normais personalizadas do FBX girarem junto.
    cx = (lo.x + hi.x) * 0.5
    mat = Matrix.Translation((cx * s, hi.y * s, -ground * s)) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(s, 4)
    for o in parts:
        o.matrix_world = mat
    select_only(parts)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print("[van01] normais personalizadas do FBX:", sum(1 for o in parts if o.data.has_custom_normals), "de", len(parts))

    imgs, uv = build_atlas()
    m_trim = trim_material(imgs)
    m_paint = paint_material()
    tris_src = 0
    for o in parts:
        dest, budget = PARTS[o.name]
        tris_src += M.count_tris([o])
        decimate(o, budget)
        # lanternas: o slot 0 do autor ("Material #118") é a luz; o slot 1 é o acrílico escuro em volta
        names = [m.name if m else "" for m in o.data.materials]
        is_lamp = [names[p.material_index].startswith("Material") for p in o.data.polygons] if names else []
        o.data.materials.clear()
        if dest == "paint":
            o.data.materials.append(m_paint)
            set_uv(o, lambda p: (0.0, 0.0))
        else:
            o.data.materials.append(m_trim)
            if dest == "TAIL":
                set_uv(o, lambda p: uv["lamp_red"] if is_lamp[p.index] else uv["tail_dark"])
            else:
                set_uv(o, lambda p, c=dest: uv[c])
        for p in o.data.polygons:
            p.material_index = 0
    # junta: um objeto com 2 materiais (pintura + atlas)
    select_only(parts)
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = body.data.name = "body"     # sombreamento: o do FBX (peças inteiras) ou o transferido (reduzidas)

    # rodas nossas: um objeto por eixo (frente = maior Y)
    r = r_src * s
    x_out = x_out_src * s
    y_f = (hi.y - y_front_src) * s
    y_r = (hi.y - y_rear_src) * s
    wf = make_wheel_axle("wheel_f", y_f, r, r, x_out, m_trim, uv)
    wr = make_wheel_axle("wheel_r", y_r, r, r, x_out, m_trim, uv)

    root = bpy.data.objects.new(NAME, None)
    bpy.context.scene.collection.objects.link(root)
    for o in (body, wf, wr):
        o.parent = root
    out = os.path.join(os.path.abspath(args.out), NAME + ".glb")
    objs = [body, wf, wr]
    M.export_glb(out, [root] + objs)
    lo2, hi2 = M.bounds(objs)
    d = hi2 - lo2
    print(f"[van01] tris origem={tris_src} final={M.count_tris(objs)} (corpo {M.count_tris([body])}, "
          f"rodas {M.count_tris([wf, wr])}) tamanho={d.x:.2f}x{d.y:.2f}x{d.z:.2f} m escala={s:.3f} "
          f"raio_roda={r:.3f} eixos y={y_r:.2f}/{y_f:.2f} glb={os.path.getsize(out) / 1e6:.3f} MB")
    if args.preview:
        render_preview(objs, os.path.abspath(args.preview))
    print("OK build_traffic_van01")


def render_preview(objs, outdir):
    """Render de conferência (EEVEE): 3/4 frente, 3/4 trás e perfil, pintura azul e luzes acesas."""
    os.makedirs(outdir, exist_ok=True)
    paint = bpy.data.materials["paint_white"]
    b = next(n for n in paint.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(hex_to_rgb("#2a5cc0")) + (1.0,)
    scn = bpy.context.scene
    scn.render.film_transparent = False
    scn.render.resolution_x, scn.render.resolution_y = 960, 600
    bg = next(n for n in scn.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.35, 0.38, 0.45, 1)
    bg.inputs[1].default_value = 1.0
    scene.add_key_light((50, 0, 35), 3.5)
    floor = M.box("floor", (30, 30, 0.02), (0, 2.2, -0.01), None, bevel=0.0)
    fm = bpy.data.materials.new("floor")
    next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.2, 0.2, 0.22, 1)
    floor.data.materials.append(fm)
    lo, hi = M.bounds(objs)
    ctr = (lo + hi) * 0.5
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    for name, (dv, ortho) in {"34front": (Vector((0.9, 1.0, 0.45)), False), "34rear": (Vector((-0.9, -1.0, 0.5)), False),
                              "side": (Vector((1, 0, 0.0)), True)}.items():
        dv.normalize()
        cam.data.type = "ORTHO" if ortho else "PERSP"
        cam.data.ortho_scale = 5.2
        cam.data.lens = 50
        cam.location = ctr + dv * (11.0 if not ortho else 20)
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(outdir, f"van01_{name}.png")
        bpy.ops.render.render(write_still=True)


main()
