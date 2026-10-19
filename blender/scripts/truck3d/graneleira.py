"""Carroceria graneleira (T-145) no chassi do baú médio: piso, fueiros, trincos, lona e lanternas do modelo de terceiros
(`gran_src.py`) + o que é NOSSO: tampas com o mural, cabeceira "torii" (鳥居, a armação cromada atrás da cabine dos
Dekotora de carroceria aberta) com o andon da frente, armação traseira com o andon de trás, fileiras de luzes,
placa, abas de lama e neon sob o chassi, e os pontos de montagem das peças movidos para a carroceria aberta.

Tamanho: o MESMO do baú médio (8,2 m de carroceria, 2 eixos traseiros, 12 m na pista), esticado para a frente nas
cabines curta/jac como os baús. Mural: o PNG trocável do jogo (material "mural") repetido nas tampas (0,7 m de altura),
porque a carroceria aberta não tem a parede alta do baú.
"""
from __future__ import annotations

from lib import mesh3d as M

from . import gran_src
from .deco import FRONT_ANDON, LAMP, REAR_ANDON, _andon, cab_brow, mural_material
from .dims import BODY_W, BODY_Z0

HEAD_GAP = 0.2           # a cabeceira ocupa os últimos 0,2 m da carroceria (fica longe dos escapamentos)
POST_X = 1.2             # colunas da cabeceira e da armação traseira
W2 = BODY_W / 2


def build_graneleira(m, add, body_l: float, cab_top: float, cab_front=None, src=None) -> dict:
    """Monta a graneleira com frente em `body_l` e devolve {mounts: {nome: (x, y, z)}, tris_src, tarp_top}."""
    bed = round(body_l - HEAD_GAP, 3)
    info = gran_src.build(m, add, bed, BODY_Z0, src)
    wall_top, tarp_top = info["wall_top"], info["tarp_top"]
    z_wall0 = gran_src.height(1.39, BODY_Z0)                      # topo do piso = base das tampas
    _walls(m, add, bed, z_wall0, wall_top)
    _side_lights(m, add, bed, wall_top)
    z_top = max(cab_top + 0.04, tarp_top + 0.25)                  # a cabeceira aparece por cima da cabine
    _torii(m, add, bed, z_top)
    _rear_frame(m, add, tarp_top)
    _under(m, add)
    if cab_front:
        cab_brow(m, add, cab_front)
    mid = (wall_top + z_wall0) / 2
    mounts = {
        "MOUNT_BODY_ROOF": (0.0, bed / 2, tarp_top),
        "MOUNT_REAR_ROOF": (0.0, 0.0, tarp_top + 0.1),
        "MOUNT_REAR_PANEL": (0.0, 0.0, 2.0),
        "MOUNT_REAR_LAMPS": (0.0, 0.0, 1.5),
    }
    for n, y in (("MOUNT_SIDE_PANEL", 4.1), ("MOUNT_SIDE_TRIM", 1.2), ("MOUNT_SIDE_ORNAMENT", 5.0)):
        mounts[n + "_R"] = (W2, y, mid)
        mounts[n + "_L"] = (-W2, y, mid)
    return {"mounts": mounts, "tris_src": info["tris"], "tarp_top": tarp_top, "wall_top": wall_top}


def _walls(m, add, bed: float, z0: float, top: float) -> None:
    """Tampas laterais (mural repetido), tampa traseira e parede da frente pintadas, friso cromado em cima."""
    h = top - z0
    zc = (z0 + top) / 2
    mural = mural_material()
    reps = max(1, round(bed / (4.0 * h)))                         # mural 4:1 repetido, sem cortar no fim
    for sx in (-1, 1):
        o = M.box(f"gran_wall_{sx}", (0.04, bed - 0.04, h), (sx * (W2 - 0.02), bed / 2, zc), mural, bevel=0.0, seg=1)
        M.uv_planar(o)
        uvl = o.data.uv_layers.active
        for d in uvl.data:
            u = d.uv[0] if sx > 0 else 1.0 - d.uv[0]              # lado esquerdo: espelha para ler igual
            d.uv = (u * reps, d.uv[1])
        add(o)
        add(M.box(f"gran_wall_rail_{sx}", (0.07, bed, 0.05), (sx * (W2 + 0.005), bed / 2, top), m["chrome"], bevel=0.012, seg=1))
    for name, y in (("gran_gate", 0.02), ("gran_front_wall", bed - 0.02)):
        add(M.box(name, (BODY_W - 0.08, 0.04, h), (0, y, zc), m["paint_white_panel"], bevel=0.0, seg=1))
    add(M.box("gran_gate_rail", (BODY_W + 0.02, 0.07, 0.05), (0, 0.0, top), m["chrome"], bevel=0.012, seg=1))


