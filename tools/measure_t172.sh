#!/usr/bin/env bash
# Custo das pecas deluxe (T-172) na corrida, modo MEDIO, sem vsync: caminhao de demonstracao com as pecas antigas
# (ANTES) e com as 6 deluxe no lugar das antigas do mesmo encaixe (DEPOIS). Mesma rota, semente de eventos fixa.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t172.sh [ROTA] [HORA] [QUADROS]
: "${GODOT:?defina GODOT (tools/env.sh)}"
ROUTE="${1:-kanto_2_viaduct}"
TOD="${2:-night}"
FRAMES="${3:-6000}"
DX="andon_ichiban_dx,marker_crown_dx,underglow_neon_dx,side_bumper_dx,step_lit_dx,rear_tail_bar_dx"
run() {
  "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after "$FRAMES" res://scenes/race/race3d.tscn -- \
      --fps-log --quality=1 --decorated --route="$ROUTE" --time="$TOD" --start=300 --start-speed=22 --autoplay \
      --event-seed=7 "$@" 2>&1 | grep -E "FPS medio|SUPERFICIES|SCRIPT ERROR|Parse Error" || true
}
echo "== ANTES ($ROUTE $TOD)"
run
echo "== DEPOIS (+ deluxe)"
run --parts="$DX"
