#!/usr/bin/env bash
# T-153: custo do trecho de 2 faixas (modo MEDIO, sem vsync). Para cada rota: o caminhao anda sozinho a partir de
# 300 m (medida padrao) e a partir de ~150 m antes do afunilamento (passa pelo trecho estreito), eventos com semente
# fixa. Imprime as medias de 5 s (FPS, chamadas de desenho, triangulos, textura).
# Uso (raiz do projeto, Git Bash): bash tools/measure_t153.sh [QUADROS] [extra...]   (extra ex.: --no-sections)
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-2400}"
shift || true
for SPOT in "kanto_1_coast 300" "kanto_1_coast 2150" "kanto_2_viaduct 300" "kanto_2_viaduct 2060" \
            "kanto_3_mountain 300" "kanto_3_mountain 560"; do
  set -- $SPOT "$@"
  ROUTE=$1; Z=$2; shift 2
  echo "== $ROUTE start=$Z $*"
  "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after "$FRAMES" res://scenes/race/race3d.tscn -- \
      --fps-log --quality=1 --route="$ROUTE" --start="$Z" --start-speed=22 --autoplay --event-seed=7 "$@" \
      2>&1 | grep -E "FPS medio|SCRIPT ERROR|Parse Error" || true
done
