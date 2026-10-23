#!/usr/bin/env bash
# T-208: folhas e prints reduzidos da abertura do duelo (linha do tempo nova) a partir de tools/capture_t208.sh.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/sheet_t208.sh PASTA_DAS_CAPTURAS [SAIDA=docs/capturas_t208]
# Grava em SAIDA: etapas/<instante>.png (PC media, 960 px), folha_<caso>.png (preparo + 12 instantes: 0,6 a 11,4 s),
# folha_reduzido.png (raio normal x "reduzir claroes"). A arte dos guardioes nao mudou (docs/capturas_t204/folha_arte.png).
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
IN="${1:?pasta das capturas}"
OUT="${2:-docs/capturas_t208}"
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
      "$IN/pc_media/abertura_07.14s_1.png" "$IN/reduzido/abertura_07.14s_1.png" \
      "$IN/pc_media/abertura_07.50s_1.png" "$IN/reduzido/abertura_07.50s_1.png"
fi

echo "folhas em $OUT"
