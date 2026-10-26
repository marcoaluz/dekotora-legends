#!/usr/bin/env bash
# T-217: prints da ambientacao (mesmas poses antes/depois), camera livre sem painel (--tour-clean).
# Precisa de janela (sem --headless). Roda UM processo por vez (memoria do PC).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t217.sh PASTA [day night] [-- extras...]
#   Q=1 (padrao, media no Compatibility = celular) ou Q=3 (Ultra, Forward+). ROUTES="kanto_1_coast ..." filtra rotas.
#   POSES="muro;tunel" filtra poses pelo nome (trecho). GAME=pasta do projeto Godot (padrao game; "antes" = worktree).
#   Grava PASTA/<hora>/<rota>_<pose>.png.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
GAME="${GAME:-game}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
TIMES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do TIMES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#TIMES[@]} -eq 0 ] && TIMES=(day night)
Q="${Q:-1}"
if [ "$Q" = 3 ]; then RM=(); else RM=(--rendering-method gl_compatibility); fi
# pose = nome@km,lateral_m,altura_m,giro_graus,inclinacao_graus (lateral + = direita; giro + = para a esquerda)
COAST="pista@0.62,-3,4.2,0,-2;contraria@1.02,6,4.5,-38,-5;muro@2.12,4,3.2,25,-3;placa@0.86,0,5,0,0;placa_azul@1.64,-2,4.5,6,1;farol@1.70,6,7,-43,-2;porto@0.58,8,6,-50,-6;praia@1.20,10,4,-48,-6;ponte@2.30,0,6,0,-4;alto@1.30,0,60,-30,-18"
CITY="pista@0.55,-3,4.2,0,-2;danchi@0.80,-4,6,48,-3;danchi_longe@1.62,-3,8,22,-5;tunel_boca@0.93,0,4.5,0,-1;tunel_dentro@1.10,-3,4,0,-1;tunel_saida@1.24,0,4,0,0;contraria@1.95,5,5,-35,-6;placa_azul@2.04,-2,4.5,6,1;alto@1.60,0,60,20,-20"
MOUNT="pista@0.35,-3,4.2,0,-2;muro@0.60,4,3.2,35,-3;muro_dir@1.48,-4,3.2,-35,-3;tunel_boca@0.76,0,4.5,0,-1;tunel_dentro@0.92,-3,4,0,-1;tunel_saida@1.03,0,4,0,0;cachoeira@1.10,-5,5,35,9;obra@0.50,22,6,-75,-10;floresta@1.50,10,5,-50,-10;contraria@1.85,6,5,-38,-5;placa_azul@1.49,-2,4.5,6,1;ponte_pensil@1.35,8,12,-62,4;alto@1.40,0,70,15,-16"
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
      timeout 420 "$GODOT" --path "$GAME" "${RM[@]}" --resolution 1280x720 res://scenes/race/race3d.tscn -- --route="$ROUTE" \
          --quality="$Q" --no-motion-blur --no-intro --no-rain --life=off --event-seed=7 --time="$T" --freecam \
          --freecam-tour="$OUT/$T" --tour="$TOUR" --tour-clean "$@" 2>&1 \
          | grep -E "^TOUR|SCRIPT ERROR|Parse Error|^ERROR" | sed "s/^TOUR/TOUR $T/"
      [ -f "$OUT/$T/${ROUTE}_${LAST}.png" ] && break
    done
  done
done
echo "capturas em $OUT"
