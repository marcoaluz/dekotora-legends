#!/usr/bin/env bash
# T-192: custo do cenario novo na ROTA INTEIRA (3 pontos espalhados por rota), MEDIA (Compatibility, --quality=1,
# sem vida = como o celular) x ULTRA (Forward+, --quality=3, vida ligada), sem vsync. O caminhao anda sozinho
# (eventos com semente fixa); sai a ultima media de 5 s de cada corrida (FPS, chamadas, triangulos, textura).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t192.sh [QUADROS] [day|night] [LARGURAxALTURA]
#   Antes/comparar: MEASURE_EXTRA="--t188=off" (visual antigo) ou "--t188=segment" (so o trecho-piloto)
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-3000}"
TOD="${2:-night}"
RES="${3:-1920x1080}"
QS="${MEASURE_Q:-media ultra}"
for SPOT in "kanto_1_coast 100" "kanto_1_coast 1100" "kanto_1_coast 2100" "kanto_2_viaduct 100" \
    "kanto_2_viaduct 1400" "kanto_2_viaduct 2150" "kanto_3_mountain 100" "kanto_3_mountain 1200" \
    "kanto_3_mountain 2400"; do
  set -- $SPOT
  for Q in $QS; do
    if [ "$Q" = media ]; then FLAGS=(--rendering-method gl_compatibility); EX=(--quality=1 --life=off)
    else FLAGS=(); EX=(--quality=3 --life=on); fi
    echo "== $1 start=$2 $TOD $Q $RES ${MEASURE_EXTRA:-}"
    timeout 300 "$GODOT" --path game "${FLAGS[@]}" --resolution "$RES" --disable-vsync --quit-after "$FRAMES" \
        res://scenes/race/race3d.tscn -- --fps-log "${EX[@]}" --route="$1" --start="$2" --start-speed=22 --autoplay \
        --event-seed=7 --no-intro --no-rain --no-motion-blur --time="$TOD" $MEASURE_EXTRA 2>&1 \
        | grep -E "FPS medio|SCRIPT ERROR|Parse Error" | tail -n 2 || true
  done
done
