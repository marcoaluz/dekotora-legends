#!/usr/bin/env bash
# Capturas da T-264 (para-choques GRANDES da frente, capturas 054–062) e folhas de contato.
# Uso (raiz do projeto, Git Bash; janela, sem --headless; um processo Godot por vez):
#   bash tools/capture_t264.sh rodada NOME     -> builds/capturas_t264_raw/NOME/ + comparação LOCAL (arte de terceiros) em
#                                                 docs/Referencias/oficina/t264/NOME.png (fora do Git)
#   bash tools/capture_t264.sh folhas          -> docs/capturas_t264/ (só o nosso jogo: peças dia/noite, 5 cabines com
#                                                 os mais altos de frente/lado/topo, todas as cabines, dano, LOD)
#   bash tools/capture_t264.sh tudo
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
MODE="${1:-tudo}"
ROOT_W="$(pwd -W)"
RAWB="$ROOT_W/builds/capturas_t264_raw"
REF="docs/Referencias/oficina/img"
PARTS="fb_wrap_lamps fb_wrap_tower fb_wrap_chrome fb_wrap_deck4 fb_wrap_deck_wide"
CAPS=(055 057 058 060 062)
CABS="chata jac curta americana flat_wide flat_quad"

shots() {   # $1 = arquivo batch
  "$GODOT" --path game --resolution 900x420 -s res://tools_dev/shot_t231.gd -- --batch="$1" 2>&1 | grep -c "^SHOT" || true
}

sheet() {   # $1 = saída, $2 = colunas, $3 = largura da célula, resto = imagens
  "$BLENDER" -b --factory-startup -P tools/sheet_t264.py -- "$@" 2>&1 | grep -E "FOLHA|Error" || true
}

rodada() {
  local name="${1:-r1}"
  local R="$RAWB/$name"
  mkdir -p "$R" docs/Referencias/oficina/t264
  : > "$R/batch.txt"
  for p in $PARTS; do
    echo "--body=base --cab=chata --parts=$p --view=fb_ref --out=$R/${p}_ref.png" >> "$R/batch.txt"
    echo "--body=base --cab=chata --parts=$p --view=fb_ref --night --out=$R/${p}_ref_noite.png" >> "$R/batch.txt"
    echo "--body=base --cab=chata --parts=$p --view=fb_top --out=$R/${p}_top.png" >> "$R/batch.txt"
  done
  shots "$R/batch.txt"
  local files=()
  local i=0
  for p in $PARTS; do
    files+=("$REF/${CAPS[$i]}.png" "$R/${p}_ref.png" "$R/${p}_ref_noite.png" "$R/${p}_top.png")
    i=$((i + 1))
  done
  sheet "docs/Referencias/oficina/t264/$name.png" 4 420 "${files[@]}"
}

folhas() {
  local R="$RAWB/folhas"
  local OUT="docs/capturas_t264"
  mkdir -p "$R" "$OUT"
  : > "$R/batch.txt"
  for p in $PARTS; do
    echo "--body=base --cab=chata --parts=$p --view=fb_ref --out=$R/peca_${p}_dia.png" >> "$R/batch.txt"
    echo "--body=base --cab=chata --parts=$p --view=fb_ref --night --out=$R/peca_${p}_noite.png" >> "$R/batch.txt"
  done
  # 5 cabines com os para-choques mais altos (deque largo, caixa de painéis, torre, cromado, deque de 4): frente, lado, topo
  local tall=("base chata fb_wrap_lamps" "base jac fb_wrap_tower" "base americana fb_wrap_chrome" "canter canter fb_wrap_deck_wide" "base curta fb_wrap_deck4")
  for t in "${tall[@]}"; do
    read -r body cab p <<< "$t"
    for v in fb_front fb_side fb_top fb_ref; do
      echo "--body=$body --cab=$cab --parts=$p --view=$v --out=$R/alto_${cab}_${v}.png" >> "$R/batch.txt"
    done
  done
  for c in $CABS; do
    echo "--body=base --cab=$c --parts=fb_wrap_deck_wide --view=fb_ref --night --out=$R/cabine_${c}.png" >> "$R/batch.txt"
  done
  echo "--body=canter --cab=canter --parts=fb_wrap_deck_wide --view=fb_ref --night --out=$R/cabine_canter.png" >> "$R/batch.txt"
  echo "--body=pinkbox --cab=flat_quad --parts=fb_wrap_deck_wide --view=fb_ref --night --out=$R/cabine_pinkbox_flat_quad.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=fb_wrap_deck4 --view=fb_ref --night --out=$R/dano_inteira.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=fb_wrap_deck4 --state=fb_wrap_deck4:broken --view=fb_ref --night --out=$R/dano_quebrada.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=fb_wrap_deck4 --state=fb_wrap_deck4:dent --view=fb_ref --out=$R/dano_amassada.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=fb_wrap_lamps --color=fb_wrap_lamps:prata_marinho --view=fb_ref --out=$R/cor_lamps_prata.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=fb_wrap_tower --color=fb_wrap_tower:preto_ciano --view=fb_ref --night --out=$R/cor_tower_preto.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=fb_wrap_deck4 --color=fb_wrap_deck4:prata_marinho --view=fb_ref --out=$R/cor_deck4_prata.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=fb_wrap_deck_wide --color=fb_wrap_deck_wide:preto_ciano --neon=fb_wrap_deck_wide:rosa --view=fb_ref --night --out=$R/cor_deckwide_rosa.png" >> "$R/batch.txt"
  echo "--body=base --cab=chata --parts=fb_wrap_deck_wide --view=front --out=$R/lod_perto.png" >> "$R/batch.txt"
  shots "$R/batch.txt"
  local f=()
  for p in $PARTS; do f+=("$R/peca_${p}_dia.png" "$R/peca_${p}_noite.png"); done
  sheet "$OUT/folha_parachoques.png" 2 640 "${f[@]}"
  for t in "${tall[@]}"; do
    read -r body cab p <<< "$t"
    sheet "$OUT/alto_${cab}.png" 2 640 "$R/alto_${cab}_fb_front.png" "$R/alto_${cab}_fb_side.png" "$R/alto_${cab}_fb_top.png" "$R/alto_${cab}_fb_ref.png"
  done
  local c=()
  for cb in $CABS canter pinkbox_flat_quad; do c+=("$R/cabine_${cb}.png"); done
  sheet "$OUT/folha_cabines.png" 2 640 "${c[@]}"
  sheet "$OUT/folha_dano.png" 3 640 "$R/dano_inteira.png" "$R/dano_quebrada.png" "$R/dano_amassada.png"   # (o --ghost deixa a placa solta no ar: so ferramenta)
  sheet "$OUT/folha_cores.png" 2 640 "$R/cor_lamps_prata.png" "$R/cor_tower_preto.png" "$R/cor_deck4_prata.png" "$R/cor_deckwide_rosa.png"
}

case "$MODE" in
  rodada) rodada "${2:-r1}" ;;
  folhas) folhas ;;
  tudo) rodada final; folhas ;;
  *) echo "uso: $0 rodada NOME | folhas | tudo"; exit 1 ;;
esac
