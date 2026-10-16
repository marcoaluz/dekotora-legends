"""Materiais PBR (Principled BSDF) para modelos 3D exportados em .glb para o Godot.

Valores pensados para tempo real: poucos materiais, metallic/roughness coerentes, emissivo para luzes.
Cores recebem sRGB (hex) e são convertidas para linear aqui.
"""
from __future__ import annotations

import bpy

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
    return pbr(name, "#0b1226", metallic=0.2, roughness=0.04, coat=1.0, coat_rough=0.02)


def emissive(name: str, hex_color: str, strength: float = 6.0):
    return pbr(name, hex_color, metallic=0.0, roughness=0.3, emission=hex_color, emission_strength=strength)


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
        "lamp_amber": emissive("lamp_amber", "#ffb347", 7.0),
        "lamp_white": emissive("lamp_white", "#ffe9c2", 9.0),
        "lamp_red": emissive("lamp_red", "#ff2a2a", 6.0),
        "lamp_cyan": emissive("lamp_cyan", "#21e6ff", 6.0),
        "lamp_pink": emissive("lamp_pink", "#ff2e88", 6.0),
        "lamp_yellow": emissive("lamp_yellow", "#fff35c", 6.0),
    }
