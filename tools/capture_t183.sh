#!/usr/bin/env bash
# Capturas da T-183 (carro acidentado no transito). Abre janelas do Godot (precisa de tela).
# Uso (raiz do projeto, Git Bash): bash tools/capture_t183.sh PASTA [prefixo]
#   Grava PASTA/<prefixo>_mesma_cam_tNN.png (camera fixa atras e acima do jogador, a mesma do "antes")
#   e PASTA/<prefixo>_acidentado_{dia,noite}_tNN.png (--cam=wreck: olha o carro batido; pisca, fumaca, triangulo).
#   prefixo padrao: depois. O "antes" (codigo antigo) foi gravado com a mesma linha "mesma_cam".
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac   # o jogo roda com --path game: caminho absoluto
PRE="${2:-depois}"
mkdir -p "$OUT"
BASE="--route=kanto_1_coast --no-events --demo=crash --start=300 --start-speed=28 --nohud --snap-every=1"

run() {  # nome, frames a copiar, argumentos
	local name="$1" frames="$2"; shift 2
	local dir="$OUT/tmp_$name"
	"$GODOT" --path game --resolution 1280x720 --quit-after 1000 res://scenes/race/race3d.tscn -- $BASE --shots="$dir" "$@" 2>&1 \
		| grep -E "SCRIPT ERROR|Parse Error|BATIDA|ACIDENTADO" | head -14
	for f in $frames; do
		[ -f "$dir/${f}_1.png" ] && cp "$dir/${f}_1.png" "$OUT/${PRE}_${name}_${f}.png"
	done
	rm -rf "${dir:?}"
	echo "$name"
}

run mesma_cam "batida_a t06 t08 t10" --time=day --cam=-14,-9,10,35,0,0
run acidentado_dia "t06 t09 t12" --time=day --cam=wreck
run acidentado_noite "t06 t09 t12" --time=night --cam=wreck
