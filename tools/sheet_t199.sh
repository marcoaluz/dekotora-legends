#!/usr/bin/env bash
# T-199: folhas antes | depois (2 colunas: esquerda antes, direita depois), uma por rota e hora, em docs/capturas_t199/.
# Uso (raiz do projeto, Git Bash): bash tools/sheet_t199.sh [PASTA=docs/capturas_t199]
#   GRID=ROTA/HORA bash tools/sheet_t199.sh  -> so uma grade 3 colunas das poses de PASTA/<lado>/HORA/ROTA_* (rapida, revisao).
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
DIR="${1:-docs/capturas_t199}"
case "$DIR" in /*|?:*) ;; *) DIR="$(pwd)/$DIR" ;; esac
m() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
if [ -n "${GRID:-}" ]; then
  SIDE="${SIDE:-depois}"; R="${GRID%%/*}"; T="${GRID#*/}"
  FILES=(); for f in "$DIR/$SIDE/$T/${R}"_*.png; do FILES+=("$(m "$f")"); done
  "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$(m "$DIR")/_grid.png" --cols=3 --w=600 \
      "${FILES[@]}" 2>&1 | grep -E "OK folha|ERROR"
  exit 0
fi
for T in day night; do
  for R in kanto_1_coast kanto_2_viaduct kanto_3_mountain; do
    FILES=()
    for f in "$DIR/depois/$T/${R}"_*.png; do
      b="$DIR/antes/$T/$(basename "$f")"
      [ -f "$b" ] && FILES+=("$(m "$b")" "$(m "$f")")
    done
    [ ${#FILES[@]} -eq 0 ] && continue
    "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$(m "$DIR")/folha_${R}_${T}.png" \
        --cols=2 --w=640 "${FILES[@]}" 2>&1 | grep -E "OK folha|ERROR"
  done
done
