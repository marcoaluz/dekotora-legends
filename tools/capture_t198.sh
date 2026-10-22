#!/usr/bin/env bash
# T-198: prints das cameras da corrida (perto, padrao, longe, cinema, orbita) com o retrovisor ligado e o rival atras.
# Precisa de janela (sem --headless). UM processo por vez (memoria do PC).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t198.sh PASTA [day night] [-- extras...]
#   CAMS="near orbit" troca a lista de cameras; ROUTE=kanto_2_viaduct troca a rota; Q=3 = Ultra (padrao 1 = media).
# Grava PASTA/<camera>_<hora>/tNN.png (um quadro a cada 2,5 s; o jogador larga 14 m na frente do rival).
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
TIMES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do TIMES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#TIMES[@]} -eq 0 ] && TIMES=(day night)
CAMS="${CAMS:-near standard far cinema orbit}"
ROUTE="${ROUTE:-kanto_1_coast}"
Q="${Q:-1}"
for T in "${TIMES[@]}"; do
  for C in $CAMS; do
    for TRY in 1 2; do
      "$GODOT" --path game --resolution 1280x720 --quit-after 1500 res://scenes/race/race3d.tscn -- --route="$ROUTE" \
          --quality="$Q" --no-motion-blur --no-rain --life=off --start=400 --start-speed=24 --time="$T" --autoplay \
          --event-seed=7 --race-cam="$C" --mirror=on --shots="$OUT/${C}_$T" --snap-every=2.5 "$@" 2>&1 \
          | grep -E "SCRIPT ERROR|Parse Error|^ERROR" | head -3
      [ -f "$OUT/${C}_$T/t02_1.png" ] && break
    done
  done
done
echo "capturas em $OUT"
