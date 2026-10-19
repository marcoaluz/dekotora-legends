#!/usr/bin/env bash
# Folhas lado a lado da T-155 (antes | depois) a partir de docs/capturas_t155/antes e depois.
# Uso (raiz do projeto): bash tools/sheet_t155.sh [DESTINO] [antes|depois|par]
#   par (padrao) = antes | depois em cada linha; antes/depois = so uma pasta, 2 por linha.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
ROOT="$(pwd)/docs/capturas_t155"
DST="${1:-$ROOT}"
MODE="${2:-par}"
mkdir -p "$DST"
sheet() {  # nome, largura, imagens...
	local name="$1" w="$2"; shift 2
	local files=()
	for f in "$@"; do
		if [ "$MODE" = "par" ]; then
			files+=("$ROOT/antes/$f.png" "$ROOT/depois/$f.png")
		else
			files+=("$ROOT/$MODE/$f.png")
		fi
	done
	"$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$DST/$name.png" --cols=2 --w="$w" \
		"${files[@]}" 2>&1 | grep -E "OK folha|ERROR" || true
}
sheet item1_mural_bau 560 mural_base_noite mural_base_tarde mural_base_dia mural_base_tunel_dia mural_base_noite_atras mural_garagem_noite
sheet item1_mural_graneleira 560 mural_graneleira_noite mural_graneleira_tarde mural_graneleira_dia mural_graneleira_tunel_dia mural_graneleira_noite_atras mural_garagem_graneleira_noite
sheet item2_ficha 640 ficha_graneleira_960x540 ficha_graneleira_1200x540 ficha_base_960x540 ficha_canter_960x540 ficha_leve_960x540 ficha_longo_960x540 ficha_base_1200x540
sheet item3_carro_batido 560 batido_perto_day batido_alto_day batido_perto_night batido_alto_night
sheet item3_bocas_tunel 560 boca_viaduto_day boca_viaduto_longe_day boca_montanha_day boca_antigo_day boca_antigo_perto_day boca_viaduto_night boca_montanha_night boca_antigo_perto_night
sheet item3_tunel_antigo 560 tunel_antigo_night tunel_antigo_day boca_antigo_night
