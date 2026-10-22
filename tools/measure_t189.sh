#!/usr/bin/env bash
# T-189: FPS no trecho-piloto de cada rota, MEDIA (Compatibility, --quality=1, sem vida = como o celular) x ULTRA
# (Forward+, --quality=3, vida ligada), sem vsync. O caminhao anda sozinho (eventos com semente fixa) e o jogo
# imprime medias de 5 s; aqui sai a ultima media de cada corrida.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t189.sh [QUADROS] [day|night] [LARGURAxALTURA]
#   MEASURE_EXTRA="--rain" bash tools/measure_t189.sh 1500 night     (com chuva)
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
FRAMES="${1:-1500}"
TOD="${2:-night}"
RES="${3:-1920x1080}"
for SPOT in "kanto_1_coast 650" "kanto_2_viaduct 1350" "kanto_3_mountain 1150"; do
  set -- $SPOT
  for Q in media ultra; do
    if [ "$Q" = media ]; then FLAGS=(--rendering-method gl_compatibility); EX=(--quality=1 --life=off)
    else FLAGS=(); EX=(--quality=3 --life=on); fi
    echo "== $1 start=$2 $TOD $Q $RES ${MEASURE_EXTRA:-}"
    timeout 300 "$GODOT" --path game "${FLAGS[@]}" --resolution "$RES" --disable-vsync --quit-after "$FRAMES" \
        res://scenes/race/race3d.tscn -- --fps-log "${EX[@]}" --route="$1" --start="$2" --start-speed=22 --autoplay \
        --event-seed=7 --no-intro --no-rain --no-motion-blur --time="$TOD" $MEASURE_EXTRA 2>&1 \
        | grep -E "FPS medio|SCRIPT ERROR|Parse Error" | tail -n 2 || true
  done
done
