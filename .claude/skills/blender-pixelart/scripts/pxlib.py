"""
pxlib.py — biblioteca de referência TESTADA (Blender 5.2, headless) para o pipeline
Blender -> pixel art do Dekotora Legends.

Uso dentro de um script rodado com:
    blender -b --factory-startup -P meu_script.py -- --out <pasta>

    import sys, os
    sys.path.insert(0, os.path.dirname(__file__))   # ou o caminho desta pasta
    import pxlib

Convenções: metros, caminhão aponta para +Y, chão em Z=0, câmera atrás (em -Y) olhando para +Y.
Arrays de pixels: numpy (altura, largura, 4), linha 0 = TOPO da imagem (já invertido aqui).
"""
from __future__ import annotations

import json
import math
import os
import random

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

# ---------------------------------------------------------------- cena

def reset_scene(seed: int = 1234) -> bpy.types.Scene:
    """Cena vazia, determinística, cores sem tone mapping."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(seed)
    np.random.seed(seed)
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    # 4.2-4.x usam BLENDER_EEVEE_NEXT; 5.x voltou para BLENDER_EEVEE
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"   # nada de AgX/Filmic: cor da paleta = cor final
    sc.view_settings.look = "None"
    sc.unit_settings.system = "METRIC"
    world = bpy.data.worlds.new("world")
    sc.world = world
    return sc


def hex_to_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def lin(rgb) -> tuple[float, float, float]:
    """sRGB (paleta) -> linear (o que os nós de material esperam). SEM isto, #ff4d4d sai rosa."""
    out = []
    for c in rgb[:3]:
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def load_palette(path: str) -> tuple[np.ndarray, np.ndarray]:
    """Lê blender/palettes/dekotora.json -> (cores Nx3 float 0..1, cor de contorno 3)."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    cols = [hex_to_rgb(c) for group in data["colors"].values() for c in group]
    return np.array(cols, dtype=np.float32), np.array(hex_to_rgb(data["outline"]), dtype=np.float32)

# ---------------------------------------------------------------- materiais (toon)

def _new_material(name: str):
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True        # obsoleto no 5.x (sempre ligado), necessário no 4.x
    nt = m.node_tree
    nt.nodes.clear()
    return m, nt


def toon_material(name: str, base: tuple, dark: float = 0.55, light: float = 0.35,
                  steps: tuple = (0.35, 0.75)):
    """Sombreamento chapado em 3 tons: sombra, base, luz. `base` em sRGB (como na paleta).
    Os tons são calculados em sRGB e convertidos para linear. Precisa de uma luz (add_key_light)."""
    m, nt = _new_material(name)
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    cr = ramp.color_ramp
    cr.interpolation = "CONSTANT"
    b = np.array(base[:3])
    shade = lin(b * dark) + (1,)
    lit = lin(b + (1 - b) * light) + (1,)
    cr.elements[0].position = 0.0
    cr.elements[0].color = shade
    cr.elements[1].position = steps[0]
    cr.elements[1].color = lin(b) + (1,)
    e = cr.elements.new(steps[1])
    e.color = lit
    nt.links.new(diff.outputs[0], s2rgb.inputs[0])
    nt.links.new(s2rgb.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs[0])
    m["px_kind"] = "toon"
    return m


def chrome_material(name: str = "chrome"):
    """Cromo: contraste alto, faixa clara. Funciona bem em pixel art pequena."""
    return toon_material(name, hex_to_rgb("#7a8597"), dark=0.35, light=0.8, steps=(0.3, 0.6))


def emissive_material(name: str, color: tuple, strength: float = 1.0):
    """Luz: cor fixa (não sofre sombra). Objetos com este material entram na camada *_glow."""
    m, nt = _new_material(name)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit.inputs["Color"].default_value = lin(color) + (1,)
    emit.inputs["Strength"].default_value = strength
    nt.links.new(emit.outputs[0], out.inputs[0])
    m["px_kind"] = "emissive"
    return m


def add_key_light(rot_deg=(50, 0, -35), energy: float = 3.0):
    sun = bpy.data.lights.new("key", "SUN")
    sun.energy = energy
    ob = bpy.data.objects.new("key", sun)
    bpy.context.scene.collection.objects.link(ob)
    ob.rotation_euler = [math.radians(a) for a in rot_deg]
    return ob

# ---------------------------------------------------------------- formas

def box(name: str, size: tuple, loc: tuple, mat=None, bevel: float = 0.0, collection=None):
    """Caixa com tamanho (x, y, z) em metros e base no ponto loc (z = chão da caixa)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0], loc[1], loc[2] + size[2] / 2))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    if mat:
        ob.data.materials.append(mat)
    if collection:
        for c in ob.users_collection:
            c.objects.unlink(ob)
        collection.objects.link(ob)
    return ob


