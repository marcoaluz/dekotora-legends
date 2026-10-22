#!/usr/bin/env bash
# T-195: prints da chegada (fim da pista), do trem do Marco, dos pontos do carro unico e do serrilhado.
# Precisa de janela (sem --headless). Roda UMA rota por vez (memoria do PC: nunca rode duas capturas juntas).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t195.sh PASTA GRUPO [day night] [-- extras...]
#   GRUPO: chegada | unico | serra (camera livre)  ou  trem (corrida parada, camera fixa olhando a ferrovia).
#   Q=1 (padrao, media) ou Q=3 (Ultra) troca a qualidade.
# Camera livre: grava PASTA/<hora>/<rota>_<pose>.png e imprime "TOUR hora rota pose km draw tri fps".
# trem: grava PASTA/<rota>_trem_<hora>/tNN.png (um quadro a cada 3,5 s; o 1o trem e sempre o do Marco).
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
GROUP="${2:?grupo}"
shift 2 || true
TIMES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do TIMES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#TIMES[@]} -eq 0 ] && TIMES=(day night)
Q="${Q:-1}"
if [ "$GROUP" = "trem" ]; then
  for T in "${TIMES[@]}"; do
    for SPEC in "kanto_1_coast|600|-6,-8,7,30,-36,3" "kanto_2_viaduct|600|-6,-10,6,30,-40,3" "kanto_3_mountain|1500|-6,-8,7,30,-38,3"; do
      IFS='|' read -r ROUTE Z CAM <<< "$SPEC"
      "$GODOT" --path game --resolution 1280x720 --quit-after 1150 res://scenes/race/race3d.tscn -- --route="$ROUTE" \
          --quality="$Q" --no-motion-blur --no-rain --life=off --start="$Z" --start-speed=0 --time="$T" --nohud --no-events \
          --shots="$OUT/${ROUTE}_trem_$T" --snap-every=3.5 --cam="$CAM" "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" | head -3
    done
  done
  echo "capturas em $OUT"; exit 0
fi
# pose = nome@km,lateral_m,altura_m,giro_graus,inclinacao_graus (giro positivo = para a esquerda)
case "$GROUP" in
  chegada)
    COAST="chegada@2.70,0,4.5,0,-3;linha@2.96,0,4.5,0,-3;pos@3.10,0,4.5,0,-3;alto@2.85,0,40,0,-12"
    CITY="chegada@2.45,0,4.5,0,-3;linha@2.71,0,4.5,0,-3;pos@2.85,0,4.5,0,-3;alto@2.60,0,40,0,-12"
    MOUNT="chegada@2.50,0,4.5,0,-3;linha@2.76,0,4.5,0,-3;pos@2.90,0,4.5,0,-3;alto@2.65,0,40,0,-12" ;;
  unico)
    COAST="unico@1.31,8,3.5,-28,-6;unico_perto@1.335,10,2.5,-60,-10"
    CITY="unico@0.61,8,6,-45,-28;unico_perto@0.63,10,9,-60,-14"
    MOUNT="unico@1.225,-6,12,40,-28;unico_perto@1.245,-10,2.5,60,-10" ;;
  serra)
    COAST="serra_palmeira@1.90,6,3,-30,-3;serra_mureta@1.20,0,3,0,-4"
    CITY="serra_predios@1.50,-6,6,40,-4;serra_asfalto@2.00,0,3,0,-8"
    MOUNT="serra_floresta@0.50,-6,4,45,-2;serra_postes@1.60,0,4,0,-3" ;;
  *) echo "grupo desconhecido: $GROUP"; exit 1 ;;
esac
for T in "${TIMES[@]}"; do
  for SPEC in "kanto_1_coast|$COAST" "kanto_2_viaduct|$CITY" "kanto_3_mountain|$MOUNT"; do
    ROUTE="${SPEC%%|*}"
    TOUR="${SPEC#*|}"
    LAST="${TOUR##*;}"; LAST="${LAST%%@*}"
    for TRY in 1 2; do
      "$GODOT" --path game --resolution 1280x720 res://scenes/race/race3d.tscn -- --route="$ROUTE" --quality="$Q" --no-motion-blur \
          --no-intro --no-rain --life=off --event-seed=7 --time="$T" --freecam --freecam-tour="$OUT/$T" --tour="$TOUR" "$@" 2>&1 \
          | grep -E "^TOUR|SCRIPT ERROR|Parse Error|^ERROR" | sed "s/^TOUR/TOUR $T/"
      [ -f "$OUT/$T/${ROUTE}_${LAST}.png" ] && break
    done
  done
done
echo "capturas em $OUT"
