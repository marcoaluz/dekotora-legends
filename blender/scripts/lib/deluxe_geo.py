"""Geometria de acabamento fino para as peças "deluxe" (T-172): molduras com perfil (cromo com espessura e bisel),
parafusos sextavados, lâmpadas por revolução (lente com anéis de Fresnel), canaletas e texturas pequenas por numpy
(acrílico iluminado, escama "uroko" de inox em mapa de normais).

Convenções iguais às de `mesh3d.py`: metros, +Y frente, +X direita, +Z cima. Tudo por bmesh (sem bpy.ops de modelagem).
Orçamento: cada função diz quantos triângulos gasta, para a peça caber em "alguns milhares".
"""
from __future__ import annotations

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

from . import mesh_adv as A
from . import tex
from .mesh3d import _link
from .palette import hex_to_rgb, lin


# ----------------------------------------------------------------------------- molduras com perfil

def _rounded_rect_path(w: float, h: float, r: float, n: int):
    """Contorno de um retângulo de cantos arredondados no plano (a, b), anti-horário: lista de (ponto, normal para fora)."""
    r = max(0.002, min(r, w / 2 - 0.001, h / 2 - 0.001))
    out = []
    corners = (((w / 2 - r, h / 2 - r), 0), ((-w / 2 + r, h / 2 - r), 90), ((-w / 2 + r, -h / 2 + r), 180), ((w / 2 - r, -h / 2 + r), 270))
    for (ca, cb), a0 in corners:
        for k in range(n + 1):
            a = math.radians(a0 + 90.0 * k / n)
            nrm = (math.cos(a), math.sin(a))
            out.append(((ca + r * nrm[0], cb + r * nrm[1]), nrm))
    return out


