#!/usr/bin/env bash
# T-241: prints de "olhar para tras / esquerda / direita" (PC 1920x1080 e celular 2400x1080 = 20:9, dia e noite).
# Antes = camera normal ("frente"); depois = segurando o olhar (--look=back|left|right forca o olhar e mostra o botao
# do olho apertado no celular). Precisa de janela (sem --headless). UM processo por vez (memoria do PC).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t241.sh PASTA [casos...] [-- extras...]
#   casos: <pc|cel>_<dia|noite>_<frente|tras|esq|dir>   (sem lista = os 16)
# Grava PASTA/<caso>.png (o quadro de 6 s depois do --start) e PASTA/raw/<caso>/tNN_1.png.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
CASES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do CASES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
if [ ${#CASES[@]} -eq 0 ]; then
  for D in pc cel; do for T in dia noite; do for L in frente tras esq dir; do CASES+=("${D}_${T}_${L}"); done; done; done
fi
PC="--window=1920x1080 --no-touch"
CEL="--window=2400x1080 --touch --hud-scale=1.25 --safe-area=22,0,0,0"
COMMON="--quality=1 --no-motion-blur --no-rain --life=off --start-speed=26 --autoplay --event-seed=7 --race-cam=standard --mirror=on --route=kanto_1_coast --start=400"
mkdir -p "$OUT/raw"
for C in "${CASES[@]}"; do
  IFS=_ read -r DEV TOD LOOK <<< "$C"
  case "$DEV" in pc) ARGS="$PC" ;; cel) ARGS="$CEL" ;; *) echo "caso desconhecido: $C"; continue ;; esac
  case "$TOD" in dia) ARGS="$ARGS --time=day" ;; noite) ARGS="$ARGS --time=night" ;; *) echo "caso desconhecido: $C"; continue ;; esac
  case "$LOOK" in frente) ;; tras) ARGS="$ARGS --look=back" ;; esq) ARGS="$ARGS --look=left" ;; dir) ARGS="$ARGS --look=right" ;;
    *) echo "caso desconhecido: $C"; continue ;; esac
  for TRY in 1 2; do
    # shellcheck disable=SC2086
    "$GODOT" --path game --quit-after 1400 res://scenes/race/race3d.tscn -- $COMMON $ARGS \
        --shots="$OUT/raw/$C" --snap-every=3 "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|^ERROR" | head -3
    [ -f "$OUT/raw/$C/t02_1.png" ] && break
  done
  [ -f "$OUT/raw/$C/t02_1.png" ] && cp "$OUT/raw/$C/t02_1.png" "$OUT/$C.png"
done
echo "capturas em $OUT"
