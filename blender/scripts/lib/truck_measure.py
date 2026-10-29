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


def kit_stretch(y: float, y0: float, front: float, ext: float, shift: float = 0.0) -> float:
    """T-251: posição (m, para a frente) depois de esticar a carga do kit; igual a TruckKit.stretch_y do jogo."""
    if y <= y0:
        return y
    if y >= front:
        return y + shift
    return y0 + (y - y0) * (front - y0 + ext) / (front - y0)


def import_truck(path) -> dict:
    """Importa o .glb numa cena vazia. Devolve {nome do objeto sem sufixo: matriz Nx3 de vértices (Godot)} e os
    pontos MOUNT_* (Godot). T-240: `path` pode ser uma lista (carroceria + cabine do kit): as malhas de mesmo nome
    viram uma só, como o jogo faz (TruckKit)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for k, p in enumerate([path] if isinstance(path, str) else list(path)):
        dy = 0.0
        st = None
        if isinstance(p, (tuple, list)):                       # (.glb, deslocamento para a frente em m[, esticar]): kit
            p, dy, st = (tuple(p) + (None,))[:3]
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(p))
        if dy:
            for o in bpy.data.objects:
                if o not in before and o.parent is None:
                    o.location.y += dy
        new = [o for o in bpy.data.objects if o not in before]
        if st:                                                 # T-251: a carga estica até a cabine (igual ao TruckKit)
            bpy.context.view_layer.update()
            for o in new:
                if o.type == "MESH" and o.name.startswith("truck_"):
                    mw = o.matrix_world
                    inv = mw.inverted()
                    for v in o.data.vertices:
                        w = mw @ v.co
                        w.y = kit_stretch(w.y, *st)
                        v.co = inv @ w
                    o.data.update()
                elif o.name.startswith("MOUNT_"):
                    o.location.y = kit_stretch(o.matrix_world.translation.y, *st) - (o.matrix_world.translation.y - o.location.y)
            for o in new:
                if o.type == "MESH" and o.name.startswith("frame_"):
                    o.name = "truck_" + o.name[len("frame_"):]
        if k == 0 and not isinstance(path, str):               # carroceria do kit: a chapa do baú antigo usa o material
            for o in [o for o in bpy.data.objects if o not in before]:     # da cabine; aqui ela conta como baú
                if o.type == "MESH" and o.name.split(".")[0] == "truck_paint_white_panel":
                    o.name = "truck_paint_white_box"
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


# ----------------------------------------------------------------------------- traseira, foguete e contorno do baú (T-231)

EDGE_STEP = 0.05                  # m: passo das células ao longo das bordas do baú
STRIP_W = 0.025                   # m: largura da faixa do contorno de LED
STRIP_MIN = 0.25                  # m: trecho livre mais curto que isto não leva contorno
STRIP_LO, STRIP_HI = 0.025, 0.012 # m: a lataria embaixo da faixa pode estar até isto abaixo/acima do plano da face
LAMP_GAP = 0.012                  # m: distância mínima entre a faixa e uma lanterna de fábrica
RB_TOP_MAX = 0.93                 # m: topo do para-choque traseiro (as setas de trás começam em 0,95)
ROCKET_MIN_W = 0.12               # m: faixa do foguete mais estreita que isto não serve
ROCKET_GAP = 0.012                # m: folga entre o foguete e o contorno de LED do teto
# T-240 (foguete maior): a faixa mais LARGA cujo trecho livre tem pelo menos esta fração do maior trecho. Antes 0,97: nos
# baús com andon de fábrica nas pontas do teto (médio premium, baú rosa) o foguete ficava fino (0,13–0,16 m) espremido ao
# lado dos andons; agora ele fica largo e para antes deles (um pouco mais curto).
ROCKET_RUN = 0.85


def _protrusion(tree, p, n, reach=0.6):
    """Quanto a lataria em `p` (Godot) sai para fora da face de normal `n` (raio vindo de fora). None = nada."""
    from mathutils import Vector
    o = Vector((p[0] + n[0] * reach, -(p[2] + n[2] * reach), p[1] + n[1] * reach))
    d = Vector((-n[0], n[2], -n[1]))
    hit = tree.ray_cast(o, d, reach + 0.3)
    if hit[0] is None:
        return None
    return reach - hit[3]


def _line_cells(tree, lamps, a, b, n, across):
    """Saliência da lataria nas células de a até b (3 pontos na largura) e células com lanterna de fábrica perto."""
    av, bv = np.array(a, float), np.array(b, float)
    length = float(np.linalg.norm(bv - av))
    u = (bv - av) / length
    acr, nv = np.array(across, float), np.array(n, float)
    cells = max(1, int(round(length / EDGE_STEP)))
    step = length / cells
    prs = []
    for i in range(cells):
        c = av + u * (step * (i + 0.5))
        prs.append([_protrusion(tree, c + acr * (STRIP_W * k), n) for k in (-0.5, 0.0, 0.5)])
    lamp = np.zeros(cells, bool)
    if len(lamps):
        rel = lamps - av
        t = rel @ u
        near = (np.abs(rel @ acr) <= STRIP_W / 2 + LAMP_GAP) & (np.abs(rel @ nv) <= 0.10) & (t > -LAMP_GAP) & (t < length + LAMP_GAP)
        for tt in t[near]:
            for i in range(max(0, int((tt - LAMP_GAP) // step)), min(cells, int((tt + LAMP_GAP) // step) + 1)):
                lamp[i] = True
    return prs, lamp, step, length


def _runs(prs, lamp, step):
    """Plano da face (mediana das saliências do meio) e trechos livres [[t0, t1], ...] em metros."""
    mids = [p[1] for p in prs if p[1] is not None]
    if not mids:
        return [], 0.0
    plane = float(np.median(mids))
    free = [not lamp[i] and all(q is not None and plane - STRIP_LO <= q <= plane + STRIP_HI for q in p) for i, p in enumerate(prs)]
    runs, start = [], None
    for i, f in enumerate(free + [False]):
        if f and start is None:
            start = i
        elif not f and start is not None:
            if (i - start) * step >= STRIP_MIN:
                runs.append([round(start * step, 3), round(i * step, 3)])
            start = None
    return runs, plane


def _best_line(tree, lamps, line, params, n, across):
    """Entre as posições `params` (da borda para dentro), a primeira cuja cobertura livre é >= 90% da melhor.
    `line(p)` -> (a, b). Devolve (p, a, b, trechos, plano) ou None."""
    found = []
    for p in params:
        a, b = line(p)
        prs, lamp, step, length = _line_cells(tree, lamps, a, b, n, across)
        runs, plane = _runs(prs, lamp, step)
        found.append((sum(r[1] - r[0] for r in runs), p, a, b, runs, plane))
    best = max(f[0] for f in found) if found else 0.0
    if best < STRIP_MIN:
        return None
    for f in found:
        if f[0] >= best * 0.9:
            return f[1:]
    return None


def _strip(a, b, n, across, runs, plane):
    """Segmentos da faixa (Godot), já no plano da face (+3 mm para não brigar com ela)."""
    av, bv = np.array(a, float), np.array(b, float)
    u = (bv - av) / float(np.linalg.norm(bv - av))
    off = np.array(n, float) * (plane + 0.003)
    out = []
    for t0, t1 in runs:
        p0, p1 = av + u * t0 + off, av + u * t1 + off
        out.append({"a": [round(float(x), 3) for x in p0], "b": [round(float(x), 3) for x in p1],
                    "n": [float(x) for x in n], "w": [float(x) for x in across]})
    return out


def _span(vals, lo, hi, step=0.01):
    return [round(float(v), 3) for v in np.arange(lo, hi, step if hi > lo else -step)]


def _longest_free(col):
    """Maior sequência de False numa lista de bool: (tamanho, início, fim exclusivo)."""
    best, run, start = (0, 0, 0), 0, 0
    for j, o in enumerate(list(col) + [True]):
        if not o:
            if run == 0:
                start = j
            run += 1
        else:
            if run > best[0]:
                best = (run, start, j)
            run = 0
    return best


def box_edges(data: dict, m: dict) -> dict:
    """Medidas da traseira, do teto e das bordas do baú (T-231), em coordenadas do Godot:
    - rear: z de trás de tudo o que fica embaixo do baú (o para-choque traseiro novo encosta ali, atrás das lanternas e
      do para-choque de fábrica, que ele substitui) e o topo dele (abaixo das setas de trás);
    - strips: faixas do contorno de LED nas 4 bordas de cada lateral e do teto. Para cada borda procura, da quina para
      dentro, a primeira linha onde a lataria está no plano da face (nada saliente, nada vazado, nenhuma lanterna de
      fábrica a menos de 1,2 cm) em >= 90% do comprimento da melhor linha; a faixa só existe nos trechos livres;
    - rocket_r/l: faixa livre do teto por dentro do contorno de LED, até o andon de fábrica do teto.
    Raios na malha real (BVH), determinístico."""
    objs = data["objs"]
    bx = m["box"]
    bh, top, bot, bf, rz = bx["half_w"], bx["top_y"], bx["bottom_y"], bx["front_z"], bx["rear_z"]
    out = {}
    rb_top = round(min(bot - 0.02, RB_TOP_MAX), 3)
    allv = _cat(objs, [k for k in objs if not k.startswith("wheel_")])
    sel = allv[(np.abs(allv[:, 0]) <= bh + 0.1) & (allv[:, 1] >= 0.10) & (allv[:, 1] <= rb_top + 0.03) & (allv[:, 2] >= rz - 0.8)]
    back = float(sel[:, 2].max()) if len(sel) else rz
    out["rear"] = {"top_y": rb_top, "back_z": round(max(back, rz) + 0.01, 3), "half_w": round(min(bh, 1.30), 3)}
    if m.get("open_body"):
        return out
    tree = _bvh()
    lamps = _cat(objs, [k for k in objs if k.startswith("truck_lamp")])
    strips = {"box_light_r": [], "box_light_l": [], "box_light_top": []}
    # --- laterais: linha de cima, de baixo, da frente e de trás
    for side, sx in (("r", 1), ("l", -1)):
        n = (sx, 0, 0)
        x = sx * bh
        zf0, zr0 = bf + 0.05, rz - 0.05
        tl = _best_line(tree, lamps, lambda y: ((x, y, zf0), (x, y, zr0)), _span(None, top - 0.02, top - 0.32), n, (0, 1, 0))
        bl = _best_line(tree, lamps, lambda y: ((x, y, zf0), (x, y, zr0)), _span(None, bot + 0.02, bot + 0.32), n, (0, 1, 0))
        key = "box_light_" + side
        for f in (tl, bl):
            if f:
                strips[key] += _strip(f[1], f[2], n, (0, 1, 0), f[3], f[4])
        ya = bl[0] if bl else bot + 0.05
        yb = tl[0] if tl else top - 0.05
        for zs in (_span(None, bf + 0.02, bf + 0.30), _span(None, rz - 0.02, rz - 0.30)):
            f = _best_line(tree, lamps, lambda z: ((x, ya, z), (x, yb, z)), zs, n, (0, 0, 1))
            if f:
                strips[key] += _strip(f[1], f[2], n, (0, 0, 1), f[3], f[4])
    # --- teto: as 2 bordas compridas e as 2 pontas
    n = (0, 1, 0)
    sides = {}
    for sx in (1, -1):
        f = _best_line(tree, lamps, lambda xx: ((sx * xx, top, bf + 0.05), (sx * xx, top, rz - 0.05)),
                       _span(None, bh - 0.015, bh - 0.30), n, (1, 0, 0))
        if f:
            sides[sx] = f
            strips["box_light_top"] += _strip(f[1], f[2], n, (1, 0, 0), f[3], f[4])
    xe = min(sides[1][0] if 1 in sides else bh - 0.05, sides[-1][0] if -1 in sides else bh - 0.05)
    cross = [bf + 0.02, rz - 0.02]                   # z das pontas do contorno do teto (o foguete fica entre elas)
    for k, zs in enumerate((_span(None, bf + 0.015, bf + 0.30), _span(None, rz - 0.015, rz - 0.30))):
        f = _best_line(tree, lamps, lambda z: ((-xe, top, z), (xe, top, z)), zs, n, (0, 0, 1))
        if f:
            cross[k] = f[0]
            strips["box_light_top"] += _strip(f[1], f[2], n, (0, 0, 1), f[3], f[4])
    out["strips"] = strips
    # --- foguete: por dentro do contorno do teto; plano do teto = mediana das saliências na faixa
    roof_plane = float(np.median([s[4] for s in sides.values()])) if sides else 0.0
    zs = np.arange(cross[0] + STRIP_W / 2 + ROCKET_GAP + EDGE_STEP / 2, cross[1] - STRIP_W / 2 - ROCKET_GAP - EDGE_STEP / 2 + 1e-6,
                   EDGE_STEP)
    for side, sx in (("r", 1), ("l", -1)):
        edge = sides[sx][0] if sx in sides else bh - 0.05
        outer = edge - STRIP_W / 2 - ROCKET_GAP
        xs = np.round(np.arange(outer, outer - 0.34, -0.01), 3)
        occ = np.zeros((len(xs), len(zs)), bool)
        for i, xx in enumerate(xs):
            for j, z in enumerate(zs):
                pr = _protrusion(tree, (sx * float(xx), top, float(z)), (0, 1, 0))
                occ[i, j] = pr is None or pr > roof_plane + 0.006 or pr < roof_plane - 0.03
        cands = []
        for i in range(int(round(ROCKET_MIN_W / 0.01)), len(xs)):
            run, j0, j1 = _longest_free(occ[: i + 1].any(0))
            cands.append((run * EDGE_STEP, i, j0, j1))
        if not cands:
            continue
        longest = max(c[0] for c in cands)
        if longest < 2.0:
            continue
        ln, i, j0, j1 = max((c for c in cands if c[0] >= longest * ROCKET_RUN), key=lambda c: c[1])
        out["rocket_" + side] = {"inner": round(float(xs[i]), 3), "outer": round(float(outer), 3),
                                 "z0": round(float(zs[j0]) - EDGE_STEP / 2 + 0.005, 3),
                                 "z1": round(float(zs[j1 - 1]) + EDGE_STEP / 2 - 0.005, 3),
                                 "top": round(top + roof_plane, 3)}
    return out


# ----------------------------------------------------------------------------- frente, retrovisor, escada e saias (T-233)

FB_FLOOR = 0.16                   # m: altura mínima do para-choque da frente (vão livre)
FB_DEPTH = 0.62                   # m: quanto o para-choque novo pode avançar além do nariz de fábrica
FB_SIDE = 0.15                    # m: quanto ele pode passar da largura da cabine de cada lado
MIRROR_REACH = 0.50               # m: quanto a haste do retrovisor pode sair da lateral da cabine (decisão T-233)
MIRROR_AHEAD = 0.60               # m: quanto ela pode avançar além da frente da cabine
SKIRT_DEPTH = 0.10                # m: espessura máxima reservada à saia
SKIRT_OUT = 0.03                  # m: quanto a saia pode passar da lateral do baú
SKIRT_H = 0.46                    # m: altura máxima da saia (embaixo do baú)
SKIRT_MIN = 0.60                  # m: trecho livre mais curto que isto não leva saia


WRAP_MAX = 0.80                   # m: (T-264) a aba lateral do para-choque grande vai no máximo isto para trás do nariz
WRAP_MIN = 0.22                   # m: mais curta que isto, sem aba (o encaixe não ganha a caixa da aba)
WRAP_WHEEL = 0.02                 # m: folga da aba até a zona protegida da roda (que já tem 3 cm)
WRAP_DOOR = 0.02                  # m: folga até a frente da porta (quando o para-choque passa da altura da porta)
WRAP_BUMP = 0.05                  # m: lataria que sai mais que isto da da frente = obstáculo (paralama, degrau): a aba para
WRAP_STEP = 0.02                  # m: passo das colunas de raios
WRAP_REF = 0.15                   # m: a quina arredondada da cabine fica nos primeiros WRAP_REF atrás do nariz
WRAP_PROF = 0.30                  # m: perfil da quina guardado até aqui (o jogo fecha o vão entre a quina e a aba)


def _wrap(tree, m: dict, nose: float, top: float, hw: float, sx: int) -> dict:
    """T-264 (capturas 054–062): o para-choque grande dobra a quina e corre pela lateral da cabine até a roda da frente.
    Raios de FORA para dentro em colunas (z) de FB_FLOOR até `top`, do nariz para trás: a lataria mais de fora na faixa
    da aba (`x`, lado de dentro da aba) e onde ela tem de parar (`z1`): antes da zona da roda, antes da porta se o
    para-choque passa da altura da porta (zona `door_*` começa em 0,62 m) e antes de um obstáculo (paralama/degrau
    que sai mais que WRAP_BUMP). Coordenadas do Godot. `len` = 0 quando não cabe aba."""
    from mathutils import Vector
    c = m["cab"]
    fw = [b for n, b in m["wheels"].items() if n.startswith("wheel_f") and (b[1][0] > 0) == (sx > 0)]
    z1 = nose + WRAP_MAX
    if fw:
        z1 = min(z1, min(b[0][2] for b in fw) - 0.03 - WRAP_WHEEL)
    d = c["door"]
    if top > d["y"][0] - 0.01:
        z1 = min(z1, d["z"][0] - WRAP_DOOR)
    cols = []
    z = nose + 0.01
    while z <= z1 + 1e-6:
        mx = -9.0
        for yy in np.arange(FB_FLOOR, top + 1e-6, 0.03):
            hit = tree.ray_cast(Vector((sx * 3.0, -z, float(yy))), Vector((-sx, 0, 0)), 3.0)
            if hit[0] is not None:
                mx = max(mx, hit[0].x * sx)
        cols.append((round(z, 3), mx))
        z += WRAP_STEP
    # lateral de referência = mediana depois da quina arredondada; obstáculo = coluna que sai mais que isso + WRAP_BUMP
    side_cols = [q[1] for q in cols if q[0] >= nose + WRAP_REF and q[1] > 0.0]
    ref = float(np.median(side_cols)) if side_cols else max([q[1] for q in cols] + [hw])
    end = z1
    for zc, mx in cols:
        if zc >= nose + WRAP_REF and mx > ref + WRAP_BUMP:
            end = min(end, zc - WRAP_STEP)
            break
    xs = [q[1] for q in cols if q[0] <= end and q[1] > 0.0]
    x = max(xs) if xs else hw
    ln = round(end - nose, 3)
    # perfil da quina (dz atrás do nariz, x da lataria) até encostar na lateral: o jogo fecha o vão em cima e embaixo
    prof = []
    for zc, mx in cols:
        if zc - nose > WRAP_PROF:
            break
        prof.append([round(zc - nose, 3), round(max(mx, 0.0), 3)])
        if mx >= x - 0.01:
            break
    return {"x": round(x, 3), "len": ln if ln >= WRAP_MIN else 0.0, "z1": round(end, 3), "ref": round(ref, 3),
            "prof": prof}


def front_side(data: dict, m: dict) -> dict:
    """Medidas da frente e das laterais (T-233), em coordenadas do Godot, por raios na malha real (BVH) e vértices:
    - nose: z do ponto mais à frente da lataria embaixo da linha dos faróis (o para-choque novo encosta ali, na frente
      do de fábrica, que ele cobre) e o topo permitido (3 cm abaixo do farol/lanterna mais baixo);
    - mirror_r/l: espelho de fábrica (caixa dos vértices fora da lateral da cabine, na altura do para-brisa: o jogo
      esconde esses triângulos quando a haste nova está montada), a lateral da cabine na coluna do para-brisa e o
      ponto de montagem da haste;
    - skirt_r/l: faixa da saia embaixo do baú (da lateral do baú para dentro) e os trechos livres entre as rodas
      (tanque, bateria e degraus de fábrica ficam fora: a saia para antes deles)."""
    from mathutils import Vector
    objs = data["objs"]
    c = m["cab"]
    tree = _bvh()
    out = {}
    hw = c["half_w"]
    lamps = [b[0][1] for k in ("headlights", "front_lamps") for b in m[k].values()]
    top = round(min(lamps or [0.88]) - 0.03, 3)
    # --- nariz: raios de frente numa grade x × y
    zf = c["front_z"] - 3.0
    nose = 99.0
    x = -(hw + FB_SIDE)
    while x <= hw + FB_SIDE + 1e-6:
        y = FB_FLOOR
        while y <= top + 1e-6:
            hit = tree.ray_cast(Vector((x, -zf, y)), Vector((0, -1, 0)))
            if hit[0] is not None:
                nose = min(nose, -hit[0].y)
            y += 0.02
        x += 0.02
    out["nose"] = {"z": round(nose, 3), "top_y": top, "floor_y": FB_FLOOR, "half_w": round(hw + FB_SIDE, 3)}
    # --- T-264: aba lateral do para-choque grande (vai do nariz até a roda da frente, colada na lateral da cabine)
    for side, sx in (("r", 1), ("l", -1)):
        out["wrap_" + side] = _wrap(tree, m, nose, top, hw, sx)
    # --- retrovisor
    w0, w1 = c["windshield"]
    d0 = c["door"]["z"][0]
    allv = _cat(objs, [k for k in objs if not k.startswith("wheel_")])
    y_lo, y_hi = w0[1] - 0.25, w1[1] + 0.20
    zmin = round(min(c["front_z"], w0[2]) - MIRROR_AHEAD, 3)
    for side, sx in (("r", 1), ("l", -1)):
        sel = allv[(allv[:, 0] * sx > hw + 0.025) & (allv[:, 1] >= w0[1] - 0.45) & (allv[:, 1] <= c["roof_shell_y"] + 0.1)
                   & (allv[:, 2] >= c["front_z"] - 0.3) & (allv[:, 2] <= d0 + 0.8)]
        stock = None
        if len(sel):
            stock = [[round(float(v) - 0.01, 3) for v in sel.min(0)], [round(float(v) + 0.01, 3) for v in sel.max(0)]]
        # lateral da cabine junto à coluna (sem o espelho de fábrica)
        near = allv[(allv[:, 0] * sx > 0.5) & (allv[:, 1] >= y_lo) & (allv[:, 1] <= y_hi) & (allv[:, 2] >= zmin) & (allv[:, 2] <= d0)]
        if stock is not None and len(near):
            inside = np.all((near >= np.array(stock[0])) & (near <= np.array(stock[1])), axis=1)
            near = near[~inside]
        x_side = float((near[:, 0] * sx).max()) if len(near) else hw
        out["mirror_" + side] = {"stock": stock, "x_side": round(x_side, 3), "y": [round(y_lo, 3), round(y_hi, 3)],
                                 "z": [zmin, round(d0 - 0.02, 3)],
                                 "anchor": [round(sx * x_side, 3), round(w0[1], 3), round(w0[2], 3)],
                                 "window_h": round(w1[1] - w0[1], 3)}
    # T-263: o espelho de fábrica some INTEIRO (braços até a raiz): uma caixa por pedaço solto da malha que sai da
    # lateral da cabine nessa região (antes uma caixa só dos vértices de fora: a raiz dos braços ficava). A lateral de
    # referência é a coluna medida (1ª passada, sem o espelho pela caixa antiga): na americana a cabine é mais estreita
    # que o capô. Depois a coluna é medida de novo sem os pedaços do espelho.
    old_boxes = [out["mirror_" + s]["stock"] for s in ("r", "l") if out["mirror_" + s]["stock"]]
    trees = _pillar_trees(old_boxes)
    for side, sx in (("r", 1), ("l", -1)):
        st = out["mirror_" + side]["stock"]
        pts = [abs(q[0]) for q in pillar(trees, c, sx)["pts"] if q]
        xr = min(pts) if pts and hw - min(pts) > 0.10 else hw     # (só quando a cabine é bem mais estreita que o capô)
        out["mirror_" + side]["stock_parts"] = _stock_islands(st, sx, xr, w0[1] - 0.30) if st else []
    # T-263: coluna do para-brisa medida por raios (a base da haste encosta na lataria, sem vão)
    stock_boxes = [d["b"] for s in ("r", "l") for d in out["mirror_" + s]["stock_parts"]] or old_boxes
    trees = _pillar_trees(stock_boxes)
    for side, sx in (("r", 1), ("l", -1)):
        out["mirror_" + side]["pillar"] = pillar(trees, c, sx)
    # --- saias: faixa embaixo do baú, trechos livres entre a roda da frente e a primeira de trás (raios de fora)
    bx = m.get("box")
    if bx:
        y_hi = round(bx["bottom_y"] - 0.02, 3)
        y_lo = round(max(0.26, y_hi - SKIRT_H), 3)
        fw = [b for n, b in m["wheels"].items() if n.startswith("wheel_f")]
        rw = [b for n, b in m["wheels"].items() if n.startswith("wheel_r")]
        za = max(b[1][2] for b in fw) + 0.08
        zb = min(b[0][2] for b in rw) - 0.08
        for side, sx in (("r", 1), ("l", -1)):
            # linha de fora do chassi em cada célula (raio de fora): o que é fino e corre o vão inteiro (trilho de
            # fábrica, longarina) fica atrás da saia; o que sai mais que a mediana (tanque, bateria, degrau) a saia
            # contorna (o trecho para antes dele)
            cells = []
            z = za
            while z < zb - 1e-6:
                mx = -9.0
                for yy in np.arange(y_lo, y_hi + 1e-6, 0.04):
                    for dz in (0.005, 0.025, 0.045):
                        hit = tree.ray_cast(Vector((sx * 3.0, -(z + dz), float(yy))), Vector((-sx, 0, 0)), 3.0)
                        if hit[0] is not None:
                            mx = max(mx, hit[0].x * sx)
                cells.append((round(z, 3), mx))
                z += 0.05
            line = float(np.median([c[1] for c in cells])) if cells else 0.0
            x_out = round(bx["half_w"] + SKIRT_OUT, 3)
            x_in = round(max(line + 0.008, x_out - SKIRT_DEPTH), 3)
            x_out = max(x_out, round(x_in + 0.04, 3))
            runs, start = [], None
            for zc, mx in cells + [(round(z, 3), 99.0)]:
                b = mx > x_in - 0.002
                if not b and start is None:
                    start = zc
                elif b and start is not None:
                    if zc - start >= SKIRT_MIN:
                        runs.append([round(start + 0.01, 3), round(zc - 0.01, 3)])
                    start = None
            out["skirt_" + side] = {"x_in": x_in, "x_out": x_out, "y": [y_lo, y_hi], "runs": runs,
                                    "span": [round(za, 3), round(zb, 3)], "line": round(line, 3)}
    return out


# ----------------------------------------------------------------------------- coluna do retrovisor (T-263)

PILLAR_DY = 0.02                  # m: passo vertical da coluna medida
PILLAR_DZ = 0.01                  # m: passo das tentativas ao longo do comprimento
PAD_HALF = (0.02, 0.035)          # m: meia largura (z) e meia altura (y) da chapa de fixação da haste
PAD_FLAT = 0.02                   # m: a lataria embaixo da chapa pode variar no máximo isto (senão é quina)
PAD_DOOR = 0.015                  # m: a chapa fica pelo menos isto na frente da porta / do vidro lateral
# Onde a chapa pode encostar: lataria pintada, plástico, aço e cromo da cabine. Vidro, lanternas, faróis etc. não.
PAD_OK = ("truck_paint", "truck_plastic", "truck_steel", "truck_chrome")


def _pillar_trees(stock_boxes):
    """BVHs (Blender) separadas: lataria onde a chapa pode encostar, vidro lateral (`truck_glass`) e o resto. Os
    triângulos do espelho de fábrica (3 vértices dentro de uma caixa, como o jogo esconde) ficam de fora."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    bms = {"ok": bmesh.new(), "side_glass": bmesh.new(), "other": bmesh.new()}
    for o in sorted(bpy.data.objects, key=lambda o: o.name):
        if o.type != "MESH" or o.name.startswith("wheel_"):
            continue
        base = o.name.split(".")[0]
        kind = "side_glass" if base == "truck_glass" else ("ok" if base.startswith(PAD_OK) else "other")
        me = o.to_mesh()
        me.transform(o.matrix_world)
        tmp = bmesh.new()
        tmp.from_mesh(me)
        o.to_mesh_clear()
        if stock_boxes:
            dead = []
            for f in tmp.faces:
                for (x0, y0, z0), (x1, y1, z1) in stock_boxes:
                    if all(x0 <= v.co.x <= x1 and y0 <= v.co.z <= y1 and z0 <= -v.co.y <= z1 for v in f.verts):
                        dead.append(f)
                        break
            if dead:
                bmesh.ops.delete(tmp, geom=dead, context="FACES")
        me2 = bpy.data.meshes.new("_pillar_tmp")
        tmp.to_mesh(me2)
        tmp.free()
        bms[kind].from_mesh(me2)
        bpy.data.meshes.remove(me2)
    out = {}
    for k, bm in bms.items():
        out[k] = BVHTree.FromBMesh(bm)
        bm.free()
    return out


