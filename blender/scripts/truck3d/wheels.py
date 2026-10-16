"""Rodas: pneu por revolução (flancos curvos + sulcos), aro cromado com cubo e porcas."""
import math

from lib import mesh3d as M
from lib import mesh_adv as A


def tire_profile(R: float, w: float):
    """Contorno fechado (raio, posição axial) do pneu: flanco curvo, ombros e dois sulcos no piso."""
    rb = 0.6 * R
    g = 0.03 * R / 0.5
    half = [(rb, 0.42 * w), (0.72 * R, 0.49 * w), (0.85 * R, 0.5 * w), (0.95 * R, 0.47 * w), (0.99 * R, 0.43 * w),
            (R, 0.40 * w), (R, 0.28 * w), (R - g, 0.27 * w), (R - g, 0.21 * w), (R, 0.20 * w)]
    left = [(r, -a) for (r, a) in half]             # lado negativo, do aro até o centro do piso
    right = [(r, a) for (r, a) in reversed(half)]   # lado positivo, do centro do piso de volta ao aro
    return left + right


def rim_profile(R: float, k_t: float):
    """Disco do aro; (raio, distância para fora do centro da roda)."""
    k = R / 0.5
    base = [(0, 0.0), (0, 0.15), (0.06, 0.15), (0.075, 0.18), (0.12, 0.18), (0.135, 0.15), (0.2, 0.142),
            (0.29, 0.145), (0.31, 0.13), (0.31, 0.0)]
    return [(r * k, t * k_t) for (r, t) in base]


def make_wheel(name, loc, m, rim=True, radius=0.52, width=0.3, seg=28):
    """Devolve lista de objetos; o primeiro (pneu) tem a origem no centro da roda."""
    side = 1 if loc[0] >= 0 else -1
    tire = A.lathe(name + "_tire", tire_profile(radius, width), loc, m["rubber"], axis="X", seg=seg)
    parts = [tire]
    k = radius / 0.5
    kt = width / 0.3
    if rim:
        prof = [(r, side * t) for (r, t) in rim_profile(radius, kt)]
        parts.append(A.lathe(name + "_rim", prof, loc, m["chrome"], axis="X", seg=seg))
        for i in range(8):
            a = i * math.tau / 8
            parts.append(M.cylinder(f"{name}_nut{i}", 0.024 * k, 0.05,
                                    (loc[0] + side * 0.16 * kt, loc[1] + math.cos(a) * 0.17 * k, loc[2] + math.sin(a) * 0.17 * k),
                                    m["steel"], axis="X", seg=6))
    else:
        prof = [(r, side * t * 0.8) for (r, t) in rim_profile(radius, kt)]
        parts.append(A.lathe(name + "_disc", prof, loc, m["steel"], axis="X", seg=seg))
    return parts
