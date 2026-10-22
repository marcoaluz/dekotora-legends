#!/usr/bin/env bash
# T-198: custo das cameras e do retrovisor. Qualidade media no Compatibility (o que o celular usa) e Ultra (PC).
# Roda UM processo por vez (memoria do PC). Imprime as 2 ultimas medias de 5 s de cada caso.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t198.sh [QUADROS=3000] [night|day] [RES=1920x1080]
#   MEASURE_Q="media" so a media; SPOTS="kanto_2_viaduct:1400" troca os pontos; CASES="standard:off standard:on" troca os casos.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-3000}"
TOD="${2:-night}"
RES="${3:-1920x1080}"
QS="${MEASURE_Q:-media ultra}"
SPOTS="${SPOTS:-kanto_1_coast:1300 kanto_2_viaduct:1400}"
CASES="${CASES:-standard:off standard:on near:on far:on cinema:off orbit:on}"
for SPOT in $SPOTS; do
  R="${SPOT%%:*}"; Z="${SPOT##*:}"
  for Q in $QS; do
    if [ "$Q" = media ]; then FLAGS=(--rendering-method gl_compatibility); EX=(--quality=1 --life=off)
    else FLAGS=(); EX=(--quality=3 --life=on); fi
    for C in $CASES; do
      CAM="${C%%:*}"; MIR="${C##*:}"
      echo "== $R start=$Z $TOD $Q camera=$CAM retrovisor=$MIR"
      timeout 300 "$GODOT" --path game "${FLAGS[@]}" --resolution "$RES" --disable-vsync --quit-after "$FRAMES" \
          res://scenes/race/race3d.tscn -- --fps-log "${EX[@]}" --route="$R" --start="$Z" --start-speed=22 --autoplay \
          --event-seed=7 --no-intro --no-rain --no-motion-blur --time="$TOD" --race-cam="$CAM" --mirror="$MIR" \
          ${MEASURE_EXTRA:-} 2>&1 | grep -E "FPS medio|SCRIPT ERROR|Parse Error" | tail -n 2 || true
    done
  done
done