def _side_hit(trees, sx, y, z):
    """Raio de fora para dentro na altura y (Godot), posição z: (x para fora, tipo, normal Godot) do 1º ponto."""
    from mathutils import Vector
    best = None
    for k, t in trees.items():
        h = t.ray_cast(Vector((sx * 3.0, -z, y)), Vector((-sx, 0, 0)), 3.0)
        if h[0] is not None and (best is None or h[0].x * sx > best[0]):
            n = h[1]
            best = (float(h[0].x * sx), k, (float(n.x), float(n.z), float(-n.y)))
    return best


def pillar(trees, c: dict, sx: int) -> dict:
    """T-263: onde a base da haste do retrovisor encosta, para cada altura y (passo PILLAR_DY) da borda de baixo do
    para-brisa − 0,30 até a de cima + 0,15: a posição z na lataria da coluna logo na frente da porta / do vidro lateral
    (nunca no vidro, na porta, em lanterna ou na quina da frente), com a chapa inteira apoiada (variação ≤ PAD_FLAT).
    `pts[i]` = [x da lataria embaixo da chapa (o ponto mais saliente), z, nx, nz] (Godot, com o sinal do lado) ou None."""
    w0, w1 = c["windshield"]
    d0 = c["door"]["z"][0]
    y0 = round(w0[1] - 0.30, 3)
    ny = int(round((w1[1] + 0.15 - y0) / PILLAR_DY)) + 1
    ys = [round(y0 + PILLAR_DY * i, 3) for i in range(ny)]
    z0 = c["front_z"]
    nz = int((d0 - z0) / PILLAR_DZ) + 1
    zs = [round(z0 + PILLAR_DZ * j, 3) for j in range(nz)]
    grid = [[_side_hit(trees, sx, y, z) for z in zs] for y in ys]
    dyi, dzi = int(round(PAD_HALF[1] / PILLAR_DY)), int(round(PAD_HALF[0] / PILLAR_DZ))
    pts = []
    for i, y in enumerate(ys):
        sg = [zs[j] for j in range(nz) if grid[i][j] and grid[i][j][1] == "side_glass" and grid[i][j][0] >= 0.6]
        z_pref = min([d0] + sg) - PAD_DOOR - PAD_HALF[0]
        best = None
        for j, z in enumerate(zs):
            if z > z_pref + 1e-6:
                break
            cells = [grid[a][b] for a in range(i - dyi, i + dyi + 1) for b in range(j - dzi, j + dzi + 1)
                     if 0 <= a < ny and 0 <= b < nz]
            if len(cells) < (2 * dyi + 1) * (2 * dzi + 1) or any(cc is None or cc[1] != "ok" for cc in cells):
                continue
            xs = [cc[0] for cc in cells]
            if min(xs) < 0.6 or max(xs) - min(xs) > PAD_FLAT:
                continue
            nxs = sum(cc[2][0] for cc in cells) * sx
            nzs = sum(cc[2][2] for cc in cells)
            ln = max(1e-6, (nxs * nxs + nzs * nzs) ** 0.5)
            if nxs / ln < 0.8:                          # (quina: a lataria vira para a frente)
                continue
            best = [round(sx * max(xs), 3), z, round(sx * nxs / ln, 3), round(nzs / ln, 3)]   # o mais perto da porta
        if best:
            # a chapa encosta no ponto mais saliente EMBAIXO dela (mesmos 7 pontos do teste do jogo, FrameContact)
            fx = [_side_hit(trees, sx, y + dy, best[1] + dz) for dz, dy in
                  ((0, 0), (-0.016, -0.03), (0.016, -0.03), (-0.016, 0.03), (0.016, 0.03), (0, -0.03), (0, 0.03))]
            if all(f is not None for f in fx):
                best[0] = round(sx * max(f[0] for f in fx), 3)
        pts.append(best)
    return {"y0": y0, "dy": PILLAR_DY, "pts": pts}


