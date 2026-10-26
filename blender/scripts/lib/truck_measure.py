"""Medidas de um caminhão do jogo a partir do .glb (T-211): cabine, teto, para-brisa, faróis, lanternas, portas, rodas e
baú. Tudo em coordenadas do GODOT (x direita, y cima, frente = -z, traseira do baú em z = 0), que é o que o jogo e o
teste de encaixe usam. Determinístico: só lê vértices (numpy), nada de raios nem aleatório.

Usado por `build_sockets.py` (que transforma as medidas em encaixes e zonas protegidas, `lib/socket_rules.py`).
"""
from __future__ import annotations

import os

import bpy
import numpy as np

SLICE = 0.05                      # m: fatia ao longo de z para o perfil do teto


def import_truck(path: str) -> dict:
    """Importa o .glb numa cena vazia. Devolve {nome do objeto sem sufixo: matriz Nx3 de vértices (Godot)} e os
    pontos MOUNT_* (Godot)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    bpy.context.view_layer.update()
    objs: dict = {}
    mounts: dict = {}
    for o in bpy.data.objects:
        base = o.name.split(".")[0]
        if o.type == "MESH":
            mw = np.array(o.matrix_world)
            co = np.empty(len(o.data.vertices) * 3)
            o.data.vertices.foreach_get("co", co)
            w = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
            g = np.stack([w[:, 0], w[:, 2], -w[:, 1]], 1)
            objs[base] = np.concatenate([objs[base], g]) if base in objs else g
        elif base.startswith("MOUNT_"):
            t = o.matrix_world.translation
            mounts[base] = [float(t.x), float(t.z), float(-t.y)]
    return {"objs": objs, "mounts": mounts}


def _cat(objs: dict, names) -> np.ndarray:
    parts = [objs[n] for n in names if n in objs]
    return np.concatenate(parts) if parts else np.zeros((0, 3))


def _aabb(v: np.ndarray) -> list:
    return [[round(float(x), 3) for x in v.min(0)], [round(float(x), 3) for x in v.max(0)]]


def _split_lr(v: np.ndarray) -> dict:
    out = {}
    for side, sel in (("l", v[:, 0] < 0), ("r", v[:, 0] > 0)):
        if sel.any():
            out[side] = _aabb(v[sel])
    return out


def measure(data: dict, body: str) -> dict:
    """Medidas da cabine, do baú e das peças protegidas. `body`: base | leve | longo | graneleira | canter | carreta."""
    objs = data["objs"]
    panel = objs.get("truck_paint_white_panel", np.zeros((0, 3)))
    wind = objs["truck_glass_wind"]
    side_glass = objs.get("truck_glass", wind)
    shell = _cat(objs, ["truck_paint_white_panel", "truck_plastic_trim", "truck_glass", "truck_glass_wind"])
    body_all = _cat(objs, [n for n in objs if not n.startswith("wheel_")])
    wheels = {n: _aabb(v) for n, v in objs.items() if n.startswith("wheel_")}

    # --- cabine: parte da casca na frente do fim do vidro lateral (baú clássico, Canter e graneleira têm a chapa do
    # baú no mesmo material da cabine): corta no baú de metal, senão logo atrás do vidro, e onde a chapa sobe de repente
    glass_back = float(side_glass[:, 2].max())
    box_v = _cat(objs, ["truck_box_metal", "truck_paint_white_box", "truck_box_alu", "truck_box_pink", "truck_tarp",
                        "truck_tank_shell", "truck_dump_bed"])        # T-218: baús e cargas dos caminhões de homenagem
    box_front = float(box_v[:, 2].min()) if len(box_v) else None
    cab_lim = (box_front - 0.01) if box_front is not None else glass_back + 0.25
    cab = panel[panel[:, 2] <= cab_lim]
    gl = cab[(cab[:, 2] >= float(side_glass[:, 2].min())) & (cab[:, 2] <= glass_back)]
    ref_top = float(np.median([gl[(gl[:, 2] >= z) & (gl[:, 2] < z + 0.2), 1].max()
                               for z in np.arange(float(gl[:, 2].min()), glass_back, 0.2)
                               if ((gl[:, 2] >= z) & (gl[:, 2] < z + 0.2)).any()]))
    for z in np.arange(float(side_glass[:, 2].min()), cab_lim, SLICE):
        sel = cab[(cab[:, 2] >= z) & (cab[:, 2] < z + SLICE)]
        if len(sel) and sel[:, 1].max() > ref_top + 0.3:          # parede do baú logo atrás da cabine (Canter)
            cab_lim = float(z) - 0.02
            cab = cab[cab[:, 2] <= cab_lim]
            break
    cab_front = float(cab[:, 2].min())
    # teto: ponto mais alto da casca da cabine e a faixa plana (até 6 cm abaixo do topo)
    zs = np.arange(cab_front, float(cab[:, 2].max()) + SLICE, SLICE)
    prof = []
    for z in zs:
        sel = cab[(cab[:, 2] >= z) & (cab[:, 2] < z + SLICE)]
        if len(sel):
            prof.append([round(float(z), 3), round(float(sel[:, 1].max()), 3)])
    prof_a = np.array(prof)
    roof_shell = float(prof_a[:, 1].max())
    flat = prof_a[prof_a[:, 1] >= roof_shell - 0.06]
    roof_front, roof_back = float(flat[:, 0].min()), float(flat[:, 0].max()) + SLICE
    roof_back = min(roof_back, cab_lim - 0.03)
    slope = prof_a[(prof_a[:, 1] >= roof_shell - 0.40) & (prof_a[:, 0] <= roof_front)]
    slope_front = float(slope[:, 0].min()) if len(slope) else roof_front
    # tudo que está no teto da cabine (lâmpadas de fábrica etc.) dentro da faixa do teto
    on_roof = body_all[(body_all[:, 2] >= slope_front) & (body_all[:, 2] <= roof_back) & (np.abs(body_all[:, 0]) < 1.4)]
    roof_y = max(roof_shell, float(on_roof[:, 1].max()) if len(on_roof) else roof_shell)
    top_band = shell[(shell[:, 1] >= roof_shell - 0.5) & (shell[:, 2] >= slope_front) & (shell[:, 2] <= roof_back)]
    roof_half = float(np.abs(top_band[:, 0]).max()) if len(top_band) else 1.1
    vis_band = shell[(shell[:, 1] >= float(wind[:, 1].max()) - 0.1) & (shell[:, 1] <= float(wind[:, 1].max()) + 0.3) & (shell[:, 2] <= glass_back)]
    visor_half = float(np.abs(vis_band[:, 0]).max()) if len(vis_band) else 1.1
    mid_band = shell[(shell[:, 1] >= 1.4) & (shell[:, 1] <= roof_shell) & (shell[:, 2] <= glass_back)]
    cab_half = float(np.abs(mid_band[:, 0]).max())
    # testa (acima do para-brisa): onde a viseira encosta
    wy1 = float(wind[:, 1].max())
    band = cab[(cab[:, 1] >= wy1 - 0.03) & (cab[:, 1] <= wy1 + 0.25)]
    visor_back = float(band[:, 2].min()) if len(band) else float(wind[:, 2].min())
    front_prof = []
    for y in np.arange(wy1 - 0.05, roof_shell + 0.01, 0.05):
        sel = cab[(cab[:, 1] >= y) & (cab[:, 1] < y + 0.05)]
        if len(sel):
            front_prof.append([round(float(y), 3), round(float(sel[:, 2].min()), 3)])

    # --- luzes da frente (farol branco/lente; lanterna âmbar) abaixo do para-brisa e na frente da cabine
    wy0 = float(wind[:, 1].min())
    front_z = cab_front + 0.6

    def front_of(names):
        v = _cat(objs, names)
        return v[(v[:, 2] <= front_z) & (v[:, 1] < wy0 - 0.05)] if len(v) else v
    head = front_of(["truck_lamp_white", "truck_glass_lens"])
    amber = front_of(["truck_lamp_amber"])
    inner = float(np.abs(head[:, 0]).min()) if len(head) else 0.7
    amber = amber[np.abs(amber[:, 0]) >= inner] if len(amber) else amber      # a lanterna da quina (a fileira do meio é enfeite)
    reds = _cat(objs, ["truck_lamp_red"])
    rear_red = reds[(reds[:, 2] >= -0.4) & (reds[:, 1] < 1.0)] if len(reds) else reds
    # portas: vidro lateral da frente (o da cabine) + altura do degrau
    sg = side_glass[side_glass[:, 2] <= glass_back]
    dz0 = max(float(sg[:, 2].min()) + 0.05, cab_front + 0.35)
    door = {"z": [round(dz0, 3), round(min(dz0 + 1.1, glass_back - 0.05), 3)],
            "y": [0.62, round(float(sg[:, 1].max()), 3)]}
    out = {
        "cab": {
            "front_z": round(cab_front, 3), "half_w": round(cab_half, 3), "roof_half_w": round(roof_half, 3), "visor_half_w": round(visor_half, 3),
            "roof_shell_y": round(roof_shell, 3), "roof_y": round(roof_y, 3), "roof_front_z": round(roof_front, 3),
            "roof_back_z": round(roof_back, 3), "slope_front_z": round(slope_front, 3), "visor_back_z": round(visor_back, 3),
            "windshield": _aabb(wind), "side_glass": _aabb(sg), "door": door,
            "roof_profile": prof, "front_profile": front_prof,
        },
        "headlights": _split_lr(head) if len(head) else {},
        "front_lamps": _split_lr(amber) if len(amber) else {},
        "rear_lamps": _split_lr(rear_red) if len(rear_red) else {},
        "wheels": wheels,
        "mounts": data["mounts"],
    }
    if len(box_v):
        out["box"] = {"front_z": round(box_front, 3), "rear_z": round(float(box_v[:, 2].max()), 3),
                      "top_y": round(float(box_v[:, 1].max()), 3), "bottom_y": round(float(box_v[:, 1].min()), 3),
                      "half_w": round(float(np.abs(box_v[:, 0]).max()), 3)}
    else:
        bx = panel[(panel[:, 2] > cab_lim + 0.05) & (panel[:, 1] > 0.8)]
        out["box"] = {"front_z": round(float(bx[:, 2].min()), 3), "rear_z": round(float(bx[:, 2].max()), 3),
                      "top_y": round(float(bx[:, 1].max()), 3), "bottom_y": round(float(bx[:, 1].min()), 3),
                      "half_w": round(float(np.abs(bx[:, 0]).max()), 3)}
    return out


# ----------------------------------------------------------------------------- superfícies reais (T-214)

GRID = 0.05                       # m: passo das grades de apoio (teto e testa)
GRID_Y = 0.02                     # m: passo vertical da grade da testa
MISS = -99.0                      # raio que não bateu em nada


def _bvh(include=None, exclude=("wheel_",)):
    """BVH (Blender) das malhas do caminhão importado: todas menos as rodas, ou só as de `include`."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    for o in sorted(bpy.data.objects, key=lambda o: o.name):
        if o.type != "MESH" or o.name.startswith(exclude):
            continue
        if include is not None and o.name.split(".")[0] not in include:
            continue
        me = o.to_mesh()
        me.transform(o.matrix_world)
        bm.from_mesh(me)
        o.to_mesh_clear()
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def surfaces(m: dict) -> dict:
    """Grades de apoio medidas por RAIOS na malha real (T-214), em coordenadas do Godot:
    - roof: altura do 1º ponto atingido de cima para baixo (teto da cabine + o que estiver nele), em x × z;
    - front: z do 1º ponto atingido vindo da FRENTE (para-brisa, testa, viseira de fábrica), em x × y;
    - lean: inclinação do para-brisa perto da borda de cima (dz/dy: quanto o vidro vai para trás por metro de subida).
    Chame logo depois de `import_truck` (usa os objetos importados). Determinístico."""
    from mathutils import Vector
    c = m["cab"]
    tree = _bvh()
    glass = _bvh(include=("truck_glass_wind",))
    hw = c["half_w"] + 0.05
    nx = int(round(2 * hw / GRID)) + 1
    x0 = -GRID * (nx - 1) / 2
    xs = [round(x0 + GRID * i, 4) for i in range(nx)]
    # teto: da testa (um pouco antes do começo da descida) até o fim da cabine
    z0 = round(c["slope_front_z"] - 0.30, 3)
    nz = int(round((c["roof_back_z"] + 0.02 - z0) / GRID)) + 1
    top = c["roof_shell_y"] + 2.0
    roof = []
    for j in range(nz):
        z = z0 + GRID * j
        for x in xs:
            hit = tree.ray_cast(Vector((x, -z, top)), Vector((0, 0, -1)))
            roof.append(round(hit[0].z, 3) if hit[0] is not None else MISS)
    # testa: da borda de cima do vidro até acima do teto
    wy1 = c["windshield"][1][1]
    y0 = round(wy1 - 0.10, 3)
    ny = int(round((c["roof_shell_y"] + 0.06 - y0) / GRID_Y)) + 1
    zf = c["front_z"] - 3.0
    front = []
    for j in range(ny):
        y = y0 + GRID_Y * j
        for x in xs:
            hit = tree.ray_cast(Vector((x, -zf, y)), Vector((0, -1, 0)))
            front.append(round(-hit[0].y, 3) if hit[0] is not None else MISS)
    # inclinação do vidro nos últimos 60 cm (reta pelos pontos do centro e de ±0,3 m)
    pts = []
    for x in (-0.3, 0.0, 0.3):
        y = wy1 - 0.60
        while y <= wy1 - 0.03:
            hit = glass.ray_cast(Vector((x, -zf, y)), Vector((0, -1, 0)))
            if hit[0] is not None:
                pts.append((y, -hit[0].y))
            y += 0.02
    a = np.array(pts) if pts else np.zeros((0, 2))
    lean = float(np.polyfit(a[:, 0], a[:, 1], 1)[0]) if len(a) >= 4 else 0.0
    return {
        "roof": {"x0": xs[0], "dx": GRID, "nx": nx, "z0": z0, "dz": GRID, "nz": nz, "h": roof},
        "front": {"x0": xs[0], "dx": GRID, "nx": nx, "y0": y0, "dy": GRID_Y, "ny": ny, "z": front},
        "lean": round(lean, 4),
        "glass_top": [round(float(a[:, 0].max()), 3), round(float(a[a[:, 0].argmax(), 1]), 3)] if len(a) else None,
    }
