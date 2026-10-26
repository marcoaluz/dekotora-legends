#!/usr/bin/env bash
# T-218: capturas dos caminhões de homenagem (precisa de janela; um processo por vez).
#   garagem: cada modelo de lado e 3/4 (dia) e o baú rosa de noite;
#   corrida: cada modelo como RIVAL na largada da campanha (litoral, --rival-body força o modelo), dia e noite.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t218.sh PASTA_ABSOLUTA [garagem] [corrida]
: "${GODOT:?defina GODOT (tools/env.sh)}"
OUT="${1:?pasta de saida (caminho absoluto)}"
shift
WHAT="${*:-garagem corrida}"
IDS="${IDS:-alubox tarp pinkbox tanker dump}"
mkdir -p "$OUT"
gshot() {   # nome vista zoom [extras...]
  local name="$1" view="$2" zoom="$3"
  shift 3
  for try in 1 2; do
    timeout 120 "$GODOT" --path game --resolution 1280x720 res://scenes/garage/garage.tscn -- --demo --noparts --hideui \
        --view="$view" --zoom="$zoom" --shot="$OUT/$name.png" "$@" >/dev/null 2>&1
    [ -f "$OUT/$name.png" ] && break
  done
}
case " $WHAT " in *" garagem "*)
  for B in $IDS; do
    gshot "garagem_${B}_lado" side 1.0 --body="$B" --day
    gshot "garagem_${B}_34" default 1.0 --body="$B" --day
  done
  gshot "garagem_pinkbox_noite_lado" side 1.0 --body=pinkbox
  gshot "garagem_pinkbox_noite_34" default 1.0 --body=pinkbox
  for B in tarp dump; do                         # com as pecas de demonstracao (deque, viseira, para-choque...)
    timeout 120 "$GODOT" --path game --resolution 1280x720 res://scenes/garage/garage.tscn -- --demo --hideui \
        --view=default --zoom=1.0 --shot="$OUT/garagem_${B}_pecas_noite.png" --body="$B" >/dev/null 2>&1
  done ;;
esac
case " $WHAT " in *" corrida "*)
  for T in day night; do
    for B in $IDS; do
      D="$OUT/corrida_${B}_${T}"
      mkdir -p "$D"
      timeout 200 "$GODOT" --path game --rendering-method gl_compatibility --resolution 1280x720 --quit-after 420 \
          res://scenes/race/race3d.tscn -- --route=kanto_1_coast --quality=1 --no-intro --no-rain --life=off --no-events \
          --time="$T" --rival-body="$B" --autoplay --start=40 --start-speed=14 --shots="$D" --snap-every=1.5 --no-touch \
          2>&1 | grep -E "SCRIPT ERROR|Parse Error|^ERROR" | head -3
    done
  done ;;
esac
echo "capturas em $OUT"
