#!/usr/bin/env bash
# T-199: prints do polimento do cenario (mesmas poses antes/depois), camera livre sem painel (--tour-clean).
# Precisa de janela (sem --headless). Roda UM processo por vez (memoria do PC).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t199.sh PASTA [day night] [-- extras...]
#   Q=1 (padrao, media no Compatibility = celular) ou Q=3 (Ultra, Forward+). ROUTES="kanto_1_coast ..." filtra rotas.
#   POSES="portico;chegada" filtra poses pelo nome (trecho). Grava PASTA/<hora>/<rota>_<pose>.png.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
TIMES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do TIMES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#TIMES[@]} -eq 0 ] && TIMES=(day night)
Q="${Q:-1}"
if [ "$Q" = 3 ]; then RM=(); else RM=(--rendering-method gl_compatibility); fi
# pose = nome@km,lateral_m,altura_m,giro_graus,inclinacao_graus (giro positivo = para a esquerda)
COAST="portico@0.25,0,4.5,0,0;terra@1.05,-8,6,62,-4;mar@1.90,8,5,-58,-6;mureta@1.20,9.5,1.4,-12,-4;ponte@2.30,0,6,0,-4;unico@1.31,8,3.5,-28,-6;chegada@2.84,0,4.5,0,-1;farois@0.06,0,2.2,180,-2;alto@2.10,0,55,20,-16"
CITY="portico@0.25,0,4.5,0,0;predios_ini@0.55,-6,6,70,-10;predios_rua@1.50,-6,6,40,-4;predios_fim@2.20,6,6,-70,-10;viaduto_velho@2.30,0,5,0,-4;unico@0.61,8,6,-45,-28;chegada@2.59,0,4.5,0,-1;farois@0.06,0,2.2,180,-2;alto@0.60,0,55,25,-20"
MOUNT="portico@0.25,0,4.5,0,0;encosta@0.50,-8,6,60,-2;floresta@1.50,10,5,-50,-10;postes@1.60,0,4,0,-3;viaduto@2.555,0,3,0,10;unico@1.225,-6,12,40,-28;chegada@2.64,0,4.5,0,-1;farois@0.06,0,2.2,180,-2;alto@2.50,0,55,15,-14"
pick() {   # filtra as poses pelo POSES
  [ -z "${POSES:-}" ] && { echo "$1"; return; }
  local out="" p
  IFS=';' read -ra ITEMS <<< "$1"
  for p in "${ITEMS[@]}"; do
    IFS=';' read -ra WANT <<< "$POSES"
    for w in "${WANT[@]}"; do case "${p%%@*}" in *"$w"*) out="$out;$p" ;; esac; done
  done
  echo "${out#;}"
}
for T in "${TIMES[@]}"; do
  for SPEC in "kanto_1_coast|$COAST" "kanto_2_viaduct|$CITY" "kanto_3_mountain|$MOUNT"; do
    ROUTE="${SPEC%%|*}"
    case " ${ROUTES:-kanto_1_coast kanto_2_viaduct kanto_3_mountain} " in *" $ROUTE "*) ;; *) continue ;; esac
    TOUR="$(pick "${SPEC#*|}")"
    [ -z "$TOUR" ] && continue
    LAST="${TOUR##*;}"; LAST="${LAST%%@*}"
    for TRY in 1 2; do
      timeout 400 "$GODOT" --path game "${RM[@]}" --resolution 1280x720 res://scenes/race/race3d.tscn -- --route="$ROUTE" \
          --quality="$Q" --no-motion-blur --no-intro --no-rain --life=off --event-seed=7 --time="$T" --freecam \
          --freecam-tour="$OUT/$T" --tour="$TOUR" --tour-clean "$@" 2>&1 \
          | grep -E "^TOUR|SCRIPT ERROR|Parse Error|^ERROR" | sed "s/^TOUR/TOUR $T/"
      [ -f "$OUT/$T/${ROUTE}_${LAST}.png" ] && break
    done
  done
done
echo "capturas em $OUT"
