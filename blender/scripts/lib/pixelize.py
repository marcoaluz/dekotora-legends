"""Pós-processo numpy: paleta, alfa binário, contorno."""
from __future__ import annotations

import numpy as np


def pixelize(hi: np.ndarray, scale: int, palette: np.ndarray, outline=None,
             alpha_cut: float = 0.5) -> np.ndarray:
    """
    hi: render em resolução scale× maior (h*scale, w*scale, 4).
    1) cada pixel vai para a cor mais próxima da paleta;
    2) cada bloco scale×scale vira 1 pixel: opaco se cobertura >= alpha_cut, cor = a mais frequente;
    3) contorno opcional nos pixels transparentes vizinhos de opacos.
    """
    H, W = hi.shape[0] // scale, hi.shape[1] // scale
    hi = hi[:H * scale, :W * scale]
    rgb, a = hi[..., :3], hi[..., 3]
    d = ((rgb[..., None, :] - palette[None, None, :, :]) ** 2).sum(-1)
    idx = d.argmin(-1)
    opaque = a >= 0.5
    blocks_a = opaque.reshape(H, scale, W, scale).mean(axis=(1, 3))
    counts = np.zeros((H, W, len(palette)), dtype=np.int32)
    ib = np.where(opaque, idx, -1).reshape(H, scale, W, scale)
    for k in range(len(palette)):
        counts[..., k] = (ib == k).sum(axis=(1, 3))
    out = np.zeros((H, W, 4), dtype=np.float32)
    solid = blocks_a >= alpha_cut
    out[solid, :3] = palette[counts.argmax(-1)][solid]
    out[solid, 3] = 1.0
    if outline is not None:
        o = solid
        n = np.zeros_like(o)
        n[1:] |= o[:-1]; n[:-1] |= o[1:]; n[:, 1:] |= o[:, :-1]; n[:, :-1] |= o[:, 1:]
        edge = n & ~o
        out[edge, :3] = outline
        out[edge, 3] = 1.0
    return out