# ----------------------------------------------------------------------------- escada na frente do baú (T-263)

LADDER_DEPTH = 0.075              # m: quanto a escada sai da frente do baú (= accessories/ladder_t233.DEPTH)
LADDER_HALF = 0.17                # m: meia largura reservada (a escada cromada tem 0,155)
LADDER_IN = 0.60                  # m: centro da escada a esta distância da quina do baú (capturas 111–113)
LADDER_MIN = 0.80                 # m: trecho livre mais curto que isto (até o topo) não leva escada
LADDER_DY = 0.05


def ladder_front(m: dict, x_max: float, sx: int = 1) -> dict | None:
    """T-263: onde a escada encosta na FRENTE do baú (atrás da cabine), por raios na malha real. Para cada centro x
    candidato (de LADDER_IN da quina para dentro/fora, sem passar de `x_max` = antes dos escapamentos), mede em 5 colunas
    (de -0,15 a +0,15) e a cada 5 cm de altura: a chapa da frente (raio de dentro do baú para a frente; plana, ±1 cm) e o
    vão livre na frente dela até a cabine/o que houver (precisa de LADDER_DEPTH + 1 cm). A escada ocupa o trecho livre mais baixo que
    chega perto do topo (um friso na borda de cima do baú encurta a escada). `sx` = lado (1 direita, -1 esquerda). Devolve {"x" (sem sinal),
    "face_z", "y0", "top"} ou None."""
    from mathutils import Vector
    bx = m["box"]
    tree = _bvh()
    bf, bot, top, bh = bx["front_z"], bx["bottom_y"], bx["top_y"], bx["half_w"]
    ys = [round(bot + 0.03 + LADDER_DY * i, 3) for i in range(int((top - 0.03 - bot - 0.03) / LADDER_DY) + 1)]
    pref = bh - LADDER_IN
    cands = sorted({round(min(x_max, pref + d), 3) for d in (0.0, -0.05, 0.05, -0.10, 0.10, -0.15, -0.20, -0.25, -0.30)},
                   key=lambda c: abs(c - pref))
    best = None
    for cx in cands:
        if cx - LADDER_HALF < 0.15:
            continue
        rows = []
        for y in ys:
            faces, gaps = [], []
            for x in (cx - 0.15, cx - 0.075, cx, cx + 0.075, cx + 0.15):
                h = tree.ray_cast(Vector((sx * x, -(bf + 0.06), y)), Vector((0, 1, 0)), 0.3)
                if h[0] is None:
                    break
                fz = -h[0].y
                g = tree.ray_cast(Vector((sx * x, -(fz - 0.003), y)), Vector((0, 1, 0)), 3.0)
                faces.append(fz)
                gaps.append(g[3] + 0.003 if g[0] is not None else 9.9)
            ok = len(faces) == 5 and max(faces) - min(faces) <= 0.01 and min(gaps) >= LADDER_DEPTH + 0.01
            rows.append((y, ok, min(faces) if faces else None))
        # trechos livres; o que serve termina perto do topo (pode haver um friso na borda de cima do baú)
        runs, start = [], None
        for i, r in enumerate(rows + [(None, False, None)]):
            if r[1] and start is None:
                start = i
            elif not r[1] and start is not None:
                runs.append((start, i - 1))
                start = None
        runs = [(a, b) for a, b in runs if rows[b][0] >= top - 0.25 and rows[b][0] - rows[a][0] >= LADDER_MIN - 0.06]
        if not runs:
            continue
        a, b = min(runs, key=lambda r: r[0])
        free = rows[a:b + 1]
        y0 = bot if a == 0 else round(free[0][0] - 0.02, 3)
        ty = round(min(top - 0.01, free[-1][0] + 0.02), 3)
        face = round(min(r[2] for r in free), 3)
        score = (y0 - bot) * 10.0 + abs(cx - pref)
        if best is None or score < best[0] - 1e-9:
            best = (score, {"x": cx, "face_z": face, "y0": y0, "top": ty})
    return best[1] if best else None


