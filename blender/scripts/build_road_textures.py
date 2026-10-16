"""Texturas repetíveis da estrada e do terreno para o Godot (asfalto, rugosidade do asfalto, grama, areia).

Uso: blender -b --factory-startup -P blender/scripts/build_road_textures.py -- [--out game/assets/textures]
Saída: asphalt_albedo.png, asphalt_rough.png, grass.png, sand.png (512 px, repetem nas bordas).
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import scene, tex  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/textures")
    out = os.path.abspath(ap.parse_args(argv).out)
    scene.reset_scene()
    col, rough = tex.asphalt()
    tex.save_png(col, os.path.join(out, "asphalt_albedo.png"))
    tex.save_png(rough, os.path.join(out, "asphalt_rough.png"))
    tex.save_png(tex.grass(), os.path.join(out, "grass.png"))
    tex.save_png(tex.sand(), os.path.join(out, "sand.png"))
    print("OK build_road_textures ->", out)


if __name__ == "__main__":
    main()
