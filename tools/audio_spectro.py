"""Spectrogram contact sheet (run in Blender): blender -b --factory-startup -P spectro.py -- out.png bands.txt glob1 [glob2 ...]
Each row = one file: log-frequency spectrogram 50 Hz..16 kHz (bottom = low), time left->right, label strip on the left
is not drawn (order = sorted file list, written to bands.txt with band energies)."""
import glob
import os
import struct
import sys
import zlib

import aud
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out_png, out_txt = args[0], args[1]
files = []
for a in args[2:]:
    files += sorted(glob.glob(os.path.join(a, "*.mp3")) if os.path.isdir(a) else glob.glob(a))

W, H, GAP = 400, 110, 6
rows = []
txt = []
for i, f in enumerate(files):
    s = aud.Sound(f)
    rate = int(s.specs[0])
    d = np.asarray(s.data(), dtype=np.float64)
    mono = d.mean(axis=1) if d.ndim == 2 else d
    win, n = 2048, len(mono)
    hop = max(1, (n - win) // W)
    hann = np.hanning(win)
    freqs = np.fft.rfftfreq(win, 1.0 / rate)
    edges = np.geomspace(50, 16000, H + 1)
    img = np.zeros((H, W))
    tot = np.zeros(len(freqs))
    for x in range(W):
        seg = mono[x * hop:x * hop + win]
        if len(seg) < win:
            break
        sp = np.abs(np.fft.rfft(seg * hann)) ** 2
        tot += sp
        for y in range(H):
            m = (freqs >= edges[y]) & (freqs < edges[y + 1])
            img[H - 1 - y, x] = sp[m].max() if m.any() else 0.0
    db = 10 * np.log10(img + 1e-12)
    db = np.clip((db - (db.max() - 70)) / 70, 0, 1)
    rows.append(db)
    bands = [(0, 150), (150, 400), (400, 1500), (1500, 5000), (5000, 20000)]
    e = [tot[(freqs >= a) & (freqs < b)].sum() for a, b in bands]
    e = np.array(e) / (sum(e) + 1e-20)
    cent = float((freqs * tot).sum() / (tot.sum() + 1e-20))
    txt.append(f"{i:2d} {os.path.basename(f):32s} cent={cent:6.0f}Hz  <150={e[0]:.2f} 150-400={e[1]:.2f} 400-1.5k={e[2]:.2f} 1.5-5k={e[3]:.2f} >5k={e[4]:.2f}")

Ht = len(rows) * (H + GAP)
canvas = np.zeros((Ht, W, 3), dtype=np.uint8)
for i, r in enumerate(rows):
    y0 = i * (H + GAP)
    # simple heat map: black -> red -> yellow -> white
    c = np.stack([np.clip(r * 3, 0, 1), np.clip(r * 3 - 1, 0, 1), np.clip(r * 3 - 2, 0, 1)], axis=-1)
    canvas[y0:y0 + H] = (c * 255).astype(np.uint8)
    canvas[y0 + H:y0 + H + GAP] = (40, 80, 160)
    # 1 kHz marker ticks on the left edge
    for fm in (100, 1000, 10000):
        yy = y0 + H - 1 - int(np.searchsorted(np.geomspace(50, 16000, H + 1), fm))
        canvas[yy, 0:8] = (0, 255, 0)


def png(path, a):
    h, w, _ = a.shape
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, data):
        c = struct.pack(">I", len(data)) + t + data
        return c + struct.pack(">I", zlib.crc32(t + data) & 0xFFFFFFFF)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                 + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


png(out_png, canvas)
with open(out_txt, "w", encoding="utf-8") as fh:
    fh.write("\n".join(txt) + "\n")
