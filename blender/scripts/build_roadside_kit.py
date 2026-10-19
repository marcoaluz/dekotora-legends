"""T-146: kit de beira de estrada a partir dos modelos que o Marco colocou em `docs/Novas Melhorias/`
(Royalty Free License, no AI; a pasta fica FORA do Git, so o resultado reduzido entra no jogo).

  Metais/  "Metal and Concrete Barriers"  -> barreiras de concreto listradas (New Jersey, com grade, muro alto),
                                             cavaletes de metal (2 tamanhos) e pecas soltas (destrocos)
  Placas/  "ROAD SIGNS"                   -> chapas de placa com borda e cantos arredondados (redonda, triangulo,
                                             losango, retangulo) e o poste com base. A FACE das placas e a nossa
                                             (atlas japones da T-130): a textura do pacote (placas ocidentais) NAO entra.
  Placao/  nodel.fbx + tex.rar            -> portico de trelica (2 pernas + viga, 76 triangulos) com textura de grade
                                             recortada (Grade1.png). Refeito com as medidas da nossa pista (27 m) e
                                             usado tambem nos paineis/outdoors. As placas americanas (I-96, Detroit)
                                             do Metal.png NAO entram.

Saida (determinística):
  game/assets/scenery/kit/*.glb       so geometria + UV; materiais pelo NOME (o Godot cria: RoadsideKit.material)
  game/assets/textures/kit/*.png      barreira 1024 (cor) + 512 (ORM, normal), metal da placa 512, trelica 1024
  blender/renders/t146/contact_sheet.png  folha de conferencia (com --preview)

Uso: blender -b --factory-startup -P blender/scripts/build_roadside_kit.py -- [--src "PASTA/Novas Melhorias"] [--preview]
A pasta padrao e <raiz>/docs/Novas Melhorias. O .rar precisa do 7-Zip (C:/Program Files/7-Zip/7z.exe ou no PATH);
sem ele a trelica sai com uma textura desenhada aqui (mesmo formato).
"""
from __future__ import annotations

import math
import os
import shutil
import subprocess
import sys
import zipfile

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import export as EX  # noqa: E402

OUT_GLB = os.path.join(ROOT, "game", "assets", "scenery", "kit")
OUT_TEX = os.path.join(ROOT, "game", "assets", "textures", "kit")
WORK = os.path.join(ROOT, "blender", "renders", "t146")

TRUSS_V = (0.29, 0.367)       # faixa da trelica em X no Grade1.png (UV do nodel.fbx, origem embaixo)
SOLID_V = 0.278               # faixa cinza opaca (linhas 728-752 do Grade1.png)
TRUSS_U_M = 11.0              # metros por repeticao horizontal (como no original)
TRUSS_W = 0.85                # secao da trelica (m)
GANTRY_HALF = 13.5            # pernas do portico: RoadMesh.BARRIER_IN + 0,5
GANTRY_TOP = 7.45             # topo da viga
BILL_W, BILL_H = 9.6, 3.6     # painel do outdoor (arte 1024 x 384)


# ---------------------------------------------------------------- argumentos
def args() -> dict:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"src": os.path.join(ROOT, "docs", "Novas Melhorias"), "preview": "--preview" in a}
    if "--src" in a:
        out["src"] = a[a.index("--src") + 1]
    return out


# ---------------------------------------------------------------- texturas
def load_px(path: str, size: tuple[int, int] | None = None) -> np.ndarray:
    """(h, w, 4) float, linha 0 = topo, valores crus (Non-Color)."""
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = "Non-Color"
    if size is not None and tuple(im.size) != tuple(size):
        im.scale(size[0], size[1])
    w, h = im.size
    px = np.empty(w * h * 4, np.float32)
    im.pixels.foreach_get(px)
    bpy.data.images.remove(im)
    return px.reshape(h, w, 4)[::-1].copy()


