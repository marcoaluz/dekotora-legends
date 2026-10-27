#!/usr/bin/env bash
# Capturas da T-239 (luzes: freio deixa tudo vermelho, seta em cima da lampada, porta do bau sem luzes).
# Uso (raiz do projeto, Git Bash):  bash tools/capture_t239.sh FASE [PASTA_ABS]
#   FASE = antes | depois (so muda o nome dos arquivos). Padrao da pasta: docs/capturas_t239
# Grava um print por estado (normal, freando, seta esquerda, seta direita) x vista (traseira/frente, sem e com
# para-choque novo) x hora (dia/noite) x caminhao, e monta uma folha por caminhao e hora (Godot, sem Pillow).
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
FASE="${1:-depois}"
OUT="${2:-$(pwd -W)/docs/capturas_t239}"   # (caminho do Windows: o Godot nao entende /d/...)
RAW="${RAW:-$(pwd -W)/builds/capturas_t239_raw/$FASE}"
mkdir -p "$RAW" "$OUT"
BATCH="$RAW/batch.txt"
: > "$BATCH"
TRUCKS=(
  "base chata rb_grand_panel fb_fan_amber"
  "canter canter rb_torpedo fb_box_amber"
  "pinkbox x rb_bullet fb_deck_neon"
  "leve jac rb_square_row fb_fan_gold"
)
STATES=("normal:" "freio:--brake" "seta_esq:--signal=-1" "seta_dir:--signal=1")
for tr in "${TRUCKS[@]}"; do
  read -r body cab rb fb <<< "$tr"
  tag="${body}_${cab}"
  for tod in dia noite; do
    night=""; [ "$tod" = noite ] && night="--night"
    for row in "back:" "back:$rb" "front:" "front:$fb"; do
      view="${row%%:*}"; parts="${row#*:}"
      pt="sem"; [ -n "$parts" ] && pt="com"
      for st in "${STATES[@]}"; do
        sname="${st%%:*}"; sflag="${st#*:}"
        echo "--body=$body --cab=$cab --parts=$parts --view=$view $night $sflag --out=$RAW/${tag}_${tod}_${view}_${pt}_${sname}.png" >> "$BATCH"
      done
    done
  done
done
"$GODOT" --path game --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$BATCH" 2>&1 | grep "^SHOT" > "$RAW/shots.txt" || true
wc -l < "$RAW/shots.txt"
for tr in "${TRUCKS[@]}"; do
  read -r body cab rb fb <<< "$tr"
  tag="${body}_${cab}"
  for tod in dia noite; do
    files=()
    for row in back_sem back_com front_sem front_com; do
      for s in normal freio seta_esq seta_dir; do
        files+=("$RAW/${tag}_${tod}_${row}_${s}.png")
      done
    done
    "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$OUT/${FASE}_${tag}_${tod}.png" \
      --cols=4 --w=480 "${files[@]}" 2>&1 | grep -iE "error|folha|sheet" || true
  done
done