def _side_lights(m, add, bed: float, top: float) -> None:
    """Fileira de cima (âmbar/amarelo, no friso) e de baixo (âmbar, na borda do piso), como nas laterais do baú."""
    lamps = (m["lamp_amber"], m["lamp_yellow"])
    n = int((bed - 0.3) / 0.32)
    for sx in (-1, 1):
        for i in range(n + 1):
            y = 0.15 + i * (bed - 0.3) / n
            add(M.box(f"gmk_top_{sx}_{i}", (0.03, LAMP, LAMP), (sx * (W2 + 0.055), y, top), lamps[i % 2], bevel=0.0, seg=1))
            if i % 2 == 0:
                add(M.box(f"gmk_low_{sx}_{i}", (0.03, LAMP, LAMP), (sx * (W2 + 0.035), y, BODY_Z0 + 0.05), m["lamp_amber"], bevel=0.0, seg=1))


def _torii(m, add, bed: float, z_top: float) -> None:
    """Cabeceira atrás da cabine: parede pintada até a lona, 2 colunas cromadas, viga dupla (kasagi + nuki) com
    luzes viradas para a frente e o andon da frente em cima."""
    y = bed + 0.07
    lamps = (m["lamp_amber"], m["lamp_yellow"])
    add(M.box("torii_panel", (2.3, 0.05, z_top - 0.2 - BODY_Z0), (0, bed + 0.03, (BODY_Z0 + z_top - 0.2) / 2), m["paint_white_panel"], bevel=0.0, seg=1))
    for sx in (-1, 1):
        add(M.box(f"torii_post_{sx}", (0.13, 0.13, z_top - BODY_Z0), (sx * POST_X, y, (BODY_Z0 + z_top) / 2), m["chrome"], bevel=0.02, seg=1))
        add(M.box(f"torii_kasagi_tip_{sx}", (0.22, 0.17, 0.08), (sx * 1.36, y, z_top + 0.17), m["chrome"], bevel=0.02, seg=1,
                  rot=(0, sx * -12, 0)))
        k = 0
        z = BODY_Z0 + 0.35
        while z < z_top - 0.3:                                     # luzes nas colunas
            add(M.box(f"torii_mk_{sx}_{k}", (LAMP, 0.03, LAMP), (sx * POST_X, y + 0.08, z), lamps[k % 2], bevel=0.0, seg=1))
            z += 0.26
            k += 1
    add(M.box("torii_kasagi", (2.62, 0.17, 0.12), (0, y, z_top + 0.1), m["chrome"], bevel=0.02, seg=1))
    add(M.box("torii_nuki", (2.4, 0.1, 0.09), (0, y, z_top - 0.32), m["chrome"], bevel=0.015, seg=1))
    for k in range(15):
        x = -1.26 + k * 0.18
        add(M.box(f"torii_mk_beam_{k}", (LAMP, 0.03, LAMP), (x, y + 0.1, z_top + 0.1), lamps[k % 2], bevel=0.0, seg=1))
        if 0 < k < 14:
            add(M.box(f"torii_mk_nuki_{k}", (LAMP, 0.03, LAMP), (x, y + 0.065, z_top - 0.32), m["lamp_pink"], bevel=0.0, seg=1))
    _andon(m, add, "andon_f", y, z_top + 0.2, FRONT_ANDON, front=True, w=2.05)


def _rear_frame(m, add, tarp_top: float) -> None:
    """Armação traseira: 2 colunas cromadas nos cantos, viga com luzes e o andon de trás em cima."""
    zb = tarp_top + 0.06
    for sx in (-1, 1):
        add(M.box(f"rear_frame_post_{sx}", (0.1, 0.1, zb - BODY_Z0), (sx * POST_X, -0.03, (BODY_Z0 + zb) / 2), m["chrome"], bevel=0.015, seg=1))
        for k in range(7):
            z = BODY_Z0 + 0.95 + k * (zb - BODY_Z0 - 1.05) / 6
            add(M.box(f"gmk_rear_v_{sx}_{k}", (LAMP, 0.03, LAMP), (sx * POST_X, -0.095, z),
                      m["lamp_red"] if k % 2 == 0 else m["lamp_amber"], bevel=0.0, seg=1))
    add(M.box("rear_frame_beam", (2.5, 0.1, 0.1), (0, -0.03, zb), m["chrome"], bevel=0.015, seg=1))
    for k in range(9):
        x = -1.0 + k * 0.25
        add(M.box(f"gmk_rear_h_{k}", (LAMP, 0.03, LAMP), (x, -0.095, zb), m["lamp_red"] if k % 2 == 0 else m["lamp_amber"], bevel=0.0, seg=1))
    _andon(m, add, "andon_r", -0.03, zb + 0.08, REAR_ANDON, front=False, w=2.05)


def _under(m, add) -> None:
    """Placa, abas de lama e neon sob o chassi (o para-choque e as lanternas vêm do modelo)."""
    add(M.box("plate", (0.5, 0.03, 0.22), (0, -0.06, 0.74), m["paint_white"], bevel=0.01, seg=1))
    for sx in (-1, 1):
        add(M.box(f"mudflap_{sx}", (0.5, 0.04, 0.5), (sx * 0.95, 0.45, 0.8), m["rubber"], bevel=0.01, seg=1))
        add(M.box(f"underglow_{sx}", (0.05, 10.0, 0.05), (sx * 0.98, 6.0, 0.36), m["lamp_cyan"], bevel=0.01, seg=1))
