#!/usr/bin/env bash
# Capturas da T-179: o que o jogador VE numa corrida normal (camera de jogo, hora do dia da propria rota, qualidade
# MEDIA = padrao do celular). Serve para conferir se montanhas nevadas, arvores de folhas, postes e viaduto aparecem.
# Precisa de janela (nao use --headless).
# Uso (raiz do projeto, Git Bash): bash tools/capture_t179.sh PASTA [FILTRO] [extra...]
#   Grava PASTA/<cena>/t01.png, t02.png... FILTRO = trecho do nome (ex.: litoral, rapida); "all" = tudo.
#   Antes/depois: rode uma vez com o codigo antigo e outra com o novo, em pastas diferentes.
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
OUT="${1:?pasta de saida}"
case "$OUT" in /*|?:*) ;; *) OUT="$(pwd)/$OUT" ;; esac   # o jogo roda com --path game: caminho absoluto
FILTER="${2:-all}"
shift; shift || true
shot() {   # nome z [args da rota...]
  local name="$1" z="$2" dir="$OUT/$1"
  shift 2
  if [ "$FILTER" != "all" ] && [[ "$name" != *"$FILTER"* ]]; then return; fi
  "$GODOT" --path game --resolution 1280x576 --quit-after 520 res://scenes/race/race3d.tscn -- \
      --quality=1 --start="$z" --start-speed=22 --autoplay --nohud --shots="$dir" --snap-every=2.5 \
      --event-seed=7 --intro=none "$@" >/dev/null 2>&1
  echo "$name"
}
shot rapida_cidade_noite 300                                   # CORRIDA RAPIDA do menu (sem rota: pista de teste)
shot litoral_tarde 600 --route=kanto_1_coast                   # frete 1 (Litoral, tarde)
shot litoral_tarde_fim 1700 --route=kanto_1_coast
shot viaduto_noite 1700 --route=kanto_2_viaduct                # frete 2 (Viaduto, noite) - passa no viaduto de 2.050 m
shot montanha_dia 1300 --route=kanto_3_mountain               # frete 3 (Montanha, dia)
shot montanha_dia_viaduto 2350 --route=kanto_3_mountain        # passa no viaduto de 2.580 m
echo "capturas em $OUT"
