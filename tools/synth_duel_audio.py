#!/usr/bin/env python
"""T-204: trovão da abertura do duelo, sintetizado (sem ElevenLabs, sem créditos).

Uso (na raiz do projeto; precisa de numpy no Python do sistema):
    python tools/synth_duel_audio.py            # grava game/assets/audio/sfx/ui/duel_thunder.wav
    python tools/synth_duel_audio.py --out X.wav

Estalo seco do raio (ruído agudo de 0,25 s com estalinhos) + ronco grave que rola e some em ~3 s.
Determinístico (semente fixa). Para trocar por um som do ElevenLabs: gere `duel_thunder` com
`python tools/gen_audio.py --only duel_thunder` (linha na seção 5 de docs/AUDIO_ELEVENLABS.md) e apague o .wav.
"""
import argparse
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 44100


def lowpass(x, cutoff):
    """One-pole low-pass (simple, enough for a rumble)."""
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def thunder(seconds=3.2, seed=204):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    # crack: bright noise, 2 ms attack, fast decay, plus a few crackles in the first 0.4 s
    white = rng.standard_normal(n)
    bright = np.diff(white, prepend=0.0)
    crack = bright * np.minimum(t / 0.002, 1.0) * np.exp(-t / 0.06)
    for _ in range(9):
        at = rng.uniform(0.02, 0.4)
        crack += bright * np.exp(-np.maximum(t - at, 0) / 0.012) * (t >= at) * rng.uniform(0.25, 0.6)
    # rumble: brown noise low-passed, rolling amplitude, long decay
    brown = np.cumsum(rng.standard_normal(n))
    brown -= lowpass(brown, 8.0)                      # remove the drift (high-pass)
    brown = lowpass(brown, 180.0)
    brown /= np.max(np.abs(brown)) + 1e-9
    roll = lowpass(rng.standard_normal(n), 3.0)
    roll = 0.55 + 0.45 * roll / (np.max(np.abs(roll)) + 1e-9)
    env = np.minimum(t / 0.12, 1.0) * np.exp(-np.maximum(t - 0.12, 0) / 0.95)
    rumble = brown * roll * env
    mid = lowpass(white, 900.0) - lowpass(white, 250.0)   # body of the clap
    mid *= np.exp(-t / 0.35) * np.minimum(t / 0.01, 1.0)
    mid /= np.max(np.abs(mid)) + 1e-9
    out = crack * 0.35 + rumble * 1.0 + mid * 0.45
    out *= np.minimum((seconds - t) / 0.3, 1.0)       # fade out
    out /= np.max(np.abs(out)) + 1e-9
    return out * 0.89                                  # about -1 dBFS


def save(path, x):
    pcm = np.clip(x * 32767.0, -32768, 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("som T-204:", path, f"{len(x) / SR:.2f} s")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "game", "assets", "audio", "sfx", "ui", "duel_thunder.wav"))
    a = ap.parse_args()
    save(a.out, thunder())


if __name__ == "__main__":
    main()
