#!/usr/bin/env bash
# Capturas da T-265 (saias laterais GRANDES, capturas 085–094) e folhas de contato.
# Uso (raiz do projeto, Git Bash; janela, sem --headless; um processo Godot por vez):
#   bash tools/capture_t265.sh rodada NOME   -> builds/capturas_t265_raw/NOME/ + comparação LOCAL com as capturas (arte de
#                                               terceiros) em docs/Referencias/oficina/t265/NOME.png (fora do Git)
#   bash tools/capture_t265.sh folhas        -> docs/capturas_t265/ (só o nosso jogo: 8 saias dia/noite, cabines e cargas
#                                               dia/noite, arcos de perto, lados, dano, LOD, cores)
#   bash tools/capture_t265.sh previas       -> game/assets/vehicles/dekotora/previews/t265_<id>_{day,night}.png
#   bash tools/capture_t265.sh tudo
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
MODE="${1:-tudo}"
ROOT_W="$(pwd -W)"
RAWB="$ROOT_W/builds/capturas_t265_raw"
REF="docs/Referencias/oficina/img"
PARTS="skirt_chrome_rails skirt_neon_twin skirt_neon_diamond skirt_neon_dash skirt_neon_arch skirt_neon_green skirt_neon_gems skirt_neon_arrows"
CAPS=(086 088 089 090 091 092 093 094)
# caminhões (carga cabine peça): todas as cabines e as cargas diferentes
TRUCKS=("base chata skirt_neon_arch" "base jac skirt_neon_twin" "base curta skirt_neon_dash" "base americana skirt_neon_gems"
        "base flat_wide skirt_neon_arrows" "base flat_quad skirt_neon_green" "canter canter skirt_neon_diamond"
        "leve chata skirt_neon_arrows" "longo curta skirt_chrome_rails" "graneleira jac skirt_neon_arch"
        "alubox americana skirt_neon_gems" "pinkbox flat_quad skirt_neon_twin" "tanker chata skirt_neon_dash"
        "dump curta skirt_neon_arrows" "tarp jac skirt_neon_green")

shots() {   # $1 = arquivo batch, $2 = resolução
  "$GODOT" --path game --resolution "${2:-960x540}" -s res://tools_dev/shot_t231.gd -- --batch="$1" 2>&1 | grep -c "^SHOT" || true
}

sheet() {   # $1 = saída, $2 = colunas, $3 = largura da célula, resto = imagens
  "$BLENDER" -b --factory-startup -P tools/sheet_t264.py -- "$@" 2>&1 | grep -E "FOLHA|Error" || true
}

rodada() {
  local name="${1:-r1}"
  local R="$RAWB/$name"
  mkdir -p "$R" docs/Referencias/oficina/t265
  : > "$R/batch.txt"
  for p in $PARTS; do
    echo "--body=base --cab=chata --parts=$p --view=sk_ref --out=$R/${p}_ref.png" >> "$R/batch.txt"
    echo "--body=base --cab=chata --parts=$p --view=sk_ref --night --out=$R/${p}_ref_noite.png" >> "$R/batch.txt"
  done
  shots "$R/batch.txt"
  local files=()
  local i=0
  for p in $PARTS; do
    files+=("$REF/${CAPS[$i]}.png" "$R/${p}_ref.png" "$R/${p}_ref_noite.png")
    i=$((i + 1))
  done
  sheet "docs/Referencias/oficina/t265/$name.png" 3 520 "${files[@]}"
}

