"""T-163: pecas de cenario tiradas dos modelos de `docs/Modelos/Road_pontes/` (Royalty Free, no AI; a pasta fica FORA
do Git, so o resultado reduzido entra no jogo). Analise dos modelos em docs/ANALISE_ROAD_PONTES.md (T-159).

  Ponte/bridge_model.FBX ("Ponte A")  -> pier_t.glb: o pilar em "T" (coluna arredondada que abre em leque ate o topo).
                                          Os aneis do original (32 lados) sao reamostrados com 16 lados (694 -> ~300
                                          triangulos). Sem textura: o jogo usa o concreto nosso (concrete_streaks.png,
                                          triplanar) e estica a coluna/alarga o leque por pilar (PierT.append).
  road/ (CGTrader)                     -> guardrail_w.glb: guard-rail em "W" (perfil do Metal_Crash_Barrier_01) com 2
                                          postes, 4,36 m; guardrail_w_profile.json: o perfil em W (profundidade,
                                          altura, v da textura) que o RoadMesh varre ao longo da pista (litoral);
                                          textures/kit/guardrail_albedo.png 1024x512 + guardrail_nrm.png 512x256 (a
                                          frente e as costas da lamina recortadas do C_B_1 2048 px; faixa amarela
                                          refletiva tirada: aco galvanizado como no Japao; sem textos).
                                       -> power_pole.glb / power_pole_tr.glb: poste de energia (電柱) de CONCRETO cinza
                                          (o original e de madeira): coluna nossa conica de 8 lados, a travessa e as
                                          maos-francesas do Pylon_01, isoladores do Porcelain_1 trocados por cilindros
                                          de 6 lados nos mesmos lugares e, no _tr, um transformador (柱上変圧器). Cores por
                                          vertice (o jogo poe a textura de concreto). Os fios sao feitos no jogo.

Saida (deterministica): game/assets/scenery/kit/*.glb, game/assets/textures/kit/guardrail_*.png,
blender/renders/t163/contact_sheet.png (com --preview). Os numeros que o jogo precisa (altura do leque, pontos dos
fios) sao impressos no fim e ficam como constantes em game/scripts/road3d/pier_t.gd e power_lines_3d.gd.

Uso: blender -b --factory-startup -P blender/scripts/build_road_pontes_kit.py -- [--src "PASTA/docs/Modelos/Road_pontes"]
     [--pole-src "PASTA/docs/Modelos/poste/Utility_pole.blend"] [--preview]
T-169: com o poste novo (`docs/Modelos/poste/`), a coluna usa o perfil dele e ganha a caixa e o suporte em U dele.
"""
from __future__ import annotations

import json
import math
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
import build_roadside_kit as RK  # noqa: E402  (write_import, export, load_objects, mesh_obj...)

OUT_GLB = os.path.join(ROOT, "game", "assets", "scenery", "kit")
OUT_TEX = os.path.join(ROOT, "game", "assets", "textures", "kit")
WORK = os.path.join(ROOT, "blender", "renders", "t163")

PIER_SIDES = 16
GR_DROP = 0.35          # o guard-rail do kit (topo 1,16 m) desce para o padrao japones (~0,8 m)
GR_LEN = 4.36
# regioes da textura C_B_1 (UV do original, origem embaixo): frente (lado da pista) e costas da lamina em W
GR_FRONT_U = (0.105, 0.197)   # u: baixo -> topo do perfil
GR_FRONT_V = (0.436, 0.868)   # v: comprimento (4,36 m)
GR_BACK_U = (0.207, 0.298)
GR_BACK_V = (0.004, 0.436)
POLE_H = 11.0           # topo da coluna (m), como o original
POLE_R0, POLE_R1 = 0.21, 0.13   # raio no pe e no topo (concreto conico)


# ---------------------------------------------------------------- argumentos
def args() -> dict:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"src": os.path.join(ROOT, "docs", "Modelos", "Road_pontes"), "preview": "--preview" in a,
           "pole_src": os.path.join(ROOT, "docs", "Modelos", "poste", "Utility_pole.blend")}
    if "--src" in a:
        out["src"] = a[a.index("--src") + 1]
    if "--pole-src" in a:                       # T-169: poste de concreto novo (coluna, caixa e suporte em U)
        out["pole_src"] = a[a.index("--pole-src") + 1]
    return out


