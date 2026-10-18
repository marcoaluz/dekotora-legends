"""Classificação das faces dos modelos de terceiros em classes do atlas do trânsito (T-124).

A cor de cada face vem da textura base do autor, amostrada no UV médio da face; a classe sai da cor
(matiz/saturação/brilho) e da posição no carro (frente/trás, acima/abaixo da linha da janela). Assim um
modelo de malha única (Ascona, Falcon) vira pintura + vidro + cromo + pneu sem separar nada à mão.

Coordenadas já no padrão do jogo: frente para +Y, traseira em Y = 0, chão em Z = 0, centro em X = 0.
"""
from __future__ import annotations

import numpy as np

from . import traffic_kit as K

_IMG_CACHE: dict = {}


def _image_array(img):
    if img.name not in _IMG_CACHE:
        w, h = img.size
        a = np.zeros(w * h * 4, np.float32)
        img.pixels.foreach_get(a)
        _IMG_CACHE[img.name] = a.reshape(h, w, 4)[..., :3]
    return _IMG_CACHE[img.name]


def _base_image(mat):
    """Imagem ligada à cor base (ou a primeira imagem do material, se a cor base vier de um Mix)."""
    if mat is None or mat.node_tree is None:
        return None
    first = None
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None and n.image.size[0] > 0:
            first = first or n.image
            if any(lk.to_socket.name == "Base Color" for lk in n.outputs[0].links):
                return n.image
    return first


def _flat_color(mat):
    if mat is None:
        return np.array([0.8, 0.8, 0.8], np.float32)
    b = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if mat.node_tree else None
    c = np.array(b.inputs["Base Color"].default_value[:3] if b else mat.diffuse_color[:3], np.float32)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)


def face_rgb(o) -> np.ndarray:
    """Cor sRGB (N,3) de cada face: textura base no UV médio, ou a cor lisa do material."""
    _ctr, _nrm, _area, uvm = K.face_data(o)
    n = len(o.data.polygons)
    mi = np.zeros(n, np.int32)
    o.data.polygons.foreach_get("material_index", mi)
    out = np.zeros((n, 3), np.float32)
    for k, mat in enumerate(o.data.materials):
        sel = mi == k
        if not sel.any():
            continue
        img = _base_image(mat)
        if img is None:
            out[sel] = _flat_color(mat)
            continue
        arr = _image_array(img)
        h, w = arr.shape[:2]
        u = np.mod(uvm[sel, 0], 1.0)
        v = np.mod(uvm[sel, 1], 1.0)
        px = np.clip((u * w).astype(int), 0, w - 1)
        py = np.clip((v * h).astype(int), 0, h - 1)
        out[sel] = arr[py, px]
    return out


def hsv(rgb: np.ndarray):
    mx = rgb.max(1)
    mn = rgb.min(1)
    d = mx - mn
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    dd = np.maximum(d, 1e-6)
    h = np.where(mx == r, ((g - b) / dd) % 6.0, np.where(mx == g, (b - r) / dd + 2.0, (r - g) / dd + 4.0)) / 6.0
    h = np.where(d < 1e-6, 0.0, h)
    return h, s, mx


def hue_dist(h, h0: float):
    d = np.abs(h - h0) % 1.0
    return np.minimum(d, 1.0 - d)


def dominant_hue(h, s, v, area) -> float:
    """Matiz mais comum (por área) entre as faces bem saturadas: a cor da lataria."""
    sel = (s > 0.35) & (v > 0.35)
    hist, edges = np.histogram(h[sel], bins=100, range=(0.0, 1.0), weights=area[sel])
    k = int(np.argmax(hist))
    return float((edges[k] + edges[k + 1]) * 0.5)


def rel_pos(o, dims):
    """Centro das faces relativo ao carro: yf (0 = traseira, 1 = frente), zf (0 = chão, 1 = teto),
    xf (0 = meio, 1 = lateral), e a normal."""
    L, W, H = dims
    ctr, nrm, area, _uv = K.face_data(o)
    return ctr[:, 1] / L, ctr[:, 2] / H, np.abs(ctr[:, 0]) / (W * 0.5), nrm, area


