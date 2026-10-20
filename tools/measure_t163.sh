#!/usr/bin/env bash
# T-163: custo do pilar em T, do guard-rail em W e dos postes de energia com fios, no modo MEDIO (--quality=1), sem vsync.
# O caminhao anda sozinho a partir de cada ponto (eventos com semente fixa) e o jogo imprime medias de 5 s
# (FPS, chamadas de desenho, triangulos, memoria de textura).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t163.sh [QUADROS]
#   Comparar com o visual antigo: MEASURE_EXTRA="--no-pontes-kit" bash tools/measure_t163.sh
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-2400}"
for SPOT in "kanto_1_coast 300" "kanto_1_coast 2250" "kanto_2_viaduct 300" "kanto_2_viaduct 2150" \
            "kanto_3_mountain 300" "kanto_3_mountain 1350"; do
  set -- $SPOT
  echo "== $1 start=$2 ${MEASURE_EXTRA:-}"
  "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after "$FRAMES" res://scenes/race/race3d.tscn -- \
      --fps-log --quality=1 --route="$1" --start="$2" --start-speed=22 --autoplay --event-seed=7 --time=night \
      $MEASURE_EXTRA 2>&1 | grep -E "FPS medio|SCRIPT ERROR|Parse Error|PONTES" || true
done