def colored(bm) -> object:
    return bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")


def paint(bm, faces, col) -> None:
    lay = colored(bm)
    for f in faces:
        for lp in f.loops:
            lp[lay] = (col[0], col[1], col[2], 1.0)


# ---------------------------------------------------------------- pilar em T (Ponte A)
def _ring(pts: list, sides: int) -> list:
    """Reamostra um anel (pontos 2D em volta da origem) em `sides` pontos igualmente espacados no angulo."""
    pts = sorted(pts, key=lambda p: math.atan2(p[1], p[0]))
    out = []
    for k in range(sides):
        th = 2 * math.pi * k / sides - math.pi
        d = (math.cos(th), math.sin(th))
        best = None
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            # raio da origem na direcao d x segmento a-b
            ex, ey = b[0] - a[0], b[1] - a[1]
            den = d[0] * ey - d[1] * ex
            if abs(den) < 1e-9:
                continue
            t = (a[0] * ey - a[1] * ex) / den
            s = (a[0] * d[1] - a[1] * d[0]) / den
            if t > 0 and -1e-6 <= s <= 1 + 1e-6 and (best is None or t < best):
                best = t
        out.append((d[0] * best, d[1] * best))
    return out


def build_pier(src: str, report: list) -> list:
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "Ponte", "bridge_model.FBX"))
    bpy.context.view_layer.update()
    o = bpy.data.objects["Layer:3D_Bridge_Pilon"]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    keep = {v for v in bm.verts if 179.0 < v.co.x < 183.0 and 52.0 < v.co.y < 58.5}   # o pilar mais alto (12,5 m)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in keep], context="VERTS")
    src_tris = sum(len(f.verts) - 2 for f in bm.faces)
    top = max(v.co.z for v in bm.verts)
    tv = [v.co.copy() for v in bm.verts if v.co.z > top - 0.05]
    _, p, q = max(((a - b).length, a, b) for a in tv for b in tv)
    d = q - p
    ang = math.atan2(d.y, d.x)
    lo_z = min(v.co.z for v in bm.verts)
    bm.transform(Matrix.Rotation(-ang, 4, "Z"))                 # largura do topo no eixo X (atravessando a pista)
    base = [v.co for v in bm.verts if v.co.z < lo_z + 0.05]
    cx = (min(c.x for c in base) + max(c.x for c in base)) * 0.5
    cy = (min(c.y for c in base) + max(c.y for c in base)) * 0.5
    bm.transform(Matrix.Translation(Vector((-cx, -cy, -lo_z))))
    levels: dict = {}
    for v in bm.verts:                                          # aneis com muitos pontos (os de 5-13 sao detalhes)
        levels.setdefault(round(v.co.z, 2), []).append((v.co.x, v.co.y))
    rings = sorted((z, pts) for z, pts in levels.items() if len(pts) >= 20)
    merged = []
    for z, pts in rings:                                        # junta niveis a menos de 2 cm
        if merged and z - merged[-1][0] < 0.02:
            merged[-1][1].extend(pts)
        else:
            merged.append([z, list(pts)])
    bm.free()
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    out = bmesh.new()
    uv = out.loops.layers.uv.new("UVMap")
    rows = []
    for z, pts in merged:
        r = _ring(pts, PIER_SIDES)
        rows.append([out.verts.new((x, y, z)) for x, y in r])
    for a, b in zip(rows, rows[1:]):
        for k in range(PIER_SIDES):
            k2 = (k + 1) % PIER_SIDES
            f = out.faces.new((a[k], a[k2], b[k2], b[k]))
            for lp in f.loops:
                lp[uv].uv = ((k + (1 if lp.vert in (a[k2], b[k2]) else 0)) / PIER_SIDES * 2.0, lp.vert.co.z / 4.0)
    cap = out.faces.new(rows[-1])                               # tampa de cima (fica escondida sob o tabuleiro)
    for lp in cap.loops:
        lp[uv].uv = (lp.vert.co.x / 4.0, lp.vert.co.y / 4.0)
    bmesh.ops.triangulate(out, faces=out.faces[:])
    bmesh.ops.recalc_face_normals(out, faces=out.faces[:])
    ob = RK.mesh_obj("pier_t", out, ["pier_concrete"])
    for poly in ob.data.polygons:
        poly.use_smooth = True
    zs = [z for z, _ in merged]
    flare = next(z for z in zs if z > 1.0)                      # 1o anel acima do pe = inicio do leque
    top_ring = merged[-1][1]
    info = {"flare_z": round(flare, 3), "top_z": round(zs[-1], 3),
            "top_w": round(max(p[0] for p in top_ring) - min(p[0] for p in top_ring), 3),
            "top_d": round(max(p[1] for p in top_ring) - min(p[1] for p in top_ring), 3),
            "col_w": round(max(p[0] for p in merged[0][1]) - min(p[0] for p in merged[0][1]), 3),
            "col_d": round(max(p[1] for p in merged[0][1]) - min(p[1] for p in merged[0][1]), 3),
            "rings": len(merged)}
    report.append(("pier_t", "Pilon (pilar 12,5 m) %d tri" % src_tris, RK.tri_count(ob)))
    print("PIER", json.dumps(info))
    return [("pier_t", [ob])]


