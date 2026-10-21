#!/usr/bin/env bash
# T-188: prints do trecho-piloto de cada rota (cenario novo) com a CAMERA LIVRE, sem teclado, dia e noite.
# Mesmas poses antes e depois. Precisa de janela (nao use --headless). Modo medio (--quality=1).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t188.sh PASTA [day|night|dusk ...] [-- extras...]
#   Antes (visual antigo): bash tools/capture_t188.sh PASTA_ANTES day night -- --t188=off
# Grava PASTA/<hora>/<rota>_<pose>.png e imprime "TOUR rota pose km draw tri fps".
# Trechos (Scenery188.zone): litoral 0,60-1,60 km; cidade 1,30-2,05 km; montanha 1,10-2,05 km.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac   # o jogo roda com --path game: caminho absoluto
shift || true
TIMES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do TIMES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#TIMES[@]} -eq 0 ] && TIMES=(day night)
# pose = nome@km,lateral_m,altura_m,giro_graus,inclinacao_graus (giro positivo = para a esquerda)
COAST="jogo@0.70,0,4.5,0,-4;terra@1.05,-8,6,62,-4;mar@1.10,8,5,-58,-6;placa@0.91,0,5.5,0,1;alto@0.80,0,45,18,-16"
CITY="jogo@1.40,0,4.5,0,-4;predios@1.55,-6,6,70,-10;predios_dir@1.75,6,6,-70,-10;placa@1.56,0,5.5,0,1;alto@1.45,0,55,25,-20"
MOUNT="jogo@1.20,0,4.5,0,-3;encosta@1.45,-8,6,60,-2;encosta_dir@1.75,8,6,-60,-2;placa@1.56,0,5.5,0,1;alto@1.30,0,55,15,-14"
for T in "${TIMES[@]}"; do
  for SPEC in "kanto_1_coast|$COAST" "kanto_2_viaduct|$CITY" "kanto_3_mountain|$MOUNT"; do
    ROUTE="${SPEC%%|*}"
    TOUR="${SPEC#*|}"
    "$GODOT" --path game --resolution 1280x720 res://scenes/race/race3d.tscn -- --route="$ROUTE" --quality=1 \
        --no-intro --event-seed=7 --time="$T" --freecam --freecam-tour="$OUT/$T" --tour="$TOUR" "$@" 2>&1 \
        | grep -E "^TOUR|SCRIPT ERROR|Parse Error|^ERROR" | sed "s/^TOUR/TOUR $T/"
  done
done
echo "capturas em $OUT"
