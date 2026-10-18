"""Cabine "americana" de bico longo (T-129): importa a cabine, o capô e a grade do Kenworth W990 (Sketchfab, Henry S,
Royalty Free confirmado pelo Marco em 2026-10-18) e leva para o quadro do jogo. O .glb original (80 MB, 2,2 milhões de
triângulos) NUNCA vai para o Git (`docs/Modelos Melhorados/` está no .gitignore); só a cabine reduzida e
re-texturizada entra no jogo.

O original olha para -Y, em metros, chão em z = 0: para-choque em y = -2,09, eixo dianteiro em y = -1,16 (pneu de raio
0,53, quase o nosso de 0,52), cabine de 2,43 m de largura. Escala 1,0 (as medidas já batem com o caminhão grande).
Fica só a cabine "dia" (corte logo atrás da porta, `CUT_SRC`): o dormitório, a carreta, o chassi, as rodas, o interior,
os escapamentos e o painel com o letreiro vão embora; o fundo aberto é fechado por `kw_cab._back_wall`.

Marcas apagadas: emblema da grade e os dois do capô (material "material", só emblemas), o "W990" da lateral e o
letreiro do protetor dos escapamentos (caixas em `EXCLUDE`).
Coordenada do jogo: metros, frente +Y, X = 0 no centro, chão Z = 0; giro de 180° em Z (sem espelhar).
"""
from __future__ import annotations

import os

import numpy as np

from lib import extract

DEFAULT_SRC = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "docs", "Modelos Melhorados",
                                            "kenworth_w990_truck.glb"))
SCALE = 1.0
CUT_SRC = 1.05            # costas da cabine "dia" no original (atrás da porta; o dormitório começa aqui)
FRONT_SRC = -2.09         # frente do para-choque
AXLE_SRC = -1.16          # eixo dianteiro
WHEEL_R = 0.53

# material do original -> NOSSO (pbr.truck_set) ou None (descarta)
MATS = {
    "carpaint-black_piano": "paint_white_panel", "chrome": "chrome", "chrome_bumpB": "chrome", "chromedark": "steel",
    "metal_black": "plastic", "plastic_rough_black": "plastic", "plastic_shiny_black": "plastic",
    "plastic_rough_grey": "plastic", "glass_clear": "glass", "glass_orange": "lamp_amber",
    "glass_orange_bumpA": "lamp_amber", "glass_red": "lamp_red", "light_white": "lamp_white",
    # descartados: emblemas ("material"), rodas, interior, carreta
    "material": None, "tire": None, "metal_rough_plus": None, "leather_black": None, "fabricB": None, "fabricD": None,
    "material_19": None, "material_20": None, "blue": None, "roof": None, "tarpaulin_bump": None, "texReflect": None,
    "mudflaps": None,
}
BOXES = [((-1.5, -2.25, 0.12), (1.5, CUT_SRC + 0.3, 3.6))]
EXCLUDE = [
    ((0.95, 0.6, 0.5), (1.6, 1.9, 4.3)), ((-1.6, 0.6, 0.5), (-0.95, 1.9, 4.3)),        # escapamentos + letreiro
    ((1.05, -0.7, 0.95), (1.4, 0.35, 1.35)), ((-1.4, -0.7, 0.95), (-1.05, 0.35, 1.35)),   # "W990" (ilhas pequenas)
    ((0.8, -1.8, 0.0), (1.45, -0.5, 1.1)), ((-1.45, -1.8, 0.0), (-0.8, -0.5, 1.1)),       # cubos/porcas da roda
]


def _island_mat(ours, c, d):
    """Escolhas por ilha: farol aceso, para-brisa com textura, chassi/motor e interior fora."""
    ax, y, z = abs(float(c[0])), float(c[1]), float(c[2])
    size = float(d.max())
    if ours == "glass":
        if y < -1.6:
            return "lamp_white" if ax > 0.6 else None              # lente do farol = farol aceso
        if y < -0.9:
            return "lamp_amber"                                     # luzes de posição do capô
        return "glass_wind" if ax < 0.75 and z > 1.85 else "glass"
    if ours == "plastic":
        if ax < 0.97 and -0.15 < y < CUT_SRC + 0.2 and 1.15 < z < 3.0 and size < 2.2:
            return None                                             # painel e forros do interior (atrás do vidro opaco)
        if z < 0.75 and y > -1.85 and size > 0.25:
            return None                                             # chassi, motor e suspensão (o chassi é o nosso)
    if ours == "plastic" and size > 2.6:
        return None                                                 # longarinas do original
    return ours


def load(src: str | None, y_back: float) -> list:
    """Ilhas da cabine já no quadro do jogo (costas da cabine em `y_back`), um objeto por material nosso
    (`o["our_mat"]`). Faces atrás do corte são apagadas (o fundo é fechado depois)."""
    path = os.path.abspath(src or DEFAULT_SRC)
    if not os.path.isfile(path):
        raise SystemExit(f"ERRO cabine americana: arquivo do Kenworth W990 nao encontrado: {path}\n"
                         "  Coloque o kenworth_w990_truck.glb (Sketchfab, Royalty Free) em docs/Modelos Melhorados/ "
                         "ou passe --cab-src CAMINHO.")
    import bpy
    before = set(bpy.data.objects)
    snap = {"im": set(bpy.data.images), "mt": set(bpy.data.materials), "me": set(bpy.data.meshes)}
    srcs = extract.load_glb(path)
    objs = extract.take(srcs, BOXES, MATS, "kw", max_size=5.5, exclude=EXCLUDE, island_mat=_island_mat)
    for o in [o for o in bpy.data.objects if o not in before and o not in objs]:
        bpy.data.objects.remove(o, do_unlink=True)
    keep = {o.data for o in objs}
    for me in [x for x in bpy.data.meshes if x not in snap["me"] and x not in keep and x.users == 0]:
        bpy.data.meshes.remove(me)
    for mt in [x for x in bpy.data.materials if x not in snap["mt"]]:
        bpy.data.materials.remove(mt)
    for im in [x for x in bpy.data.images if x not in snap["im"]]:
        bpy.data.images.remove(im)
    extract.clip(objs, (-9, -9, -1), (9, CUT_SRC, 9))
    objs = [o for o in objs if len(o.data.polygons) > 0]
    for o in objs:                                   # original -> jogo: giro de 180° (frente +Y) e costas em y_back
        me = o.data
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        co[:, 0] = -co[:, 0] * SCALE
        co[:, 1] = y_back + (CUT_SRC - co[:, 1]) * SCALE
        co[:, 2] = co[:, 2] * SCALE
        me.vertices.foreach_set("co", co.ravel())
        me.update()
    return objs


def y_game(y_src: float, y_back: float) -> float:
    return y_back + (CUT_SRC - y_src) * SCALE
