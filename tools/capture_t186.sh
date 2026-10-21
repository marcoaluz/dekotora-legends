#!/usr/bin/env bash
# T-186: prints de cada rota com a CAMERA LIVRE (painel com FPS e chamadas de desenho visivel), sem teclado:
# o jogo abre na camera livre (--freecam), visita as poses de cada rota (--freecam-tour) e fecha.
# Precisa de janela (nao use --headless). Modo medio (--quality=1), hora da propria rota.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t186.sh PASTA [extras...]
#   Antes (visual antigo): bash tools/capture_t186.sh PASTA_ANTES --old-trees --old-lamps --no-people
# Grava PASTA/<rota>_<pose>.png e imprime linhas "TOUR rota pose km draw tri fps".
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac   # o jogo roda com --path game: caminho absoluto
shift || true
# pose = nome@km,lateral_m,altura_m,giro_graus,inclinacao_graus (giro em relacao ao sentido da pista; positivo = para a esquerda)
COAST="pedagio@0.128,0,2.5,0,-3;bosque_terra@0.9,-9,6,55,-12;palmeiras_mar@1.3,9,5,-60,-10;ponte@2.15,0,7,0,-8;alto@1.6,0,45,0,-32"
CITY="pedagio@0.128,0,2.5,0,-3;arvores_rua@0.75,-12,6,75,-25;postes_viaduto@1.3,0,5,0,-5;viaduto_pessoas@2.025,0,3,0,10;alto@1.2,0,60,0,-35"
MOUNT="pedagio@0.128,0,2.5,0,-3;floresta_esq@1.5,-10,5,50,-10;floresta_dir@1.5,10,5,-50,-10;viaduto_pessoas@2.555,0,3,0,10;alto@1.4,0,60,0,-35"
CITY_DAY="dia_arvores_rua@0.75,-12,6,75,-25;dia_viaduto_pessoas@2.025,0,3,0,10;dia_alto@1.2,0,60,0,-35"
for SPEC in "kanto_1_coast|$COAST" "kanto_2_viaduct|$CITY" "kanto_3_mountain|$MOUNT" "kanto_2_viaduct|$CITY_DAY|--time=day"; do
  ROUTE="${SPEC%%|*}"
  REST="${SPEC#*|}"
  TOUR="${REST%%|*}"
  XTRA=""
  [ "$REST" != "$TOUR" ] && XTRA="${REST#*|}"
  "$GODOT" --path game --resolution 1280x720 res://scenes/race/race3d.tscn -- --route="$ROUTE" --quality=1 \
      --no-intro --event-seed=7 --freecam --freecam-tour="$OUT" --tour="$TOUR" $XTRA "$@" 2>&1 | grep -E "^TOUR|SCRIPT ERROR|Parse Error"
done
echo "capturas em $OUT"