# ---------------------------------------------------------------- guard-rail em W (kit road)
def _crop(img: np.ndarray, u: tuple, v: tuple) -> np.ndarray:
    """Recorte da imagem (linha 0 = topo) na regiao UV (u0..u1, v0..v1), virado para: x = comprimento (v do original),
    y = perfil (linha 0 = topo do perfil = u1)."""
    h, w = img.shape[:2]
    x0, x1 = int(round(u[0] * w)), int(round(u[1] * w))
    y0, y1 = int(round((1.0 - v[1]) * h)), int(round((1.0 - v[0]) * h))
    c = img[y0:y1, x0:x1]                    # linhas = comprimento (topo = v1), colunas = perfil (esq = u0 = baixo)
    c = np.transpose(c, (1, 0, 2))[::-1]     # linhas = perfil (topo = u1), colunas = comprimento (esq = v1)
    return c[:, ::-1].copy()                 # esq = v0


def _resize(a: np.ndarray, w: int, h: int) -> np.ndarray:
    ys = (np.arange(h) + 0.5) * a.shape[0] / h
    xs = (np.arange(w) + 0.5) * a.shape[1] / w
    y0 = np.clip(np.floor(ys - 0.5).astype(int), 0, a.shape[0] - 1)
    x0 = np.clip(np.floor(xs - 0.5).astype(int), 0, a.shape[1] - 1)
    y1 = np.clip(y0 + 1, 0, a.shape[0] - 1)
    x1 = np.clip(x0 + 1, 0, a.shape[1] - 1)
    fy = np.clip(ys - 0.5 - y0, 0, 1)[:, None, None]
    fx = np.clip(xs - 0.5 - x0, 0, 1)[None, :, None]
    top = a[y0][:, x0] * (1 - fx) + a[y0][:, x1] * fx
    bot = a[y1][:, x0] * (1 - fx) + a[y1][:, x1] * fx
    return top * (1 - fy) + bot * fy


def _box_area(img: np.ndarray, w: int, h: int) -> np.ndarray:
    """Reducao por media de blocos (o recorte e maior que a saida)."""
    return _resize(img, w, h)


