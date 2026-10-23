#!/usr/bin/env bash
# T-207: prints da praca de pedagio (ilha central, duas passagens, luzes). Precisa de janela (sem --headless).
# Um processo por vez (memoria). Uso (raiz do projeto, Git Bash):
#   GODOT=... bash tools/capture_t207.sh PASTA [day night dusk] [-- extras...]
#   Q=1 (padrao: media no Compatibility = celular) ou Q=3 (Ultra, Forward+ = PC).
#   RES=1280x720 (padrao) ou RES=1200x540 (proporcao do celular 2400x1080).
#   ROUTES="kanto_1_coast ..." filtra rotas; MODES="tour drive" (padrao os dois).
# tour  = camera livre sem painel: PASTA/<hora>/<rota>_<pose>.png
# drive = camera do jogo, caminhao do jogador na passagem da direita (piloto automatico): PASTA/<hora>/<rota>_drive/t01.png ...
# Antes/depois: bash tools/capture_t207.sh PASTA_ANTES day night -- --no-toll
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
TIMES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do TIMES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#TIMES[@]} -eq 0 ] && TIMES=(day night)
Q="${Q:-1}"
RES="${RES:-1280x720}"
MODES="${MODES:-tour drive}"
TOUCH=(--no-touch); [ "$RES" = 1200x540 ] && TOUCH=(--touch --hud-scale=1.25)   # celular: botoes de toque na tela
if [ "$Q" = 3 ]; then RM=(); else RM=(--rendering-method gl_compatibility); fi
# pose = nome@km,lateral_m,altura_m,giro_graus,inclinacao_graus (giro positivo = para a esquerda); pedagio em 0,150 km
POSES="chegada@0.060,3.6,3.4,0,-2;frente@0.100,0,4.2,0,-5;nariz@0.122,-1.2,1.6,-8,0;lado@0.115,-17,6,-58,-12;cabine@0.140,-3.4,2.0,-30,-2;sob@0.141,3.6,2.4,0,6;alto@0.075,-16,30,-28,-34;saida@0.222,0,5,180,-6"
for T in "${TIMES[@]}"; do
  for ROUTE in ${ROUTES:-kanto_1_coast kanto_2_viaduct kanto_3_mountain}; do
    case " $MODES " in *" tour "*)
      for TRY in 1 2; do
        timeout 400 "$GODOT" --path game "${RM[@]}" --resolution "$RES" res://scenes/race/race3d.tscn -- --route="$ROUTE" \
            --quality="$Q" --no-motion-blur --no-intro --no-rain --life=off --event-seed=7 --time="$T" --freecam \
            --freecam-tour="$OUT/$T" --tour="$POSES" --tour-clean "$@" 2>&1 \
            | grep -E "^TOUR|SCRIPT ERROR|Parse Error|^ERROR|TOLL_T207" | sed "s/^TOUR/TOUR $T/"
        [ -f "$OUT/$T/${ROUTE}_saida.png" ] && break
      done ;;
    esac
    case " $MODES " in *" drive "*)
      mkdir -p "$OUT/$T/${ROUTE}_drive"
      timeout 200 "$GODOT" --path game "${RM[@]}" --resolution "$RES" --quit-after 900 res://scenes/race/race3d.tscn -- \
          --route="$ROUTE" --quality="$Q" --no-motion-blur --no-rain --life=off --event-seed=7 --time="$T" --autoplay \
          --start=40 --start-speed=12 --shots="$OUT/$T/${ROUTE}_drive" --snap-every=1.2 "${TOUCH[@]}" "$@" 2>&1 \
          | grep -E "SCRIPT ERROR|Parse Error|^ERROR|TOLL_T207" ;;
    esac
  done
done
echo "capturas em $OUT"
