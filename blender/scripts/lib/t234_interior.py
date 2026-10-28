"""Interior da cabine visto pelo para-brisa (T-234, lacuna "interior" da seção 19 de docs/REFERENCIA_PECAS.md).

O vidro dos caminhões é opaco (azul escuro com reflexo). Em vez de abrir a cabine, cada interior é uma ARTE que o jogo
põe 4 mm na frente do para-brisa (retângulo medido por raios, `lib/t234_measure.py`; montagem igual à das pinturas,
`game/scripts/truck/paint_fit.gd`, com transparência nas bordas). A arte é um render 3D nosso (EEVEE) de uma cabine
genérica (painel, volante à direita, bancos, parede do fundo) com a peça: cortina franzida, lustre de cristal ou
estofado capitonê. Depois o vidro é aplicado por cima (tom azulado e o reflexo do céu em cima) e as bordas somem aos
poucos (cada cabine tem um vidro de formato diferente). À noite: render só com o que acende (`_emit`).
Olhando de fora, a direita da imagem é o lado ESQUERDO do caminhão (u = -x): o volante (à direita, Japão) aparece à
esquerda da imagem. Determinístico.
"""
from __future__ import annotations

import math
import os

import bpy
import numpy as np

from . import mesh3d as M
from . import paint2d as P
from . import scene
from .palette import hex_to_rgb, lin

PX = (1024, 416)              # proporção ~2,46 (para-brisas de 2,0 a 3,0)
WIN_W = 2.2                   # m: largura do quadro (ortográfico)
REL = "paint_t234/interior"
ARTS = [
    ("interior_curtain", "Cortina franzida vermelha"),
    ("interior_chandelier", "Lustre de cristal âmbar"),
    ("interior_tufted", "Estofado capitonê com neon"),
]


def _mat(name, hexc, metal=0.0, rough=0.5, emit=0.0, emit_hex=None):
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(hex_to_rgb(hexc)) + (1.0,)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = lin(hex_to_rgb(emit_hex or hexc)) + (1.0,)
        b.inputs["Emission Strength"].default_value = emit
    return m


def _cab(mt):
    """Cabine genérica: parede do fundo, teto, laterais, painel com mostradores, volante e 2 bancos."""
    o = [M.box("back", (2.6, 0.05, 1.6), (0, -1.75, 0.35), mt["wall"], bevel=0.0, seg=1),
         M.box("ceil", (2.6, 1.9, 0.05), (0, -0.85, 1.02), mt["ceil"], bevel=0.0, seg=1)]
    for sx in (-1, 1):
        o.append(M.box(f"side_{sx}", (0.05, 1.9, 1.6), (sx * 1.25, -0.85, 0.35), mt["wall"], bevel=0.0, seg=1))
    o.append(M.box("dash", (2.4, 0.5, 0.42), (0, -0.30, -0.12), mt["dash"], bevel=0.04, seg=2))
    o.append(M.box("dash_top", (2.3, 0.35, 0.04), (0, -0.22, 0.10), mt["dash"], bevel=0.015, seg=1))
    for k, x in enumerate((0.42, 0.62)):                     # mostradores (lado do volante: +X)
        o.append(M.cylinder(f"gauge_{k}", 0.035, 0.02, (x, -0.06, 0.03), mt["gauge"], axis="Y", seg=16))
    o.append(M.torus("wheel", 0.20, 0.022, (0.55, -0.28, 0.20), mt["dash"], axis="Y", seg=24, tube_seg=6))
    o[-1].rotation_euler = (math.radians(65), 0, 0)
    for sx in (-1, 1):
        o.append(M.box(f"seat_{sx}", (0.55, 0.16, 0.75), (sx * 0.55, -1.05, 0.25), mt["seat"], bevel=0.06, seg=2))
        o.append(M.box(f"head_{sx}", (0.32, 0.12, 0.2), (sx * 0.55, -1.05, 0.72), mt["seat"], bevel=0.05, seg=2))
    return o


