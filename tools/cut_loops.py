"""T-220: cut seamless engine loops out of REAL recordings and tune them to the game's RPM points.

System Python + numpy (no Pillow/scipy). Non-WAV files (mp3, flac, ogg...) are decoded with Blender first
(BLENDER env var or /d/Blender/blender.exe; see tools/env.sh).

One file:
    python tools/cut_loops.py audio_src/engine/idle.wav --voice i6 --kind off --rpm auto [--start 3.0 --len 6.0]
All files of a list (one line per loop; '#' = comment):
    python tools/cut_loops.py --list audio_src/engine/cortes.txt
    # arquivo                        voz  tipo  rpm   inicio  duracao
    "audio_src/engine/128160_Diesel Truck Idling Front.wav"  i6  off  auto  2.0  10.0
    audio_src/engine/rev_1400.flac   i6   on    1450  -       -

What it does, per loop:
  1. reads the file (mono), keeps [start, start+len] if given;
  2. measures the firing frequency (YIN) -> rpm = f x 120 / cylinders (6 cyl: f x 20). `--rpm N` gives it by hand;
  3. picks the steadiest stretch (fundamental within +-3%) of at least --min-loop seconds;
  4. pitches it to the nearest game RPM point (700, 1000, 1400, 1900, 2500; or --point N) by resampling:
     the firing rhythm then matches the game exactly (at most +-25%; farther = refused, record closer to the point);
  5. finds the loop end that best matches the start (cross-correlation, then the nearest rising zero crossing),
     crossfades the tail into the head (--xfade ms) -> no click at the seam;
  6. checks the result like tools/audio_t220_analyze.py (fundamental x expected): CONFERE / NAO CONFERE;
  7. normalises (RMS -20 dBFS, peak <= -1 dBFS) and writes rec_<voz>_<tipo>_<ponto>.wav (32 kHz mono, 16-bit, "smpl"
     loop chunk = Godot imports it already looping) + a check PNG (seam waveform + spectrum with expected harmonics).
A kind "off" at 700 rpm is the idle; if no "on" 700 is given the idle is also written as on_700.
The game uses rec_* ONLY when all 10 files (on/off x 5 points) of a voice exist (EngineAudio.recordings_complete);
until then it keeps the syn_* loops. Output folder: --out (default game/assets/audio/engines).
"""
import os
import shlex
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_plot as ap  # noqa: E402
from audio_t220_analyze import analyse, windows_f0, welch  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
POINTS = [700, 1000, 1400, 1900, 2500]
CYL = {"i6": 6, "i6t": 6, "v8": 8, "i4": 4}
OUT_SR = 32000
MAX_SHIFT = 0.25


