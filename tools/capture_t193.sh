#!/usr/bin/env bash
# T-193: prints dos modelos novos (carro unico, predios texturizados, neon kanji, skyline ao longe)
# com a CAMERA LIVRE, sem teclado. Precisa de janela (sem --headless). Antes: -- --no-city-models --no-unique-car
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t193.sh PASTA [day|night ...] [-- extras...]
#   Comparar com o trecho-piloto/visual antigo: ... -- --t188=segment   ou   -- --t188=off
# Grava PASTA/<hora>/<rota>_<pose>.png e imprime "TOUR rota pose km draw tri fps".
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
TIMES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do TIMES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#TIMES[@]} -eq 0 ] && TIMES=(day night)
# pose = nome@km,lateral_m,altura_m,giro_graus,inclinacao_graus (giro positivo = para a esquerda)
COAST="unico@1.31,8,3.5,-28,-6;unico_perto@1.335,10,2.5,-60,-10;fim@2.75,0,4.5,0,-4"
CITY="unico@0.61,8,6,-45,-28;predios@1.50,-6,6,70,-6;predios_dir@0.80,6,6,-70,-6;alto@1.00,0,60,25,-18;neon@0.70,-6,4,80,-2;skyline@1.25,0,40,95,-2;fim@2.60,0,4.5,0,-4"
MOUNT="unico@1.225,-6,12,40,-28;unico_perto@1.245,-10,2.5,60,-10;fim@2.70,0,4.5,0,-3"
for T in "${TIMES[@]}"; do
  for SPEC in "kanto_1_coast|$COAST" "kanto_2_viaduct|$CITY" "kanto_3_mountain|$MOUNT"; do
    ROUTE="${SPEC%%|*}"
    TOUR="${SPEC#*|}"
    for TRY in 1 2; do
      "$GODOT" --path game --resolution 1280x720 res://scenes/race/race3d.tscn -- --route="$ROUTE" --quality=1 --no-motion-blur \
          --no-intro --no-rain --life=off --event-seed=7 --time="$T" --freecam --freecam-tour="$OUT/$T" --tour="$TOUR" "$@" 2>&1 \
          | grep -E "^TOUR|SCRIPT ERROR|Parse Error|^ERROR" | sed "s/^TOUR/TOUR $T/"
      [ -f "$OUT/$T/${ROUTE}_fim.png" ] && break
    done
  done
done
echo "capturas em $OUT"
