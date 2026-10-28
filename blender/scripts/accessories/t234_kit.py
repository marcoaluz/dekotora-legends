"""Kit de geometria da T-234 (rodas, escapamento, grade e buzina): sólido de revolução (corneta, calota funda),
anel de lâmpadas, textura de colmeia e materiais novos.

Materiais (além dos papéis da T-211 e dos da T-231/T-233, `t233_kit.materials`):
  deco_honey   colmeia dourada da grade (o jogo põe a textura `textures/deco_honey.png` repetida pelo tamanho da grade)
  lamp_amber   lâmpadas âmbar (acendem à noite e seguem o padrão de pisca)
Convenção (Blender): +Y frente, +X direita (para fora na roda e no escapamento direito), +Z cima, metros.
Grupos pelo prefixo do nome: CEN_ = parte da grade que NÃO estica (o sol do meio; `game/scripts/truck/lot5_fit.gd`).
"""
from __future__ import annotations

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

from lib import mesh3d as M

from . import t211_kit as K
from . import t233_kit as Q

HONEY_PNG = "game/assets/vehicles/dekotora/textures/deco_honey.png"
HONEY_CELL = 0.09          # m: uma repetição da textura (2 colunas de favos) no tamanho nominal da grade


def materials(atlas=None) -> dict:
    m = Q.materials(atlas)
    m["honey"] = _honey_mat()
    return m


def _honey_mat():
    mat = bpy.data.materials.get("deco_honey")
    if mat is not None:
        return mat
    mat = bpy.data.materials.new("deco_honey")
    if hasattr(mat, "use_nodes") and not mat.use_nodes:
        mat.use_nodes = True
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if os.path.exists(HONEY_PNG):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(os.path.abspath(HONEY_PNG))
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    b.inputs["Metallic"].default_value = 1.0
    b.inputs["Roughness"].default_value = 0.25
    return mat


def honey_texture(path: str = HONEY_PNG, size: int = 256) -> None:
    """Favos dourados (2 colunas x 2 linhas de hexágonos por repetição, emendando nas bordas): RGBA, buraco = alfa 0.
    O dourado é claro (o material do jogo multiplica pela cor dourada)."""
    from lib import paint2d as P
    h = w = size
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    # grade hexagonal "pontuda em cima": centros em (i * dx + (j % 2) * dx / 2, j * dy)
    dx = w / 2.0
    dy = h / 2.0
    r = dx / math.sqrt(3) * 1.02                   # raio do hexágono (vértice) que encosta nos vizinhos
    best = np.full((h, w), 1e9, np.float32)
    for j in range(-1, 4):
        for i in range(-1, 4):
            cx = i * dx + (j % 2) * dx / 2
            cy = j * dy
            px, py = np.abs(xs - cx), np.abs(ys - cy)
            # distância "hexagonal" (normalizada: 1 = borda do favo)
            d = np.maximum(px * math.sqrt(3) / 2 + py / 2, py) / (r * math.sqrt(3) / 2)
            best = np.minimum(best, d)
    wall = np.clip((best - 0.80) / 0.06, 0.0, 1.0)          # parede do favo = opaco
    shade = 0.75 + 0.25 * np.clip((best - 0.80) / 0.2, 0, 1)
    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., 0] = 1.0 * shade
    rgba[..., 1] = 0.86 * shade
    rgba[..., 2] = 0.55 * shade
    rgba[..., 3] = wall
    os.makedirs(os.path.dirname(path), exist_ok=True)
    P.save_png(rgba, path)


# ----------------------------------------------------------------------------- sólidos de revolução

def lathe(name, prof, mat, axis="Y", seg=16, loc=(0, 0, 0), cap0=False, cap1=False):
    """Perfil [(raio, posição ao longo do eixo), ...] girado em volta do eixo `axis` (X, Y ou Z) a partir de `loc`.
    Raio 0 num ponto = fecha em ponta. `cap0`/`cap1` tampam a primeira/última volta."""
    bm = bmesh.new()
    rings = []
    for r, t in prof:
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            c, s = math.cos(a) * r, math.sin(a) * r
            if axis == "Y":
                p = (c, t, s)
            elif axis == "X":
                p = (t, c, s)
            else:
                p = (c, s, t)
            ring.append(bm.verts.new(Vector(p) + Vector(loc)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(seg):
            bm.faces.new([a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]])
    if cap0:
        bm.faces.new(list(reversed(rings[0])))
    if cap1:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return M._link(name, bm, mat)


def trumpet(name, length, r_pipe, r_bell, mat, loc=(0, 0, 0), seg=14, flare=3):
    """Corneta apontando para +Y: tubo fino que abre em sino (curva exponencial nos últimos 45%)."""
    prof = [(r_pipe, 0.0)]
    n = 6
    for k in range(1, n + 1):
        t = k / n
        y = length * (0.55 + 0.45 * t)
        r = r_pipe + (r_bell - r_pipe) * (t ** flare)
        prof.append((r, y))
    prof.append((r_bell * 0.86, length + 0.004))           # lábio virado para dentro (a boca parece funda)
    prof.append((r_bell * 0.55, length - 0.03))
    return lathe(name, prof, mat, "Y", seg, loc, cap0=True)


def ring_of(name, n, R, size, mat, x=0.0, axis="X", depth=0.02, phase=0.0, round_=True, seg=8):
    """`n` lâmpadas (cilindros curtos ou quadradinhos) num círculo de raio R no plano perpendicular a `axis`."""
    out = []
    for k in range(n):
        a = 2 * math.pi * (k + phase) / n
        y, z = math.sin(a) * R, math.cos(a) * R
        if round_:
            out.append(M.cylinder(f"{name}_{k}", size, depth, (x, y, z), mat, axis=axis, seg=seg))
        else:
            out.append(M.box(f"{name}_{k}", (depth, size * 1.6, size * 1.6), (x, y, z), mat, bevel=0.0, seg=1,
                             rot=(math.degrees(-a), 0, 0)))
    return out


def tag(objs, group):
    return Q.tag(objs, group)
