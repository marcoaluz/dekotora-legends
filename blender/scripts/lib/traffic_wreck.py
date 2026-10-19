"""Carro batido do evento "acidente" (T-143): picape com a frente amassada, a partir de
docs/Novas Melhorias/Carro batido/model_download+(24).obj (fornecido pelo Marco, Royalty Free License (no AI)).

O OBJ é uma malha só, SEM materiais, UV ou normais (80 mil triângulos; comprimento no eixo X, frente em -X; escala
~1:2,4). A malha é refeita em voxels (cascas finas e triângulos tortos viravam espinhos na redução) e as classes saem
só da geometria, já no padrão do jogo (frente +Y, traseira em Y = 0, chão em Z = 0):
  - pneu/aro: faces dentro do cilindro de cada roda (eixos achados pelas faces que tocam o chão), na parte de fora;
  - interior: faces da cabine viradas para dentro (as janelas do arquivo são vãos abertos = vidro quebrado);
  - lanternas: faces da traseira viradas para trás na altura das lanternas, nos cantos;
  - fundo: faces viradas para baixo, embaixo da soleira; o resto é pintura (trocável no Godot);
  - um filtro de vizinhança (maioria) tira as manchinhas isoladas antes da redução.
Não há marca, texto nem placa no arquivo (conferido nas vistas). Parado no acidente: as rodas ficam no corpo
(sem nós "wheel_*"), 1 objeto e 2 materiais.
"""
from __future__ import annotations

import os
from collections import Counter

import bpy
import numpy as np

from . import traffic_kit as K

LAMP_Z = (0.55, 0.95)        # m: altura das lanternas traseiras
SILL_Z = 0.32                # m: abaixo disso, face virada para baixo = fundo (a soleira fica pintada)


