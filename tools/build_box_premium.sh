#!/usr/bin/env bash
# Baú premium (T-136): grava os mapas (bake, ~3-4 min) e regera o baú médio com as 4 cabines.
# Uso (raiz do projeto, Git Bash): source tools/env.sh && bash tools/build_box_premium.sh [--no-bake] [--src PASTA_RAIZ]
#   --no-bake  pula a gravação (usa os tex_box_*.png que já estão em game/assets/vehicles/dekotora/textures/)
#   --src      raiz onde estão docs/Novos modelos/ e docs/Modelos Melhorados/ (fora do Git; padrão: este projeto)
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
run() {
    echo "== $*"
    "$BLENDER" -b --factory-startup -P blender/scripts/build_truck_3d.py -- --variant base --no-preview "$@" 2>&1 \
        | grep -E "^OK|ERRO|Error|cabine |triangulos:" || true
}
run --cab chata --cab-src "$SRC/docs/Novos modelos/Cabine/CF_500_complete.stl"
run --cab jac --cab-src "$SRC/docs/Modelos Melhorados/JAC+1045+Truck.blend"
run --cab curta --cab-src "$SRC/docs/Modelos Melhorados/JAC+1045+Truck.blend"
run --cab americana --cab-src "$SRC/docs/Modelos Melhorados/kenworth_w990_truck.glb"
