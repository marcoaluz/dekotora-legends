#!/usr/bin/env bash
# T-197: grava o som REAL do jogo (Godot Movie Maker) do roteiro de direcao da cena de teste do motor
# (lenta 2,5 s -> acelera ate 15,5 s trocando marchas -> solta (freio-motor) -> freia ate parar -> lenta), antes
# (som antigo, ElevenLabs) e depois (diesel sintetizado), e gera espectrogramas + analise.
# Uso (na raiz): GODOT=... [ONLY=depois] bash tools/render_t197_audio.sh [PASTA]   (padrao docs/audio_t197)
# Abre UMA janela por vez (o Movie Maker precisa de tela); ~50 s por arquivo.
set -e
OUT="${1:-docs/audio_t197}"
GODOT="${GODOT:?defina GODOT (source tools/env.sh)}"
TMP="$(mktemp -d)"
mkdir -p "$OUT"
# nome  cfg = MOTOR:TURBO:ESCAPE:CARROCERIA:jake|nojake:new|old:out|cab
JOBS=(
  "antes_6cil_padrao        eng_i6_std:turbo_single:exh_std:-:nojake:old:out"
  "depois_6cil_padrao       eng_i6_std:turbo_single:exh_std:-:nojake:new:out"
  "antes_v8_chamines_jake   eng_v8:turbo_twin:exh_stack:-:jake:old:out"
  "depois_v8_chamines_jake  eng_v8:turbo_twin:exh_stack:-:jake:new:out"
  "antes_6cil_prep_reto     eng_i6_tuned:turbo_single:exh_straight:-:nojake:old:out"
  "depois_6cil_prep_reto    eng_i6_tuned:turbo_single:exh_straight:-:nojake:new:out"
  "depois_leve_canter       eng_i6_std:turbo_none:exh_std:canter:nojake:new:out"
  "depois_6cil_estalos      eng_i6_std:turbo_none:exh_chrome_cut:-:nojake:new:out"
  "depois_6cil_cabine       eng_i6_std:turbo_single:exh_std:-:nojake:new:cab"
)
for j in "${JOBS[@]}"; do
  read -r name cfg <<< "$j"
  [[ -n "$ONLY" && "$name" != *"$ONLY"* ]] && continue      # ONLY=depois grava so os novos
  rm -f "$TMP"/*
  "$GODOT" --path game --write-movie "$TMP/f.png" --fixed-fps 30 res://scenes/tools/engine_audio_test.tscn \
    -- --sweep --quit-at-end --cfg="$cfg" > "$TMP/log.txt" 2>&1 || true
  grep -E "SCRIPT ERROR|Parse Error" "$TMP/log.txt" && exit 1
  # 32-bit estereo 48 kHz -> 16-bit mono 24 kHz (arquivo menor para o repositorio)
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
  echo "gravado $OUT/$name.wav"
done
rm -rf "$TMP"
python tools/audio_t197_report.py "$OUT/espectrogramas" "$OUT"/antes_*.wav "$OUT"/depois_*.wav
