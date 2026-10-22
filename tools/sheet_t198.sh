#!/usr/bin/env bash
# T-198: folha de contato das cameras (esquerda = dia, direita = noite), a partir de tools/capture_t198.sh.
# Uso (raiz do projeto): bash tools/sheet_t198.sh [PASTA=docs/capturas_t198] [QUADRO=t03]
#   Usa PASTA/raw/<camera>_<hora>/<QUADRO>_1.png; CAMS="near standard" troca a lista; grava PASTA/folha_cameras.png.
set -u
DIR="${1:-docs/capturas_t198}"
F="${2:-t03}"
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
case "$DIR" in /*|[A-Za-z]:*) ;; *) DIR="$(pwd)/$DIR" ;; esac
files=()
for C in ${CAMS:-near standard far cinema orbit}; do
  files+=("$DIR/raw/${C}_day/${F}_1.png" "$DIR/raw/${C}_night/${F}_1.png")
done
"$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$DIR/${OUT_NAME:-folha_cameras}.png" \
    --cols=2 --w=640 "${files[@]}" 2>&1 | grep -iE "erro|error" || true
echo "$DIR/${OUT_NAME:-folha_cameras}.png"
