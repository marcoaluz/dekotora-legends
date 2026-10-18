"""Gravação de mapas (bake) no Cycles por linha de comando (T-136): da malha ALTA para a malha LEVE.

Fluxo: `setup()` liga o Cycles na CPU; `target_copy()` junta cópias das malhas leves num alvo só (com o mesmo
sombreamento do jogo); `bake_pass()` grava um passe ("NORMAL", "AO", "DIFFUSE" só cor, "ROUGHNESS", "EMIT") de todas
as fontes selecionadas para o alvo ativo; `pixels()`/`save_png()` leem e gravam com numpy (sem conversão de cor).
Determinístico: semente fixa e mesma ordem de objetos.
"""
from __future__ import annotations

import os

import bpy
import numpy as np


def setup(samples: int = 4, ao_distance: float = 0.25, threads: int = 0) -> None:
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.seed = 7
    sc.cycles.use_denoising = False
    if threads:
        sc.render.threads_mode = "FIXED"
        sc.render.threads = threads
    if sc.world is None:
        sc.world = bpy.data.worlds.new("bake_world")
    sc.world.light_settings.distance = ao_distance
    sc.render.bake.margin = 8
    sc.render.bake.margin_type = "EXTEND"


def new_image(name: str, w: int, h: int, color=(0, 0, 0, 1)):
    img = bpy.data.images.new(name, w, h, alpha=False, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    img.generated_color = color
    return img


def target_copy(objs, name: str, smooth_deg: float = 35.0):
    """Cópia junta das malhas leves `objs` (sem mexer nas originais), com um material só para receber o bake."""
    from . import mesh3d as M
    copies = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        copies.append(c)
    M.apply_transforms(copies)
    bpy.ops.object.select_all(action="DESELECT")
    for c in copies:
        c.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    if len(copies) > 1:
        bpy.ops.object.join()
    t = bpy.context.view_layer.objects.active
    t.name = name
    t.data.materials.clear()
    mat = bpy.data.materials.new(name + "_mat")
    if hasattr(mat, "use_nodes") and not mat.use_nodes:
        mat.use_nodes = True
    t.data.materials.append(mat)
    M.smooth([t], smooth_deg)
    for attr in ("visible_camera", "visible_diffuse", "visible_glossy", "visible_transmission", "visible_shadow"):
        setattr(t, attr, False)                      # não faz sombra na oclusão das fontes
    return t


def _set_target_image(t, img) -> None:
    nt = t.data.materials[0].node_tree
    node = nt.nodes.get("__bake")
    if node is None:
        node = nt.nodes.new("ShaderNodeTexImage")
        node.name = "__bake"
    node.image = img
    nt.nodes.active = node


def bake_pass(kind: str, sources, target, img, cage: float = 0.03, ray: float = 0.08, samples: int | None = None) -> None:
    """Grava `kind` das `sources` (malhas altas) na imagem `img` do alvo `target`."""
    sc = bpy.context.scene
    if samples is not None:
        sc.cycles.samples = samples
    _set_target_image(target, img)
    bpy.ops.object.select_all(action="DESELECT")
    for s in sources:
        s.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    kw = dict(type=kind, use_selected_to_active=True, cage_extrusion=cage, max_ray_distance=ray, margin=8)
    if kind == "DIFFUSE":
        kw["pass_filter"] = {"COLOR"}
    if kind == "NORMAL":
        kw.update(normal_space="TANGENT", normal_r="POS_X", normal_g="POS_Y", normal_b="POS_Z")
    bpy.ops.object.bake(**kw)


def pixels(img) -> np.ndarray:
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, 4)


def save_png(arr: np.ndarray, path: str) -> None:
    """Grava RGB(A) 0..1 como PNG 8 bits, sem conversão de cor (linha 0 = embaixo, como o Blender guarda)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    h, w = arr.shape[:2]
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1), np.float32)], axis=2)
    img = bpy.data.images.new("__png_" + os.path.basename(path), w, h, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)
