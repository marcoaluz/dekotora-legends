#!/usr/bin/env bash
# T-155: custo do acabamento (mural aceso, bocas de tunel, tunel antigo) no modo MEDIO, sem vsync. O caminhao anda
# sozinho a partir de cada ponto (eventos com semente fixa) e imprime as medias de 5 s (FPS, chamadas, triangulos).
# Uso (raiz do projeto, Git Bash): bash tools/measure_t155.sh [QUADROS] [extra...]
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-1800}"
shift || true
for SPOT in "kanto_2_viaduct 300 night" "kanto_2_viaduct 900 night" "kanto_3_mountain 640 night" \
            "kanto_3_mountain 640 day" "kanto_3_mountain 1980 day"; do
  set -- $SPOT "$@"
  ROUTE=$1; Z=$2; TOD=$3; shift 3
  echo "== $ROUTE start=$Z $TOD $*"
  "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after "$FRAMES" res://scenes/race/race3d.tscn -- \
      --fps-log --quality=1 --route="$ROUTE" --start="$Z" --start-speed=22 --autoplay --event-seed=7 --time="$TOD" "$@" \
      2>&1 | grep -E "FPS medio|SCRIPT ERROR|Parse Error" || true
done
