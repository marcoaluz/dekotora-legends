"""Kit de geometria das peças da oficina (T-211: deque frontal e viseira, depois os outros lotes).

Materiais por PAPEL (o jogo troca a cor de cada papel pela tabela de cores L/R, `game/data/deco_colors/`):
  deco_body  estrutura (preto, cromo, prata, branco, dourado...)
  deco_trim  painéis secundários (azul-marinho na versão prata, preto na versão preta)
  deco_led   matriz de LED (quadradinhos)
  deco_neon  faixas, colunas e tubos de neon
  acrylic_sign  letreiro de acrílico (atlas de nomes prontos; o jogo escolhe a célula pela UV)
  acrylic_art   painéis pintados (mesmo atlas, células fixas)
  chrome        frisos cromados que não mudam de cor
Convenção: +Y frente, +X direita, +Z cima, metros; origem = ponto do encaixe (base, atrás, no centro).
"""
from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Vector

from lib import mesh3d as M
from lib.palette import hex_to_rgb, lin

ATLAS_COLS, ATLAS_ROWS = 4, 4          # atlas 1024 x 512: células 256 x 128 (2:1)
ART_CELLS = (12, 13, 14, 15)          # células dos painéis pintados (ondas, sakura, raios, nuvens)


def _mat(name, hex_color, metal=0.0, rough=0.4, emit=0.0):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = lin(hex_to_rgb(hex_color)) + (1.0,)
    b.inputs["Base Color"].default_value = c
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = c
        b.inputs["Emission Strength"].default_value = emit
    return m


def _atlas_mat(name, image, strength):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = nt.nodes.new("ShaderNodeTexImage")
    if image is not None:
        t.image = image
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = strength
    b.inputs["Roughness"].default_value = 0.25
    return m


def materials(atlas=None, night=False) -> dict:
    """Cores padrão (versão "preto + ciano"): o jogo troca pelos presets. `night` = luzes mais fortes na prévia."""
    k = 2.2 if night else 1.0
    return {
        "body": _mat("deco_body", "#15171c", 0.35, 0.28),
        "trim": _mat("deco_trim", "#0b0d12", 0.2, 0.45),
        "led": _mat("deco_led", "#22ff3c", 0.0, 0.5, 1.6 * k),
        "neon": _mat("deco_neon", "#14d9ff", 0.0, 0.5, 2.0 * k),
        "sign": _atlas_mat("acrylic_sign", atlas, 0.8 * k),
        "art": _atlas_mat("acrylic_art", atlas, 0.5 * k),
        "chrome": _mat("chrome", "#e6ebf2", 1.0, 0.07),
    }


def recolor(m: dict, body, trim, led, neon, metal=0.35) -> None:
    """Prévia de outra cor L/R (só no Blender; no jogo quem troca é o DecoStyle)."""
    for key, hx in (("body", body), ("trim", trim), ("led", led), ("neon", neon)):
        b = next(n for n in m[key].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = lin(hex_to_rgb(hx)) + (1.0,)
        if key in ("led", "neon"):
            b.inputs["Emission Color"].default_value = lin(hex_to_rgb(hx)) + (1.0,)
        elif key == "body":
            b.inputs["Metallic"].default_value = metal
            b.inputs["Roughness"].default_value = 0.08 if metal > 0.9 else 0.28


# ----------------------------------------------------------------------------- formas básicas

def mesh_from(name, verts, faces, mat):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def wedge_box(name, W, D, H, top_inset, mat, y0=0.0, z0=0.0, side_inset=0.0, bevel=0.012):
    """Caixa com a frente inclinada para trás (o topo da frente recua `top_inset`); `side_inset` afina o topo nas
    laterais. Base em z0, costas em y0, frente da base em y0 + D."""
    w0, w1 = W / 2, W / 2 - side_inset
    v = [(-w0, y0, z0), (w0, y0, z0), (w0, y0 + D, z0), (-w0, y0 + D, z0),
         (-w1, y0, z0 + H), (w1, y0, z0 + H), (w1, y0 + D - top_inset, z0 + H), (-w1, y0 + D - top_inset, z0 + H)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)]
    o = mesh_from(name, v, f, mat)
    if bevel > 0:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        M._bevel(bm, bevel, 1)
        bm.to_mesh(o.data)
        bm.free()
    return o


class Face:
    """Plano de uma face da peça: origem `o` (canto de baixo à esquerda), eixos `u` (largura) e `v` (altura), normal
    para fora `n`. Coloca coisas em coordenadas da face (s em 0..1 ao longo de u, t em 0..1 ao longo de v)."""

    def __init__(self, o, u, v):
        self.o, self.u, self.v = Vector(o), Vector(u), Vector(v)
        self.n = self.u.cross(self.v).normalized()

    def at(self, s, t, off=0.0):
        return self.o + self.u * s + self.v * t + self.n * off


