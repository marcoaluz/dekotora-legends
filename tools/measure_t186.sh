#!/usr/bin/env bash
# T-186: custo dos bosques (todas as arvores, 2 LODs), dos 2 postes de luz e das pessoas, no modo
# MEDIO (--quality=1), sem vsync. O caminhao anda sozinho
# a partir de cada ponto (eventos com semente fixa) e o jogo imprime medias de 5 s (FPS, chamadas, triangulos, textura).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t186.sh [QUADROS] [day|night]
#   Antes (visual antigo): MEASURE_EXTRA="--old-trees --old-lamps --no-people" bash tools/measure_t186.sh
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-1500}"
TOD="${2:-night}"
for SPOT in "kanto_1_coast 300" "kanto_1_coast 1700" "kanto_2_viaduct 1900" "kanto_2_viaduct 900" \
            "kanto_3_mountain 1350" "kanto_3_mountain 2420"; do
  set -- $SPOT
  echo "== $1 start=$2 $TOD ${MEASURE_EXTRA:-}"
  "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after "$FRAMES" res://scenes/race/race3d.tscn -- \
      --fps-log --quality=1 --route="$1" --start="$2" --start-speed=22 --autoplay --event-seed=7 --time="$TOD" \
      $MEASURE_EXTRA 2>&1 | grep -E "FPS medio|SCRIPT ERROR|Parse Error" | tail -n 2 || true
done
