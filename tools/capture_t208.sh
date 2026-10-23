#!/usr/bin/env bash
# T-208 (copia da T-204 com a linha do tempo nova de 8,9 s + 3 s): prints de cada etapa da abertura do duelo
# (preparo preto com neblina, entrada, guardioes, 対決, faixas, raio, arrancada, contagem).
# Precisa de janela (sem --headless). Relogio fixo de 60 quadros/s (--fixed-fps): os prints caem sempre no mesmo
# instante da abertura. UM processo por vez (memoria do PC).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t208.sh PASTA [casos...] [-- extras...]
#   casos: pc_ultra (1920x1080, Ultra/Forward+), pc_media (1920x1080, media/Compatibility = celular),
#          cel (2400x1080, media/Compatibility, botoes de toque), reduzido (pc_media com "reduzir claroes"),
#          dia (pc_media na montanha de dia: a contagem na pista de dia). Sem lista = todos.
# Grava PASTA/<caso>/abertura_preparo_1.png, abertura_00.60s_1.png ... abertura_11.40s_1.png (DuelPlan.SHOT_TIMES:
# 0,6 / 1,6 / 2,4 / 3,3 / 4,5 / 6,0 / 7,14 / 7,5 / 8,5 s da cena e 9,4 / 10,4 / 11,4 s = contagem 3-2-1 na pista).
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
CASES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do CASES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#CASES[@]} -eq 0 ] && CASES=(pc_ultra pc_media cel reduzido dia)
COMMON="--intro=full --no-events --no-rain --no-motion-blur --decorated"
COMPAT="--rendering-method gl_compatibility"
for C in "${CASES[@]}"; do
  REND=""
  case "$C" in
    pc_ultra) ARGS="--window=1920x1080 --no-touch --quality=3 --route=kanto_2_viaduct" ;;
    pc_media) REND="$COMPAT"; ARGS="--window=1920x1080 --no-touch --quality=1 --life=off --route=kanto_2_viaduct" ;;
    cel)      REND="$COMPAT"; ARGS="--window=2400x1080 --touch --hud-scale=1.25 --safe-area=22,0,0,0 --quality=1 --life=off --route=kanto_1_coast" ;;
    reduzido) REND="$COMPAT"; ARGS="--window=1920x1080 --no-touch --quality=1 --life=off --route=kanto_2_viaduct --reduce-flash" ;;
    dia)      REND="$COMPAT"; ARGS="--window=1920x1080 --no-touch --quality=1 --life=off --route=kanto_3_mountain --time=day" ;;
    *) echo "caso desconhecido: $C"; continue ;;
  esac
  mkdir -p "$OUT/$C"
  for TRY in 1 2; do
    # shellcheck disable=SC2086
    "$GODOT" --path game $REND --fixed-fps 60 --quit-after 860 res://scenes/race/race3d.tscn -- $COMMON $ARGS \
        --shots="$OUT/$C" "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|^ERROR|ABERTURA" | head -5
    [ -f "$OUT/$C/abertura_11.40s_1.png" ] && break
  done
done
echo "capturas em $OUT"