def curtain(mt):
    """Cortina franzida vermelha (金華山) com varão dourado e franja: bando em cima e 2 laterais amarradas."""
    o = [M.cylinder("rod", 0.018, 2.3, (0, -0.10, 0.86), mt["gold"], axis="X", seg=12)]
    n = 44
    for k in range(n):                                       # bando franzido: pregas alternando para frente/trás
        x = -1.1 + 2.2 * (k + 0.5) / n
        dy = 0.03 if k % 2 else -0.01
        o.append(M.box(f"valance_{k}", (2.2 / n * 1.25, 0.05, 0.24), (x, -0.13 + dy, 0.74), mt["velvet"], bevel=0.02, seg=2))
        o.append(M.sphere(f"tassel_{k}", 0.016, (x, -0.10 + dy, 0.60), mt["gold"], seg=8, rings=5))
    for sx in (-1, 1):                                       # laterais caindo e amarradas
        for k in range(7):
            x = sx * (1.05 - k * 0.045)
            o.append(M.box(f"drape_{sx}_{k}", (0.06, 0.06, 0.9), (x, -0.16 - (k % 2) * 0.03, 0.30), mt["velvet"], bevel=0.025, seg=2))
        o.append(M.torus(f"tie_{sx}", 0.13, 0.02, (sx * 0.92, -0.14, 0.18), mt["gold"], axis="Z", seg=16, tube_seg=5))
    return o


def chandelier(mt):
    """Lustre de cristal âmbar pendurado no teto, no meio, com braços dourados (acende à noite)."""
    o = [M.cylinder("chain", 0.01, 0.20, (0, -0.55, 0.92), mt["gold"], axis="Z", seg=6),
         M.sphere("hub", 0.06, (0, -0.55, 0.78), mt["gold"], seg=12, rings=8)]
    for ring, (r, z, n) in enumerate(((0.32, 0.70, 12), (0.22, 0.60, 9), (0.11, 0.52, 6))):
        o.append(M.torus(f"arm_{ring}", r, 0.01, (0, -0.55, z + 0.03), mt["gold"], axis="Z", seg=24, tube_seg=4))
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * ring) / n
            x, y = math.sin(a) * r, -0.55 + math.cos(a) * r
            o.append(M.sphere(f"crystal_{ring}_{k}", 0.028, (x, y, z), mt["crystal"], seg=8, rings=6, scale=(1, 1, 1.6)))
    o.append(M.sphere("drop", 0.05, (0, -0.55, 0.42), mt["crystal"], seg=10, rings=8, scale=(1, 1, 1.8)))
    for sx in (-1, 1):                                       # 2 arandelas pequenas nos cantos
        o.append(M.sphere(f"sconce_{sx}", 0.035, (sx * 0.95, -0.30, 0.80), mt["crystal"], seg=8, rings=6))
    return o


def tufted(mt):
    """Estofado capitonê vermelho com botões dourados na parede do fundo e no teto, e friso de neon rosa."""
    o = []
    for j in range(7):                                       # parede: almofadas em losango (botões nos vértices)
        for i in range(15):
            x = -1.2 + i * 0.17 + (0.085 if j % 2 else 0.0)
            z = -0.05 + j * 0.15
            o.append(M.sphere(f"puff_{i}_{j}", 0.10, (x, -1.70, z), mt["velvet"], seg=10, rings=6, scale=(1.0, 0.35, 0.85)))
            o.append(M.sphere(f"button_{i}_{j}", 0.014, (x + 0.085, -1.66, z + 0.075), mt["gold"], seg=6, rings=4))
    for j in range(5):                                       # teto
        for i in range(12):
            o.append(M.sphere(f"cpuff_{i}_{j}", 0.12, (-1.1 + i * 0.2, -0.3 - j * 0.3, 1.0), mt["velvet"], seg=8, rings=5,
                              scale=(0.85, 1.1, 0.25)))
    o.append(M.cylinder("neon_dash", 0.012, 2.3, (0, -0.06, 0.125), mt["neon"], axis="X", seg=8))
    o.append(M.cylinder("neon_top", 0.012, 2.3, (0, -0.06, 0.86), mt["neon"], axis="X", seg=8))
    for sx in (-1, 1):
        o.append(M.cylinder(f"neon_side_{sx}", 0.012, 0.8, (sx * 1.12, -0.06, 0.53), mt["neon"], axis="Z", seg=8))
    return o


BUILDERS = {"interior_curtain": curtain, "interior_chandelier": chandelier, "interior_tufted": tufted}


def _materials(night):
    k = 1.0 if night else 0.18
    return {
        "wall": _mat("wall", "#0c0709", rough=0.8), "ceil": _mat("ceil", "#0a0608", rough=0.9),
        "dash": _mat("dash", "#0a0a0d", rough=0.45), "seat": _mat("seat", "#0e0a0c", rough=0.35),
        "gauge": _mat("gauge", "#ff9a2a", emit=2.0 * k), "gold": _mat("gold", "#f0b83a", metal=1.0, rough=0.25),
        "velvet": _mat("velvet", "#7a0612", rough=0.6), "crystal": _mat("crystal", "#ff9a30", metal=0.3, rough=0.1, emit=6.0 * k),
        "neon": _mat("neon", "#ff2e88", emit=8.0 * k),
    }


