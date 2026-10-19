#!/usr/bin/env bash
# Capturas da T-153 (trechos de 2 faixas): afunilamento, dentro do trecho (tunel antigo, ponte, viaduto antigo) e
# reabertura, de dia e de noite, caminhao parado e camera fixa, sem HUD.
# Uso (raiz do projeto, Git Bash): bash tools/capture_t153.sh PASTA [FILTRO] [extra...]
#   Grava PASTA/<rota>_<cena>_<hora>/t01.png. FILTRO (opcional) = trecho do nome (ex.: coast, tunel, night); "all" = tudo.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac   # o jogo roda com --path game: caminho absoluto
FILTER="${2:-all}"
shift; shift || true
shot() {   # rota cena z hora camera(ou "") [extras...]
  local name="$1_$2_$4" dir="$OUT/$1_$2_$4" route="$1" z="$3" tod="$4" cam="$5"
  shift 5
  if [ "$FILTER" != "all" ] && [[ "$name" != *"$FILTER"* ]]; then return; fi
  "$GODOT" --path game --resolution 1280x720 --quit-after 330 res://scenes/race/race3d.tscn -- \
      --route="$route" --start="$z" --start-speed=0 --time="$tod" --nohud --shots="$dir" --snap-every=3.5 \
      --event-seed=7 ${cam:+--cam=$cam} "$@" >/dev/null 2>&1
  echo "$name"
}
HI="-20,0,24,120,0,0"          # alto atras, olhando o afunilamento inteiro
LOW="-18,0,7.5,30,0,1.5"        # atras e acima dos caminhoes (como a camera da corrida, mais alta)
SIDE="10,-26,9,40,0,0"          # de fora, pela esquerda (ponte e pilares)
for T in day night; do
  shot kanto_1_coast afunila 2250 $T "$HI" "$@"
  shot kanto_1_coast ponte 2470 $T "$LOW" "$@"
  shot kanto_1_coast ponte_fora 2520 $T "$SIDE" "$@"
  shot kanto_1_coast alarga 2720 $T "$HI" "$@"
  shot kanto_2_viaduct afunila 2120 $T "$HI" "$@"
  shot kanto_2_viaduct viaduto_antigo 2330 $T "$LOW" "$@"
  shot kanto_2_viaduct viaduto_fora 2350 $T "$SIDE" "$@"
  shot kanto_3_mountain afunila 630 $T "$HI" "$@"
  shot kanto_3_mountain boca_tunel 770 $T "-6,-2,5,40,-2.4,4" "$@"
  shot kanto_3_mountain tunel 870 $T "-13,-2.4,4.6,30,-2.4,1.5" "$@"
  shot kanto_3_mountain alarga 1050 $T "$HI" "$@"
done
echo "capturas em $OUT"
