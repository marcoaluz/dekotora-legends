"""T-169/T-186: arvores de folhas (Gleditsia triacanthos, `docs/Modelos/Arvore/`, liberadas pelo Marco; a pasta fica
FORA do Git) reduzidas para o celular. As 6 variacoes do pacote viram 6 arvores do jogo, cada uma com 2 niveis (LOD):

  Gledista_Triacanthos[_2.._6].fbx (unidades em decimetros: 9 a 24 m)
      -> game/assets/scenery/tree_leafy[_b.._f].glb        LOD0 (perto): tronco ~200-260 tri + 20-28 tufos
      -> game/assets/scenery/tree_leafy[_b.._f]_lod1.glb   LOD1 (longe): tronco ~36 tri + 6 tufos
         - tronco e galhos grossos (material da casca) reduzidos, cor por vertice de casca;
         - copa: os triangulos de folha/galhinho/vagem viram grupos (k-medias deterministico dos centros) e cada grupo
           vira 2 cartoes cruzados (4 triangulos) do tamanho do grupo, normais "de volume", miolo mais escuro;
      -> game/assets/textures/backdrop/tree_leafy[_<v>]_leaves.png (512 x 512, 2 x 2 tufos): 4 pedacos da copa ORIGINAL
         renderizados (Cycles, so a cor das texturas, fundo transparente), cada um visto de fora.
  O jogo cria os materiais pelo nome (BackdropKit): "tree_bark" (cor por vertice) e "tree_leaves" (recorte por alfa).

Deterministico. Com --preview: blender/renders/t186/tree_sheet.png (todas as variacoes, LOD0 e LOD1).
Uso: blender -b --factory-startup -P blender/scripts/build_tree_kit.py -- [--src "PASTA/docs/Modelos/Arvore"]
     [--only a,b,c,d,e,f] [--preview]
"""
from __future__ import annotations

import json
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import export as EX  # noqa: E402
from lib import tree_atlas as TA  # noqa: E402
import build_roadside_kit as RK  # noqa: E402

OUT_GLB = os.path.join(ROOT, "game", "assets", "scenery")
OUT_TEX = os.path.join(ROOT, "game", "assets", "textures", "backdrop")
WORK = os.path.join(ROOT, "blender", "renders", "t186")
FBX_DIR = os.path.join("Gledista_Triacanthos_FBX", "Gledista_Triacanthos_FBX")

# variacao -> (arquivo, nome no jogo, escala, tufos LOD0, triangulos do tronco LOD0)
# As 3 primeiras tem 9-11,5 m (decimetros); as 3 ultimas 22-24 m (arvores adultas, ficam com 11-12 m no jogo).
VARIANTS = {
    "a": ("Gledista_Triacanthos.fbx", "tree_leafy", 0.07, 20, 200),
    "b": ("Gledista_Triacanthos_2.fbx", "tree_leafy_b", 0.07, 22, 220),
    "c": ("Gledista_Triacanthos_3.fbx", "tree_leafy_c", 0.065, 24, 240),
    "d": ("Gledista_Triacanthos_4.fbx", "tree_leafy_d", 0.05, 28, 260),
    "e": ("Gledista_Triacanthos_5.fbx", "tree_leafy_e", 0.05, 28, 260),
    "f": ("Gledista_Triacanthos_6.fbx", "tree_leafy_f", 0.05, 28, 260),
}
LOD1_CARDS = 6
LOD1_TRUNK = 36
BARK = (0.30, 0.27, 0.24)


def args() -> dict:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"src": os.path.join(ROOT, "docs", "Modelos", "Arvore"), "preview": "--preview" in a, "only": list(VARIANTS)}
    if "--src" in a:
        out["src"] = a[a.index("--src") + 1]
    if "--only" in a:
        out["only"] = [v for v in a[a.index("--only") + 1].split(",") if v in VARIANTS]
    return out


