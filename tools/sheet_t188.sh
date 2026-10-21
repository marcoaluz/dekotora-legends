#!/usr/bin/env bash
# T-188: folhas antes | depois (esquerda = antes, direita = depois) das capturas de tools/capture_t188.sh.
# Uso (raiz do projeto): bash tools/sheet_t188.sh [PASTA=docs/capturas_t188]   (usa PASTA/antes e PASTA/depois)
set -u
DIR="${1:-docs/capturas_t188}"
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
case "$DIR" in /*|[A-Za-z]:*) ;; *) DIR="$(pwd)/$DIR" ;; esac
sheet() {   # nome hora rota pose...
  local name="$1" t="$2" route="$3"
  shift 3
  local files=()
  for p in "$@"; do
    files+=("$DIR/antes/$t/${route}_$p.png" "$DIR/depois/$t/${route}_$p.png")
  done
  "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$DIR/$name.png" --cols=2 --w=640 \
      "${files[@]}" 2>&1 | grep -iE "erro|error" || true
  echo "$DIR/$name.png"
}
for T in day night; do
  sheet "folha_litoral_$T" "$T" kanto_1_coast jogo terra mar placa alto
  sheet "folha_cidade_$T" "$T" kanto_2_viaduct jogo predios predios_dir placa alto
  sheet "folha_montanha_$T" "$T" kanto_3_mountain jogo encosta encosta_dir placa alto
done
# resumo: a pose de jogo das 3 rotas, dia e noite
files=()
for T in day night; do
  for R in kanto_1_coast kanto_2_viaduct kanto_3_mountain; do
    files+=("$DIR/antes/$T/${R}_jogo.png" "$DIR/depois/$T/${R}_jogo.png")
  done
done
"$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$DIR/folha_resumo.png" --cols=2 --w=640 \
    "${files[@]}" 2>&1 | grep -iE "erro|error" || true
echo "$DIR/folha_resumo.png"
