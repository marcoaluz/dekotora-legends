"""Caminhão leve "Canter" e cabine curta (T-125): importa a malha de terceiros (JAC 1045 Truck, CGTrader, Royalty
Free) já na escala e na orientação do jogo. O arquivo original NUNCA vai para o Git (`docs/Modelos/Modelos Melhorados/`
está no .gitignore); só o .glb reduzido e re-texturizado entra no jogo.

O .blend do JAC está em metros, frente em +Y (para-choque em y = -0,06), traseira do chassi em y = -9,36, chão em
z = 0, mas ~1,4x maior que um caminhão leve de verdade (cabine com 2,85 m de largura, pneu com 1,21 m).

`Frame` = escala + onde a frente do para-choque fica no jogo. Dois usos:
  CANTER: escala 0,74 (cabine 2,1 m, pneu 0,9 m, entre-eixos 3,95 m), traseira do chassi em y = 0 (frente em 6,88);
  CURTA:  escala 0,84 (cabine 2,4 m = CAB_W, pneu 1,02 m): a frente cai em CAB_Y1 = 11,5 e o eixo dianteiro do JAC
          cai exatamente no nosso (FRONT_AXLE_Y = 10,2), então a cabine serve nos baús leve/médio/longo.
  JAC:    (T-129) escala 0,95 na altura/comprimento e 0,88 na largura (cabine 2,5 m = largura do baú, teto 2,95 m,
          quase o do baú): a cabine "grande" para os baús leve/médio/longo, com os escapamentos atrás dela.
          O eixo dianteiro do JAC cai de novo no nosso (frente em 11,67).
Coordenada do jogo: metros, frente +Y, X = 0 no centro, chão Z = 0. Cada peça vira um objeto sem pais, com a malha
já transformada e sem materiais (o classificador `jac_parts` põe os nossos).
"""
from __future__ import annotations

import os
from dataclasses import dataclass

import bpy
import numpy as np

_DOCS = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "docs"))
_NOVO = os.path.join(_DOCS, "Modelos", "Modelos Melhorados")   # T-162: pasta nova; volta para a antiga se não existir
DEFAULT_SRC = os.path.join(_NOVO if os.path.isdir(_NOVO) else os.path.join(_DOCS, "Modelos Melhorados"),
                           "JAC+1045+Truck.blend")
Y_FRONT_SRC = -0.059     # frente do para-choque no original
Y_REAR_SRC = -9.36       # traseira do chassi no original (barra das lanternas)
# peças repetidas no original (mesma malha duas vezes, uma por cima da outra)
DUPLICATES = ("suspensi_n.002", "suspensi_n.003", "Focos_Enciende_0_0", "Base_limpoiapara.001")


@dataclass(frozen=True)
class Frame:
    scale: float
    y_front: float           # y do jogo onde fica a frente do para-choque
    sx: float = 0.0          # escala da largura (0 = a mesma de `scale`)

    @property
    def kx(self) -> float:
        return self.sx or self.scale

    def y(self, y_src: float) -> float:
        return self.y_front + (y_src - Y_FRONT_SRC) * self.scale

    def pt(self, p74) -> tuple:
        """Ponto medido no quadro do CANTER (escala 0,74, traseira em 0) -> este quadro."""
        k = self.scale / CANTER.scale
        return (p74[0] * self.kx / CANTER.scale, self.y_front + (p74[1] - CANTER.y_front) * k, p74[2] * k)


CANTER = Frame(0.74, (Y_FRONT_SRC - Y_REAR_SRC) * 0.74)
CURTA = Frame(0.84, 11.5)
AXLE_SRC = (11.5 - 10.2) / 0.84          # eixo dianteiro do JAC atrás da frente do para-choque (m no original)
JAC = Frame(0.95, round(10.2 + AXLE_SRC * 0.95, 3), sx=0.88)


def load(frame: Frame, path: str | None = None, keep=None) -> dict:
    """Anexa as malhas do .blend e leva cada uma ao `frame`. `keep(nome)` filtra as peças. Devolve {nome: objeto}."""
    path = os.path.abspath(path or DEFAULT_SRC)
    if not os.path.isfile(path):
        raise SystemExit(f"ERRO Canter: arquivo do JAC 1045 nao encontrado: {path}\n"
                         "  Coloque o JAC+1045+Truck.blend (CGTrader, Royalty Free) nessa pasta ou passe --jac-src CAMINHO.")
    before = {"m": set(bpy.data.materials), "i": set(bpy.data.images), "me": set(bpy.data.meshes)}
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = list(src.objects)
    tmp = bpy.data.collections.new("jac_tmp")       # na cena só para o Blender calcular matrix_world (pais, rotação)
    bpy.context.scene.collection.children.link(tmp)
    for o in dst.objects:
        if o is not None:
            tmp.objects.link(o)
    bpy.context.view_layer.update()
    out = {}
    for o in sorted((o for o in dst.objects if o is not None), key=lambda o: o.name):
        if o.type != "MESH" or o.name in DUPLICATES or (keep is not None and not keep(o.name)):
            continue
        mw = np.array(o.matrix_world)
        me = o.data.copy()
        n = len(me.vertices)
        co = np.empty(n * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        co = (np.c_[co, np.ones(n)] @ mw.T)[:, :3]
        co[:, 1] = frame.y_front + (co[:, 1] - Y_FRONT_SRC) * frame.scale
        co[:, 0] *= frame.kx
        co[:, 2] *= frame.scale
        me.vertices.foreach_set("co", co.ravel())
        if np.linalg.det(mw[:3, :3]) < 0:            # espelhado no original: normais para fora de novo
            me.flip_normals()
        me.materials.clear()
        me.update()
        name = "jac_" + o.name.replace(".", "_")
        ob = bpy.data.objects.new(name, me)
        me.name = name
        bpy.context.scene.collection.objects.link(ob)
        out[o.name] = ob
    for o in dst.objects:                              # os originais anexados não ficam no arquivo
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(tmp)
    for me in [x for x in bpy.data.meshes if x not in before["me"] and x.users == 0]:
        bpy.data.meshes.remove(me)
    for mat in [x for x in bpy.data.materials if x not in before["m"] and x.users == 0]:
        bpy.data.materials.remove(mat)
    for img in [x for x in bpy.data.images if x not in before["i"] and x.users == 0]:
        bpy.data.images.remove(img)
    return out
