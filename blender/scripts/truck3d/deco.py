"""Decoração Dekotora do caminhão base (V7), comum a todas as cabines e baús e montada DEPOIS da variante
(sabe o comprimento final do baú):

- fileiras densas de luzes de marcação: borda de cima e trilho de baixo das laterais do baú, moldura da traseira;
- andon (painel luminoso com kanji): na frente do teto do baú, virado para a frente, e no alto da traseira;
- mural nas laterais do baú: placa fina com material "mural" (UV 0..1 por lado). O jogo troca a textura pelo
  PNG em game/assets/vehicles/dekotora/murals/mural_side.png (arte de pessoa ou de IA de imagem).

Nada aqui ocupa os pontos de montagem das peças compráveis (saias, guarnições, painéis, ornamentos).
"""
import math
import os

import numpy as np

from lib import mesh3d as M
from lib import pbr, tex

from .dims import BODY_TOP, BODY_W

W2 = BODY_W / 2
FONT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "game", "assets", "fonts", "NotoSansJP.ttf"))
FRONT_ANDON = "銀河丸"          # "Ginga-maru": nome do caminhão no andon da frente (a fonte variável carrega fina: tamanho ~3x)
REAR_ANDON = "街道爆走"          # "Kaidō Bakusō": o nome do jogo na traseira
LAMP = 0.075                      # lado da lâmpada de marcação (m): ~1 px a 30 m de distância na tela do celular


def mural_material():
    arr = tex.mural_geometric()
    img = tex._image("tex_mural", arr[::-1])                     # Blender guarda a linha 0 embaixo
    return pbr.textured("mural", img, 0.15, 0.35, coat=0.6, coat_rough=0.05)


def build_deco(m, add, body_l: float, cab_top: float, cab_front=None, mural=None):
    """`body_l` = comprimento final do baú (traseira em Y=0); `cab_top` = altura do teto da cabine;
    `cab_front` = (Y da frente da cabine, altura da base do para-brisa)."""
    lamps = (m["lamp_amber"], m["lamp_yellow"])
    # --- laterais: fileira de cima (alternando âmbar/amarelo) e de baixo (âmbar), sob os trilhos cromados
    for sx in (-1, 1):
        x = sx * (W2 + 0.035)
        n = int((body_l - 0.3) / 0.32)
        for i in range(n + 1):
            y = 0.15 + i * (body_l - 0.3) / n
            add(M.box(f"mk_top_{sx}_{i}", (0.03, LAMP, LAMP), (x, y, 3.0), lamps[i % 2], bevel=0.0, seg=1))
            if i % 2 == 0:
                add(M.box(f"mk_low_{sx}_{i}", (0.03, LAMP, LAMP), (x, y, 1.21), m["lamp_amber"], bevel=0.0, seg=1))
    # --- traseira: moldura de luzes (colunas nos cantos e linha no alto), vermelho/âmbar alternados
    for sx in (-1, 1):
        for k in range(7):
            z = 1.35 + k * 0.27
            add(M.box(f"mk_rear_v_{sx}_{k}", (LAMP, 0.03, LAMP), (sx * (W2 - 0.12), -0.11, z),
                      m["lamp_red"] if k % 2 == 0 else m["lamp_amber"], bevel=0.0, seg=1))
    for k in range(9):
        x = -1.0 + k * 0.25
        add(M.box(f"mk_rear_h_{k}", (LAMP, 0.03, LAMP), (x, -0.11, 3.02), m["lamp_red"] if k % 2 == 0 else m["lamp_amber"], bevel=0.0, seg=1))
    # --- frente da cabine: fileira de luzes logo abaixo do para-brisa ("sobrancelha")
    if cab_front:
        yf, wz0 = cab_front[:2]
        surf = cab_front[2] if len(cab_front) > 2 else None       # (x, z) -> (ponto, normal) na casca curva
        for k in range(13):
            x = -1.02 + k * 0.17
            z = wz0 - 0.15
            if surf is None:
                add(M.box(f"mk_cab_{k}", (LAMP, 0.03, LAMP), (x, yf + 0.03, z), lamps[k % 2], bevel=0.0, seg=1))
                continue
            p, n = surf(x, z)
            p = p + n * 0.012
            add(M.box(f"mk_cab_{k}", (LAMP, 0.03, LAMP), tuple(p), lamps[k % 2], bevel=0.0, seg=1,
                      rot=(0, 0, -math.degrees(math.atan2(n.x, n.y)))))
    # --- andons
    z0 = max(BODY_TOP + 0.08, cab_top + 0.04)                     # a frente aparece por cima de qualquer cabine
    _andon(m, add, "andon_f", body_l - 0.25, z0, FRONT_ANDON, front=True)
    if z0 > BODY_TOP + 0.1:
        for sx in (-1, 1):                                          # pés do andon alto
            add(M.box(f"andon_f_leg_{sx}", (0.06, 0.06, z0 - BODY_TOP), (sx * 0.9, body_l - 0.25, (z0 + BODY_TOP) / 2), m["chrome"], bevel=0.0, seg=1))
    _andon(m, add, "andon_r", 0.12, BODY_TOP + 0.06, REAR_ANDON, front=False)
    # --- murais
    mat = mural or mural_material()
    for sx in (-1, 1):
        o = M.box(f"mural_{sx}", (0.01, body_l - 0.7, 1.62), (sx * (W2 + 0.014), body_l / 2, 2.175), mat, bevel=0.0, seg=1)
        M.uv_planar(o)
        if sx < 0:                                                  # lado esquerdo: espelha para ler igual
            uvl = o.data.uv_layers.active
            for d in uvl.data:
                d.uv = (1.0 - d.uv[0], d.uv[1])
        add(o)


def _andon(m, add, name, y, z0, text, front: bool):
    """Caixa cromada com painel vermelho aceso e kanji âmbar; `front` = lê de frente (senão, de trás)."""
    w, h = 2.05, 0.5
    face = 1 if front else -1
    zc = z0 + h / 2
    add(M.box(name + "_frame", (w + 0.1, 0.12, h + 0.1), (0, y, zc), m["chrome"], bevel=0.02, seg=1))
    add(M.box(name + "_panel", (w, 0.02, h), (0, y + face * 0.065, zc), m["andon_panel"], bevel=0.0, seg=1))
    t = M.text3d(name + "_kanji", text, 1.15, (0, y + face * 0.085, zc), m["lamp_amber"], font_path=FONT,
                 extrude=0.008, rot=(90, 0, 180) if front else (90, 0, 0), resolution=4)
    M.apply_transforms([t])
    xs = [v.co.x for v in t.data.vertices]
    if xs:                                                          # cabe no painel
        span = max(xs) - min(xs)
        if span > w * 0.9:
            k = w * 0.9 / span
            for v in t.data.vertices:
                v.co.x *= k
    add(t)
    for k in range(10):                                             # luzinhas rosa na borda de cima
        x = -w / 2 + 0.1 + k * (w - 0.2) / 9
        add(M.box(f"{name}_lamp_{k}", (LAMP, 0.03, LAMP), (x, y + face * 0.07, z0 + h + 0.09), m["lamp_pink"], bevel=0.0, seg=1))
