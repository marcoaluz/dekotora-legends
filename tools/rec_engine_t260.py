"""T-260: the game's recorded engine loops (rec_<voz>_<on|off>_<rpm>.wav) rebuilt from the 4 real recordings of an
Iveco Daily 3.0 HPI (inline-4 diesel) by Joseph Sardin, BigSoundBank, CC0 (also on SFX Jar). System Python + numpy.

    python -P tools/rec_engine_t260.py [--voices i4,i6,i6t] [--src audio_src/engine] [--out game/assets/audio/engines]
    (sources: bash tools/fetch_t260_sources.sh downloads the original WAVs into audio_src/engine/)

The recordings are free revs (truck stopped): idle ~850 rpm, small blips to ~2000 rpm, big revs 1800-3300 rpm. There is
no long stretch at a fixed high rpm, so cutting loops (tools/cut_loops.py) does not work. Instead, per loop:
  1. track the firing frequency every 10 ms (t260_engine_lib.rpm_track) and label frames idle / on (rising or held,
     loud) / off (falling, foot off);
  2. take every stretch whose firing frequency is within +-25% of the loop's target (cylinders of the VOICE x rpm/120);
  3. order-tracking resample of each stretch: the firing frequency becomes exactly the target (rhythm stays natural);
  4. move the resonances back (the resample moved them by the same ratio) and then by the voice's own factor:
     i4 = the real Iveco (light truck, Canter), i6 = heavy 6-cyl (resonances x0.80, more bass), i6t = tuned/turbo
     6-cyl (x0.88, brighter). 6-cyl voices use stretches at 1.5x the rpm (same firing rate as a 4-cyl);
  5. join the grains (aligned, crossfaded), even out the loudness, close the loop without a click (cut_loops.find_loop);
  6. loudness = the T-197 loop of the same voice/kind/point (the game's mix stays balanced), "off" a few dB under "on"
     by what the recording itself shows; peak <= -1 dBFS;
  7. check like tools/audio_t220_analyze.py (fundamental x expected, drift): CONFERE / NAO CONFERE.
Idle (700): off = "truck engine" (1145, soft idle), on = "truck engine #1" (1442, idle with more clatter).
Outputs: 10 loops per voice + docs/audio_t260/loops/<name>_check.png + docs/audio_t260/gerar_log.txt.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_plot as ap  # noqa: E402
import t260_engine_lib as L  # noqa: E402
from audio_t220_analyze import analyse  # noqa: E402
from cut_loops import check_png, find_loop  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC_CYL = 4
OUT_SR = 32000
POINTS = [700, 1000, 1400, 1900, 2500]
MAX_RATIO = 1.25
WIDE_RATIO = 1.4
EDGE = 50                       # frames (0.5 s) skipped at the start and end of each recording
LOOP_S = 2.4
FILES = {"idle_off": "bsb1145_truck_engine.wav", "idle_on": "bsb1442_truck_engine_1.wav",
         "small": "bsb1146_truck_engine_small_accelerations.wav", "big": "bsb1147_truck_engine_big_accelerations.wav"}
VOICES = {
    "i4": {"cyl": 4, "formant": 1.00, "low_db": 0.0, "high_db": 0.0},
    "i6": {"cyl": 6, "formant": 0.80, "low_db": 2.5, "high_db": -1.5},
    "i6t": {"cyl": 6, "formant": 0.88, "low_db": 1.0, "high_db": 3.0},
}


class Source:
    def __init__(self, path):
        x, sr = ap.read_wav(path)
        self.name = os.path.basename(path)
        self.x = x - np.mean(x)
        self.sr = sr
        self.xa = ap.fft_lowpass(self.x, sr, 0.45 * OUT_SR / MAX_RATIO)        # anti-alias for the speed-up
        self.t, self.f, self.score = L.rpm_track(self.x, sr, SRC_CYL)
        self.lev = L.level_track(self.x, sr, len(self.t))


def label(srcs):
    idle = srcs["idle_off"]
    idle_rpm = float(np.median(idle.f)) * 120.0 / SRC_CYL
    idle_db = float(np.median(idle.lev))
    for s in srcs.values():
        s.kind = L.classify(s.f * 120.0 / SRC_CYL, s.lev, idle_rpm, idle_db if s is not srcs["idle_on"] else float(np.median(s.lev)))
    return idle_rpm, idle_db


def candidates(srcs, kind, point, f_target, max_ratio=MAX_RATIO):
    """(source, i0, i1) stretches for a loop, best (closest rpm) first."""
    lo, hi = f_target / max_ratio, f_target * max_ratio
    if point == POINTS[0]:
        plan = [(srcs["idle_off" if kind == "off" else "idle_on"], ("idle",))]
    else:
        want = ("on",) if kind == "on" else ("off",)
        plan = [(srcs["small"], want), (srcs["big"], want)]
    out = []
    for s, kinds in plan:
        mask = np.array([k in kinds for k in s.kind]) & (s.f >= lo) & (s.f <= hi)
        mask[:EDGE] = False                                     # fade in / out of the recording
        mask[-EDGE:] = False
        if kinds == ("idle",):                                  # steady idle only (no start-up wobble)
            mask &= np.abs(s.f / np.median(s.f) - 1.0) < 0.04
        for i0, i1 in L.runs(mask, 10):
            for a in range(i0, i1, 120):                       # long idle stretches: grains of <= 1.2 s
                b = min(a + 120, i1)
                if b - a >= 10:
                    out.append((s, a, b, float(np.mean(np.abs(np.log(s.f[a:b] / f_target))))))
    if not out and kind == "off" and point != POINTS[0]:      # no falling stretch here: fast idle = foot off
        mask_src = srcs["idle_off"]
        mask = np.array([k == "idle" for k in mask_src.kind]) & (mask_src.f >= lo) & (mask_src.f <= hi)
        out = [(mask_src, a, b, 0.0) for a, b in L.runs(mask, 10)]
    out.sort(key=lambda c: c[3])
    return out


def real_drop_db(srcs, point, f_target):
    """How much quieter 'off' frames are than 'on' frames near this point in the recording itself."""
    lo, hi = f_target / MAX_RATIO, f_target * MAX_RATIO
    on, off = [], []
    for s in (srcs["small"], srcs["big"]):
        near = (s.f >= lo) & (s.f <= hi)
        on += list(s.lev[near & np.array([k == "on" for k in s.kind])])
        off += list(s.lev[near & np.array([k == "off" for k in s.kind])])
    if len(on) < 10 or len(off) < 10:
        return 8.0
    return float(np.clip(np.median(on) - np.median(off), 3.0, 14.0))


def build(srcs, voice, kind, point):
    v = VOICES[voice]
    f_target = point * v["cyl"] / 120.0
    cands = candidates(srcs, kind, point, f_target)
    if sum(b - a for _s, a, b, _d in cands) * L.HOP_S < 2.0:     # little material (6-cyl top point): wider range
        cands = candidates(srcs, kind, point, f_target, WIDE_RATIO)
    if not cands:
        raise ValueError("sem material para %s %s %d" % (voice, kind, point))
    grains, total, used = [], 0.0, []
    for s, a, b, _d in cands:
        y, ratio = L.warp_run(s.xa, s.sr, s.t, s.f, a, b, f_target, OUT_SR)
        if y is None:
            continue
        y = L.formant_shift(y, OUT_SR, v["formant"] / ratio)
        rms = np.sqrt(np.mean(y ** 2)) + 1e-12
        grains.append((s.t[a], s.name, y / rms))
        used.append(ratio)
        total += len(y) / OUT_SR
        if total > LOOP_S * 2.0:
            break
    grains.sort(key=lambda g: (g[1], g[0]))                    # time order: natural variety between grains
    period = 1.0 / f_target
    seq = L.stitch([g[2] for g in grains], OUT_SR, period, LOOP_S + 1.2, 0.03)
    if seq is None:
        raise ValueError("grãos curtos demais para %s %s %d" % (voice, kind, point))
    # slow loudness rider: swells of the revs flattened (the game sets loudness by load and rpm)
    env = np.sqrt(np.convolve(seq ** 2, np.ones(int(0.25 * OUT_SR)) / int(0.25 * OUT_SR), mode="same")) + 1e-9
    seq = seq * np.clip((np.median(env) / env) ** 0.7, 0.5, 2.0)
    loop, match, jump = find_loop(seq, OUT_SR, period, LOOP_S, 0.03)
    if v["low_db"]:
        loop = L.shelf(loop, OUT_SR, 150.0, v["low_db"], low=True)
    if v["high_db"]:
        loop = L.shelf(loop, OUT_SR, 1500.0, v["high_db"], low=False)
    loop -= np.mean(loop)
    return loop, {"grains": len(grains), "material_s": total, "ratio_min": min(used), "ratio_max": max(used),
                  "match": match, "jump": jump, "f_target": f_target}


def target_db(voice, kind, point, drop):
    syn = os.path.join(ROOT, "game", "assets", "audio", "engines", "syn_%s_on_%d.wav" % (voice, point))
    on_db = -20.0
    if os.path.exists(syn):
        x, _sr = ap.read_wav(syn)
        on_db = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
    if kind == "on" or point == POINTS[0]:
        return on_db
    return on_db - drop


def main():
    a = sys.argv[1:]

    def opt(k, d):
        return a[a.index(k) + 1] if k in a else d
    src_dir = opt("--src", os.path.join(ROOT, "audio_src", "engine"))
    out_dir = opt("--out", os.path.join(ROOT, "game", "assets", "audio", "engines"))
    doc_dir = opt("--docs", os.path.join(ROOT, "docs", "audio_t260"))
    voices = opt("--voices", "i4,i6,i6t").split(",")
    os.makedirs(os.path.join(doc_dir, "loops"), exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    srcs = {k: Source(os.path.join(src_dir, f)) for k, f in FILES.items()}
    idle_rpm, idle_db = label(srcs)
    lines = ["fontes: marcha lenta %.0f rpm (4 cil.), nivel %.1f dB; quadros on/off/idle: %s" % (
        idle_rpm, idle_db, ", ".join("%s %d/%d/%d" % (k, sum(1 for q in s.kind if q == "on"), sum(1 for q in s.kind if q == "off"),
                                                       sum(1 for q in s.kind if q == "idle")) for k, s in srcs.items()))]
    print(lines[0])
    bad = 0
    for voice in voices:
        cyl = VOICES[voice]["cyl"]
        for point in POINTS:
            drop = real_drop_db(srcs, point, point * cyl / 120.0)
            for kind in ("off", "on"):
                name = "rec_%s_%s_%d" % (voice, kind, point)
                loop, info = build(srcs, voice, kind, point)
                loop *= 10 ** (target_db(voice, kind, point, drop) / 20.0) / (np.sqrt(np.mean(loop ** 2)) + 1e-12)
                pk = float(np.max(np.abs(loop)))
                if pk > 0.89:
                    loop *= 0.89 / pk
                ap.write_wav(os.path.join(out_dir, name + ".wav"), loop, OUT_SR, loop=True)
                chk = analyse(loop, OUT_SR, cyl, float(point), 1.0)
                ok = chk["ok"]
                bad += 0 if ok else 1
                check_png(os.path.join(doc_dir, "loops", name + "_check.png"), loop, OUT_SR, info["f_target"],
                          "%s  %d GRAOS  X%.2f-%.2f  LOOP %.2f S  %s" % (name.upper(), info["grains"], info["ratio_min"],
                                                                       info["ratio_max"], len(loop) / OUT_SR, "CONFERE" if ok else "NAO CONFERE"))
                line = "%-18s %2d graos (%.1f s de material, x%.2f..%.2f)  f0 %.1f Hz (esperado %.1f)  deriva %.2f st  clareza %.2f  RMS %.1f dB  casamento %.2f  %s" % (
                    name, info["grains"], info["material_s"], info["ratio_min"], info["ratio_max"], chk["f0"], chk["expected"],
                    chk["drift"], chk["clarity"], chk["rms_db"], info["match"], "CONFERE" if ok else "NAO CONFERE (%s)" % "; ".join(chk["reasons"]))
                print(line)
                lines.append(line)
    with open(os.path.join(doc_dir, "gerar_log.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("NAO CONFERE: %d" % bad)


if __name__ == "__main__":
    main()
