#!/usr/bin/env bash
# T-218/T-240: gera os kits de cabine e carroceria (LOD0/1/2) dos 5 caminhões de homenagem, mede os encaixes, importa no Godot e refaz a tabela do deque
# de 2 níveis. UM processo por vez (memória). Uso (raiz do projeto, Git Bash):
#   source tools/env.sh && bash tools/build_t218.sh [PASTA_ABS_DAS_PREVIAS]
# Com a pasta: também gera as prévias (frente, lateral, traseira, 3/4, dia e noite) e as folhas de contato.
set -e
: "${BLENDER:?rode antes: source tools/env.sh}"
: "${GODOT:?rode antes: source tools/env.sh}"
IDS="alubox,tarp,pinkbox,tanker,dump"
PREV=()
[ -n "$1" ] && PREV=(--preview "$1" --night)
if [ ${#PREV[@]} -gt 0 ]; then
  echo "== previas (o .glb unico de cada um fica so nas previas; o jogo usa o kit desde a T-240)"
  "$BLENDER" -b --factory-startup -P blender/scripts/build_t218_trucks.py -- --out "$(pwd)/builds/t218_glb" "${PREV[@]}" 2>&1 | grep -E "^\[t218\]|^OK|ERRO|Error|Trace" || true
fi
echo "== kits: cabines + carrocerias (T-240)"
"$BLENDER" -b --factory-startup -P blender/scripts/build_t240_kits.py -- --bodies "$IDS,base,leve,longo,graneleira" 2>&1 | grep -E "^\[t240\]|^OK|ERRO|Error|Trace" || true
echo "== encaixes (todos os caminhoes; as combinacoes do kit entram sozinhas)"
"$BLENDER" -b --factory-startup -P blender/scripts/build_sockets.py 2>&1 | grep -E "PROBLEMA|^OK|ERRO" || true
echo "== importar"
timeout 900 "$GODOT" --headless --path game --import 2>&1 | grep -iE "^ERROR" | head -5 || true
echo "== deque de 2 niveis"
timeout 1500 "$GODOT" --headless --path game -s res://tools_dev/gen_stack_fit.gd 2>&1 | grep -E "alubox|tarp|pinkbox|tanker|dump|^OK" || true
