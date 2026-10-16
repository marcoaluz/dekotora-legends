"""Renderiza peças decorativas em camadas (holdout do caminhão base) nos 5 ângulos e 3 estados de dano.

Uso: blender -b --factory-startup -P blender/scripts/render_parts.py -- [--parts all | id1,id2]
Saída: game/assets/sprites/parts/<id>/part_<id>_<estado>_<ang>.png (+ <id>_glow_<estado>_<ang>.png
       se a peça tiver luzes) e <id>.json; folha de contato em blender/renders/parts/contact_sheet.png
Todos os PNG têm o mesmo quadro e a mesma âncora do caminhão base (basta empilhar no Godot).
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parts as PARTS  # noqa: E402
import render_truck  # noqa: E402
from lib import camera_rig, damage, export, palette as pal, pixelize, render  # noqa: E402


def over(dst: np.ndarray, src: np.ndarray) -> np.ndarray:
    """Composição simples (alfa binário): src sobre dst."""
    out = dst.copy()
    m = src[..., 3:4] > 0
    out[..., :3] = np.where(m, src[..., :3], out[..., :3])
    out[..., 3:4] = np.maximum(out[..., 3:4], src[..., 3:4])
    return out


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--parts", default="all")
    ap.add_argument("--palette", default="blender/palettes/dekotora.json")
    ap.add_argument("--sprites", default="game/assets/sprites/parts")
    ap.add_argument("--renders", default="blender/renders/parts")
    ap.add_argument("--icons", default="game/assets/sprites/icons/parts")
    ap.add_argument("--w", type=int, default=render_truck.FRAME_W)
    ap.add_argument("--h", type=int, default=render_truck.FRAME_H)
    ap.add_argument("--ss", type=int, default=render_truck.SUPERSAMPLE)
    args = ap.parse_args(argv)
    ids = PARTS.ORDER if args.parts == "all" else args.parts.split(",")
    sprites, renders = os.path.abspath(args.sprites), os.path.abspath(args.renders)
    os.makedirs(renders, exist_ok=True)
    colors, outline = pal.load_palette(args.palette)
    W, H, S = args.w, args.h, args.ss
    tmp = os.path.join(renders, "_tmp.png")

    base, mats, piv = render_truck.setup()
    part_objs = {}
    for pid in ids:
        objs = PARTS.load(pid).build(mats)
        part_objs[pid] = objs
        for o in objs:       # liga ao pivô sem mover
            o.parent = piv
            o.matrix_parent_inverse = piv.matrix_world.inverted()
        damage.prepare(objs)
    snaps = {pid: damage.capture(o) for pid, o in part_objs.items()}
    all_part_objs = [o for objs in part_objs.values() for o in objs]
    for o in all_part_objs:
        o.hide_render = True

    def shot(visible, holdout=(), outl=None):
        render.set_layer(visible=visible, holdout=holdout)
        return pixelize.pixelize(render.render_rgba(tmp, W * S, H * S), S, colors, outl)

    results = {}      # (pid, state, ang) -> sprite
    base_sprites = {}
    for ang, deg in camera_rig.ANGLES.items():
        piv.rotation_euler = (0, 0, math.radians(deg))
        for pid in ids:       # peças ficam em estado ok enquanto a base é renderizada
            damage.apply_state(part_objs[pid], "ok", snaps[pid])
        base_sprites[ang] = shot(base, outl=outline)
        for pid in ids:
            objs = part_objs[pid]
            for st in damage.STATES:
                damage.apply_state(objs, st, snaps[pid])
                vis = damage.visible(objs)
                holdout = base + [o for pid2 in ids if pid2 != pid for o in part_objs[pid2]]
                # só a peça, com a base (e as outras peças) tampando o que está atrás
                sp = shot(vis, holdout=base, outl=None)
                results[(pid, st, ang)] = sp
                export.save_png(sp, os.path.join(sprites, pid, f"part_{pid}_{st}_{ang}.png"))
                glow_objs = render.emissive_objects(vis)
                if glow_objs:
                    others = base + [o for o in vis if o not in glow_objs]
                    g = shot(glow_objs, holdout=others)
                    export.save_png(g, os.path.join(sprites, pid, f"{pid}_glow_{st}_{ang}.png"))
            damage.apply_state(objs, "ok", snaps[pid])
    os.remove(tmp)

    ax, ay = camera_rig.anchor_pixel(W, H, (0, 0, 0))
    for pid in ids:
        mod = PARTS.load(pid)
        has_glow = any(render.emissive_objects(part_objs[pid]))
        export.save_meta(os.path.join(sprites, pid, f"{pid}.json"), id=pid, slot=mod.SLOT, zone=mod.ZONE,
                         size=[W, H], anchor=[ax, ay], offset=[0, 0], angles=list(camera_rig.ANGLES),
                         states=list(damage.STATES), glow=has_glow)

    # folha de contato: linha 1 = base; depois, base + todas as peças empilhadas em cada estado
    sheet = [(f"base_{a}", s) for a, s in base_sprites.items()]
    for st in damage.STATES:
        for ang in camera_rig.ANGLES:
            img = base_sprites[ang]
            for pid in PARTS.ORDER:
                if (pid, st, ang) in results:
                    img = over(img, results[(pid, st, ang)])
            sheet.append((f"all_{st}_{ang}", img))
    export.contact_sheet(sheet, os.path.join(renders, "contact_sheet.png"), cols=5)
    print("OK render_parts ->", sprites)


if __name__ == "__main__":
    main()
