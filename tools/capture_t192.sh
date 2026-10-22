#!/usr/bin/env bash
# T-192: prints das 3 ROTAS INTEIRAS (inicio, emendas do antigo trecho-piloto, tuneis, ponte, viaduto, fim, pintura
# do asfalto) com a CAMERA LIVRE, sem teclado. Mesmas poses antes e depois. Precisa de janela (sem --headless).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t192.sh PASTA [day|night ...] [-- extras...]
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
COAST="inicio@0.15,0,4.5,0,-4;emenda@0.50,-8,6,45,-4;terra@1.05,-8,6,62,-4;mar@1.90,8,5,-58,-6;terra_fim@2.05,-8,6,62,-4;ponte@2.30,0,6,0,-4;alto@2.10,0,55,20,-16;fim@2.75,0,4.5,0,-4"
CITY="inicio@0.15,0,4.5,0,-4;pintura@1.555,0,3.2,0,-14;predios_ini@0.55,-6,6,70,-10;tunel@0.90,0,4.5,0,-4;alto@0.60,0,55,25,-20;predios_fim@2.20,6,6,-70,-10;viaduto_velho@2.30,0,5,0,-4;fim@2.60,0,4.5,0,-4"
MOUNT="inicio@0.15,0,4.5,0,-3;pintura@0.245,0,3.2,0,-14;encosta_ini@0.50,-8,6,60,-2;tunel1@0.72,0,4.5,0,-3;tunel2@2.00,0,4.5,0,-3;encosta_fim@2.45,8,6,-60,-2;alto@2.50,0,55,15,-14;fim@2.70,0,4.5,0,-3"
for T in "${TIMES[@]}"; do
  for SPEC in "kanto_1_coast|$COAST" "kanto_2_viaduct|$CITY" "kanto_3_mountain|$MOUNT"; do
    ROUTE="${SPEC%%|*}"
    TOUR="${SPEC#*|}"
    for TRY in 1 2; do
      "$GODOT" --path game --resolution 1280x720 res://scenes/race/race3d.tscn -- --route="$ROUTE" --quality=1 \
          --no-intro --no-rain --life=off --event-seed=7 --time="$T" --freecam --freecam-tour="$OUT/$T" --tour="$TOUR" "$@" 2>&1 \
          | grep -E "^TOUR|SCRIPT ERROR|Parse Error|^ERROR" | sed "s/^TOUR/TOUR $T/"
      [ -f "$OUT/$T/${ROUTE}_fim.png" ] && break
    done
  done
done
echo "capturas em $OUT"
