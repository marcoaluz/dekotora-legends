"""Superfície da casca da cabine e "adesivos" 3D que acompanham a curva (vidros, faróis, grade, frisos).

Coordenada desenvolvida `q` ao redor da frente (lado direito q > 0, esquerdo q < 0, simétrico):
  0..1  frente (x vai de 0 até o início do canto; a frente recua `bow` nas pontas: leve curva vista de cima)
  1..2  canto arredondado (ângulo 0..90 graus, raio rf(z))
  2..   lateral: cada unidade = 1 m para trás a partir do fim do canto
Assim um vidro "dobra" o canto sem saber o raio. A lateral também tem `side_ev` com y direto (portas).

`patch()` cria uma placa fina que acompanha a casca: contorno dado por um polígono convexo em (u, z),
face externa a `off1` da casca e paredes até `off0` (dá a espessura que pega luz na borda).
"""
from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from lib.mesh3d import _link

from .dims import CAB_Y0


class Shell:
    """Avaliação analítica da casca (a mesma fórmula que gera a malha em `cab.py`)."""

    def __init__(self, c):
        self.c = c

    def rf(self, z: float) -> float:
        c = self.c
        return c.rf0 + c.rf1 * max(0.0, min(1.0, (z - 2.1) / 1.1))

    def raw(self, q: float, z: float):
        """Ponto (x, y) da casca na lateral direita/esquerda conforme o sinal de q."""
        c = self.c
        sx = 1.0 if q >= 0 else -1.0
        q = abs(q)
        hw, yf, rf, bow = c.hw(z), c.yf(z), self.rf(z), c.bow
        xe = hw - rf
        if q <= 1.0:
            x, y = q * xe, yf - bow * q * q
        elif q <= 2.0:
            a = (q - 1.0) * math.pi / 2
            x, y = xe + rf * math.sin(a), yf - bow - rf + rf * math.cos(a)
        else:
            x, y = hw, yf - bow - rf - (q - 2.0)
        return Vector((sx * x, y, z))

    def ev(self, q: float, z: float, off: float = 0.0) -> Vector:
        """Ponto na casca deslocado `off` metros pela normal (para fora)."""
        p = self.raw(q, z)
        if off == 0.0:
            return p
        return p + self.normal(q, z) * off

    def normal(self, q: float, z: float) -> Vector:
        e = 1e-3
        dq = self.raw(q + e, z) - self.raw(q - e, z)
        dz = self.raw(q, z + e) - self.raw(q, z - e)
        n = dz.cross(dq) if q >= 0 else dq.cross(dz)
        if n.length < 1e-9:
            return Vector((0, 1, 0))
        n.normalize()
        p = self.raw(q, z)
        if n.dot(Vector((p.x, p.y - (CAB_Y0 + 1.5), 0))) < 0:     # sempre para fora
            n = -n
        return n

    def q_from_x(self, x: float, z: float) -> float:
        """q da frente para um x dado (inverso de `raw` na frente e nos cantos)."""
        c = self.c
        rf = self.rf(z)
        xe = c.hw(z) - rf
        ax = abs(x)
        if ax <= xe:
            q = ax / xe
        else:
            q = 1.0 + math.asin(min(1.0, (ax - xe) / rf)) / (math.pi / 2)
        return q if x >= 0 else -q

    def side_q(self, y: float, z: float) -> float:
        """q da lateral (direita) para um y dado."""
        c = self.c
        return 2.0 + (c.yf(z) - c.bow - self.rf(z) - y)

    def side_ev(self, sx: int):
        """Avaliador (y, z, off) -> ponto para a lateral sx; u = y. Se o y cai no canto arredondado, acha o
        ângulo do canto com esse y (sem degrau na passagem lateral -> canto)."""
        def f(y, z, off=0.0):
            q = self.side_q(y, z)
            if q < 2.0:
                rf = self.rf(z)
                ystart = self.c.yf(z) - self.c.bow - rf
                a = math.acos(max(-1.0, min(1.0, (y - ystart) / rf)))
                q = 1.0 + a / (math.pi / 2)
            return self.ev(sx * q, z, off)
        f.kinks = self.kinks()
        return f

    def front_ev(self):
        def f(q, z, off=0.0):
            return self.ev(q, z, off)
        f.kinks = self.kinks()
        return f

    def kinks(self):
        """Alturas onde a casca dobra (as placas precisam de uma linha exatamente ali para não afundar)."""
        return [2.1, 2.4, self.c.wz0, self.c.wz1]


# ------------------------------------------------------------------ polígonos em (u, z)

def rounded_poly(pts, r, n=4):
    """Arredonda os cantos de um polígono (lista de (u, z)) com raio r (ou lista de raios)."""
    out = []
    m = len(pts)
    rs = r if isinstance(r, (list, tuple)) else [r] * m
    for i in range(m):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % m])
        a, b = (p0 - p1), (p2 - p1)
        la, lb = a.length, b.length
        ri = min(rs[i], la * 0.45, lb * 0.45)
        if ri <= 1e-4:
            out.append(tuple(p1))
            continue
        s, e = p1 + a.normalized() * ri, p1 + b.normalized() * ri
        for k in range(n + 1):                          # Bézier quadrática (aproxima o arco)
            t = k / n
            q = s * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + e * t * t
            out.append((q.x, q.y))
    return out


