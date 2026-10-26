#!/usr/bin/env bash
# Capturas da T-232 (pinturas: mural dos 2 lados, traseira, teto) no jogo e folhas de contato.
# Uso (raiz do projeto, Git Bash):  bash tools/capture_t232.sh [PASTA_ABS]   (padrão: docs/capturas_t232)
# Um processo Godot por vez: primeiro os prints (janela, sem --headless), depois as folhas (headless).
# Os prints crus ficam em blender/renders/t232/shots (fora do Git; caminho sem espaços: o --batch separa por espaço).
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
OUT="${1:-$(pwd -W)/docs/capturas_t232}"
RAW="${RAW:-$(pwd -W)/blender/renders/t232/shots}"
mkdir -p "$RAW" "$OUT"
BATCH="$RAW/batch.txt"
: > "$BATCH"
MURALS="mural_ryu_kumo mural_ryu_nami mural_tora_take mural_tora_yuki mural_nami_fuji mural_kabuki mural_musha mural_bijin_ogi mural_bijin_tsuki mural_hoo mural_men mural_koi"
REARS="rearpaint_ryu rearpaint_tora rearpaint_hannya rearpaint_oni rearpaint_kitsune rearpaint_tengu rearpaint_noh rearpaint_kabuki rearpaint_bijin rearpaint_shishi rearpaint_hoo rearpaint_koi"
ROOFS="roofpaint_01 roofpaint_02 roofpaint_03 roofpaint_04 roofpaint_05 roofpaint_06 roofpaint_07 roofpaint_08 roofpaint_09"
for m in $MURALS; do
  echo "--body=base --cab=chata --parts=$m --view=side --out=$RAW/mural_${m}_dir.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$m --view=side_l --out=$RAW/mural_${m}_esq.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$m --view=side --night --out=$RAW/mural_${m}_noite.png" >> "$BATCH"
done
for r in $REARS; do
  echo "--body=base --cab=chata --parts=$r,rb_grand_panel --view=back --out=$RAW/tras_${r}_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$r,rb_grand_panel --view=back --night --out=$RAW/tras_${r}_noite.png" >> "$BATCH"
done
for r in $ROOFS; do
  echo "--body=base --cab=chata --parts=$r,rocket_led --view=roof_back --out=$RAW/teto_${r}_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$r,rocket_led --view=roof_back --night --out=$RAW/teto_${r}_noite.png" >> "$BATCH"
done
FULL="fb_gold_wing,visor_chrome_v,deck_led_box,skirt_light_bar,rb_grand_panel,rocket_frame,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top,mural_ryu_kumo,rearpaint_ryu,roofpaint_05"
for v in q34 side side_l back34 roof_back back; do
  echo "--body=base --cab=chata --parts=$FULL --view=$v --out=$RAW/completo_dia_$v.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$FULL --view=$v --night --out=$RAW/completo_noite_$v.png" >> "$BATCH"
done
LOTS=(
  "canter canter rb_round_twin,rocket_twin,mural_koi,rearpaint_koi,roofpaint_01"
  "leve jac rb_target,rocket_neon_dash,mural_tora_take,rearpaint_tora,roofpaint_02"
  "longo curta rb_torpedo,rocket_led,mural_musha,rearpaint_oni,roofpaint_09"
  "base americana rb_neon_rows,mural_hoo,rearpaint_hoo,roofpaint_06"
  "alubox x rb_double_deck,mural_men,rearpaint_hannya,roofpaint_04"
  "pinkbox x rb_bullet,mural_bijin_tsuki,rearpaint_bijin,roofpaint_07"
  "graneleira chata rb_neon_plate,mural_kabuki,rearpaint_kabuki,roofpaint_03"
)
for lot in "${LOTS[@]}"; do
  read -r body cab parts <<< "$lot"
  echo "--body=$body --cab=$cab --parts=$parts --view=q34_back --out=$RAW/bau_${body}_${cab}_dia.png" >> "$BATCH"
  echo "--body=$body --cab=$cab --parts=$parts --view=q34_back --night --out=$RAW/bau_${body}_${cab}_noite.png" >> "$BATCH"
done
"$GODOT" --path game --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$BATCH" 2>&1 | grep -c "^SHOT" || true

sheet() {   # sheet SAIDA COLS LARGURA arquivos...
  local out="$1" cols="$2" w="$3"
  shift 3
  "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$OUT/$out" --cols="$cols" --w="$w" "$@" 2>&1 \
    | grep -E "ERROR" || true
}
set -- $MURALS
for part in 1 2 3; do
  files=()
  for k in 1 2 3 4; do
    m="$1"; shift
    files+=("$RAW/mural_${m}_dir.png" "$RAW/mural_${m}_esq.png")
  done
  sheet "murais_${part}_dois_lados_dia.png" 2 640 "${files[@]}"
done
files=(); for m in $MURALS; do files+=("$RAW/mural_${m}_noite.png"); done
sheet "murais_noite.png" 3 480 "${files[@]}"
for t in dia noite; do
  files=(); for r in $REARS; do files+=("$RAW/tras_${r}_$t.png"); done
  sheet "traseiras_$t.png" 4 400 "${files[@]}"
  files=(); for r in $ROOFS; do files+=("$RAW/teto_${r}_$t.png"); done
  sheet "tetos_$t.png" 3 480 "${files[@]}"
  files=(); for v in q34 side side_l back34 roof_back back; do files+=("$RAW/completo_${t}_$v.png"); done
  sheet "dekotora_completo_$t.png" 2 640 "${files[@]}"
  files=(); for lot in "${LOTS[@]}"; do read -r body cab parts <<< "$lot"; files+=("$RAW/bau_${body}_${cab}_$t.png"); done
  sheet "todos_os_baus_$t.png" 3 480 "${files[@]}"
done
ls "$OUT"
