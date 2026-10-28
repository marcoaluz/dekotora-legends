"""T-258: pinturas do grupo "Wallpapers" (arte digital criada pelo Marco, ex.: no Gemini; não é pintura de museu).
Lê as imagens de docs/Murais/wallpaper/ pelo NOME do arquivo (guia em docs/CREDITOS_MURAIS.md):

  <nome>_mural_d.png + <nome>_mural_e.png   mural (lado direito e esquerdo, cada um com o seu desenho)   2048 x 512
  <nome>_traseira.png                       pintura da traseira (portas)                                1280 x 1024
  <nome>_teto.png                           pintura do teto (o alto da imagem = frente do caminhão)      512 x 2048
  <arquivo>_brilho.png (opcional)           máscara de brilho noturno (branco = acende). Sem ela, acende só o que já
                                            é luz forte e colorida na imagem (neon, lanterna, lua), nunca a pele.
<nome> = letras minúsculas, números e "_" (vira o id `wall_<nome>`). JPG também serve.

Uso (raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t258_wallpapers.py -- [--src PASTA] [--sheet PASTA_ABS] [--install]
  sem --install: só a folha de aprovação (docs/capturas_t258/wallpaper_proposta.png) e a arte em blender/renders/t258/;
  com --install: grava a arte no jogo (game/assets/vehicles/dekotora/paint_wall/{mural,rear,roof}/) e a lista
  blender/renders/t258/wallpapers.json; depois `python -I tools/gen_t258_data.py` (catálogo, .tres, textos) e
  `bash tools/import_textures_3d.sh game/assets/vehicles/dekotora/paint_wall/mural game/assets/vehicles/dekotora/paint_wall/rear game/assets/vehicles/dekotora/paint_wall/roof`.
O jogo nunca espelha a arte (kanji legível dos dois lados). Determinístico.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402

from lib import paint2d as p  # noqa: E402
from lib import t242_photo as PH  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GAME = os.path.join(ROOT, "game", "assets", "vehicles", "dekotora", "paint_wall")
RAW = os.path.join(ROOT, "blender", "renders", "t258")
KINDS = {  # sufixo -> (tipo, lado, tamanho final, escala da emissão)
    "mural_d": ("mural", "R", (2048, 512), 4), "mural_e": ("mural", "L", (2048, 512), 4),
    "traseira": ("rear", "R", (800, 640), 2), "teto": ("roof", "R", (256, 1024), 2),
}
PAT = re.compile(r"^([a-z0-9_]+?)_(mural_d|mural_e|traseira|teto)\.(png|jpe?g)$")
DIM = 0.2
TONE = {"paper": 0.0, "sat": 1.04, "gamma": 1.0, "lo": 0.2, "hi": 99.8}


def _args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    get = lambda k, d="": a[a.index(k) + 1] if k in a else d   # noqa: E731
    return {"src": get("--src", os.path.join(ROOT, "docs", "Murais", "wallpaper")), "sheet": get("--sheet"),
            "install": "--install" in a, "out": get("--out", "")}


def scan(src):
    """{nome: {sufixo: arquivo}} das imagens com nome no padrão (as outras são ignoradas e listadas)."""
    found, skipped = {}, []
    if not os.path.isdir(src):
        return found, skipped
    for f in sorted(os.listdir(src)):
        if f.lower().endswith(("_brilho.png", ".md")):
            continue
        m = PAT.match(f.lower())
        if not m:
            skipped.append(f)
            continue
        found.setdefault(m.group(1), {})[m.group(2)] = os.path.join(src, f)
    return found, skipped


def auto_glow(col):
    """Sem máscara: acende o que já é luz forte E colorida (neon, lanterna, lua amarela); pele e branco não."""
    L = col @ PH.LUMA
    sat = col.max(-1) - col.min(-1)
    m = PH.smooth(0.55, 0.8, L) * PH.smooth(0.35, 0.6, sat)
    return col * m[..., None] * 1.2


def build_one(path, size):
    img = PH.load(path)
    col = PH.tone(PH.fit(img, (0.0, 0.0, 1.0, 1.0), size[0], size[1], stretch_max=1.08), **TONE)
    mask = os.path.splitext(path)[0] + "_brilho.png"
    if os.path.exists(mask):
        mk = PH.fit(PH.load(mask), (0.0, 0.0, 1.0, 1.0), size[0], size[1], stretch_max=1.08) @ PH.LUMA
        glow = col * np.clip(mk, 0, 1)[..., None] * 1.3
    else:
        glow = auto_glow(col)
    return col, glow


def main():
    a = _args()
    found, skipped = scan(a["src"])
    for f in skipped:
        print("[t258] ignorado (nome fora do padrão):", f)
    out_root = a["out"] or (GAME if a["install"] else os.path.join(RAW, "arte"))
    manifest, rows = [], []
    for name, files in found.items():
        if ("mural_d" in files) != ("mural_e" in files):
            print("[t258] mural sem os 2 lados (precisa _mural_d e _mural_e):", name)
            files = {k: v for k, v in files.items() if not k.startswith("mural")}
        pieces = {}
        for suf, path in sorted(files.items()):
            kind, side, size, es = KINDS[suf]
            col, glow = build_one(path, size)
            em = np.clip(p.downsample(col * DIM + glow, es), 0, 1)
            pid = {"mural": "wall_%s", "rear": "wallrear_%s", "roof": "wallroof_%s"}[kind] % name
            sub = os.path.join(out_root, kind)
            os.makedirs(sub, exist_ok=True)
            stem = os.path.join(sub, pid + ("_" + side.lower() if kind == "mural" else ""))
            p.save_png(col, stem + ".png")
            p.save_png(em, stem + "_emit.png")
            try:
                rel = os.path.relpath(stem, ROOT).replace(os.sep, "/")
            except ValueError:                                  # (teste numa pasta de outro disco)
                rel = stem.replace(os.sep, "/")
            arts = [{"stem": rel, "aspect": round(size[0] / size[1], 3), "px": list(size)}]
            if kind == "roof":                                   # teto curto (baús menores): o meio da imagem, 1:2
                h2 = size[1] // 2
                y0 = (size[1] - h2) // 2
                p.save_png(col[y0:y0 + h2], stem + "_short.png")
                p.save_png(em[y0 // es:(y0 + h2) // es], stem + "_short_emit.png")
                arts.append({"stem": arts[0]["stem"] + "_short", "aspect": round(size[0] / h2, 3), "px": [size[0], h2]})
            pieces.setdefault(pid, {"id": pid, "kind": kind, "name": name, "sides": {}})["sides"][side] = arts
            night = np.clip(col * 0.12 + np.repeat(np.repeat(em, es, 0), es, 1)[:size[1], :size[0]] * 1.1, 0, 1)
            w = 1000
            rows.append(np.concatenate([PH.resample(col, (0, 0, size[0], size[1]), w, int(w * size[1] / size[0])),
                                        PH.resample(night, (0, 0, size[0], size[1]), w, int(w * size[1] / size[0]))], 1)
                        if kind == "mural" else None)
            print(f"[t258] {pid} {side} <- {os.path.basename(path)}")
        manifest += list(pieces.values())
    os.makedirs(RAW, exist_ok=True)
    if a["install"]:
        with open(os.path.join(RAW, "wallpapers.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=1)
    rows = [r for r in rows if r is not None]
    if a["sheet"] and rows:
        gap = np.zeros((6, rows[0].shape[1], 3), np.float32)
        sheet = np.concatenate([x for r in rows for x in (r, gap)][:-1], 0)
        os.makedirs(a["sheet"], exist_ok=True)
        p.save_png(sheet, os.path.join(a["sheet"], "wallpaper_proposta.png"))
    print(f"[t258] OK: {len(manifest)} pintura(s) de {len(found)} nome(s); {'instalado no jogo' if a['install'] else 'só proposta'}")


main()
