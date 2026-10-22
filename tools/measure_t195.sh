#!/usr/bin/env bash
# T-195: custo em 3 pontos por rota (meio da rota e chegada), qualidade media no Compatibility (o que o celular usa)
# e Ultra (PC). Roda UM processo por vez (memoria do PC).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t195.sh [QUADROS=3000] [day|night] [RES=1920x1080]
#   MEASURE_Q="media" so a media; MEASURE_EXTRA="--msaa=0 --no-arrival" = como antes da T-195.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-3000}"
TOD="${2:-night}"
RES="${3:-1920x1080}"
QS="${MEASURE_Q:-media ultra}"
for SPOT in "kanto_1_coast 1300" "kanto_1_coast 2700" "kanto_2_viaduct 1400" "kanto_2_viaduct 2450" \
    "kanto_3_mountain 1200" "kanto_3_mountain 2500"; do
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