def _stock_islands(stock, sx: int, hw: float, y_min: float) -> list:
    """T-263: pedaços soltos (ilhas da malha, vértices iguais juntados) que ficam pelo menos 20% dentro da caixa `stock` do
    espelho de fábrica e com 10% dos vértices por fora da lateral da cabine: braços, cabeças e suportes. Uma caixa (Godot, +4 mm) por pedaço,
    com o material (`m`): o jogo esconde os triângulos DESSE material com os 3 vértices dentro (FrameFit.hide_stock). Pedaço maior que 1,6 m = lataria, fica."""
    import bmesh
    (x0, y0, z0), (x1, y1, z1) = stock
    out, near = [], []
    for o in sorted(bpy.data.objects, key=lambda o: o.name):
        if o.type != "MESH" or o.name.startswith("wheel_"):
            continue
        base = o.name.split(".")[0]
        bm = bmesh.new()
        me = o.to_mesh()
        me.transform(o.matrix_world)
        bm.from_mesh(me)
        o.to_mesh_clear()
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        bm.faces.ensure_lookup_table()
        seen = set()
        for f in bm.faces:
            if f.index in seen:
                continue
            isl, stack = [], [f]
            seen.add(f.index)
            while stack:
                g = stack.pop()
                isl.append(g)
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in seen:
                            seen.add(h.index)
                            stack.append(h)
            if base.startswith(("truck_lamp", "truck_glass", "truck_mural", "truck_andon")):
                continue                                     # (lanterna, vidro, painel: nunca são o espelho)
            vs = np.array([(v.co.x, v.co.z, -v.co.y) for g in isl for v in g.verts])
            mn, mx = vs.min(0), vs.max(0)
            outside = vs[:, 0] * sx > hw + 0.025
            box = {"b": [[round(float(v) - 0.004, 3) for v in mn], [round(float(v) + 0.004, 3) for v in mx]], "m": base}
            if (mx - mn).max() > 0.6:
                if base.startswith(("truck_paint", "truck_glass")):
                    continue
                # pedaço grande (ex.: os braços da americana fazem parte da faixa preta do capô): só a parte por fora da
                # cabine perto do espelho, e só deste material
                sel = vs[outside & (vs[:, 1] >= y0 - 0.15) & (vs[:, 1] <= y1 + 0.15) & (vs[:, 2] >= z0 - 0.15) & (vs[:, 2] <= z1 + 0.15)]
                if len(sel) >= 3:
                    lo2, hi2 = sel.min(0), sel.max(0)
                    xa = (hw + 0.005) if sx > 0 else float(lo2[0]) - 0.004
                    xb = float(hi2[0]) + 0.004 if sx > 0 else -(hw + 0.005)
                    out.append({"b": [[round(xa, 3), round(float(lo2[1]) - 0.004, 3), round(float(lo2[2]) - 0.004, 3)],
                                      [round(xb, 3), round(float(hi2[1]) + 0.004, 3), round(float(hi2[2]) + 0.004, 3)]], "m": base})
                continue
            # pelo menos 20% da caixa do pedaço dentro da caixa do espelho (puxadores e lanternas vizinhos ficam)
            lo = np.maximum(mn, (x0, y0, z0))
            hi = np.minimum(mx, (x1, y1, z1))
            dim = np.maximum(mx - mn, 0.01)
            frac = float(np.prod(np.clip(hi - lo, 0.0, None) / dim))
            if outside.mean() >= 0.10 and frac >= 0.2:
                out.append(box)
            elif (mx - mn).max() < 0.3 and (vs[:, 0] * sx > hw - 0.06).mean() > 0.3:
                near.append(box)                             # (base do braço colada na lataria: entra se encostar)
        bm.free()
    for _ in range(3):                                       # pedaços pequenos encostados num pedaço do espelho
        add = [b for b in near if any(all(b["b"][0][i] <= c["b"][1][i] + 0.01 and c["b"][0][i] <= b["b"][1][i] + 0.01
                                          for i in range(3)) for c in out)]
        near = [b for b in near if b not in add]
        out += add
        if not add:
            break
    out = [d for d in out if (d["b"][0][1] + d["b"][1][1]) / 2 >= y_min]   # (acabamento da porta embaixo fica)
    out.sort(key=lambda d: (d["m"], d["b"]))
    merged = []
    for d in out:                                            # caixas iguais/contidas (mesmo material) viram uma
        if any(c["m"] == d["m"] and all(c["b"][0][i] <= d["b"][0][i] and d["b"][1][i] <= c["b"][1][i] for i in range(3)) for c in merged):
            continue
        merged.append(d)
    return merged


