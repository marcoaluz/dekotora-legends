#!/usr/bin/env bash
# Capturas da T-231 (oficina lote 2: traseira, foguete, contorno do baú) e folhas de contato.
# Uso (raiz do projeto, Git Bash):  bash tools/capture_t231.sh [PASTA_ABS]   (padrão: docs/capturas_t231)
# Um processo Godot por vez (janela, sem --headless) e depois um Blender para montar as folhas.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
OUT="${1:-$(pwd -W)/docs/capturas_t231}"   # (caminho do Windows: o Godot não entende /d/...)
RAW="${RAW:-$(pwd -W)/builds/capturas_t231_raw}"   # (fora do Git; só as folhas vão para docs/)
mkdir -p "$RAW" "$OUT"
BATCH="$RAW/batch.txt"
: > "$BATCH"
LOTS=(
  "base chata rb_grand_panel,rocket_frame,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top"
  "canter canter rb_round_twin,rocket_twin,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top"
  "longo curta rb_torpedo,rocket_led,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top"
  "leve jac rb_target,rocket_neon_dash,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top"
  "base americana rb_neon_rows,rocket_flat_neon,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top"
  "pinkbox x rb_bullet,rocket_round,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top"
  "alubox x rb_double_deck,rocket_square,boxlight_dash_r,boxlight_dash_l,boxlight_dash_top"
  "graneleira chata rb_neon_plate,rocket_round,boxlight_dash_r"
  "tanker x rb_square_grid"
)
VIEWS="front side back q34 back34 roof_back"
for lot in "${LOTS[@]}"; do
  read -r body cab parts <<< "$lot"
  tag="${body}_${cab}"
  for v in $VIEWS; do
    echo "--body=$body --cab=$cab --parts=$parts --view=$v --out=$RAW/${tag}_dia_$v.png" >> "$BATCH"
    echo "--body=$body --cab=$cab --parts=$parts --view=$v --night --out=$RAW/${tag}_noite_$v.png" >> "$BATCH"
  done
done
for p in rb_square_row rb_round_twin rb_square_grid rb_round_grid rb_target rb_double_deck rb_neon_rows rb_neon_plate rb_bullet rb_torpedo rb_grand_panel; do
  echo "--body=base --cab=chata --parts=$p --view=rear_low --out=$RAW/traseira_${p}_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$p --view=rear_low --night --out=$RAW/traseira_${p}_noite.png" >> "$BATCH"
done
for p in rocket_round rocket_square rocket_twin rocket_led rocket_flat_neon rocket_neon_dash rocket_frame; do
  echo "--body=base --cab=chata --parts=$p,boxlight_dash_top --view=roof_corner --out=$RAW/foguete_${p}_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$p,boxlight_dash_top --view=roof_corner --night --out=$RAW/foguete_${p}_noite.png" >> "$BATCH"
done
echo "--body=base --cab=chata --parts=rb_target,rocket_round,boxlight_dash_r --state=rb_target:broken --state=rocket_round:broken --state=boxlight_dash_r:broken --view=back34 --night --out=$RAW/dano_quebrada_noite.png" >> "$BATCH"
echo "--body=base --cab=chata --parts=rb_target,rocket_round,boxlight_dash_r --view=back34 --night --out=$RAW/dano_inteira_noite.png" >> "$BATCH"
"$GODOT" --path game --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$BATCH" 2>&1 | grep -c "^SHOT" || true
"$BLENDER" -b --factory-startup -P tools/sheet_t231.py -- "$RAW" "$OUT" 2>&1 | grep -E "FOLHA|Error" || true
