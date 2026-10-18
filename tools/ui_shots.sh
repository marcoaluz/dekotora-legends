#!/usr/bin/env bash
# Capturas de todas as telas (T-138) em uma resolucao. Abre uma janela por tela (o modo headless nao desenha).
# Uso (na raiz do projeto): bash tools/ui_shots.sh 960x540 PASTA [tela...]
# 2400x1080 (20:9): use 1200x540. A janela nao passa do tamanho do monitor, e com stretch canvas_items
# (base 960x540, aspect expand) o layout de 1200x540 e identico ao de 2400x1080 (so muda a nitidez).
# Telas: menu market options newcareer garage garage_parts garage_mech garage_repair garage_wheel lobby pause result result_lose result_timeout
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
RES="${1:-960x540}"
OUT="${2:-docs/direcao_arte/telas_$RES}"
shift 2 2>/dev/null
mkdir -p "$OUT"
ABS_OUT="$(cd "$OUT" && pwd -W 2>/dev/null || pwd)"
ALL="menu market options newcareer garage garage_parts garage_mech garage_repair garage_wheel lobby pause result result_lose result_timeout"
LIST="${*:-$ALL}"
run() {   # nome, cena, argumentos...
	local name="$1" scene="$2"
	shift 2
	echo "== $name"
	timeout 90 "$GODOT" --path game --resolution "$RES" "$scene" -- "$@" 2>&1 | grep -E "CAPTURA|SCRIPT ERROR|Parse Error|ERROR:" | grep -v "resources still in use" | head -5
}
for s in $LIST; do
	case "$s" in
		menu) run menu res://scenes/menu/main_menu.tscn --shot="$ABS_OUT/menu.png" --shot-delay=3 ;;
		menu_a) run menu_a res://scenes/menu/main_menu.tscn --menu-bg=a --shot="$ABS_OUT/menu_fundo_a.png" --shot-delay=4 ;;
		menu_b) run menu_b res://scenes/menu/main_menu.tscn --menu-bg=b --shot="$ABS_OUT/menu_fundo_b.png" --shot-delay=4 ;;
		market) run market res://scenes/menu/main_menu.tscn --screen=market --shot="$ABS_OUT/mercado.png" ;;
		options) run options res://scenes/menu/main_menu.tscn --screen=options --shot="$ABS_OUT/opcoes.png" ;;
		newcareer) run newcareer res://scenes/menu/main_menu.tscn --screen=newcareer --shot="$ABS_OUT/nova_carreira.png" ;;
		garage) run garage res://scenes/garage/garage.tscn --demo --shot="$ABS_OUT/garagem.png" ;;
		garage_parts) run garage_parts res://scenes/garage/garage.tscn --demo --tab=parts --shot="$ABS_OUT/garagem_decoracao.png" ;;
		garage_slot) run garage_slot res://scenes/garage/garage.tscn --demo --slot=front_bumper --shot="$ABS_OUT/garagem_peca.png" ;;
		garage_mech) run garage_mech res://scenes/garage/garage.tscn --demo --tab=mech --shot="$ABS_OUT/garagem_mecanica.png" ;;
		garage_repair) run garage_repair res://scenes/garage/garage.tscn --demo --damage --tab=repair --shot="$ABS_OUT/garagem_reparo.png" ;;
		garage_wheel) run garage_wheel res://scenes/garage/garage.tscn --demo --view=wheel --spin --shot="$ABS_OUT/garagem_rodas.png" ;;
		lobby) run lobby res://scenes/lobby/lobby.tscn --shot="$ABS_OUT/lobby.png" ;;
		pause) run pause res://scenes/race/race3d.tscn --route=kanto_1_coast --start=400 --nohud --paused --shot="$ABS_OUT/pausa.png" --shot-delay=4 ;;
		result) run result res://scenes/race/race3d.tscn --route=kanto_1_coast --demo=result --contract=ceramica --shot="$ABS_OUT/resultado.png" ;;
		result_lose) run result_lose res://scenes/race/race3d.tscn --route=kanto_1_coast --demo=result_lose --shot="$ABS_OUT/resultado_derrota.png" ;;
		result_timeout) run result_timeout res://scenes/race/race3d.tscn --route=kanto_1_coast --demo=result_timeout --shot="$ABS_OUT/resultado_tempo.png" ;;
	esac
done
