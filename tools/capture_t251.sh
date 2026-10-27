#!/usr/bin/env bash
# Capturas da T-251 (cabine encostada na carroceria) e T-252 (foguete maior, andon e luzes da americana).
# Uso (raiz do projeto, Git Bash): bash tools/capture_t251.sh [cabines|t252|tudo] [PASTA_ABS]
#   "antes" sai de ANTES=<projeto Godot antes da T-251> (padrão ../t251_antes/game; monte com
#   `git archive 2a868b6 game tools | tar -x -C ../t251_antes` + cópia do .godot + --import). Um processo Godot por vez.
#   SKIP_ANTES=1 reaproveita os prints "antes" já gravados em $RAW (só refaz os "depois").
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
WHAT="${1:-tudo}"
OUT="${2:-$(pwd -W)/docs/capturas_t251}"
RAW="${RAW:-$(pwd -W)/builds/capturas_t251_raw}"
ANTES="${ANTES:-../t251_antes/game}"
mkdir -p "$RAW" "$OUT"
shot() { "$GODOT" --path "$1" --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$2" 2>&1 | grep -c "^SHOT" || true; }
sheet() { "$BLENDER" -b --factory-startup -P tools/sheet_grid.py -- "$@" 2>&1 | grep -E "FOLHA|Error" || true; }
CABS="flat_wide flat_quad chata jac curta americana"
OLD="base leve longo graneleira"
if [ "$WHAT" = cabines ] || [ "$WHAT" = tudo ]; then
  for when in antes depois; do
    B="$RAW/cabs_$when.txt"; : > "$B"
    for body in alubox tarp pinkbox tanker dump; do
      for cab in $CABS; do
        echo "--body=$body --cab=$cab --view=side --out=$RAW/${when}_${body}_${cab}_side.png" >> "$B"
        echo "--body=$body --cab=$cab --view=q34 --out=$RAW/${when}_${body}_${cab}_q34.png" >> "$B"
      done
    done
    for body in $OLD; do for cab in flat_wide flat_quad; do
      echo "--body=$body --cab=$cab --view=q34 --out=$RAW/${when}_${body}_${cab}_q34.png" >> "$B"
    done; done
    if [ "$when" = antes ]; then [ -n "${SKIP_ANTES:-}" ] || shot "$ANTES" "$B"; else shot game "$B"; fi
  done
  for body in alubox tarp pinkbox tanker dump; do
    L=()
    for v in side q34; do for when in antes depois; do for cab in $CABS; do L+=("$RAW/${when}_${body}_${cab}_$v.png"); done; done; done
    sheet "$OUT/cabines_${body}_antes_depois.png" 6 "${L[@]}"
  done
  L=()
  for when in antes depois; do for body in $OLD; do for cab in flat_wide flat_quad; do L+=("$RAW/${when}_${body}_${cab}_q34.png"); done; done; done
  sheet "$OUT/hayate_baus_antigos_antes_depois.png" 4 "${L[@]}"
fi
if [ "$WHAT" = t252 ] || [ "$WHAT" = tudo ]; then
  LOTS=("base chata rocket_round" "pinkbox flat_wide rocket_square" "alubox flat_wide rocket_twin" "leve chata rocket_led")
  for when in antes depois; do
    B="$RAW/t252_$when.txt"; : > "$B"
    for lot in "${LOTS[@]}"; do
      read -r body cab part <<< "$lot"
      for v in roof_corner back34; do
        echo "--body=$body --cab=$cab --parts=$part,boxlight_dash_top --view=$v --night --out=$RAW/rk_${when}_${body}_${v}.png" >> "$B"
      done
    done
    for bc in "base americana" "leve chata" "longo chata" "leve americana" "longo americana" "pinkbox americana"; do
      read -r body cab <<< "$bc"
      echo "--body=$body --cab=$cab --view=q34 --out=$RAW/fix_${when}_${body}_${cab}.png" >> "$B"
      echo "--body=$body --cab=$cab --view=front --night --out=$RAW/fix_${when}_${body}_${cab}_noite.png" >> "$B"
    done
    if [ "$when" = antes ]; then [ -n "${SKIP_ANTES:-}" ] || shot "$ANTES" "$B"; else shot game "$B"; fi
  done
  L=()
  for lot in "${LOTS[@]}"; do read -r body cab part <<< "$lot"
    L+=("$RAW/rk_antes_${body}_roof_corner.png" "$RAW/rk_depois_${body}_roof_corner.png" "$RAW/rk_antes_${body}_back34.png" "$RAW/rk_depois_${body}_back34.png"); done
  sheet "$OUT/foguetes_t252_antes_depois_noite.png" 4 "${L[@]}"
  L=()
  for bc in "base americana" "leve chata" "longo chata" "leve americana" "longo americana" "pinkbox americana"; do read -r body cab <<< "$bc"
    L+=("$RAW/fix_antes_${body}_${cab}.png" "$RAW/fix_depois_${body}_${cab}.png" "$RAW/fix_antes_${body}_${cab}_noite.png" "$RAW/fix_depois_${body}_${cab}_noite.png"); done
  sheet "$OUT/americana_e_andon_antes_depois.png" 4 "${L[@]}"
fi
