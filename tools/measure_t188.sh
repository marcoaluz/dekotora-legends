#!/usr/bin/env bash
# T-188: custo do cenario novo no TRECHO-PILOTO de cada rota (modo medio, --quality=1, sem vsync). O caminhao anda
# sozinho a partir do inicio do trecho (eventos com semente fixa) e o jogo imprime medias de 5 s (FPS, chamadas de
# desenho, triangulos, textura). Uso (raiz do projeto, Git Bash):
#   GODOT=... bash tools/measure_t188.sh [QUADROS] [day|night]          (depois)
#   MEASURE_EXTRA="--t188=off" bash tools/measure_t188.sh [QUADROS] [day|night]   (antes: visual antigo)
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-1500}"
TOD="${2:-night}"
for SPOT in "kanto_1_coast 650" "kanto_2_viaduct 1350" "kanto_3_mountain 1150"; do
  set -- $SPOT
  echo "== $1 start=$2 $TOD ${MEASURE_EXTRA:-}"
  "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after "$FRAMES" res://scenes/race/race3d.tscn -- \
      --fps-log --quality=1 --route="$1" --start="$2" --start-speed=22 --autoplay --event-seed=7 --time="$TOD" \
      $MEASURE_EXTRA 2>&1 | grep -E "FPS medio|SCRIPT ERROR|Parse Error" | tail -n 2 || true
done
