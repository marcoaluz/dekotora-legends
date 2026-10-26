"""Tigre (tora) da T-232: corpo de lado (formas unidas suavemente, listras por código) e rosto de frente rugindo.
Desenho nosso por código; a pose segue a tradição dos tigres de Kishi Ganku e Maruyama Ōkyo, sem copiar obra.
"""
from __future__ import annotations

import math

import numpy as np

from . import paint2d as p
from .paint2d import hexc
from .t232_kit import Local, paint

ORANGE = ("#b8360c", "#f07a1a", "#ffc25a")
LINE = "#1a0a04"
WHITE = "#fff6e6"


def _stripes(lx, ly, seed, freq=13.0, thick=0.8):
    n = p.vnoise(lx, ly, 0.35, seed=seed)
    v = np.sin(lx * freq + np.sin(ly * 5.0) * 1.4 + n * 5.0)
    return np.clip((v - thick) / (1 - thick) * 3, 0, 1)


def side(cv, L, pose="stand", seed=1, mouth=0.6):
    """Tigre de lado olhando para +x local. Corpo ~2,6 de comprimento (com cauda), ~1,1 de altura; patas em y ~ 0,66."""
    leap = pose == "leap"

    def sd(x, y):
        tilt = -0.25 if leap else 0.0
        d = p.sd_ellipse(x, y, 0.0, 0.0, 0.78, 0.31, tilt)
        d = p.smin(d, p.sd_ellipse(x, y, 0.55, -0.03 + tilt * 0.6, 0.36, 0.36), 0.12)
        d = p.smin(d, p.sd_ellipse(x, y, -0.62, 0.02 - tilt * 0.6, 0.36, 0.36), 0.12)
        hx, hy = (1.05, -0.38) if leap else (1.02, -0.26)
        d = p.smin(d, p.sd_circle(x, y, hx, hy, 0.32), 0.14)
        d = p.smin(d, p.sd_ellipse(x, y, hx + 0.3, hy + 0.1, 0.22, 0.16, 0.2), 0.06)
        for ex in (-0.2, 0.0):
            d = np.minimum(d, p.sd_circle(x, y, hx + ex, hy - 0.28, 0.085))
        if leap:
            legs = [((0.6, 0.15), (0.95, 0.3), (1.25, 0.25)), ((0.45, 0.2), (0.75, 0.45), (1.05, 0.48)),
                    ((-0.6, 0.15), (-0.95, 0.35), (-1.3, 0.45)), ((-0.7, 0.2), (-1.0, 0.5), (-1.25, 0.65))]
        else:
            legs = [((0.62, 0.18), (0.7, 0.45), (0.78, 0.64)), ((0.4, 0.2), (0.36, 0.45), (0.32, 0.64)),
                    ((-0.62, 0.15), (-0.45, 0.42), (-0.7, 0.64)), ((-0.78, 0.15), (-0.75, 0.42), (-0.98, 0.64))]
        for a, b, c in legs:
            d = p.smin(d, p.sd_seg(x, y, a[0], a[1], b[0], b[1], 0.15, 0.1), 0.06)
            d = p.smin(d, p.sd_seg(x, y, b[0], b[1], c[0], c[1], 0.1, 0.085), 0.04)
            d = p.smin(d, p.sd_ellipse(x, y, c[0] + 0.06, c[1] + 0.02, 0.13, 0.065), 0.03)
        return d

    hx, hy = (1.05, -0.38) if leap else (1.02, -0.26)
    # cauda (tubo em S com anéis)
    tail = p.spline([(-0.9, -0.08), (-1.25, -0.25), (-1.35, -0.6), (-1.2, -0.85)] if not leap else
                    [(-0.9, -0.05), (-1.3, -0.1), (-1.6, -0.35), (-1.75, -0.6)], 10)
    tl, (ts, tw) = L.SV(tail, [0.07, 0.065, 0.055, 0.04], need_uv=True)
    cv.fill(p.outline(cv, tl, 0.005), hexc(LINE))
    ring = (np.sin(ts / (0.09 * L.s) * math.pi) > 0.55).astype(np.float32)
    cv.fill(tl, p.mix(hexc(ORANGE[1]), hexc(LINE), ring[..., None]))
    body = L.sdf((-1.4, -0.75, 1.6, 0.8), sd)
    cv.fill(p.outline(cv, body, 0.007), hexc(LINE))
    lx, ly = L.local_xy(body)
    col = p.grad_t((ly + 0.45) / 0.9, [(0, ORANGE[0]), (0.45, ORANGE[1]), (0.8, ORANGE[2])])
    belly = (np.clip((ly - (0.14 + 0.05 * np.cos(lx * 2.5))) / 0.06, 0, 1) * np.clip((0.36 - ly) / 0.05, 0, 1)
             * np.clip((0.75 - np.abs(lx)) / 0.1, 0, 1))
    belly = np.maximum(belly, np.clip((ly - 0.58) / 0.04, 0, 1))          # patas brancas
    col = p.mix(col, hexc(WHITE), belly[..., None])
    st = _stripes(lx, ly, seed) * (1 - belly) * (lx < hx - 0.18)
    legst = np.clip((np.sin(ly * 26 + lx * 3) - 0.75) * 4, 0, 1) * (ly > 0.3)
    st = np.maximum(st * (ly < 0.3), legst * (np.abs(lx) > 0.25))
    col = p.mix(col, hexc(LINE), st[..., None] * 0.92)
    cv.fill(body, col)
    _side_face(cv, L, hx, hy, mouth)