def build_guardrail_textures(src: str) -> None:
    maps = os.path.join(src, "road", "Model", "Model", "Maps")
    col = RK.load_px(os.path.join(maps, "C_B_1_Base_color.jpg"))
    nrm = RK.load_px(os.path.join(maps, "C_B_1_Normal_OpenGL.png"))
    out_c = np.ones((512, 1024, 4), np.float32)
    out_n = np.ones((256, 512, 4), np.float32)
    for k, (uu, vv) in enumerate(((GR_FRONT_U, GR_FRONT_V), (GR_BACK_U, GR_BACK_V))):
        c = _crop(col, uu, vv)
        out_c[k * 256:(k + 1) * 256] = _box_area(c, 1024, 256)
        n = _crop(nrm, uu, vv)
        out_n[k * 128:(k + 1) * 128] = _box_area(n, 512, 128)
    rgb = out_c[..., :3]
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    yellow = (rgb[..., 0] > 0.42) & (rgb[..., 0] - rgb[..., 2] > 0.22) & (rgb[..., 1] > 0.28)
    yellow = np.array([np.convolve(r.astype(np.float32), np.ones(9), "same") > 0 for r in yellow])   # borda junto
    fill = rgb.copy()                                            # faixa amarela -> o aco da mesma linha (galvanizado),
    todo = yellow.copy()                                         # copiado de um pedaco ao lado (mantem a sujeira)
    for dx in (170, -170, 340, -340, 510):
        src_ok = ~np.roll(yellow, -dx, axis=1)
        take = todo & src_ok
        fill[take] = np.roll(rgb, -dx, axis=1)[take]
        todo &= ~take
    rgb[:] = np.where(yellow[..., None], fill, rgb)
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)          # ferrugem mais discreta (55% da saturacao)
    rgb[:] = lum[..., None] + (rgb - lum[..., None]) * 0.55
    out_c[..., :3] = np.clip(rgb * 1.08 + 0.03, 0, 1)
    out_c[..., 3] = 1.0
    out_n[..., 3] = 1.0
    EX.save_png(out_c, os.path.join(OUT_TEX, "guardrail_albedo.png"))
    EX.save_png(out_n, os.path.join(OUT_TEX, "guardrail_nrm.png"))
    RK.write_import(os.path.join(OUT_TEX, "guardrail_albedo.png"))
    RK.write_import(os.path.join(OUT_TEX, "guardrail_nrm.png"), normal=True)


def _gr_profile(src: str) -> list:
    """Perfil em W da frente da lamina (lado da pista) na ponta do Metal_Crash_Barrier_01: [(profundidade, altura, v)]
    de baixo para cima; profundidade 0 = face dos postes, positiva para a pista; v na nossa textura (0 topo, 0,5 baixo)."""
    objs = RK.load_objects(os.path.join(src, "road", "Model", "Model", "Models.blend"), ["Metal_Crash_Barrier_01"])
    o = objs["Metal_Crash_Barrier_01"]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    uv = bm.loops.layers.uv.active
    front = [lp for f in bm.faces for lp in f.loops
             if GR_FRONT_U[0] - 1e-3 <= lp[uv].uv.x <= GR_FRONT_U[1] + 1e-3 and lp[uv].uv.y > GR_FRONT_V[0] - 1e-3]
    xmin = min(lp.vert.co.x for lp in front)
    pts = {}
    for lp in front:
        if abs(lp.vert.co.x - xmin) < 1e-3:
            pts[round(lp[uv].uv.x, 4)] = (lp.vert.co.y, lp.vert.co.z)
    post_face = max(v.co.y for v in bm.verts if v.co.z < 0.7)   # face dos postes do lado da pista
    bm.free()
    bpy.data.objects.remove(o, do_unlink=True)
    prof = []
    for u in sorted(pts):
        y, z = pts[u]
        v = (GR_FRONT_U[1] - u) / (GR_FRONT_U[1] - GR_FRONT_U[0]) * 0.5
        prof.append([round(y - post_face, 4), round(z - GR_DROP, 4), round(v, 4)])
    # simplifica: tira pontos quase alinhados (menos de 6 mm fora da reta dos vizinhos)
    keep = [prof[0]]
    for i in range(1, len(prof) - 1):
        a, b, c = keep[-1], prof[i], prof[i + 1]
        ab = Vector((c[0] - a[0], c[1] - a[1]))
        ap = Vector((b[0] - a[0], b[1] - a[1]))
        dist = abs(ab.x * ap.y - ab.y * ap.x) / max(ab.length, 1e-6)
        if dist > 0.006:
            keep.append(b)
    keep.append(prof[-1])
    return keep


