#!/usr/bin/env bash
# Capturas da T-240 (cabine trocável e foguete maior) e folhas de contato.
# Uso (raiz do projeto, Git Bash):  bash tools/capture_t240.sh [cabines|foguetes|garagem|tudo] [PASTA_ABS]
#   foguetes: "antes" sai de ANTES=<pasta do projeto Godot antes da T-240> (padrão ../t240_antes/game; monte com
#   `git archive <commit> game tools | tar -x -C ../t240_antes` e um --import). Um processo Godot por vez.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
WHAT="${1:-tudo}"
OUT="${2:-$(pwd -W)/docs/capturas_t240}"
RAW="${RAW:-$(pwd -W)/builds/capturas_t240_raw}"
ANTES="${ANTES:-../t240_antes/game}"
mkdir -p "$RAW" "$OUT"
shot() {  # $1 = pasta do projeto, $2 = batch
  "$GODOT" --path "$1" --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$2" 2>&1 | grep -c "^SHOT" || true
}
sheet() { "$BLENDER" -b --factory-startup -P tools/sheet_grid.py -- "$@" 2>&1 | grep -E "FOLHA|Error" || true; }
CABS="flat_wide flat_quad chata jac curta americana"
if [ "$WHAT" = cabines ] || [ "$WHAT" = tudo ]; then
  B="$RAW/cabs.txt"; : > "$B"
  for body in alubox tarp pinkbox tanker dump; do
    for cab in $CABS; do
      echo "--body=$body --cab=$cab --view=q34 --out=$RAW/cab_${body}_${cab}_q34.png" >> "$B"
      echo "--body=$body --cab=$cab --view=side --out=$RAW/cab_${body}_${cab}_side.png" >> "$B"
    done
  done
  for body in base leve longo graneleira; do
    for cab in flat_wide flat_quad; do
      echo "--body=$body --cab=$cab --view=q34 --out=$RAW/cab_${body}_${cab}_q34.png" >> "$B"
    done
  done
  for cab in chata jac americana; do
    echo "--body=pinkbox --cab=$cab --view=q34 --night --out=$RAW/cab_pinkbox_${cab}_noite.png" >> "$B"
    echo "--body=tanker --cab=$cab --view=front --night --signal=2 --out=$RAW/cab_tanker_${cab}_frente_noite.png" >> "$B"
  done
  shot game "$B"
  for body in alubox tarp pinkbox tanker dump; do
    L=(); S=()
    for cab in $CABS; do L+=("$RAW/cab_${body}_${cab}_q34.png"); S+=("$RAW/cab_${body}_${cab}_side.png"); done
    sheet "$OUT/cabines_${body}.png" 3 "${L[@]}" "${S[@]}"
  done
  L=()
  for body in base leve longo graneleira; do for cab in flat_wide flat_quad; do L+=("$RAW/cab_${body}_${cab}_q34.png"); done; done
  sheet "$OUT/cabines_novas_nos_baus_antigos.png" 4 "${L[@]}"
  sheet "$OUT/cabines_noite.png" 3 "$RAW"/cab_pinkbox_{chata,jac,americana}_noite.png "$RAW"/cab_tanker_{chata,jac,americana}_frente_noite.png
fi
if [ "$WHAT" = foguetes ] || [ "$WHAT" = tudo ]; then
  LOTS=("base chata rocket_round" "pinkbox flat_wide rocket_square" "alubox flat_wide rocket_twin" "leve chata rocket_led")
  for when in antes depois; do
    B="$RAW/rockets_$when.txt"; : > "$B"
    for lot in "${LOTS[@]}"; do
      read -r body cab part <<< "$lot"
      c="$cab"; [ "$when" = antes ] && [ "$body" != base ] && [ "$body" != leve ] && c=x   # antes: cabine fixa
      for v in roof_corner back34; do
        echo "--body=$body --cab=$c --parts=$part,boxlight_dash_top --view=$v --out=$RAW/rk_${when}_${body}_${v}_dia.png" >> "$B"
        echo "--body=$body --cab=$c --parts=$part,boxlight_dash_top --view=$v --night --out=$RAW/rk_${when}_${body}_${v}_noite.png" >> "$B"
      done
    done
    if [ "$when" = antes ]; then shot "$ANTES" "$B"; else shot game "$B"; fi
  done
  for t in dia noite; do
    L=()
    for lot in "${LOTS[@]}"; do
      read -r body cab part <<< "$lot"
      L+=("$RAW/rk_antes_${body}_roof_corner_$t.png" "$RAW/rk_depois_${body}_roof_corner_$t.png"
          "$RAW/rk_antes_${body}_back34_$t.png" "$RAW/rk_depois_${body}_back34_$t.png")
    done
    sheet "$OUT/foguetes_antes_depois_$t.png" 4 "${L[@]}"
  done
fi
if [ "$WHAT" = garagem ] || [ "$WHAT" = tudo ]; then
  for cab in flat_wide americana; do
    timeout 120 "$GODOT" --path game --resolution 1280x720 res://scenes/garage/garage.tscn -- --demo --noparts \
      --body=pinkbox --cab=$cab --tab=model --shot="$RAW/garagem_pinkbox_$cab.png" 2>&1 | grep -E "SHOT|ERROR" | head -3 || true
  done
  sheet "$OUT/garagem_escolha_da_cabine.png" 1 "$RAW/garagem_pinkbox_flat_wide.png" "$RAW/garagem_pinkbox_americana.png"
fi
