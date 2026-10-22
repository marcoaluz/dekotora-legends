#!/usr/bin/env bash
# T-189: prints MEDIA (como no celular: renderizador Compatibility, --quality=1, sem a vida do cenario) x ULTRA (PC:
# Forward+, --quality=3, vida ligada) no MESMO ponto das 3 rotas (trecho-piloto da T-188), dia e noite, com a camera
# do jogo. Precisa de janela (nao use --headless). Grava PASTA/<rota>_<hora>_<media|ultra>.png e a folha
# PASTA/folha_<hora>.png (esquerda = media, direita = ultra; uma linha por rota).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t189.sh PASTA [day night] [-- extras]
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shift || true
TIMES=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do TIMES+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#TIMES[@]} -eq 0 ] && TIMES=(day night)
TMP="$OUT/_bruto"
mkdir -p "$TMP"
for T in "${TIMES[@]}"; do
  SHEET=()
  for SPOT in "kanto_1_coast 650" "kanto_2_viaduct 1350" "kanto_3_mountain 1150"; do
    set -- $SPOT "$@"
    R="$1"; Z="$2"; shift 2
    for Q in media ultra; do
      if [ "$Q" = media ]; then FLAGS=(--rendering-method gl_compatibility); EX=(--quality=1 --life=off)
      else FLAGS=(); EX=(--quality=3 --life=on); fi
      D="$TMP/${R}_${T}_$Q"
      rm -rf "${D:?}"
      for TRY in 1 2; do                     # as vezes a janela nao grava nenhum quadro: tenta de novo uma vez
      [ -f "$D/t02_1.png" ] && break
      timeout 240 "$GODOT" --path game "${FLAGS[@]}" --resolution 1280x720 --quit-after 900 res://scenes/race/race3d.tscn -- \
          --route="$R" --start="$Z" --start-speed=22 --autoplay --event-seed=7 --no-intro --nohud --no-rain --no-motion-blur \
          --time="$T" "${EX[@]}" --shots="$D" --snap-every=4 "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" || true
      done
      if [ -f "$D/t02_1.png" ]; then cp "$D/t02_1.png" "$OUT/${R}_${T}_$Q.png"; else echo "FALTOU $D/t02_1.png"; fi
      SHEET+=("$OUT/${R}_${T}_$Q.png")
    done
  done
  "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$OUT/folha_$T.png" --cols=2 --w=640 \
      "${SHEET[@]}" 2>&1 | grep -E "OK folha|ERROR" || true
done
rm -rf "${TMP:?}"
echo "capturas em $OUT"
