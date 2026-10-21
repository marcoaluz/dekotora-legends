#!/usr/bin/env bash
# Capturas da T-163 (pilar em T, guard-rail em W, postes de energia com fios), de dia e de noite, caminhao parado,
# camera fixa, sem HUD. Precisa de janela (nao use --headless).
# Uso (raiz do projeto, Git Bash): bash tools/capture_t163.sh PASTA [FILTRO] [extra...]
#   Grava PASTA/<cena>_<hora>/t01.png. FILTRO = trecho do nome (ex.: pilar, poste, night); "all" = tudo.
#   Antes/depois: bash tools/capture_t163.sh PASTA_ANTES all --no-pontes-kit
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac   # o jogo roda com --path game: caminho absoluto
FILTER="${2:-all}"
shift; shift || true
shot() {   # cena rota z hora camera [extras...]
  local name="$1_$4" dir="$OUT/$1_$4" route="$2" z="$3" tod="$4" cam="$5"
  shift 5
  if [ "$FILTER" != "all" ] && [[ "$name" != *"$FILTER"* ]]; then return; fi
  "$GODOT" --path game --resolution 1280x720 --quit-after 330 res://scenes/race/race3d.tscn -- \
      --route="$route" --start="$z" --start-speed=0 --time="$tod" --nohud --shots="$dir" --snap-every=3.5 \
      --event-seed=7 --cam="$cam" "$@" >/dev/null 2>&1
  echo "$name"
}
for T in day night; do
  shot pilar_ponte kanto_1_coast 2520 $T "10,-26,9,40,0,0" "$@"
  shot pilar_ponte_mar kanto_1_coast 2500 $T "30,34,1.5,40,2,-4" "$@"
  shot pilar_viaduto kanto_2_viaduct 600 $T "18,-30,-7,40,0,-4" "$@"
  shot pilar_viaduto_antigo kanto_2_viaduct 2330 $T "18,-28,-7,40,0,-4" "$@"
  shot guardrail_litoral kanto_1_coast 640 $T "2,10.5,1.6,26,13.3,0.5" "$@"
  shot guardrail_litoral_alto kanto_1_coast 640 $T "-14,4,7,40,10,0" "$@"
  shot poste_montanha kanto_3_mountain 1500 $T "-12,3,5,45,17,7" "$@"
  shot poste_montanha_corrida kanto_3_mountain 1500 $T "-18,0,7.5,30,0,1.5" "$@"
  shot poste_litoral kanto_1_coast 600 $T "-12,-3,5,45,-17,7" "$@"
done
echo "capturas em $OUT"
