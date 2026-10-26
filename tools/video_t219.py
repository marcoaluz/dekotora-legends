"""T-219: monta os VIDEOS antes|depois (MP4 H.264 com o som do "depois") e as TIRAS de quadros a partir das sequencias
gravadas por tools/capture_t219.sh. Usa o FFmpeg que ja vem dentro do Blender (nada a instalar).

    blender -b --factory-startup -P tools/video_t219.py -- ANTES DEPOIS SAIDA [casos...] [--tiras]

ANTES/DEPOIS: pastas com <caso>/f00000000.png ... e <caso>/f.wav. SAIDA (ex.: docs/capturas_t219):
  <caso>_antes_depois.mp4  lado a lado (esquerda ANTES, direita DEPOIS), 1920x540, 30 quadros/s
  tira_<caso>.jpg          2 linhas (antes em cima, depois embaixo) com os quadros de TIRAS[caso]
Deterministico: mesmos quadros, mesma saida.
"""
import os
import sys

import bpy
import numpy as np

# quadros (indice a 30 quadros/s) de cada tira; a batida do crash e em ~4,3 s (quadro ~129)
TIRAS = {
    "crash": [120, 129, 132, 135, 140, 150, 165, 190],
    "crash_lado": [120, 129, 132, 135, 140, 150, 165, 190],
    "lanes": [30, 40, 48, 56, 64, 72, 84, 100],
    "brake_lado": [100, 130, 140, 150, 160, 180, 200, 230],
}
CELL = (480, 270)   # tamanho de cada quadro na tira


def frames(folder):
    fs = sorted(f for f in os.listdir(folder) if f.startswith("f") and f.endswith(".png"))
    return [os.path.join(folder, f) for f in fs]


def video(antes, depois, out):
    fa, fd = frames(antes), frames(depois)
    n = min(len(fa), len(fd))
    sc = bpy.data.scenes.new("t219")
    sc.render.resolution_x, sc.render.resolution_y = 1920, 540
    sc.render.resolution_percentage = 100
    sc.render.fps = 30
    sc.view_settings.view_transform = "Standard"          # sem isto o AgX desbota as cores dos quadros do jogo
    sc.view_settings.look = "None"
    sc.frame_start, sc.frame_end = 1, n
    if hasattr(sc.render.image_settings, "media_type"):      # Blender 5: escolher "video" antes do formato
        sc.render.image_settings.media_type = "VIDEO"
    sc.render.image_settings.file_format = "FFMPEG"
    sc.render.ffmpeg.format = "MPEG4"
    sc.render.ffmpeg.codec = "H264"
    sc.render.ffmpeg.constant_rate_factor = "LOW"
    sc.render.ffmpeg.audio_codec = "AAC"
    sc.render.ffmpeg.audio_bitrate = 160
    sc.render.filepath = out
    se = sc.sequence_editor_create()
    strips = se.strips if hasattr(se, "strips") else se.sequences
    for k, (fl, x) in enumerate([(fa, -480), (fd, 480)]):
        s = strips.new_image("v%d" % k, fl[0], channel=k + 1, frame_start=1)
        for f in fl[1:n]:
            s.elements.append(os.path.basename(f))
        s.blend_type = "ALPHA_OVER"
        s.transform.scale_x = s.transform.scale_y = 960.0 / 1440.0
        s.transform.offset_x = x
        s.frame_final_duration = n
    wav = os.path.join(depois, "f.wav")
    if os.path.exists(wav):
        a = strips.new_sound("som", wav, channel=4, frame_start=1)
        a.frame_final_duration = n
    for k, (txt, x) in enumerate([("ANTES", 0.25), ("DEPOIS (T-219)", 0.75)]):
        t = strips.new_effect("txt%d" % k, "TEXT", channel=5 + k, frame_start=1, length=n) if hasattr(strips, "new_effect") else None
        if t is not None:
            t.text = txt
            t.font_size = 34
            t.location = (x, 0.93)
            t.use_shadow = True
            t.use_box = True
            t.box_color = (0.0, 0.0, 0.0, 0.55)
            t.color = (1.0, 0.85, 0.3, 1.0) if k else (1.0, 1.0, 1.0, 1.0)
    bpy.context.window_manager  # noqa: B018 (garante o contexto)
    with bpy.context.temp_override(scene=sc):
        bpy.ops.render.render(animation=True, scene=sc.name)
    print("VIDEO_T219", out, n, "quadros")


def load_px(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)


def shrink(a, size):
    h, w = a.shape[:2]
    ys = (np.arange(size[1]) * h / size[1]).astype(int)
    xs = (np.arange(size[0]) * w / size[0]).astype(int)
    # media de 2x2 vizinhos (menos serrilhado que o vizinho mais proximo)
    ys2 = np.minimum(ys + 1, h - 1)
    xs2 = np.minimum(xs + 1, w - 1)
    return (a[ys][:, xs] + a[ys2][:, xs] + a[ys][:, xs2] + a[ys2][:, xs2]) * 0.25


def strip(antes, depois, case, out):
    idx = TIRAS.get(case, [30, 60, 90, 120, 150, 180])
    fa, fd = frames(antes), frames(depois)
    cols = len(idx)
    pad = 4
    W = cols * (CELL[0] + pad) + pad
    H = 2 * (CELL[1] + pad) + pad
    canvas = np.zeros((H, W, 4), dtype=np.float32)
    canvas[..., 3] = 1.0
    canvas[..., :3] = 0.06
    for row, fl in enumerate([fd, fa]):          # numpy: linha 0 = embaixo da imagem -> depois embaixo, antes em cima
        for c, i in enumerate(idx):
            if i >= len(fl):
                continue
            a = shrink(load_px(fl[i]), CELL)
            y0 = pad + row * (CELL[1] + pad)
            x0 = pad + c * (CELL[0] + pad)
            canvas[y0:y0 + CELL[1], x0:x0 + CELL[0]] = a
    img = bpy.data.images.new("tira", W, H, alpha=True)
    img.pixels.foreach_set(canvas.ravel())
    img.filepath_raw = out
    img.file_format = "JPEG"
    sc = bpy.context.scene
    sc.view_settings.view_transform = "Standard"          # sem desbotar (AgX)
    sc.view_settings.look = "None"
    sc.render.image_settings.file_format = "JPEG"
    sc.render.image_settings.quality = 88
    img.save_render(out, scene=sc)
    print("TIRA_T219", out, "quadros", idx)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    antes, depois, out = argv[0], argv[1], argv[2]
    only_strips = "--tiras" in argv                       # so as tiras (rapido), sem refazer os videos
    argv = [a for a in argv if a != "--tiras"]
    cases = argv[3:] or ["crash", "lanes", "crash_lado", "brake_lado"]
    os.makedirs(out, exist_ok=True)
    for c in cases:
        a, d = os.path.join(antes, c), os.path.join(depois, c)
        if not (os.path.isdir(a) and os.path.isdir(d)):
            print("faltou", c)
            continue
        strip(a, d, c, os.path.join(out, "tira_%s.jpg" % c))
        if not only_strips:
            video(a, d, os.path.join(out, "%s_antes_depois.mp4" % c))


main()