def _side_face(cv, L, hx, hy, mouth):
    # bochecha branca, focinho, olho, orelhas, boca aberta
    cheek = L.P(p.spline([(hx - 0.1, hy + 0.05), (hx + 0.05, hy + 0.25), (hx + 0.25, hy + 0.27), (hx + 0.42, hy + 0.12)], 8) +
                [(hx + 0.3, hy + 0.02)])
    cv.fill(cheek, hexc(WHITE))
    for k in range(4):
        y = hy - 0.18 + k * 0.06
        cv.fill(L.SV([(hx - 0.25, y), (hx - 0.05, y + 0.02), (hx + 0.08, y - 0.01)], [0.012, 0.02, 0.004])[0], hexc(LINE))
    for ex in (-0.2, 0.0):
        cv.fill(L.E(hx + ex, hy - 0.27, 0.045, 0.045), hexc(WHITE))
    eye = L.E(hx + 0.12, hy - 0.08, 0.06, 0.035, -15)
    cv.fill(p.outline(cv, eye, 0.003), hexc(LINE))
    cv.fill(eye, hexc("#d8ff5a"), neon=0.7)
    cv.fill(L.E(hx + 0.13, hy - 0.08, 0.014, 0.03), hexc(LINE))
    cv.fill(L.E(hx + 0.12, hy - 0.13, 0.08, 0.02, -15), hexc(WHITE))
    cv.fill(L.E(hx + 0.47, hy + 0.02, 0.04, 0.03), hexc("#3a1410"))
    if mouth > 0:
        m = L.P([(hx + 0.18, hy + 0.12), (hx + 0.47, hy + 0.08), (hx + 0.45, hy + 0.12 + mouth * 0.2), (hx + 0.22, hy + 0.2)])
        cv.fill(p.outline(cv, m, 0.003), hexc(LINE))
        cv.fill(m, hexc("#8a0f1e"))
        for fx, fy, dy in ((hx + 0.42, hy + 0.09, 0.07), (hx + 0.4, hy + 0.12 + mouth * 0.2, -0.07)):
            cv.fill(L.P([(fx - 0.02, fy), (fx, fy + dy), (fx + 0.02, fy)]), hexc("#ffffff"))
    for k in range(3):
        cv.fill(L.S([(hx + 0.38, hy + 0.06 + k * 0.025), (hx + 0.7, hy + 0.0 + k * 0.06)], 0.003), hexc("#ffffff"))


