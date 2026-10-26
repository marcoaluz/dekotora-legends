"""Folhas de contato da T-231 a partir das capturas de tools/capture_t231.sh (Blender + numpy, sem Pillow).
Uso: blender -b --factory-startup -P tools/sheet_t231.py -- PASTA_RAW PASTA_SAIDA
"""
import glob
import os
import sys

import bpy
import numpy as np

RAW, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
VIEWS = ["front", "side", "back", "q34", "back34", "roof_back"]


def load(path):
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = "Non-Color"
    w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(im)
    return a


def sheet(files, cols, out):
    imgs = [load(f) for f in files if os.path.exists(f)]
    if not imgs:
        return
    h, w = imgs[0].shape[:2]
    gap = 4
    rows = (len(imgs) + cols - 1) // cols
    H, W = rows * h + (rows - 1) * gap, cols * w + (cols - 1) * gap
    s = np.zeros((H, W, 4), np.float32)
    s[..., 3] = 1.0
    for i, a in enumerate(imgs):
        r, c = i // cols, i % cols
        y0 = H - (r + 1) * h - r * gap
        s[y0:y0 + h, c * (w + gap):c * (w + gap) + w] = a[:h, :w]
    img = bpy.data.images.new("sheet", W, H)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(s.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    print("FOLHA", out)


tags = sorted({os.path.basename(f).split("_dia_")[0] for f in glob.glob(os.path.join(RAW, "*_dia_*.png"))})
for t in tags:
    files = [os.path.join(RAW, f"{t}_{tod}_{v}.png") for tod in ("dia", "noite") for v in VIEWS]
    sheet(files, len(VIEWS), os.path.join(OUT, f"folha_{t}.png"))
for kind in ("traseira", "foguete"):
    fs = sorted(glob.glob(os.path.join(RAW, f"{kind}_*_dia.png")))
    files = []
    for f in fs:
        files += [f, f.replace("_dia.png", "_noite.png")]
    sheet(files, 4, os.path.join(OUT, f"folha_{kind}s.png"))
sheet([os.path.join(RAW, "dano_inteira_noite.png"), os.path.join(RAW, "dano_quebrada_noite.png")], 2, os.path.join(OUT, "folha_dano.png"))
