#!/usr/bin/env bash
# Baú premium (T-136): grava os mapas (bake, ~3-4 min) e regera o baú médio com as 4 cabines.
# Uso (raiz do projeto, Git Bash): source tools/env.sh && bash tools/build_box_premium.sh [--no-bake] [--src PASTA_RAIZ]
#   --no-bake  pula a gravação (usa os tex_box_*.png que já estão em game/assets/vehicles/dekotora/textures/)
#   --src      raiz onde estão docs/Modelos/Novos modelos/ e docs/Modelos/Modelos Melhorados/ (fora do Git; padrão: este projeto;
#              se a pasta nova não existir, usa docs/Novos modelos/ e docs/Modelos Melhorados/)
# Depois: godot --headless --path game --import  (reimporta os .glb e as texturas)
set -e
: "${BLENDER:?rode antes: source tools/env.sh}"
BAKE=1
SRC="$(pwd)"
while [ $# -gt 0 ]; do
    case "$1" in
        --no-bake) BAKE=0 ;;
        --src) SRC="$2"; shift ;;
    esac
    shift
done
if [ "$BAKE" = 1 ]; then
    "$BLENDER" -b --factory-startup -P blender/scripts/bake_box_premium.py -- 2>&1 | grep -E "^OK|alta:|  box|ERRO|Error" || true
fi
# T-162: pastas novas em docs/Modelos/; volta para docs/<pasta> antiga se a nova não existir
NOVOS="$SRC/docs/Modelos/Novos modelos"
[ -d "$NOVOS" ] || NOVOS="$SRC/docs/Novos modelos"
MELHORADOS="$SRC/docs/Modelos/Modelos Melhorados"
[ -d "$MELHORADOS" ] || MELHORADOS="$SRC/docs/Modelos Melhorados"
run() {
    echo "== $*"
    "$BLENDER" -b --factory-startup -P blender/scripts/build_truck_3d.py -- --variant base --no-preview "$@" 2>&1 \
        | grep -E "^OK|ERRO|Error|cabine |triangulos:" || true
}
run --cab chata --cab-src "$NOVOS/Cabine/CF_500_complete.stl"
run --cab jac --cab-src "$MELHORADOS/JAC+1045+Truck.blend"
run --cab curta --cab-src "$MELHORADOS/JAC+1045+Truck.blend"
run --cab americana --cab-src "$MELHORADOS/kenworth_w990_truck.glb"
