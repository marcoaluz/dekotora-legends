#!/usr/bin/env bash
# T-220: grava o som REAL do jogo (Godot Movie Maker) no roteiro --ramp da cena de teste do motor
# (lenta 2 s -> acelera 8 s ate o corte (700 -> 2400 rpm, 6 cil. padrao) -> segura 1 s -> solta 4 s -> lenta 2 s),
# sem turbo, em cada modo de som, e gera os graficos de comparacao (tools/audio_t220_compare.py).
# Uso (na raiz): GODOT=... [ONLY=synth] bash tools/render_t220_audio.sh [PASTA]   (padrao docs/audio_t220)
# Abre UMA janela por vez (o Movie Maker precisa de tela); ~25 s por arquivo.
set -e
OUT="${1:-docs/audio_t220}"
GODOT="${GODOT:?defina GODOT (source tools/env.sh)}"
TMP="${TMP_T220:-$(mktemp -d)}"
mkdir -p "$OUT" "$TMP"
CFG="eng_i6_std:turbo_none:exh_std:-:nojake:new:out"
# nome  argumentos extras
JOBS=(
  "antes_elevenlabs           --mode=old"
  "antes_loops_t197           --mode=loops"
  "depois_sintetizador        --mode=synth"
  "depois_sintetizador_leve   --mode=synth --synth-light"
  "depois_mistura             --mode=mix"
)
for j in "${JOBS[@]}"; do
  read -r name extra <<< "$j"
  [[ -n "$ONLY" && "$name" != *"$ONLY"* ]] && continue
  rm -f "$TMP"/*
  # shellcheck disable=SC2086
  "$GODOT" --path game --write-movie "$TMP/f.png" --fixed-fps 30 res://scenes/tools/engine_audio_test.tscn \
    -- --ramp --quit-at-end --cfg="$CFG" $extra > "$TMP/log.txt" 2>&1 || true
  grep -E "SCRIPT ERROR|Parse Error" "$TMP/log.txt" && exit 1
  python - "$TMP/f.wav" "$OUT/$name.wav" <<'PY'
import sys, wave, numpy as np
with wave.open(sys.argv[1], "rb") as w:
    sw, ch, sr = w.getsampwidth(), w.getnchannels(), w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i%d" % sw).astype(np.float64) / 2 ** (8 * sw - 1)
x = x.reshape(-1, ch).mean(axis=1)
x = 0.5 * (x[0:len(x) // 2 * 2:2] + x[1:len(x) // 2 * 2:2])
with wave.open(sys.argv[2], "wb") as o:
    o.setnchannels(1); o.setsampwidth(2); o.setframerate(sr // 2)
    o.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
PY
  rm -f "$TMP"/*.png
  echo "gravado $OUT/$name.wav"
done
python tools/audio_t220_compare.py "$OUT" "$OUT"/antes_*.wav "$OUT"/depois_*.wav
