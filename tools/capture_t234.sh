#!/usr/bin/env bash
# Capturas da T-234 (oficina lote 5: calotas, escapamentos, grades, buzinas, interior e adesivos) e folhas de contato.
# Uso (raiz do projeto, Git Bash):  bash tools/capture_t234.sh [PASTA_ABS]   (padrão: docs/capturas_t234)
# Um processo Godot por vez (janela, sem --headless) e depois um Blender para montar as folhas.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
OUT="${1:-$(pwd -W)/docs/capturas_t234}"   # (caminho do Windows: o Godot não entende /d/...)
RAW="${RAW:-$(pwd -W)/builds/capturas_t234_raw}"   # (fora do Git; só as folhas vão para docs/)
mkdir -p "$RAW" "$OUT"
BATCH="$RAW/batch.txt"
: > "$BATCH"
OLD="deck_led_box,visor_v_chevron,fb_fan_amber,mirror_stay_frame,rb_grand_panel,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top,mural_ryu_kumo"
LOTS=(
  "base chata hub_led_ring,stack_neon_twin,grille_honey_sun,horn_triple,interior_chandelier,$OLD"
  "base jac hub_star_gold,stack_j_amber,grille_bars_led,horn_ship,interior_curtain,$OLD"
  "base curta hub_neon_spinner,stack_side_triple,grille_slats_neon,horn_twin_long,interior_tufted,$OLD"
  "base americana hub_led_ring,stack_j_amber,grille_honey_sun,horn_ship,interior_curtain,$OLD"
  "base flat_wide hub_star_gold,stack_neon_twin,grille_slats_neon,horn_triple,interior_chandelier,$OLD"
  "canter canter hub_neon_spinner,stack_neon_twin,grille_bars_led,horn_twin_long,interior_tufted,$OLD"
  "alubox x hub_led_ring,stack_neon_twin,grille_honey_sun,horn_ship,interior_chandelier,$OLD"
  "tanker x hub_star_gold,stack_j_amber,grille_bars_led,horn_triple,interior_curtain,deck_led_box,visor_v_chevron"
)
VIEWS="front34 front_close wheel_close stack34 horn_back side"
for lot in "${LOTS[@]}"; do
  read -r body cab parts <<< "$lot"
  tag="${body}_${cab}"
  for v in $VIEWS; do
    echo "--body=$body --cab=$cab --parts=$parts --view=$v --out=$RAW/${tag}_dia_$v.png" >> "$BATCH"
    echo "--body=$body --cab=$cab --parts=$parts --view=$v --night --out=$RAW/${tag}_noite_$v.png" >> "$BATCH"
  done
done
one() {  # tipo peca vista [cabine]
  echo "--body=base --cab=${4:-chata} --parts=$2 --view=$3 --out=$RAW/${1}_${2}_dia.png" >> "$BATCH"
  echo "--body=base --cab=${4:-chata} --parts=$2 --view=$3 --night --out=$RAW/${1}_${2}_noite.png" >> "$BATCH"
}
for p in hub_led_ring hub_star_gold hub_neon_spinner; do one roda $p wheel_close; done
for p in stack_neon_twin stack_j_amber stack_side_triple; do one escape $p stack34; done
for p in grille_bars_led grille_honey_sun grille_slats_neon; do one grade $p front_close; done
for p in horn_triple horn_twin_long horn_ship; do one buzina $p horn_back; done
for p in interior_curtain interior_chandelier interior_tufted; do one interior $p front_close; done
# a mesma grade em todas as cabines (estica na largura/altura de cada uma; o sol continua redondo)
for m in "base chata" "base jac" "base curta" "base americana" "base flat_wide" "canter canter"; do
  read -r body cab <<< "$m"
  echo "--body=$body --cab=$cab --parts=grille_honey_sun,interior_chandelier --view=front_close --night --out=$RAW/cabines_${body}_${cab}.png" >> "$BATCH"
done
# adesivos: frases nos lados e na traseira, labaredas e sol (cores diferentes)
echo "--body=base --cab=chata --parts=deck_led_box --decal=decal_frase_08:side_l:ffffff:0.5 --decal=decal_labaredas:cab:ff2e88:0.4 --view=decal_side --out=$RAW/adesivos_lado_dia.png" >> "$BATCH"
echo "--body=base --cab=chata --parts=deck_led_box --decal=decal_frase_04:side_l:f5cc5a:0.45 --decal=decal_sol_nascente:cab:21e6ff:0.5 --view=decal_side --night --out=$RAW/adesivos_lado_noite.png" >> "$BATCH"
echo "--body=base --cab=chata --parts=rb_grand_panel --decal=decal_frase_01:rear:ffffff:0.35 --view=back --out=$RAW/adesivos_tras_dia.png" >> "$BATCH"
D="hub_neon_spinner,stack_j_amber,grille_bars_led,horn_ship"
echo "--body=base --cab=chata --parts=$D --state=stack_j_amber:broken --state=grille_bars_led:broken --state=horn_ship:broken --view=front34 --night --out=$RAW/dano_quebrada_noite.png" >> "$BATCH"
echo "--body=base --cab=chata --parts=$D --view=front34 --night --out=$RAW/dano_inteira_noite.png" >> "$BATCH"
"$GODOT" --path game --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$BATCH" 2>&1 | grep "^SHOT" > "$RAW/shots.txt" || true
wc -l < "$RAW/shots.txt"
"$BLENDER" -b --factory-startup -P tools/sheet_t234.py -- "$RAW" "$OUT" 2>&1 | grep -E "FOLHA|Error" || true
