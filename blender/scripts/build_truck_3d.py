"""Caminhão base 3D (PBR) para o Godot: cabine plana japonesa GENÉRICA + baú, ~12 x 2,5 x 3,4 m.

Uso: blender -b --factory-startup -P blender/scripts/build_truck_3d.py -- [--out game/assets/vehicles/dekotora]
Saída: <out>/truck/dekotora_truck_base.glb, <out>/source_blend/truck_base.blend, <out>/previews/truck_base_*.png

Convenções: metros, +Y frente, Z cima, traseira do baú em Y=0, X=0 no centro. As peças usam os pontos
de montagem (empties MOUNT_*) criados aqui; o glTF os exporta como nós.
"""
import argparse
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, pbr, preview, scene  # noqa: E402

# --- medidas do caminhão (m): as peças e os testes usam estes números
BODY_W, BODY_L, BODY_Z0, BODY_TOP = 2.5, 8.2, 1.1, 3.2
CAB_W, CAB_Y0, CAB_Y1, CAB_Z0, CAB_TOP = 2.4, 8.45, 11.5, 0.9, 3.35
REAR_AXLES_Y = (1.5, 3.0)
FRONT_AXLE_Y = 10.2
WHEEL_R = 0.52

MOUNTS = {
    "MOUNT_FRONT_BUMPER": (0.0, CAB_Y1, 0.45),
    "MOUNT_FRONT_GRILLE": (0.0, CAB_Y1, 1.25),
    "MOUNT_VISOR": (0.0, 11.12, CAB_TOP - 0.05),
    "MOUNT_ROOF": (0.0, 10.0, CAB_TOP),
    "MOUNT_ROOF_LIGHTS": (0.0, 11.0, CAB_TOP),
    "MOUNT_SIDE_LEFT": (-BODY_W / 2, 4.5, 0.95),
    "MOUNT_SIDE_RIGHT": (BODY_W / 2, 4.5, 0.95),
    "MOUNT_CAB_SIDE_LEFT": (-CAB_W / 2, 10.0, 1.0),
    "MOUNT_CAB_SIDE_RIGHT": (CAB_W / 2, 10.0, 1.0),
    "MOUNT_REAR": (0.0, 0.0, 0.7),
    "MOUNT_REAR_PANEL": (0.0, 0.0, 2.2),
    "MOUNT_REAR_ROOF": (0.0, 0.2, BODY_TOP),
    "MOUNT_WHEEL_FRONT_L": (-1.0, FRONT_AXLE_Y, 0.5),
    "MOUNT_WHEEL_FRONT_R": (1.0, FRONT_AXLE_Y, 0.5),
    "MOUNT_WHEEL_REAR_L": (-1.06, REAR_AXLES_Y[0], 0.52),
    "MOUNT_WHEEL_REAR_R": (1.06, REAR_AXLES_Y[0], 0.52),
    "MOUNT_MUDFLAP_L": (-0.95, 0.45, 0.8),
    "MOUNT_MUDFLAP_R": (0.95, 0.45, 0.8),
    "MOUNT_FENDER_L": (-1.1, 2.25, 1.1),
    "MOUNT_FENDER_R": (1.1, 2.25, 1.1),
    "MOUNT_STEP_L": (-CAB_W / 2, 9.4, 0.55),
    "MOUNT_STEP_R": (CAB_W / 2, 9.4, 0.55),
}