def quad_panel(name, face: Face, s0, t0, s1, t1, mat, off=0.006, depth=0.0, uv_cell=None):
    """Painel retangular na face (de s0,t0 a s1,t1). `depth` > 0 = placa com espessura; `uv_cell` mapeia a frente para a
    célula do atlas (0..15)."""
    p = [face.at(s0, t0, off), face.at(s1, t0, off), face.at(s1, t1, off), face.at(s0, t1, off)]
    if depth > 0:
        back = [q - face.n * depth for q in p]
        o = mesh_from(name, p + back, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], mat)
    else:
        o = mesh_from(name, p, [(0, 1, 2, 3)], mat)
    if uv_cell is not None:
        _uv_cell(o, p, uv_cell)
    return o


def _uv_cell(o, corners, cell):
    """UV da face da frente (os 4 primeiros vértices) na célula `cell` do atlas; as outras faces ficam num canto."""
    cu, cv = 1.0 / ATLAS_COLS, 1.0 / ATLAS_ROWS
    col, row = cell % ATLAS_COLS, cell // ATLAS_COLS
    u0, v1 = col * cu, 1.0 - row * cv               # Blender: v para cima; linha 0 do atlas = topo da imagem
    pad = 0.004
    uvs = [(u0 + pad, v1 - cv + pad), (u0 + cu - pad, v1 - cv + pad), (u0 + cu - pad, v1 - pad), (u0 + pad, v1 - pad)]
    me = o.data
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uvl.data[li].uv = uvs[vi] if vi < 4 else uvs[0]


def led_grid(name, face: Face, s0, t0, s1, t1, cols, rows, mat, fill=0.62, off=0.008, depth=0.012, skip=None):
    """Matriz de LED: `cols` x `rows` quadradinhos em relevo dentro do retângulo (s0,t0)-(s1,t1) da face.
    `skip(c, r)` -> True apaga aquele LED (padrões falhados como nas capturas)."""
    bm = bmesh.new()
    du, dv = (s1 - s0) / cols, (t1 - t0) / rows
    hu, hv = du * fill / 2, dv * fill / 2
    for r in range(rows):
        for c in range(cols):
            if skip and skip(c, r):
                continue
            sc, tc = s0 + du * (c + 0.5), t0 + dv * (r + 0.5)
            p = [face.at(sc - hu, tc - hv, off), face.at(sc + hu, tc - hv, off), face.at(sc + hu, tc + hv, off), face.at(sc - hu, tc + hv, off)]
            b = [q - face.n * depth for q in p]
            vs = [bm.verts.new(q) for q in p + b]
            for f in ((0, 1, 2, 3), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
                bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return M._link(name, bm, mat)


def bar_on(name, face: Face, s0, t0, s1, t1, mat, off=0.008, depth=0.03):
    """Barra (neon/coluna/friso) em relevo sobre a face."""
    return quad_panel(name, face, s0, t0, s1, t1, mat, off=off + depth, depth=depth + off)


def frame_on(name, face: Face, s0, t0, s1, t1, bar_s, bar_t, mat, off=0.01, depth=0.03):
    """Moldura retangular (4 barras) em volta de (s0,t0)-(s1,t1)."""
    return [bar_on(f"{name}_b", face, s0 - bar_s, t0 - bar_t, s1 + bar_s, t0, mat, off, depth),
            bar_on(f"{name}_t", face, s0 - bar_s, t1, s1 + bar_s, t1 + bar_t, mat, off, depth),
            bar_on(f"{name}_l", face, s0 - bar_s, t0, s0, t1, mat, off, depth),
            bar_on(f"{name}_r", face, s1, t0, s1 + bar_s, t1, mat, off, depth)]


def sign(name, face: Face, s0, t0, s1, t1, m, cell=0, frame_mat=None, bar=0.035):
    """Letreiro de acrílico (célula `cell` do atlas) com moldura; a face do acrílico fica um pouco para dentro."""
    W = face.u.length
    Hh = face.v.length
    out = [quad_panel(name + "_face", face, s0, t0, s1, t1, m["sign"], off=0.004, uv_cell=cell)]
    if frame_mat is not None:
        out += frame_on(name + "_fr", face, s0, t0, s1, t1, bar / W, bar / Hh, frame_mat, off=0.004, depth=0.025)
    return out


def art_panel(name, face: Face, s0, t0, s1, t1, m, cell):
    return quad_panel(name, face, s0, t0, s1, t1, m["art"], off=0.005, uv_cell=cell)


def hex_pod(name, length, radius, loc, mat, seg=6):
    """Tubo sextavado deitado ao longo de Y (canhão de luz), centro em `loc`."""
    o = M.cylinder(name, radius, length, loc, mat, axis="Y", seg=seg, bevel=0.01, bevel_seg=1)
    o.rotation_euler.y = math.radians(30 if seg == 6 else 45)
    return o


def lens(name, radius, loc, mat, seg=6):
    o = M.cylinder(name, radius, 0.03, loc, mat, axis="Y", seg=seg, bevel=0.0)
    o.rotation_euler.y = math.radians(30 if seg == 6 else 45)
    return o


def arc_tube(name, x0, x1, y, z, rise, radius, mat, n=8):
    """Arco de neon (sobrancelha) de x0 a x1, subindo `rise` no meio."""
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + (x1 - x0) * t, y, z + rise * math.sin(math.pi * t)))
    return M.tube(name, pts, radius, mat, seg=6)
