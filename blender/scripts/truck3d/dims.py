"""Medidas do caminhão (m) e pontos de montagem. As peças (accessories/) e os testes usam estes números.

Convenções: +Y frente, Z cima, traseira do baú em Y=0, X=0 no centro.
"""
import math

BODY_W, BODY_L, BODY_Z0, BODY_TOP = 2.5, 8.2, 1.1, 3.2
CAB_W, CAB_Y0, CAB_Y1, CAB_Z0, CAB_TOP = 2.4, 8.45, 11.5, 0.9, 3.35
REAR_AXLES_Y = (1.5, 3.0)
FRONT_AXLE_Y = 10.2
WHEEL_R = 0.52

# Pontos de montagem. Os que terminam em _R têm gêmeo _L espelhado em X.
_MOUNTS_CENTER = {
    "MOUNT_FRONT_BUMPER": (0.0, CAB_Y1, 0.45),
    "MOUNT_FRONT_GRILLE": (0.0, CAB_Y1, 1.25),
    "MOUNT_FRONT_ORNAMENT": (0.0, CAB_Y1, 1.85),
    "MOUNT_VISOR": (0.0, 11.17, CAB_TOP - 0.01),
    "MOUNT_ROOF": (0.0, 10.0, CAB_TOP),
    "MOUNT_ROOF_LIGHTS": (0.0, 10.95, CAB_TOP),
    "MOUNT_BODY_ROOF": (0.0, 4.0, BODY_TOP),
    "MOUNT_REAR": (0.0, 0.0, 0.7),
    "MOUNT_REAR_LAMPS": (0.0, 0.0, 1.6),
    "MOUNT_REAR_PLATE": (0.0, 0.0, 1.0),
    "MOUNT_REAR_PANEL": (0.0, 0.0, 2.2),
    "MOUNT_REAR_ROOF": (0.0, 0.0, BODY_TOP),
}
_MOUNTS_SIDE_R = {
    "MOUNT_SIDE_R": (BODY_W / 2, 3.95, 0.95),
    "MOUNT_FENDER_R": (1.2, 2.25, 0.52),
    "MOUNT_STEP_R": (1.2, 9.4, 0.55),
    "MOUNT_SIDE_TRIM_R": (BODY_W / 2, 1.2, 2.45),
    "MOUNT_SIDE_BOX_R": (BODY_W / 2, 4.9, 0.4),
    "MOUNT_SIDE_ORNAMENT_R": (BODY_W / 2, 5.0, 2.3),
    "MOUNT_SIDE_PANEL_R": (BODY_W / 2, 4.1, 2.35),
    "MOUNT_CAB_SIDE_R": (CAB_W / 2, 10.0, 1.0),
    "MOUNT_WHEEL_FRONT_R": (1.0, FRONT_AXLE_Y, 0.5),
    "MOUNT_WHEEL_FRONT_FACE_R": (1.165, FRONT_AXLE_Y, 0.5),
    "MOUNT_WHEEL_REAR_FACE_R": (1.215, REAR_AXLES_Y[0], 0.52),
    "MOUNT_WHEEL_REAR_R": (1.06, REAR_AXLES_Y[0], 0.52),
    "MOUNT_MUDFLAP_R": (0.95, 0.45, 0.8),
}
MOUNTS = dict(_MOUNTS_CENTER)
for _n, _p in _MOUNTS_SIDE_R.items():
    MOUNTS[_n] = _p
    MOUNTS[_n[:-1] + "L"] = (-_p[0], _p[1], _p[2])


# --- forma da cabine (usada para construir e para encostar detalhes na superfície)
WIND_Z0, WIND_Z1 = 2.1, 3.2          # trecho inclinado do para-brisa
WIND_SETBACK = 0.38                  # quanto o topo do para-brisa recua
ROOF_R = 0.15                        # altura do arredondado do teto
ROOF_INSET = 0.13


def cab_yf(z: float) -> float:
    """Y da face frontal da cabine na altura z (antes do arredondado do teto)."""
    if z <= WIND_Z0:
        return CAB_Y1
    t = min(1.0, (z - WIND_Z0) / (WIND_Z1 - WIND_Z0))
    return CAB_Y1 - WIND_SETBACK * t


def cab_hw(z: float) -> float:
    """Meia-largura da cabine na altura z (leve afunilamento para cima)."""
    if z <= 2.4:
        return CAB_W / 2
    t = min(1.0, (z - 2.4) / 0.8)
    return CAB_W / 2 - 0.05 * t


SLOPE_DEG = math.degrees(math.atan2(WIND_SETBACK, WIND_Z1 - WIND_Z0))
