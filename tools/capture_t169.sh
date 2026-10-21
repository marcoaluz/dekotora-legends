#!/usr/bin/env bash
# Capturas da T-169 (modelos novos de docs/Modelos: montanhas do horizonte, mar, arvore de folhas, poste; + T-163/T-164),
# caminhao parado, camera fixa, sem HUD. Precisa de janela (nao use --headless).
# Uso (raiz do projeto, Git Bash): bash tools/capture_t169.sh PASTA [FILTRO] [extra...]
#   Grava PASTA/<cena>_<hora>/t01.png. FILTRO = trecho do nome (ex.: montanha, arvore, night); "all" = tudo.
#   Antes (visual antigo): bash tools/capture_t169.sh PASTA_ANTES all --no-backdrop --no-pontes-kit
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
for T in day dusk night; do
  shot montanha_horizonte kanto_3_mountain 1500 $T "-14,0,4.5,60,-10,14" "$@"
  shot montanha_vale kanto_3_mountain 2200 $T "-14,0,4.5,60,12,14" "$@"
  shot litoral_mar kanto_1_coast 900 $T "-12,-3,4,50,22,3" "$@"
  shot litoral_terra kanto_1_coast 900 $T "-12,3,4,60,-25,12" "$@"
  shot cidade_horizonte kanto_2_viaduct 600 $T "-14,0,4,60,0,12" "$@"
done
for T in day night; do
  shot viaduto_cidade kanto_2_viaduct 2040 $T "-14,0,5,100,0,8" "$@"
  shot viaduto_cidade_lado kanto_2_viaduct 2040 $T "70,-60,4,100,0,8" "$@"
  shot viaduto_montanha kanto_3_mountain 2480 $T "-14,0,5,100,0,8" "$@"
  shot viaduto_montanha_lado kanto_3_mountain 2480 $T "60,55,3,100,0,7" "$@"
  shot arvore_montanha kanto_3_mountain 1500 $T "-10,-4,3.5,30,14,5" "$@"
  shot arvore_litoral kanto_1_coast 1300 $T "-10,4,3.5,30,-18,5" "$@"
done
echo "capturas em $OUT"
