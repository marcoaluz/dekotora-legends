#!/usr/bin/env bash
# Capturas da T-172 (pecas deluxe): garagem e corrida, dia e noite, ANTES (pecas antigas do caminhao de demonstracao)
# e DEPOIS (as 6 deluxe no lugar das antigas do mesmo encaixe). Precisa de janela (nao use --headless).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t172.sh PASTA_ABSOLUTA [garagem|corrida]
#   Garagem: PASTA/garagem_<antes|depois>_<dia|noite>_<vista>.png ; corrida: PASTA/corrida_<antes|depois>_<dia|noite>/t01.png
: "${GODOT:?defina GODOT (tools/env.sh)}"
OUT="${1:?pasta de saida (caminho absoluto)}"
WHAT="${2:-all}"
mkdir -p "$OUT"
DX="andon_ichiban_dx,marker_crown_dx,underglow_neon_dx,side_bumper_dx,step_lit_dx,rear_tail_bar_dx"
garage() {   # nome vista zoom [extras...]
  local name="$1" view="$2" zoom="$3"
  shift 3
  "$GODOT" --path game --resolution 1280x720 res://scenes/garage/garage.tscn -- --demo --body=base --cab=chata --hideui --view="$view" \
      --zoom="$zoom" --shot="$OUT/$name.png" "$@" >/dev/null 2>&1
}
race() {     # nome hora [extras...]
  local name="$1" tod="$2"
  shift 2
  "$GODOT" --path game --resolution 1280x720 --quit-after 400 res://scenes/race/race3d.tscn -- --decorated \
      --route=kanto_2_viaduct --start=300 --start-speed=0 --no-events --time="$tod" --nohud --shots="$OUT/$name" \
      --snap-every=4 --cam=17,5,3.6,6,0,2.0 "$@" >/dev/null 2>&1
}
if [ "$WHAT" = all ] || [ "$WHAT" = garagem ]; then
  for V in default:1.0 roof:0.8 side:1.0 rear:0.9; do
    view="${V%%:*}"; zoom="${V##*:}"
    garage "garagem_antes_noite_$view" "$view" "$zoom"
    garage "garagem_depois_noite_$view" "$view" "$zoom" --parts="$DX"
    garage "garagem_antes_dia_$view" "$view" "$zoom" --day
    garage "garagem_depois_dia_$view" "$view" "$zoom" --day --parts="$DX"
  done
fi
if [ "$WHAT" = all ] || [ "$WHAT" = corrida ]; then
  for T in night day; do
    race "corrida_antes_$T" "$T"
    race "corrida_depois_$T" "$T" --parts="$DX"
  done
fi
echo "capturas em $OUT"
