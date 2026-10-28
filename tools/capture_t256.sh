#!/usr/bin/env bash
# Capturas da T-256 (refino do lote 5: grade inclinada com colar e contorno de LED, arte na lata da cabine, cornetas
# à esquerda / à direita / dos dois lados). Uso (raiz do projeto, Git Bash): bash tools/capture_t256.sh [PASTA_ABS]
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
OUT="${1:-$(pwd -W)/docs/capturas_t256}"
RAW="${RAW:-$(pwd -W)/builds/capturas_t256_raw}"
mkdir -p "$RAW" "$OUT"
B="$RAW/batch.txt"
: > "$B"
for cab in chata jac curta flat_wide canter americana; do
  body=base; [ "$cab" = canter ] && body=canter
  for v in front_close grille_side; do
    echo "--body=$body --cab=$cab --parts=grille_honey_sun --view=$v --night --out=$RAW/grade_${cab}_${v}.png" >> "$B"
  done
  for a in 12 13 14; do
    echo "--body=$body --cab=$cab --parts=grille_bars_led --art=grille_bars_led:$a --view=front_close --out=$RAW/arte_${cab}_${a}_dia.png" >> "$B"
  done
  echo "--body=$body --cab=$cab --parts=grille_slats_neon --art=grille_slats_neon:13 --view=front_close --night --out=$RAW/arte_${cab}_13_noite.png" >> "$B"
  for s in both left right; do
    echo "--body=$body --cab=$cab --parts=horn_triple,visor_v_chevron --side=horn_triple:$s --view=visor_close --out=$RAW/buzina_${cab}_${s}.png" >> "$B"
  done
done
for s in both left right; do
  echo "--body=base --cab=chata --parts=horn_ship,deck_led_box --side=horn_ship:$s --view=cab34 --night --out=$RAW/buzina_deque_${s}.png" >> "$B"
done
"$GODOT" --path game --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$B" 2>&1 | grep "^SHOT" > "$RAW/shots.txt" || true
wc -l < "$RAW/shots.txt"
S="$GODOT --headless --path game -s res://tools_dev/make_compare_sheet.gd --"
F=()
for cab in chata jac curta flat_wide canter americana; do F+=("$RAW/grade_${cab}_front_close.png" "$RAW/grade_${cab}_grille_side.png"); done
$S --out="$OUT/grade_encaixe.png" --cols=4 --w=480 "${F[@]}" | tail -1
F=()
for cab in chata jac curta flat_wide canter americana; do F+=("$RAW/arte_${cab}_12_dia.png" "$RAW/arte_${cab}_13_dia.png" "$RAW/arte_${cab}_14_dia.png" "$RAW/arte_${cab}_13_noite.png"); done
$S --out="$OUT/grade_arte_na_lata.png" --cols=4 --w=480 "${F[@]}" | tail -1
F=()
for cab in chata jac curta flat_wide canter americana; do F+=("$RAW/buzina_${cab}_both.png" "$RAW/buzina_${cab}_left.png" "$RAW/buzina_${cab}_right.png"); done
$S --out="$OUT/buzina_disposicao.png" --cols=3 --w=480 "${F[@]}" | tail -1
$S --out="$OUT/buzina_com_deque.png" --cols=3 --w=480 "$RAW/buzina_deque_both.png" "$RAW/buzina_deque_left.png" "$RAW/buzina_deque_right.png" | tail -1
