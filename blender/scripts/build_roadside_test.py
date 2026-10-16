"""Cenário de teste (P23): céu noturno, montanhas, 2 camadas de skyline (parallax, largura repetível) e
objetos de beira de estrada (poste de luz, placa verde, árvore, guard-rail).

Uso: blender -b --factory-startup -P blender/scripts/build_roadside_test.py
Saída: game/assets/backgrounds/kanto/{sky,mountains,city_far,city_near}.png
       game/assets/sprites/roadside/<id>.png (+ <id>_glow.png) e <id>.json (tamanho, âncora, ppm)
Folha de contato: blender/renders/roadside/contact_sheet.png
"""
import argparse
import math
import os
import random
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import camera_rig, export, materials, palette as pal, pixelize, render, scene, shapes  # noqa: E402
from lib.palette import hex_to_rgb as H  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--palette", default="blender/palettes/dekotora.json")
ap.add_argument("--bg", default="game/assets/backgrounds/kanto")
ap.add_argument("--sprites", default="game/assets/sprites/roadside")
ap.add_argument("--renders", default="blender/renders/roadside")
args = ap.parse_args(argv)
BG, SPR, REN = (os.path.abspath(p) for p in (args.bg, args.sprites, args.renders))
os.makedirs(REN, exist_ok=True)
COLORS, OUTLINE = pal.load_palette(args.palette)
SS = 4
TMP = os.path.join(REN, "_tmp.png")
SHEET = []


def nearest_palette(rgb):
    return COLORS[((COLORS - np.array(rgb, dtype=np.float32)) ** 2).sum(1).argmin()]


# ------------------------------------------------------------------ céu e montanhas (numpy, periódicos)

def make_sky(w=480, h=120):
    img = np.zeros((h, w, 4), dtype=np.float32)
    bands = [nearest_palette(H(c)) for c in ("#0b0a14", "#14122a", "#1e1b3d", "#2b2757", "#3c3a73")]
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
    for y in range(h):
        t = y / (h - 1) * (len(bands) - 1)
        i = min(int(t), len(bands) - 2)
        f = t - i
        for x in range(w):
            img[y, x, :3] = bands[i + 1] if f > bayer[y % 4, x % 4] else bands[i]
    img[..., 3] = 1
    rng = np.random.RandomState(5)
    star = [nearest_palette(H(c)) for c in ("#ffffff", "#8af4ff", "#fff35c")]
    for _ in range(60):
        x, y = rng.randint(0, w), rng.randint(0, int(h * 0.6))
        img[y, x, :3] = star[rng.randint(0, 3)]
    return img


def make_mountains(w=960, h=64):
    rng = np.random.RandomState(11)
    x = np.arange(w)
    height = np.zeros(w)
    for k, amp in ((2, 14), (3, 9), (5, 6), (9, 3), (17, 1.5)):
        height += amp * np.sin(2 * math.pi * k * x / w + rng.uniform(0, 6.28))
    height = (height - height.min()) / (height.max() - height.min()) * (h - 14) + 10
    img = np.zeros((h, w, 4), dtype=np.float32)
    body, rim = nearest_palette(H("#2b2757")), nearest_palette(H("#545394"))
    for xi in range(w):
        top = h - int(height[xi])
        img[top:, xi, :3] = body
        img[top:, xi, 3] = 1
        img[top, xi, :3] = rim
    return img


# ------------------------------------------------------------------ render genérico de objetos Blender

def render_object(name, build, w, h, ppm, pitch=0.0, out_dir=None, glow=True, outline=True, tz_extra=0.0):
    """Renderiza o que `build(mats)` criar, de trás/frente, âncora = base no chão (0,0,0)."""
    scene.reset_scene()
    mats = {"white": materials.toon_material("white", H("#dfe6f0")),
            "gray": materials.toon_material("gray", H("#4a5262")),
            "dark": materials.toon_material("dark", H("#1e1b3d")),
            "green": materials.toon_material("green", H("#1f6e48")),
            "green_d": materials.toon_material("green_d", H("#123a2a")),
            "leaf": materials.toon_material("leaf", H("#1f6e48"), dark=0.6, light=0.25),
            "trunk": materials.toon_material("trunk", H("#d29a2e"), dark=0.5),
            "chrome": materials.chrome_material(),
            "amber": materials.emissive_material("amber", H("#ffb347")),
            "frame": materials.toon_material("frame", H("#121214")),
            "red": materials.toon_material("red", H("#d1303f"))}
    objs = build(mats)
    scene.add_key_light(rot_deg=(50, 0, -35), energy=3.0)
    cam = camera_rig.camera_rig(ortho_scale=w / ppm, pitch_deg=pitch, distance=40.0,
                                target_z=(h / 2 - 2) / ppm / math.cos(math.radians(pitch)) + tz_extra)
    cam.data.sensor_fit = "HORIZONTAL"
    bpy.context.view_layer.update()
    glow_objs = render.emissive_objects(objs)
    others = [o for o in objs if o not in glow_objs]
    render.set_layer(visible=objs)
    img = pixelize.pixelize(render.render_rgba(TMP, w * SS, h * SS), SS, COLORS, OUTLINE if outline else None)
    export.save_png(img, os.path.join(out_dir or SPR, f"{name}.png"))
    has_glow = False
    if glow and glow_objs:
        render.set_layer(visible=glow_objs, holdout=others)
        g = pixelize.pixelize(render.render_rgba(TMP, w * SS, h * SS), SS, COLORS, None)
        export.save_png(g, os.path.join(out_dir or SPR, f"{name}_glow.png"))
        has_glow = True
    ax, ay = camera_rig.anchor_pixel(w, h, (0, 0, 0))
    export.save_meta(os.path.join(out_dir or SPR, f"{name}.json"), id=name, size=[w, h], anchor=[ax, ay],
                     ppm=ppm, glow=has_glow)
    SHEET.append((name, img))
    return img