def load_any(path, tmp):
    if path.lower().endswith(".wav"):
        try:
            return ap.read_wav(path)
        except Exception:
            pass                                  # float WAV or odd format: let Blender decode it
    blender = os.environ.get("BLENDER", "D:/Blender/blender.exe")
    os.makedirs(tmp, exist_ok=True)
    subprocess.run([blender, "-b", "--factory-startup", "-P", os.path.join(ROOT, "tools", "audio_decode.py"), "--", tmp, path],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return ap.read_wav(os.path.join(tmp, os.path.splitext(os.path.basename(path))[0] + ".wav"))


def f0_track(x, sr):
    ds = 4000
    lo = ap.resample(ap.fft_lowpass(x, sr, 1000.0), sr, ds)
    f, c = windows_f0(lo, ds, 0.4, 0.1)
    t = 0.2 + 0.1 * np.arange(len(f))
    return t, f, c


def steady_region(t, f, c, min_len):
    """Longest run of windows with clear rhythm and f0 within +-3% of the run median. Returns (t0, t1, f0)."""
    best = (0.0, 0.0, 0.0)
    good = c >= 0.4
    if not good.any():
        return None
    # a lopey idle makes some windows lock on half / double the firing rate: fold them to the main octave
    med = np.median(f[good])
    f = f * 2.0 ** np.round(np.log2(med / np.maximum(f, 1e-3)))
    n = len(f)
    for i in range(n):
        if c[i] < 0.4:
            continue
        j = i
        while j + 1 < n and c[j + 1] >= 0.4 and abs(f[j + 1] / np.median(f[i:j + 2]) - 1.0) < 0.03:
            j += 1
        if t[j] - t[i] > best[1] - best[0]:
            best = (t[i] - 0.2, t[j] + 0.2, float(np.median(f[i:j + 1])))
    if best[1] - best[0] < min_len:
        return None
    return best


def find_loop(x, sr, period_s, want_s, xfade):
    """Loop of about want_s seconds: end chosen where the waveform best matches the start (+-1 period), then moved to
    the nearest rising zero crossing; tail crossfaded into the head. Returns (loop, seam_score)."""
    p = int(period_s * sr)
    ref_len = max(p, int(0.03 * sr))
    head = x[:ref_len]
    target = int(want_s * sr)
    lo, hi = max(target - p, ref_len * 2), min(target + p, len(x) - ref_len - int(xfade * sr) - 1)
    if hi <= lo:
        raise ValueError("trecho curto demais para o loop pedido")
    best, best_k = -2.0, lo
    for k in range(lo, hi):
        seg = x[k:k + ref_len]
        r = float(np.dot(head, seg) / (np.sqrt(np.dot(head, head) * np.dot(seg, seg)) + 1e-12))
        if r > best:
            best, best_k = r, k
    L = best_k
    nx = int(xfade * sr)
    loop = x[:L].copy()
    fade = np.sin(np.linspace(0, np.pi / 2, nx)) ** 2
    loop[:nx] = x[:nx] * fade + x[L:L + nx] * (1.0 - fade)          # head = continuation of the tail
    # rotate so the file starts/ends at a rising zero crossing (outside the crossfade)
    zc = np.where((loop[nx:-1] <= 0) & (loop[nx + 1:] > 0))[0]
    if len(zc):
        loop = np.roll(loop, -(zc[0] + nx + 1))
    jump = abs(loop[0] - loop[-1]) / (np.mean(np.abs(np.diff(loop))) + 1e-12)
    return loop, best, jump


def check_png(path, loop, sr, f_exp, title):
    W, H = 900, 300
    img = np.zeros((H, W, 3), np.uint8)
    img[:] = (10, 12, 20)
    ap.text(img, 8, 6, title, (250, 210, 60))
    # seam: last 30 ms + first 30 ms
    n = int(0.03 * sr)
    seam = np.concatenate([loop[-n:], loop[:n]])
    xs = np.linspace(8, W / 2 - 8, len(seam))
    ap.polyline(img, xs, 90 - seam / (np.max(np.abs(seam)) + 1e-9) * 60, (90, 200, 255))
    ap.vline(img, (8 + W / 2 - 8) / 2, 30, 150, (255, 70, 70), dash=3)
    ap.text(img, 8, 156, "EMENDA DO LOOP (FIM | INICIO): SEM DEGRAU NA LINHA VERMELHA", (150, 150, 160))
    freqs, P = welch(loop, sr)
    m = (freqs >= 20) & (freqs <= 4000)
    db = 10 * np.log10(P[m] + 1e-20)
    dbn = np.clip((db - (db.max() - 60)) / 60, 0, 1)
    x0, w, y0, h = W / 2 + 8, W / 2 - 16, 30, 230

    def fx(f):
        return x0 + np.log(f / 20.0) / np.log(200.0) * w
    for k in range(1, 12):
        if f_exp * k < 4000:
            ap.vline(img, fx(f_exp * k), y0, y0 + h, (60, 220, 110) if k == 1 else (40, 110, 60), dash=3)
    ap.polyline(img, fx(freqs[m]), y0 + h - dbn * h, (90, 200, 255))
    for g in (20, 50, 100, 200, 500, 1000, 2000, 4000):
        ap.text(img, int(fx(g)) - 6, y0 + h + 4, str(g) if g < 1000 else "%dK" % (g // 1000), (120, 125, 140))
    ap.save_png(path, img)


def cut_one(path, voice, kind, rpm_arg, start, length, out, point_arg=None, min_loop=1.2, want=2.0, xfade_ms=25.0,
            tmp=None, quiet=False):
    cyl = CYL.get(voice, 6)
    x, sr = load_any(path, tmp or os.path.join(out, "_decoded"))
    if start is not None:
        x = x[int(start * sr):]
    if length is not None:
        x = x[:int(length * sr)]
    x = x - np.mean(x)
    t, f, c = f0_track(x, sr)
    reg = steady_region(t, f, c, min_loop)
    if rpm_arg in (None, "auto"):
        if reg is None:
            raise ValueError("%s: nenhum trecho estavel de %.1f s (ritmo de ignicao claro). Use --rpm N e --start/--len." % (path, min_loop))
        t0, t1, f0 = reg
        rpm = f0 * 120.0 / cyl
    else:
        rpm = float(rpm_arg)
        t0, t1 = (reg[0], reg[1]) if reg else (0.0, len(x) / sr)
    seg = x[int(t0 * sr):int(t1 * sr)]
    point = int(point_arg) if point_arg else min(POINTS, key=lambda p: abs(np.log(p / rpm)))
    ratio = point / rpm                          # >1 = play faster (higher rpm)
    if abs(np.log(ratio)) > np.log(1.0 + MAX_SHIFT):
        raise ValueError("%s: %.0f rpm esta longe demais do ponto %d (x%.2f). Grave mais perto do ponto." % (path, rpm, point, ratio))
    # resample: new length = old / ratio, at OUT_SR
    seg = ap.resample(seg, sr, OUT_SR)
    n_new = int(len(seg) / ratio)
    seg = np.interp(np.arange(n_new) * ratio, np.arange(len(seg)), seg)
    period = 120.0 / point / cyl
    loop, match, jump = find_loop(seg, OUT_SR, period, min(want, len(seg) / OUT_SR * 0.8), xfade_ms / 1000.0)
    rms = np.sqrt(np.mean(loop ** 2))
    loop *= 10 ** (-20 / 20) / max(rms, 1e-9)
    pk = np.max(np.abs(loop))
    if pk > 0.89:
        loop *= 0.89 / pk
    os.makedirs(out, exist_ok=True)
    names = ["rec_%s_%s_%d" % (voice, kind, point)]
    if kind == "off" and point == 700 and not os.path.exists(os.path.join(out, "rec_%s_on_700.wav" % voice)):
        names.append("rec_%s_on_700" % voice)
    for nm in names:
        ap.write_wav(os.path.join(out, nm + ".wav"), loop, OUT_SR, loop=True)
    check_png(os.path.join(out, names[0] + "_check.png"), loop, OUT_SR, point * cyl / 120.0,
              "%s  %.0f RPM -> %d (X%.2f)  LOOP %.2f S  CASAMENTO %.2f" % (names[0], rpm, point, ratio, len(loop) / OUT_SR, match))
    chk = analyse(loop, OUT_SR, cyl, float(point), 1.0)     # same check as tools/audio_t220_analyze.py
    verdict = "CONFERE" if chk["ok"] else "NAO CONFERE (%s)" % "; ".join(chk["reasons"])
    line = "%-22s <- %s  medido %.0f rpm (%.1f Hz) trecho %.1f-%.1f s -> ponto %d (x%.3f)  loop %.2f s  casamento %.2f  degrau %.1f  %s" % (
        names[0], os.path.basename(path), rpm, rpm * cyl / 120.0, t0, t1, point, ratio, len(loop) / OUT_SR, match, jump, verdict)
    if not quiet:
        print(line)
    return line


def main():
    a = sys.argv[1:]

    def opt(k, d=None):
        return a[a.index(k) + 1] if k in a else d
    out = opt("--out", os.path.join(ROOT, "game", "assets", "audio", "engines"))
    lines = []
    if "--list" in a:
        for raw in open(opt("--list"), encoding="utf-8"):
            raw = raw.split("#")[0].strip()
            if not raw:
                continue
            p = shlex.split(raw, posix=True)                  # "nome com espaco.wav" entre aspas
            st = None if p[4] == "-" else float(p[4])
            ln = None if p[5] == "-" else float(p[5])
            try:
                lines.append(cut_one(p[0], p[1], p[2], p[3], st, ln, out))
            except Exception as e:  # noqa: BLE001
                lines.append("ERRO %s: %s" % (p[0], e))
                print(lines[-1])
    else:
        st = opt("--start")
        ln = opt("--len")
        lines.append(cut_one(a[0], opt("--voice", "i6"), opt("--kind", "on"), opt("--rpm", "auto"),
                             float(st) if st else None, float(ln) if ln else None, out, opt("--point"),
                             float(opt("--min-loop", 1.2)), float(opt("--loop", 2.0)), float(opt("--xfade", 25.0))))
    with open(os.path.join(out, "cut_loops_log.txt"), "a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
