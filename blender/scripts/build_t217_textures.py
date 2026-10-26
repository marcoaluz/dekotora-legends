"""T-217: route ambience textures made by code (numpy, deterministic, nothing downloaded).

Uso: blender -b --factory-startup -P blender/scripts/build_t217_textures.py -- [--out game/assets/textures/t217]
Saida (ver lib/tex_t217.py):
  stone_wall.png, stone_wall_nrm.png  1024 px: muro de pedra 谷積み (cor + mapa de normais), 3 m por repeticao
  hedge.png                           512 px: cerca viva do canteiro central
  mist.png                            256 px: nuvem de neblina (alfa)
  water.png                           256 x 512: agua caindo da cachoeira (repete na vertical)
  danchi_atlas.png                    1024 x 512: celulas dos predios de apartamentos (団地)
  cut_frame.png                       512 px: talude com grade de concreto (のり枠) e grama
Se o Marco colocar texturas CC0 em game/assets/textures/cc0/t217/ (docs/BIBLIOTECA_CENARIO.md, secao 6), o jogo usa
as dele no lugar destas.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import tex_scenic, tex_t217  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/textures/t217")
    ap.add_argument("--only", default="")
    a = ap.parse_args(argv)
    out = os.path.abspath(a.out)
    only = set(x for x in a.only.split(",") if x)
    jobs = {
        "stone_wall": tex_t217.stone_wall,
        "stone_wall_nrm": tex_t217.stone_wall_normal,
        "hedge": tex_t217.hedge,
        "mist": tex_t217.mist,
        "water": tex_t217.water,
        "danchi_atlas": tex_t217.danchi_atlas,
        "cut_frame": tex_t217.cut_frame,
    }
    for name, fn in jobs.items():
        if only and name not in only:
            continue
        tex_scenic.save_rgba(fn(), os.path.join(out, name + ".png"))
        print("  ", name)
    print("OK build_t217_textures ->", out)


if __name__ == "__main__":
    main()
