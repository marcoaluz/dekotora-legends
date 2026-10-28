#!/usr/bin/env bash
# Capturas da T-259 (adesivo na lataria da frente, refeito pela referência do Marco; grade só grade). Folha de
# comparação referência x resultado em 6 cabines. Uso (raiz do projeto, Git Bash): bash tools/capture_t259.sh [PASTA_ABS]
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
OUT="${1:-$(pwd -W)/docs/capturas_t259}"
RAW="${RAW:-$(pwd -W)/builds/capturas_t259_raw}"
REF="$(pwd -W)/docs/Referencias/grade_t234"
mkdir -p "$RAW" "$OUT"
B="$RAW/batch.txt"
: > "$B"
# cabine, grade, arte, referência parecida (imagens 1-8 da referência)
SET=("chata grille_bars_led 12 1" "jac grille_honey_sun 13 2" "curta grille_slats_neon 14 4" "flat_wide grille_bars_led 13 3"
     "canter grille_honey_sun 15 8" "americana grille_slats_neon 12 7")
for s in "${SET[@]}"; do
  read -r cab g a r <<< "$s"
  body=base; [ "$cab" = canter ] && body=canter
  P="$g,deck_led_box,visor_v_chevron,fb_fan_amber"
  echo "--body=$body --cab=$cab --parts=$P --art=$g:$a --view=ref34 --out=$RAW/${cab}_dia.png" >> "$B"
  echo "--body=$body --cab=$cab --parts=$P --art=$g:$a --view=ref34 --night --out=$RAW/${cab}_noite.png" >> "$B"
  echo "--body=$body --cab=$cab --parts=$g --view=front_close --out=$RAW/${cab}_grade_so.png" >> "$B"
done
"$GODOT" --path game --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$B" 2>&1 | grep "^SHOT" > "$RAW/shots.txt" || true
wc -l < "$RAW/shots.txt"
F=()
for s in "${SET[@]}"; do
  read -r cab g a r <<< "$s"
  F+=("$REF/grade_ref_$r.png" "$RAW/${cab}_dia.png" "$RAW/${cab}_noite.png" "$RAW/${cab}_grade_so.png")
done
"$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$OUT/referencia_x_resultado.png" --cols=4 --w=480 "${F[@]}" | tail -1
