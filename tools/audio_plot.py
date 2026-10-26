"""T-220: tiny raster plotting with numpy only (no Pillow/matplotlib): 5x7 bitmap font, lines, PNG writer, WAV I/O.
Used by tools/audio_t220_analyze.py, tools/cut_loops.py and tools/audio_t220_compare.py.
"""
import struct
import wave
import zlib

import numpy as np

_F = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    " ": ["00000"] * 7,
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ",": ["00000", "00000", "00000", "00000", "01100", "00100", "01000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
    "=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
    "%": ["11001", "11010", "00010", "00100", "01000", "01011", "10011"],
    "(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
    ")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
    "_": ["00000", "00000", "00000", "00000", "00000", "00000", "11111"],
    ">": ["01000", "00100", "00010", "00001", "00010", "00100", "01000"],
    "<": ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
    "*": ["00000", "10101", "01110", "11111", "01110", "10101", "00000"],
    "|": ["00100"] * 7,
    "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
    "#": ["01010", "11111", "01010", "01010", "01010", "11111", "01010"],
}
_ACCENTS = str.maketrans("ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç×", "AAAAEEIOOOUCaaaaeeiooouc*")


def text(img, x, y, s, color=(255, 255, 255), scale=1):
    """Draws ASCII text (accents folded, lower case shown as upper case) at pixel (x, y) = top left."""
    s = s.translate(_ACCENTS).upper()
    h, w, _ = img.shape
    for ch in s:
        g = _F.get(ch, _F["?"])
        for r, row in enumerate(g):
            for c, bit in enumerate(row):
                if bit == "1":
                    y0, x0 = y + r * scale, x + c * scale
                    if 0 <= y0 < h and 0 <= x0 < w:
                        img[y0:y0 + scale, x0:x0 + scale] = color
        x += 6 * scale
    return x


def line(img, x0, y0, x1, y1, color):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    xs = np.clip(np.round(np.linspace(x0, x1, n)).astype(int), 0, img.shape[1] - 1)
    ys = np.clip(np.round(np.linspace(y0, y1, n)).astype(int), 0, img.shape[0] - 1)
    img[ys, xs] = color


def polyline(img, xs, ys, color):
    for i in range(len(xs) - 1):
        line(img, xs[i], ys[i], xs[i + 1], ys[i + 1], color)


def vline(img, x, y0, y1, color, dash=0):
    x = int(round(x))
    if not 0 <= x < img.shape[1]:
        return
    for y in range(int(y0), int(y1)):
        if dash == 0 or (y // dash) % 2 == 0:
            img[y, x] = color


def rect(img, x0, y0, x1, y1, color):
    img[int(y0):int(y1), int(x0):int(x1)] = color


def save_png(path, img):
    img = np.ascontiguousarray(img.astype(np.uint8))
    h, w, _ = img.shape
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def read_wav(path):
    """Mono float64 in -1..1 and the sample rate (8/16/24/32-bit PCM; 24-bit unpacked by hand)."""
    with wave.open(path, "rb") as w:
        n, ch, sr, sw = w.getnframes(), w.getnchannels(), w.getframerate(), w.getsampwidth()
        raw = w.readframes(n)
    if sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v >= 1 << 23, v - (1 << 24), v)
        x = v.astype(np.float64) / float(1 << 23)
    elif sw == 1:
        x = (np.frombuffer(raw, dtype=np.uint8).astype(np.float64) - 128.0) / 128.0
    else:
        x = np.frombuffer(raw, dtype="<i%d" % sw).astype(np.float64) / float(2 ** (8 * sw - 1))
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return x, sr


def write_wav(path, x, sr, loop=False):
    """16-bit mono; loop=True adds a 'smpl' chunk (Godot imports the file already looping)."""
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(int(sr))
        w.writeframes(pcm.tobytes())
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / sr), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(pcm) - 1, 0, 0)
        with open(path, "r+b") as f:
            f.seek(0, 2)
            f.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
            size = f.tell() - 8
            f.seek(4)
            f.write(struct.pack("<I", size))


def fft_lowpass(x, sr, cut):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / sr)
    X[f > cut] = 0.0
    return np.fft.irfft(X, n=len(x))


def resample(x, sr, new_sr):
    """Band-limited resample (FFT low-pass + linear interpolation; fine for analysis)."""
    if sr == new_sr:
        return x
    y = fft_lowpass(x, sr, 0.45 * min(sr, new_sr))
    t = np.arange(int(len(x) * new_sr / sr)) * (sr / new_sr)
    return np.interp(t, np.arange(len(y)), y)
