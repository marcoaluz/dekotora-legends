#!/usr/bin/env bash
# T-217: custo da ambientacao: FPS medio, chamadas e triangulos em pontos das 3 rotas (inclui a pista contraria,
# muros de pedra, danchi, tunel gemeo e a cachoeira), corrida de verdade (camera da corrida, autoplay).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t217.sh [QUADROS=3000] [day|night] [RES=1280x720]
#   GAME=pasta (padrao game; "antes" = worktree do commit anterior). MEASURE_Q="media ultra" (padrao so media).
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
GAME="${GAME:-game}"
FRAMES="${1:-3000}"
TOD="${2:-day}"
RES="${3:-1280x720}"
QS="${MEASURE_Q:-media}"
for SPOT in "kanto_1_coast 550" "kanto_1_coast 2150" "kanto_2_viaduct 700" "kanto_2_viaduct 1000" \
    "kanto_3_mountain 330" "kanto_3_mountain 1060"; do
  set -- $SPOT
  for Q in $QS; do
    if [ "$Q" = media ]; then FLAGS=(--rendering-method gl_compatibility); EX=(--quality=1 --life=off)
    else FLAGS=(); EX=(--quality=3 --life=on); fi
    echo "== $1 start=$2 $TOD $Q $RES ${MEASURE_EXTRA:-}"
    timeout 300 "$GODOT" --path "$GAME" "${FLAGS[@]}" --resolution "$RES" --disable-vsync --quit-after "$FRAMES" \
        res://scenes/race/race3d.tscn -- --fps-log "${EX[@]}" --route="$1" --start="$2" --start-speed=22 --autoplay \
        --event-seed=7 --no-intro --no-rain --no-motion-blur --mirror=off --time="$TOD" $MEASURE_EXTRA 2>&1 \
        | grep -E "FPS medio|SCRIPT ERROR|Parse Error" | tail -n 2 || true
  done
done
