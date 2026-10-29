"""Folha de contato genérica da T-264 (Blender + numpy, sem Pillow): junta imagens de tamanhos diferentes numa grade,
cada uma reduzida/ampliada (vizinho mais próximo) para a mesma célula.
Uso: blender -b --factory-startup -P tools/sheet_t264.py -- SAIDA.png COLUNAS LARGURA_CELULA img1.png img2.png ...
(caminho que não existe vira célula preta; a altura da célula sai da proporção da 1ª imagem)
"""
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
OUT, COLS, CW = os.path.abspath(args[0]), int(args[1]), int(args[2])
FILES = [os.path.abspath(f) for f in args[3:]]


def load(path):
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = "Non-Color"
    w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(im)
    return a


def fit(a, w, h):
    ys = (np.arange(h) * a.shape[0] / h).astype(int)
    xs = (np.arange(w) * a.shape[1] / w).astype(int)
    return a[ys][:, xs]


imgs = [load(f) if os.path.exists(f) else None for f in FILES]
first = next(a for a in imgs if a is not None)
CH = int(round(CW * first.shape[0] / first.shape[1]))
gap = 4
rows = (len(imgs) + COLS - 1) // COLS
H, W = rows * CH + (rows - 1) * gap, COLS * CW + (COLS - 1) * gap
s = np.zeros((H, W, 4), np.float32)
s[..., 3] = 1.0
for i, a in enumerate(imgs):
    if a is None:
        continue
    r, c = i // COLS, i % COLS
    y0 = H - (r + 1) * CH - r * gap
    b = fit(a, CW, CH)
    b[..., 3] = 1.0
    s[y0:y0 + CH, c * (CW + gap):c * (CW + gap) + CW] = b
img = bpy.data.images.new("sheet", W, H)
img.colorspace_settings.name = "Non-Color"
img.pixels.foreach_set(s.ravel())
img.filepath_raw = OUT
img.file_format = "PNG"
img.save()
print("FOLHA", OUT)
