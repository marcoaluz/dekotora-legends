"""Jipe Suzuki (Samurai/Gypsy) do trânsito (T-131/T-143), a partir de docs/Novos modelos/Carro/obj/obj.obj.

O OBJ é uma malha só (436 mil triângulos, 22 materiais, frente para +Y, chão em Z = 0, escala ~1,6x).
As classes saem do NOME do material (conferido numa folha com um material por vez em vermelho):
  - Car_Paint.009 (carroceria) e .010 (capô) = pintura trocável; .012 (capota rígida) = branco ("plate");
  - Car_Paint.011 / Material.009 (para-choques, para-lamas, molduras) = plástico preto;
  - Car_chrome.001 = as letras "SUZUKI" do capô: APAGADAS (a marca não vai para o jogo);
  - Steel_grinded / Material.033 / Material.035 (caixa interna, interior, freios) saem: ninguém vê e gastam triângulos.
Nenhuma das 50 texturas 4K do autor é usada (cores lisas do atlas do trânsito).
"""
from __future__ import annotations

import os

import bpy
import numpy as np

from . import traffic_kit as K

MAT_CLASS = {
    "Car_Paint.009": K.PAINT, "Car_Paint.010": K.PAINT, "Car_Paint.012": "plate", "Car_Paint.011": "plastic",
    "Material.009": "plastic", "Material.032": "plastic", "Material.036": "glass", "Material.037": "rim",
    "Car_plastic_dark.001": "grille", "Carlight_line_chrome_orange.001": "lamp_amber",
    "Carlight_shingle_chrome_white": "lamp_white", "Transparent_Glass": "lamp_white", "Glass_Simple.001": "lamp_amber",
    "Gold_Leaf.001": "chrome", "Metal_Black_Dixon.002": "rubber", "Procedural_Metal.001": "rim",
    "Red_car_lights_glass.001": "lamp_red", "Air_Duct_Rubber.002": "rubber",
}
MAT_DROP = ("Car_chrome.001", "Steel_grinded.001", "Material.033", "Material.035")


def import_jeep(path: str) -> list:
    if not os.path.isfile(path):
        raise SystemExit(f"original não encontrado: {path}")
    bpy.ops.wm.obj_import(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def _mat_of_faces(o) -> list:
    mi = np.zeros(len(o.data.polygons), np.int32)
    o.data.polygons.foreach_get("material_index", mi)
    names = [m.name if m else "" for m in o.data.materials]
    return [names[i] for i in mi]


def auto_axles(o, tire_mask, dims) -> list:
    """(y, z, raio) de cada eixo pelos pneus: o y é o meio das faces de pneu que tocam o chão (frente/trás);
    o raio sai da face de pneu mais alta sobre esse y."""
    L, W, H = dims
    ctr = K.face_data(o)[0]
    side = tire_mask & (np.abs(ctr[:, 0]) > W * 0.3)
    out = []
    for front in (False, True):
        half = side & ((ctr[:, 1] > L * 0.5) == front)
        ground = half & (ctr[:, 2] < 0.04)
        yc = float(np.median(ctr[ground, 1]))
        near = half & (np.abs(ctr[:, 1] - yc) < 0.03) & (ctr[:, 2] < H * 0.5)
        r = float(ctr[near, 2].max()) * 0.5
        out.append((yc, r, r))
    return out


def prep_jeep(spec, objs, dims, _to_final):
    L, W, H = dims
    o = K.join(objs, "body")
    mats = _mat_of_faces(o)
    drop = np.array([m in MAT_DROP for m in mats])
    K.delete_faces(o, drop)
    mats = [m for m, d in zip(mats, drop) if not d]
    cls = [MAT_CLASS.get(m, "grey") for m in mats]
    K.assign_classes(o, cls)
    tire = np.array([c == "rubber" for c in cls])
    axles = auto_axles(o, tire, dims)
    print(f"[{spec['tag']}] eixos (y, z, r): {[tuple(round(v, 3) for v in a) for a in axles]}")

    def is_wheel(P):
        if np.abs(P[:, 0]).min() < W * 0.5 * 0.4:
            return False
        return any(np.hypot(P[:, 1] - ya, P[:, 2] - za).max() <= r * 1.08 for ya, za, r in axles)

    small, wheel = K.part_masks(o, keep_min=0.03, inside=is_wheel)
    K.delete_faces(o, small)
    wheels = K.split_faces(o, wheel[~small], "wheels")
    print(f"[{spec['tag']}] rodas={int(wheel.sum())} faces, miúdas={int(small.sum())}")
    return [o], [wheels]