def cylinder_x(name: str, radius: float, width: float, loc: tuple, mat=None, verts: int = 12):
    """Cilindro deitado no eixo X (rodas, faróis redondos)."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=width,
                                        location=loc, rotation=(0, math.radians(90), 0))
    ob = bpy.context.active_object
    ob.name = name
    if mat:
        ob.data.materials.append(mat)
    return ob


def group(name: str) -> bpy.types.Collection:
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col

# ---------------------------------------------------------------- câmera

ANGLES = {"L2": 20.0, "L1": 10.0, "C": 0.0, "R1": -10.0, "R2": -20.0}


def camera_rig(ortho_scale: float = 6.0, height: float = 4.0, distance: float = 30.0,
               pitch_deg: float = 12.0, target_z: float = 1.6):
    """Câmera ortográfica atrás do caminhão (em -Y), levemente acima, olhando para +Y."""
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = ortho_scale
    ob = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    p = math.radians(pitch_deg)
    ob.location = (0, -distance * math.cos(p), target_z + distance * math.sin(p))
    ob.rotation_euler = (math.radians(90) - p, 0, 0)
    bpy.context.scene.camera = ob
    return ob


def pivot(objects) -> bpy.types.Object:
    """Empty que gira todos os objetos juntos (para os ângulos L2..R2)."""
    e = bpy.data.objects.new("pivot", None)
    bpy.context.scene.collection.objects.link(e)
    for o in objects:
        o.parent = e
    return e


def fit_camera(objects, piv, angles: dict = None, margin: float = 0.06) -> float:
    """Ajusta ortho_scale para TODOS os ângulos caberem no quadro (mesmo zoom em todos,
    para as camadas e ângulos continuarem alinhados). Chame depois de camera_rig e pivot."""
    sc = bpy.context.scene
    cam = sc.camera
    angles = angles or ANGLES
    worst = 0.0
    for deg in angles.values():
        piv.rotation_euler = (0, 0, math.radians(deg))
        bpy.context.view_layer.update()
        for o in objects:
            for c in o.bound_box:
                v = world_to_camera_view(sc, cam, o.matrix_world @ Vector(c))
                worst = max(worst, abs(v.x - 0.5) * 2, abs(v.y - 0.5) * 2)
    piv.rotation_euler = (0, 0, 0)
    cam.data.ortho_scale *= worst * (1 + margin)
    bpy.context.view_layer.update()
    return cam.data.ortho_scale


def anchor_pixel(width: int, height: int, world_point=(0, 0, 0)) -> tuple[int, int]:
    """Pixel (x, y a partir do topo) onde um ponto do mundo aparece. Use como âncora no JSON."""
    sc = bpy.context.scene
    v = world_to_camera_view(sc, sc.camera, Vector(world_point))
    return int(round(v.x * width)), int(round((1 - v.y) * height))

# ---------------------------------------------------------------- render

def render_rgba(path: str, width: int, height: int) -> np.ndarray:
    """Renderiza e devolve array (h, w, 4) com linha 0 no topo, valores 0..1 exatos (sRGB)."""
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = width, height
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"      # lê os bytes como estão, sem conversão
    buf = np.empty(width * height * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return buf.reshape(height, width, 4)[::-1].copy()


def set_layer(visible, holdout=(), hidden=()):
    """Configura uma camada: visíveis, invisíveis que tampam (holdout) e escondidos."""
    for o in bpy.context.scene.objects:
        if o.type not in {"MESH", "CURVE", "FONT"}:
            continue
        o.hide_render = True
        o.is_holdout = False
    for o in visible:
        o.hide_render = False
    for o in holdout:
        o.hide_render = False
        o.is_holdout = True
    for o in hidden:
        o.hide_render = True


def emissive_objects(objs):
    out = []
    for o in objs:
        for slot in getattr(o, "material_slots", []):
            if slot.material and slot.material.get("px_kind") == "emissive":
                out.append(o)
                break
    return out

# ---------------------------------------------------------------- pixelização

def pixelize(hi: np.ndarray, scale: int, palette: np.ndarray, outline=None,
             alpha_cut: float = 0.5) -> np.ndarray:
    """
    hi: render em resolução scale× maior (h*scale, w*scale, 4).
    1) cada pixel vai para a cor mais próxima da paleta;
    2) cada bloco scale×scale vira 1 pixel: opaco se cobertura >= alpha_cut, cor = a mais frequente;
    3) contorno opcional nos pixels transparentes vizinhos de opacos.
    """
    H, W = hi.shape[0] // scale, hi.shape[1] // scale
    hi = hi[:H * scale, :W * scale]
    rgb, a = hi[..., :3], hi[..., 3]
    d = ((rgb[..., None, :] - palette[None, None, :, :]) ** 2).sum(-1)
    idx = d.argmin(-1)
    opaque = a >= 0.5
    blocks_a = opaque.reshape(H, scale, W, scale).mean(axis=(1, 3))
    counts = np.zeros((H, W, len(palette)), dtype=np.int32)
    ib = np.where(opaque, idx, -1).reshape(H, scale, W, scale)
    for k in range(len(palette)):
        counts[..., k] = (ib == k).sum(axis=(1, 3))
    out = np.zeros((H, W, 4), dtype=np.float32)
    solid = blocks_a >= alpha_cut
    out[solid, :3] = palette[counts.argmax(-1)][solid]
    out[solid, 3] = 1.0
    if outline is not None:
        o = solid
        n = np.zeros_like(o)
        n[1:] |= o[:-1]; n[:-1] |= o[1:]; n[:, 1:] |= o[:, :-1]; n[:, :-1] |= o[:, 1:]
        edge = n & ~o
        out[edge, :3] = outline
        out[edge, 3] = 1.0
    return out

# ---------------------------------------------------------------- saída

def save_png(arr: np.ndarray, path: str) -> None:
    """Salva array (h, w, 4), linha 0 no topo, como PNG exato (sem conversão de cor)."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    h, w = arr.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).ravel().astype(np.float32))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def save_meta(path: str, **data) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def contact_sheet(items: list[tuple[str, np.ndarray]], path: str, cols: int = 5,
                  zoom: int = 4, bg=(0.08, 0.07, 0.16)) -> None:
    """Folha de revisão: imagens lado a lado ampliadas zoom×; nomes em <path>.txt (linha, coluna)."""
    if not items:
        return
    ch = max(a.shape[0] for _, a in items) * zoom + 8
    cw = max(a.shape[1] for _, a in items) * zoom + 8
    rows = math.ceil(len(items) / cols)
    sheet = np.zeros((rows * ch, cols * cw, 4), dtype=np.float32)
    sheet[..., :3] = bg
    sheet[..., 3] = 1
    legend = []
    for i, (name, a) in enumerate(items):
        r, c = divmod(i, cols)
        big = np.repeat(np.repeat(a, zoom, 0), zoom, 1)
        y, x = r * ch + 4, c * cw + 4
        region = sheet[y:y + big.shape[0], x:x + big.shape[1]]
        al = big[..., 3:4]
        region[..., :3] = big[..., :3] * al + region[..., :3] * (1 - al)
        legend.append(f"linha {r + 1}, coluna {c + 1}: {name}")
    save_png(sheet, path)
    with open(path + ".txt", "w", encoding="utf-8") as f:
        f.write("\n".join(legend) + "\n")
