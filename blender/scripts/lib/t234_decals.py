"""Adesivos novos (T-234, lacuna "adesivos" da seção 19 de docs/REFERENCIA_PECAS.md): as 9 frases da decisão 7 em
caligrafia de pincel (fonte Yuji Syuku, OFL; os mesmos glifos das pinturas do teto da T-232, conferidos na `cmap`),
labaredas e sol nascente sobre ondas. PNG com fundo transparente, desenho BRANCO com contorno escuro: o jogo tinge
pela cor escolhida na garagem (`DecalPlacer`, cor x textura; o contorno continua escuro). Kanji na horizontal, da
esquerda para a direita, nunca espelhado (o adesivo é um quadrado virado para fora em cada lado).
O sol nascente aqui é um sol com raios saindo de trás de ondas (não a bandeira de 16 raios). Determinístico.
"""
from __future__ import annotations

import math
import os

import numpy as np

from . import paint2d as p
from . import t232_glyphs, t232_text, t232_texts
from .paint2d import hexc

GLYPHS = os.path.join("blender", "renders", "t232", "glyphs.npz")
INK, EDGE = "#ffffff", "#141014"
PHRASES = [(f"frase_{i + 1:02d}", t) for i, t in enumerate(t232_texts.ROOF)]   # ids decal_frase_01..09


def _rgba(cv, lay_alpha):
    col, _em = cv.result()
    a = p.downsample(lay_alpha[..., None], cv.ss)[..., 0]
    return np.concatenate([col, np.clip(a, 0, 1)[..., None]], 2)


def _alpha(cv, layers):
    full = np.zeros((cv.h, cv.w), np.float32)
    for a, (r0, r1, c0, c1) in layers:
        full[r0:r1, c0:c1] = np.maximum(full[r0:r1, c0:c1], np.clip(a, 0, 1))
    return full


def phrase(text, glyphs, path):
    n = len(text)
    aspect = max(2.0, n * 0.9 + 0.3)
    cv = p.Canvas(aspect, 256, 2)
    size = 0.82
    x0 = (aspect - size * 0.92 * (n - 1)) / 2
    parts = t232_text.layout(glyphs, text, x0, 0.5, size, vertical=False, spacing=0.92)
    lay = p.union(cv, [p.tris_layer(cv, t) for t in parts])
    edge = p.outline(cv, lay, 0.035)
    cv.fill(edge, hexc(EDGE))
    cv.fill(lay, hexc(INK))
    p.save_png(_rgba(cv, _alpha(cv, [edge, lay])), path)


def flames(path):
    """Labaredas no estilo "hot rod": línguas de fogo saindo da esquerda (frente) e afinando em pontas curvas para a
    direita, branco na raiz e cinza nas pontas (o jogo tinge pela cor escolhida)."""
    cv = p.Canvas(3.0, 300, 2)
    lays = []
    licks = [(0.50, 2.55, 0.11, -1.0), (0.27, 2.05, 0.085, -1.0), (0.73, 2.20, 0.085, 1.0), (0.20, 1.45, 0.06, 1.0),
             (0.80, 1.60, 0.06, -1.0)]
    for y, ln, half, curl in licks:
        top, bot = [], []
        n = 24
        for i in range(n + 1):
            t = i / n
            x = 0.06 + ln * t
            w = half * (1.0 - t) ** 0.7 * (1.0 + 0.35 * math.sin(t * math.pi * 2.5))
            yc = y + curl * (0.05 * math.sin(t * math.pi * 2.2) + 0.14 * t ** 3)
            top.append((x, yc - w))
            bot.append((x, yc + w))
        pts = [(0.02, y - half * 0.9)] + top + list(reversed(bot))[1:] + [(0.02, y + half * 0.9)]
        lays.append(p.P(cv, pts))
    base = p.union(cv, lays)
    edge = p.outline(cv, base, 0.03)
    cv.fill(edge, hexc(EDGE))
    X, Y = cv.coords(base)
    shade = np.clip((X - 0.6) / 2.0, 0, 1)[..., None]
    cv.fill(base, np.ones(X.shape + (3,), np.float32) * (1.0 - 0.35 * shade))
    p.save_png(_rgba(cv, _alpha(cv, [edge, base])), path)


def sun_waves(path):
    """Sol nascente: disco com raios saindo de trás de duas ondas estilizadas."""
    cv = p.Canvas(1.6, 320, 2)
    cx, cy = 0.8, 0.62
    rays = []
    for k in range(11):
        a = math.pi * (0.06 + 0.88 * k / 10)
        x1, y1 = cx - math.cos(a) * 0.62, cy - math.sin(a) * 0.62
        rays.append(p.S(cv, [(cx - math.cos(a) * 0.30, cy - math.sin(a) * 0.30), (x1, y1)], 0.035))
    disc = p.C(cv, cx, cy, 0.26)
    wave_pts = []
    for i in range(41):
        x = 0.02 + 1.56 * i / 40
        wave_pts.append((x, 0.70 + 0.05 * math.sin(i / 40 * math.pi * 4)))
    wave = p.P(cv, wave_pts + [(1.58, 0.98), (0.02, 0.98)])
    sun = p.union(cv, rays + [disc])
    top = p.minus(sun, wave)
    edge = p.outline(cv, p.union(cv, [top, wave]), 0.03)
    cv.fill(edge, hexc(EDGE))
    cv.fill(top, hexc(INK))
    cv.fill(wave, hexc("#d8d8d8"))
    crest = p.S(cv, wave_pts, 0.012)
    cv.fill(crest, hexc(EDGE))
    p.save_png(_rgba(cv, _alpha(cv, [edge, top, wave])), path)


def build_all(out_dir: str) -> list:
    os.makedirs(out_dir, exist_ok=True)
    if not os.path.exists(GLYPHS):
        t232_glyphs.build(t232_texts.all_chars(), GLYPHS)
    glyphs = t232_text.load(GLYPHS)
    ids = []
    for pid, text in PHRASES:
        phrase(text, glyphs, os.path.join(out_dir, f"decal_{pid}.png"))
        ids.append(f"decal_{pid}")
    flames(os.path.join(out_dir, "decal_labaredas.png"))
    sun_waves(os.path.join(out_dir, "decal_sol_nascente.png"))
    ids += ["decal_labaredas", "decal_sol_nascente"]
    print(f"[t234] adesivos: {len(ids)} em {out_dir}")
    return ids
