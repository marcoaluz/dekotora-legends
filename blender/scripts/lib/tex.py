"""Texturas procedurais pequenas (numpy) para materiais PBR exportados no .glb.

Cada função devolve uma imagem do Blender já empacotada (vai embutida no .glb).
Resoluções baixas (256-512 px) para o celular.
"""
from __future__ import annotations

import bpy
import numpy as np

from .palette import hex_to_rgb


def _image(name: str, arr: np.ndarray, srgb: bool = True):
    """arr: (h, w, 3|4) float 0..1 em sRGB (cores) ou dados lineares (normal/rugosidade)."""
    h, w = arr.shape[:2]
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1))], axis=2)
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    img.pack()
    return img


def perforated_mesh(name: str = "tex_perforated", cols: int = 28, rows: int = 2, w: int = 1024, h: int = 72):
    """Chapa perfurada (a proporção w:h deve seguir a da face, para os furos ficarem redondos): furos escuros redondos sobre aço claro (grade do estilo Actros/Dekotora)."""
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx / w * cols) % 1.0 - 0.5
    v = (yy / h * rows) % 1.0 - 0.5
    d = np.sqrt((u * (w / cols)) ** 2 + (v * (h / rows)) ** 2) / (w / cols)
    hole = np.clip((0.34 - d) / 0.05, 0, 1)
    steel = np.array(hex_to_rgb("#aab4c2"))
    dark = np.array(hex_to_rgb("#08080a"))
    arr = steel * (1 - hole[..., None]) + dark * hole[..., None]
    return _image(name, arr)


def diamond_plate(name: str = "tex_diamond", n: int = 8, size: int = 256):
    """Chapa xadrez antiderrapante (degraus): losangos claros sobre aço escuro."""
    yy, xx = np.mgrid[0:size, 0:size]
    u = (xx / size * n) % 1.0
    v = (yy / size * n * 2) % 1.0
    a = np.abs(u - 0.5) + np.abs(v - 0.5) * 0.5
    bump = np.clip((0.32 - a) / 0.06, 0, 1)
    lo = np.array(hex_to_rgb("#4a505a"))
    hi = np.array(hex_to_rgb("#c4ccd8"))
    arr = lo * (1 - bump[..., None]) + hi * bump[..., None]
    return _image(name, arr)


def grime_panel(name: str = "tex_grime", w: int = 512, h: int = 256, seed: int = 7):
    """Sujeira discreta para chapa pintada (multiplica a cor): escurece a parte de baixo (poeira da estrada),
    riscos de água escorrendo de cima e pontinhos de uso. Valores 0,66..1,0 (nunca preto)."""
    rng = np.random.default_rng(seed)
    v = np.linspace(0, 1, h)[:, None]                       # 0 = embaixo, 1 = em cima
    grime = 0.3 * np.clip(1 - v / 0.4, 0, 1) ** 1.4         # poeira na barra inferior (lama das rodas)
    streaks = np.zeros((h, w))
    for _ in range(26):                                     # riscos verticais
        x = rng.integers(0, w)
        wd = rng.integers(1, 4)
        top = rng.uniform(0.5, 1.0)
        a = rng.uniform(0.02, 0.07)
        y1 = int((1 - top) * h)
        y0 = int(h * rng.uniform(0.0, 0.5))
        ramp = np.linspace(a, 0, max(h - y1 - y0, 1))
        streaks[y1:h - y0, x:x + wd] += ramp[:, None][: streaks[y1:h - y0, x:x + wd].shape[0]]
    speck = np.clip(rng.normal(0, 1, (h, w)), 1.6, 4) - 1.6   # arranhoes/pontinhos raros
    speck = (speck > 0.9) * 0.05
    val = np.clip(1.0 - grime - streaks - speck, 0.66, 1.0)
    return _image(name, np.repeat(val[..., None], 3, axis=2))


def load_pixels(path: str, size: int) -> np.ndarray:
    """Lê uma imagem (jpg/png) e devolve (size, size, 3) em sRGB 0..1, de cima para baixo, reduzida por média."""
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"            # lê os valores como estão no arquivo
    w, h = img.size
    arr = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]
    bpy.data.images.remove(img)
    f = w // size
    return arr[: size * f, : size * f].reshape(size, f, size, f, 3).mean(axis=(1, 3))


def streaked_concrete(src: str, size: int = 512, seed: int = 5) -> np.ndarray:
    """Concreto CC0 (src) com manchas de chuva escorrida: riscos escuros que começam no topo (linha 0) e somem
    para baixo, mais uma faixa de poeira na base. Repete nas laterais. Devolve (size, size, 3) sRGB."""
    rng = np.random.default_rng(seed)
    base = load_pixels(src, size)
    lum = base.mean(axis=2, keepdims=True)
    base = lum + (base - lum) * 0.55                        # menos amarelado
    base = base / max(float(base.mean()), 1e-3) * 0.55      # brilho medio padronizado
    dark = np.zeros((size, size))
    for _ in range(70):
        x = int(rng.integers(0, size))
        wd = int(rng.integers(2, 9))
        length = rng.uniform(0.25, 0.95)
        a = rng.uniform(0.08, 0.28)
        n = int(size * length)
        ramp = np.linspace(a, 0.0, n) ** 1.3
        for k in range(wd):                                  # borda suave do risco
            fall = 1.0 - abs(k - wd / 2) / (wd / 2 + 1)
            dark[:n, (x + k) % size] += ramp * fall
    v = np.linspace(0, 1, size)[:, None]
    dark += 0.12 * np.clip((v - 0.8) / 0.2, 0, 1)           # poeira da pista na base
    val = np.clip(1.0 - dark, 0.45, 1.0)
    return np.clip(base * val[..., None], 0, 1)[::-1]     # save_png grava a linha 0 embaixo


