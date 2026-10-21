#!/usr/bin/env bash
# T-179: folhas antes | depois (esquerda = antes, direita = depois) a partir de duas rodadas de tools/capture_t179.sh.
# Uso (raiz do projeto): bash tools/sheet_t179.sh PASTA_ANTES PASTA_DEPOIS [SAIDA=docs/capturas_t179]
set -u
A="${1:?pasta antes}"
B="${2:?pasta depois}"
OUT="${3:-docs/capturas_t179}"
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
case "$OUT" in /*|[A-Za-z]:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
mkdir -p "$OUT"
sheet() {   # nome cena/quadro...
  local name="$1"
  shift
  local files=()
  for f in "$@"; do
    files+=("$A/$f.png" "$B/$f.png")
  done
  "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$OUT/$name.png" --cols=2 --w=640 \
      "${files[@]}" 2>&1 | grep -iE "folha|erro|error" || true
  echo "$OUT/$name.png"
}
sheet folha_montanha_dia montanha_dia/largada_1 montanha_dia/t02_1 montanha_dia_viaduto/t02_1
sheet folha_litoral_tarde litoral_tarde/t01_1 litoral_tarde/t02_1 litoral_tarde_fim/largada_1
sheet folha_cidade_noite rapida_cidade_noite/t01_1 rapida_cidade_noite/t02_1 viaduto_noite/t01_1
