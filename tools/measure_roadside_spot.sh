#!/usr/bin/env bash
# T-146: mede o MESMO quadro com e sem o kit (caminhao parado, eventos com semente fixa), modo medio, nas 3 rotas.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_roadside_spot.sh [Z]
#   Z padrao 640 (ve o outdoor de 700 m, o portico de 970 m e placas). Imprime a 2a media de 5 s de cada caso.
: "${GODOT:?defina GODOT (tools/env.sh)}"
Z="${1:-640}"
for ROUTE in kanto_1_coast kanto_2_viaduct kanto_3_mountain; do
  for K in "" "--no-kit"; do
    printf "%-18s %-9s " "$ROUTE" "${K:-kit}"
    "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after 3200 res://scenes/race/race3d.tscn -- \
        --fps-log --quality=1 --route="$ROUTE" --start="$Z" --start-speed=0 --event-seed=7 $K 2>&1 \
        | grep "FPS medio" | sed -n 2p
  done
done
