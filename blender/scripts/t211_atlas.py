"""Atlas dos letreiros e painéis pintados das peças da oficina (T-211): 1024 x 512, 16 células de 256 x 128.

Células 0–11: letreiros de acrílico com NOMES PRONTOS (decisão 9 do Marco: lista, sem texto livre), fonte de pincel
Yuji Syuku (OFL, `blender/fonts/`). Células 12–15: painéis pintados feitos por código (ondas seigaiha, sakura,
raios do sol nascente, nuvens douradas). O jogo escolhe o nome mudando a UV (StandardMaterial3D.uv1_offset).
Determinístico. A ordem de SIGNS é a mesma de `game/scripts/truck/deco_style.gd` (SIGN_NAMES).
"""
from __future__ import annotations

import math
import os

import bpy
import numpy as np

from lib import mesh3d as M
from lib.palette import hex_to_rgb, lin

FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fonts", "YujiSyuku-Regular.ttf")
# (texto, fundo, tinta)
SIGNS = [
    ("銀河丸", "#fff1cf", "#c0182c"), ("一番星", "#f6f7fb", "#c0182c"), ("爆走丸", "#d61f36", "#fff6e8"),
    ("龍神丸", "#fff1cf", "#1d3f8a"), ("桜吹雪", "#ffc6dc", "#8a0f30"), ("天翔丸", "#bfe6ff", "#c0182c"),
    ("浪花節", "#ffd2e4", "#1d3f8a"), ("男一匹", "#fff1cf", "#c0182c"), ("夜桜", "#7d3cff", "#ffffff"),
    ("鳳凰丸", "#ff8fb8", "#7a0f24"), ("雷神丸", "#ffe0ea", "#d61f36"), ("唐獅子", "#2f6bff", "#ffffff"),
]
W_PX, H_PX, COLS, ROWS = 1024, 512, 4, 4


def _emit(name, hx):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = lin(hex_to_rgb(hx)) + (1.0,)
    nt.links.new(e.outputs[0], o.inputs[0])
    return m


def _art(cell: int, w: int, h: int) -> np.ndarray:
    """Painéis pintados por código (linha 0 = topo). sRGB 0..1."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = xx / w, yy / h
    if cell == 12:                                  # ondas seigaiha azuis
        img = np.zeros((h, w, 3)) + np.array(hex_to_rgb("#0d2a6b"))
        r = 30.0
        for row in range(-1, int(h / (r * 0.5)) + 2):
            cy = row * r * 0.5
            off = r if row % 2 else 0.0
            for col in range(-1, int(w / (2 * r)) + 2):
                cx = col * 2 * r + off
                d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
                above = yy <= cy
                for k, c in enumerate(("#ffffff", "#3fa9ff", "#ffffff", "#1d5fd6")):
                    ring = (d < r * (1 - k * 0.24)) & above
                    img[ring] = hex_to_rgb(c)
        return img
    if cell == 13:                                  # sakura sobre azul-noite
        img = np.zeros((h, w, 3)) + np.array(hex_to_rgb("#14123a")) * (0.7 + 0.3 * v[..., None])
        rng = np.random.default_rng(13)
        for _ in range(26):
            cx, cy, s = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(8, 18)
            for p in range(5):
                a = p * 2 * math.pi / 5
                px, py = cx + math.cos(a) * s * 0.55, cy + math.sin(a) * s * 0.55
                d = np.sqrt((xx - px) ** 2 + (yy - py) ** 2)
                img[d < s * 0.45] = hex_to_rgb("#ffb7d2")
            img[np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) < s * 0.18] = hex_to_rgb("#ffe35c")
        return img
    if cell == 14:                                  # raios do sol nascente
        a = np.arctan2(yy - h * 1.1, xx - w * 0.5)
        rays = (np.floor((a + math.pi) / (math.pi / 14)) % 2) == 0
        img = np.where(rays[..., None], np.array(hex_to_rgb("#e3122d")), np.array(hex_to_rgb("#fff4e0")))
        sun = np.sqrt((xx - w * 0.5) ** 2 + (yy - h * 1.1) ** 2) < h * 0.55
        img[sun] = hex_to_rgb("#ff2a2a")
        return img
    img = np.zeros((h, w, 3)) + np.array(hex_to_rgb("#101a4a"))     # 15: nuvens douradas
    for k, (cx, cy, r) in enumerate(((0.25, 0.6, 0.22), (0.62, 0.35, 0.28), (0.85, 0.75, 0.2), (0.45, 0.85, 0.16))):
        d = np.sqrt(((u - cx) * 2) ** 2 + (v - cy) ** 2)
        for j, c in enumerate(("#f0b83a", "#101a4a", "#f6d27a", "#101a4a")):
            img[(d < r * (1 - j * 0.22))] = hex_to_rgb(c)
    return img


def make(out_png: str) -> str:
    """Renderiza os letreiros (Eevee, câmera ortográfica) e pinta as células de arte por numpy."""
    from lib import scene
    sc = scene.reset_scene()
    sc.render.film_transparent = False
    sc.render.resolution_x, sc.render.resolution_y = W_PX, H_PX
    sc.world.color = (0, 0, 0)
    cw, ch = 1.0, 0.5
    for i, (txt, bg, ink) in enumerate(SIGNS):
        c, r = i % COLS, i // COLS
        cx, cy = -2.0 + cw * (c + 0.5), 1.0 - ch * (r + 0.5)
        M.box(f"bg_{i}", (cw * 0.995, ch * 0.99, 0.01), (cx, cy, 0), _emit(f"bg_{i}", bg), bevel=0.0)
        M.box(f"edge_{i}", (cw, ch, 0.005), (cx, cy, -0.01), _emit(f"edge_{i}", "#20242c"), bevel=0.0)
        t = M.text3d(f"t_{i}", txt, 0.3, (cx, cy, 0.02), _emit(f"ink_{i}", ink), font_path=FONT, extrude=0.0,
                     rot=(0, 0, 0), resolution=6, offset=0.0)
        M.apply_transforms([t])
        xs = [v.co.x for v in t.data.vertices]
        ys = [v.co.y for v in t.data.vertices]
        k = min(cw * 0.84 / (max(xs) - min(xs)), ch * 0.72 / (max(ys) - min(ys)))
        mx, my = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
        for vv in t.data.vertices:
            vv.co.x = cx + (vv.co.x - mx) * k
            vv.co.y = cy + (vv.co.y - my) * k
            vv.co.z = 0.02
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = 4.0
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    co.location = (0, 0, 5)
    sc.camera = co
    tmp = out_png + ".tmp.png"
    sc.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(tmp)
    img.colorspace_settings.name = "Non-Color"
    arr = np.array(img.pixels[:], dtype=np.float32).reshape(H_PX, W_PX, 4)[::-1].copy()     # linha 0 = topo
    bpy.data.images.remove(img)
    os.remove(tmp)
    cwp, chp = W_PX // COLS, H_PX // ROWS
    for cell in (12, 13, 14, 15):
        c, r = cell % COLS, cell // COLS
        arr[r * chp:(r + 1) * chp, c * cwp:(c + 1) * cwp, :3] = _art(cell, cwp, chp)
        arr[r * chp:(r + 1) * chp, c * cwp:(c + 1) * cwp, 3] = 1.0
    out = bpy.data.images.new("deck_signs", W_PX, H_PX, alpha=False)
    out.colorspace_settings.name = "Non-Color"
    out.pixels.foreach_set(np.clip(arr[::-1], 0, 1).ravel())
    out.filepath_raw = out_png
    out.file_format = "PNG"
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    out.save()
    print("[t211] atlas:", out_png)
    return out_png