def concrete(name: str = "tex_concrete", size: int = 512, seed: int = 11):
    """Concreto polido repetível: ruído suave em várias escalas + manchas leves e juntas de dilatação."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size))
    for k, amp in ((8, 0.5), (32, 0.3), (128, 0.2)):          # ruído de valor em 3 escalas (repetível)
        g = rng.random((k, k))
        idx = np.arange(size) * k / size
        i0 = np.floor(idx).astype(int)
        f = idx - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % k
        row = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
        row2 = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
        acc += amp * (row * (1 - f)[:, None] + row2 * f[:, None])
    val = 0.42 + 0.16 * (acc - acc.mean())
    val[:3, :] *= 0.75                                        # junta de dilatação nas bordas do ladrilho
    val[:, :3] *= 0.75
    val += (rng.random((size, size)) - 0.5) * 0.025           # granulado fino
    return _image(name, np.repeat(np.clip(val, 0, 1)[..., None], 3, axis=2) * np.array([1.0, 1.0, 1.04]))


def corrugated(name: str = "tex_corrugated", w: int = 256, h: int = 64, waves: int = 8):
    """Chapa ondulada (parede do galpão): faixas claras/escuras verticais, repetível na horizontal."""
    x = np.linspace(0, waves * 2 * np.pi, w, endpoint=False)
    band = 0.5 + 0.5 * np.sin(x)
    base = np.array(hex_to_rgb("#3a4150"))
    hi = np.array(hex_to_rgb("#6c7686"))
    arr = base * (1 - band[None, :, None]) + hi * band[None, :, None]
    return _image(name, np.repeat(arr, h, axis=0))


def hazard(name: str = "tex_hazard", w: int = 256, h: int = 32):
    """Faixa zebrada amarelo/preto (piso de oficina)."""
    yy, xx = np.mgrid[0:h, 0:w]
    s = ((xx + yy) // 16) % 2
    y = np.array(hex_to_rgb("#e8b512"))
    k = np.array(hex_to_rgb("#16161a"))
    arr = y * (1 - s[..., None]) + k * s[..., None]
    return _image(name, arr)


def _value_noise(size: int, rng, octaves=((8, 0.5), (32, 0.3), (128, 0.2))) -> np.ndarray:
    """Ruído de valor repetível (as bordas casam) em várias escalas; média ~0,5."""
    acc = np.zeros((size, size))
    for k, amp in octaves:
        g = rng.random((k, k))
        idx = np.arange(size) * k / size
        i0 = np.floor(idx).astype(int)
        f = idx - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % k
        row = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
        row2 = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
        acc += amp * (row * (1 - f)[:, None] + row2 * f[:, None])
    return acc


def asphalt(size: int = 512, seed: int = 31):
    """(cor, rugosidade) do asfalto: brita clara/escura salpicada, manchas de piche e trechos mais lisos
    (parecem molhados à noite). Repetível."""
    rng = np.random.default_rng(seed)
    base = _value_noise(size, rng)
    speck = rng.random((size, size))
    val = 0.16 + 0.07 * (base - 0.5)
    val += np.where(speck > 0.985, 0.12, 0.0) + np.where(speck < 0.02, -0.05, 0.0)   # pedrinhas
    tar = _value_noise(size, rng, ((4, 0.7), (16, 0.3)))
    val -= np.where(tar > 0.62, 0.035, 0.0)                                            # remendos de piche
    col = np.repeat(np.clip(val, 0, 1)[..., None], 3, axis=2) * np.array([1.0, 1.0, 1.06])
    rough = np.clip(0.62 - 0.32 * np.clip((tar - 0.45) * 3, 0, 1) + (speck - 0.5) * 0.08, 0.2, 0.9)
    return col, np.repeat(rough[..., None], 3, axis=2)


def grass(size: int = 512, seed: int = 41):
    rng = np.random.default_rng(seed)
    n = _value_noise(size, rng, ((6, 0.5), (24, 0.3), (96, 0.2)))
    blades = rng.random((size, size)) * 0.12
    g = np.array(hex_to_rgb("#1f4a2a"))
    y = np.array(hex_to_rgb("#4a5a2a"))
    t = np.clip((n - 0.35) * 1.6, 0, 1)[..., None]
    return (g * (1 - t) + y * t) * (0.85 + blades[..., None])


def sand(size: int = 512, seed: int = 51):
    rng = np.random.default_rng(seed)
    n = _value_noise(size, rng, ((5, 0.5), (40, 0.3), (160, 0.2)))
    grain = (rng.random((size, size)) - 0.5) * 0.08
    a = np.array(hex_to_rgb("#9c8a6a"))
    b = np.array(hex_to_rgb("#c9b48c"))
    t = np.clip(n + grain, 0, 1)[..., None]
    return a * (1 - t) + b * t


def save_png(arr: np.ndarray, path: str) -> None:
    """Grava um array (h, w, 3) 0..1 como PNG (sRGB, sem conversão)."""
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    h, w = arr.shape[:2]
    rgba = np.concatenate([arr, np.ones((h, w, 1))], axis=2)
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.clip(rgba, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
