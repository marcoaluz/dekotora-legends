#!/usr/bin/env bash
# T-171: capturas da previa de pecas na garagem (com a tela). Uso: bash tools/capture_t171_preview.sh PASTA
set -u
OUT="${1:?pasta de saida}"
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
case "$OUT" in /*|[A-Za-z]:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
mkdir -p "$OUT"
shot() {   # nome, argumentos...
	local name="$1"; shift
	"$GODOT" --path game --resolution 960x540 res://scenes/garage/garage.tscn -- --demo --noparts "$@" \
		--shot="$OUT/$name.png" > /dev/null 2>&1
	echo "$OUT/$name.png"
}
shot sem_previa_parachoque --slot=front_bumper
shot previa_parachoque --preview=fb_gold_wing
shot previa_calota --preview=hub_gold
shot previa_mural --preview=mural_lightning
shot previa_escapamento --preview=kw_exhaust_stacks
shot previa_sem_dinheiro --preview=fb_gold_wing --fame=0
shot previa_cor_travada --preview-paint=#f0b83a --fame=0
shot previa_canter_teto --body=canter --preview=roof_lights_crown
