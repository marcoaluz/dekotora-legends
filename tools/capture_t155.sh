#!/usr/bin/env bash
# Capturas da T-155 (acabamento visual F4), para comparar antes/depois. Abre janelas do Godot (precisa de tela).
# Uso (raiz do projeto, Git Bash): bash tools/capture_t155.sh PASTA [GRUPO...]
#   GRUPO = mural | ficha | batido | tunel (sem grupo = todos). Grava PNGs com nomes fixos em PASTA.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac   # o jogo roda com --path game: caminho absoluto
shift
GROUPS_="${*:-mural ficha batido tunel}"
mkdir -p "$OUT"

race() {   # nome, frame (t02...), rota, hora, argumentos extras: corrida andando (piloto automatico)
	local name="$1" frame="$2" route="$3" tod="$4"; shift 4
	local dir="$OUT/tmp_$name"
	"$GODOT" --path game --resolution 1280x720 --quit-after 700 res://scenes/race/race3d.tscn -- --decorated --noparts \
		--route="$route" --time="$tod" --nohud --shots="$dir" --snap-every=3 --event-seed=7 "$@" 2>&1 \
		| grep -E "SCRIPT ERROR|Parse Error" || true
	[ -f "$dir/${frame}_1.png" ] && cp "$dir/${frame}_1.png" "$OUT/$name.png"
	rm -rf "${dir:?}"
	echo "$name"
}
still() {  # nome, rota, z, hora, camera, extras: caminhao parado, camera fixa
	local name="$1" route="$2" z="$3" tod="$4" cam="$5"; shift 5
	local dir="$OUT/tmp_$name"
	"$GODOT" --path game --resolution 1280x720 --quit-after 330 res://scenes/race/race3d.tscn -- \
		--route="$route" --start="$z" --start-speed=0 --time="$tod" --nohud --shots="$dir" --snap-every=3.5 \
		--event-seed=7 --cam="$cam" "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" || true
	[ -f "$dir/t01_1.png" ] && cp "$dir/t01_1.png" "$OUT/$name.png"
	rm -rf "${dir:?}"
	echo "$name"
}
garage() { # nome, resolucao, argumentos
	local name="$1" res="$2"; shift 2
	timeout 90 "$GODOT" --path game --resolution "$res" res://scenes/garage/garage.tscn -- --demo "$@" \
		--shot="$OUT/$name.png" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" || true
	echo "$name"
}

SIDE="-3,-5.5,2.4,5,0,1.8"     # de lado, atras e a esquerda do bau (como a T-136)
for g in $GROUPS_; do
	case "$g" in
	mural)
		for B in base graneleira; do
			race "mural_${B}_noite" t02 kanto_2_viaduct night --body="$B" --start=300 --start-speed=22 --autoplay --cam="$SIDE"
			race "mural_${B}_tarde" t02 kanto_1_coast dusk --body="$B" --start=300 --start-speed=22 --autoplay --cam="$SIDE"
			race "mural_${B}_dia" t02 kanto_3_mountain day --body="$B" --start=300 --start-speed=22 --autoplay --cam="$SIDE"
			race "mural_${B}_noite_atras" t02 kanto_2_viaduct night --body="$B" --start=300 --start-speed=22 --autoplay --cam=-16,-1.5,5,8,0,2
			race "mural_${B}_tunel_dia" t01 kanto_3_mountain day --body="$B" --start=2095 --start-speed=12 --autoplay --cam="$SIDE" --no-events
		done
		garage mural_garagem_noite 1280x720 --noparts --hideui --body=base --zoom=0.55
		garage mural_garagem_graneleira_noite 1280x720 --noparts --hideui --body=graneleira --zoom=0.55
		;;
	ficha)
		for B in graneleira base leve longo canter; do
			garage "ficha_${B}_960x540" 960x540 --body="$B"
		done
		garage ficha_graneleira_1200x540 1200x540 --body=graneleira
		garage ficha_base_1200x540 1200x540 --body=base
		;;
	batido)
		for T in day night; do
			still "batido_perto_$T" kanto_2_viaduct 1990 "$T" "4,-1,2.6,19,6,0.6" --event=accident:2-3@1990
			still "batido_alto_$T" kanto_2_viaduct 1990 "10,-3,5.5,19,6,0.4" --event=accident:2-3@1990
		done
		;;
	tunel)
		for T in day night; do
			still "boca_viaduto_$T" kanto_2_viaduct 972 "$T" "-6,-8,2.5,8,-13.5,1" --no-events
			still "boca_viaduto_longe_$T" kanto_2_viaduct 930 "$T" "-10,0,6,60,0,2" --no-events
			still "boca_montanha_$T" kanto_3_mountain 2040 "$T" "-10,0,6,50,0,2" --no-events
			still "boca_antigo_$T" kanto_3_mountain 770 "$T" "-6,-2,5,40,-2.4,4" --no-events
			still "boca_antigo_perto_$T" kanto_3_mountain 785 "$T" "-4,-6,2.4,22,-9,1" --no-events
			still "tunel_antigo_$T" kanto_3_mountain 870 "$T" "-13,-2.4,4.6,30,-2.4,1.5" --no-events
		done
		;;
	esac
done
echo "capturas em $OUT"
