"""Biblioteca de acessórios Dekotora 3D (32 peças nossas em 4 categorias + 10 de modelos de terceiros, `thirdparty`,
+ amostras "deluxe" com acabamento fino, `deluxe`, T-172).

Cada módulo (front, lighting, sides, rear) expõe `ACCESSORIES`: lista de dicts
    id        identificador estável (snake_case), vira o nome do arquivo .glb
    name      nome legível (pt-BR)
    category  front | lighting | sides | rear   (pasta de saída)
    mount     nome do ponto de montagem do caminhão (MOUNT_*), origem local da peça
    mirror    True se a mesma peça serve para o lado oposto (Godot: scale.x = -1)
    build     função build(m) -> lista de objetos Blender, com a origem do mundo = ponto de montagem
    materials variantes de material permitidas por "slot" (catalog.json)
Convenção do modelo: +Y = frente do caminhão, +X = direita, +Z = cima, metros.
"""
from . import deluxe, front, lighting, rear, sides, thirdparty  # noqa: F401

ALL = front.ACCESSORIES + lighting.ACCESSORIES + sides.ACCESSORIES + rear.ACCESSORIES + thirdparty.ACCESSORIES + deluxe.ACCESSORIES
THIRDPARTY = [a["id"] for a in thirdparty.ACCESSORIES]          # T-126: tiradas de modelos de terceiros
DELUXE = [a["id"] for a in deluxe.ACCESSORIES]                  # T-172: amostras com acabamento fino
BY_ID = {a["id"]: a for a in ALL}
CATEGORIES = ("front", "lighting", "sides", "rear")
