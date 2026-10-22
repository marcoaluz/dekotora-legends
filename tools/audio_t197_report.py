"""T-197: analysis of the engine sound renders (system Python + numpy; reads 16/32-bit PCM WAV, e.g. Godot Movie Maker).
    python tools/audio_t197_report.py OUT_PREFIX file1.wav [file2.wav ...]
Writes OUT_PREFIX.png (one log-frequency spectrogram row per file, 30 Hz..8 kHz, bottom = low; a thin white tick
every 2 s) and OUT_PREFIX.txt: per file, every second: loudness (dBFS), brightness (spectral centroid), the
strongest low peak 25..300 Hz (engine firing rhythm) and the share of energy that a phone speaker can play (>300 Hz).
"""
import struct
import sys
import wave
import zlib

import numpy as np


def read(path):
    with wave.open(path, "rb") as w:
        n, ch, sr, sw = w.getnframes(), w.getnchannels(), w.getframerate(), w.getsampwidth()
        x = np.frombuffer(w.readframes(n), dtype="<i%d" % sw).astype(np.float64) / float(2 ** (8 * sw - 1))
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return x, sr


def png(path, img):
    h, w, _ = img.shape
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(h))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def spectro_row(x, sr, width=780, height=120):
    win = 4096
    hop = max(1, (len(x) - win) // width)
    hann = np.hanning(win)
    f = np.fft.rfftfreq(win, 1.0 / sr)
    edges = np.geomspace(30.0, 8000.0, height + 1)
    cols = []
    for i in range(width):
        seg = x[i * hop:i * hop + win]
        if len(seg) < win:
            seg = np.pad(seg, (0, win - len(seg)))
        p = np.abs(np.fft.rfft(seg * hann)) ** 2
        cols.append([p[(f >= edges[k]) & (f < edges[k + 1])].mean() if np.any((f >= edges[k]) & (f < edges[k + 1])) else 0.0
                     for k in range(height)])
    m = 10 * np.log10(np.array(cols).T + 1e-12)
    m = np.clip((m - (m.max() - 70.0)) / 70.0, 0, 1)[::-1]
    img = np.stack([np.clip(m * 3 - 1.5, 0, 1), np.clip(m * 2 - 0.4, 0, 1) * 0.9, np.clip(1.2 - np.abs(m * 2 - 0.9), 0, 1) * m], -1)
    img = (img * 255).astype(np.uint8)
    secs = len(x) / sr
    for s in range(0, int(secs) + 1, 2):
        c = min(width - 1, int(s / secs * width))
        img[:6, c] = 255
    return img


def stats(x, sr):
    out = []
    for s in range(int(len(x) / sr)):
        seg = x[s * sr:(s + 1) * sr]
        p = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
        f = np.fft.rfftfreq(len(seg), 1.0 / sr)
        rms = 10 * np.log10(np.mean(seg ** 2) + 1e-12)
        cen = (p * f).sum() / (p.sum() + 1e-12)
        band = (f >= 25) & (f <= 300)
        pk = f[band][np.argmax(p[band])] if p[band].sum() > 0 else 0.0
        phone = p[f > 300].sum() / (p.sum() + 1e-12)
        out.append("  %2d s  %6.1f dBFS  brilho %5.0f Hz  pico grave %5.0f Hz  >300Hz %3.0f%%" % (s, rms, cen, pk, phone * 100))
    return out


def main():
    prefix, files = sys.argv[1], sys.argv[2:]
    rows, txt = [], []
    for i, path in enumerate(files):
        x, sr = read(path)
        rows.append(spectro_row(x, sr))
        rows.append(np.full((6, rows[-1].shape[1], 3), 40, np.uint8))
        name = path.replace("\\", "/").split("/")[-1]
        txt.append("[%d] %s  (%.1f s, pico %.2f)" % (i, name, len(x) / sr, np.max(np.abs(x))))
        txt += stats(x, sr)
    png(prefix + ".png", np.concatenate(rows, 0))
    with open(prefix + ".txt", "w", encoding="utf-8") as f:
        f.write("\n".join(txt) + "\n")
    print("\n".join(txt[:3]))


if __name__ == "__main__":
    main()