# ----------------------------------------------------------------------------- escada na lateral da cabine (T-263, correção do Marco)

LADDER_W = 0.34                   # m: largura reservada (a escada cromada tem 0,31); encolhe até LADDER_WMIN onde não cabe
LADDER_WMIN = 0.22
LADDER_DOOR = 0.03                # m: folga entre a escada e a porta (ou o fim do vidro da porta)
LADDER_ROOF = 0.10                # m: os trilhos passam um pouco do teto da cabine; a caixa de LED fica em cima (capturas 111–113)
LADDER_FLAT = 0.25                # m: vão máximo entre a escada (inclinada com a lateral) e a lataria (espaçadores cobrem)


def ladder_side(m: dict, trees, sx: int, z_lim: float) -> dict | None:
    """T-263 (Marco: "as escadas são do lado da cabine, tipo do lado da porta"): escada em pé na LATERAL da cabine, logo
    atrás da porta (e do vidro da porta), virada para fora, do alto da roda da frente até um pouco acima do teto. Raios
    de fora para dentro numa grade z × y: a escada fica no primeiro lugar atrás da porta onde a lataria embaixo dela é
    chapa (sem vidro, sem lanterna) e quase plana; `z_lim` = onde ela tem que acabar (escapamentos, baú). Devolve
    {"x" (sem sinal, a lataria mais saliente embaixo dela), "z" (centro), "w" (largura útil), "y0", "top"} ou None."""
    c = m["cab"]
    d0, d1 = c["door"]["z"]
    roof = c["roof_shell_y"]
    y_bot = 0.62
    for n, b in m["wheels"].items():                                   # acima da zona da roda da frente
        if n.startswith("wheel_f") and b[0][2] - 0.03 < z_lim and b[1][2] + 0.03 > d1:
            y_bot = max(y_bot, b[1][1] + 0.12)       # (acima do paralama também)
    y_cap = min(roof - 0.40, 2.95)
    if y_cap - y_bot < 0.8:
        return None
    ys = [round(y_bot + 0.05 * i, 3) for i in range(int((y_cap - y_bot) / 0.05) + 1)]
    zs = [round(d1 - 0.1 + 0.02 * j, 3) for j in range(int((z_lim - (d1 - 0.1)) / 0.02) + 1)]
    col = {z: [_side_hit(trees, sx, y, z) for y in ys] for z in zs}
    glass = {z: any(h and h[1] == "side_glass" for h in col[z]) for z in zs}
    door_end = d1
    for z in zs:                                                       # o vidro da porta pode passar da porta medida
        if z >= d1 and not glass[z]:
            break
        if glass[z]:
            door_end = max(door_end, z)
    for w in (LADDER_W, 0.30, 0.26, LADDER_WMIN):
        z = door_end + LADDER_DOOR + w / 2
        while z + w / 2 <= z_lim + 1e-6:
            cols = [min(zs, key=lambda q: abs(q - zz)) for zz in (z - w / 2 + 0.02, z, z + w / 2 - 0.02)]
            rows = [[col[q][i] for q in cols] for i in range(len(ys))]
            flat = [h for r in rows for h in r]
            hit = [h for h in flat if h]
            if all(h[1] == "ok" for h in hit) and len(hit) >= 0.85 * len(flat) and all(any(r) for r in rows):
                # a lateral recolhe para cima (a cabine afina): a escada inclina junto (reta pelos pontos mais salientes)
                xr = np.array([max(h[0] for h in r if h) for r in rows])
                xc = np.array([r[1][0] if r[1] else max(h[0] for h in r if h) for r in rows])   # coluna do meio (espaçador)
                yv = np.array(ys)
                k, a0 = np.polyfit(yv, xr, 1)
                k = float(np.clip(k, -0.15, 0.05))
                off = float((xr - (a0 + k * yv)).max())
                line = a0 + k * yv + off
                if float((line - xr).max()) <= LADDER_FLAT:
                    x0 = float(a0 + k * y_bot + off)
                    # vão de cada altura (a escada leva espaçadores até a lataria: FrameFit, fit "ladder")
                    return {"x": round(x0, 3), "lean": round(k, 4), "z": round(z, 3), "w": w, "y0": round(y_bot, 3),
                            "top": round(roof + LADDER_ROOF, 3), "dy": 0.05,
                            "gaps": [round(float(g), 3) for g in (line - xc)]}
            z += 0.02
    return None


