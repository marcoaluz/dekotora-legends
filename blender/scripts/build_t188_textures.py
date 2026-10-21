"""T-188: scenery textures made by code (numpy, deterministic, nothing downloaded).

Uso: blender -b --factory-startup -P blender/scripts/build_t188_textures.py -- [--out game/assets/textures/scenic]
Saida:
  terrain_detail.png  512 x 512 RGBA: R grama, G terra, B rocha, A copa de floresta (detalhe em tons de cinza;
                      a cor vem do shader do terreno, road3d/terrain_patch.gd)
  facade_atlas.png    1024 x 512 RGBA: 8 fachadas (12 m x 14 m cada, alfa = vidro das janelas)
  tree_cards.png      512 x 256 RGBA: silhueta de conifera e de arvore de folhas (floresta das encostas)
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import tex_scenic  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/textures/scenic")
    out = os.path.abspath(ap.parse_args(argv).out)
    tex_scenic.save_rgba(tex_scenic.terrain_detail(), os.path.join(out, "terrain_detail.png"))
    tex_scenic.save_rgba(tex_scenic.facade_atlas(), os.path.join(out, "facade_atlas.png"))
    tex_scenic.save_rgba(tex_scenic.tree_cards(), os.path.join(out, "tree_cards.png"))
    print("OK build_t188_textures ->", out)


if __name__ == "__main__":
    main()
