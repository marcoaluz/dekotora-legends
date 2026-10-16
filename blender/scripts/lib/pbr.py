"""Materiais PBR (Principled BSDF) para modelos 3D exportados em .glb para o Godot.

Valores pensados para tempo real: poucos materiais, metallic/roughness coerentes, emissivo para luzes.
Cores recebem sRGB (hex) e são convertidas para linear aqui.
"""
from __future__ import annotations

import bpy

from . import tex
from .palette import hex_to_rgb, lin


def _principled(name: str):
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    return m, bsdf


def _set(bsdf, key: str, value) -> None:
    if key in bsdf.inputs:
        bsdf.inputs[key].default_value = value


def pbr(name: str, hex_color: str, metallic: float = 0.0, roughness: float = 0.5,
        coat: float = 0.0, coat_rough: float = 0.05, emission: str | None = None,
        emission_strength: float = 0.0):
    m, b = _principled(name)
    _set(b, "Base Color", lin(hex_to_rgb(hex_color)) + (1.0,))
    _set(b, "Metallic", metallic)
    _set(b, "Roughness", roughness)
    if coat > 0:
        _set(b, "Coat Weight", coat)
        _set(b, "Coat Roughness", coat_rough)
    if emission:
        _set(b, "Emission Color", lin(hex_to_rgb(emission)) + (1.0,))
        _set(b, "Emission Strength", emission_strength)
    m["px_kind"] = "emissive" if emission else "pbr"
    return m


def paint(name: str, hex_color: str):
    """Pintura perolizada: levemente metálica, verniz brilhante."""
    return pbr(name, hex_color, metallic=0.35, roughness=0.32, coat=0.8, coat_rough=0.04)


def chrome(name: str = "chrome"):
    return pbr(name, "#e6ebf2", metallic=1.0, roughness=0.07)


def brushed_steel(name: str = "steel"):
    return pbr(name, "#aeb8c8", metallic=1.0, roughness=0.32)


def rubber(name: str = "rubber"):
    return pbr(name, "#1a1a1d", metallic=0.0, roughness=0.88)


def plastic_black(name: str = "plastic_black"):
    return pbr(name, "#121214", metallic=0.0, roughness=0.55)


def glass(name: str = "glass"):
    return pbr(name, "#1a2c52", metallic=0.55, roughness=0.03, coat=1.0, coat_rough=0.02)


def emissive(name: str, hex_color: str, strength: float = 6.0):
    return pbr(name, hex_color, metallic=0.0, roughness=0.3, emission=hex_color, emission_strength=strength)


def textured(name: str, image, metallic: float = 0.8, roughness: float = 0.4, tint: str | None = None,
             coat: float = 0.0, coat_rough: float = 0.05):
    """Material PBR com a textura de `image` na cor base (exportada no .glb). `tint` multiplica a textura
    (vira o fator de cor do glTF, então o jogo ainda consegue retingir a pintura)."""
    m, b = _principled(name)
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    if tint:
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[7].default_value = lin(hex_to_rgb(tint)) + (1.0,)
        nt.links.new(tex.outputs["Color"], mix.inputs[6])
        nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    else:
        nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    _set(b, "Metallic", metallic)
    _set(b, "Roughness", roughness)
    if coat > 0:
        _set(b, "Coat Weight", coat)
        _set(b, "Coat Roughness", coat_rough)
    m["px_kind"] = "pbr"
    return m


def standard_set() -> dict:
    """Conjunto padrão usado por caminhão e acessórios (nomes estáveis para o Godot)."""
    return {
        "paint_white": paint("paint_white", "#d6dce6"),
        "paint_pink": paint("paint_pink", "#ff2e88"),
        "paint_red": paint("paint_red", "#c8202f"),
        "paint_blue": paint("paint_blue", "#1d3f8a"),
        "paint_gold": pbr("paint_gold", "#f0b83a", metallic=1.0, roughness=0.22),
        "chrome": chrome(),
        "steel": brushed_steel(),
        "rubber": rubber(),
        "plastic": plastic_black(),
        "glass": glass(),
        "mesh_perf": textured("mesh_perf", tex.perforated_mesh(), 0.85, 0.38),
        "mesh_perf_vent": textured("mesh_perf_vent", tex.perforated_mesh("tex_perf_vent", 12, 2, 768, 128), 0.85, 0.38),
        "mesh_perf_grille": textured("mesh_perf_grille", tex.perforated_mesh("tex_perf_grille", 14, 6, 840, 360), 0.85, 0.38),
        "paint_white_panel": textured("paint_white_panel", tex.grime_panel(), 0.35, 0.32, tint="#d6dce6", coat=0.8, coat_rough=0.04),
        "diamond": textured("diamond", tex.diamond_plate(), 0.7, 0.45),
        "lamp_amber": emissive("lamp_amber", "#ffb347", 3.0),
        "lamp_white": emissive("lamp_white", "#ffe9c2", 3.5),
        "lamp_red": emissive("lamp_red", "#ff2a2a", 3.0),
        "lamp_cyan": emissive("lamp_cyan", "#21e6ff", 3.0),
        "lamp_pink": emissive("lamp_pink", "#ff2e88", 3.0),
        "lamp_yellow": emissive("lamp_yellow", "#fff35c", 3.0),
        "lamp_green": emissive("lamp_green", "#3dff7a", 3.0),
        "lamp_blue": emissive("lamp_blue", "#2f7bff", 3.0),
        "lamp_orange": emissive("lamp_orange", "#ff7a1a", 3.0),
    }
