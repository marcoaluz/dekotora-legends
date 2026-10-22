#!/usr/bin/env bash
# T-192: folhas antes | depois (esquerda = antes, direita = depois) das capturas de tools/capture_t192.sh.
# Uso (raiz do projeto): bash tools/sheet_t192.sh [PASTA=docs/capturas_t192]   (usa PASTA/antes e PASTA/depois)
set -u
DIR="${1:-docs/capturas_t192}"
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
  sheet "folha_litoral_$T" "$T" kanto_1_coast inicio emenda terra mar terra_fim ponte alto fim
  sheet "folha_cidade_$T" "$T" kanto_2_viaduct inicio pintura predios_ini tunel alto predios_fim viaduto_velho fim
  sheet "folha_montanha_$T" "$T" kanto_3_mountain inicio pintura encosta_ini tunel1 tunel2 encosta_fim alto fim
done
# resumo: um ponto FORA do antigo trecho-piloto de cada rota, dia e noite
files=()
for T in day night; do
  for R in kanto_1_coast:emenda kanto_2_viaduct:predios_fim kanto_3_mountain:encosta_ini; do
    files+=("$DIR/antes/$T/${R%%:*}_${R#*:}.png" "$DIR/depois/$T/${R%%:*}_${R#*:}.png")
  done
done
"$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$DIR/folha_resumo.png" --cols=2 --w=640 \
    "${files[@]}" 2>&1 | grep -iE "erro|error" || true
echo "$DIR/folha_resumo.png"
