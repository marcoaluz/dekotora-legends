"""Matcaps do cromo (V6): esferas pintadas com o "ambiente" que o cromo reflete, para o Godot usar no lugar
do reflexo real (o renderizador Compatibility não tem reflexo de tela e o céu noturno escuro deixava o
cromo preto).

Uso: blender -b --factory-startup -P blender/scripts/build_matcaps.py -- [--out game/assets/textures]
Saída: matcap_chrome_night.png (cidade à noite: postes de sódio, neon rosa/ciano, luzes no horizonte)
       matcap_chrome_day.png   (céu azul, sol, horizonte e asfalto)
       matcap_chrome_studio.png (estúdio neutro da garagem, sem tom azul; T-138)
256 px, determinístico (semente fixa).
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import scene, tex  # noqa: E402

SIZE = 256


def _hash(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.modf(np.abs(np.sin(a * 127.1 + b * 311.7) * 43758.5453))[0]


def _reflection():
    """Direção refletida (x, y, z) para cada pixel da esfera, vista de frente. y = cima."""
    lin = (np.arange(SIZE) + 0.5) / SIZE * 2 - 1
    x, y = np.meshgrid(lin, -lin)                         # linha 0 = topo
    r2 = np.clip(x * x + y * y, 0, 0.999)
    nz = np.sqrt(1 - r2)
    rx, ry, rz = 2 * nz * x, 2 * nz * y, 2 * nz * nz - 1
    elev = ry
    az = np.arctan2(rx, -rz)
    rim = np.sqrt(r2)
    return elev, az, rim


def _blob(elev, az, e0, a0, rad, col):
    d2 = (elev - e0) ** 2 + ((az - a0 + np.pi) % (2 * np.pi) - np.pi) ** 2 * 0.35
    return np.exp(-d2 / (rad * rad))[..., None] * np.array(col)


def night() -> np.ndarray:
    elev, az, rim = _reflection()
    sky = np.where(elev[..., None] > 0,
                   np.array([0.02, 0.03, 0.09]) + np.array([0.10, 0.06, 0.10]) * np.exp(-np.abs(elev) * 6)[..., None],
                   np.array([0.03, 0.03, 0.035]) + np.array([0.08, 0.04, 0.02]) * np.exp(-np.abs(elev) * 5)[..., None])
    col = sky.copy()
    band = np.exp(-(elev / 0.07) ** 2)                     # luzes da cidade no horizonte
    cell_a = np.floor((az + np.pi) * 40)
    cell_e = np.floor(elev * 90)
    h = _hash(cell_a, cell_e)
    lights = (h > 0.72) * band
    warm = np.array([1.0, 0.72, 0.38])
    pink = np.array([1.0, 0.25, 0.6])
    cyan = np.array([0.25, 0.9, 1.0])
    pick = _hash(cell_a + 3.0, cell_e + 9.0)
    lc = np.where((pick < 0.65)[..., None], warm, np.where((pick < 0.83)[..., None], pink, cyan))
    col += lights[..., None] * lc * 0.9
    for a0 in (-2.4, -1.1, 0.35, 1.5, 2.7):                # postes de sódio passando por cima
        col += _blob(elev, az, 0.62, a0, 0.13, [1.4, 0.8, 0.35])
    for e0, a0, a1, c in ((0.22, -2.0, -0.6, pink), (0.3, 0.8, 2.2, cyan), (0.16, 2.4, 3.0, pink)):   # neon
        on = ((az > a0) & (az < a1)).astype(float)
        col += (np.exp(-((elev - e0) / 0.012) ** 2) * on)[..., None] * c * 0.9
    col += _blob(elev, az, -0.25, 0.0, 0.18, [0.5, 0.25, 0.1])   # asfalto molhado refletindo o sódio
    col += np.exp(-((elev - 0.08) / 0.3) ** 2)[..., None] * np.array([0.4, 0.22, 0.12])   # neblina laranja da cidade
    col += (rim ** 6)[..., None] * 0.18
    return np.clip(col, 0, 1)


def day() -> np.ndarray:
    elev, az, rim = _reflection()
    t = np.clip(elev, 0, 1)[..., None]
    sky = np.array([0.78, 0.86, 0.95]) * (1 - t) ** 1.5 + np.array([0.22, 0.48, 0.9]) * (1 - (1 - t) ** 1.5)
    ground = np.array([0.24, 0.22, 0.2]) * (1 - 0.4 * np.clip(-elev, 0, 1))[..., None]
    col = np.where(elev[..., None] > 0, sky, ground)
    trees = (elev > 0) & (elev < 0.05 + 0.03 * np.sin(az * 9) ** 2)   # linha de árvores/serra
    col = np.where(trees[..., None], np.array([0.16, 0.2, 0.17]), col)
    cloud = _hash(np.floor((az + np.pi) * 6), np.floor(elev * 8)) > 0.6
    col = np.where((cloud & (elev > 0.15) & (elev < 0.55))[..., None], col * 0.4 + 0.6, col)
    col += _blob(elev, az, 0.68, 0.7, 0.07, [1.6, 1.5, 1.3])         # sol
    col += (rim ** 6)[..., None] * 0.12
    return np.clip(col, 0, 1)


def studio() -> np.ndarray:
    """Estúdio neutro da garagem (T-138): cinza sem tom azul, softbox grande no teto, duas faixas de luz
    verticais nas laterais, uma caixa de luz na frente e o piso escuro com o reflexo das lâmpadas."""
    elev, az, rim = _reflection()
    white = np.array([1.0, 0.98, 0.95])                   # luz levemente quente (nunca azul)
    wall = 0.10 + 0.06 * np.exp(-np.abs(elev) * 4)
    col = np.where(elev[..., None] > 0, wall[..., None] * white,
                   (0.05 + 0.04 * np.exp(-np.abs(elev) * 6))[..., None] * np.array([1.0, 0.97, 0.93]))
    # softbox do teto: retângulo largo e suave
    top = np.clip((elev - 0.55) / 0.08, 0, 1)
    col += top[..., None] * white * 1.1
    # faixas verticais nas laterais (luzes de estúdio)
    for a0 in (-1.75, 1.75):
        d = (az - a0 + np.pi) % (2 * np.pi) - np.pi
        band = np.exp(-(d / 0.09) ** 2) * np.clip((elev + 0.05) / 0.2, 0, 1) * np.clip((0.75 - elev) / 0.2, 0, 1)
        col += band[..., None] * white * 1.2
    col += _blob(elev, az, 0.25, -0.6, 0.16, [0.9, 0.88, 0.85])     # caixa de luz na frente/esquerda
    col += _blob(elev, az, 0.18, 2.9, 0.12, [0.5, 0.49, 0.47])      # rebatedor atrás
    col += np.exp(-((elev + 0.04) / 0.035) ** 2)[..., None] * white * 0.35   # linha de luz no horizonte
    col += _blob(elev, az, -0.35, 0.0, 0.2, [0.12, 0.115, 0.11])     # piso refletindo o teto
    col += (rim ** 6)[..., None] * 0.15
    return np.clip(col, 0, 1)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/textures")
    out = os.path.abspath(ap.parse_args(argv).out)
    scene.reset_scene()
    tex.save_png(night()[::-1], os.path.join(out, "matcap_chrome_night.png"))   # save_png grava a linha 0 embaixo
    tex.save_png(day()[::-1], os.path.join(out, "matcap_chrome_day.png"))
    tex.save_png(studio()[::-1], os.path.join(out, "matcap_chrome_studio.png"))
    print("OK build_matcaps ->", out)


if __name__ == "__main__":
    main()