def import_wreck(path: str) -> list:
    if not os.path.isfile(path):
        raise SystemExit(f"original não encontrado: {path}")
    bpy.ops.wm.obj_import(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def _remesh(o, voxel: float) -> None:
    """Refaz a malha em voxels de `voxel` m: a casca refeita reduz limpa."""
    md = o.modifiers.new("rm", "REMESH")
    md.mode = "VOXEL"
    md.voxel_size = voxel
    md.adaptivity = 0.0
    K.select_only([o])
    bpy.ops.object.modifier_apply(modifier=md.name)
    for p in o.data.polygons:
        p.use_smooth = True


def _smooth(o, iters: int) -> None:
    """Alisa o ruído miúdo da superfície (mantém o amassado grande): a redução fica sem lascas."""
    md = o.modifiers.new("sm", "SMOOTH")
    md.factor = 0.6
    md.iterations = iters
    K.select_only([o])
    bpy.ops.object.modifier_apply(modifier=md.name)


def _wheels(ctr, half_w: float, L: float) -> list:
    """(y, raio) de cada eixo: meio das faces de fora que tocam o chão (atrás e na frente); raio = altura mediana
    das faces de fora logo acima do eixo."""
    outer = np.abs(ctr[:, 0]) > half_w - 0.30
    out = []
    for front in (False, True):
        half = outer & ((ctr[:, 1] > L * 0.5) == front)
        g = half & (ctr[:, 2] < 0.05)
        y = float(np.median(ctr[g, 1]))
        top = ctr[half & (np.abs(ctr[:, 1] - y) < 0.04) & (ctr[:, 2] < 1.1), 2]
        r = float(np.clip(np.percentile(top, 50) if len(top) else 0.36, 0.30, 0.45))
        out.append((y, r))
    return out


def classify_base(o, dims, half_w, cab_y) -> np.ndarray:
    """Pintura, fundo e interior (as classes grandes, que passam pelo filtro de maioria)."""
    _L, _W, H = dims
    ctr, nrm, _area, _uv = K.face_data(o)
    x, y, z = ctr[:, 0], ctr[:, 1], ctr[:, 2]
    ax = np.abs(x)
    cls = np.array([K.PAINT] * len(ctr), dtype=object)
    cls[(nrm[:, 2] < -0.55) & (z < SILL_Z)] = "under"
    # interior da cabine (visto pelos vãos das janelas): faces viradas para o meio do carro ou para baixo
    cab = (y > cab_y[0]) & (y < cab_y[1]) & (z > H * 0.45) & (z < H - 0.06) & (ax < half_w - 0.10)
    inward = (nrm[:, 0] * np.sign(x) < -0.35) | (nrm[:, 2] < -0.5)
    cls[cab & inward] = "plastic"
    back = (y < 0.30) & (nrm[:, 1] < -0.55)
    cls[back & (z > 0.25) & (z < LAMP_Z[0] - 0.05)] = "plastic"        # para-choque traseiro
    return cls


def overlay_small(o, cls, half_w, wheels) -> np.ndarray:
    """Classes pequenas por cima (depois do filtro, para não sumirem): lanternas e rodas."""
    ctr, nrm, _area, _uv = K.face_data(o)
    x, y, z = ctr[:, 0], ctr[:, 1], ctr[:, 2]
    ax = np.abs(x)
    back = (y < 0.30) & (nrm[:, 1] < -0.55)
    cls[back & (z > LAMP_Z[0]) & (z < LAMP_Z[1]) & (ax > half_w - 0.30)] = "lamp_red"
    for yc, r in wheels:                     # cilindro em torno de cada eixo, na parte de fora da carroceria
        d = np.hypot(y - yc, z - r)
        inw = (d < r * 1.0) & (ax > half_w - 0.32)
        face_out = nrm[:, 0] * np.sign(x) > 0.5
        cls[inw] = "rubber"
        cls[inw & face_out & (d < r * 0.66)] = "rim_dark"
        cls[inw & face_out & (d < r * 0.44)] = "rim"
    return cls


def majority(o, cls: np.ndarray, passes: int = 2) -> np.ndarray:
    """Cada face fica com a classe mais comum entre ela e as vizinhas (tira manchinhas soltas)."""
    me = o.data
    n = len(me.polygons)
    ev = np.zeros(len(me.edges) * 2, np.int32)
    me.edges.foreach_get("vertices", ev)
    edge_faces: dict = {}
    for p in me.polygons:
        for ek in p.edge_keys:
            edge_faces.setdefault(ek, []).append(p.index)
    nb = [[] for _ in range(n)]
    for fs in edge_faces.values():
        for a in fs:
            for b in fs:
                if a != b:
                    nb[a].append(b)
    for _ in range(passes):
        new = cls.copy()
        for i in range(n):
            c = Counter(cls[j] for j in nb[i])
            c[cls[i]] += 1
            best, k = c.most_common(1)[0]
            if best != cls[i] and k >= 3:
                new[i] = best
        cls = new
    return cls


def prep_wreck(spec, objs, dims, _to_final):
    L, W, H = dims
    o = K.join(objs, "body")
    K.weld(o, 1e-5)
    small, _ = K.part_masks(o, keep_min=0.06)       # lascas soltas
    K.delete_faces(o, small)
    if spec.get("voxel"):
        _remesh(o, spec["voxel"])
    if spec.get("smooth"):
        _smooth(o, spec["smooth"])
    ctr = K.face_data(o)[0]
    half_w = float(np.abs(ctr[ctr[:, 2] < 0.8, 0]).max())      # meia largura sem os retrovisores
    wheels = _wheels(ctr, half_w, L)
    print(f"[{spec['tag']}] meia largura={half_w:.2f} rodas (y, r): {[(round(a, 2), round(b, 2)) for a, b in wheels]}")
    cab_y = (L * spec.get("cab_from", 0.40), L * spec.get("cab_to", 0.74))
    cls = overlay_small(o, majority(o, classify_base(o, dims, half_w, cab_y)), half_w, wheels)
    K.assign_classes(o, list(cls))
    print(f"[{spec['tag']}] classes: {dict(Counter(cls))}")
    return [o], []
