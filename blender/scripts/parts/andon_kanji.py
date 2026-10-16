"""Andon traseiro: painel luminoso com o kanji 一番星 (Noto Sans JP) sobre a porta do baú."""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import build_truck_base as T  # noqa: E402,F401
from lib import materials, shapes  # noqa: E402
from lib.palette import hex_to_rgb as H  # noqa: E402

ID, SLOT, ZONE = "andon_kanji", "andon", "rear"
FONT = "game/assets/fonts/NotoSansJP.ttf"


def build(m: dict) -> list:
    n = f"part_{SLOT}_{ID}"
    glow = materials.emissive_material("andon_glow", H("#fff35c"))
    z0 = 2.15
    o = [
        shapes.box(f"{n}_frame", (2.2, 0.14, 1.0), (0, -0.1, z0), m["chrome"], bevel=0.02),
        shapes.box(f"{n}_face", (2.04, 0.04, 0.84), (0, -0.2, z0 + 0.08), glow),
    ]
    # kanji escuro sobre o painel luminoso (texto 3D); sem a fonte, cai para texto latino
    font_path = os.path.abspath(FONT)
    has_font = os.path.exists(font_path)
    curve = bpy.data.curves.new(f"{n}_text", "FONT")
    curve.body = "一番星" if has_font else "ICHIBAN"
    if has_font:
        curve.font = bpy.data.fonts.load(font_path)
    curve.size = 1.5
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.01
    curve.offset = 0.03   # engrossa os traços (legível em pixel art)
    ob = bpy.data.objects.new(f"{n}_text", curve)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (0, -0.225, z0 + 0.5)
    ob.rotation_euler = (1.5707963, 0, 0)   # de pé, voltado para trás (-Y), legível de trás
    ob.data.materials.append(m["frame"])
    o.append(ob)
    return o