folhas() {
  local R="$RAWB/folhas"
  local OUT="docs/capturas_t265"
  mkdir -p "$R" "$OUT"
  : > "$R/batch.txt"
  for p in $PARTS; do
    echo "--body=base --cab=chata --parts=$p --view=sk_ref --out=$R/peca_${p}_dia.png" >> "$R/batch.txt"
    echo "--body=base --cab=chata --parts=$p --view=sk_ref --night --out=$R/peca_${p}_noite.png" >> "$R/batch.txt"
    echo "--body=base --cab=chata --parts=$p --view=sk_arch --night --out=$R/arco_${p}_noite.png" >> "$R/batch.txt"
  done
  for t in "${TRUCKS[@]}"; do
    read -r body cab p <<< "$t"
    echo "--body=$body --cab=$cab --parts=$p --view=sk_side --out=$R/cam_${body}_${cab}_dia.png" >> "$R/batch.txt"
    echo "--body=$body --cab=$cab --parts=$p --view=sk_side --night --out=$R/cam_${body}_${cab}_noite.png" >> "$R/batch.txt"
    echo "--body=$body --cab=$cab --parts=$p --view=sk_arch --out=$R/perto_${body}_${cab}_dia.png" >> "$R/batch.txt"
  done
  # lados: direito/esquerdo, frente (tanque), atrás da roda de trás, bem baixo
  for v in sk_side sk_left sk_front sk_arch sk_low; do
    echo "--body=base --cab=chata --parts=skirt_neon_arch --view=$v --out=$R/lado_${v}_dia.png" >> "$R/batch.txt"
    echo "--body=base --cab=chata --parts=skirt_neon_arch --view=$v --night --out=$R/lado_${v}_noite.png" >> "$R/batch.txt"
  done
  echo "--body=base --cab=chata --parts=skirt_neon_gems --view=sk_arch --night --out=$R/dano_inteira.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=skirt_neon_gems --state=skirt_neon_gems:broken --view=sk_arch --night --out=$R/dano_quebrada.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=skirt_neon_gems --state=skirt_neon_gems:dent --view=sk_arch --out=$R/dano_amassada.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=skirt_neon_gems --view=sk_far --fov=12 --night --out=$R/lod_longe.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=skirt_neon_twin --color=skirt_neon_twin:prata_marinho --view=sk_ref --out=$R/cor_twin_prata.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=skirt_neon_twin --neon=skirt_neon_twin:rosa --view=sk_ref --night --out=$R/cor_twin_rosa.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=skirt_neon_green --led=skirt_neon_green:amarelo --neon=skirt_neon_green:violeta --view=sk_ref --night --out=$R/cor_green_led.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=skirt_chrome_rails --color=skirt_chrome_rails:dourado_ambar --view=sk_ref --out=$R/cor_rails_dourado.png" >> "$R/batch.txt"
  shots "$R/batch.txt"
  local f=()
  for p in $PARTS; do f+=("$R/peca_${p}_dia.png" "$R/peca_${p}_noite.png"); done
  sheet "$OUT/folha_saias.png" 2 640 "${f[@]}"
  local a=()
  for p in $PARTS; do a+=("$R/arco_${p}_noite.png"); done
  sheet "$OUT/folha_arcos_noite.png" 2 640 "${a[@]}"
  local d=() n=() c=()
  for t in "${TRUCKS[@]}"; do
    read -r body cab p <<< "$t"
    d+=("$R/cam_${body}_${cab}_dia.png"); n+=("$R/cam_${body}_${cab}_noite.png"); c+=("$R/perto_${body}_${cab}_dia.png")
  done
  sheet "$OUT/folha_caminhoes_dia.png" 3 640 "${d[@]}"
  sheet "$OUT/folha_caminhoes_noite.png" 3 640 "${n[@]}"
  sheet "$OUT/folha_caminhoes_perto.png" 3 640 "${c[@]}"
  local l=()
  for v in sk_side sk_left sk_front sk_arch sk_low; do l+=("$R/lado_${v}_dia.png" "$R/lado_${v}_noite.png"); done
  sheet "$OUT/folha_lados.png" 2 640 "${l[@]}"
  sheet "$OUT/folha_dano_lod.png" 2 640 "$R/dano_inteira.png" "$R/dano_quebrada.png" "$R/dano_amassada.png" "$R/lod_longe.png"
  sheet "$OUT/folha_cores.png" 2 640 "$R/cor_twin_prata.png" "$R/cor_twin_rosa.png" "$R/cor_green_led.png" "$R/cor_rails_dourado.png"
}

previas() {
  local R="$RAWB/previas"
  local P="$ROOT_W/game/assets/vehicles/dekotora/previews"
  mkdir -p "$R"
  : > "$R/batch.txt"
  for p in $PARTS; do
    echo "--body=base --cab=chata --parts=$p --view=sk_arch --out=$P/t265_${p}_day.png" >> "$R/batch.txt"
    echo "--body=base --cab=chata --parts=$p --view=sk_arch --night --out=$P/t265_${p}_night.png" >> "$R/batch.txt"
  done
  shots "$R/batch.txt" 640x420
}

case "$MODE" in
  rodada) rodada "${2:-r1}" ;;
  folhas) folhas ;;
  previas) previas ;;
  tudo) rodada final; folhas; previas ;;
  *) echo "uso: $0 rodada NOME | folhas | previas | tudo"; exit 1 ;;
esac
