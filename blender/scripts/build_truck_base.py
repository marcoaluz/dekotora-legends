"""Caminhão base: cabine plana japonesa GENÉRICA (sem marca) + baú. Importável (build_base) e executável.

Convenções: metros, frente = +Y, chão Z=0, traseira do baú em Y=0, centro em X=0.
Dimensões: ~12 m x 2,5 m x 3,2 m. Os scripts de peças importam as constantes daqui.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import materials, shapes  # noqa: E402
from lib.palette import hex_to_rgb as H  # noqa: E402

# --- medidas (m) usadas também pelas peças
BODY_W, BODY_L, BODY_Z0, BODY_TOP = 2.5, 8.2, 1.1, 3.2     # baú
CAB_W, CAB_Y0, CAB_Y1, CAB_Z0, CAB_TOP = 2.4, 8.45, 11.5, 0.9, 3.35
TRUCK_LEN = 12.0
CENTER = (0.0, 6.0, 1.6)                                   # ponto de mira e pivô de giro
REAR_AXLES_Y = (1.5, 3.0)
FRONT_AXLE_Y = 10.2


def make_materials() -> dict:
    return {
        "white": materials.toon_material("white", H("#dfe6f0")),
        "stripe": materials.toon_material("stripe", H("#ff2e88")),
        "glass": materials.toon_material("glass", H("#1e1b3d"), dark=0.8, light=0.5),
        "rubber": materials.toon_material("rubber", H("#26262b")),
        "frame": materials.toon_material("frame", H("#121214")),
        "gray": materials.toon_material("gray", H("#4a5262")),
        "red": materials.toon_material("red", H("#d1303f")),
        "chrome": materials.chrome_material(),
        "tail": materials.emissive_material("tail", H("#ff4d4d")),
        "head": materials.emissive_material("head", H("#ffe9c2")),
    }


def build_base(m: dict) -> list:
    """Cria o caminhão base. Devolve a lista de objetos (nomes começam com 'base_')."""
    b = shapes.box
    o = []
    add = o.append
    W2 = BODY_W / 2

    # chassi e baú
    add(b("base_chassis", (2.0, 11.6, 0.3), (0, 6.0, 0.55), m["frame"]))
    add(b("base_body", (BODY_W, BODY_L, BODY_TOP - BODY_Z0), (0, BODY_L / 2, BODY_Z0), m["white"], bevel=0.05))
    add(b("base_body_stripe", (BODY_W + 0.02, BODY_L + 0.02, 0.24), (0, BODY_L / 2, 1.75), m["stripe"]))
    # porta traseira: junta central, dobradiças, trincos
    add(b("base_door_seam", (0.05, 0.05, 2.05), (0, -0.02, BODY_Z0 + 0.02), m["frame"]))
    add(b("base_door_top", (BODY_W - 0.1, 0.05, 0.05), (0, -0.02, BODY_TOP - 0.15), m["frame"]))
    for sx in (-1, 1):
        for z in (1.45, 2.3, 3.0):
            add(b(f"base_hinge_{sx}_{z}", (0.12, 0.1, 0.22), (sx * (W2 - 0.04), -0.04, z), m["gray"]))
        add(b(f"base_latch_{sx}", (0.06, 0.08, 1.9), (sx * 0.42, -0.04, BODY_Z0 + 0.1), m["chrome"]))
    # faixa refletiva (vermelho/branco) na base da traseira
    for i in range(10):
        x = -1.1 + i * 0.245
        add(b(f"base_refl_{i}", (0.24, 0.04, 0.12), (x, -0.02, BODY_Z0 + 0.02), m["red"] if i % 2 == 0 else m["white"]))
    # escada na porta, lado direito
    for x in (0.8, 1.12):
        add(b(f"base_ladder_rail_{x}", (0.05, 0.1, 2.0), (x, -0.1, BODY_Z0 + 0.05), m["chrome"]))
    for i in range(6):
        add(b(f"base_ladder_rung_{i}", (0.37, 0.05, 0.05), (0.96, -0.12, BODY_Z0 + 0.25 + i * 0.35), m["chrome"]))
    # lanternas traseiras (emissivas -> camada de brilho)
    for sx in (-1, 1):
        add(b(f"base_tail_{sx}", (0.3, 0.08, 0.4), (sx * 1.0, -0.04, 1.5), m["tail"]))
    # cabine
    add(b("base_cab", (CAB_W, CAB_Y1 - CAB_Y0, CAB_TOP - CAB_Z0), (0, (CAB_Y0 + CAB_Y1) / 2, CAB_Z0), m["white"], bevel=0.07))
    add(b("base_cab_stripe", (CAB_W + 0.02, CAB_Y1 - CAB_Y0 + 0.02, 0.24), (0, (CAB_Y0 + CAB_Y1) / 2, 1.75), m["stripe"]))
    add(b("base_windshield", (2.1, 0.06, 1.0), (0, CAB_Y1, 2.2), m["glass"]))
    for sx in (-1, 1):
        add(b(f"base_sidewin_{sx}", (0.06, 1.3, 0.8), (sx * CAB_W / 2, 10.0, 2.2), m["glass"]))
        add(b(f"base_mirror_{sx}", (0.1, 0.14, 0.55), (sx * (CAB_W / 2 + 0.2), 11.2, 2.2), m["frame"]))
        add(b(f"base_mirror_arm_{sx}", (0.22, 0.05, 0.05), (sx * (CAB_W / 2 + 0.08), 11.2, 2.65), m["gray"]))
        add(b(f"base_head_{sx}", (0.4, 0.06, 0.25), (sx * 0.9, CAB_Y1 + 0.02, 1.25), m["head"]))
    add(b("base_grille", (1.2, 0.06, 0.5), (0, CAB_Y1 + 0.02, 1.15), m["frame"]))
    add(b("base_cab_step", (2.3, 0.2, 0.3), (0, CAB_Y1 + 0.1, 0.62), m["rubber"]))
    # rodas: 2 eixos traseiros com pneus duplos, 1 eixo dianteiro
    for sx in (-1, 1):
        for y in REAR_AXLES_Y:
            for tx in (0.72, 1.06):
                add(shapes.cylinder_x(f"base_tire_r_{sx}_{y}_{tx}", 0.52, 0.3, (sx * tx, y, 0.52), m["rubber"]))
            add(shapes.cylinder_x(f"base_hub_r_{sx}_{y}", 0.25, 0.34, (sx * 1.06, y, 0.52), m["gray"]))
        add(shapes.cylinder_x(f"base_tire_f_{sx}", 0.5, 0.32, (sx * 1.0, FRONT_AXLE_Y, 0.5), m["rubber"]))
        add(shapes.cylinder_x(f"base_hub_f_{sx}", 0.24, 0.36, (sx * 1.0, FRONT_AXLE_Y, 0.5), m["gray"]))
        # para-lama sobre o conjunto traseiro e para-barro atrás
        add(b(f"base_fender_{sx}", (0.62, 2.2, 0.08), (sx * 1.02, 2.25, 1.1), m["frame"]))
        add(b(f"base_mudflap_{sx}", (0.5, 0.04, 0.5), (sx * 0.95, 0.5, 0.35), m["rubber"]))
    return o
