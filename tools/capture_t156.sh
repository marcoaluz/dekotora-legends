#!/usr/bin/env bash
# Capturas da T-156 (abertura "frente a frente" antes da largada), de dia e de noite.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t156.sh PASTA [so_estas_cenas...]
#   Grava PASTA/<cena>/duelo_N_<momento>_1.png: 1 frente a frente, 2 detalhes do jogador (para-choque, viseira, mural)
#   com a faixa, 3 detalhes do rival com a faixa e a fala, 4 VS, 5 alinhamento, 6 contagem.
#   Cenas: dia (montanha, praca de pedagio), noite (viaduto, area de descanso), tarde (litoral, area de descanso),
#          curta (revanche: so alinhamento e contagem), comboio (corrida rapida com 4 caminhoes, versao curta).
: "${GODOT:?defina GODOT (tools/env.sh)}"
OUT="${1:?pasta de saida}"
shift
ONLY=" $* "
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
shot() {   # cena [argumentos da corrida...]
  local name="$1"
  shift
  if [ "$ONLY" != "  " ] && [[ "$ONLY" != *" $name "* ]]; then return; fi
  mkdir -p "$OUT/$name"
  "$GODOT" --path game --resolution 1280x720 --quit-after 1100 res://scenes/race/race3d.tscn -- \
      --no-events --shots="$OUT/$name" "$@" >/dev/null 2>&1
}
shot dia --route=kanto_3_mountain --decorated
shot noite --route=kanto_2_viaduct --decorated
shot tarde --route=kanto_1_coast --decorated
shot curta --route=kanto_2_viaduct --intro=short
shot comboio --intro=short
echo "capturas em $OUT"