def build_guardrail(src: str, report: list) -> list:
    build_guardrail_textures(src)
    prof = _gr_profile(src)
    with open(os.path.join(OUT_GLB, "guardrail_w_profile.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"source": "road/Model/Model/Models.blend Metal_Crash_Barrier_01 (CGTrader, Royalty Free)",
                   "drop_m": GR_DROP, "length_m": GR_LEN, "points": prof,
                   "post": {"w": 0.15, "d": 0.1, "top": round(1.22 - GR_DROP, 3), "v": [0.55, 0.95]}}, f, indent=1)
    # peca de 4,36 m para as curvas: lamina (o mesmo perfil) + 2 postes, comprimento em Y, pista em -Y (frente)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for side in (-1.0, 1.0):                                    # frente e costas (sem material de duas faces)
        rows = []
        for y in (-GR_LEN * 0.5, GR_LEN * 0.5):
            rows.append([bm.verts.new((0.0, 0.0, 0.0)) for _ in prof])
            for vtx, p in zip(rows[-1], prof):
                vtx.co = Vector((-(p[0] + 0.1) if side > 0 else -(p[0] + 0.097), y, p[1]))
        for k in range(len(prof) - 1):
            quad = (rows[0][k], rows[1][k], rows[1][k + 1], rows[0][k + 1])
            f = bm.faces.new(quad if side > 0 else quad[::-1])
            for lp in f.loops:
                kk = k if lp.vert in (rows[0][k], rows[1][k]) else k + 1
                along = 0.0 if lp.vert in rows[0] else 1.0
                v = prof[kk][2] if side > 0 else 1.0 - prof[kk][2]
                lp[uv].uv = (along, 1.0 - v)
    for py in (-GR_LEN * 0.5 + 0.35, GR_LEN * 0.5 - 0.35):     # postes (atras da lamina)
        r = bmesh.ops.create_cube(bm, size=1.0)
        for vtx in r["verts"]:
            vtx.co = Vector((0.05 + vtx.co.x * 0.1, py + vtx.co.y * 0.15, (vtx.co.z + 0.5) * (1.22 - GR_DROP)))
        for f in {f for vtx in r["verts"] for f in vtx.link_faces}:
            for lp in f.loops:
                c = lp.vert.co
                lp[uv].uv = ((c.x + c.y) * 0.5, 1.0 - (0.55 + 0.4 * c.z / (1.22 - GR_DROP)))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    ob = RK.mesh_obj("guardrail_w", bm, ["kit_guardrail"])
    report.append(("guardrail_w", "Metal_Crash_Barrier_01 372 tri", RK.tri_count(ob)))
    print("GUARDRAIL_PROFILE", json.dumps(prof))
    return [("guardrail_w", [ob])]


# ---------------------------------------------------------------- poste de energia (kit road)
CONCRETE = (0.66, 0.66, 0.64)
STEEL = (0.42, 0.43, 0.45)
PORCELAIN = (0.86, 0.87, 0.9)
TRANSFORMER = (0.6, 0.64, 0.62)


def _cyl(bm, c: Vector, r0: float, r1: float, h: float, sides: int, col, cap: bool = True) -> None:
    lo = [bm.verts.new(c + Vector((r0 * math.cos(2 * math.pi * k / sides), r0 * math.sin(2 * math.pi * k / sides), 0)))
          for k in range(sides)]
    hi = [bm.verts.new(c + Vector((r1 * math.cos(2 * math.pi * k / sides), r1 * math.sin(2 * math.pi * k / sides), h)))
          for k in range(sides)]
    faces = [bm.faces.new((lo[k], lo[(k + 1) % sides], hi[(k + 1) % sides], hi[k])) for k in range(sides)]
    if cap:
        faces.append(bm.faces.new(hi))
    paint(bm, faces, col)


