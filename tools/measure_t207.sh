#!/usr/bin/env bash
# T-207: custo da praca de pedagio. O caminhao do jogador sai 50 m antes da ilha e passa por baixo da cobertura
# (piloto automatico); compara com --no-toll (pedagio antigo, sem fisica). Um processo por vez.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t207.sh [QUADROS=1500] [night|day] [RES=1920x1080]
#   MEASURE_Q="media" so a media (Compatibility = celular); ROUTES="kanto_1_coast ..." filtra.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-1500}"
TOD="${2:-night}"
RES="${3:-1920x1080}"
QS="${MEASURE_Q:-media ultra}"
for ROUTE in ${ROUTES:-kanto_1_coast kanto_2_viaduct}; do
  for Q in $QS; do
    if [ "$Q" = media ]; then FLAGS=(--rendering-method gl_compatibility); EX=(--quality=1 --life=off)
    else FLAGS=(); EX=(--quality=3 --life=on); fi
    for CASE in depois antes; do
      [ "$CASE" = antes ] && X="--no-toll" || X=""
      for TRY in 1 2; do
        echo "== $ROUTE $TOD $Q $RES $CASE ($TRY)"
        timeout 300 "$GODOT" --path game "${FLAGS[@]}" --resolution "$RES" --disable-vsync --quit-after "$FRAMES" \
            res://scenes/race/race3d.tscn -- --fps-log "${EX[@]}" --route="$ROUTE" --start=82 --start-speed=10 --autoplay \
            --event-seed=7 --no-intro --no-rain --no-motion-blur --time="$TOD" $X 2>&1 \
            | grep -E "FPS medio|SCRIPT ERROR|Parse Error" | head -n 1 || true
      done
    done
  done
done
