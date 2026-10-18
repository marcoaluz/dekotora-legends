"""Materiais da versão ALTA (só para gravar mapas, T-136), com texturas PBR CC0 de `blender/cc0/`:

- pintura com desgaste: Poly Haven "Blue Metal Plate" (Rob Tuytel, CC0): rugosidade em manchas, riscos no mapa de
  normais e lascas (os pontos claros da cor viram metal exposto); a cor é a NOSSA (branco do baú);
- metal: ambientCG "Metal012" (CC0): alumínio/aço escovado (cor, rugosidade e normal);
- borracha: ambientCG "Rubber004" (CC0): rugosidade e normal da borracha de vedação.
Sujeira: oclusão local (nó Ambient Occlusion do Cycles) escurece frestas e a base do baú fica mais suja.
O metálico de cada material também sai na emissão (força 0); `metal_pass(True)` liga a força para gravar o metálico
pelo passe EMIT (o Cycles não tem passe de metálico).
"""
from __future__ import annotations

import os

import bpy

from .palette import hex_to_rgb, lin

CC0 = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "cc0"))
FILES = {
    "paint": ("blue_metal_plate/blue_metal_plate_diff_512.jpg", "blue_metal_plate/blue_metal_plate_rough_512.jpg",
              "blue_metal_plate/blue_metal_plate_nor_gl_512.jpg"),
    "metal": ("Metal012/Metal012_512-JPG_Color.jpg", "Metal012/Metal012_512-JPG_Roughness.jpg", "Metal012/Metal012_512-JPG_NormalGL.jpg"),
    "rubber": (None, "Rubber004/Rubber004_512-JPG_Roughness.jpg", "Rubber004/Rubber004_512-JPG_NormalGL.jpg"),
}
_EMIT: list = []


def _img(rel: str, srgb: bool):
    path = os.path.join(CC0, rel)
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    return img


def _rgb(hexc: str):
    return lin(hex_to_rgb(hexc)) + (1.0,)


def _new(name: str):
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    return m, nt, b


def _tex(nt, img, uv):
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    nt.links.new(uv, t.inputs["Vector"])
    return t


def _math(nt, op, a, b=None, clamp=True):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def _mix(nt, fac, a, b):
    n = nt.nodes.new("ShaderNodeMix")
    n.data_type = "RGBA"
    for i, v in ((6, a), (7, b)):
        if isinstance(v, tuple):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    if isinstance(fac, (int, float)):
        n.inputs[0].default_value = fac
    else:
        nt.links.new(fac, n.inputs[0])
    return n.outputs[2]


def _common(nt, b, kind: str, scale: float, normal_strength: float, z0: float):
    """UV em metros x escala, normal CC0, sujeira (oclusão local + base do baú). Devolve (uv, rough_tex, dirt)."""
    uvn = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    nt.links.new(uvn.outputs["UV"], mp.inputs["Vector"])
    uv = mp.outputs[0]
    col_f, rough_f, nrm_f = FILES[kind]
    rough = _tex(nt, _img(rough_f, False), uv).outputs["Color"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.inputs["Strength"].default_value = normal_strength
    nt.links.new(_tex(nt, _img(nrm_f, False), uv).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.05
    ao.samples = 8
    crease = _math(nt, "SUBTRACT", 1.0, ao.outputs["AO"])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    low = _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", z0 + 0.7, sep.outputs["Z"], clamp=False), 0.5)
    dirt = _math(nt, "ADD", _math(nt, "MULTIPLY", crease, 1.4), _math(nt, "MULTIPLY", low, 0.45))
    return uv, rough, dirt, col_f


def _finish(nt, b, metal_out) -> None:
    """Metálico também na emissão (força 0); o passe EMIT grava o metálico com `metal_pass(True)`."""
    cc = nt.nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        if isinstance(metal_out, (int, float)):
            cc.inputs[i].default_value = metal_out
        else:
            nt.links.new(metal_out, cc.inputs[i])
    nt.links.new(cc.outputs[0], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.0
    if isinstance(metal_out, (int, float)):
        b.inputs["Metallic"].default_value = metal_out
    else:
        nt.links.new(metal_out, b.inputs["Metallic"])
    _EMIT.append(b)


def paint(name: str = "hi_paint", color: str = "#eef1f4", z0: float = 1.1, scale: float = 0.55):
    m, nt, b = _new(name)
    uv, rough, dirt, col_f = _common(nt, b, "paint", scale, 0.35, z0)
    diff = _tex(nt, _img(col_f, True), uv).outputs["Color"]
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(diff, bw.inputs[0])
    chip = nt.nodes.new("ShaderNodeMapRange")                         # pontos claros da textura = lascas
    chip.inputs["From Min"].default_value = 0.30
    chip.inputs["From Max"].default_value = 0.42
    nt.links.new(bw.outputs[0], chip.inputs["Value"])
    chip = chip.outputs[0]
    base = _mix(nt, _math(nt, "MULTIPLY", rough, 0.12), _rgb(color), _rgb("#c9ccd0"))   # leve mancha
    base = _mix(nt, chip, base, _rgb("#a7adb4"))                       # lasca: alumínio por baixo
    base = _mix(nt, _math(nt, "MINIMUM", dirt, 0.75), base, _rgb("#6e675d"))   # poeira/fuligem
    nt.links.new(base, b.inputs["Base Color"])
    r = _math(nt, "ADD", 0.24, _math(nt, "MULTIPLY", rough, 0.35))
    r = _math(nt, "ADD", r, _math(nt, "MULTIPLY", dirt, 0.25))
    nt.links.new(r, b.inputs["Roughness"])
    _finish(nt, b, _math(nt, "ADD", 0.08, _math(nt, "MULTIPLY", chip, 0.85)))
    return m


def metal(name: str = "hi_metal", z0: float = 1.1, scale: float = 0.8):
    m, nt, b = _new(name)
    uv, rough, dirt, col_f = _common(nt, b, "metal", scale, 0.5, z0)
    col = _tex(nt, _img(col_f, True), uv).outputs["Color"]
    col = _mix(nt, _math(nt, "MINIMUM", dirt, 0.8), col, _rgb("#57524b"))
    nt.links.new(col, b.inputs["Base Color"])
    r = _math(nt, "ADD", _math(nt, "MULTIPLY", rough, 0.8), _math(nt, "MULTIPLY", dirt, 0.3))
    nt.links.new(r, b.inputs["Roughness"])
    _finish(nt, b, 1.0)
    return m


def rubber(name: str = "hi_rubber", z0: float = 1.1, scale: float = 2.0):
    m, nt, b = _new(name)
    uv, rough, dirt, _ = _common(nt, b, "rubber", scale, 0.6, z0)
    b.inputs["Base Color"].default_value = _rgb("#151517")
    r = _math(nt, "ADD", 0.72, _math(nt, "MULTIPLY", rough, 0.25))
    nt.links.new(r, b.inputs["Roughness"])
    _finish(nt, b, 0.0)
    return m


def metal_pass(on: bool) -> None:
    for b in _EMIT:
        b.inputs["Emission Strength"].default_value = 1.0 if on else 0.0
