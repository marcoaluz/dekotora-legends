"""T-220: decode any audio file Blender's ffmpeg reads (mp3, ogg, flac, wav, m4a...) into 16-bit mono WAV.
Run inside Blender (it has ffmpeg + numpy):
    blender -b --factory-startup -P tools/audio_decode.py -- OUT_DIR file1.mp3 file2.flac ...
Each input becomes OUT_DIR/<name>.wav at its own sample rate (stereo is averaged to mono).
Used by tools/cut_loops.py for files that are not WAV, and by tools/audio_t220_analyze.py for the old MP3 loops.
"""
import os
import sys
import wave

import aud
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out_dir = args[0]
os.makedirs(out_dir, exist_ok=True)
for path in args[1:]:
    s = aud.Sound(path)
    rate = int(s.specs[0])
    d = np.asarray(s.data(), dtype=np.float64)
    mono = d.mean(axis=1) if d.ndim == 2 else d
    pcm = (np.clip(mono, -1.0, 1.0) * 32767.0).astype("<i2")
    name = os.path.splitext(os.path.basename(path))[0]
    dst = os.path.join(out_dir, name + ".wav")
    with wave.open(dst, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    print("DECODED %s %d Hz %.2f s" % (dst, rate, len(mono) / rate))
