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


def import_truck(path) -> dict:
    """Importa o .glb numa cena vazia. Devolve {nome do objeto sem sufixo: matriz Nx3 de vértices (Godot)} e os
    pontos MOUNT_* (Godot). T-240: `path` pode ser uma lista (carroceria + cabine do kit): as malhas de mesmo nome
    viram uma só, como o jogo faz (TruckKit)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for k, p in enumerate([path] if isinstance(path, str) else list(path)):
        dy = 0.0
        if isinstance(p, (tuple, list)):                       # (.glb, deslocamento para a frente em m): cabine do kit
            p, dy = p
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(p))
        if dy:
            for o in bpy.data.objects:
                if o not in before and o.parent is None:
                    o.location.y += dy
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