def face(cv, L, roar=0.8, seed=3):
    """Rosto de frente, rugindo. Quadro local: centro do rosto em (0, 0), largura ~1,6 com a juba das bochechas."""
    def sd(x, y):
        d = p.sd_ellipse(x, y, 0, -0.05, 0.5, 0.48)
        d = p.smin(d, p.sd_ellipse(x, y, 0, 0.25, 0.42, 0.32), 0.1)
        for s in (-1, 1):
            d = p.smin(d, p.sd_circle(x, y, s * 0.4, -0.42, 0.14), 0.06)
        return d

    def ruff(x, y):
        a = np.arctan2(y - 0.1, np.abs(x))                  # 0 = para o lado, +pi/2 = para baixo
        saw = np.abs(((a * 9 / math.pi) % 1.0) - 0.5) * 2    # 0..1 dente de serra
        r = 0.6 + 0.12 * (1 - saw) * np.clip((a + 0.6) / 0.6, 0, 1)
        return np.hypot(x, (y - 0.1) * 1.05) - r

    rf = L.sdf((-0.8, -0.65, 0.8, 0.85), lambda x, y: np.maximum(ruff(x, y), -(y + 0.15)))
    cv.fill(p.outline(cv, rf, 0.006), hexc(LINE))
    lx, ly = L.local_xy(rf)
    cv.fill(rf, p.mix(hexc(WHITE), hexc("#f2d8b0"), np.clip(np.abs(lx) / 0.7, 0, 1)[..., None]))
    for s in (-1, 1):
        for k in range(3):
            y = 0.05 + k * 0.12
            cv.fill(L.SV([(s * 0.66, y), (s * 0.5, y + 0.02), (s * 0.42, y + 0.05)], [0.03, 0.022, 0.005])[0], hexc(LINE))
        ear = L.E(s * 0.4, -0.42, 0.14, 0.14)
        cv.fill(p.outline(cv, ear, 0.005), hexc(LINE))
        cv.fill(ear, hexc(LINE))
        cv.fill(L.E(s * 0.4, -0.4, 0.08, 0.08), hexc(WHITE))
    head = L.sdf((-0.6, -0.6, 0.6, 0.6), sd)
    cv.fill(p.outline(cv, head, 0.006), hexc(LINE))
    lx, ly = L.local_xy(head)
    col = p.grad_t((ly + 0.5) / 1.0, [(0, ORANGE[0]), (0.5, ORANGE[1]), (1, ORANGE[2])])
    cv.fill(head, col)
    # listras do rosto (simétricas): testa ("王"), laterais
    for s in (-1, 1):
        for k in range(4):
            y = -0.36 + k * 0.08
            cv.fill(L.SV([(s * 0.03, y), (s * 0.12, y + 0.01), (s * 0.2, y - 0.02)], [0.02, 0.016, 0.003])[0], hexc(LINE))
        for k in range(3):
            y = -0.1 + k * 0.11
            cv.fill(L.SV([(s * 0.5, y), (s * 0.38, y + 0.03), (s * 0.3, y + 0.02)], [0.035, 0.022, 0.004])[0], hexc(LINE))
        cv.fill(L.E(s * 0.17, -0.18, 0.12, 0.05, s * 10), hexc(WHITE))
        eye = L.sdf((s * 0.17 - 0.12, -0.12, s * 0.17 + 0.12, 0.04), lambda x, y, s=s: np.maximum(
            p.sd_ellipse(x, y, s * 0.17, -0.04, 0.11, 0.055, s * 0.25), -(y + 0.09 - s * (x - s * 0.17) * 0.25)))
        cv.fill(p.outline(cv, eye, 0.006), hexc(LINE))
        cv.fill(eye, hexc("#e8ff6a"), neon=0.8)
        cv.fill(L.E(s * 0.17, -0.035, 0.022, 0.045), hexc(LINE))
    cv.fill(L.S([(0, -0.5), (0, -0.25)], 0.02), hexc(LINE))
    for s in (-1, 1):
        cv.fill(L.E(s * 0.12, 0.2, 0.16, 0.12), hexc(WHITE))
        for k in range(3):
            for j in range(2):
                cv.fill(L.E(s * (0.08 + k * 0.05), 0.17 + j * 0.045, 0.008, 0.008), hexc(LINE))
    nose = L.P([(-0.09, 0.03), (0.09, 0.03), (0.0, 0.12)])
    cv.fill(p.outline(cv, nose, 0.003), hexc(LINE))
    cv.fill(nose, hexc("#e0707a"))
    if roar > 0:
        m = L.sdf((-0.3, 0.2, 0.3, 0.7), lambda x, y: p.sd_ellipse(x, y, 0, 0.36 + roar * 0.06, 0.22, 0.08 + roar * 0.1))
        cv.fill(p.outline(cv, m, 0.006), hexc(LINE))
        cv.fill(m, hexc("#7a0a1a"))
        cv.fill(L.E(0, 0.42 + roar * 0.12, 0.12, 0.05), hexc("#e8325a"))
        for s in (-1, 1):
            cv.fill(L.P([(s * 0.16, 0.28), (s * 0.12, 0.28 + 0.12 * roar), (s * 0.08, 0.28)]), hexc("#ffffff"))
            cv.fill(L.P([(s * 0.15, 0.44 + roar * 0.16), (s * 0.12, 0.36 + roar * 0.06), (s * 0.09, 0.44 + roar * 0.16)]), hexc("#ffffff"))
    for s in (-1, 1):
        for k in range(3):
            cv.fill(L.S([(s * 0.22, 0.2 + k * 0.03), (s * 0.75, 0.1 + k * 0.08)], 0.004), hexc("#ffffff"))
