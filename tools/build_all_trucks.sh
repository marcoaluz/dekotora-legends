#!/usr/bin/env bash
# Gera todos os caminhões 3D (T-129): 3 baús + graneleira (T-145) x 4 cabines de arquivo + Canter + carreta guardada.
# Uso (na raiz do projeto, Git Bash): source tools/env.sh && bash tools/build_all_trucks.sh [--preview]
# Precisa dos modelos originais em docs/Modelos Melhorados/ e docs/Novos modelos/ (fora do Git). ~10 min.
set -e
: "${BLENDER:?rode antes: source tools/env.sh}"
PREVIEW="--no-preview"
[ "$1" = "--preview" ] && PREVIEW=""
run() {
    echo "== $*"
    "$BLENDER" -b --factory-startup -P blender/scripts/build_truck_3d.py -- "$@" $PREVIEW 2>&1 | grep -E "^OK|ERRO|Error|cabine " || true
}
for v in base leve longo graneleira; do        # graneleira (T-145): precisa de docs/Novas Melhorias/Carroceria/
    for c in chata jac curta americana; do
        run --variant "$v" --cab "$c"
    done
done
run --variant canter
run --variant carreta
