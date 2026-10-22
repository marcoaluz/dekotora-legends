"""T-193: kanji/kana neon signs of docs/Modelos/Letras Japones e neon/NeonText.blend (outside Git; "Royalty Free, sem
IA, sem credito") rendered with their OWN neon materials into one atlas for the city (NeonSigns, T-188).
The .blend is opened read-only and never saved. Only the Japanese signs are used (the "Text messege"/"TEXT"
placeholders of the pack are left out). The Cinema 4D pack of the same folder cannot be opened by Blender.

Atlas game/assets/textures/scenic/neon_t193_atlas.png (1024 x 1024, black = board, bright = tubes):
  h_taisetsu  大切に思ってる (horizontal, rooftop)      v_gensou  幻想通り + か (vertical, facade)
  s_yozora    夜空 (red box)    s_mugen  無限 (round)    s_neko  招き猫 (lucky cat)
  s_inori     祈 Pray           s_hito   人 Person
Cell rects in pixels are in NeonSigns (game/scripts/road3d/neon_signs.gd, T193_CELLS) and must match CELLS here.
Usage: blender -b --factory-startup -P blender/scripts/build_t193_neon.py -- [--file NeonText.blend]
"""
from __future__ import annotations

import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import export as EX  # noqa: E402

OUT = os.path.join(ROOT, "game", "assets", "textures", "scenic", "neon_t193_atlas.png")
WORK = os.path.join(ROOT, "blender", "renders", "t193", "neon")
SIZE = 1024
# name: (pixel rect x, y, w, h in the atlas (y from the top), world centre x, z of the board in the .blend, world height)
CELLS = {
    "h_taisetsu": ((0, 0, 1024, 320), (1.125, 9.955), 2.5),
    "v_gensou": ((0, 320, 224, 704), (8.69, 8.0), 5.5),
    "s_yozora": ((224, 320, 320, 320), (6.32, 9.91), 2.1),
    "s_mugen": ((544, 320, 320, 320), (11.26, 2.04), 2.7),
    "s_neko": ((224, 640, 320, 320), (-0.25, 4.63), 3.0),
    "s_inori": ((544, 640, 160, 160), (11.765, 8.225), 1.35),
    "s_hito": ((544, 800, 160, 160), (11.765, 6.76), 1.35),
}


def main() -> None:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    src = a[a.index("--file") + 1] if "--file" in a else os.path.join(ROOT, "docs", "Modelos", "Letras Japones e neon",
                                                                       "NeonText.blend")
    bpy.ops.wm.open_mainfile(filepath=src)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False
    w = sc.world or bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = next((n for n in w.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg is not None:
        bg.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
        bg.inputs["Strength"].default_value = 0.0
    cam = bpy.data.objects.new("t193_cam", bpy.data.cameras.new("t193_cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.rotation_euler = (1.5708, 0.0, 0.0)                    # looking toward +Y (the front of the board)
    cam.data.clip_end = 100.0
    sc.camera = cam
    os.makedirs(WORK, exist_ok=True)
    atlas = np.zeros((SIZE, SIZE, 4), np.float32)
    atlas[..., 3] = 1.0
    for name, ((px, py, pw, ph), (cx, cz), wh) in CELLS.items():
        sc.render.resolution_x, sc.render.resolution_y = pw, ph
        sc.render.resolution_percentage = 100
        cam.data.ortho_scale = wh * max(pw, ph) / ph            # ortho_scale = the larger side
        cam.location = (cx, -20.0, cz)
        p = os.path.join(WORK, name + ".png")
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(p)
        arr = np.zeros(pw * ph * 4, np.float32)
        im.pixels.foreach_get(arr)
        arr = arr.reshape(ph, pw, 4)[::-1]
        atlas[py:py + ph, px:px + pw, :3] = arr[..., :3]
        print("NEON_T193", name, (px, py, pw, ph))
    EX.save_png(atlas, OUT)
    imp = OUT + ".import"
    if not os.path.isfile(imp):
        with open(os.path.join(ROOT, "game", "assets", "textures", "scenic", "neon_atlas.png.import"), encoding="utf-8") as f:
            txt = f.read()
        with open(imp, "w", encoding="utf-8", newline="\n") as f:          # same import settings as the T-188 atlas
            f.write("\n".join(l for l in txt.splitlines() if not l.startswith(("uid=", "path=", "dest_files=", "source_file="))) + "\n")
    print("OK build_t193_neon", OUT)


main()