def leaves_png(name: str) -> str:
    """tree_leafy -> tree_leafy_leaves.png (nome antigo, T-169); tree_leafy_b -> tree_leafy_b_leaves.png."""
    return os.path.join(OUT_TEX, name + "_leaves.png")


def load_variant(src: str, scale: float) -> tuple:
    """Importa o .fbx e devolve (bmesh no chao em metros, indice do material da casca, objeto importado)."""
    bpy.ops.import_scene.fbx(filepath=src, use_image_search=True)
    tree = [o for o in bpy.data.objects if o.type == "MESH"][0]
    bm = bmesh.new()
    bm.from_mesh(tree.data)
    bm.transform(tree.matrix_world)
    bm.transform(Matrix.Scale(scale, 4))
    z0 = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= z0
    bark_i = -1
    for i, m in enumerate(tree.data.materials):          # tronco = imagem "bark reflect" (bark2 = galhos finos)
        col, _ = TA.mat_images(m)
        if col is not None and "bark reflect" in col.name.lower():
            bark_i = i
    if bark_i < 0:
        raise SystemExit("ERRO: material da casca nao encontrado em %s" % src)
    return bm, bark_i, tree


def crown_clusters(bm, bark_i: int, k: int) -> tuple:
    """Centros dos k grupos da copa, raios, eixo do tronco e centro da copa."""
    bm.faces.ensure_lookup_table()
    fol = [f for f in bm.faces if f.material_index != bark_i]
    cen = np.array([f.calc_center_median() for f in fol])
    area = np.array([f.calc_area() for f in fol]) + 1e-6
    axis = np.array([np.average(cen[:, 0], weights=area), np.average(cen[:, 1], weights=area)])
    crown = np.array([axis[0], axis[1], np.average(cen[:, 2], weights=area)])
    c, _ = TA.kmeans(cen[::7], area[::7], k)          # 1 em cada 7 (T-169: igual ao tree_leafy original)
    lab_all = np.argmin(((cen[:, None, :] - c[None, :, :]) ** 2).sum(-1), axis=1)
    radii = np.array([np.percentile(np.linalg.norm(cen[lab_all == j] - c[j], axis=1), 80) if (lab_all == j).any()
                      else 0.5 for j in range(k)])
    counts = np.bincount(lab_all, minlength=k)
    return c, radii, axis, crown, counts


def _keep_big_islands(bm, frac: float) -> None:
    """Tira os galhos soltos pequenos (pedacos com area < frac x a do maior): o decimate nao reduz um pedaco solto a
    menos de ~2 triangulos, e as arvores grandes tem centenas deles (escondidos pela copa)."""
    bm.faces.ensure_lookup_table()
    seen: set = set()
    islands = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, isl = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        islands.append((sum(g.calc_area() for g in isl), isl))
    big = max(a for a, _ in islands)
    drop = [g for a, isl in islands if a < big * frac for g in isl]
    bmesh.ops.delete(bm, geom=drop, context="FACES")


