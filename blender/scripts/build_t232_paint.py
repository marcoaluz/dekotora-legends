"""Pinturas da T-232: 12 murais (lado direito e esquerdo diferentes), 12 traseiras e 9 tetos, arte NOSSA feita por
código (numpy, lib/paint2d.py + lib/t232_*.py), kanji na fonte de pincel Yuji Syuku (OFL) conferida na tabela da fonte.

Uso (raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t232_paint.py -- [--only id1,id2] [--sheets PASTA_ABS] [--no-art]
Saídas: game/assets/vehicles/dekotora/paint_t232/{mural,rear,roof}/*.png (cor + `_emit` para a noite).
  --sheets: folhas de contato das artes (dia e "noite" = só a emissão) nessa pasta.
  --no-art: só as letras (blender/renders/t232/glyphs.npz) e as folhas, sem regravar as artes.
Determinístico: mesmas entradas, mesmos bytes (PNG gravado pelo próprio paint2d, sem metadados).
Depois: `bash tools/import_textures_3d.sh game/assets/vehicles/dekotora/paint_t232/mural ...` (VRAM + mipmaps).
"""
import importlib
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402

from lib import paint2d as p  # noqa: E402
from lib import t232_glyphs, t232_rear, t232_registry as REG, t232_roof, t232_text, t232_texts  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GLYPHS = os.path.join(ROOT, "blender", "renders", "t232", "glyphs.npz")
SS = 2


def _args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"only": None, "sheets": None, "art": True}
    i = 0
    while i < len(a):
        if a[i] == "--only":
            out["only"] = set(a[i + 1].split(","))
            i += 1
        elif a[i] == "--sheets":
            out["sheets"] = a[i + 1]
            i += 1
        elif a[i] == "--no-art":
            out["art"] = False
        i += 1
    return out


def _save(col, emit, rel):
    path = os.path.join(ROOT, REG.OUT_DIR, rel)
    p.save_png(col, path)
    p.save_png(emit, path[:-4] + "_emit.png")


def render_all(only=None):
    glyphs = t232_text.load(GLYPHS)
    arts = {}
    for pid, mod, fn, *_ in REG.MURALS:
        for side in ("R", "L"):
            if only and pid not in only:
                continue
            t = time.time()
            cv = p.Canvas(4.0, REG.MURAL_PX[1], SS)
            getattr(importlib.import_module("lib." + mod), fn)(cv, side)
            col, emit = cv.result(emit_scale=4)             # emissão 512 x 128: luz difusa, menos MB no APK
            _save(col, emit, f"mural/{pid}_{side.lower()}.png")
            arts[(pid, side)] = (col, emit)
            print(f"[t232] {pid} {side} {time.time() - t:.1f} s")
    for pid, kind, *_ in REG.REARS:
        if only and pid not in only:
            continue
        cv = p.Canvas(REG.REAR_PX[0] / REG.REAR_PX[1], REG.REAR_PX[1], SS)
        t232_rear.make(cv, kind, glyphs)
        col, emit = cv.result(emit_scale=2)
        _save(col, emit, f"rear/{pid}.png")
        arts[(pid, "R")] = (col, emit)
        print(f"[t232] {pid}")
    for pid, idx, *_ in REG.ROOFS:
        if only and pid not in only:
            continue
        for k, (w, h) in REG.ROOF_PX.items():
            cv = p.Canvas(w / h, h, SS)
            t232_roof.make(cv, idx, glyphs)
            col, emit = cv.result(emit_scale=2)
            _save(col, emit, f"roof/{pid}_{k}.png")
            arts[(pid, k)] = (col, emit)
        print(f"[t232] {pid}")
    return arts


def _night(col, emit):
    """Como a arte fica de noite no jogo, de forma aproximada: pouca luz + a emissão."""
    k = col.shape[0] // emit.shape[0]
    up = np.repeat(np.repeat(emit, k, 0), k, 1)[: col.shape[0], : col.shape[1]]
    return np.clip(col * 0.12 + up * 1.1, 0, 1)


def _scale(a, w):
    """Reduz por média de blocos (inteiro) até ~w de largura."""
    k = max(1, a.shape[1] // w)
    return p.downsample(a, k) if k > 1 else a


def _gap(n, w, c=0.08):
    return np.full((n, w, 3), c, np.float32)


def sheets(out_dir, arts):
    os.makedirs(out_dir, exist_ok=True)
    for night in (False, True):
        tag = "noite" if night else "dia"
        for part in range(3):
            rows = []
            for pid, *_ in REG.MURALS[part * 4:(part + 1) * 4]:
                for side in ("R", "L"):
                    if (pid, side) not in arts:
                        continue
                    c, e = arts[(pid, side)]
                    img = _scale(_night(c, e) if night else c, 768)
                    rows += [img, _gap(10, img.shape[1])]
                rows += [_gap(20, rows[0].shape[1], 0.0)]
            if rows:
                p.save_png(np.concatenate(rows), os.path.join(out_dir, f"arte_murais_{part + 1}_{tag}.png"))
        tiles = []
        for pid, *_ in REG.REARS:
            if (pid, "R") in arts:
                c, e = arts[(pid, "R")]
                tiles.append(_scale(_night(c, e) if night else c, 320))
        if tiles:
            h = tiles[0].shape[0]
            rows = []
            for r in range(0, len(tiles), 6):
                row = []
                for t in tiles[r:r + 6]:
                    row += [t, _gap(h, 8)]
                rows += [np.concatenate(row, 1), _gap(8, sum(x.shape[1] for x in row))]
            wmax = max(x.shape[1] for x in rows)
            rows = [np.concatenate([x, _gap(x.shape[0], wmax - x.shape[1])], 1) if x.shape[1] < wmax else x for x in rows]
            p.save_png(np.concatenate(rows), os.path.join(out_dir, f"arte_traseiras_{tag}.png"))
        cols = []
        for pid, *_ in REG.ROOFS:
            if (pid, "long") not in arts:
                continue
            lo = _scale(_night(*arts[(pid, "long")]) if night else arts[(pid, "long")][0], 128)
            sh = _scale(_night(*arts[(pid, "short")]) if night else arts[(pid, "short")][0], 128)
            sh = np.concatenate([sh, _gap(lo.shape[0] - sh.shape[0], sh.shape[1], 0.0)])
            cols += [lo, _gap(lo.shape[0], 4), sh, _gap(lo.shape[0], 14, 0.0)]
        if cols:
            p.save_png(np.concatenate(cols, 1), os.path.join(out_dir, f"arte_tetos_{tag}.png"))


def main():
    a = _args()
    t = time.time()
    n = t232_glyphs.build(t232_texts.all_chars(), GLYPHS)
    print(f"[t232] letras: {len(n)} caracteres conferidos na fonte (sem tofu) -> {GLYPHS}")
    arts = render_all(a["only"]) if a["art"] or a["sheets"] else {}
    if a["sheets"]:
        sheets(a["sheets"], arts)
    print(f"[t232] OK em {time.time() - t:.0f} s")


main()
