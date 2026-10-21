"""T-169: fundo de montanha e ondas do mar a partir dos modelos novos de `docs/Modelos/` (liberados pelo Marco; a pasta
fica FORA do Git, so o resultado reduzido entra no jogo).

  Fundo Montanha Gelo/sNOWlaNDSCAPE.fbx (6,3 milhoes de triangulos, 9 macicos nevados num quadrado de 53 unidades)
      -> game/assets/scenery/backdrop/mountain_a..d.glb: os 4 maiores macicos refeitos como malha leve (~900
         triangulos cada) a partir do MAPA DE ALTURA do original (512 x 512, altura maxima por celula). Base em z = 0
         com uma saia que desce abaixo do chao; pegada normalizada (maior lado = 1,0; a altura na mesma proporcao):
         o jogo escala cada copia (600-900 m). Cores por vertice: R = onde a neve pega (altura + parte plana),
         G = sombra das ravinas (cavidade), o shader do jogo decide a quantidade de neve por rota/hora.
  Agua/Water_Pack_Ozero.blend (placa de ondas de 33 m, 280 mil triangulos, sem textura)
      -> game/assets/textures/backdrop/water_waves_nrm.png (512 px): mapa de normais das ondas, repetivel (sem
         emenda: mistura com uma copia deslocada de meia placa), para o mar do litoral (CityBuilder.WATER_SHADER).

Deterministico (sem sorteio). Saida extra com --preview: blender/renders/t169/backdrop_sheet.png.

Uso: blender -b --factory-startup -P blender/scripts/build_backdrop_kit.py --
        [--snow-src "PASTA/docs/Modelos/Fundo Montanha Gelo/sNOWlaNDSCAPE.fbx"]
        [--water-src "PASTA/docs/Modelos/Agua/Water_Pack_Ozero.blend"] [--only mountains|water] [--preview]
"""
from __future__ import annotations

import json
import math
import os
import sys
from collections import deque

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import export as EX  # noqa: E402
import build_roadside_kit as RK  # noqa: E402

OUT_GLB = os.path.join(ROOT, "game", "assets", "scenery", "backdrop")
OUT_TEX = os.path.join(ROOT, "game", "assets", "textures", "backdrop")
WORK = os.path.join(ROOT, "blender", "renders", "t169")
MODELS = os.path.join(ROOT, "docs", "Modelos")

HM_RES = 512            # mapa de altura do relevo
MASSIFS = 4             # quantos macicos viram modelo
GRID = 46               # grade de cada macico antes de reduzir
TARGET_TRIS = 900
WATER_RES = 256         # menor que o espacamento dos vertices (~375 por lado): sem serrilhado
WATER_OUT = 512


def args() -> dict:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"snow": os.path.join(MODELS, "Fundo Montanha Gelo", "sNOWlaNDSCAPE.fbx"),
           "water": os.path.join(MODELS, "Agua", "Water_Pack_Ozero.blend"),
           "only": "", "preview": "--preview" in a}
    for k, key in (("--snow-src", "snow"), ("--water-src", "water"), ("--only", "only")):
        if k in a:
            out[key] = a[a.index(k) + 1]
    return out