def _new_pole_parts(path: str) -> dict:
    """T-169: do poste de concreto `docs/Modelos/poste/Utility_pole.blend` (Royalty Free, liberado pelo Marco) tira a
    coluna (raio no pe e no topo, para 11 m de altura), a caixa cilindrica pendurada e o suporte em U de baixo. Os
    feixes de cabos (24 m, 37 mil triangulos cada) e os cabos pretos saem: os fios sao feitos no jogo. Devolve as
    medidas ja na escala do nosso poste (11 m), no sistema do poste original (cabos ao longo de X)."""
    if not path or not os.path.isfile(path):
        return {}
    with bpy.data.libraries.load(path, link=False) as (s, d):
        d.objects = list(s.objects)
    src = [o for o in d.objects if o is not None and o.type == "MESH"][0]
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bm.transform(src.matrix_world)
    mats = [m.name if m else "" for m in src.data.materials]
    z0 = min(v.co.z for v in bm.verts)
    cement = [v.co for f in bm.faces if mats[f.material_index] == "Cement" for v in f.verts]
    top = max(c.z for c in cement)
    k = POLE_H / (top - z0)
    r0 = max(math.hypot(c.x, c.y) for c in cement if c.z < z0 + 1.0) * k
    r1 = max(math.hypot(c.x, c.y) for c in cement if c.z > top - 1.0) * k
    # ilhas pequenas de metal (caixa, suportes): caixa = a de 508 faces; suporte em U de baixo = alto e fino, ~9 m
    bm.faces.ensure_lookup_table()
    seen, boxes = set(), []
    for f in bm.faces:
        if f.index in seen or mats[f.material_index] != "Metal":
            continue
        st, grp = [f], []
        seen.add(f.index)
        while st:
            g = st.pop()
            grp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        st.append(h)
        co = [v.co for g in grp for v in g.verts]
        lo = Vector([min(c[i] for c in co) for i in range(3)])
        hi = Vector([max(c[i] for c in co) for i in range(3)])
        boxes.append((len(grp), (lo - Vector((0, 0, z0))) * k, (hi - Vector((0, 0, z0))) * k))
    bm.free()
    for o in d.objects:
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    can = next((b for b in boxes if 300 < b[0] < 800 and (b[2] - b[1]).z > 0.3), None)
    brackets = sorted((b for b in boxes if (b[2] - b[1]).z > 0.35 and (b[2] - b[1]).x < 0.05 and (b[2] - b[1]).length < 1.0),
                      key=lambda b: b[1].z)
    return {"r0": r0, "r1": r1, "can": can, "bracket": brackets[0] if brackets else None,
            "tris": sum(b[0] for b in boxes), "scale": k}


def _box_lohi(bm, lo: Vector, hi: Vector, col) -> None:
    r = bmesh.ops.create_cube(bm, size=1.0)
    c, s = (lo + hi) * 0.5, hi - lo
    for vtx in r["verts"]:
        vtx.co = Vector((c.x + vtx.co.x * s.x, c.y + vtx.co.y * s.y, c.z + vtx.co.z * s.z))
    paint(bm, {f for vtx in r["verts"] for f in vtx.link_faces}, col)


def _add_new_pole_hardware(bm, parts: dict) -> None:
    """Caixa e suporte em U do poste novo. No original os cabos correm em X e o suporte sai em -Y; no nosso poste (ja
    girado) os fios correm em Y: gira +90 graus (x, y) -> (-y, x)."""
    rot = lambda v: Vector((-v.y, v.x, v.z))  # noqa: E731
    def lohi(lo, hi):
        a, b = rot(lo), rot(hi)
        return Vector((min(a.x, b.x), min(a.y, b.y), lo.z)), Vector((max(a.x, b.x), max(a.y, b.y), hi.z))
    if parts.get("can"):
        _, lo, hi = parts["can"]
        lo, hi = lohi(lo, hi)
        _cyl(bm, Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z)), (hi.x - lo.x) * 0.5, (hi.x - lo.x) * 0.5,
             hi.z - lo.z, 6, TRANSFORMER)
    if parts.get("bracket"):
        _, lo, hi = parts["bracket"]
        lo, hi = lohi(lo, hi)
        t = 0.035                                                      # barra de ~3,5 cm (o original tem 2 cm)
        far = lo.x if abs(lo.x) > abs(hi.x) else hi.x
        x0, x1 = (min(0.0, far), max(0.0, far))
        _box_lohi(bm, Vector((x0, -t, hi.z - t)), Vector((x1, t, hi.z)), STEEL)            # braco de cima
        _box_lohi(bm, Vector((x0, -t, lo.z)), Vector((x1, t, lo.z + t)), STEEL)            # braco de baixo
        _box_lohi(bm, Vector((far - t, -t, lo.z)), Vector((far + t, t, hi.z)), STEEL)      # barra de pe