def frame(name, w, h, profile, loc, mat=None, r=0.03, n=3, plane="XZ", collection=None):
    """Moldura: `profile` (lista FECHADA de (o, d)) varrida em volta da ABERTURA w x h (cantos com raio r).
    o = quanto sai para fora da abertura (>= 0), d = profundidade (plano XZ: d em +Y = frente; plano XY: d em +Z).
    Triângulos ~ 2 * len(profile) * 4 * (n + 1)."""
    path = _rounded_rect_path(w, h, r, n)
    bm = bmesh.new()
    rings = []
    for (pa, pb), (na, nb) in path:
        ring = []
        for o, d in profile:
            a, b = pa + na * o, pb + nb * o
            co = (a, d, b) if plane == "XZ" else ((d, a, b) if plane == "YZ" else (a, b, d))
            ring.append(bm.verts.new(co))
        rings.append(ring)
    m = len(profile)
    for i in range(len(rings)):
        i2 = (i + 1) % len(rings)
        for j in range(m):
            j2 = (j + 1) % m
            bm.faces.new((rings[i][j], rings[i2][j], rings[i2][j2], rings[i][j2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    return ob


def sweep_open(name, path, profile, mat=None, caps=True, collection=None):
    """Perfil (lista fechada de (a, b): a = para o lado, b = para cima) varrido ao longo de `path` (pontos 3D).
    O lado é tangente x Z (o caminho não pode ser vertical). Triângulos ~ 2 * len(profile) * (len(path) - 1)."""
    bm = bmesh.new()
    rings = []
    n = len(path)
    for i, p in enumerate(path):
        p = Vector(p)
        t = (Vector(path[min(i + 1, n - 1)]) - Vector(path[max(i - 1, 0)])).normalized()
        side = t.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(t).normalized()
        rings.append([bm.verts.new(p + side * a + up * b) for a, b in profile])
    m = len(profile)
    for i in range(n - 1):
        for j in range(m):
            j2 = (j + 1) % m
            bm.faces.new((rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]))
    if caps:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _link(name, bm, mat, collection)


def rounded_rect_profile(w: float, h: float, r: float, n: int = 2):
    """Perfil 2D (a, b) de um retângulo de cantos arredondados centrado na origem (para `sweep_open`)."""
    return [p for p, _ in _rounded_rect_path(w, h, r, n)]


def chrome_lip_profile(bar: float, depth: float, crown: float = 0.018, bev: float = 0.008):
    """Perfil de moldura cromada: parede interna, bisel, coroa arredondada, bisel externo e costas (fechado)."""
    return [(0.0, -depth), (0.0, -bev), (bev * 0.6, 0.0), (bar * 0.25, crown * 0.8), (bar * 0.5, crown),
            (bar * 0.75, crown * 0.8), (bar - bev * 0.6, 0.0), (bar, -bev), (bar, -depth)]


# ----------------------------------------------------------------------------- ferragens

def hex_bolt(name, loc, r=0.012, axis="Y", sign=1, mat=None, washer=False):
    """Parafuso sextavado (20 triângulos; com arruela +32). `axis` = direção da cabeça; `sign` = para que lado sai."""
    parts = []
    h = r * 0.7
    off = Vector({"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[axis]) * sign
    base = Vector(loc)
    if washer:
        parts.append(_cyl(name + "_w", r * 1.45, r * 0.25, base + off * (r * 0.125), axis, 8, mat))
        base = base + off * (r * 0.25)
    parts.append(_cyl(name, r, h, base + off * (h / 2), axis, 6, mat, rot_extra=30.0))
    return parts


def _cyl(name, r, depth, loc, axis, seg, mat, rot_extra=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r, depth=depth)
    if rot_extra:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(rot_extra), 3, "Z"))
    ob = _link(name, bm, mat)
    ob.location = loc
    if axis == "X":
        ob.rotation_euler = (0, math.radians(90), 0)
    elif axis == "Y":
        ob.rotation_euler = (math.radians(90), 0, 0)
    return ob


def bulb(name, loc, r, chrome, lens, axis="Y", sign=1, seg=10):
    """Lâmpada de marcação pequena: copo cromado + lente em domo (~ 6*seg + 5*seg triângulos)."""
    cup = [(0.0, 0.0), (r * 1.25, 0.0), (r * 1.3, r * 0.35), (r * 1.05, r * 0.45), (0.0, r * 0.45)]
    dome = [(0.0, r * 0.4), (r, r * 0.4), (r * 0.82, r * 0.95), (r * 0.42, r * 1.25), (0.0, r * 1.32)]
    return _lathe_pair(name, loc, cup, dome, chrome, lens, axis, sign, seg)


def bus_marker(name, loc, chrome, lens, r=0.055, seg=12):
    """Lanterna de ônibus japonesa (バスマーカー): corpo cromado com friso e domo de lente com degraus de Fresnel.
    Vertical (eixo Z). ~ 330 triângulos com seg=12."""
    body = [(0.0, 0.0), (r * 1.05, 0.0), (r * 1.08, r * 0.2), (r * 1.08, r * 0.75), (r * 0.98, r * 0.85),
            (r * 1.08, r * 0.95), (r * 1.08, r * 1.5), (r * 0.98, r * 1.62), (0.0, r * 1.62)]
    lens_p = [(0.0, r * 1.55), (r * 0.98, r * 1.55), (r * 0.98, r * 2.05), (r * 0.86, r * 2.12), (r * 0.86, r * 2.5),
              (r * 0.7, r * 2.58), (r * 0.62, r * 2.85), (r * 0.36, r * 3.0), (0.0, r * 3.04)]
    return _lathe_pair(name, loc, body, lens_p, chrome, lens, "Z", 1, seg)


def round_tail(name, loc, r, chrome, lens, seg=14, sign=-1):
    """Lanterna redonda de caminhão: aro cromado com degrau + lente com anéis (Fresnel). Olha para `sign` em Y
    (-1 = traseira). ~ 9*seg*2 triângulos."""
    ring = [(r * 0.86, 0.0), (r * 1.18, 0.0), (r * 1.22, r * 0.14), (r * 1.12, r * 0.24), (r * 0.98, r * 0.26), (r * 0.9, r * 0.12)]
    lens_p = [(0.0, r * 0.06), (r * 0.92, r * 0.06), (r * 0.92, r * 0.16), (r * 0.7, r * 0.2), (r * 0.66, r * 0.27),
              (r * 0.42, r * 0.3), (r * 0.38, r * 0.35), (0.0, r * 0.38)]
    return _lathe_pair(name, loc, ring, lens_p, chrome, lens, "Y", sign, seg)


def _lathe_pair(name, loc, prof_a, prof_b, mat_a, mat_b, axis, sign, seg):
    out = []
    for suffix, prof, mat in (("_cup", prof_a, mat_a), ("_lens", prof_b, mat_b)):
        p = [(r, a * sign) for r, a in prof]
        if sign < 0:
            p = p[::-1]
        ob = A.lathe(name + suffix, p, (0, 0, 0), mat, axis="Z", seg=seg)
        rot = Matrix.Identity(4)
        if axis == "Y":
            rot = Matrix.Rotation(math.radians(-90), 4, "X")
        elif axis == "X":
            rot = Matrix.Rotation(math.radians(90), 4, "Y")
        ob.data.transform(rot)
        ob.location = loc
        out.append(ob)
    return out


def channel_y(name, y0, y1, w, h, t, loc, mat=None):
    """Canaleta em U aberta para baixo, ao longo de Y (perfil de alumínio do neon de chão). 4 faces + pontas."""
    pts = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, -h), (w / 2 - t, -h), (w / 2 - t, -t), (-w / 2 + t, -t), (-w / 2 + t, -h), (-w / 2, -h)]
    from .mesh3d import plane_extrude
    ob = plane_extrude(name, pts, y1 - y0, (loc[0], loc[1] + (y0 + y1) / 2, loc[2]), mat, plane="XZ", bevel=0.003, seg=1)
    return ob


