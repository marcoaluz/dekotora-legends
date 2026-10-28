"""T-242 (ampliação): murais estilo anime do Marco (gerados por ele no Gemini; exceção registrada em docs/DECISOES.md).
PROPOSTA para o Marco aprovar: gera a arte 2048 x 512 + emissão e a folha de contato; NÃO entra no jogo ainda.

Uso (raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t242_anime.py -- [--grid] [--sheet PASTA_ABS]
  --grid: folha com régua (x 0..4, y 0..1) para marcar os pontos de brilho; --sheet: folha de aprovação (dia, noite,
  máscara do brilho) nessa pasta.
Saída: blender/renders/t242/anime/<id>_<r|l>.png + _emit.png (fora do Git). Determinístico.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402

from lib import paint2d as p  # noqa: E402
from lib import t242_anime as A  # noqa: E402
from lib import t242_photo as PH  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "blender", "renders", "t242", "anime")
W, H = 2048, 512
EMIT_SCALE = 4
DIM = 0.2
_IMG = {}


def _args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return {"grid": "--grid" in a, "sheet": a[a.index("--sheet") + 1] if "--sheet" in a else ""}


def image(name):
    if name not in _IMG:
        _IMG[name] = PH.load(PH.find_source(ROOT, name))
    return _IMG[name]


def build(pid, side):
    spec = A.ARTS[(pid, side)]
    col = PH.tone(PH.fit(image(spec["src"]), spec["box"], W, H, stretch_max=1.12), **A.TONE)
    g = PH.Glow(W, H)
    for sh in spec["glow"]:
        if sh[0] == "key":
            g.key(col, *sh[1:])
        else:
            getattr(g, sh[0])(*sh[1:])
    em = PH.emission(col, g, DIM, EMIT_SCALE)
    mask = np.clip(p.downsample(g.e, EMIT_SCALE), 0, 1)
    os.makedirs(OUT, exist_ok=True)
    stem = os.path.join(OUT, f"{pid}_{side.lower()}")
    p.save_png(col, stem + ".png")
    p.save_png(em, stem + "_emit.png")
    return col, em, mask


def _grid(col):
    out = col.copy()
    for k in range(1, 40):
        x = int(k * H / 10)
        if x < W:
            out[:, x:x + 1] = [1, 1, 0] if k % 10 == 0 else [0.4, 0.4, 0.4]
    for k in range(1, 10):
        y = int(k * H / 10)
        out[y:y + 1, :] = [1, 1, 0] if k == 5 else [0.4, 0.4, 0.4]
    return out


def _up(a, k):
    return np.repeat(np.repeat(a, k, 0), k, 1)


def main():
    a = _args()
    rows = []
    for pid in A.pieces():
        for side in ("R", "L"):
            col, em, mask = build(pid, side)
            if a["grid"]:
                rows.append(_grid(col)[::2, ::2])
            else:
                night = PH.night(col, em)
                rows.append(np.concatenate([col[::2, ::2], night[::2, ::2], _up(mask, EMIT_SCALE)[::2, ::2]], 1))
            print(f"[t242-anime] {pid} {side}")
    if a["sheet"] or a["grid"]:
        gap = np.zeros((6, rows[0].shape[1], 3), np.float32)
        sheet = np.concatenate([r for row in rows for r in (row, gap)][:-1], 0)
        d = a["sheet"] or OUT
        os.makedirs(d, exist_ok=True)
        name = "anime_regua.png" if a["grid"] else "anime_proposta.png"
        p.save_png(sheet, os.path.join(d, name))
        print("[t242-anime] folha", os.path.join(d, name))
    print("[t242-anime] OK")


main()
