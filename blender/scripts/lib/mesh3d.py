"""Geometria 3D de jogo: caixas chanfradas, cilindros, perfis extrudados, tubos e exportação .glb.

Tudo por bmesh (sem bpy.ops de modelagem, que quebra em modo sem tela). Convenções do projeto:
metros, frente = +Y, chão Z=0. A exportação glTF converte para Y-up (frente = -Z no Godot).
"""
from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def _link(name: str, bm: bmesh.types.BMesh, mat=None, collection=None) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    if mat is not None:
        ob.data.materials.append(mat)
    return ob


def _bevel(bm, width: float, segments: int) -> None:
    if width > 0:
        bmesh.ops.bevel(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                        offset=width, segments=segments, profile=0.6, affect="EDGES")


def box(name, size, loc, mat=None, bevel=0.03, seg=2, collection=None, rot=(0, 0, 0)):
    """Caixa chanfrada. `loc` = CENTRO. size = (x, y, z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    _bevel(bm, min(bevel, min(size) * 0.45), seg)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob


def cylinder(name, radius, depth, loc, mat=None, axis="Z", seg=24, bevel=0.0, bevel_seg=2, collection=None,
             radius2=None):
    """Cilindro/cone. axis: X, Y ou Z (direção do comprimento). `loc` = CENTRO."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=depth)
    _bevel(bm, min(bevel, radius * 0.45, depth * 0.45), bevel_seg)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    if axis == "X":
        ob.rotation_euler = (0, math.radians(90), 0)
    elif axis == "Y":
        ob.rotation_euler = (math.radians(90), 0, 0)
    return ob


def sphere(name, radius, loc, mat=None, seg=16, rings=10, scale=(1, 1, 1), collection=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    return ob


def profile_extrude(name, pts_yz, width, loc, mat=None, bevel=0.05, seg=2, collection=None):
    """Perfil lateral (lista de (y, z)) extrudado em X por `width` (centrado). Para cabines e saias."""
    bm = bmesh.new()
    verts = [bm.verts.new((-width / 2, y, z)) for y, z in pts_yz]
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    ext = [v for v in res["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(width, 0, 0), verts=ext)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    _bevel(bm, bevel, seg)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    return ob


def plate(name, size, loc, mat=None, bevel=0.01, collection=None, rot=(0, 0, 0)):
    """Chapa fina (alias de box com chanfro pequeno)."""
    return box(name, size, loc, mat, bevel=bevel, seg=1, collection=collection, rot=rot)


def tube(name, points, radius, mat=None, seg=12, collection=None):
    """Tubo por segmentos retos ligando pontos (X,Y,Z); junções esféricas. Devolve um objeto único."""
    bm = bmesh.new()
    for a, b in zip(points[:-1], points[1:]):
        va, vb = Vector(a), Vector(b)
        d = vb - va
        mid = (va + vb) / 2
        m = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=radius, radius2=radius,
                                  depth=d.length)
        verts = m["verts"]
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation(mid) @ rot, verts=verts)
    for p in points[1:-1]:
        s = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=radius)
        bmesh.ops.translate(bm, vec=Vector(p), verts=s["verts"])
    return _link(name, bm, mat, collection)


def smooth(objs, angle_deg: float = 35.0) -> None:
    """Sombreamento suave só onde o ângulo é pequeno (arestas vivas ficam vivas)."""
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in objs if o.type == "MESH"]
    for o in meshes:
        o.select_set(True)
    if not meshes:
        return
    bpy.context.view_layer.objects.active = meshes[0]
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle_deg))
    except Exception:
        for o in meshes:
            for p in o.data.polygons:
                p.use_smooth = True


def mirror_x(objs) -> None:
    """Espelha objetos em X (geometria já com transformações aplicadas) e corrige as normais."""
    for o in objs:
        if o.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.scale(bm, vec=Vector((-1, 1, 1)), verts=bm.verts)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


def join_by_material(objs, prefix: str = "", keep=lambda o: False) -> list:
    """Junta objetos que usam o mesmo material (menos draw calls no jogo). Devolve os novos objetos."""
    groups: dict = {}
    out = []
    for o in objs:
        if o.type != "MESH" or not o.data.materials:
            continue
        if keep(o):          # objetos editáveis (texto, face) ficam separados
            out.append(o)
            continue
        groups.setdefault(o.data.materials[0].name, []).append(o)
    for matname, lst in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in lst:
            o.select_set(True)
        bpy.context.view_layer.objects.active = lst[0]
        if len(lst) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = f"{prefix}{matname}"
        ob.data.name = ob.name
        out.append(ob)
    return out


def empty(name: str, loc, size: float = 0.15, collection=None) -> bpy.types.Object:
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = size
    e.location = loc
    (collection or bpy.context.scene.collection).objects.link(e)
    return e


