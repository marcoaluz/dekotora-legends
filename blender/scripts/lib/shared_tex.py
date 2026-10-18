"""Texturas compartilhadas (T-118): grava cada textura grande UMA vez numa pasta do jogo e, só durante a
exportação do .glb, troca-a por uma miniatura 4x4 com a cor média (mesmo nome de imagem). No Godot,
`TruckTextures` (game/scripts/truck/truck_textures.gd) acha a textura compartilhada pelo nome e troca em runtime.

Uso:
    swaps = shared_tex.externalize(materiais, pasta)   # antes de exportar
    M.export_glb(...)
    shared_tex.restore(swaps)                          # volta as texturas cheias (prévias e .blend)
"""
from __future__ import annotations

import os

import bpy
import numpy as np

SKIP = ("tex_mural",)        # o mural já é trocado pelo TruckNode (PNG trocável); fica embutido


def _pixels(img) -> np.ndarray:
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, 4)


def _save(arr: np.ndarray, path: str) -> None:
    """Grava os pixels como estão (linha 0 = embaixo, igual ao Blender), sem conversão de cor."""
    h, w = arr.shape[:2]
    img = bpy.data.images.new("__save_" + os.path.basename(path), w, h, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def externalize(materials, out_dir: str):
    """Grava as texturas dos `materials` em `out_dir/<nome>.png` e põe miniaturas no lugar. Devolve a lista
    para `restore`."""
    os.makedirs(out_dir, exist_ok=True)
    swaps = []
    done = {}
    for mat in materials:
        if mat is None or not mat.node_tree:
            continue
        for node in mat.node_tree.nodes:
            if node.type != "TEX_IMAGE" or node.image is None or node.image.name in SKIP:
                continue
            full = node.image
            if full.name.endswith("__full"):
                key = full.name[:-6]
            else:
                key = full.name
            if key not in done:
                arr = _pixels(full)
                _save(arr, os.path.join(out_dir, key + ".png"))
                full.name = key + "__full"
                mini = bpy.data.images.new(key, 4, 4, alpha=False)
                mini.colorspace_settings.name = full.colorspace_settings.name
                mean = arr.reshape(-1, 4).mean(axis=0)
                mean[3] = 1.0
                mini.pixels.foreach_set(np.tile(mean, 16).astype(np.float32))
                mini.pack()
                done[key] = (full, mini)
            full, mini = done[key]
            node.image = mini
            swaps.append((node, full))
    return swaps


def restore(swaps) -> None:
    minis = set()
    for node, full in swaps:
        minis.add(node.image)
        node.image = full
    for mini in minis:
        name = mini.name
        bpy.data.images.remove(mini)
        for node, full in swaps:
            if full.name == name + "__full":
                full.name = name
