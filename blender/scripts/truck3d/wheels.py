"""Rodas: pneu por revolução (flancos curvos + sulcos), aro cromado com cubo e porcas."""
import math

from lib import mesh3d as M
from lib import mesh_adv as A


LUGS = 12   # chevron lugs around the tire


def tire_profile(R: float, w: float):
    """Contorno fechado (raio, posição axial) do pneu: flanco curvo, ombros e piso subdividido (para os sulcos)."""
    rb = 0.6 * R
    half = [(rb, 0.42 * w), (0.72 * R, 0.49 * w), (0.85 * R, 0.5 * w), (0.95 * R, 0.47 * w), (0.99 * R, 0.43 * w),
            (R, 0.40 * w)]
    half += [(R, w * (0.40 - 0.05 * k)) for k in range(1, 9)]      # tread from 0.35w down to 0
    left = [(r, -a) for (r, a) in half]             # lado negativo, do aro até o centro do piso
    right = [(r, a) for (r, a) in reversed(half[:-1])]   # lado positivo (centro do piso não repete)
    return left + right


def tread_disp(R: float, w: float):
    """Deslocamento radial: sulcos em chevron (V) no piso, com nervura central contínua."""
    depth = 0.07 * R

    def disp(r, a, t):
        if r < R - 1e-6 or abs(a) > 0.395 * w or abs(a) < 0.04 * w:
            return r
        sgn = 1.0 if a > 0 else -1.0
        ph = (t * LUGS / math.tau + sgn * abs(a) / w * 1.1) % 1.0
        return r - depth if ph < 0.4 else r
    return disp


def rim_profile(R: float, k_t: float):
    """Disco do aro; (raio, distância para fora do centro da roda)."""
    k = R / 0.5
    base = [(0, 0.0), (0, 0.15), (0.06, 0.15), (0.075, 0.18), (0.12, 0.18), (0.135, 0.15), (0.2, 0.142),
            (0.29, 0.145), (0.31, 0.13), (0.31, 0.0)]
    return [(r * k, t * k_t) for (r, t) in base]


def make_wheel(name, loc, m, rim=True, radius=0.52, width=0.3, seg=48):
    """Devolve lista de objetos; o primeiro (pneu) tem a origem no centro da roda."""
    side = 1 if loc[0] >= 0 else -1
    tire = A.lathe(name + "_tire", tire_profile(radius, width), loc, m["rubber"], axis="X", seg=seg,
                    disp=tread_disp(radius, width))
    parts = [tire]
    k = radius / 0.5
    kt = width / 0.3
    if rim:
        prof = [(r, side * t) for (r, t) in rim_profile(radius, kt)]
        parts.append(A.lathe(name + "_rim", prof, loc, m["chrome"], axis="X", seg=seg))
        for i in range(8):
            a = i * math.tau / 8
            parts.append(M.cylinder(f"{name}_nut{i}", 0.03 * k, 0.07,
                                    (loc[0] + side * 0.16 * kt, loc[1] + math.cos(a) * 0.17 * k, loc[2] + math.sin(a) * 0.17 * k),
                                    m["steel"], axis="X", seg=6))
    else:
        prof = [(r, side * t * 0.8) for (r, t) in rim_profile(radius, kt)]
        parts.append(A.lathe(name + "_disc", prof, loc, m["steel"], axis="X", seg=seg))
    return parts
