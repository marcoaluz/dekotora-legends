"""Letras da T-232 (kanji/kana) em VETOR: o Blender converte cada caractere da fonte de pincel Yuji Syuku (OFL,
`blender/fonts/`) em malha e guardamos os triângulos (unidade = tamanho da fonte, y para BAIXO, centro do caractere
em (0, 0)). As pinturas desenham esses triângulos com o rasterizador do `paint2d` em qualquer tamanho.

Confere cada caractere na tabela `cmap` da própria fonte (lib/font_cmap.py): caractere que a fonte não tem sairia
como "tofu" (o Blender desenha um glifo reserva sem avisar) -> ERRO, nunca entra.
Precisa do Blender (`bpy`); o resultado (.npz) é lido por qualquer Python com numpy.
"""
from __future__ import annotations

import os

import numpy as np

FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fonts", "YujiSyuku-Regular.ttf")


def build(chars: str, out_npz: str, font_path: str = FONT) -> dict:
    """Gera o .npz com {"U+XXXX": triângulos (n, 3, 2) float32}. Devolve {caractere: nº de triângulos}."""
    import bpy
    from . import font_cmap
    lack = font_cmap.missing(font_path, chars)
    if lack:
        raise RuntimeError("ERRO: a fonte não tem estes caracteres (sairiam como tofu): " + " ".join("U+%04X" % ord(c) for c in lack))
    font = bpy.data.fonts.load(os.path.abspath(font_path), check_existing=True)
    out, count, missing = {}, {}, []
    for ch in sorted(set(chars) - {" ", "\n"}):
        curve = bpy.data.curves.new("g", "FONT")
        curve.body = ch
        curve.size = 1.0
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.resolution_u = 10
        curve.font = font
        ob = bpy.data.objects.new("g", curve)
        bpy.context.scene.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        me.calc_loop_triangles()
        co = np.array([v.co[:2] for v in me.vertices], np.float32).reshape(-1, 2)
        tri = np.array([t.vertices[:] for t in me.loop_triangles], np.int64).reshape(-1, 3)
        bpy.data.objects.remove(ob)
        bpy.data.curves.remove(curve)
        bpy.data.meshes.remove(me)
        if len(tri) == 0:
            missing.append(ch)
            continue
        t = co[tri]
        t[..., 1] *= -1.0                                   # y para baixo (como a imagem)
        out["U+%04X" % ord(ch)] = t.astype(np.float32)
        count[ch] = len(tri)
    if missing:
        raise RuntimeError("ERRO: a fonte não tem estes caracteres (sairiam como tofu): " + "".join(missing))
    os.makedirs(os.path.dirname(os.path.abspath(out_npz)), exist_ok=True)
    np.savez_compressed(out_npz, **out)
    return count
