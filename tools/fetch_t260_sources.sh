#!/usr/bin/env bash
# T-260: baixa os 4 WAV originais (48 kHz mono) do BigSoundBank (Joseph Sardin, CC0) para audio_src/engine/.
# Sao as mesmas gravacoes dos mp3 do SFX Jar em "docs/som caminhão/" (conferido por correlacao 0,95-0,999).
# Depois: python -P tools/rec_engine_t260.py  (gera os 30 loops rec_* em game/assets/audio/engines/)
set -e
cd "$(dirname "$0")/.."
mkdir -p audio_src/engine
get() { curl -fsSL -o "audio_src/engine/$2" "https://bigsoundbank.com/UPLOAD/bwf-en/$1.wav"; echo "OK $2"; }
get 1145 bsb1145_truck_engine.wav                       # https://bigsoundbank.com/truck-engine-s1145.html
get 1146 bsb1146_truck_engine_small_accelerations.wav   # https://bigsoundbank.com/truck-engine-small-accelerations-s1146.html
get 1147 bsb1147_truck_engine_big_accelerations.wav     # https://bigsoundbank.com/truck-engine-big-accelerations-s1147.html
get 1442 bsb1442_truck_engine_1.wav                     # https://bigsoundbank.com/truck-engine-1-s1442.html