def build_pole(src: str, report: list, pole_src: str = "") -> list:
    newp = _new_pole_parts(pole_src)
    objs = RK.load_objects(os.path.join(src, "road", "Model", "Model", "Models.blend"), ["Pylon_01", "Porcelain_1"])
    pylon = RK.evaluated_copy(objs["Pylon_01"], "pylon")
    pylon.faces.ensure_lookup_table()
    # ilhas do Pylon_01: a coluna de madeira (a mais alta) sai; travessa e maos-francesas ficam
    seen, parts = set(), []
    for f in pylon.faces:
        if f.index in seen:
            continue
        st, grp = [f], []
        seen.add(f.index)
        while st:
            g = st.pop()
            grp.append(g)
            for vtx in g.verts:
                for h in vtx.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        st.append(h)
        parts.append(grp)
    column = max(parts, key=lambda g: max(v.co.z for f in g for v in f.verts) - min(v.co.z for f in g for v in f.verts))
    cverts = {v for f in column for v in f.verts}
    pc = Vector((sum(v.co.x for v in cverts) / len(cverts), sum(v.co.y for v in cverts) / len(cverts), 0.0))
    small = [g for g in parts if len(g) > 100]                  # parafusos redondos de 216 faces: saem
    drop = {v for g in parts if g is column or g in small for f in g for v in f.verts}
    bmesh.ops.delete(pylon, geom=list(drop), context="VERTS")
    # isoladores: centro e topo de cada um (pontos dos fios)
    por = RK.evaluated_copy(objs["Porcelain_1"], "por")
    por.faces.ensure_lookup_table()
    seen, ins = set(), []
    for f in por.faces:
        if f.index in seen:
            continue
        st, grp = [f], []
        seen.add(f.index)
        while st:
            g = st.pop()
            grp.append(g)
            for vtx in g.verts:
                for h in vtx.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        st.append(h)
        co = [v.co for g in grp for v in g.verts]
        ins.append((Vector([min(c[i] for c in co) for i in range(3)]), Vector([max(c[i] for c in co) for i in range(3)])))
    por.free()
    # agrupa as ilhas do isolador pela posicao (cada isolador tem 3 ilhas)
    stacks: list = []
    for lo, hi in ins:
        ctr = (lo + hi) * 0.5
        for s in stacks:
            if abs(s[0].y - ctr.y) < 0.3:
                s[1] = Vector((min(s[1].x, lo.x), min(s[1].y, lo.y), min(s[1].z, lo.z)))
                s[2] = Vector((max(s[2].x, hi.x), max(s[2].y, hi.y), max(s[2].z, hi.z)))
                break
        else:
            stacks.append([ctr, lo.copy(), hi.copy()])
    bm = bmesh.new()
    tmp = bpy.data.meshes.new("tmp")
    pylon.to_mesh(tmp)
    pylon.free()
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    bm.transform(Matrix.Translation(-pc))
    paint(bm, bm.faces[:], STEEL)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(3.0), verts=bm.verts[:], edges=bm.edges[:], delimit={"NORMAL"})
    r0, r1 = (newp["r0"], newp["r1"]) if newp else (POLE_R0, POLE_R1)   # T-169: perfil da coluna do poste novo
    _cyl(bm, Vector((0, 0, 0)), r0, r1, POLE_H, 8, CONCRETE)
    wires = []
    for _, lo, hi in sorted(stacks, key=lambda s: s[0].y):
        c = Vector(((lo.x + hi.x) * 0.5 - pc.x, (lo.y + hi.y) * 0.5 - pc.y, lo.z))
        h = hi.z - lo.z
        _cyl(bm, c, 0.07, 0.05, h * 0.85, 6, PORCELAIN)
        _cyl(bm, c + Vector((0, 0, h * 0.55)), 0.11, 0.09, 0.06, 6, PORCELAIN, cap=False)   # saia do isolador
        wires.append((c.x, c.y, lo.z + h * 0.85))
    # o modelo tem o comprimento da travessa em Y: girar para X (atravessando a pista no jogo)
    bm.transform(Matrix.Rotation(-math.pi / 2, 4, "Z"))
    wires = [(-y, x, z) for x, y, z in wires]
    # 2a travessa baixa (cabo de telefone, como nos postes japoneses) e o ponto do cabo
    r = bmesh.ops.create_cube(bm, size=1.0)
    for vtx in r["verts"]:
        vtx.co = Vector((vtx.co.x * 0.9, 0.0 + vtx.co.y * 0.08 - 0.2, 7.6 + vtx.co.z * 0.08))
    paint(bm, {f for vtx in r["verts"] for f in vtx.link_faces}, STEEL)
    wires.append((0.45, -0.2, 7.45))
    if newp:
        _add_new_pole_hardware(bm, newp)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm2 = bm.copy()
    ob = RK.mesh_obj("power_pole", bm, ["pole_concrete"])
    # variante com transformador (柱上変圧器) pendurado no poste
    _cyl(bm2, Vector((0.0, 0.42, 8.1)), 0.32, 0.32, 0.95, 8, TRANSFORMER)
    r = bmesh.ops.create_cube(bm2, size=1.0)
    for vtx in r["verts"]:
        vtx.co = Vector((vtx.co.x * 0.16, 0.22 + vtx.co.y * 0.3, 8.55 + vtx.co.z * 0.7))
    paint(bm2, {f for vtx in r["verts"] for f in vtx.link_faces}, STEEL)
    bmesh.ops.triangulate(bm2, faces=bm2.faces[:])
    ob2 = RK.mesh_obj("power_pole_tr", bm2, ["pole_concrete"])
    for o in objs.values():
        bpy.data.objects.remove(o, do_unlink=True)
    if newp:
        print("NEW_POLE", json.dumps({"r0": round(newp["r0"], 3), "r1": round(newp["r1"], 3),
                                      "metal_tris": newp["tris"], "scale": round(newp["scale"], 4)}))
    report.append(("power_pole", "Pylon_01 1434 + Porcelain_1 7452 tri" + (" + poste novo" if newp else ""),
                   RK.tri_count(ob)))
    report.append(("power_pole_tr", "(+ transformador)", RK.tri_count(ob2)))
    # pontos dos fios no sistema do Godot (x, y = altura, z = -y do Blender)
    print("POLE_WIRES", json.dumps([[round(x, 3), round(z, 3), round(-y, 3)] for x, y, z in wires]))
    return [("power_pole", [ob]), ("power_pole_tr", [ob2])]