def floor_glow(name, w, l, loc, mat):
    """Quadrado no chão (2 triângulos) com UV 0..1: no jogo vira o brilho aditivo do neon (AccessoryGlow, falloff
    calculado no shader pela UV); no Blender usa a textura de gradiente do material."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    v = [bm.verts.new((loc[0] + x * w / 2, loc[1] + y * l / 2, loc[2])) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = bm.faces.new(v)
    for lp, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        lp[uvl].uv = uv
    return _link(name, bm, mat)


def uv_box_meters(o, tile: float = 0.3) -> None:
    """UV em metros por face (projeção pela normal dominante), na posição local da malha. Para a escama uroko."""
    me = o.data
    uvl = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        n = poly.normal
        k = max(range(3), key=lambda i: abs(n[i]))
        a, b = [i for i in range(3) if i != k]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = (co[a] / tile, co[b] / tile)


# ----------------------------------------------------------------------------- texturas (numpy, determinísticas)

def acrylic_face_tex(name="tex_acrylic_andon", w=512, h=160, tint="#fff1cf", tubes=3):
    """Acrílico leitoso iluminado por dentro: fundo quente, faixas mais claras onde ficam as lâmpadas tubulares,
    bordas mais escuras (sombra da moldura). sRGB."""
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / (w - 1), yy / (h - 1)
    base = np.array(hex_to_rgb(tint))
    band = np.zeros_like(v)
    for k in range(tubes):
        c = (k + 0.5) / tubes
        band += np.exp(-((v - c) ** 2) / (2 * 0.06 ** 2))
    edge = np.minimum(np.minimum(u, 1 - u) * 9.0, np.minimum(v, 1 - v) * 4.0)
    vign = np.clip(edge, 0, 1) ** 0.6
    lum = (0.72 + 0.28 * np.clip(band, 0, 1)) * (0.55 + 0.45 * vign)
    arr = base[None, None, :] * lum[..., None]
    arr = np.clip(arr + 0.08 * np.clip(band, 0, 1)[..., None], 0, 1)        # o tubo "estoura" para o branco
    return tex._image(name, arr)


def glow_gradient_tex(name="tex_glow_floor", w=64, h=256):
    """Gradiente para o brilho no chão (prévia do Blender): forte no centro da faixa, some nas bordas e pontas."""
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / (w - 1), yy / (h - 1)
    across = np.exp(-((u - 0.5) ** 2) / (2 * 0.16 ** 2))
    along = np.clip(np.minimum(v, 1 - v) * 6.0, 0, 1)
    a = across * along
    arr = np.stack([a, a, a], axis=-1)
    return tex._image(name, arr, srgb=False)


def uroko_normal_tex(name="tex_uroko_nrm", size=256, cols=4):
    """Mapa de normais da escama de inox "uroko" (ウロコ): fileiras de escamas em meia-lua, desencontradas.
    Cada escama é um domo raso com borda; o tile repete nos dois sentidos."""
    yy, xx = np.mgrid[0:size, 0:size]
    cw = size / cols
    rows = cols * 2
    rh = size / rows
    hgt = np.zeros((size, size))
    for row in range(-1, rows + 1):
        off = (cw / 2) if row % 2 else 0.0
        cy = (row + 1.0) * rh
        for col in range(-1, cols + 2):
            cx = col * cw + off
            d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (cw * 0.62)
            below = yy <= cy + 0.5
            dome = np.where((d < 1.0) & below, np.sqrt(np.clip(1 - d ** 2, 0, 1)), 0.0)
            hgt = np.maximum(hgt, dome * 0.8 + np.where((d < 1.0) & below, 0.2, 0.0))
    gy, gx = np.gradient(hgt)
    s = 3.2
    nx, ny, nz = -gx * s, -gy * s, np.ones_like(hgt)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    arr = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)
    return tex._image(name, arr, srgb=False)


# ----------------------------------------------------------------------------- materiais extras

def _principled(name):
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    return m, next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def acrylic_material(name="acrylic_andon", tint="#fff1cf", strength=2.2):
    """Acrílico leitoso do andon: textura na cor E na emissão (o jogo controla a força pela noite/dia)."""
    m, b = _principled(name)
    nt = m.node_tree
    img = acrylic_face_tex("tex_" + name, tint=tint)
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = strength
    b.inputs["Roughness"].default_value = 0.18
    b.inputs["Metallic"].default_value = 0.0
    m["px_kind"] = "emissive"
    return m


def glow_material(name="glow_floor_cyan", hex_color="#21e6ff", strength=4.0):
    """Brilho no chão: emissivo com alfa em gradiente (prévia). No Godot o AccessoryGlow troca pelo shader aditivo."""
    m, b = _principled(name)
    nt = m.node_tree
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = glow_gradient_tex("tex_" + name)
    col = lin(hex_to_rgb(hex_color)) + (1.0,)
    b.inputs["Base Color"].default_value = col
    b.inputs["Emission Color"].default_value = col
    b.inputs["Emission Strength"].default_value = strength
    nt.links.new(t.outputs["Color"], b.inputs["Alpha"])
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    elif hasattr(m, "blend_method"):
        m.blend_method = "BLEND"
    m["px_kind"] = "emissive"
    return m


def uroko_material(name="steel_uroko"):
    """Inox com escama "uroko" (mapa de normais embutido). Metálico 0,6: no Compatibility metálico 1,0 sem reflexo escurece."""
    m, b = _principled(name)
    nt = m.node_tree
    b.inputs["Base Color"].default_value = lin(hex_to_rgb("#d9e0ea")) + (1.0,)
    b.inputs["Metallic"].default_value = 0.6
    b.inputs["Roughness"].default_value = 0.22
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = uroko_normal_tex()
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.inputs["Strength"].default_value = 1.0
    nt.links.new(t.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    m["px_kind"] = "pbr"
    return m


def deluxe_set(m: dict) -> dict:
    """Acrescenta ao conjunto padrão os materiais das peças deluxe (nomes estáveis: o jogo procura pelo nome)."""
    from . import pbr
    m["acrylic_andon"] = acrylic_material()
    m["andon_ink"] = pbr.pbr("andon_ink", "#7c0d1c", metallic=0.0, roughness=0.35)
    m["glow_floor_cyan"] = glow_material("glow_floor_cyan", "#21e6ff")
    m["glow_floor_pink"] = glow_material("glow_floor_pink", "#ff2e88")
    m["steel_uroko"] = uroko_material()
    return m
