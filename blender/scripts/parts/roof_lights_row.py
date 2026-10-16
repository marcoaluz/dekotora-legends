"""Fileira de luzes no teto da cabine."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import build_truck_base as T  # noqa: E402
from lib import materials, shapes  # noqa: E402
from lib.palette import hex_to_rgb as H  # noqa: E402

ID, SLOT, ZONE = "roof_lights_row", "roof_lights", "roof"


def build(m: dict) -> list:
    n = f"part_{SLOT}_{ID}"
    amber = materials.emissive_material("amber", H("#ffb347"))
    z, y = T.CAB_TOP, T.CAB_Y1 - 0.45
    o = [shapes.box(f"{n}_bar", (2.3, 0.4, 0.14), (0, y, z), m["chrome"], bevel=0.02)]
    for i in range(7):
        x = -1.05 + i * 0.35
        o.append(shapes.box(f"{n}_light_{i}", (0.22, 0.16, 0.2), (x, y + 0.05, z + 0.14), amber))
    return o
