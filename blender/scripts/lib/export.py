"""Saída: PNG exato, JSON ao lado e folha de contato ampliada."""
from __future__ import annotations

import json
import math
import os

import bpy
import numpy as np


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