# ------------------------------------------------------------------ objetos

def build_lamp(m):
    b = shapes.box
    o = [b("pole", (0.18, 0.18, 7.0), (0.9, 0, 0), m["gray"]),
         b("base", (0.4, 0.4, 0.4), (0.9, 0, 0), m["dark"]),
         b("arm", (1.6, 0.14, 0.14), (0.15, 0, 6.8), m["gray"]),
         b("head", (0.7, 0.3, 0.16), (-0.5, 0, 6.65), m["frame"]),
         b("lamp", (0.55, 0.22, 0.08), (-0.5, 0, 6.58), m["amber"])]
    return o


def build_sign(m):
    b = shapes.box
    o = [b("post_l", (0.14, 0.14, 4.6), (-1.6, 0, 0), m["gray"]),
         b("post_r", (0.14, 0.14, 4.6), (1.6, 0, 0), m["gray"]),
         b("panel", (4.2, 0.1, 2.0), (0, 0, 3.0), m["green"]),
         b("border", (4.3, 0.08, 2.1), (0, 0.02, 2.95), m["white"])]
    for i, (x, w_) in enumerate(((-1.2, 1.2), (0.3, 0.8), (1.3, 0.5))):
        o.append(b(f"line{i}", (w_, 0.12, 0.2), (x, -0.06, 4.2 - 0.0 - i * 0.0), m["white"]))
    o.append(b("arrow", (2.4, 0.12, 0.16), (0, -0.06, 3.5), m["white"]))
    return o


def build_tree(m):
    b = shapes.box
    o = [b("trunk", (0.5, 0.5, 1.6), (0, 0, 0), m["trunk"])]
    for i, (w_, z) in enumerate(((3.2, 1.2), (2.4, 2.4), (1.6, 3.5))):
        o.append(b(f"leaf{i}", (w_, w_, 1.3), (0, 0, z), m["leaf"], bevel=0.12))
    return o


def build_guardrail(m):
    b = shapes.box
    o = []
    for i in range(5):
        o.append(b(f"post{i}", (0.12, 0.12, 0.8), (-2.0 + i, 0, 0), m["gray"]))
    o.append(b("rail", (4.2, 0.1, 0.3), (0, -0.06, 0.45), m["chrome"]))
    o.append(b("rail2", (4.2, 0.1, 0.14), (0, -0.06, 0.2), m["chrome"]))
    return o


# ------------------------------------------------------------------ skyline (Blender, periódico por espelhamento)

def build_skyline(seed, count, hmin, hmax, wmin, wmax, base, win_on):
    def build(m):
        rng = random.Random(seed)
        mat_b = materials.toon_material(f"b{seed}", H(base), dark=0.7, light=0.2)
        win = materials.emissive_material(f"w{seed}", H(win_on))
        objs = []
        total = 0.0
        half = []
        x = 0.0
        while len(half) < count:
            wd, hg = rng.uniform(wmin, wmax), rng.uniform(hmin, hmax)
            half.append((x + wd / 2, wd, hg))
            x += wd + rng.uniform(0, 1.5)
        span = x
        allb = half + [(2 * span - cx, wd, hg) for cx, wd, hg in reversed(half)]
        for i, (cx, wd, hg) in enumerate(allb):
            objs.append(shapes.box(f"bld{i}", (wd, 3.0, hg), (cx - span, 0, 0), mat_b))
            nx, nz = max(int(wd / 2.2), 1), max(int(hg / 2.6), 1)
            for ix in range(nx):
                for iz in range(nz):
                    if rng.random() < 0.45:
                        objs.append(shapes.box(f"w{i}_{ix}_{iz}", (0.9, 0.1, 1.0),
                                               (cx - span - wd / 2 + (ix + 0.5) * wd / nx, -1.55, 0.9 + iz * 2.6), win))
        return objs
    return build


def main():
    bg_sky = make_sky()
    export.save_png(bg_sky, os.path.join(BG, "sky.png"))
    mnt = make_mountains()
    export.save_png(mnt, os.path.join(BG, "mountains.png"))
    SHEET.append(("sky", bg_sky[:, :240]))
    SHEET.append(("mountains", mnt[:, :240]))

    render_object("lamp_post", build_lamp, 56, 128, 16.0)
    render_object("sign_green", build_sign, 112, 120, 22.0)
    render_object("tree", build_tree, 80, 90, 20.0)
    render_object("guardrail", build_guardrail, 112, 36, 24.0)

    # skylines (largura repetível: construídas simétricas, largura total = 2 x span)
    render_object("city_far", build_skyline(3, 18, 8, 22, 5, 11, "#2b2757", "#8af4ff"), 960, 64, 3.0,
                  out_dir=BG, outline=False, glow=False)
    render_object("city_near", build_skyline(8, 14, 10, 26, 7, 14, "#3c3a73", "#fff35c"), 960, 88, 3.0,
                  out_dir=BG, outline=True, glow=False)
    sheet = [(n, a[:, :240]) if a.shape[1] > 300 else (n, a) for n, a in SHEET]
    export.contact_sheet(sheet, os.path.join(REN, "contact_sheet.png"), cols=4, zoom=3)
    if os.path.exists(TMP):
        os.remove(TMP)
    print("OK build_roadside_test")


main()
