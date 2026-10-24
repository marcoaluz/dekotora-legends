#!/usr/bin/env bash
# Capturas da T-211 (deque frontal + viseira): o caminhão "mais exagerado" (peças de demonstração + deque e viseira
# novos) na garagem, de frente, de lado, de trás, de cima e 3/4 do teto, de noite e de dia; e a frente de cada
# cabine com o deque e a viseira. Precisa de janela (não use --headless).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/capture_t211.sh PASTA_ABSOLUTA [DEQUE] [VISEIRA]
: "${GODOT:?defina GODOT (tools/env.sh)}"
OUT="${1:?pasta de saida (caminho absoluto)}"
DECK="${2:-deck_painted_wings}"
VISOR="${3:-visor_v_chevron}"
mkdir -p "$OUT"
shot() {   # nome vista zoom [extras...]
  local name="$1" view="$2" zoom="$3"
  shift 3
  for try in 1 2; do
    "$GODOT" --path game --resolution 1280x720 res://scenes/garage/garage.tscn -- --demo --hideui --view="$view" \
        --zoom="$zoom" --shot="$OUT/$name.png" --parts="$DECK,$VISOR" "$@" >/dev/null 2>&1
    [ -f "$OUT/$name.png" ] && break
  done
}
for T in noite dia; do
  extra=""; [ "$T" = dia ] && extra="--day"
  shot "exagerado_${T}_frente" front 0.9 --body=base --cab=chata $extra
  shot "exagerado_${T}_lado" side 1.0 --body=base --cab=chata $extra
  shot "exagerado_${T}_tras" rear 1.0 --body=base --cab=chata $extra
  shot "exagerado_${T}_topo" top 1.0 --body=base --cab=chata $extra
  shot "exagerado_${T}_teto" roof 0.8 --body=base --cab=chata $extra
done
for C in jac curta americana; do
  shot "cabine_${C}_frente" front 0.9 --body=base --cab="$C"
done
shot "cabine_canter_frente" front 0.9 --body=canter
echo "capturas em $OUT"
