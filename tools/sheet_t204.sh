#!/usr/bin/env bash
# T-204: folhas e prints reduzidos da abertura nova do duelo a partir das capturas de tools/capture_t204.sh.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/sheet_t204.sh PASTA_DAS_CAPTURAS [SAIDA=docs/capturas_t204]
# Grava em SAIDA: etapas/<instante>.png (PC media, 960 px), folha_<caso>.png (10 instantes: 0,5 a 7,5 s),
# folha_reduzido.png (raio normal x "reduzir claroes") e folha_arte.png (Raijin, Fujin, titulo).
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
IN="${1:?pasta das capturas}"
OUT="${2:-docs/capturas_t204}"
case "$IN" in /*|?:*) ;; *) IN="$(pwd)/$IN" ;; esac
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
mkdir -p "$OUT/etapas"
sheet() { "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- "$@" 2>&1 | grep -E "OK folha|ERROR" ; }
for f in "$IN"/pc_media/abertura_*_1.png; do
  [ -f "$f" ] || continue
  n="$(basename "$f" _1.png)"
  sheet --out="$OUT/etapas/$n.png" --cols=1 --w=960 "$f"
done
for C in pc_media pc_ultra cel dia; do
  [ -d "$IN/$C" ] || continue
  # shellcheck disable=SC2046
  sheet --out="$OUT/folha_$C.png" --cols=4 --w=480 $(ls "$IN/$C"/abertura_*_1.png)
done
if [ -d "$IN/reduzido" ]; then
  sheet --out="$OUT/folha_reduzido.png" --cols=2 --w=640 \
      "$IN/pc_media/abertura_03.80s_1.png" "$IN/reduzido/abertura_03.80s_1.png" \
      "$IN/pc_media/abertura_04.05s_1.png" "$IN/reduzido/abertura_04.05s_1.png"
fi
A="$(pwd)/game/assets/textures/duel"
sheet --out="$OUT/folha_arte.png" --cols=3 --w=512 "$A/raijin.png" "$A/fujin.png" "$A/title_taiketsu.png"
echo "folhas em $OUT"
