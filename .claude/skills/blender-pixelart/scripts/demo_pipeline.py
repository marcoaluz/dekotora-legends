"""
demo_pipeline.py — prova de ponta a ponta do pipeline (testado no Blender 5.2 headless).

Monta um caminhão PROVISÓRIO de caixas, uma peça de teste (luzes de teto) e renderiza:
  base_<ângulo>.png, part_roof_<ângulo>.png (com holdout), roof_glow_<ângulo>.png, contact_sheet.png

Rodar a partir da raiz do projeto:
    blender -b --factory-startup -P .claude/skills/blender-pixelart/scripts/demo_pipeline.py -- --out blender/renders/demo

Use como modelo para os scripts reais; não é o caminhão final.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pxlib  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--out", default="blender/renders/demo")
ap.add_argument("--palette", default="blender/palettes/dekotora.json")
ap.add_argument("--w", type=int, default=96)
ap.add_argument("--h", type=int, default=72)
ap.add_argument("--ss", type=int, default=4, help="supersample: render ss× maior e reduz")
args = ap.parse_args(argv)
out = os.path.abspath(args.out)
os.makedirs(out, exist_ok=True)

sc = pxlib.reset_scene()
palette, outline = pxlib.load_palette(args.palette)
H = pxlib.hex_to_rgb

white = pxlib.toon_material("white", H("#dfe6f0"))
red = pxlib.toon_material("red", H("#d1303f"))
dark = pxlib.toon_material("glass", H("#1e1b3d"))
rubber = pxlib.toon_material("rubber", H("#26262b"))
chrome = pxlib.chrome_material()
tail = pxlib.emissive_material("tail", H("#ff4d4d"))
amber = pxlib.emissive_material("amber", H("#ffb347"))

# --- caminhão base provisório (traseira em Y=0, frente em +Y)
base = [
    pxlib.box("bau", (2.5, 9.0, 2.6), (0, 4.5, 1.0), white, bevel=0.03),
    pxlib.box("faixa", (2.52, 9.02, 0.25), (0, 4.5, 1.25), red),
    pxlib.box("cabine", (2.4, 2.0, 2.4), (0, 10.2, 0.9), white, bevel=0.05),
    pxlib.box("vidro", (2.2, 0.05, 0.7), (0, 11.2, 2.3), dark),
    pxlib.box("chassi", (2.2, 11.5, 0.35), (0, 5.8, 0.55), rubber),
    pxlib.box("lanterna_e", (0.35, 0.05, 0.18), (-0.95, -0.03, 0.75), tail),
    pxlib.box("lanterna_d", (0.35, 0.05, 0.18), (0.95, -0.03, 0.75), tail),
]
for x in (-0.9, 0.9):
    for y in (1.0, 2.3, 10.0):
        base.append(pxlib.cylinder_x(f"roda_{x}_{y}", 0.5, 0.45, (x, y, 0.5), rubber))

# --- peça de teste: barra cromada com luzes no topo traseiro do baú
part = [pxlib.box("roof_bar", (2.4, 0.2, 0.15), (0, 0.1, 3.6), chrome)]
for i in range(7):
    x = -1.05 + i * 0.35
    part.append(pxlib.box(f"roof_light_{i}", (0.18, 0.06, 0.12), (x, -0.02, 3.66), amber))

pxlib.add_key_light()
pxlib.camera_rig(ortho_scale=6.5, target_z=1.9)
piv = pxlib.pivot(base + part)
pxlib.fit_camera(base + part, piv)
glow_objs = pxlib.emissive_objects(part)

W, Hh, S = args.w, args.h, args.ss
sheet = []
for name, deg in pxlib.ANGLES.items():
    piv.rotation_euler = (0, 0, deg * 3.14159265 / 180)
    bpy_tmp = os.path.join(out, "_tmp.png")

    pxlib.set_layer(visible=base)
    b = pxlib.pixelize(pxlib.render_rgba(bpy_tmp, W * S, Hh * S), S, palette, outline)
    pxlib.save_png(b, os.path.join(out, f"base_{name}.png"))

    pxlib.set_layer(visible=part, holdout=base)          # só o que aparece da peça
    p = pxlib.pixelize(pxlib.render_rgba(bpy_tmp, W * S, Hh * S), S, palette, None)
    pxlib.save_png(p, os.path.join(out, f"part_roof_{name}.png"))

    others = [o for o in base + part if o not in glow_objs]
    pxlib.set_layer(visible=glow_objs, holdout=others)   # máscara de brilho
    g = pxlib.pixelize(pxlib.render_rgba(bpy_tmp, W * S, Hh * S), S, palette, None)
    pxlib.save_png(g, os.path.join(out, f"roof_glow_{name}.png"))

    stacked = b.copy()
    m = p[..., 3:4]
    stacked[..., :3] = p[..., :3] * m + stacked[..., :3] * (1 - m)
    stacked[..., 3:4] = (stacked[..., 3:4] + m).clip(0, 1)
    sheet += [(f"base_{name}", b), (f"base+roof_{name}", stacked)]

ax, ay = pxlib.anchor_pixel(W, Hh, (0, 0, 0))
pxlib.save_meta(os.path.join(out, "truck.json"), size=[W, Hh], anchor=[ax, ay],
                angles=list(pxlib.ANGLES), layers=["base", "part_roof"], glow=["roof_glow"])
pxlib.contact_sheet(sheet, os.path.join(out, "contact_sheet.png"), cols=2)
os.remove(os.path.join(out, "_tmp.png"))
print("OK demo_pipeline ->", out)
