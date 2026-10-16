"""Materiais chapados (toon), cromo e luz emissiva. Cores da paleta (sRGB) viram linear aqui."""
from __future__ import annotations

import bpy
import numpy as np

from .palette import hex_to_rgb, lin


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