def extract_sources(src: str) -> dict:
    os.makedirs(WORK, exist_ok=True)
    met = os.path.join(WORK, "src_metais")
    zp = os.path.join(src, "Metais", "Metal+and+Concrete+Barrier+Textures.zip")
    if not os.path.isdir(met):
        with zipfile.ZipFile(zp) as z:
            z.extractall(met)
    tdir = os.path.join(met, "Metal and Concrete Barrier Textures")
    pla = os.path.join(WORK, "src_placao")
    grade = os.path.join(pla, "tex", "Grade1.png")
    if not os.path.isfile(grade):
        exe = shutil.which("7z") or r"C:\Program Files\7-Zip\7z.exe"
        if os.path.isfile(exe):
            subprocess.run([exe, "x", "-y", "-o" + pla, os.path.join(src, "Placão", "tex.rar")],
                           check=False, stdout=subprocess.DEVNULL)
    return {"barrier": tdir, "grade": grade if os.path.isfile(grade) else "",
            "metal": os.path.join(src, "Placas", "textures", "textures", "blue_metal_plate_diff_1k.jpg")}


def build_textures(t: dict) -> None:
    os.makedirs(OUT_TEX, exist_ok=True)
    b = t["barrier"]
    col = load_px(os.path.join(b, "Metal_Concrete_Barrier_BaseColor.tga"), (1024, 1024))
    col[..., 3] = 1.0
    EX.save_png(col, os.path.join(OUT_TEX, "barrier_albedo.png"))
    orm = np.ones((512, 512, 4), np.float32)
    for ch, name in enumerate(("Occlusion", "Roughness", "Metallic")):
        orm[..., ch] = load_px(os.path.join(b, f"Metal_Concrete_Barrier_{name}.tga"), (512, 512))[..., 0]
    EX.save_png(orm, os.path.join(OUT_TEX, "barrier_orm.png"))
    nrm = load_px(os.path.join(b, "Metal_Concrete_Barrier_Normal.tga"), (512, 512))
    nrm[..., 3] = 1.0
    EX.save_png(nrm, os.path.join(OUT_TEX, "barrier_nrm.png"))
    # chapa da placa: metal pintado (Poly Haven, CC0) sem a cor azul -> aco galvanizado
    m = load_px(t["metal"], (512, 512))
    lum = m[..., 0] * 0.3 + m[..., 1] * 0.59 + m[..., 2] * 0.11
    lum = 0.5 + (lum - lum.mean()) * 1.4
    g = np.clip(lum, 0.0, 1.0)
    out = np.stack([g * 0.97, g * 0.99, g * 1.02, np.ones_like(g)], -1)
    EX.save_png(np.clip(out, 0, 1), os.path.join(OUT_TEX, "sign_metal.png"))
    # trelica / grades (Grade1.png, 1024 com alfa); sem o .rar: trelica desenhada no mesmo lugar
    if t["grade"]:
        gr = load_px(t["grade"], (1024, 1024))
    else:
        gr = np.zeros((1024, 1024, 4), np.float32)
        y0, y1 = int((1 - TRUSS_V[1]) * 1024), int((1 - TRUSS_V[0]) * 1024)
        yy, xx = np.mgrid[y0:y1, 0:1024]
        h = y1 - y0
        f = ((yy - y0) < 6) | ((y1 - yy) < 6) | (np.abs(((xx % h) - (yy - y0))) < 4) | (np.abs(((xx % h) - (h - (yy - y0)))) < 4)
        gr[y0:y1][f] = (0.36, 0.4, 0.42, 1.0)
        gr[728:753] = (0.55, 0.56, 0.57, 1.0)                    # faixa opaca das chapas (SOLID_V)
    EX.save_png(gr, os.path.join(OUT_TEX, "truss_fence.png"))
    for name in ("barrier_albedo", "barrier_orm", "barrier_nrm", "sign_metal", "truss_fence"):
        write_import(os.path.join(OUT_TEX, name + ".png"), normal=name.endswith("_nrm"))


IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=%d
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def write_import(png: str, normal: bool = False) -> None:
    """Textura comprimida na VRAM (S3TC no PC, ETC2/ASTC no Android) com mipmaps, como a T-136. So cria o .import
    se ainda nao existe (o Godot completa o resto na importacao)."""
    p = png + ".import"
    if not os.path.isfile(p):
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(IMPORT_TMPL % (1 if normal else 0))


# ---------------------------------------------------------------- malhas
def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name: str) -> bpy.types.Material:
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    return m


def mesh_obj(name: str, bm: bmesh.types.BMesh, mats: list[str]) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for mn in mats:
        me.materials.append(material(mn))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def evaluated_copy(o: bpy.types.Object, name: str) -> bmesh.types.BMesh:
    """Malha com os modificadores aplicados e o transform do objeto (mundo)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, depsgraph=dg)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(o.matrix_world)
    bpy.data.meshes.remove(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def load_objects(path: str, names: list[str] | None = None) -> dict:
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if names is None or n in names]
    out = {}
    for o in dst.objects:
        if o is not None:
            bpy.context.scene.collection.objects.link(o)
            out[o.name] = o
    bpy.context.view_layer.update()
    return out


def bbox(bm) -> tuple[Vector, Vector]:
    co = np.array([v.co[:] for v in bm.verts])
    return Vector(co.min(0)), Vector(co.max(0))


def ground_center(bm) -> None:
    """Centro em X/Y na origem e o pe em Z = 0."""
    lo, hi = bbox(bm)
    bm.transform(Matrix.Translation(Vector(((lo.x + hi.x) * -0.5, (lo.y + hi.y) * -0.5, -lo.z))))


def keep_uv(bm, layer: str) -> None:
    for name in [l.name for l in bm.loops.layers.uv]:
        if name != layer:
            bm.loops.layers.uv.remove(bm.loops.layers.uv[name])


def decimate(o: bpy.types.Object, target: int) -> None:
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tris <= target:
        return
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(0.004, target / tris)
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)


def planar(bm, angle_deg: float = 2.0) -> None:
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(angle_deg), verts=bm.verts[:], edges=bm.edges[:],
                             delimit={"NORMAL"})
    bmesh.ops.triangulate(bm, faces=bm.faces[:])


def tri_count(o) -> int:
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def export(objs: list, name: str) -> str:
    os.makedirs(OUT_GLB, exist_ok=True)
    path = os.path.join(OUT_GLB, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_image_format="NONE", export_materials="EXPORT")
    return path


# ---------------------------------------------------------------- Metais
BARRIERS = {   # objeto original -> (nosso nome, triangulos maximos)
    "Concrete_Barrier_1": ("barrier_jersey", 200),
    "Concrete_Barrier_2": ("barrier_wall", 200),           # muro alto (1,3 m)
    "Concrete_Barrier_3": ("barrier_jersey_fence", 200),   # New Jersey com grade em cima
    "Metal_Barrier_1": ("barrier_aframe_s", 260),
    "Metal_Barrier_2": ("barrier_aframe", 280),
}
DEBRIS = ["Metal_Element_1", "Metal_Element_2", "Metal_Element_3", "Metal_Element_4"]


def build_barriers(src: str, report: list) -> list:
    out = []
    objs = load_objects(os.path.join(src, "Metais", "Metal+and+Concrete+Barrier.blend"))
    for oname, (name, cap) in BARRIERS.items():
        bm = evaluated_copy(objs[oname], name)
        keep_uv(bm, "UVChannel_1")
        lo, hi = bbox(bm)
        if (hi.x - lo.x) > (hi.y - lo.y):                 # comprimento sempre em Y (sentido da pista)
            bm.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))
        ground_center(bm)
        o = mesh_obj(name, bm, ["kit_barrier"])
        decimate(o, cap)
        out.append((name, [o]))
        report.append((name, oname, tri_count(o)))
    bm = bmesh.new()
    for i, n in enumerate(DEBRIS):                         # destrocos: as 4 pecas soltas lado a lado
        part = evaluated_copy(objs[n], n)
        keep_uv(part, "UVChannel_1")
        ground_center(part)
        part.transform(Matrix.Rotation(0.6 * i, 4, "Z") @ Matrix.Translation(Vector((0.0, 0.0, 0.0))))
        part.transform(Matrix.Translation(Vector(((i % 2) * 0.9 - 0.45, (i // 2) * 0.8 - 0.4, 0.0))))
        tmp = bpy.data.meshes.new("tmp")
        part.to_mesh(tmp)
        part.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    o = mesh_obj("debris_metal", bm, ["kit_barrier"])
    out.append(("debris_metal", [o]))
    report.append(("debris_metal", "+".join(DEBRIS), tri_count(o)))
    for o in objs.values():
        bpy.data.objects.remove(o, do_unlink=True)
    return out


# ---------------------------------------------------------------- Placas
PLATES = {   # objeto original -> (nosso nome, triangulos maximos)
    "Cylinder.001": ("sign_plate_round", 120),
    "Circle.001": ("sign_plate_tri", 80),
    "Plane.002": ("sign_plate_diamond", 60),
    "Plane.013": ("sign_plate_rect", 80),
}


def _plate(o, name: str, cap: int):
    bm = evaluated_copy(o, name)
    keep_uv(bm, "UVMap")
    front = Vector((0, 0, 0))                              # material 0 = face (lado impresso)
    for f in bm.faces:
        if f.material_index == 0:
            front += f.normal * f.calc_area()
    if front.y > 0.0:                                      # face para -Y no Blender = +Z no Godot (para quem vem)
        bm.transform(Matrix.Rotation(math.pi, 4, "Z"))
    lo, hi = bbox(bm)
    bm.transform(Matrix.Translation(Vector(((lo.x + hi.x) * -0.5, -lo.y, (lo.z + hi.z) * -0.5))))
    bm.transform(Matrix.Diagonal(Vector((1.0 / (hi.x - lo.x), 1.0, 1.0 / (hi.z - lo.z), 1.0))))   # 1 x 1 m
    planar(bm)
    for f in bm.faces:
        f.material_index = 0
    uv = bm.loops.layers.uv.active
    for f in bm.faces:
        for lp in f.loops:
            lp[uv].uv = (lp.vert.co.x + 0.5, lp.vert.co.z + 0.5)
    ob = mesh_obj(name, bm, ["kit_sign_metal"])
    decimate(ob, cap)
    return ob


def build_signs(src: str, report: list) -> list:
    out = []
    names = list(PLATES) + ["Cylinder"]
    objs = load_objects(os.path.join(src, "Placas", "ROAD+SIGNS.blend"), names)
    for oname, (name, cap) in PLATES.items():
        o = _plate(objs[oname], name, cap)
        out.append((name, [o]))
        report.append((name, oname, tri_count(o)))
    bm = evaluated_copy(objs["Cylinder"], "sign_post")      # poste com base: altura 1 m (o jogo estica)
    keep_uv(bm, "UVMap")
    ground_center(bm)
    lo, hi = bbox(bm)
    bm.transform(Matrix.Diagonal(Vector((1.0, 1.0, 1.0 / (hi.z - lo.z), 1.0))))
    planar(bm, 1.0)
    for f in bm.faces:
        f.material_index = 0
    o = mesh_obj("sign_post", bm, ["kit_sign_metal"])
    decimate(o, 90)
    out.append(("sign_post", [o]))
    report.append(("sign_post", "Cylinder", tri_count(o)))
    for ob in objs.values():
        bpy.data.objects.remove(ob, do_unlink=True)
    return out


# ---------------------------------------------------------------- Placao (trelica)
def truss_box(bm, uv, a: Vector, b: Vector, w: float = TRUSS_W, mat: int = 0) -> None:
    """Caixa de secao w x w de `a` ate `b` (eixo X ou Z), faces laterais com a trelica (UV como o nodel.fbx)."""
    axis = (b - a).normalized()
    length = (b - a).length
    side = Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))
    up = axis.cross(side).normalized()
    side = up.cross(axis).normalized()
    h = w * 0.5
    corners = [side * h + up * h, -side * h + up * h, -side * h - up * h, side * h - up * h]
    v0 = [bm.verts.new(a + c) for c in corners]
    v1 = [bm.verts.new(b + c) for c in corners]
    u1 = length / TRUSS_U_M
    for i in range(4):
        j = (i + 1) % 4
        f = bm.faces.new((v0[i], v0[j], v1[j], v1[i]))
        f.material_index = mat
        for lp, (u, v) in zip(f.loops, ((0, TRUSS_V[0]), (0, TRUSS_V[1]), (u1, TRUSS_V[1]), (u1, TRUSS_V[0]))):
            lp[uv].uv = (u, v)
    for vs in (v0[::-1], v1):                            # tampas
        f = bm.faces.new(vs)
        f.material_index = mat
        for lp, (u, v) in zip(f.loops, ((0, TRUSS_V[0]), (0.08, TRUSS_V[0]), (0.08, TRUSS_V[1]), (0, TRUSS_V[1]))):
            lp[uv].uv = (u, v)


def solid_box(bm, uv, lo: Vector, hi: Vector, mat: int = 0) -> None:
    """Caixa de chapa: UV na faixa OPACA cinza do Grade1.png (logo abaixo da trelica), para tudo do portico/outdoor
    sair numa superficie so (uma chamada de desenho)."""
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = r["verts"]
    for v in vs:
        v.co = Vector((lo.x + (v.co.x + 0.5) * (hi.x - lo.x), lo.y + (v.co.y + 0.5) * (hi.y - lo.y),
                       lo.z + (v.co.z + 0.5) * (hi.z - lo.z)))
    faces = {f for v in vs for f in v.link_faces}
    for f in faces:
        f.material_index = mat
        n = f.normal
        for lp in f.loops:
            c = lp.vert.co
            lp[uv].uv = ((c.y if abs(n.x) > 0.5 else c.x) / TRUSS_U_M, SOLID_V)


def build_gantry(report: list) -> list:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for sx in (-1.0, 1.0):
        x = sx * GANTRY_HALF
        truss_box(bm, uv, Vector((x, 0, 0.27)), Vector((x, 0, GANTRY_TOP)))
        solid_box(bm, uv, Vector((x - 0.6, -0.6, 0.0)), Vector((x + 0.6, 0.6, 0.27)))   # sapata
    truss_box(bm, uv, Vector((-GANTRY_HALF - TRUSS_W * 0.5, 0, GANTRY_TOP - TRUSS_W * 0.5)),
              Vector((GANTRY_HALF + TRUSS_W * 0.5, 0, GANTRY_TOP - TRUSS_W * 0.5)))
    o = mesh_obj("gantry_truss", bm, ["kit_truss"])
    report.append(("gantry_truss", "nodel.fbx (refeito 27 m)", tri_count(o)))
    return [("gantry_truss", [o])]


def build_billboard(name: str, leg_h: float, report: list):
    """Outdoor: 2 pernas de trelica, moldura de chapa, passarela e 3 luminarias (tudo `kit_truss`); arte em `kit_art`."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for sx in (-1.0, 1.0):
        x = sx * BILL_W * 0.3
        truss_box(bm, uv, Vector((x, 0.8, 0.0)), Vector((x, 0.8, leg_h + BILL_H)))   # atras da moldura
    solid_box(bm, uv, Vector((-BILL_W * 0.5 - 0.15, 0.02, leg_h - 0.15)), Vector((BILL_W * 0.5 + 0.15, 0.3, leg_h + BILL_H + 0.15)))
    solid_box(bm, uv, Vector((-BILL_W * 0.5, -0.9, leg_h - 0.32)), Vector((BILL_W * 0.5, 0.0, leg_h - 0.24)))   # passarela
    for i in range(3):
        x = (i - 1) * BILL_W * 0.33
        solid_box(bm, uv, Vector((x - 0.04, -1.1, leg_h - 0.3)), Vector((x + 0.04, -0.0, leg_h - 0.22)))
        solid_box(bm, uv, Vector((x - 0.22, -1.25, leg_h - 0.3)), Vector((x + 0.22, -1.0, leg_h - 0.18)))   # luminaria
    o = mesh_obj(name, bm, ["kit_truss"])
    # arte: um quadrado na frente da moldura (UV 0..1), separado para o jogo trocar a textura por painel
    bm2 = bmesh.new()
    uv2 = bm2.loops.layers.uv.new("UVMap")
    vs = [bm2.verts.new(v) for v in ((-BILL_W * 0.5, 0.0, leg_h), (BILL_W * 0.5, 0.0, leg_h),
                                    (BILL_W * 0.5, 0.0, leg_h + BILL_H), (-BILL_W * 0.5, 0.0, leg_h + BILL_H))]
    f = bm2.faces.new(vs)
    for lp, c in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        lp[uv2].uv = c
    art = mesh_obj(name + "_art", bm2, ["kit_art"])
    report.append((name, "nodel.fbx (pernas) + chapa", tri_count(o) + tri_count(art)))
    return [(name, [o, art])]


