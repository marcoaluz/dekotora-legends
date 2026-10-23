#!/usr/bin/env bash
# T-202: prints do HUD novo da corrida (PC 1920x1080 e celular 2400x1080, dia e noite, e um com dano + seta ligada).
# Precisa de janela (sem --headless); funciona mesmo com o monitor desligado (--window= cria a janela no tamanho
# certo, sem borda). UM processo por vez (memoria do PC).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t202.sh PASTA [casos...] [-- extras...]
#   casos: pc_dia pc_noite cel_dia cel_noite dano_pc dano_cel tunel_pc (sem lista = todos)
# Grava PASTA/<caso>.png (o quadro de 6 s depois do --start) e PASTA/raw/<caso>/tNN_1.png.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
CASES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do CASES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#CASES[@]} -eq 0 ] && CASES=(pc_dia pc_noite cel_dia cel_noite dano_pc dano_cel tunel_pc)
PC="--window=1920x1080 --no-touch"
CEL="--window=2400x1080 --touch --hud-scale=1.25 --safe-area=22,0,0,0"
COMMON="--quality=1 --no-motion-blur --no-rain --life=off --start-speed=26 --autoplay --event-seed=7 --race-cam=standard --mirror=on"
mkdir -p "$OUT/raw"
for C in "${CASES[@]}"; do
  case "$C" in
    pc_dia)    ARGS="$PC --route=kanto_1_coast --start=400 --time=day --event=accident:3@760" ;;
    pc_noite)  ARGS="$PC --route=kanto_1_coast --start=400 --time=night --event=accident:3@760" ;;
    cel_dia)   ARGS="$CEL --route=kanto_1_coast --start=400 --time=day --event=works:1@760+170" ;;
    cel_noite) ARGS="$CEL --route=kanto_1_coast --start=400 --time=night --event=works:1@760+170" ;;
    dano_pc)   ARGS="$PC --route=kanto_2_viaduct --start=500 --time=night --hud-demo" ;;
    dano_cel)  ARGS="$CEL --route=kanto_2_viaduct --start=500 --time=day --hud-demo" ;;
    tunel_pc)  ARGS="$PC --route=kanto_3_mountain --start=700 --time=day" ;;
    *) echo "caso desconhecido: $C"; continue ;;
  esac
  for TRY in 1 2; do
    # shellcheck disable=SC2086
    "$GODOT" --path game --quit-after 1400 res://scenes/race/race3d.tscn -- $COMMON $ARGS \
        --shots="$OUT/raw/$C" --snap-every=3 "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|^ERROR" | head -3
    [ -f "$OUT/raw/$C/t02_1.png" ] && break
  done
  [ -f "$OUT/raw/$C/t02_1.png" ] && cp "$OUT/raw/$C/t02_1.png" "$OUT/$C.png"
done
echo "capturas em $OUT"
