"""T-242: murais e traseiras a partir de obras prontas de domínio público / CC0 (ukiyo-e, biombos), com o brilho
noturno desenhado à mão só nos pontos escolhidos (olhos, lua, sol, feixe, molduras de neon, kanji).

Uso (raiz do projeto):
  python -I tools/fetch_t242_sources.py            (uma vez: baixa as obras para blender/renders/t242/fontes/)
  blender -b --factory-startup -P blender/scripts/build_t242_ukiyoe.py -- [--only id1,id2] [--sheets PASTA_ABS]
Saída: os MESMOS arquivos da T-232 (game/assets/vehicles/dekotora/paint_t232/{mural,rear}/<id>[_l|_r].png + _emit).
  --sheets: folhas antes/depois (dia, noite e a máscara do brilho) nessa pasta.
Antes de sobrescrever, guarda a arte antiga em blender/renders/t242/antes/ (para as folhas "antes").
Depois: bash tools/import_textures_3d.sh game/assets/vehicles/dekotora/paint_t232/mural game/assets/vehicles/dekotora/paint_t232/rear
Determinístico (mesmas imagens de entrada, mesmos bytes).
"""
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402

from lib import paint2d as p  # noqa: E402
from lib import t232_kit as K  # noqa: E402
from lib import t232_registry as R232  # noqa: E402
from lib import t232_text as TX  # noqa: E402
from lib import t232_texts as TT  # noqa: E402
from lib import t242_photo as PH  # noqa: E402
from lib import t242_registry as REG  # noqa: E402
from lib import t242_sources as SRC  # noqa: E402
from lib.paint2d import hexc  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, R232.OUT_DIR)
BEFORE = os.path.join(ROOT, "blender", "renders", "t242", "antes")
GLYPHS = os.path.join(ROOT, "blender", "renders", "t232", "glyphs.npz")
SS = 2
REAR_BG = {"tora": [(0, "#14060a"), (0.6, "#4a1408"), (1, "#8a3a10")],
           "kabuki": [(0, "#14061e"), (0.6, "#4a0c30"), (1, "#8a1a4a")],
           "bijin": [(0, "#08061e"), (0.6, "#2a1450"), (1, "#5a2a6a")]}
REAR_RAYS = {"tora": "#ffb347", "kabuki": "#ff6fae", "bijin": "#c9a7ff"}
REAR_INK = {"tora": ("#ffe14a", "#3a0e00", "#ff9a3c"), "kabuki": ("#ffffff", "#c0102a", "#ff4fb4"),
            "bijin": ("#ffffff", "#8a0f50", "#ff6fae")}

_IMG = {}


def _args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"only": None, "sheets": None}
    for i, x in enumerate(a):
        if x == "--only":
            out["only"] = set(a[i + 1].split(","))
        elif x == "--sheets":
            out["sheets"] = a[i + 1]
    return out


def image(key):
    if key not in _IMG:
        _IMG.clear()                                    # uma obra por vez na memória
        _IMG[key] = PH.load(PH.find_source(ROOT, SRC.info(key)["file"]))
    return _IMG[key]


def box3(box, img, aspect):
    """(x0, y0, x1) -> (x0, y0, x1, y1) com a proporção da área."""
    if len(box) == 4:
        return box
    H, W = img.shape[:2]
    x0, y0, x1 = box
    return (x0, y0, x1, y0 + (x1 - x0) * W / (aspect * H))


def photo(key, box, w, h, tone, stretch_max=1.12):
    img = image(key)
    return PH.tone(PH.fit(img, box3(box, img, w / h), w, h, stretch_max), **tone)


def to_canvas(cv, rgb, x0=0.0, y0=0.0):
    """Cola uma imagem (na resolução final) na tela do paint2d (supersample) a partir de (x0, y0)."""
    up = np.repeat(np.repeat(rgb, cv.ss, 0), cv.ss, 1)
    r0, c0 = int(round(y0 * cv.h)), int(round(x0 * cv.h))
    cv.rgb[r0:r0 + up.shape[0], c0:c0 + up.shape[1]] = up[: cv.h - r0, : cv.w - c0]


def neon_rect(cv, x0, y0, x1, y1, color, w=0.006):
    pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)]
    lay = p.S(cv, pts, w)
    cv.add(p.glow(cv, lay, w * 1.5), hexc(color), 0.8, neon=1.0)
    cv.fill(p.S(cv, pts, w * 1.6), hexc("#0a0608"))
    cv.fill(lay, hexc(color), neon=1.0)
    cv.fill(p.S(cv, pts, w * 0.35), hexc("#ffffff"), neon=0.6)


