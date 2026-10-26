"""T-219: sons PROCEDURAIS da sensacao de peso (versao provisoria; a lista para o ElevenLabs esta em
docs/AUDIO_ELEVENLABS.md, secao T-219). Deterministico (sementes fixas). Python do sistema com numpy:
    python tools/synth_feel_audio.py            # grava em game/assets/audio/
    python tools/synth_feel_audio.py --out DIR  # previa em DIR
Depois: godot --headless --path game --import

  sfx/crash/impact_thud_deep.wav   pancada GRAVE de chassi somada as batidas grandes (40-90 Hz, sem estalo agudo)
  sfx/truck/chassis_creak.wav      rangido/gemido da estrutura do bau ao frear forte (metal torcendo, 0,9 s)
  sfx/truck/road_joint_thump.wav   "ta-dum" das rodas na emenda de dilatacao do viaduto (2 pancadas curtas)
  sfx/truck/body_rumble_loop.wav   vibracao da carroceria (ronco grave com batimento), loop de 2 s; o jogo sobe o
                                   volume e o tom com a velocidade
Nomes: nao use _low/_mid/_high/_idle (o AudioBus tornaria loop; ver LOOP_HINTS).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from synth_truck_audio import SR, TAU, alpha_pulse, filt, one_shot, soft, write_wav  # noqa: E402


def norm(x, peak=0.89):
    return x * (peak / max(1e-9, np.max(np.abs(x))))


def impact_thud():
    rng = np.random.default_rng(219)
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    # corpo: senoide grave que cai de 70 para 42 Hz (o chassi "afunda") + sub com envelope longo
    f = 42.0 + 28.0 * np.exp(-t / 0.08)
    ph = TAU * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.22) * np.minimum(t / 0.002, 1.0)
    sub = np.sin(TAU * 31.0 * t) * np.exp(-t / 0.35) * np.minimum(t / 0.01, 1.0) * 0.5
    knock = rng.standard_normal(n) * np.exp(-t / 0.025)
    knock = filt(knock, [("lp", 380.0, 0.7), ("hp", 60.0, 0.7)]) * 1.2
    x = soft(norm(body + sub + knock), 1.8)
    return norm(one_shot(x, [("lp", 900.0, 0.7)], 0.1))


def chassis_creak():
    rng = np.random.default_rng(220)
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    env = np.minimum(t / 0.06, 1.0) * np.clip((1.0 - t) / 0.45, 0.0, 1.0) ** 1.5
    # atrito "stick-slip": pulsos irregulares que aceleram e desaceleram (o metal torcendo)
    rate = 38.0 + 22.0 * np.sin(TAU * 0.9 * t + 0.4) + 6.0 * np.sin(TAU * 3.1 * t)
    ph = np.cumsum(rate) / SR
    clicks = np.zeros(n)
    k_prev = 0
    for i in range(n):
        k = int(ph[i])
        if k != k_prev:
            k_prev = k
            m = min(400, n - i)
            clicks[i:i + m] += alpha_pulse(0.0006, 0.0, m) * (0.6 + 0.4 * rng.random())
    groan = filt(clicks, [("peak", 310.0, 6.0, 14.0), ("peak", 740.0, 8.0, 10.0), ("peak", 1350.0, 9.0, 6.0),
                          ("hp", 140.0, 0.7), ("lp", 3200.0, 0.7)])
    return norm(one_shot(groan * env, [("lp", 4000.0, 0.7)], 0.15), 0.8)


def joint_thump():
    rng = np.random.default_rng(221)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for t0, g in [(0.0, 1.0), (0.11, 0.8)]:                 # eixo da frente e de tras
        i0 = int(t0 * SR)
        tt = t[: n - i0]
        hit = (np.sin(TAU * (55.0 + 30.0 * np.exp(-tt / 0.03)) * tt) * np.exp(-tt / 0.06)
               + rng.standard_normal(n - i0) * np.exp(-tt / 0.012) * 0.6)
        x[i0:] += hit * g
    return norm(one_shot(filt(x, [("lp", 700.0, 0.7), ("hp", 40.0, 0.7)]), [("lp", 1200.0, 0.7)], 0.08), 0.85)


def body_rumble_loop():
    rng = np.random.default_rng(222)
    n = int(2.0 * SR)                                         # loop exato: filtros circulares
    t = np.arange(n) / SR
    noise = filt(rng.standard_normal(n), [("lp", 140.0, 0.7), ("hp", 25.0, 0.7), ("peak", 62.0, 1.5, 8.0)])
    hum = np.sin(TAU * 47.0 * t) * 0.35 + np.sin(TAU * 94.0 * t) * 0.12
    beat = 1.0 + 0.25 * np.sin(TAU * 1.5 * t) + 0.12 * np.sin(TAU * 4.0 * t)   # batimento (inteiro em 2 s: sem emenda)
    rattle = filt(rng.standard_normal(n), [("bp", 900.0, 3.0)]) * 0.08
    return norm((norm(noise) * 0.7 + hum) * beat + rattle, 0.7)


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio")
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    jobs = [("sfx/crash/impact_thud_deep.wav", impact_thud, False), ("sfx/truck/chassis_creak.wav", chassis_creak, False),
            ("sfx/truck/road_joint_thump.wav", joint_thump, False), ("sfx/truck/body_rumble_loop.wav", body_rumble_loop, True)]
    for rel, fn, loop in jobs:
        path = os.path.normpath(os.path.join(out, rel))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        x = fn()
        write_wav(path, x, loop)
        print("gravado", path, "%.2f s" % (len(x) / SR))


if __name__ == "__main__":
    main()
