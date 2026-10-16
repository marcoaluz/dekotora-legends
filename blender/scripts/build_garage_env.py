"""Galpão industrial da garagem (fundo 3D da garagem e da tela inicial).

Uso: blender -b --factory-startup -P blender/scripts/build_garage_env.py -- [--out game/assets/scenery]
Saída: <out>/garage_hall.glb (+ prévia em blender/renders/garage_hall.png)

Convenções iguais ao caminhão: metros, +Y frente, Z cima. O caminhão fica no centro da plataforma giratória
em (0, 6) — no Godot isso é (0, 0, -6), o mesmo centro que o palco já usa. O galpão é grande (72 x 72 m) porque
a câmera orbital da garagem chega a ~33 m do caminhão e nunca pode atravessar a parede.
Poucos materiais, texturas pequenas e repetíveis (concreto, chapa ondulada, faixa zebrada) e nenhuma luz
exportada: a iluminação é feita no Godot (painéis de LED aqui são só emissivos, para refletir no cromo).
"""
import argparse
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, pbr, scene, tex  # noqa: E402

CX, CY = 0.0, 6.0            # centro da plataforma (= centro do caminhão)
HALF = 36.0                  # meia-largura do galpão
H = 14.0                     # pé-direito


def materials():
    return {
        "floor": pbr.textured("hall_floor", tex.concrete(), 0.05, 0.38),
        "wall": pbr.textured("hall_wall", tex.corrugated(), 0.55, 0.45),
        "hazard": pbr.textured("hall_hazard", tex.hazard(), 0.0, 0.6),
        "block": pbr.pbr("hall_block", "#4a4d55", 0.0, 0.85),
        "beam": pbr.pbr("hall_beam", "#2b3d6b", 0.45, 0.45),
        "roof": pbr.pbr("hall_roof", "#14161b", 0.2, 0.8),
        "turntable": pbr.pbr("hall_turntable", "#1a1d24", 0.65, 0.3),
        "trim": pbr.chrome("hall_trim"),
        "door": pbr.pbr("hall_door", "#8a8f99", 0.6, 0.4),
        "line": pbr.pbr("hall_line", "#d9a514", 0.0, 0.6),
        "red": pbr.pbr("hall_red", "#a81c26", 0.3, 0.35),
        "blue": pbr.pbr("hall_blue", "#1d3f8a", 0.3, 0.4),
        "rubber": pbr.rubber("hall_rubber"),
        "steel": pbr.brushed_steel("hall_steel"),
        "panel": pbr.emissive("hall_led_panel", "#eef3ff", 2.4),
        "pink": pbr.emissive("hall_neon_pink", "#ff2e88", 3.0),
        "cyan": pbr.emissive("hall_neon_cyan", "#21e6ff", 2.0),
        "window": pbr.emissive("hall_window", "#1b2a55", 0.6),
    }