# ---------------------------------------------------------------- folha de conferencia
def preview(items: list, path: str) -> None:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = sc.render.resolution_y = 320
    sc.world = bpy.data.worlds.new("w")
    tex = {"kit_barrier": "barrier_albedo.png", "kit_sign_metal": "sign_metal.png", "kit_truss": "truss_fence.png"}
    for mn, fn in tex.items():
        m = material(mn)
        nt = m.node_tree
        if nt is None:
            m.use_nodes = True
            nt = m.node_tree
        if not any(n.type == "TEX_IMAGE" for n in nt.nodes):
            img = bpy.data.images.load(os.path.join(OUT_TEX, fn))
            tn = nt.nodes.new("ShaderNodeTexImage")
            tn.image = img
            bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
            nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
            nt.links.new(tn.outputs["Alpha"], bsdf.inputs["Alpha"])
    cam_d = bpy.data.cameras.new("c")
    cam = bpy.data.objects.new("c", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = []
    every = [o for _, objs in items for o in objs]
    for name, objs in items:
        for o in every:
            o.hide_render = o not in objs
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        ctr, rad = (lo + hi) * 0.5, max((hi - lo).length * 0.5, 0.2)
        d = Vector((0.75, -1.0, 0.45)).normalized()
        cam.location = ctr + d * rad * 2.7
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        p = os.path.join(WORK, "prev_" + name + ".png")
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        shots.append(p)
    from lib import preview as PV
    PV.contact_sheet(shots, path, cols=4)


def main() -> None:
    a = args()
    if not os.path.isdir(a["src"]):
        raise SystemExit("ERRO: pasta dos modelos nao encontrada: %s (use --src)" % a["src"])
    clear_scene()
    t = extract_sources(a["src"])
    build_textures(t)
    report: list = []
    items = build_barriers(a["src"], report)
    items += build_signs(a["src"], report)
    items += build_gantry(report)
    items += build_billboard("billboard_low", 7.0, report)
    items += build_billboard("billboard_tall", 16.0, report)
    for name, objs in items:
        export(objs, name)
    for r in report:
        print("KIT %-22s %-34s %5d tri" % r)
    if a["preview"]:
        preview(items, os.path.join(WORK, "contact_sheet.png"))
        print("folha:", os.path.join(WORK, "contact_sheet.png"))
    print("OK kit", len(items), "modelos")


main()