def build_truck(m: dict, paint_name: str = "paint_white"):
    """Devolve (meshes_estaticas, rodas, empties). `m` = dicionário de materiais (pbr.standard_set)."""
    body_paint = m[paint_name]
    parts = []
    wheels = []
    W2 = BODY_W / 2

    def add(o):
        parts.append(o)
        return o

    # ---- chassi, tanque, eixos
    add(M.box("chassis", (1.9, 11.5, 0.28), (0, 6.0, 0.62), m["plastic"], bevel=0.04))
    add(M.cylinder("tank_l", 0.32, 1.5, (-1.0, 6.5, 0.55), m["steel"], axis="Y", bevel=0.05))
    add(M.cylinder("tank_r", 0.32, 1.5, (1.0, 6.5, 0.55), m["steel"], axis="Y", bevel=0.05))
    # ---- baú
    add(M.box("body", (BODY_W, BODY_L, BODY_TOP - BODY_Z0), (0, BODY_L / 2, (BODY_Z0 + BODY_TOP) / 2), body_paint, bevel=0.07, seg=3))
    for i, z in enumerate((1.55, 2.2, 2.85)):       # nervuras horizontais do baú
        add(M.box(f"rib_{i}", (BODY_W + 0.03, BODY_L - 0.3, 0.035), (0, BODY_L / 2, z), m["steel"], bevel=0.01, seg=1))
    add(M.box("stripe_body", (BODY_W + 0.05, BODY_L + 0.04, 0.22), (0, BODY_L / 2, 1.85), m["paint_pink"], bevel=0.02, seg=1))
    add(M.box("trim_top", (BODY_W + 0.06, BODY_L + 0.02, 0.08), (0, BODY_L / 2, BODY_TOP - 0.02), m["chrome"], bevel=0.02, seg=1))
    # ---- porta traseira
    add(M.box("door_seam", (0.04, 0.05, 2.0), (0, -0.03, 2.15), m["plastic"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        for z in (1.5, 2.3, 3.0):
            add(M.cylinder(f"hinge_{sx}_{z}", 0.05, 0.22, (sx * (W2 + 0.02), -0.05, z), m["steel"], axis="Z", seg=10))
        add(M.cylinder(f"lockbar_{sx}", 0.025, 1.9, (sx * 0.45, -0.07, 2.12), m["chrome"], axis="Z", seg=10))
        add(M.box(f"lockhandle_{sx}", (0.08, 0.06, 0.18), (sx * 0.45, -0.1, 2.0), m["chrome"], bevel=0.015, seg=1))
    for i in range(10):                              # faixa refletiva vermelho/branco
        x = -1.1 + i * 0.245
        add(M.box(f"refl_{i}", (0.235, 0.03, 0.14), (x, -0.025, 1.22), m["paint_red"] if i % 2 == 0 else m["paint_white"], bevel=0.008, seg=1))
    add(M.box("plate", (0.5, 0.03, 0.22), (0, -0.04, 1.0), m["paint_white"], bevel=0.01, seg=1))
    for x in (0.8, 1.12):                            # escada
        add(M.box(f"ladder_rail_{x}", (0.05, 0.06, 2.0), (x, -0.12, 2.15), m["chrome"], bevel=0.01, seg=1))
    for i in range(6):
        add(M.box(f"ladder_rung_{i}", (0.37, 0.05, 0.045), (0.96, -0.14, 1.3 + i * 0.33), m["chrome"], bevel=0.01, seg=1))
    for sx in (-1, 1):                               # lanternas traseiras
        add(M.box(f"tail_{sx}", (0.34, 0.07, 0.5), (sx * 1.0, -0.045, 1.55), m["lamp_red"], bevel=0.03))
        add(M.box(f"tail_rim_{sx}", (0.4, 0.04, 0.56), (sx * 1.0, -0.02, 1.55), m["chrome"], bevel=0.03, seg=1))
    # ---- cabine
    cab_pts = [(CAB_Y0, CAB_Z0), (CAB_Y0, CAB_TOP), (11.15, CAB_TOP), (CAB_Y1, 2.1), (CAB_Y1, CAB_Z0)]
    add(M.profile_extrude("cab", cab_pts, CAB_W, (0, 0, 0), body_paint, bevel=0.09, seg=3))
    add(M.box("stripe_cab", (CAB_W + 0.04, CAB_Y1 - CAB_Y0 - 0.1, 0.22), (0, (CAB_Y0 + CAB_Y1) / 2 - 0.05, 1.85), m["paint_pink"], bevel=0.02, seg=1))
    slope = math.degrees(math.atan2(0.35, 1.05))
    add(M.box("windshield", (2.12, 0.05, 1.12), (0, 11.34, 2.65), m["glass"], bevel=0.02, seg=1, rot=(slope, 0, 0)))
    add(M.box("windshield_frame", (2.22, 0.04, 1.22), (0, 11.325, 2.65), m["steel"], bevel=0.02, seg=1, rot=(slope, 0, 0)))
    for sx in (-1, 1):
        add(M.box(f"side_window_{sx}", (0.05, 1.35, 0.85), (sx * (CAB_W / 2 + 0.015), 10.15, 2.65), m["glass"], bevel=0.02, seg=1))
        add(M.box(f"door_line_{sx}", (0.03, 0.03, 1.9), (sx * (CAB_W / 2 + 0.015), 9.35, 2.0), m["plastic"], bevel=0.005, seg=1))
        add(M.box(f"door_handle_{sx}", (0.05, 0.22, 0.05), (sx * (CAB_W / 2 + 0.03), 9.65, 1.9), m["chrome"], bevel=0.01, seg=1))
        # espelhos
        add(M.box(f"mirror_{sx}", (0.08, 0.2, 0.55), (sx * (CAB_W / 2 + 0.28), 11.05, 2.35), m["plastic"], bevel=0.025))
        add(M.box(f"mirror_face_{sx}", (0.02, 0.18, 0.5), (sx * (CAB_W / 2 + 0.33), 11.05, 2.35), m["chrome"], bevel=0.01, seg=1))
        add(M.cylinder(f"mirror_arm_{sx}", 0.02, 0.35, (sx * (CAB_W / 2 + 0.13), 11.05, 2.7), m["steel"], axis="X", seg=8))
        # faróis frontais e pisca
        add(M.box(f"headlight_{sx}", (0.5, 0.08, 0.3), (sx * 0.85, CAB_Y1 + 0.03, 1.3), m["lamp_white"], bevel=0.04))
        add(M.box(f"headlight_rim_{sx}", (0.58, 0.05, 0.38), (sx * 0.85, CAB_Y1 + 0.015, 1.3), m["chrome"], bevel=0.04, seg=1))
        add(M.box(f"blinker_{sx}", (0.18, 0.06, 0.12), (sx * 1.1, CAB_Y1 + 0.03, 0.98), m["lamp_amber"], bevel=0.02, seg=1))
        # escapamentos verticais cromados atrás da cabine
        add(M.cylinder(f"stack_{sx}", 0.1, 2.9, (sx * 1.3, 8.3, 2.05), m["chrome"], axis="Z", seg=16, bevel=0.01))
        add(M.cylinder(f"stack_cap_{sx}", 0.115, 0.1, (sx * 1.3, 8.3, 3.5), m["chrome"], axis="Z", seg=16))
        add(M.box(f"stack_clamp_{sx}", (0.28, 0.16, 0.08), (sx * 1.3, 8.3, 1.2), m["steel"], bevel=0.015, seg=1))
        add(M.box(f"stack_clamp2_{sx}", (0.28, 0.16, 0.08), (sx * 1.3, 8.3, 2.6), m["steel"], bevel=0.015, seg=1))
        # estribos / degraus
        add(M.box(f"step_{sx}", (0.25, 0.7, 0.05), (sx * (CAB_W / 2 + 0.12), 9.4, 0.55), m["steel"], bevel=0.01, seg=1))
    add(M.box("grille", (1.3, 0.06, 0.55), (0, CAB_Y1 + 0.02, 1.2), m["plastic"], bevel=0.03))
    for i in range(5):
        add(M.box(f"grille_bar_{i}", (1.3, 0.05, 0.035), (0, CAB_Y1 + 0.05, 0.98 + i * 0.11), m["chrome"], bevel=0.008, seg=1))
    add(M.box("front_panel_low", (2.3, 0.07, 0.5), (0, CAB_Y1 + 0.01, 0.65), m["plastic"], bevel=0.03))
    add(M.box("cab_back_gap", (2.0, 0.3, 0.4), (0, 8.3, 0.9), m["plastic"], bevel=0.03))
    # luz decorativa sob o chassi (neon)
    for sx in (-1, 1):
        add(M.box(f"underglow_{sx}", (0.05, 10.0, 0.05), (sx * 0.98, 6.0, 0.42), m["lamp_cyan"], bevel=0.01, seg=1))
    # ---- rodas
    for sx in (-1, 1):
        for y in REAR_AXLES_Y:
            for tx in (0.72, 1.06):
                wheels.append(_wheel(f"wheel_r_{'L' if sx < 0 else 'R'}_{y}_{tx}", (sx * tx, y, WHEEL_R), m, rim=(tx > 1.0)))
        wheels.append(_wheel(f"wheel_f_{'L' if sx < 0 else 'R'}", (sx * 1.0, FRONT_AXLE_Y, 0.5), m, rim=True, radius=0.5))
        add(M.box(f"fender_{sx}", (0.66, 2.3, 0.07), (sx * 1.02, 2.25, 1.13), m["plastic"], bevel=0.02, seg=1))
        add(M.box(f"mudflap_{sx}", (0.5, 0.04, 0.5), (sx * 0.95, 0.45, 0.8), m["rubber"], bevel=0.01, seg=1))
        add(M.box(f"fender_front_{sx}", (0.5, 1.4, 0.07), (sx * 1.0, FRONT_AXLE_Y, 1.05), m["plastic"], bevel=0.02, seg=1))
    empties = [M.empty(n, p) for n, p in MOUNTS.items()]
    return parts, wheels, empties


def _wheel(name, loc, m, rim=True, radius=WHEEL_R, width=0.3):
    """Pneu (cilindro chanfrado) + aro cromado + miolo + porcas. Um único objeto por roda."""
    tire = M.cylinder(name + "_tire", radius, width, loc, m["rubber"], axis="X", seg=28, bevel=0.07, bevel_seg=3)
    parts = [tire]
    side = 1 if loc[0] >= 0 else -1
    face = loc[0] + side * (width / 2 + 0.005)
    if rim:
        parts.append(M.cylinder(name + "_rim", radius * 0.62, 0.04, (face, loc[1], loc[2]), m["chrome"], axis="X", seg=28, bevel=0.01, bevel_seg=1))
        parts.append(M.cylinder(name + "_hub", radius * 0.28, 0.06, (face + side * 0.02, loc[1], loc[2]), m["steel"], axis="X", seg=16))
        for k in range(8):
            a = k * math.tau / 8
            parts.append(M.cylinder(f"{name}_nut{k}", 0.025, 0.05, (face + side * 0.04, loc[1] + math.cos(a) * radius * 0.45, loc[2] + math.sin(a) * radius * 0.45), m["plastic"], axis="X", seg=6))
    else:
        parts.append(M.cylinder(name + "_disc", radius * 0.6, 0.03, (face, loc[1], loc[2]), m["steel"], axis="X", seg=20))
    return parts


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/vehicles/dekotora")
    ap.add_argument("--paint", default="paint_white")
    args = ap.parse_args(argv)
    out = os.path.abspath(args.out)
    scene.reset_scene()
    m = pbr.standard_set()
    parts, wheels, empties = build_truck(m, args.paint)
    all_meshes = parts + [w for ws in wheels for w in ws]
    M.smooth(all_meshes, 35.0)
    tris = M.count_tris(all_meshes)
    # junta por material (poucos draw calls); cada roda vira um objeto para poder girar
    merged = M.join_by_material(parts, prefix="truck_")
    wheel_objs = []
    for ws in wheels:
        bpy.ops.object.select_all(action="DESELECT")
        for o in ws:
            o.select_set(True)
        bpy.context.view_layer.objects.active = ws[0]
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        # origem no centro da roda para girar no eixo X
        base = o.name.replace("_tire", "")
        o.name = base
        o.data.name = base
        bpy.context.scene.cursor.location = o.location if False else (0, 0, 0)
        wheel_objs.append(o)
    # pivô das rodas: origem no centro do pneu
    for o in wheel_objs:
        verts = [v.co for v in o.data.vertices]
        cx = sum(v.x for v in verts) / len(verts)
        cy = sum(v.y for v in verts) / len(verts)
        cz = sum(v.z for v in verts) / len(verts)
        for v in o.data.vertices:
            v.co.x -= cx
            v.co.y -= cy
            v.co.z -= cz
        o.location = (o.location.x + cx, o.location.y + cy, o.location.z + cz)
    root = bpy.data.objects.new("DekotoraTruckBase", None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged + wheel_objs + empties:
        o.parent = root
    final = [root] + merged + wheel_objs + empties
    print(f"triangulos: {tris}  objetos: {len(final)}  materiais: {len(bpy.data.materials)}")
    glb = os.path.join(out, "truck", "dekotora_truck_base.glb")
    M.export_glb(glb, final)
    os.makedirs(os.path.join(out, "source_blend"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "source_blend", "truck_base.blend"))
    pdir = os.path.join(out, "previews")
    preview.render_views(os.path.join(pdir, "truck_base"), merged + wheel_objs, size=(960, 540))
    print("OK build_truck_3d ->", glb)


main()
