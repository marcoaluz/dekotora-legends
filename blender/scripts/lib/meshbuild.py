"""Construtor de malha com UV explícito (T-136): faces e UVs escritos à mão, para peças que vão receber mapas
gravados (bake) num atlas. Cada vértice de face leva o seu UV; nada de projeção automática (é determinístico e o
mesmo layout serve para a versão alta e a leve).

Uso:
    mb = MeshBuilder()
    mb.quad(p0, p1, p2, p3, (uv0, uv1, uv2, uv3))      # pontos no sentido anti-horário visto de fora
    mb.strip(rows, uv_fn)                               # grade de quads a partir de linhas de pontos
    ob = mb.build("nome", material)
"""
from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Vector


class Rect:
    """Retângulo no atlas (u0, v0, largura, altura), coordenadas 0..1 com v para cima (convenção do Blender)."""

    def __init__(self, u0: float, v0: float, w: float, h: float):
        self.u0, self.v0, self.w, self.h = u0, v0, w, h

    def at(self, s: float, t: float):
        """Ponto (s, t) em 0..1 dentro do retângulo."""
        return (self.u0 + s * self.w, self.v0 + t * self.h)

    def inset(self, px: float, size: int = 1024) -> "Rect":
        d = px / size
        return Rect(self.u0 + d, self.v0 + d, self.w - 2 * d, self.h - 2 * d)


class MeshBuilder:
    def __init__(self):
        self.verts: list = []
        self.faces: list = []          # (índices, uvs)

    def _v(self, p) -> int:
        self.verts.append(Vector(p))
        return len(self.verts) - 1

    def poly(self, pts, uvs) -> None:
        idx = [self._v(p) for p in pts]
        self.faces.append((idx, list(uvs)))

    def quad(self, p0, p1, p2, p3, uvs) -> None:
        self.poly((p0, p1, p2, p3), uvs)

    def strip(self, rows, uv_fn, closed: bool = False) -> None:
        """`rows` = lista de linhas de pontos (mesmo tamanho); faz quads entre linhas vizinhas.
        `uv_fn(i, j)` dá o UV do ponto j da linha i. A ordem (linha i -> i+1, ponto j -> j+1) define a frente."""
        n = len(rows[0])
        last = n if closed else n - 1
        for i in range(len(rows) - 1):
            for j in range(last):
                k = (j + 1) % n
                self.quad(rows[i][j], rows[i][k], rows[i + 1][k], rows[i + 1][j],
                          (uv_fn(i, j), uv_fn(i, k if k else n), uv_fn(i + 1, k if k else n), uv_fn(i + 1, j)))

    def extend(self, other: "MeshBuilder") -> None:
        base = len(self.verts)
        self.verts += other.verts
        self.faces += [([i + base for i in idx], uvs) for idx, uvs in other.faces]

    def build(self, name: str, mat=None, weld: float = 1e-5):
        """Cria o objeto (vértices iguais soldados para o sombreamento suave funcionar entre faces)."""
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in self.verts]
        uvl = bm.loops.layers.uv.new("UVMap")
        for idx, uvs in self.faces:
            try:
                f = bm.faces.new([vs[i] for i in idx])
            except ValueError:
                continue
            for loop, uv in zip(f.loops, uvs):
                loop[uvl].uv = uv
        if weld > 0:
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=weld)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        if mat is not None:
            ob.data.materials.append(mat)
        return ob


def extrude_profile(mb: MeshBuilder, profile, a: float, b: float, axis: str, rect: Rect, caps: bool = True,
                    cap_rect: Rect | None = None) -> None:
    """Perfil 2D (lista de (p, q), sentido anti-horário no plano (p, q)) extrudado de `a` até `b` ao longo de
    `axis` ("x", "y" ou "z"). UV desenrolado: u = posição ao longo do eixo (a..b -> 0..1), v = comprimento do perímetro
    (0..1). `profile` em coordenadas dos outros dois eixos, na ordem (y, z) para x, (x, z) para y, (x, y) para z."""
    def P(s, p, q):
        if axis == "x":
            return (s, p, q)
        if axis == "y":
            return (p, s, q)
        return (p, q, s)
    n = len(profile)
    seg = [math.dist(profile[i], profile[(i + 1) % n]) for i in range(n)]
    per = sum(seg) or 1.0
    acc = [0.0]
    for s in seg:
        acc.append(acc[-1] + s)
    flip = axis != "y"                                   # mantém as normais para fora nos três eixos
    for i in range(n):
        j = (i + 1) % n
        p0, p1 = profile[i], profile[j]
        v0, v1 = acc[i] / per, acc[i + 1] / per
        quad = [P(a, *p0), P(b, *p0), P(b, *p1), P(a, *p1)]
        uvs = [rect.at(0, v0), rect.at(1, v0), rect.at(1, v1), rect.at(0, v1)]
        if flip:
            quad, uvs = quad[::-1], uvs[::-1]
        mb.quad(*quad, uvs)
    if caps:
        cr = cap_rect or Rect(rect.u0, rect.v0, rect.w * 0.02, rect.h)
        lo = [min(p[k] for p in profile) for k in (0, 1)]
        hi = [max(p[k] for p in profile) for k in (0, 1)]
        uv = [cr.at((p[0] - lo[0]) / max(hi[0] - lo[0], 1e-6), (p[1] - lo[1]) / max(hi[1] - lo[1], 1e-6)) for p in profile]
        end_a = [P(a, *p) for p in profile]
        end_b = [P(b, *p) for p in profile]
        if flip:
            mb.poly(end_a[::-1], uv[::-1])
            mb.poly(end_b, uv)
        else:
            mb.poly(end_a, uv)
            mb.poly(end_b[::-1], uv[::-1])


def mirror_x(ob, name: str):
    """Cópia espelhada em X com os MESMOS UVs (o mapa gravado serve para os dois lados)."""
    me = ob.data.copy()
    me.name = name
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.scale(bm, vec=Vector((-1, 1, 1)), verts=bm.verts)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    o2 = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o2)
    return o2
