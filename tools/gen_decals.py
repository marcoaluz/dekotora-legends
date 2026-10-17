"""Gera os 6 adesivos provisorios em game/assets/decals/ (branco sobre transparente: o jogo pinta com a cor escolhida).

Uso: python tools/gen_decals.py      (precisa de Pillow; usa a fonte NotoSansJP do proprio projeto)
Para trocar por arte propria (carpa, tigre, mascara...): coloque PNGs brancos/transparentes em game/assets/decals/
ou, sem reimportar, em user://decals/ (pasta de dados do jogo). Detalhes em game/assets/decals/LEIA-ME.md.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "decals")
FONT = os.path.join(ROOT, "game", "assets", "fonts", "NotoSansJP.ttf")
W = (255, 255, 255, 255)
S = 4  # supersampling


def canvas(w, h):
    return Image.new("RGBA", (w * S, h * S), (255, 255, 255, 0))


def finish(img, name):
    w, h = img.size[0] // S, img.size[1] // S
    img = img.resize((w, h), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"), optimize=True)
    print("ok", name, img.size)


def kanji(text, w, h, size, name, ring=False):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, size * S)
    if ring:
        d.ellipse([6 * S, 6 * S, (w - 6) * S, (h - 6) * S], outline=W, width=8 * S)
    bb = d.textbbox((0, 0), text, font=f)
    d.text(((w * S - (bb[2] - bb[0])) / 2 - bb[0], (h * S - (bb[3] - bb[1])) / 2 - bb[1]), text, font=f, fill=W, stroke_width=5 * S, stroke_fill=W)
    finish(img, name)


def ondas(n=256):
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    d.ellipse([4 * S, 4 * S, (n - 4) * S, (n - 4) * S], outline=W, width=6 * S)
    # seigaiha: fileiras de semicirculos concentricos, recortados no disco
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([10 * S, 10 * S, (n - 10) * S, (n - 10) * S], fill=255)
    pat = Image.new("RGBA", img.size, (255, 255, 255, 0))
    pd = ImageDraw.Draw(pat)
    r = 36
    for row in range(-1, 8):
        for col in range(-1, 8):
            cx = col * r * 2 + (r if row % 2 else 0)
            cy = row * r
            for k in range(3):
                rr = r - k * 10
                pd.arc([(cx - rr) * S, (cy - rr) * S, (cx + rr) * S, (cy + rr) * S], 180, 360, fill=W, width=4 * S)
    img.paste(pat, (0, 0), mask)
    finish(img, "ondas")


def raio(n=256):
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    pts = [(150, 8), (60, 140), (118, 140), (84, 248), (200, 104), (140, 104), (190, 8)]
    d.polygon([(x * S, y * S) for x, y in pts], fill=W)
    finish(img, "raio")


def estrela(n=256):
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    cx = cy = n / 2
    pts = []
    for i in range(10):
        r = 120 if i % 2 == 0 else 50
        a = -math.pi / 2 + i * math.pi / 5
        pts.append(((cx + r * math.cos(a)) * S, (cy + r * math.sin(a)) * S))
    d.polygon(pts, fill=W)
    finish(img, "estrela")


def sol(n=256):
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    cx = cy = n / 2
    d.ellipse([(cx - 52) * S, (cy - 52) * S, (cx + 52) * S, (cy + 52) * S], fill=W)
    for i in range(16):
        a0 = i * math.pi / 8 - math.pi / 32
        a1 = a0 + math.pi / 16
        pts = [(cx + 66 * math.cos(a0), cy + 66 * math.sin(a0)), (cx + 124 * math.cos((a0 + a1) / 2), cy + 124 * math.sin((a0 + a1) / 2)), (cx + 66 * math.cos(a1), cy + 66 * math.sin(a1))]
        d.polygon([(x * S, y * S) for x, y in pts], fill=W)
    finish(img, "sol")


if __name__ == "__main__":
    kanji("爆走", 512, 256, 190, "kanji_bakusou")
    kanji("魂", 256, 256, 170, "kanji_tamashii", ring=True)
    ondas()
    raio()
    estrela()
    sol()