def classify_painted(o, dims, belt: float = 0.56, vinyl: bool = False, grille=None) -> list:
    """Modelo de textura pintada única (illustros): lataria = matiz dominante; vidro = cinza acima da
    linha da janela; faróis/placa = claros nas pontas; lanternas = vermelho saturado na traseira."""
    rgb = face_rgb(o)
    h, s, v = hsv(rgb)
    yf, zf, xf, nrm, area = rel_pos(o, dims)
    body_h = dominant_hue(h, s, v, area)
    n = len(h)
    cls = np.full(n, "grey", dtype=object)
    dark = v < 0.13
    neutral = (s < 0.25) & ~dark
    sat = (s >= 0.25) & ~dark
    cls[dark] = "plastic"
    cls[dark & (nrm[:, 2] < -0.5) & (zf < 0.35)] = "under"
    cls[neutral & (v >= 0.6)] = "chrome"
    cls[neutral & (v < 0.6)] = "grey"
    cls[neutral & (zf > belt) & (v < 0.9) & (yf > 0.04) & (yf < 0.92)] = "glass"
    ends = (yf > 0.93) | (yf < 0.06)
    cls[neutral & (v > 0.7) & ends & (xf < 0.42) & (zf < belt)] = "plate"
    cls[neutral & (v > 0.7) & (yf > 0.93) & (xf >= 0.42) & (zf < belt)] = "lamp_white"
    body = sat & (hue_dist(h, body_h) < 0.06)
    cls[sat & ~body] = "grey"
    cls[body] = K.PAINT
    if vinyl:
        bv = float(np.median(v[body])) if body.any() else 0.7
        cls[body & (v < bv * 0.6) & (zf > belt)] = "vinyl"
    red = sat & (s > 0.5) & (hue_dist(h, 0.0) < 0.035) & (hue_dist(h, body_h) > 0.03)
    cls[red & (yf < 0.5)] = "lamp_red"
    cls[red & (yf >= 0.5)] = "lamp_amber"
    if grille is not None:
        # frente entre o para-choque e o capô: grade lisa (o emblema some, mesmo pintado) e faróis nas pontas;
        # fora dessa faixa nada é farol (o cromo claro do para-choque virava "farol")
        z0, z1, lamp_x = grille
        cls[cls == "lamp_white"] = "chrome"
        front = (yf > 0.955) & (zf > z0) & (zf < z1) & (nrm[:, 1] > 0.3) & (cls != "plate")
        zone = front & ((cls != K.PAINT) | (xf < lamp_x * 0.8))
        cls[zone] = "grille"
        cls[zone & (xf >= lamp_x)] = "lamp_white"
    print(f"[classify] matiz da lataria={body_h:.3f}; classes:", _count(cls))
    return list(cls)


def classify_by_value(o, dark_cls: str, mid_cls: str, light_cls: str, lo: float = 0.13, hi: float = 0.55) -> list:
    """Só pelo brilho da textura: escuro / médio / claro (pneu x aro, plástico x cromo)."""
    _h, _s, v = hsv(face_rgb(o))
    return [dark_cls if x < lo else (light_cls if x >= hi else mid_cls) for x in v]


def classify_lights(o, dims) -> list:
    """Peça de faróis e lanternas: vermelho = lanterna, âmbar = pisca, claro = farol na frente / lanterna atrás."""
    h, s, v = hsv(face_rgb(o))
    yf = rel_pos(o, dims)[0]
    out = []
    for hh, ss, vv, y in zip(h, s, v, yf):
        if vv < 0.12:
            out.append("tail_dark" if y < 0.5 else "plastic")
        elif ss > 0.45 and hue_dist(np.array([hh]), 0.0)[0] < 0.05:
            out.append("lamp_red")
        elif ss > 0.45 and 0.05 <= hh <= 0.17:
            out.append("lamp_amber")
        elif vv > 0.6:
            out.append("lamp_white" if y >= 0.5 else "lamp_red")
        else:
            out.append("chrome")
    return out


def classify_glass_lights(o, dims, belt: float = 0.58) -> list:
    """Peça de vidros + lentes (SUV): vermelho = lanterna, âmbar = pisca; abaixo da linha da janela a lente
    vira farol (frente) ou lanterna (trás); acima, vidro."""
    h, s, v = hsv(face_rgb(o))
    yf, zf = rel_pos(o, dims)[:2]
    out = []
    red = (s > 0.45) & (hue_dist(h, 0.0) < 0.05) & (v > 0.2)
    amber = (s > 0.45) & (h >= 0.05) & (h <= 0.17) & (v > 0.2)
    for k in range(len(h)):
        if red[k]:
            out.append("lamp_red" if yf[k] < 0.5 else "lamp_amber")
        elif amber[k]:
            out.append("lamp_amber")
        elif v[k] < 0.1:
            out.append("plastic")
        elif zf[k] < belt:
            out.append("lamp_white" if yf[k] > 0.5 else "lamp_red")
        else:
            out.append("glass")
    return out


def classify_by_position(o, dims, front_cls: str, rear_cls: str, mid_cls: str, front: float = 0.85, rear: float = 0.15) -> list:
    yf = rel_pos(o, dims)[0]
    return [front_cls if y >= front else (rear_cls if y <= rear else mid_cls) for y in yf]


def _count(cls) -> dict:
    u, c = np.unique(np.asarray(cls, dtype=str), return_counts=True)
    return {str(a): int(b) for a, b in zip(u, c)}