def count_tris(objs) -> int:
    n = 0
    for o in objs:
        if o.type == "MESH":
            n += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return n


def export_glb(path: str, objs) -> None:
    """Exporta apenas `objs` (e seus filhos) para .glb com materiais embutidos (Y-up)."""
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_extras=True)


def torus(name, R, r, loc, mat=None, axis="Y", seg=28, tube_seg=8, collection=None):
    """Toro (anel). `axis` = eixo perpendicular ao plano do anel (X, Y ou Z). Para aros de farol, molduras."""
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = math.tau * i / seg
        ring = []
        for j in range(tube_seg):
            b = math.tau * j / tube_seg
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            ring.append(bm.verts.new((x, y, z)))
        verts.append(ring)
    for i in range(seg):
        for j in range(tube_seg):
            a, b = verts[i][j], verts[i][(j + 1) % tube_seg]
            c, d = verts[(i + 1) % seg][(j + 1) % tube_seg], verts[(i + 1) % seg][j]
            bm.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    if axis == "X":
        ob.rotation_euler = (0, math.radians(90), 0)
    elif axis == "Y":
        ob.rotation_euler = (math.radians(90), 0, 0)
    return ob


def plane_extrude(name, pts, depth, loc, mat=None, plane="XZ", bevel=0.01, seg=1, collection=None):
    """Polígono 2D extrudado. plane: XZ (extrude em Y, vista de frente/trás), YZ (extrude em X, vista
    lateral) ou XY (extrude em Z, vista de cima). pts = [(a, b), ...] sentido anti-horário."""
    bm = bmesh.new()
    def v(a, b, d):
        if plane == "XZ":
            return bm.verts.new((a, d, b))
        if plane == "YZ":
            return bm.verts.new((d, a, b))
        return bm.verts.new((a, b, d))
    front = [v(a, b, -depth / 2) for a, b in pts]
    back = [v(a, b, depth / 2) for a, b in pts]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    _bevel(bm, bevel, seg)
    ob = _link(name, bm, mat, collection)
    ob.location = loc
    return ob


def text3d(name, text, size, loc, mat=None, font_path=None, extrude=0.01, rot=(90, 0, 0), collection=None, resolution=12):
    """Texto 3D convertido em malha (sem bpy.ops). Gira 90° em X para ficar de pé, lendo de trás
    (olhando para +Y). Use rot=(90,0,180) para ler de frente."""
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = extrude
    curve.offset = size * 0.04
    curve.resolution_u = resolution
    if font_path:
        import os
        if os.path.exists(font_path):
            curve.font = bpy.data.fonts.load(font_path)
    tmp = bpy.data.objects.new(name + "_curve", curve)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(curve)
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    if mat is not None:
        ob.data.materials.append(mat)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob


def apply_transforms(objs) -> None:
    """Aplica rotação/escala/posição à malha (origem do objeto volta a 0,0,0 e a geometria fica
    no lugar). Necessário antes de juntar objetos e exportar."""
    for o in objs:
        if o.type == "MESH":
            o.data.transform(o.matrix_basis)
            o.matrix_basis = Matrix.Identity(4)


def bounds(objs):
    """(min, max) como Vector, em coordenadas Blender, considerando a matriz do objeto."""
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
            mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    return mn, mx


def uv_planar(o) -> None:
    """UV por face: projeta cada face nos 2 eixos perpendiculares à sua normal dominante, normalizado
    pela caixa do objeto (a textura cobre a face inteira 0..1). Usar antes de juntar os objetos."""
    me = o.data
    uvl = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    xs = [v.co for v in me.vertices]
    lo = [min(c[i] for c in xs) for i in range(3)]
    hi = [max(c[i] for c in xs) for i in range(3)]
    for poly in me.polygons:
        n = poly.normal
        k = max(range(3), key=lambda i: abs(n[i]))
        a, b = [i for i in range(3) if i != k]
        if k == 1:                      # frente/trás: u = X, v = Z
            a, b = 0, 2
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u = (co[a] - lo[a]) / max(hi[a] - lo[a], 1e-6)
            v = (co[b] - lo[b]) / max(hi[b] - lo[b], 1e-6)
            uvl.data[li].uv = (u, v)


def uv_world(o, tile: float = 4.0) -> None:
    """UV em metros (repete a textura a cada `tile` m): projeta cada face nos 2 eixos perpendiculares à
    sua normal dominante. Para pisos/paredes grandes com textura repetível. Aplique transformações antes."""
    me = o.data
    uvl = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    mw = o.matrix_world
    for poly in me.polygons:
        n = poly.normal
        k = max(range(3), key=lambda i: abs(n[i]))
        a, b = [i for i in range(3) if i != k]
        for li in poly.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = (co[a] / tile, co[b] / tile)