# ----------------------------------------------------------------------------- escada na quina da frente da carga (T-267)

# Decisão do Marco (T-263, opção b): na americana e no Canter a porta vai até o fim da cabine e não sobra chapa atrás
# dela; nesses dois a escada vai na LATERAL DA CARGA (baú/carroceria), logo atrás da quina da frente.
CARGO_LADDER_CABS = ("americana", "canter")
CARGO_BAD = ("truck_lamp", "truck_glass", "truck_andon", "truck_led", "truck_neon")   # luz de marcação, vidro: nunca
CARGO_REACH = 0.70                # m: a borda de trás da escada fica no máximo isto atrás da frente da carga (quina)
CARGO_MIN = 0.80                  # m: lateral livre mais baixa que isto não leva escada
CARGO_DEEP = 0.30                 # m: raio que bate mais fundo que isto (dentro da lateral) não conta como lataria
CARGO_WMIN = 0.20                 # m: na carga a escada encolhe até aqui (graneleira: entre as lanternas da tampa)
CARGO_LAMP_GAP = 0.015            # m: folga mínima entre a borda da escada e uma luz de marcação ao lado
CARGO_GAP_DY = 0.01               # m: passo do vão medido atrás da escada da carga (espaçadores)
CARGO_LIFT = 0.40                 # m: a escada pode começar até isto acima do fundo da carga (acima da fileira de luzes)
STRIP_T = 0.03                    # = socket_rules.STRIP_T (contorno de LED do baú, T-231)
STRIP_W = 0.025                   # = socket_rules.STRIP_W
LEDBOX_H = 0.16                   # = accessories/ladder_t233.LEDBOX_H