def _simple_trunk(src, top: float):
    """Cone de 6 lados (12 triangulos, sem tampas): raio do pe medido no original, afina ate 45% no topo."""
    pts = np.array([v.co[:] for v in src.verts])
    src.free()
    low = pts[pts[:, 2] < 0.6]
    ctr = low[:, :2].mean(0) if len(low) else np.zeros(2)
    r0 = float(np.percentile(np.linalg.norm(low[:, :2] - ctr, axis=1), 80)) if len(low) else 0.25
    bm = bmesh.new()
    ring = []
    for z, r in ((0.0, r0), (top, r0 * 0.45)):
        ring.append([bm.verts.new((ctr[0] + r * np.cos(a), ctr[1] + r * np.sin(a), z))
                     for a in np.linspace(0, 2 * np.pi, 7)[:-1]])
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((ring[0][i], ring[0][j], ring[1][j], ring[1][i]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def make_tree(bm, bark_i: int, cards: int, trunk_tris: int, name: str) -> bpy.types.Object:
    """Tronco reduzido + cartoes cruzados da copa, num objeto so (materiais tree_bark e tree_leaves)."""
    c, radii, axis, crown, _ = crown_clusters(bm, bark_i, cards)
    trunk = bm.copy()
    trunk.faces.ensure_lookup_table()
    bmesh.ops.delete(trunk, geom=[f for f in trunk.faces if f.material_index != bark_i], context="FACES")
    if cards <= LOD1_CARDS:                              # LOD1: o tronco vira um cone de 6 lados ate o pe da copa
        top = float(np.percentile(c[:, 2], 40)) if len(c) else 3.0   # entra na copa (sem tronco "solto")
        trunk = _simple_trunk(trunk, max(top, 1.5))
    else:
        _keep_big_islands(trunk, 0.03)
    tro = RK.mesh_obj(name + "_trunk", trunk, ["tree_bark"])
    for p_ in tro.data.polygons:
        p_.material_index = 0
    if cards > LOD1_CARDS:
        RK.decimate(tro, trunk_tris)                     # galhos abertos: o decimate para em ~2x o alvo nas grandes
    attr = tro.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for d in attr.data:
        d.color = (*BARK, 1.0)
    leaves = TA.crown_cards(c, radii, axis, crown, name + "_cards")
    bpy.ops.object.select_all(action="DESELECT")
    for o in (tro, leaves):
        o.hide_render = False
        o.select_set(True)
    bpy.context.view_layer.objects.active = tro
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    return obj


def export_tree(obj, name: str) -> str:
    path = os.path.join(OUT_GLB, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_image_format="NONE", export_materials="EXPORT",
                              export_vertex_color="NAME", export_vertex_color_name="Col",
                              export_all_vertex_colors=False)
    return path


def build_variant(src_dir: str, key: str) -> list:
    fname, name, scale, cards, trunk_tris = VARIANTS[key]
    src = os.path.join(src_dir, FBX_DIR, fname)
    if not os.path.isfile(src):
        raise SystemExit("ERRO: arvore nao encontrada: %s (use --src)" % src)
    RK.clear_scene()
    bm, bark_i, tree = load_variant(src, scale)
    c, radii, axis, _, counts = crown_clusters(bm, bark_i, cards)
    tex = leaves_png(name)
    TA.render_atlas(bm, bark_i, tree, c, radii, axis, counts, tex, os.path.join(WORK, name))
    RK.write_import(tex)
    out = []
    for lod, (k, tt, suffix) in enumerate(((cards, trunk_tris, ""), (LOD1_CARDS, LOD1_TRUNK, "_lod1"))):
        obj = make_tree(bm, bark_i, k, tt, name + suffix)
        path = export_tree(obj, name + suffix)
        h = max(v.co.z for v in obj.data.vertices)
        w = max(max(abs(v.co.x), abs(v.co.y)) for v in obj.data.vertices) * 2.0
        info = {"name": name + suffix, "lod": lod, "tris": RK.tri_count(obj), "height_m": round(h, 2),
                "width_m": round(w, 2), "cards": k, "src": fname}
        print("TREE", json.dumps(info))
        out.append((obj, path, info))
    bm.free()
    return out


def main() -> None:
    a = args()
    for d in (OUT_GLB, OUT_TEX, WORK):
        os.makedirs(d, exist_ok=True)
    report = []
    shots = []
    for key in a["only"]:
        res = build_variant(a["src"], key)
        report += [r[2] for r in res]
        if a["preview"]:
            name = VARIANTS[key][1]
            shots += TA.preview_variant([r[0] for r in res], leaves_png(name), WORK, name)
    with open(os.path.join(WORK, "trees.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=1)
    if shots:
        from lib import preview as PV
        PV.contact_sheet(shots, os.path.join(WORK, "tree_sheet.png"), cols=4)
        print("folha:", os.path.join(WORK, "tree_sheet.png"))
    print("OK tree")


main()
