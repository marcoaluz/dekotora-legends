#!/usr/bin/env bash
# T-154: custo da ferrovia no modo MEDIO nas 3 rotas, com e sem (--no-rail).
#   andando: caminhao sozinho de 300 m em diante (como tools/measure_roadside.sh), eventos com semente fixa;
#   parado:  caminhao parado em Z (padrao 640 m); o 1o trem passa ~10 s depois da largada (3a media de 5 s).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_railway.sh [Z]
: "${GODOT:?defina GODOT (tools/env.sh)}"
Z="${1:-640}"
for ROUTE in kanto_1_coast kanto_2_viaduct kanto_3_mountain; do
  for K in "" "--no-rail"; do
    echo "== $ROUTE ${K:-com ferrovia} (andando)"
    "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after 2400 res://scenes/race/race3d.tscn -- \
        --fps-log --quality=1 --route="$ROUTE" --start=300 --start-speed=22 --autoplay --event-seed=7 $K 2>&1 \
        | grep -E "FPS medio|FERROVIA|SCRIPT ERROR" || true
    echo "== $ROUTE ${K:-com ferrovia} (parado em $Z, trem passando)"
    "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after 3600 res://scenes/race/race3d.tscn -- \
        --fps-log --quality=1 --route="$ROUTE" --start="$Z" --start-speed=0 --event-seed=7 $K 2>&1 \
        | grep -E "FPS medio" | head -3 || true
  done
done
