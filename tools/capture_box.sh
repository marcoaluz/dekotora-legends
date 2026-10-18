#!/usr/bin/env bash
# Capturas do baú dentro do JOGO (T-136): garagem de noite e de dia (3/4 e traseira) e corrida de noite e de dia
# (câmera de perseguição e de lado), sempre o caminhão de fábrica branco, sem peças.
# Uso (raiz do projeto, Git Bash): source tools/env.sh && bash tools/capture_box.sh PASTA [CABINE] [MODELO]
#   PASTA  = onde gravar os PNG (caminho absoluto, ex.: C:/tmp/bau_depois)
#   CABINE = chata (padrão) | jac | curta | americana    MODELO = base (padrão) | leve | longo | canter
# Abre janelas do Godot por alguns segundos (precisa de tela). Para medir FPS use tools/measure_box.sh.
set -e
: "${GODOT:?rode antes: source tools/env.sh}"
OUT="${1:?informe a pasta de saida}"
CAB="${2:-chata}"
BODY="${3:-base}"
mkdir -p "$OUT"
G=(--path game --resolution 1280x720)
garage() {   # nome, argumentos extras
    local name="$1"; shift
    "$GODOT" "${G[@]}" res://scenes/garage/garage.tscn -- --demo --noparts --hideui --cab="$CAB" --body="$BODY" "$@" \
        --shot="$OUT/garagem_$name.png" 2>&1 | grep -E "CAPTURA|SCRIPT ERROR|Parse Error" || true
}
race() {     # nome, rota, hora, argumentos extras
    local name="$1" route="$2" tod="$3"; shift 3
    local dir="$OUT/tmp_$name"
    "$GODOT" "${G[@]}" --quit-after 700 res://scenes/race/race3d.tscn -- --decorated --noparts --cab="$CAB" --body="$BODY" \
        --route="$route" --time="$tod" --start=300 --start-speed=22 --autoplay --nohud --shots="$dir" --snap-every=3 "$@" \
        2>&1 | grep -E "SCRIPT ERROR|Parse Error" || true
    [ -f "$dir/t02_1.png" ] && cp "$dir/t02_1.png" "$OUT/corrida_$name.png"
    rm -rf "${dir:?}"
}
garage noite_34 --zoom=0.55
garage dia_34 --day --zoom=0.55
garage noite_traseira --view=rear --zoom=0.8
garage dia_traseira --day --view=rear --zoom=0.8
garage dia_lado --day --view=side --zoom=0.7
race noite kanto_2_viaduct night
race dia kanto_3_mountain day
race noite_lado kanto_2_viaduct night --cam=-3,-5.5,2.4,5,0,1.8
race dia_lado kanto_3_mountain day --cam=-3,-5.5,2.4,5,0,1.8
ls "$OUT"
