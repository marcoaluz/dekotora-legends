#!/usr/bin/env bash
# T-171: recortes ampliados do contato pneu/piso (antes | depois) a partir das capturas de tools/capture_t171.sh.
# Uso (na raiz do projeto): bash tools/sheet_t171.sh [PASTA=docs/capturas_t171] [vista=wheel] [rect=400,230,320,140]
set -u
DIR="${1:-docs/capturas_t171}"
VIEW="${2:-wheel}"
RECT="${3:-400,230,320,140}"
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
case "$DIR" in /*|[A-Za-z]:*) ;; *) DIR="$(pwd)/$DIR" ;; esac
for a in "$DIR"/antes/*_"$VIEW".png; do
	name="$(basename "$a" .png)"
	b="$DIR/depois/$name.png"
	[ -f "$b" ] || continue
	"$GODOT" --headless --path game -s res://tools_dev/crop_zoom.gd -- --rect="$RECT" --zoom=2 \
		--out="$DIR/zoom_$name.png" "$a" "$b" 2>&1 | grep FOLHA
done
