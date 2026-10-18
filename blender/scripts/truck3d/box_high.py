"""Baú premium (T-136), versão ALTA: só existe no Blender, para gravar os mapas da versão leve (nunca vai para o jogo).

Mesmas medidas da leve (`box_layout`), com o detalhe de verdade: nervuras arredondadas, juntas das chapas com
colunas de rebites, rebites nos trilhos, nos montantes, na travessa, na soleira e nas colunas, arcos de reforço no
teto, parede da frente ondulada, portas com moldura estampada, vincos horizontais, folga e borracha de vedação.
"""
from __future__ import annotations

import bmesh
import bpy
from mathutils import Matrix, Vector

from lib import mesh3d as M
from lib.meshbuild import MeshBuilder, Rect, extrude_profile

from . import box_layout as BL
from . import box_premium as BP

FULL = Rect(0, 0, 1, 1)
SEAM_EVERY = 11            # junta de chapa a cada 11 nervuras (simétrico: 11, 22, 33, 44, 55)


def rivets(name: str, pts, normal: Vector, mat, r: float = 0.0068):
    """Cabeças de rebite (meia esfera achatada) em `pts`, viradas para `normal`."""
    bm = bmesh.new()
    rot = normal.to_track_quat("Z", "Y").to_matrix().to_4x4()
    for p in pts:
        g = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=4, radius=r)
        vs = g["verts"]
        bmesh.ops.scale(bm, vec=(1, 1, 0.55), verts=vs)
        bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(p)) @ rot, verts=vs)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def _side(lay, hm, out):
    w2 = lay.w2
    sheet = BP.side_sheet(lay, lay.z_rail_lo, lay.z_rail_hi, FULL, hi_res=16, rows=24).build("hi_side", hm["paint"])
    out.append(sheet)
    p = (lay.y1 - lay.y0) / BL.N_RIB
    crest = w2 + BL.RIB_OUT
    trough = w2 + BL.RIB_IN
    pts = []
    for i in range(BL.N_RIB):                                     # rebites no pé e no topo de cada vale
        y = lay.y0 + (i + 0.5) * p if False else lay.y0 + i * p + 0.075 * p
        for z in (lay.z_rail_lo + 0.03, lay.z_rail_hi - 0.03):
            pts.append((trough + 0.001, y, z))
    nz = int((lay.z_rail_hi - lay.z_rail_lo - 0.1) / 0.1)
    seam_ys = [lay.y0 + i * SEAM_EVERY * p for i in range(1, BL.N_RIB // SEAM_EVERY)]
    for ys in seam_ys + [lay.y0 + 0.5 * p * 0.3, lay.y1 - 0.5 * p * 0.3]:   # juntas e pontas: coluna de rebites
        for j in range(nz + 1):
            pts.append((trough + 0.001, ys, lay.z_rail_lo + 0.05 + j * 0.1))
    out.append(rivets("hi_rv_side", pts, Vector((1, 0, 0)), hm["paint"]))
    for ys in seam_ys:                                            # sobreposição da junta: tira fina em relevo
        mb = MeshBuilder()
        prof = [(w2 + off + 0.0025, y) for y, off in lay.rib_points(16) if abs(y - ys) < 0.6 * p]
        rows = [[(x, y, z) for x, y in prof] for z in (lay.z_rail_lo, lay.z_rail_hi)]
        mb.strip([[(x, y, z) for x, y, z in r] for r in rows], lambda i, j: (j / max(len(prof), 1), i))
        out.append(mb.build(f"hi_seam_{ys:.2f}", hm["paint"]))
    pts = []
    for yc in lay.post_ys():                                      # rebites nas abas dos montantes
        for dy in (-0.05, 0.05):
            for j in range(nz + 1):
                pts.append((w2 + 0.016, yc + dy, lay.z_rail_lo + 0.05 + j * 0.1))
    pts += [(w2 + BL.RAIL_OUT, lay.y0 + i * p + 0.075 * p, z) for i in range(BL.N_RIB)
            for z in ((lay.b.z0 + lay.z_rail_lo) / 2, (lay.z_rail_hi + lay.b.top) / 2)]
    out.append(rivets("hi_rv_metal", pts, Vector((1, 0, 0)), hm["metal"]))
    out.append(BP.metal_right(lay).build("hi_metal_R", hm["metal"]))


def _roof(lay, hm, out):
    b, w2 = lay.b, lay.w2
    rx = w2 - 0.05
    mb = BP.paint_panels(lay)
    out.append(mb.build("hi_panels", hm["paint"]))
    n = 14
    for i in range(1, n):                                         # arcos de reforço do teto
        y = i * b.l / n
        out.append(M.box(f"hi_bow_{i}", (2 * rx, 0.045, 0.008), (0, y, b.top + 0.008), hm["paint"], bevel=0.003, seg=2))
    out.append(rivets("hi_rv_roof", [(x * rx, i * b.l / n, b.top + 0.012) for i in range(1, n) for x in (-0.9, -0.45, 0, 0.45, 0.9)],
                      Vector((0, 0, 1)), hm["paint"], r=0.006))
    nf, fx = 16, w2 - 0.08                                        # parede da frente ondulada
    mb = MeshBuilder()
    xs = [(-fx + (2 * fx) * (i / (nf * 16))) for i in range(nf * 16 + 1)]
    rows = []
    for z in (b.z0, b.top):
        rows.append([(x, b.l + BL._rib_round(((x + fx) / (2 * fx) * nf) % 1.0) - BL.RIB_IN + 0.002, z) for x in xs[::-1]])
    mb.strip(rows, lambda i, j: (j / len(xs), i))
    out.append(mb.build("hi_front", hm["paint"]))


def _doors(lay, hm, out):
    b = lay.b
    dx, zd0, zd1 = lay.door_x, lay.z_door0, lay.z_door1
    y = BL.REAR_Y
    gap = 0.012
    out.append(M.box("hi_door_back", (2 * dx, 0.01, zd1 - zd0), (0, y + 0.012, (zd0 + zd1) / 2), hm["rubber"], bevel=0.0, seg=1))
    for sx in (-1, 1):
        x0, x1 = (gap, dx - gap) if sx > 0 else (-dx + gap, -gap)
        cx, w = (x0 + x1) / 2, x1 - x0
        h = zd1 - zd0 - 2 * gap
        zc = (zd0 + zd1) / 2
        out.append(M.box(f"hi_door_{sx}", (w, 0.03, h), (cx, y + 0.011, zc), hm["paint"], bevel=0.006, seg=2))
        for (ww, hh, d) in ((w - 0.02, 0.05, 0.005),):            # moldura estampada (borda em relevo)
            for zz in (zd0 + gap + 0.045, zd1 - gap - 0.045):
                out.append(M.box(f"hi_door_fr_h_{sx}_{zz:.2f}", (ww - 0.07, d, hh), (cx, y - 0.006, zz), hm["paint"], bevel=0.002, seg=2))
            for xx in (x0 + 0.045, x1 - 0.045):
                out.append(M.box(f"hi_door_fr_v_{sx}_{xx:.2f}", (0.05, d, h - 0.07), (xx, y - 0.006, zc), hm["paint"], bevel=0.002, seg=2))
        for t in (0.27, 0.5, 0.73):                                # vincos horizontais
            out.append(M.cylinder(f"hi_door_rib_{sx}_{t}", 0.016, w - 0.2, (cx, y - 0.002, zd0 + t * (zd1 - zd0)), hm["paint"],
                                  axis="X", seg=16))
        out.append(M.box(f"hi_seal_{sx}", (w + 0.02, 0.008, h + 0.02), (cx, y + 0.016, zc), hm["rubber"], bevel=0.004, seg=2))
    out.append(BP.metal_center(lay).build("hi_metal_C", hm["metal"]))
    pts = [(x, -0.081, z) for z in (b.z0 + 0.03, lay.z_door0 - 0.035, lay.z_door1 + 0.035, b.top - 0.025)
           for x in [(-dx + 0.06 + i * (2 * dx - 0.12) / 14) for i in range(15)]]
    for sx in (-1, 1):
        pts += [(sx * (lay.w2 - 0.03), -0.081, b.z0 + 0.08 + j * 0.15) for j in range(int((b.top - b.z0) / 0.15))]
    out.append(rivets("hi_rv_rear", pts, Vector((0, -1, 0)), hm["metal"]))


def build_high(lay: BL.Layout, hm: dict):
    """Malhas altas (lado direito + centro). Devolve a lista de objetos (fontes do bake)."""
    out = []
    _side(lay, hm, out)
    _roof(lay, hm, out)
    _doors(lay, hm, out)
    for o in out:
        if o.type == "MESH":
            M.apply_transforms([o])
            M.uv_world(o, 1.0)                                    # texturas CC0 em metros (o material escala)
    return out
