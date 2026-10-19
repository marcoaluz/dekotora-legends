#!/usr/bin/env bash
# Capturas da T-146 (barreiras, placas, porticos de trelica, outdoors) nas 3 rotas, de dia e de noite.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t146.sh PASTA [extra...]
#   Grava PASTA/<rota>_<cena>_<hora>/t01.png (caminhao parado; camera padrao da corrida, sem HUD).
#   Extras vao para o jogo (ex.: --no-kit para as capturas "antes").
: "${GODOT:?defina GODOT (tools/env.sh)}"
OUT="${1:?pasta de saida}"
shift
shot() {   # rota cena z hora camera(ou "") [extras...]
  local dir="$OUT/$1_$2_$4" route="$1" z="$3" tod="$4" cam="$5"
  shift 5
  "$GODOT" --path game --resolution 1280x720 --quit-after 330 res://scenes/race/race3d.tscn -- \
      --route="$route" --start="$z" --start-speed=0 --time="$tod" --nohud --shots="$dir" --snap-every=3.5 \
      ${cam:+--cam=$cam} "$@" >/dev/null 2>&1
}
P="-14,2,8,70,0,6"          # portico: atras e alto
O="-6,-10,9,48,-22,8"        # outdoor: alto, olhando para a esquerda
E="-10,0,10,60,0,0"          # eventos e tunel: alto, olhando a pista
for T in day night; do
  shot kanto_1_coast portico 270 $T "$P" "$@"
  shot kanto_1_coast outdoor 650 $T "$O" "$@"
  shot kanto_1_coast estreitamento 1600 $T "$E" "$@"
  shot kanto_1_coast placa 240 $T "-2,-8,2.5,25,-13,3" "$@"
  shot kanto_2_viaduct portico 270 $T "$P" "$@"
  shot kanto_2_viaduct tunel 935 $T "$E" "$@"
  shot kanto_2_viaduct acidente 1950 $T "$E" "$@"
  shot kanto_2_viaduct outdoor 650 $T "$O" "$@"
  shot kanto_3_mountain obras 2440 $T "$E" "$@"
  shot kanto_3_mountain tunel 2035 $T "$E" "$@"
  shot kanto_3_mountain outdoor 650 $T "$O" "$@"
done
echo "capturas em $OUT"
