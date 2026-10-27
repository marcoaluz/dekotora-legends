"""Folha de contato simples: junta PNGs do mesmo tamanho numa grade (Blender + numpy, sem Pillow). T-240.
Uso: blender -b --factory-startup -P tools/sheet_grid.py -- SAIDA.png COLUNAS a.png b.png ...
Arquivo que falta vira um quadro preto (a grade não anda)."""
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out, cols, files = args[0], int(args[1]), args[2:]


def load(p):
    im = bpy.data.images.load(p)
    im.colorspace_settings.name = "Non-Color"
    w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(im)
    return a


imgs = [load(f) if os.path.exists(f) else None for f in files]
ref = next(a for a in imgs if a is not None)
h, w = ref.shape[:2]
gap = 4
rows = (len(imgs) + cols - 1) // cols
sheet = np.zeros((rows * h + (rows + 1) * gap, cols * w + (cols + 1) * gap, 4), np.float32)
sheet[..., :3] = 0.05
sheet[..., 3] = 1.0
for i, a in enumerate(imgs):
    if a is None or a.shape[:2] != (h, w):
        continue
    r, c = divmod(i, cols)
    y, x = gap + r * (h + gap), gap + c * (w + gap)
    sheet[y:y + h, x:x + w] = a
img = bpy.data.images.new(os.path.basename(out), sheet.shape[1], sheet.shape[0], alpha=False)
img.colorspace_settings.name = "Non-Color"
img.pixels.foreach_set(sheet[::-1].ravel())
img.filepath_raw = out
img.file_format = "PNG"
img.save()
print("FOLHA", out, len([a for a in imgs if a is not None]), "quadros")
