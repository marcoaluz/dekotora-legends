#!/usr/bin/env bash
# T-217: importa texturas novas de cenario 3D com as opcoes certas (sem isso viram "grao" a distancia, T-199):
# compressao VRAM (mode=2) + mipmaps; arquivos *_nrm* / *_normal* como mapa de normais.
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/import_textures_3d.sh [PASTA_res=game/assets/textures/t217 ...]
#   Ex.: depois de colocar as texturas CC0 do Marco: bash tools/import_textures_3d.sh game/assets/textures/cc0/t217
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
DIRS=("$@")
[ ${#DIRS[@]} -eq 0 ] && DIRS=(game/assets/textures/t217)
"$GODOT" --headless --path game --import > /dev/null 2>&1
changed=0
for D in "${DIRS[@]}"; do
  for f in "$D"/*.png.import "$D"/*.jpg.import "$D"/*.jpeg.import "$D"/*.webp.import; do
    [ -f "$f" ] || continue
    before="$(cat "$f")"
    sed -i -e 's/^compress\/mode=.*/compress\/mode=2/' -e 's/^mipmaps\/generate=.*/mipmaps\/generate=true/' \
        -e 's/^detect_3d\/compress_to=.*/detect_3d\/compress_to=0/' "$f"
    case "$f" in
      *_nrm*|*_normal*|*_nor_gl*) sed -i -e 's/^compress\/normal_map=.*/compress\/normal_map=1/' "$f" ;;
    esac
    [ "$before" != "$(cat "$f")" ] && changed=$((changed + 1))
  done
done
if [ $changed -gt 0 ]; then
  for D in "${DIRS[@]}"; do
    for f in "$D"/*.import; do
      [ -f "$f" ] || continue
      grep -o 'res://.godot/imported/[^"]*' "$f" | sed 's#res://#game/#' | xargs -r rm -f
    done
  done
  "$GODOT" --headless --path game --import > /dev/null 2>&1
fi
echo "texturas 3D conferidas: $changed arquivo(s) .import ajustado(s) em ${DIRS[*]}"
