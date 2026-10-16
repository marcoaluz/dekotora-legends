"""Para-choque frontal em degraus cromados (visível nas laterais em curva)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import build_truck_base as T  # noqa: E402
from lib import materials, shapes  # noqa: E402
from lib.palette import hex_to_rgb as H  # noqa: E402

ID, SLOT, ZONE = "fb_chrome_steps", "front_bumper", "front"


def build(m: dict) -> list:
    n = f"part_{SLOT}_{ID}"
    chrome = m["chrome"]
    amber = materials.emissive_material("amber", H("#ffb347"))
    y = T.CAB_Y1
    o = [
        shapes.box(f"{n}_step1", (2.7, 0.45, 0.28), (0, y + 0.25, 0.38), chrome, bevel=0.03),
        shapes.box(f"{n}_step2", (2.5, 0.35, 0.26), (0, y + 0.2, 0.66), chrome, bevel=0.03),
        shapes.box(f"{n}_step3", (2.3, 0.28, 0.26), (0, y + 0.16, 0.92), chrome, bevel=0.03),
    ]
    for sx in (-1, 1):
        o.append(shapes.box(f"{n}_lamp_{sx}", (0.18, 0.1, 0.14), (sx * 1.25, y + 0.4, 0.45), amber))
    return o