def compose(spec, w, h):
    aspect = w / h
    cv = p.Canvas(aspect, h, SS)
    tone = dict(spec.get("tone") or {})
    if spec["layout"] == "crop":
        to_canvas(cv, photo(spec["src"], spec["box"], w, h, tone, spec.get("stretch", 1.12)))
    elif spec["layout"] == "tiles":
        K.sky(cv, [(0, "#0c060c"), (1, "#1a0a14")])
        n, m = len(spec["tiles"]), 0.035
        tw = (aspect - (n + 1) * m) / n
        th = 1 - 2 * m
        for i, (key, box) in enumerate(spec["tiles"]):
            x0 = m + i * (tw + m)
            pw, ph = int(round(tw * h)), int(round(th * h))
            to_canvas(cv, photo(key, box, pw, ph, tone), x0, m)
            neon_rect(cv, x0, m, x0 + pw / h, m + ph / h, spec["frame"])
    elif spec["layout"] == "rear":
        kind = spec["kind"]
        K.sky(cv, REAR_BG[kind])
        K.rays(cv, aspect / 2, 0.5, 18, REAR_RAYS[kind], 0.12, 1.2)
        pw_f, m = 0.62, 0.045
        pw, ph = int(round(pw_f * h)), int(round((1 - 2 * m) * h))
        x0 = (aspect - pw / h) / 2
        to_canvas(cv, photo(spec["src"], spec["box"], pw, ph, tone), x0, m)
        gold = [(x0, m), (x0 + pw / h, m), (x0 + pw / h, m + ph / h), (x0, m + ph / h), (x0, m)]
        cv.fill(p.S(cv, gold, 0.011), hexc("#3a2400"))
        cv.fill(p.S(cv, gold, 0.006), hexc("#f2c14e"))
        glyphs = TX.load(GLYPHS)
        ink, edge, halo = REAR_INK[kind]
        for txt, x in ((TT.REAR[kind][0], 0.16), (TT.REAR[kind][1], aspect - 0.16)):
            size = min(0.14, 0.46 / len(txt))
            TX.draw(cv, glyphs, txt, x, 0.08 + size * 0.5, size, ink=ink, edge=edge, edge_w=0.012, halo=halo,
                    halo_w=0.008, neon=0.6)
        cv.fill(p.mul(p.S(cv, [(aspect / 2, 0.0), (aspect / 2, 1.0)], 0.0022), 0.85), hexc("#0a0606"))
        cv.fill(p.mul(p.S(cv, [(aspect / 2 + 0.004, 0.0), (aspect / 2 + 0.004, 1.0)], 0.0012), 0.5), hexc("#ffffff"))
        K.frame(cv, w=0.01)
    col = np.clip(p.downsample(cv.rgb, SS), 0, 1)
    neon = np.clip(p.downsample(cv.neon, SS), 0, 1)
    g = PH.Glow(w, h)
    g.e += neon
    for s in spec.get("glow", []):
        kind, args = s[0], s[1:]
        if kind == "key":
            x, y, rx, ry, color, k, thr = args
            g.key(col, x, y, rx, ry, color, k, thr)
        else:
            getattr(g, kind)(*args)
    return col, g


def build(pid, side):
    spec = REG.ARTS[(pid, side)]
    rear = pid.startswith("rearpaint_")
    w, h = REG.REAR_PX if rear else REG.MURAL_PX
    col, g = compose(spec, w, h)
    emit = PH.emission(col, g, REG.DIM, REG.REAR_EMIT_SCALE if rear else REG.MURAL_EMIT_SCALE)
    rel = REG.rel_path(pid, side)
    dst = os.path.join(OUT, rel)
    for f in (dst, dst[:-4] + "_emit.png"):                    # guarda a arte da T-232 uma vez (folha "antes")
        b = os.path.join(BEFORE, os.path.relpath(f, OUT))
        if os.path.exists(f) and not os.path.exists(b):
            os.makedirs(os.path.dirname(b), exist_ok=True)
            shutil.copyfile(f, b)
    p.save_png(col, dst)
    p.save_png(emit, dst[:-4] + "_emit.png")
    return col, emit, g.e


# ---------------------------------------------------------------------------------------------- folhas
def _fit_w(a, w):
    """Redimensiona (h, w0, 3) para largura w mantendo a proporção (reamostragem simples, só para a folha)."""
    h = int(round(a.shape[0] * w / a.shape[1]))
    return PH.resample(a, (0, 0, a.shape[1], a.shape[0]), w, h)


def _bar(h, w, c=0.06):
    return np.full((h, w, 3), c, np.float32)


def sheet(pid, arts, out_dir):
    """Uma folha por peça. Cada lado: [antes dia | depois dia] em cima, [depois noite | máscara do brilho] embaixo."""
    rows = []
    for side in ("R", "L"):
        if (pid, side) not in arts:
            continue
        col, emit, glow = arts[(pid, side)]
        W = 1000 if not pid.startswith("rearpaint_") else 600
        rel = REG.rel_path(pid, side)
        bf = os.path.join(BEFORE, rel)
        before = PH.load(bf) if os.path.exists(bf) else np.zeros_like(col)
        be = bf[:-4] + "_emit.png"
        before_n = PH.night(before, PH.load(be)) if os.path.exists(be) else np.zeros_like(before)
        mask = np.clip(col * 0.12 + glow, 0, 1)
        tiles = [_fit_w(x, W) for x in (before, col, before_n, PH.night(col, emit), np.zeros_like(col), mask)]
        hh = tiles[0].shape[0]
        g = _bar(hh, 12)
        for a, b in ((0, 1), (2, 3), (4, 5)):
            if a == 4:
                continue
            rows += [np.concatenate([tiles[a], g, tiles[b]], 1), _bar(12, 2 * W + 12)]
        rows += [np.concatenate([_bar(hh, W, 0.0), g, tiles[5]], 1), _bar(30, 2 * W + 12, 0.0)]
    p.save_png(np.concatenate(rows), os.path.join(out_dir, f"{pid}.png"))


def main():
    a = _args()
    t = time.time()
    arts = {}
    for (pid, side) in REG.ARTS:
        if a["only"] and pid not in a["only"]:
            continue
        t1 = time.time()
        arts[(pid, side)] = build(pid, side)
        print(f"[t242] {pid} {side} {time.time() - t1:.1f} s")
    if a["sheets"]:
        os.makedirs(a["sheets"], exist_ok=True)
        for pid in REG.pieces():
            if any(k[0] == pid for k in arts):
                sheet(pid, arts, a["sheets"])
    print(f"[t242] OK em {time.time() - t:.0f} s")


main()
