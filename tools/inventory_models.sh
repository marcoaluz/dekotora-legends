#!/usr/bin/env bash
# T-186: inventario de docs/Modelos (todos os arquivos de modelo, um processo do Blender por arquivo).
# Uso (na raiz do projeto, Git Bash): bash tools/inventory_models.sh [PASTA_MODELOS] [PASTA_SAIDA]
# Grava um .json por arquivo em PASTA_SAIDA (padrao blender/renders/t186/inventory) e a lista de todos os arquivos
# (com tamanho) em PASTA_SAIDA/files.txt. Nada e alterado em docs/Modelos.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/env.sh"
SRC="${1:-$ROOT/docs/Modelos}"
OUT="${2:-$ROOT/blender/renders/t186/inventory}"
mkdir -p "$OUT"
(cd "$SRC" && find . -type f -printf '%s\t%P\n' | sort -t$'\t' -k2) > "$OUT/files.txt"
cd "$SRC"
find . -type f \( -iname '*.glb' -o -iname '*.gltf' -o -iname '*.fbx' -o -iname '*.obj' -o -iname '*.stl' \
  -o -iname '*.abc' -o -iname '*.usdz' -o -iname '*.usdc' -o -iname '*.blend' -o -iname '*.dae' -o -iname '*.3ds' \) \
  -printf '%P\n' | sort | while IFS= read -r f; do
  key="$(echo "$f" | sed 's/[^A-Za-z0-9._-]/_/g')"
  [ -s "$OUT/$key.json" ] && continue
  "$BLENDER" -b --factory-startup -P "$ROOT/blender/scripts/inventory_models.py" -- \
    --file "$SRC/$f" --out "$OUT/$key.json" 2>&1 | grep -E "INVENTORY|Error|ERRO" | head -3
done
echo "OK inventario em $OUT"