def export(objs: list, name: str) -> str:
    """Como RK.export, mas leva as cores por vertice (COLOR_0) do poste."""
    path = os.path.join(OUT_GLB, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_image_format="NONE", export_materials="EXPORT",
                              export_vertex_color="NAME", export_vertex_color_name="Col",
                              export_all_vertex_colors=False)
    return path


# ---------------------------------------------------------------- folha de conferencia
def preview(items: list, path: str) -> None:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "VERTEX"
    sc.render.resolution_x = sc.render.resolution_y = 360
    sc.world = bpy.data.worlds.new("w")
    cam_d = bpy.data.cameras.new("c")
    cam = bpy.data.objects.new("c", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = []
    every = [o for _, objs in items for o in objs]
    for name, objs in items:
        for o in every:
            o.hide_render = o not in objs
        if name == "guardrail_w":
            sc.display.shading.color_type = "TEXTURE"
            m = bpy.data.materials["kit_guardrail"]
            nt = m.node_tree
            if not any(n.type == "TEX_IMAGE" for n in nt.nodes):
                tn = nt.nodes.new("ShaderNodeTexImage")
                tn.image = bpy.data.images.load(os.path.join(OUT_TEX, "guardrail_albedo.png"))
                bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
                nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            sc.display.shading.color_type = "VERTEX" if name.startswith("power") else "MATERIAL"
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        ctr, rad = (lo + hi) * 0.5, max((hi - lo).length * 0.5, 0.2)
        for d in (Vector((0.75, -1.0, 0.35)), Vector((-0.2, -1.0, 0.05))):
            cam.location = ctr + d.normalized() * rad * 2.4
            cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
            p = os.path.join(WORK, "prev_%s_%d.png" % (name, len(shots)))
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            shots.append(p)
    from lib import preview as PV
    PV.contact_sheet(shots, path, cols=4)


def main() -> None:
    a = args()
    if not os.path.isdir(a["src"]):
        raise SystemExit("ERRO: pasta dos modelos nao encontrada: %s (use --src)" % a["src"])
    RK.clear_scene()
    os.makedirs(OUT_GLB, exist_ok=True)
    os.makedirs(OUT_TEX, exist_ok=True)
    os.makedirs(WORK, exist_ok=True)
    report: list = []
    items = build_pier(a["src"], report)
    items += build_guardrail(a["src"], report)
    items += build_pole(a["src"], report, a["pole_src"])
    for name, objs in items:
        export(objs, name)
    for r in report:
        print("KIT %-16s %-40s %5d tri" % r)
    if a["preview"]:
        preview(items, os.path.join(WORK, "contact_sheet.png"))
        print("folha:", os.path.join(WORK, "contact_sheet.png"))
    print("OK road_pontes", len(items), "modelos")


main()
