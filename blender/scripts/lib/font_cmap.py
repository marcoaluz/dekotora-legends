"""Quais caracteres uma fonte TTF/OTF tem de verdade (tabela `cmap`, formatos 4 e 12). Só biblioteca padrão.
Usado para garantir que nenhum kanji sai como "tofu" (o Blender desenha um glifo reserva quando falta o caractere)."""
from __future__ import annotations

import struct


def codepoints(path: str) -> set:
    with open(path, "rb") as f:
        data = f.read()
    num = struct.unpack(">H", data[4:6])[0]
    off = None
    for i in range(num):
        tag, _cs, o, _ln = struct.unpack(">4sIII", data[12 + 16 * i: 28 + 16 * i])
        if tag == b"cmap":
            off = o
    if off is None:
        return set()
    n = struct.unpack(">H", data[off + 2: off + 4])[0]
    out: set = set()
    for i in range(n):
        _pid, _eid, sub = struct.unpack(">HHI", data[off + 4 + 8 * i: off + 12 + 8 * i])
        s = off + sub
        fmt = struct.unpack(">H", data[s: s + 2])[0]
        if fmt == 4:
            segx2 = struct.unpack(">H", data[s + 6: s + 8])[0]
            seg = segx2 // 2
            ends = struct.unpack(">%dH" % seg, data[s + 14: s + 14 + segx2])
            starts = struct.unpack(">%dH" % seg, data[s + 16 + segx2: s + 16 + 2 * segx2])
            deltas = struct.unpack(">%dh" % seg, data[s + 16 + 2 * segx2: s + 16 + 3 * segx2])
            ro_pos = s + 16 + 3 * segx2
            ros = struct.unpack(">%dH" % seg, data[ro_pos: ro_pos + segx2])
            for k in range(seg):
                for c in range(starts[k], ends[k] + 1):
                    if c == 0xFFFF:
                        continue
                    if ros[k] == 0:
                        g = (c + deltas[k]) & 0xFFFF
                    else:
                        a = ro_pos + 2 * k + ros[k] + 2 * (c - starts[k])
                        g = struct.unpack(">H", data[a: a + 2])[0]
                        g = (g + deltas[k]) & 0xFFFF if g else 0
                    if g:
                        out.add(c)
        elif fmt == 12:
            ng = struct.unpack(">I", data[s + 12: s + 16])[0]
            for k in range(ng):
                a, b, g0 = struct.unpack(">III", data[s + 16 + 12 * k: s + 28 + 12 * k])
                for c in range(a, b + 1):
                    if g0 + (c - a):
                        out.add(c)
    return out


def missing(path: str, chars: str) -> str:
    cps = codepoints(path)
    return "".join(sorted({c for c in chars if c.strip() and ord(c) not in cps}))
