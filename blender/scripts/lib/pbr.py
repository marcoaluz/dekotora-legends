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


def textured_full(name: str, color_img, orm_img=None, normal_img=None, metallic: float = 0.0,
                  roughness: float = 0.5, tint: str | None = None, coat: float = 0.0, coat_rough: float = 0.05,
                  normal_strength: float = 1.0):
    """Material PBR completo para o glTF: cor (x tint), ORM (G = rugosidade, B = metálico) e mapa de normais.
    Os nós seguem o padrão que o exportador glTF reconhece (Separate Color -> Roughness/Metallic,
    Normal Map -> Normal); no Godot vira StandardMaterial3D com as mesmas texturas."""
    m = textured(name, color_img, metallic, roughness, tint, coat, coat_rough)
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if orm_img is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = orm_img
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(t.outputs["Color"], sep.inputs[0])
        nt.links.new(sep.outputs[1], b.inputs["Roughness"])
        nt.links.new(sep.outputs[2], b.inputs["Metallic"])
    if normal_img is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = normal_img
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = normal_strength
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m


def _gltf_occlusion(nt, socket) -> None:
    """Liga `socket` (canal R do ORM) à oclusão do glTF: o exportador do Blender lê o grupo "glTF Material Output"."""
    g = bpy.data.node_groups.get("glTF Material Output")
    if g is None:
        g = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        g.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    n = nt.nodes.new("ShaderNodeGroup")
    n.node_tree = g
    nt.links.new(socket, n.inputs["Occlusion"])


def baked_full(name: str, color_img, orm_img, normal_img, coat: float = 0.0, coat_rough: float = 0.05):
    """Material com mapas gravados (T-136): cor, ORM (R = oclusão, G = rugosidade, B = metálico) e normais.
    No Godot vira StandardMaterial3D com ao_texture (canal R), roughness (G), metallic (B) e normal_texture."""
    m = textured_full(name, color_img, orm_img, normal_img, metallic=1.0, roughness=1.0, coat=coat, coat_rough=coat_rough)
    nt = m.node_tree
    sep = next(n for n in nt.nodes if n.type == "SEPARATE_COLOR")
    _gltf_occlusion(nt, sep.outputs[0])
    return m


BOX_TEX = ("tex_box_albedo", "tex_box_orm", "tex_box_nrm", "tex_box_mural_orm", "tex_box_mural_nrm")


def box_premium_set(m: dict, tex_dir: str) -> dict:
    """Materiais do baú premium (T-136) com os mapas de `bake_box_premium.py` (em `tex_dir`, a pasta das texturas
    compartilhadas do jogo): paint_white_box (pintura, tingível), box_metal (alumínio, mesmo atlas) e mural
    (cor = PNG trocável do mural; normais/oclusão gravadas). Erro claro se os mapas não existirem."""
    import os
    imgs = {}
    for k in BOX_TEX:
        p = os.path.join(tex_dir, k + ".png")
        if not os.path.exists(p):
            raise SystemExit(f"ERRO: falta {p}. Rode antes: blender -b --factory-startup -P blender/scripts/bake_box_premium.py")
        img = bpy.data.images.load(p, check_existing=False)
        img.name = k
        img.colorspace_settings.name = "sRGB" if k == "tex_box_albedo" else "Non-Color"
        imgs[k] = img
    m["paint_white_box"] = baked_full("paint_white_box", imgs["tex_box_albedo"], imgs["tex_box_orm"], imgs["tex_box_nrm"],
                                      coat=0.6, coat_rough=0.06)
    m["box_metal"] = baked_full("box_metal", imgs["tex_box_albedo"], imgs["tex_box_orm"], imgs["tex_box_nrm"])
    mural = tex._image("tex_mural", tex.mural_geometric()[::-1])          # embutido; o jogo troca pelo PNG do mural
    m["mural"] = baked_full("mural", mural, imgs["tex_box_mural_orm"], imgs["tex_box_mural_nrm"], coat=0.6, coat_rough=0.05)
    return m


def truck_set(m: dict) -> dict:
    """Materiais exclusivos do caminhão (T-106), acrescentados ao conjunto padrão. Nomes estáveis: o jogo
    procura "paint_white" no nome da malha para tingir e "chrome"/"paint_gold" para o cromo por matcap."""
    from . import tex_truck as T
    for k in ("paint_white_panel", "diamond"):                  # troca as versões simples (mesmo nome no .glb)
        old = m.get(k)
        if old is not None:
            for node in old.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image is not None and node.image.users <= 1:
                    bpy.data.images.remove(node.image)
            bpy.data.materials.remove(old)
    col, orm, nrm = T.paint_maps()
    m["paint_white_panel"] = textured_full("paint_white_panel", tex._image("tex_paint_dirt", col),
                                           tex._image("tex_paint_orm", orm, srgb=False), tex._image("tex_paint_nrm", nrm, srgb=False),
                                           tint="#d6dce6", coat=0.8, coat_rough=0.04, normal_strength=1.0)
    col, orm = T.plastic_maps()
    m["plastic_trim"] = textured_full("plastic_trim", tex._image("tex_plastic_dust", col), tex._image("tex_plastic_orm", orm, srgb=False))
    col, orm = T.glass_wind_maps()
    m["glass_wind"] = textured_full("glass_wind", tex._image("tex_glass_wind", col), tex._image("tex_glass_wind_orm", orm, srgb=False),
                                    coat=1.0, coat_rough=0.02)
    m["glass_lens"] = pbr("glass_lens", "#2b313c", metallic=0.85, roughness=0.12)
    col, nrm = T.honeycomb()
    m["grille_honeycomb"] = textured_full("grille_honeycomb", tex._image("tex_honeycomb", col), None,
                                          tex._image("tex_honeycomb_nrm", nrm, srgb=False), metallic=0.5, roughness=0.45)
    col, nrm = T.slots()
    m["vent_slots"] = textured_full("vent_slots", tex._image("tex_vent_slots", col), None,
                                    tex._image("tex_vent_slots_nrm", nrm, srgb=False), metallic=0.2, roughness=0.55)
    col, nrm = T.diamond_maps()
    m["diamond"] = textured_full("diamond", tex._image("tex_diamond_plate", col), None, tex._image("tex_diamond_nrm", nrm, srgb=False),
                                 metallic=0.75, roughness=0.42)
    return m


def tire_material(profile, R: float):
    from . import tex_truck as T
    col, orm = T.tire_maps(profile, R)
    return textured_full("rubber_tire", tex._image("tex_tire", col), tex._image("tex_tire_orm", orm, srgb=False))


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
        "andon_panel": emissive("andon_panel", "#7a0f24", 1.2),
        "lamp_blue": emissive("lamp_blue", "#2f7bff", 3.0),
        "lamp_orange": emissive("lamp_orange", "#ff7a1a", 3.0),
    }
