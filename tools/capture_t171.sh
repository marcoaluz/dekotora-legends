#!/usr/bin/env bash
# T-171: capturas da garagem (rodas sobre o piso) para varios modelos/cabines.
# Uso (na raiz do projeto, Git Bash): bash tools/capture_t171.sh PASTA [vista] [extra...]
#   vista: wheel (padrao) | side | front | default
#   GODOT=... troca o executavel. Precisa de janela (nao use --headless).
set -u
OUT="${1:?pasta de saida}"
VIEW="${2:-wheel}"
shift; shift || true
EXTRA="$*"
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
case "$OUT" in /*|[A-Za-z]:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
mkdir -p "$OUT"
for combo in base:chata base:jac base:curta base:americana canter:chata leve:chata longo:jac graneleira:americana; do
	body="${combo%%:*}"
	cab="${combo##*:}"
	f="$OUT/${body}_${cab}_${VIEW}.png"
	"$GODOT" --path game --resolution 960x540 res://scenes/garage/garage.tscn -- --demo --noparts --hideui \
		--body="$body" --cab="$cab" --view="$VIEW" $EXTRA --shot="$f" > /dev/null 2>&1
	echo "$f"
done