def _cargo_trees():
    """T-267: BVHs (Blender) separadas: tudo o que é lataria/estrutura da carga ("ok") e lâmpadas/vidro ("bad")."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    bms = {"ok": bmesh.new(), "bad": bmesh.new()}
    for o in sorted(bpy.data.objects, key=lambda o: o.name):
        if o.type != "MESH" or o.name.startswith("wheel_"):
            continue
        base = o.name.split(".")[0]
        me = o.to_mesh()
        me.transform(o.matrix_world)
        bms["bad" if base.startswith(CARGO_BAD) else "ok"].from_mesh(me)
        o.to_mesh_clear()
    out = {}
    for k, bm in bms.items():
        out[k] = BVHTree.FromBMesh(bm)
        bm.free()
    return out


def ladder_cargo(m: dict, trees, sx: int, strips: list, edge_min: float, dbg: list | None = None) -> dict | None:
    """T-267: escada em pé na LATERAL DA CARGA logo atrás da quina da frente (americana e Canter), virada para fora, do
    fundo da carga até 10 cm acima da borda de cima (caixa de LED por cima), medida por raios de fora para dentro numa
    grade z × y. A escada fica no primeiro lugar a partir da quina onde: as 3 colunas (bordas e meio) batem na lateral da
    carga do fundo até pelo menos CARGO_MIN; nenhuma coluna (a cada 2 cm, com CARGO_LAMP_GAP de folga dos lados) bate em lâmpada ou
    vidro (luz de marcação) em toda a altura da escada + caixa de LED; nada sai mais que a lateral acima da borda
    (onde a escada fica livre; um poste mais para dentro fica atrás dela); a lateral é quase plana (espaçadores cobrem até LADDER_FLAT). A escada fica por FORA do contorno
    de LED do baú (`strips` = trechos box_light_* deste lado, T-231) e o espaçador nunca cruza uma faixa dele (`sp_free`).
    `edge_min` = onde a borda da frente da escada pode começar (atrás dos escapamentos). Devolve as mesmas chaves de
    `ladder_side` (`lean` 0: a lateral da carga é vertical) + "on": "cargo" e "sp_free", ou None (não cabe)."""
    bx = m["box"]
    fz, bot, top, hw = bx["front_z"], bx["bottom_y"], bx["top_y"], bx["half_w"]
    side = [g for g in strips if abs(g["n"][0]) > 0.5]
    horiz = [g for g in side if abs(g["a"][1] - g["b"][1]) < 1e-3]
    vert = [g for g in side if abs(g["a"][2] - g["b"][2]) < 1e-3 and g["a"][2] < fz + 0.5]
    # (a frente da carga pode ter um poste/cabeceira na frente de `front_z`, como a graneleira: a escada pode montar nele)
    edge0 = max([m["cab"]["roof_back_z"] + 0.05, edge_min] + [g["a"][2] + STRIP_W * 0.6 + 0.021 for g in vert])
    y_bot = round(bot + 0.03, 3)
    ys = [round(y_bot + 0.05 * i, 3) for i in range(int((top + 0.02 - y_bot) / 0.05) + 1)]
    above = [round(top + 0.03 + 0.05 * i, 3) for i in range(int((LADDER_ROOF + LEDBOX_H + 0.02) / 0.05) + 2)]
    cache: dict = {}

    def hit(y, z):
        k = (y, round(z, 3))
        if k not in cache:
            cache[k] = _side_hit(trees, sx, y, z)
        return cache[k]

    for w in (LADDER_W, 0.30, 0.26, LADDER_WMIN, CARGO_WMIN):
        z = edge0 + w / 2
        while z + w / 2 <= fz + CARGO_REACH + 1e-6:
            cols = (z - w / 2 + 0.02, z, z + w / 2 - 0.02)
            # colunas a cada 2 cm (uma lanterna de 8 cm passa entre as 3 colunas da lateral) com a folga dos lados
            z_a = z - w / 2 - CARGO_LAMP_GAP
            wide = [z_a + 0.02 * k for k in range(int((w + 2 * CARGO_LAMP_GAP) / 0.02) + 1)] + [z + w / 2 + CARGO_LAMP_GAP]
            lamps = [y for y in ys + above if any((h := hit(y, q)) and h[1] == "bad" for q in wide)]
            # fileira de luzes de marcação no friso de baixo da carga: a escada começa logo acima dela (sobe até CARGO_LIFT)
            low = [y for y in lamps if y <= y_bot + CARGO_LIFT]
            y_start = max(low) + 0.06 if low else y_bot
            rows = []
            for y in ys:                                                  # lateral da carga, do fundo para cima
                if y < y_start - 1e-6:
                    continue
                r = [hit(y, q) for q in cols]
                if not all(h and h[1] == "ok" and h[0] >= hw - CARGO_DEEP for h in r):
                    if not rows and y < y_start + 0.2:
                        continue                  # (vão entre o assoalho e o friso de baixo: a escada começa no friso)
                    break
                rows.append((y, r))
            ok = len(rows) >= 2 and rows[-1][0] - rows[0][0] >= CARGO_MIN
            if dbg is not None and not ok:
                dbg.append((w, round(z, 3), "lateral curta", rows[-1][0] if rows else None))
            if ok:
                ltop = rows[-1][0]
                face = max(h[0] for _, r in rows for h in r)
                for y, _ in rows:                                         # o que sai mais, a cada 2 cm (dobradiça, friso)
                    for q in wide:
                        h = hit(y, q) if z - w / 2 - 1e-6 <= q <= z + w / 2 + 1e-6 else None
                        if h and h[0] >= hw - CARGO_DEEP:
                            face = max(face, h[0])
                # luz de marcação (e vidro) em nenhuma coluna, da base da escada até a caixa de LED
                up = [y for y in lamps if rows[0][0] - 0.03 <= y <= ltop + LADDER_ROOF + LEDBOX_H + 0.03]
                if up:
                    ok = False
                    if dbg is not None:
                        dbg.append((w, round(z, 3), "luz/vidro", up[0]))
            if ok:
                for y in [q for q in ys if q > ltop] + above:           # acima da borda: nada saindo da lateral
                    if y > ltop + LADDER_ROOF + LEDBOX_H + 0.03:
                        break
                    if any((h := hit(y, q)) and h[0] > face - 0.005 for q in cols):
                        ok = False
                        if dbg is not None:
                            dbg.append((w, round(z, 3), "acima da borda", y))
                        break
            if ok:
                xc = [r[1][0] for _, r in rows]                           # coluna do meio (onde fica o espaçador)
                # o espaçador fica na coluna do meio: é ela que precisa estar perto (as bordas só não podem sair mais)
                if dbg is not None and face - min(xc) > LADDER_FLAT:
                    dbg.append((w, round(z, 3), "torta", round(face - min(xc), 3)))
                if face - min(xc) <= LADDER_FLAT:
                    # por fora do contorno de LED da lateral (faixas que passam por esta escada)
                    zs0, zs1 = z - w / 2 - 0.02, z + w / 2 + 0.02
                    over = [g for g in horiz if min(g["a"][2], g["b"][2]) - 0.01 < zs1 and max(g["a"][2], g["b"][2]) + 0.01 > zs0]
                    lx = max([face] + [abs(g["a"][0]) + STRIP_T + 0.004 for g in over])
                    # faixas de altura onde o espaçador pode ficar (entre as faixas do contorno, dentro da lateral medida)
                    bands = sorted((g["a"][1] - STRIP_W * 0.6 - 0.002, g["a"][1] + STRIP_W * 0.6 + 0.002) for g in over)
                    y0 = rows[0][0]
                    free, lo = [], y0
                    for b0, b1 in bands:
                        if b0 > lo:
                            free.append([round(lo, 3), round(min(b0, ltop), 3)])
                        lo = max(lo, b1)
                    if lo < ltop:
                        free.append([round(lo, 3), round(ltop, 3)])
                    free = [f for f in free if f[1] - f[0] >= 0.05]
                    # vão a cada 1 cm na coluna do meio (friso, nervura: o jogo não põe espaçador onde o vão muda de repente)
                    fine = []
                    for i in range(int(round((ltop - y0) / CARGO_GAP_DY)) + 1):
                        h = hit(round(y0 + CARGO_GAP_DY * i, 3), z)
                        fine.append(round(float(lx - h[0]), 3) if h and h[0] >= hw - CARGO_DEEP else -1.0)
                    return {"x": round(lx, 3), "lean": 0.0, "z": round(z, 3), "w": w, "y0": y0,
                            "top": round(ltop + LADDER_ROOF, 3), "dy": CARGO_GAP_DY,
                            "gaps": fine, "on": "cargo", "sp_free": free}
            z += 0.01
    return None
