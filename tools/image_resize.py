"""Corta (centro) e redimensiona PNGs usando o Python do Blender (sem Pillow).
Uso: blender -b --factory-startup -P tools/image_resize.py -- entrada.png saida.png LARGURA ALTURA
"""
import sys
import bpy
import os
src, dst, w, h = sys.argv[sys.argv.index("--") + 1:][:4]
src, dst = os.path.abspath(src), os.path.abspath(dst)
w, h = int(w), int(h)
img = bpy.data.images.load(src)
iw, ih = img.size
target = w / h
cw, ch = (iw, int(iw / target)) if iw / ih > target else (int(ih * target), ih)
if cw > iw or ch > ih:
    cw, ch = iw, ih
import numpy as np
px = np.empty(iw * ih * 4, dtype=np.float32)
img.pixels.foreach_get(px)
px = px.reshape(ih, iw, 4)
y0, x0 = (ih - ch) // 2, (iw - cw) // 2
crop = np.ascontiguousarray(px[y0:y0 + ch, x0:x0 + cw])
tmp = bpy.data.images.new("crop", cw, ch, alpha=True)
tmp.pixels.foreach_set(crop.ravel())
tmp.scale(w, h)
tmp.filepath_raw = dst
tmp.file_format = "PNG"
tmp.save()
print("OK", dst, w, h)