def poly_lim(poly):
    """Para um polígono convexo em (u, z), devolve (zmin, zmax, lim(z) -> (u0, u1))."""
    zs = [p[1] for p in poly]
    zmin, zmax = min(zs), max(zs)

    def lim(z):
        z = min(max(z, zmin + 1e-6), zmax - 1e-6)
        xs = []
        m = len(poly)
        for i in range(m):
            (u0, z0), (u1, z1) = poly[i], poly[(i + 1) % m]
            if (z0 - z) * (z1 - z) <= 0 and z0 != z1:
                xs.append(u0 + (z - z0) * (u1 - u0) / (z1 - z0))
        if not xs:
            return (0.0, 0.0)
        return (min(xs), max(xs))
    return zmin, zmax, lim


def patch(name, ev, poly, off0, off1, mat, nz=8, nu=12, walls=True, uv=True, collection=None):
    """Placa que acompanha a casca. `ev(u, z, off)` -> Vector. `poly` = contorno convexo em (u, z)."""
    zmin, zmax, lim = poly_lim(poly)
    bm = bmesh.new()
    rows = []
    zs = [zmin + (zmax - zmin) * (0.5 - 0.5 * math.cos(math.pi * i / nz)) for i in range(nz + 1)]  # densas nas pontas
    zs += [k for k in getattr(ev, "kinks", ()) if zmin + 0.01 < k < zmax - 0.01]
    zs = sorted(zs)
    zs = [z for i, z in enumerate(zs) if i == 0 or z - zs[i - 1] > 0.004]
    nz = len(zs) - 1
    for z in zs:
        t = (z - zmin) / max(zmax - zmin, 1e-9)
        u0, u1 = lim(z)
        rows.append([(u0 + (u1 - u0) * j / nu, z, j / nu, t) for j in range(nu + 1)])
    top = [[bm.verts.new(ev(u, z, off1)) for (u, z, _, _) in row] for row in rows]
    uvl = bm.loops.layers.uv.new("UVMap") if uv else None

    def face(vs, uvs=None):
        try:
            f = bm.faces.new(vs)
        except ValueError:
            return
        if uvl is not None and uvs is not None:
            for lp, c in zip(f.loops, uvs):
                lp[uvl].uv = c
    for i in range(nz):
        for j in range(nu):
            vs = [top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j]]
            uvs = [rows[i][j][2:], rows[i][j + 1][2:], rows[i + 1][j + 1][2:], rows[i + 1][j][2:]]
            face(vs, uvs)
    if walls and off0 != off1:
        ring = [rows[0][j] for j in range(nu + 1)] + [rows[i][nu] for i in range(1, nz + 1)] + \
               [rows[nz][j] for j in range(nu - 1, -1, -1)] + [rows[i][0] for i in range(nz - 1, 0, -1)]
        ring_top = [top[0][j] for j in range(nu + 1)] + [top[i][nu] for i in range(1, nz + 1)] + \
                   [top[nz][j] for j in range(nu - 1, -1, -1)] + [top[i][0] for i in range(nz - 1, 0, -1)]
        bot = [bm.verts.new(ev(u, z, off0)) for (u, z, _, _) in ring]
        m = len(ring)
        for k in range(m):
            k2 = (k + 1) % m
            face([ring_top[k], bot[k], bot[k2], ring_top[k2]])
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    _orient_out(bm, ev, poly)
    ob = _link(name, bm, mat, collection)
    ob["has_uv"] = True                                   # o build não troca este UV (vidro, telas perfuradas)
    return ob


def _orient_out(bm, ev, poly):
    """Vira as faces para fora da casca (normal no mesmo sentido do deslocamento)."""
    cu = sum(p[0] for p in poly) / len(poly)
    cz = sum(p[1] for p in poly) / len(poly)
    n_ref = ev(cu, cz, 0.01) - ev(cu, cz, 0.0)
    if not bm.faces:
        return
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    big = max(bm.faces, key=lambda f: f.calc_area() * abs(f.normal.dot(n_ref)))
    if big.normal.dot(n_ref) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])


def ribbon(name, ev, path, off, width, mat, collection=None, closed=False):
    """Fita fina (largura `width`) deitada sobre a casca ao longo de `path` [(u, z), ...]: frisos, juntas
    de porta, borrachas. 2 triângulos por segmento (bem mais barato que um tubo)."""
    bm = bmesh.new()
    pts = [ev(u, z, off) for (u, z) in path]
    nrm = [(ev(u, z, off + 0.01) - ev(u, z, off)).normalized() for (u, z) in path]
    n = len(pts)
    left, right = [], []
    for i in range(n):
        a = pts[(i - 1) % n] if (closed or i > 0) else pts[i]
        b = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
        t = (b - a)
        t = t.normalized() if t.length > 1e-9 else Vector((0, 0, 1))
        s = nrm[i].cross(t).normalized() * (width / 2)
        left.append(bm.verts.new(pts[i] + s))
        right.append(bm.verts.new(pts[i] - s))
    segs = n if closed else n - 1
    for i in range(segs):
        j = (i + 1) % n
        try:
            f = bm.faces.new((left[i], right[i], right[j], left[j]))
        except ValueError:
            continue
        if f.normal.dot(nrm[i]) < 0:
            f.normal_flip()
    return _link(name, bm, mat, collection)
