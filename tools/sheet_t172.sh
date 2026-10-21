#!/usr/bin/env bash
# Folhas antes/depois da T-172 (esquerda = antes, direita = depois), a partir das capturas de tools/capture_t172.sh.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/sheet_t172.sh PASTA_ABSOLUTA
: "${GODOT:?defina GODOT (tools/env.sh)}"
D="${1:?pasta das capturas (caminho absoluto)}"
sheet() {   # saida png...
  local out="$1"
  shift
  "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$out" --cols=2 --w=640 "$@" 2>&1 | grep -i "error" || true
}
for T in noite dia; do
  files=()
  for V in default roof side rear; do
    files+=("$D/garagem_antes_${T}_$V.png" "$D/garagem_depois_${T}_$V.png")
  done
  sheet "$D/antes_depois_garagem_$T.png" "${files[@]}"
done
sheet "$D/antes_depois_corrida.png" "$D/corrida_antes_night/t01_1.png" "$D/corrida_depois_night/t01_1.png" \
    "$D/corrida_antes_day/t01_1.png" "$D/corrida_depois_day/t01_1.png"
echo "folhas em $D"
