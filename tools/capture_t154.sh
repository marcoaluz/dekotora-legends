#!/usr/bin/env bash
# Capturas da T-154 (ferrovia ao lado da rodovia, trens, viadutos de trem e bocas de tunel), de dia e de noite.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t154.sh PASTA [so_estas_cenas...]
#   Grava PASTA/<cena>_<hora>/tNN.png (caminhao parado; o 1o trem passa ~10 s depois da largada; no cruzamento ~12 s).
#   Cenas: litoral_trem litoral_boca cidade_trem cidade_cruzamento montanha_cruzamento montanha_boca montanha_trem
#   Extras para comparar: CAPTURE_EXTRA="--no-rail" bash tools/capture_t154.sh PASTA
: "${GODOT:?defina GODOT (tools/env.sh)}"
OUT="${1:?pasta de saida}"
shift
ONLY=" $* "
shot() {   # cena rota z hora camera [extras...]
  local name="$1" route="$2" z="$3" tod="$4" cam="$5"
  shift 5
  if [ "$ONLY" != "  " ] && [[ "$ONLY" != *" $name "* ]]; then return; fi
  "$GODOT" --path game --resolution 1280x720 --quit-after 1150 res://scenes/race/race3d.tscn -- \
      --route="$route" --start="$z" --start-speed=0 --time="$tod" --nohud --no-events --shots="$OUT/${name}_$tod" \
      --snap-every=3.5 ${cam:+--cam=$cam} $CAPTURE_EXTRA "$@" >/dev/null 2>&1
}
for T in day night; do
  shot litoral_trem kanto_1_coast 600 $T "-6,-8,7,30,-36,3" --train=freight
  shot litoral_bonde kanto_1_coast 900 $T "-4,-10,5,25,-36,3" --train=lrt --train-dir=opposite
  shot litoral_boca kanto_1_coast 2060 $T "-10,-6,9,90,-36,5"
  shot cidade_trem kanto_2_viaduct 600 $T "-6,-10,6,30,-40,3" --train=lrt
  shot cidade_cruzamento kanto_2_viaduct 1350 $T "-12,0,9,150,-10,12"
  shot montanha_cruzamento kanto_3_mountain 110 $T "-12,0,7,130,-12,8"
  shot montanha_boca kanto_3_mountain 1990 $T "-10,-8,8,90,-38,5"
  shot montanha_trem kanto_3_mountain 1500 $T "-6,-8,7,30,-38,3"
done
echo "capturas em $OUT"
