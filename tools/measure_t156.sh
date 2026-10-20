#!/usr/bin/env bash
# T-156: custo da abertura "frente a frente" no modo MEDIO (sem vsync), nas 3 rotas (tarde, noite, dia).
#   Durante a abertura o --fps-log imprime a cada 2 s com "[abertura <momento>]"; depois a corrida (autoplay) a cada 5 s.
#   Compare com a mesma rota sem abertura: MEASURE_EXTRA="--intro=none" bash tools/measure_t156.sh
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t156.sh
: "${GODOT:?defina GODOT (tools/env.sh)}"
for ROUTE in kanto_1_coast kanto_2_viaduct kanto_3_mountain; do
  echo "== $ROUTE ${MEASURE_EXTRA:-abertura cheia}"
  "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after 4200 res://scenes/race/race3d.tscn -- \
      --fps-log --quality=1 --route="$ROUTE" --autoplay --decorated --event-seed=7 $MEASURE_EXTRA 2>&1 \
      | grep -E "FPS medio|ABERTURA|SCRIPT ERROR" | head -9 || true
done