def build(m):
    parts = []
    add = parts.append
    y0, y1 = CY - HALF, CY + HALF
    # piso + plataforma giratória com anel de LED
    add(M.box("floor", (2 * HALF, 2 * HALF, 0.2), (CX, CY, -0.1), m["floor"], bevel=0.0, seg=1))
    add(M.cylinder("turntable", 9.5, 0.1, (CX, CY, 0.05), m["turntable"], axis="Z", seg=72, bevel=0.03))
    add(M.torus("turntable_trim", 9.5, 0.05, (CX, CY, 0.1), m["trim"], axis="Z", seg=72, tube_seg=6))
    add(M.torus("turntable_led", 9.75, 0.06, (CX, CY, 0.03), m["pink"], axis="Z", seg=72, tube_seg=6))
    # faixas amarelas das baias e zebrado em frente aos portões
    for x in (-14.0, 14.0):
        add(M.box(f"bay_line_{x}", (0.18, 2 * HALF - 6, 0.01), (x, CY, 0.006), m["line"], bevel=0.0, seg=1))
    for x in (-11.0, 11.0):
        add(M.box(f"door_hazard_{x}", (9.0, 0.8, 0.012), (x, y0 + 3.2, 0.007), m["hazard"], bevel=0.0, seg=1))
    # paredes: barra de bloco embaixo + chapa ondulada em cima
    walls = [("N", (2 * HALF, 0.3), (CX, y1)), ("S", (2 * HALF, 0.3), (CX, y0)),
             ("E", (0.3, 2 * HALF), (CX + HALF, CY)), ("W", (0.3, 2 * HALF), (CX - HALF, CY))]
    for n, (sx, sy), (x, y) in walls:
        add(M.box(f"wall_{n}", (sx, sy, H - 1.5), (x, y, 1.5 + (H - 1.5) / 2), m["wall"], bevel=0.0, seg=1))
        add(M.box(f"wall_block_{n}", (sx + 0.1 if sx > 1 else 0.5, sy + 0.1 if sy > 1 else 0.5, 1.5), (x, y, 0.75), m["block"], bevel=0.0, seg=1))
    # janelas altas nas paredes laterais (noite lá fora)
    for x in (CX - HALF + 0.2, CX + HALF - 0.2):
        for k in range(6):
            y = y0 + 8 + k * 11
            add(M.box(f"window_{x}_{k}", (0.1, 7.0, 1.8), (x, y, 10.0), m["window"], bevel=0.0, seg=1))
    # pilares e treliças azuis
    for k in range(9):
        y = y0 + 0.5 + k * 9.0
        for x in (CX - HALF + 0.5, CX + HALF - 0.5):
            add(M.box(f"col_{x}_{k}", (0.5, 0.5, H), (x, y, H / 2), m["beam"], bevel=0.02, seg=1))
        add(M.box(f"truss_{k}", (2 * HALF, 0.35, 0.6), (CX, y, H - 1.2), m["beam"], bevel=0.02, seg=1))
    for k in range(9):
        x = CX - HALF + 0.5 + k * 9.0
        add(M.box(f"col_s_{k}", (0.5, 0.5, H), (x, y0 + 0.5, H / 2), m["beam"], bevel=0.02, seg=1))
    add(M.box("roof", (2 * HALF, 2 * HALF, 0.2), (CX, CY, H), m["roof"], bevel=0.0, seg=1))
    # painéis de LED pendurados (refletem no cromo)
    for i in range(-2, 3):
        for j in range(-2, 3):
            add(M.box(f"led_{i}_{j}", (5.0, 0.5, 0.12), (CX + i * 9.0, CY + j * 9.0, H - 2.5), m["panel"], bevel=0.02, seg=1))
    # parede do fundo (atrás do caminhão na vista padrão): 2 portões de enrolar + letreiro neon
    for x in (-11.0, 11.0):
        add(M.box(f"door_{x}", (8.0, 0.2, 7.0), (x, y0 + 0.3, 3.5), m["door"], bevel=0.0, seg=1))
        for z in range(14):
            add(M.box(f"door_rib_{x}_{z}", (8.0, 0.1, 0.06), (x, y0 + 0.45, 0.3 + z * 0.5), m["steel"], bevel=0.01, seg=1))
        add(M.box(f"door_frame_{x}", (8.6, 0.3, 0.35), (x, y0 + 0.45, 7.2), m["beam"], bevel=0.02, seg=1))
        add(M.box(f"door_led_{x}", (8.2, 0.08, 0.08), (x, y0 + 0.6, 7.45), m["pink"], bevel=0.01, seg=1))
    font = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "fonts", "Rajdhani-Bold.ttf")
    add(M.text3d("sign", "KAIDO GARAGE", 1.8, (0.0, y0 + 0.5, 10.0), m["pink"], font_path=font, extrude=0.05, rot=(90, 0, 180)))
    add(M.box("sign_back", (16.0, 0.15, 2.6), (0.0, y0 + 0.35, 10.0), m["roof"], bevel=0.02, seg=1))
    # oficina: armários de ferramentas, pilhas de pneus, tambores e bancada (parede oeste)
    xw = CX - HALF + 1.2
    for k in range(5):
        add(M.box(f"cabinet_{k}", (0.8, 1.6, 1.4), (xw, CY - 8 + k * 1.7, 0.7), m["red"], bevel=0.04))
        add(M.box(f"cabinet_top_{k}", (0.85, 1.65, 0.05), (xw, CY - 8 + k * 1.7, 1.42), m["steel"], bevel=0.01, seg=1))
    for s in range(3):
        for k in range(4):
            add(M.cylinder(f"tire_{s}_{k}", 0.55, 0.32, (xw + 0.4, CY + 8 + s * 1.3, 0.17 + k * 0.33), m["rubber"], axis="Z", seg=20, bevel=0.06))
    for k in range(4):
        add(M.cylinder(f"drum_{k}", 0.3, 0.9, (xw + (k % 2) * 0.7, CY + 13.5 + (k // 2) * 0.7, 0.45), m["blue"] if k % 2 else m["red"], axis="Z", seg=16, bevel=0.02))
    add(M.box("bench", (1.0, 4.0, 0.9), (xw, CY + 18, 0.45), m["steel"], bevel=0.03))
    add(M.box("bench_led", (0.05, 3.8, 0.05), (xw + 0.5, CY + 18, 0.9), m["cyan"], bevel=0.01, seg=1))
    return parts


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/scenery")
    args = ap.parse_args(argv)
    scene.reset_scene()
    m = materials()
    parts = build(m)
    M.apply_transforms(parts)
    for o in parts:
        mat = o.data.materials[0].name if o.data.materials else ""
        if mat == "hall_floor":
            M.uv_world(o, 4.0)
        elif mat == "hall_wall":
            M.uv_world(o, 1.6)
        elif mat == "hall_hazard":
            M.uv_planar(o)
    M.smooth(parts, 35.0)
    tris = M.count_tris(parts)
    merged = M.join_by_material(parts, prefix="hall_")
    root = bpy.data.objects.new("GarageHall", None)
    bpy.context.scene.collection.objects.link(root)
    for o in merged:
        o.parent = root
    glb = os.path.join(os.path.abspath(args.out), "garage_hall.glb")
    M.export_glb(glb, [root] + merged)
    print(f"triangulos: {tris}  objetos: {len(merged)}")
    print("OK build_garage_env ->", glb)


if __name__ == "__main__":
    main()