def _render(pid, night, path):
    scene.reset_scene()
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = PX
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0, 0, 0, 1)
    bg.inputs["Strength"].default_value = 0.0
    mt = _materials(night)
    _cab(mt)
    BUILDERS[pid](mt)
    if not night:
        from mathutils import Vector
        for name, loc, e in (("sun_in", (0.0, 2.5, 3.0), 260), ("fill_in", (0.0, 1.5, 0.4), 45)):
            ld = bpy.data.lights.new(name, "AREA")
            ld.energy = e
            ld.size = 3.0
            lo = bpy.data.objects.new(name, ld)
            lo.location = loc
            d = Vector((0.0, -0.8, 0.4)) - Vector(loc)              # aponta para o meio da cabine
            lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
            sc.collection.objects.link(lo)
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = WIN_W
    co = bpy.data.objects.new("cam", cam)
    co.location = (0.0, 3.0, 0.45)
    co.rotation_euler = (math.radians(90), 0, math.radians(180))     # olhando para -Y (de fora para dentro)
    sc.collection.objects.link(co)
    sc.camera = co
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def _load(path):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"
    a = np.array(img.pixels[:], np.float32).reshape(img.size[1], img.size[0], 4)[::-1, :, :3]
    bpy.data.images.remove(img)
    return a


def _glass(col):
    """Vidro por cima: tom azulado escuro, reflexo do céu no alto e borda que some (alfa)."""
    h, w = col.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    v, u = ys / (h - 1), xs / (w - 1)
    tint = np.array([0.88, 0.89, 0.95], np.float32)
    out = col * tint * 0.88 + np.array([0.02, 0.03, 0.055], np.float32)
    refl = np.clip(1.0 - v / 0.18, 0, 1) ** 2 * 0.16 + np.clip(1.0 - np.abs((u - 0.65) - (v - 0.5) * 0.6) / 0.05, 0, 1) * 0.05
    out = 1 - (1 - out) * (1 - refl[..., None])
    edge = np.minimum(np.minimum(u, 1 - u) / 0.045, np.minimum(v, 1 - v) / 0.09)
    alpha = np.clip(edge, 0, 1) ** 1.5
    return np.concatenate([np.clip(out, 0, 1), alpha[..., None]], 2)


def build_all(out_root: str) -> list:
    """Renderiza os 3 interiores (dia + noite) e devolve as entradas do catálogo (fit "paint", encaixe "interior")."""
    tmp = os.path.abspath(os.path.join("blender", "renders", "t234"))
    os.makedirs(tmp, exist_ok=True)
    os.makedirs(os.path.join(out_root, REL), exist_ok=True)
    entries = []
    for pid, name in ARTS:
        day, night = os.path.join(tmp, pid + "_day.png"), os.path.join(tmp, pid + "_night.png")
        _render(pid, False, day)
        _render(pid, True, night)
        col = _glass(_load(day))
        em = _load(night)
        em = P.downsample(em * col[..., 3:4], 2)
        P.save_png(col, os.path.join(out_root, REL, pid + ".png"))
        P.save_png(np.clip(em, 0, 1), os.path.join(out_root, REL, pid + "_emit.png"))
        base = f"res://assets/vehicles/dekotora/{REL}/{pid}"
        entries.append({
            "id": pid, "name": name, "category": "front", "model": "", "mount_point": "SOCKET_interior", "mount_point_left": None,
            "mirror_for_left": False, "dimensions_m": None, "triangles": 2,
            "compatibility": ["todas as cabines (retângulo medido no para-brisa: truck/sockets/*.json, rect)"],
            "materials_used": ["paint_art"], "materials_available": {}, "customizable": None,
            "license": "original (render 3D nosso no Blender, T-234)", "fit_warnings": [], "tier": "oficina",
            "socket": "interior", "fit": "paint", "alpha": True,
            "paint": {"R": [{"tex": base + ".png", "emit": base + "_emit.png", "aspect": round(PX[0] / PX[1], 3), "px": list(PX)}]},
        })
        print(f"[t234] interior {pid} ok")
    return entries
