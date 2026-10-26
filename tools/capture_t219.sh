#!/usr/bin/env bash
# T-219 (peso do caminhao): grava SEQUENCIAS de quadros (Movie Maker, 30 quadros/s, com o som em .wav) dos demos
# --demo=crash e --demo=lanes, para comparar antes/depois. Abre janelas do Godot (precisa de tela). UM processo por vez.
# Uso (raiz do projeto, Git Bash): bash tools/capture_t219.sh PASTA_ABS [casos...]
#   casos: crash lanes crash_lado brake_lado (padrao: todos)
#   Grava PASTA/<caso>/f00000000.png ... + f.wav e PASTA/<caso>/feel.csv (telemetria, so no codigo novo).
#   GAME=... aponta para outra pasta do jogo (o "antes" usa um worktree do commit antigo).
#   EXTRA="..." argumentos a mais para a corrida (ex.: --feel=res://data/feel/truck_feel_antes_t219.tres).
# Depois: blender -b --factory-startup -P tools/video_t219.py -- ANTES DEPOIS SAIDA (MP4 lado a lado e tiras).
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
GAME="${GAME:-game}"
OUT="${1:?pasta de saida (absoluta)}"
shift
CASES="${*:-crash lanes crash_lado brake_lado}"
mkdir -p "$OUT"
COMMON="--route=kanto_1_coast --no-events --start=300 --quality=1 --life=off --no-rain --no-touch --time=day"

run() {  # caso, quadros, argumentos
	local name="$1" frames="$2"; shift 2
	local dir="$OUT/$name"
	rm -rf "${dir:?}"
	mkdir -p "$dir"
	"$GODOT" --path "$GAME" --rendering-method gl_compatibility --write-movie "$dir/f.png" --fixed-fps 30 \
		--quit-after "$frames" res://scenes/race/race3d.tscn -- $COMMON --feel-log="$dir/feel.csv" $EXTRA "$@" 2>&1 \
		| grep -E "SCRIPT ERROR|Parse Error|BATIDA|FEEL_T219|recorded" | head -12
	echo "$name: $(ls "$dir" | grep -c png) quadros"
}

for c in $CASES; do
	case "$c" in
		crash) run crash 330 --demo=crash --start-speed=28 ;;
		lanes) run lanes 390 --demo=lanes --start-speed=20 ;;
		crash_lado) run crash_lado 240 --demo=crash --start-speed=28 --cam=21,7,3.2,12,0,1.2 ;;
		brake_lado) run brake_lado 300 --demo=brake --start-speed=30 --cam=21,7,3.2,12,0,1.2 ;;
		*) echo "caso desconhecido: $c" ;;
	esac
done