# ---------------------------------------------------------------- leitura
def load_points(path: str) -> np.ndarray:
    """Vertices (mundo, com modificadores) de todas as malhas do arquivo, como (n, 3)."""
    before = set(bpy.data.objects)
    ext = os.path.splitext(path)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".glb":
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".blend":
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = list(src.objects)
        for o in dst.objects:
            if o is not None and o.name not in bpy.context.scene.collection.objects:
                bpy.context.scene.collection.objects.link(o)
    else:
        raise SystemExit("formato nao suportado: " + ext)
    new = [o for o in bpy.data.objects if o not in before]
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in new:
        if o.type != "MESH":
            continue
        me = o.evaluated_get(dg).to_mesh()
        co = np.empty(len(me.vertices) * 3, np.float32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        m = np.array(o.matrix_world, dtype=np.float64)
        co = (co @ m[:3, :3].T + m[:3, 3]).astype(np.float32)
        pts.append(co)
        o.evaluated_get(dg).to_mesh_clear()
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    return np.concatenate(pts)


def heightmap(pts: np.ndarray, res: int, mode: str = "max") -> tuple[np.ndarray, tuple]:
    """Altura por celula (linha = y, coluna = x) numa grade quadrada que cobre os pontos; buracos preenchidos."""
    lo = pts[:, :2].min(0)
    hi = pts[:, :2].max(0)
    size = float((hi - lo).max())
    ij = np.clip(((pts[:, :2] - lo) / size * (res - 1)).round().astype(np.int64), 0, res - 1)
    flat = ij[:, 1] * res + ij[:, 0]
    if mode == "max":
        h = np.full(res * res, -np.inf, np.float64)
        np.maximum.at(h, flat, pts[:, 2])
        ok = np.isfinite(h)
    else:
        s = np.bincount(flat, weights=pts[:, 2], minlength=res * res)
        n = np.bincount(flat, minlength=res * res)
        ok = n > 0
        h = np.where(ok, s / np.maximum(n, 1), 0.0)
    h = h.reshape(res, res)
    ok = ok.reshape(res, res)
    for _ in range(64):                                  # buracos: media dos vizinhos ja conhecidos
        if ok.all():
            break
        acc = np.zeros_like(h)
        cnt = np.zeros_like(h)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            hs = np.roll(np.where(ok, h, 0.0), (dy, dx), (0, 1))
            os_ = np.roll(ok, (dy, dx), (0, 1))
            acc += hs
            cnt += os_
        fill = (~ok) & (cnt > 0)
        h[fill] = acc[fill] / cnt[fill]
        ok = ok | fill
    return h, (float(lo[0]), float(lo[1]), size)


def blur(a: np.ndarray, r: int) -> np.ndarray:
    out = a.copy()
    for _ in range(r):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out


def sample(a: np.ndarray, y: np.ndarray, x: np.ndarray) -> np.ndarray:
    """Amostra bilinear de `a` nas coordenadas (linha y, coluna x) em pixels."""
    h, w = a.shape
    x0 = np.clip(np.floor(x).astype(int), 0, w - 1)
    y0 = np.clip(np.floor(y).astype(int), 0, h - 1)
    x1 = np.clip(x0 + 1, 0, w - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    fx = np.clip(x - x0, 0, 1)
    fy = np.clip(y - y0, 0, 1)
    return (a[y0, x0] * (1 - fx) * (1 - fy) + a[y0, x1] * fx * (1 - fy) + a[y1, x0] * (1 - fx) * fy
            + a[y1, x1] * fx * fy)


# ---------------------------------------------------------------- montanhas
def components(mask: np.ndarray) -> list:
    """Ilhas (4 vizinhos) de `mask`: lista de (n_celulas, (y0, y1, x0, x1))."""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    out = []
    for y in range(h):
        row = mask[y]
        for x in np.nonzero(row & ~seen[y])[0]:
            if seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            n, y0, y1, x0, x1 = 0, y, y, x, x
            while q:
                cy, cx = q.popleft()
                n += 1
                y0, y1, x0, x1 = min(y0, cy), max(y1, cy), min(x0, cx), max(x1, cx)
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            out.append((n, (y0, y1, x0, x1)))
    return sorted(out, key=lambda c: -c[0])


def massif_mesh(h: np.ndarray, box: tuple, base: float, thr: float, name: str, px: float) -> tuple:
    """Malha de um macico (grade GRID x GRID sobre o recorte), normalizada e reduzida."""
    y0, y1, x0, x1 = box
    pad = 22
    y0, x0 = max(0, y0 - pad), max(0, x0 - pad)
    y1, x1 = min(h.shape[0] - 1, y1 + pad), min(h.shape[1] - 1, x1 + pad)
    side = max(y1 - y0, x1 - x0)
    cy, cx = (y0 + y1) * 0.5, (x0 + x1) * 0.5
    t = np.linspace(-0.5, 0.5, GRID)
    gy, gx = np.meshgrid(cy + t * side, cx + t * side, indexing="ij")
    hh = sample(h, gy, gx) - base
    r = np.maximum(np.abs(t)[:, None], np.abs(t)[None, :]) * 2.0          # 0 no centro, 1 na borda do recorte
    hh = np.maximum(hh, 0.0) * (1.0 - np.clip((r - 0.72) / 0.28, 0.0, 1.0) ** 2)   # vizinhos somem na borda
    top = float(hh.max())
    hn = np.clip(hh / top, 0.0, 1.0)
    cav = np.clip((hh - blur(hh, 3)) / (top * 0.04) * 0.5 + 0.7, 0.35, 1.0)    # ravinas mais escuras
    lim = 0.03                                           # abaixo disso e chao (vira saia)
    edge = np.zeros_like(hn, bool)
    edge[[0, -1], :] = True
    edge[:, [0, -1]] = True
    z = np.where(hn < lim, -0.06, hn)                    # fora do macico: saia abaixo do chao
    z[edge] = -0.06
    zk = top / (side * px)                               # altura em "lados do recorte" (a grade vai de -0,5 a 0,5)
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    vs = [[bm.verts.new((float(t[j]), float(-t[i]), float(z[i, j] * zk)))
           for j in range(GRID)] for i in range(GRID)]
    keep = hn >= lim * 0.6
    for i in range(GRID - 1):
        for j in range(GRID - 1):
            if not (keep[i, j] or keep[i + 1, j] or keep[i, j + 1] or keep[i + 1, j + 1]):
                continue
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # T-179: a malha e aberta (casca sem fundo); o recalc escolhia "para baixo" como lado de fora e o jogo via a
    # parte de dentro da encosta de tras (escura, "laminas rasgadas"). A casca tem de olhar para cima.
    if sum(f.normal.z * f.calc_area() for f in bm.faces) < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.normal_update()
    # pegada: maior lado = 1, centro em (0, 0), base em z = 0 (a saia fica abaixo)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    s = 1.0 / max(max(xs) - min(xs), max(ys) - min(ys))
    c = Vector(((max(xs) + min(xs)) * 0.5, (max(ys) + min(ys)) * 0.5, 0.0))
    for v in bm.verts:
        v.co = (v.co - c) * s
    o = RK.mesh_obj(name, bm, ["backdrop_mountain"])
    RK.decimate(o, TARGET_TRIS)
    for poly in o.data.polygons:                          # sombreamento suave (ao longe facetas viram serrilhado)
        poly.use_smooth = True
    # cores por vertice depois de reduzir: neve (altura + parte plana) e cavidade (do mapa)
    me = o.data
    zmax = max(v.co.z for v in me.vertices) or 1.0
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    if attr.domain != "CORNER":
        me.color_attributes.remove(attr)
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.calc_loop_triangles()
    vn = [Vector((0, 0, 1))] * len(me.vertices)
    acc = [Vector((0, 0, 0)) for _ in me.vertices]
    for p in me.polygons:
        for vi in p.vertices:
            acc[vi] += p.normal * p.area
    vn = [a.normalized() if a.length > 0 else Vector((0, 0, 1)) for a in acc]
    for p in me.polygons:
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            hfrac = max(co.z, 0.0) / zmax
            flat = max(0.0, min(1.0, (vn[vi].z - 0.25) / 0.6))
            snow = max(0.0, min(1.0, hfrac * 0.75 + flat * 0.35 - 0.05))
            u = (co.x / s + c.x) / 1.0
            gi = int(round((0.5 - (co.y / s + c.y)) * (GRID - 1)))
            gj = int(round((u + 0.5) * (GRID - 1)))
            cv = float(cav[min(max(gi, 0), GRID - 1), min(max(gj, 0), GRID - 1)])
            attr.data[li].color = (snow, cv, hfrac, 1.0)
    info = {"name": name, "cells": None, "height_over_width": round(zmax, 3), "tris": RK.tri_count(o)}
    return o, info


def build_mountains(path: str, report: list) -> list:
    print("lendo", path)
    pts = load_points(path)
    print("pontos", len(pts))
    h, (lx, ly, size) = heightmap(pts, HM_RES, "max")
    del pts
    base = float(np.percentile(h, 8))
    top = float(h.max())
    best = None                                          # limiar que separa mais macicos grandes (vales entre eles)
    for k in range(2, 20):
        frac = 0.03 * k
        cs = components(h > base + (top - base) * frac)
        big = sum(1 for c in cs if c[0] > 1500)
        if best is None or big > best[0]:
            best = (big, frac, cs)
    thr = base + (top - base) * best[1]
    comps = best[2]
    print("limiar", round(best[1], 2), "macicos grandes", best[0])
    print("macicos", [c[0] for c in comps[:10]])
    items = []
    names = "abcdefgh"
    for k, (n, box) in enumerate(comps[:MASSIFS]):
        o, info = massif_mesh(h, box, base, thr, "mountain_" + names[k], size / (HM_RES - 1))
        info["cells"] = n
        report.append(info)
        items.append(("mountain_" + names[k], [o]))
    return items


# ---------------------------------------------------------------- agua
def resize(a: np.ndarray, n: int) -> np.ndarray:
    """Redimensiona uma imagem periodica (bilinear com volta nas bordas)."""
    h, w = a.shape
    y = (np.arange(n) + 0.5) * h / n - 0.5
    x = (np.arange(n) + 0.5) * w / n - 0.5
    gy, gx = np.meshgrid(y, x, indexing="ij")
    y0 = np.floor(gy).astype(int)
    x0 = np.floor(gx).astype(int)
    fy, fx = gy - y0, gx - x0
    y0 %= h
    x0 %= w
    y1, x1 = (y0 + 1) % h, (x0 + 1) % w
    return (a[y0, x0] * (1 - fx) * (1 - fy) + a[y0, x1] * fx * (1 - fy) + a[y1, x0] * (1 - fx) * fy
            + a[y1, x1] * fx * fy)


def build_water(path: str, report: list) -> str:
    pts = load_points(path)
    h, (_, _, size) = heightmap(pts, WATER_RES, "mean")
    m = 6                                                 # borda da placa (ondas cortadas): fora
    h = h[m:-m, m:-m]
    h = blur(h - h.mean(), 1)
    n = h.shape[0]
    w = np.sin(np.pi * np.arange(n) / n) ** 2              # peso da placa; a copia deslocada de meia placa leva 1 - w
    tile = h * w[None, :] + np.roll(h, n // 2, 1) * (1.0 - w)[None, :]          # repete em x (emendas somem)
    tile = tile * w[:, None] + np.roll(tile, n // 2, 0) * (1.0 - w)[:, None]    # repete em y
    tile = resize(tile, WATER_OUT)
    px_m = size * (n / WATER_RES) / WATER_OUT             # metros por pixel da placa
    gx = (np.roll(tile, -1, 1) - np.roll(tile, 1, 1)) / (2 * px_m)
    gy = (np.roll(tile, -1, 0) - np.roll(tile, 1, 0)) / (2 * px_m)
    k = 1.0 / max(float(np.percentile(np.hypot(gx, gy), 98)), 1e-6)   # inclinacao maxima ~45 graus
    nx, ny, nz = -gx * k, gy * k, np.ones_like(gx)        # convencao OpenGL (verde para cima), como o Godot
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    img = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5, np.ones_like(nx)], -1)
    out = os.path.join(OUT_TEX, "water_waves_nrm.png")
    EX.save_png(img.astype(np.float32), out)
    RK.write_import(out, normal=True)
    report.append({"name": "water_waves_nrm.png", "px": WATER_OUT, "tile_m": round(size * n / WATER_RES, 2)})
    return out


# ---------------------------------------------------------------- exportar e conferir
def export(objs: list, name: str) -> str:
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


def preview(items: list, water_png: str, path: str) -> None:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "VERTEX"
    sc.render.resolution_x = 480
    sc.render.resolution_y = 300
    sc.world = bpy.data.worlds.new("w")
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = []
    every = [o for _, objs in items for o in objs]
    for name, objs in items:
        for o in every:
            o.hide_render = o not in objs
        cam.location = Vector((0.15, -1.25, 0.32))
        cam.rotation_euler = (Vector((0, 0, 0.12)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 35
        p = os.path.join(WORK, "prev_%s.png" % name)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        shots.append(p)
    if water_png and os.path.isfile(water_png):         # 2 x 2 placas para ver que nao ha emenda
        a = RK.load_px(water_png)
        t = np.tile(a, (2, 2, 1))
        img = resize_rgba(t, 300, 480)
        p = os.path.join(WORK, "prev_water_tile.png")
        EX.save_png(img, p)
        shots.append(p)
    from lib import preview as PV
    PV.contact_sheet(shots, path, cols=3)


def resize_rgba(a: np.ndarray, h: int, w: int) -> np.ndarray:
    ys = (np.arange(h) * a.shape[0] / h).astype(int)
    xs = (np.arange(w) * a.shape[1] / w).astype(int)
    return a[ys][:, xs].astype(np.float32)


def main() -> None:
    a = args()
    RK.clear_scene()
    for d in (OUT_GLB, OUT_TEX, WORK):
        os.makedirs(d, exist_ok=True)
    report: list = []
    items: list = []
    water = ""
    if a["only"] in ("", "water"):
        if not os.path.isfile(a["water"]):
            raise SystemExit("ERRO: agua nao encontrada: %s (use --water-src)" % a["water"])
        water = build_water(a["water"], report)
    if a["only"] in ("", "mountains"):
        if not os.path.isfile(a["snow"]):
            raise SystemExit("ERRO: relevo nao encontrado: %s (use --snow-src)" % a["snow"])
        items = build_mountains(a["snow"], report)
        for name, objs in items:
            export(objs, name)
    for r in report:
        print("BACKDROP", json.dumps(r))
    if a["preview"]:
        preview(items, water, os.path.join(WORK, "backdrop_sheet.png"))
        print("folha:", os.path.join(WORK, "backdrop_sheet.png"))
    print("OK backdrop", len(items), "montanhas", "agua" if water else "")


main()
