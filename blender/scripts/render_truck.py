"""Renderiza o caminhão base nos 5 ângulos (L2, L1, C, R1, R2) em pixel art.

Uso: blender -b --factory-startup -P blender/scripts/render_truck.py -- [--w 160 --h 120]
Saída: game/assets/sprites/truck/base/base_<ang>.png, base_glow_<ang>.png, base.json,
       blender/renders/truck_base/{contact_sheet.png, review_3q.png}
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_truck_base as T  # noqa: E402
from lib import camera_rig, export, palette as pal, pixelize, render, scene  # noqa: E402

FRAME_W, FRAME_H, SUPERSAMPLE, PITCH = 160, 120, 4, 7.0


def setup(pitch: float = PITCH):
    """Cena + base + câmera + pivô. Devolve (objs, mats, pivô). Reutilizado pelos scripts de peças."""
    scene.reset_scene()
    mats = T.make_materials()
    objs = T.build_base(mats)
    scene.add_key_light(rot_deg=(50, 0, -35), energy=3.0)
    camera_rig.camera_rig(ortho_scale=6.5, pitch_deg=pitch, target_z=T.CENTER[2], target_y=T.CENTER[1])
    piv = camera_rig.pivot(objs, center=(0, T.CENTER[1], 0))
    camera_rig.fit_camera(objs, piv)
    return objs, mats, piv


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--palette", default="blender/palettes/dekotora.json")
    ap.add_argument("--sprites", default="game/assets/sprites/truck/base")
    ap.add_argument("--renders", default="blender/renders/truck_base")
    ap.add_argument("--w", type=int, default=FRAME_W)
    ap.add_argument("--h", type=int, default=FRAME_H)
    ap.add_argument("--ss", type=int, default=SUPERSAMPLE)
    ap.add_argument("--pitch", type=float, default=PITCH)
    args = ap.parse_args(argv)
    sprites, renders = os.path.abspath(args.sprites), os.path.abspath(args.renders)
    os.makedirs(renders, exist_ok=True)

    colors, outline = pal.load_palette(args.palette)
    objs, _mats, piv = setup(args.pitch)
    W, H, S = args.w, args.h, args.ss
    tmp = os.path.join(renders, "_tmp.png")
    glow_objs = render.emissive_objects(objs)
    others = [o for o in objs if o not in glow_objs]
    sheet = []
    for name, deg in camera_rig.ANGLES.items():
        piv.rotation_euler = (0, 0, math.radians(deg))
        render.set_layer(visible=objs)
        a = pixelize.pixelize(render.render_rgba(tmp, W * S, H * S), S, colors, outline)
        export.save_png(a, os.path.join(sprites, f"base_{name}.png"))
        render.set_layer(visible=glow_objs, holdout=others)
        g = pixelize.pixelize(render.render_rgba(tmp, W * S, H * S), S, colors, None)
        export.save_png(g, os.path.join(sprites, f"base_glow_{name}.png"))
        sheet.append((f"base_{name}", a))
    # render de revisão: 3/4 de frente, ampliado (não vai para o jogo)
    piv.rotation_euler = (0, 0, math.radians(150))
    render.set_layer(visible=objs)
    rv = pixelize.pixelize(render.render_rgba(tmp, W * 2 * S, H * 2 * S), S, colors, outline)
    export.save_png(rv, os.path.join(renders, "review_3q.png"))
    os.remove(tmp)
    ax, ay = camera_rig.anchor_pixel(W, H, (0, 0, 0))
    export.save_meta(os.path.join(sprites, "base.json"), size=[W, H], anchor=[ax, ay], offset=[0, 0],
                     angles=list(camera_rig.ANGLES), layers=["base"], glow=["base_glow"])
    export.contact_sheet(sheet, os.path.join(renders, "contact_sheet.png"), cols=5)
    print("OK render_truck ->", sprites)


if __name__ == "__main__":
    main()
