"""T-266: imagens "Praia" do Marco (docs/Murais/Paria/) viram 3 murais (um desenho por lado), 2 pinturas da traseira e
1 pintura do teto no grupo Wallpapers. Recortes, rosto (focus) e brilho noturno em `lib/t266_praia.py`.

Uso (raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t266_praia.py -- [--sheet PASTA_ABS] [--install]
  sem --install: só as folhas (PASTA/praia_proposta.png e praia_recortes.png) e a arte em blender/renders/t266/arte;
  com --install: grava a arte em game/assets/vehicles/dekotora/paint_wall/{mural,rear,roof}/ e a lista
  blender/renders/t266/praia.json; depois
    python -I tools/gen_t258_data.py --manifest blender/renders/t266/praia.json
    bash tools/import_textures_3d.sh game/assets/vehicles/dekotora/paint_wall/mural game/assets/vehicles/dekotora/paint_wall/rear game/assets/vehicles/dekotora/paint_wall/roof
Determinístico (mesmas imagens = mesmos bytes).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402

from lib import paint2d as p  # noqa: E402
from lib import t242_photo as PH  # noqa: E402
from lib import t266_praia as R  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GAME = os.path.join(ROOT, "game", "assets", "vehicles", "dekotora", "paint_wall")
RAW = os.path.join(ROOT, "blender", "renders", "t266")
DIM = 0.2                                     # a arte inteira à noite (luzinhas do baú), como T-232/T-258
ES = {"mural": 4, "rear": 2, "roof": 2}       # emissão em 1/ES da arte
TONE = {"paper": 0.0, "sat": 1.0, "gamma": 1.06, "lo": 0.1, "hi": 99.9, "gain": 0.95}   # já é muito clara/saturada
# proporções reais das faces (truck/sockets/*.json, rect w/h) para a folha "como fica em cada baú"
RECTS = {"mural": [("canter", 2.565), ("leve", 2.824), ("leve longo", 3.347), ("alu", 3.663), ("rosa", 4.045),
                   ("base", 4.114), ("base longo", 4.759), ("longo", 5.794), ("carreta", 7.054)],
         "rear": [("alu/rosa", 1.071), ("canter", 1.151), ("leve/longo/carreta", 1.213), ("base", 1.263)],
         "roof": [("carreta", 0.182), ("longo", 0.232), ("base", 0.276), ("leve", 0.406), ("canter", 0.451)]}


def _args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    get = lambda k, d="": a[a.index(k) + 1] if k in a else d   # noqa: E731
    return {"sheet": get("--sheet"), "install": "--install" in a}


def color_glow(col, spots):
    """Acende só as cores escolhidas (flor roxa, drinque, coração, lanterna, kanji) dentro de cada elipse."""
    h, w = col.shape[:2]
    ys = (np.arange(h, dtype=np.float32) + 0.5) / h
    xs = (np.arange(w, dtype=np.float32) + 0.5) / h            # x em unidades da altura (elipse redonda)
    X, Y = np.meshgrid(xs, ys)
    out = np.zeros_like(col)
    for fx, fy, rx, ry, target, tol, k in spots:
        u, v = (X - fx * w / h) / rx, (Y - fy) / ry
        inside = PH.smooth(1.0, 0.7, np.sqrt(u * u + v * v))
        d = np.linalg.norm(col - np.array(target, np.float32), axis=-1)
        m = PH.smooth(tol, tol * 0.45, d) * inside
        out += col * m[..., None] * k
    return out


def uv_window(art, rect, focus, keep):
    """Mesma conta de PaintFit.uv_window (game/scripts/truck/paint_fit.gd), em frações (x, y, w, h)."""
    lo = 0.8 if keep is None else keep
    hi = 1.25 if keep is None else 1.0 / lo
    c = min(max(rect, art * lo), art * hi)
    if c >= art:
        hf = art / c
        return 0.0, min(max(focus[1] - hf / 2, 0.0), 1.0 - hf), 1.0, hf, rect / c
    wf = c / art
    return min(max(focus[0] - wf / 2, 0.0), 1.0 - wf), 0.0, wf, 1.0, rect / c


def build_art(spec):
    img = PH.load(os.path.join(ROOT, R.SRC_DIR, spec["src"]))
    w, h = spec["size"]
    col = PH.tone(PH.resample(img, spec["box"], w, h), **TONE)
    glow = color_glow(col, spec.get("glow", []))
    if spec.get("rot"):
        col, glow = np.ascontiguousarray(np.rot90(col, 1)), np.ascontiguousarray(np.rot90(glow, 1))
    return col, glow


TILE_H = {"mural": 150, "rear": 330, "roof": 520}
SHEET_W = 2400


def window_strip(col, kind, focus, keep):
    """Uma miniatura por baú (na proporção real da face): o pedaço que o jogo mostra ali (mesma conta do jogo).
    Esticado = moldura vermelha. Quebra a linha em SHEET_W px."""
    H, W = col.shape[:2]
    hgt = TILE_H[kind]
    lines, line, lw = [], [], 0
    for _name, ra in RECTS[kind]:
        x, y, wf, hf, st = uv_window(W / H, ra, focus, keep)
        tw = max(8, int(round(hgt * ra)))
        t = PH.resample(col, (x * W, y * H, (x + wf) * W, (y + hf) * H), tw, hgt)
        frame = (0.9, 0.15, 0.15) if abs(st - 1.0) > 0.02 else (0.25, 0.25, 0.25)
        t = np.pad(t, ((3, 3), (3, 3), (0, 0)))
        t[:3], t[-3:], t[:, :3], t[:, -3:] = frame, frame, frame, frame
        t = np.pad(t, ((0, 8), (0, 8), (0, 0)), constant_values=0.08)
        if line and lw + t.shape[1] > SHEET_W:
            lines.append(line)
            line, lw = [], 0
        line.append(t)
        lw += t.shape[1]
    lines.append(line)
    rows = [np.concatenate(ln, 1) for ln in lines]
    wmax = max(r.shape[1] for r in rows)
    return np.concatenate([np.pad(r, ((0, 0), (0, wmax - r.shape[1]), (0, 0)), constant_values=0.08) for r in rows], 0)


def save_jpg(arr, path, quality=88):
    """Folha de revisão em JPG (bem mais leve que PNG para foto) pelo próprio Blender."""
    import bpy
    a = np.clip(np.asarray(arr, np.float32), 0, 1)
    h, w = a.shape[:2]
    rgba = np.concatenate([a[::-1], np.ones((h, w, 1), np.float32)], -1)
    img = bpy.data.images.new("t266_sheet", w, h, alpha=False)
    try:
        img.colorspace_settings.name = "sRGB"
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = path
        img.file_format = "JPEG"
        try:
            img.save(quality=quality)
        except TypeError:                                   # Blender antigo: sem o parâmetro
            img.save()
    finally:
        bpy.data.images.remove(img)


def _fit_w(a, w):
    return PH.resample(a, (0, 0, a.shape[1], a.shape[0]), w, max(1, int(round(w * a.shape[0] / a.shape[1]))))


def main():
    a = _args()
    out_root = GAME if a["install"] else os.path.join(RAW, "arte")
    manifest, rows, crops = [], [], []
    for pc in R.PIECES:
        kind = pc["kind"]
        entry = {"id": pc["id"], "kind": kind, "name": pc["id"], "label": pc["label"], "origin": R.ORIGIN,
                 "price": pc["price"], "fame": pc["fame"], "sides": {}}
        for side, spec in pc["sides"].items():
            col, glow = build_art(spec)
            em = np.clip(p.downsample(col * DIM + glow, ES[kind]), 0, 1)
            sub = os.path.join(out_root, kind)
            os.makedirs(sub, exist_ok=True)
            stem = os.path.join(sub, pc["id"] + ("_" + side.lower() if kind == "mural" else ""))
            p.save_png(col, stem + ".png", filtered=True)      # PNG menor no Git (mesmos pixels; o APK leva o ETC2)
            p.save_png(em, stem + "_emit.png", filtered=True)
            H, W = col.shape[:2]
            art = {"stem": os.path.relpath(stem, ROOT).replace(os.sep, "/"), "aspect": round(W / H, 4), "px": [W, H],
                   "focus": [round(spec["focus"][0], 3), round(spec["focus"][1], 3)]}
            if spec.get("keep"):
                art["keep"] = spec["keep"]
            entry["sides"][side] = [art]
            night = PH.night(col, em)
            if kind == "roof":
                col_v, night_v = np.rot90(col, -1), np.rot90(night, -1)     # na folha: de volta deitada
            else:
                col_v, night_v = col, night
            rows.append(np.concatenate([_fit_w(col_v, 760), np.zeros((_fit_w(col_v, 760).shape[0], 8, 3), np.float32),
                                        _fit_w(night_v, 760)], 1))
            crops.append(window_strip(col, kind, spec["focus"], spec.get("keep")))
            print(f"[t266] {pc['id']} {side} {W}x{H} <- {spec['src']}")
        manifest.append(entry)
    os.makedirs(RAW, exist_ok=True)
    if a["install"]:
        with open(os.path.join(RAW, "praia.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=1)
    if a["sheet"]:
        os.makedirs(a["sheet"], exist_ok=True)
        for name, items in (("praia_proposta.jpg", rows), ("praia_recortes.jpg", crops)):
            wmax = max(r.shape[1] for r in items)
            items = [np.pad(r, ((0, 10), (0, wmax - r.shape[1]), (0, 0)), constant_values=0.08) for r in items]
            save_jpg(np.concatenate(items, 0), os.path.join(a["sheet"], name))
    print(f"[t266] OK: {len(manifest)} pintura(s); {'instalado no jogo' if a['install'] else 'só proposta'}")


main()
