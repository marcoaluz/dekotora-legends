#!/usr/bin/env bash
# Capturas da T-233 (oficina lote 4: para-choque da frente, retrovisor, escada e saias) e folhas de contato.
# Uso (raiz do projeto, Git Bash):  bash tools/capture_t233.sh [PASTA_ABS]   (padrão: docs/capturas_t233)
# Um processo Godot por vez (janela, sem --headless) e depois um Blender para montar as folhas.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
OUT="${1:-$(pwd -W)/docs/capturas_t233}"   # (caminho do Windows: o Godot não entende /d/...)
RAW="${RAW:-$(pwd -W)/builds/capturas_t233_raw}"   # (fora do Git; só as folhas vão para docs/)
mkdir -p "$RAW" "$OUT"
BATCH="$RAW/batch.txt"
: > "$BATCH"
OLD="deck_led_box,visor_v_chevron,rb_grand_panel,rocket_frame,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top,mural_ryu_kumo,rearpaint_ryu,roofpaint_05"
OLD_OPEN="deck_pods_round,visor_v_step,rb_neon_rows"
LOTS=(
  "base chata fb_deck_neon,mirror_stay_grand,ladder_neon,skirt_neon_arrows,$OLD"
  "base jac fb_fan_gold,mirror_stay_truss,ladder_green,skirt_neon_gems,$OLD"
  "base curta fb_box_steps,mirror_stay_frame,ladder_chrome,skirt_chrome_rails,$OLD"
  "base americana fb_smooth_chrome,mirror_stay_box,ladder_neon,skirt_neon_twin,$OLD"
  "canter canter fb_fan_amber,mirror_stay_chain,ladder_green,skirt_neon_dash,$OLD"
  "pinkbox x fb_box_amber,mirror_stay_l,ladder_chrome,skirt_neon_arch,rb_bullet,rocket_round,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top"
  "alubox x fb_deck_checker,mirror_stay_grand,ladder_neon,skirt_neon_green,$OLD"
  "graneleira chata fb_fan_stripe,mirror_stay_frame,skirt_neon_diamond,$OLD_OPEN"
  "tanker x fb_fan_red,mirror_stay_truss,skirt_neon_twin,$OLD_OPEN"
)
VIEWS="front34 front_low cab34 ladder34 skirt34 side"
for lot in "${LOTS[@]}"; do
  read -r body cab parts <<< "$lot"
  tag="${body}_${cab}"
  for v in $VIEWS; do
    echo "--body=$body --cab=$cab --parts=$parts --view=$v --out=$RAW/${tag}_dia_$v.png" >> "$BATCH"
    echo "--body=$body --cab=$cab --parts=$parts --view=$v --night --out=$RAW/${tag}_noite_$v.png" >> "$BATCH"
  done
done
for p in fb_fan_plate fb_fan_amber fb_fan_red fb_fan_gold fb_fan_stripe fb_fan_chrome fb_box_amber fb_box_steps fb_smooth_chrome fb_deck_checker fb_deck_neon; do
  echo "--body=base --cab=chata --parts=$p --view=front34 --out=$RAW/parachoque_${p}_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$p --view=front34 --night --out=$RAW/parachoque_${p}_noite.png" >> "$BATCH"
done
for p in mirror_stay_l mirror_stay_truss mirror_stay_frame mirror_stay_box mirror_stay_chain mirror_stay_grand; do
  echo "--body=base --cab=chata --parts=$p --view=cab34 --out=$RAW/retrovisor_${p}_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$p --view=cab34 --night --out=$RAW/retrovisor_${p}_noite.png" >> "$BATCH"
done
for p in ladder_neon ladder_green ladder_chrome; do
  echo "--body=base --cab=chata --parts=$p --view=ladder34 --out=$RAW/escada_${p}_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$p --view=ladder34 --night --out=$RAW/escada_${p}_noite.png" >> "$BATCH"
done
for p in skirt_chrome_rails skirt_neon_twin skirt_neon_diamond skirt_neon_dash skirt_neon_arch skirt_neon_green skirt_neon_gems skirt_neon_arrows; do
  echo "--body=base --cab=chata --parts=$p --view=skirt34 --out=$RAW/saia_${p}_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$p --view=skirt34 --night --out=$RAW/saia_${p}_noite.png" >> "$BATCH"
done
# a mesma peça nas cabines de farol alto e baixo (altura do para-choque e do retrovisor se ajusta)
for m in "base chata" "base jac" "base curta" "base americana" "canter canter" "alubox x"; do
  read -r body cab <<< "$m"
  echo "--body=$body --cab=$cab --parts=fb_box_amber,mirror_stay_frame --view=front34 --night --out=$RAW/cabines_${body}_${cab}.png" >> "$BATCH"
done
D="fb_fan_amber,mirror_stay_truss,ladder_green,skirt_neon_gems"
echo "--body=base --cab=chata --parts=$D --state=fb_fan_amber:broken --state=mirror_stay_truss:broken --state=ladder_green:broken --state=skirt_neon_gems:broken --view=front34 --night --out=$RAW/dano_quebrada_noite.png" >> "$BATCH"
echo "--body=base --cab=chata --parts=$D --view=front34 --night --out=$RAW/dano_inteira_noite.png" >> "$BATCH"
"$GODOT" --path game --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$BATCH" 2>&1 | grep "^SHOT" > "$RAW/shots.txt" || true
wc -l < "$RAW/shots.txt"
"$BLENDER" -b --factory-startup -P tools/sheet_t233.py -- "$RAW" "$OUT" 2>&1 | grep -E "FOLHA|Error" || true
