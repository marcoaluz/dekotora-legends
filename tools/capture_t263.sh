#!/usr/bin/env bash
# Capturas da T-263 (retrovisor colado na lataria em todas as cabines; escada na lateral da cabine, ao lado da porta,
# passando do teto com a caixa de LED e estribo embaixo, como nas capturas 111-113 — correção do Marco)
# e folhas de contato. Uso (raiz do projeto, Git Bash):  bash tools/capture_t263.sh [antes|depois|folhas|tudo]
# "antes" usa ANTES_GAME (padrão ../t263_antes/game, worktree do commit a0e82b2 com o cache .godot copiado e --import).
# Brutos em builds/capturas_t263_raw/ (fora do Git); folhas em docs/capturas_t263/. Um processo Godot por vez (janela).
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
WHAT="${1:-tudo}"
ROOT="$(pwd -W)"
RAW="$ROOT/builds/capturas_t263_raw"
OUT="$ROOT/docs/capturas_t263"
ANTES_GAME="${ANTES_GAME:-../t263_antes/game}"
mkdir -p "$RAW" "$OUT"
CABS=("base chata mirror_stay_l" "base jac mirror_stay_truss" "base curta mirror_stay_frame" "base americana mirror_stay_box"
      "canter canter mirror_stay_chain" "base flat_wide mirror_stay_grand" "pinkbox flat_quad mirror_stay_frame")
STAYS="mirror_stay_l mirror_stay_truss mirror_stay_frame mirror_stay_box mirror_stay_chain mirror_stay_grand"
LADDER_TRUCKS=("base chata ladder_neon" "base jac ladder_green" "base curta ladder_chrome" "base flat_wide ladder_neon"
      "graneleira chata ladder_green" "alubox jac ladder_chrome" "pinkbox flat_wide ladder_neon" "leve flat_quad ladder_green"
      "tanker curta ladder_chrome")

batch() {   # $1 = antes|depois
  local tag="$1" f="$RAW/$1_batch.txt"
  : > "$f"
  for c in "${CABS[@]}"; do
    read -r body cab stay <<< "$c"
    for v in mirror_front mirror_side mirror_top mirror_back; do
      echo "--body=$body --cab=$cab --parts=$stay --view=$v --out=$RAW/${tag}_cab_${cab}_${v}_dia.png" >> "$f"
    done
    for v in mirror_front mirror_back; do
      echo "--body=$body --cab=$cab --parts=$stay --view=$v --night --out=$RAW/${tag}_cab_${cab}_${v}_noite.png" >> "$f"
    done
  done
  for p in $STAYS; do
    echo "--body=base --cab=chata --parts=$p --view=mirror_root --out=$RAW/${tag}_haste_${p}_raiz.png" >> "$f"
    echo "--body=base --cab=chata --parts=$p --view=mirror_close --out=$RAW/${tag}_haste_${p}_dia.png" >> "$f"
    echo "--body=base --cab=chata --parts=$p --view=mirror_close --night --out=$RAW/${tag}_haste_${p}_noite.png" >> "$f"
  done
  for c in "${LADDER_TRUCKS[@]}"; do
    read -r body cab lad <<< "$c"
    echo "--body=$body --cab=$cab --parts=$lad --view=ladder_ref --out=$RAW/${tag}_escada_${body}_${cab}_dia.png" >> "$f"
    echo "--body=$body --cab=$cab --parts=$lad --view=lad_close --out=$RAW/${tag}_escada_${body}_${cab}_perto.png" >> "$f"
    echo "--body=$body --cab=$cab --parts=$lad --view=ladder_ref --night --out=$RAW/${tag}_escada_${body}_${cab}_noite.png" >> "$f"
  done
  for lad in ladder_neon ladder_green ladder_chrome; do
    for v in ladder_ref lad_close lad_hi lad_gap lad_back; do
      echo "--body=alubox --cab=jac --parts=$lad --view=$v --out=$RAW/${tag}_modelo_${lad}_${v}_dia.png" >> "$f"
    done
    echo "--body=alubox --cab=jac --parts=$lad --view=ladder_ref --night --out=$RAW/${tag}_modelo_${lad}_ladder_ref_noite.png" >> "$f"
    echo "--body=base --cab=chata --parts=$lad --view=lad_close --out=$RAW/${tag}_modelo_${lad}_base_chata_close.png" >> "$f"
  done
  echo "$f"
}

shoot() {   # $1 = antes|depois  $2 = pasta game
  local f
  f="$(batch "$1")"
  "$GODOT" --path "$2" --resolution 640x480 -s res://tools_dev/shot_t231.gd -- --batch="$f" 2>&1 | grep -c "^SHOT" || true
}

sheet() {   # $1 = saída  $2 = colunas  resto = arquivos
  local o="$1" c="$2"
  shift 2
  "$BLENDER" -b --factory-startup -P tools/sheet_grid.py -- "$o" "$c" "$@" 2>&1 | grep "^FOLHA" || true
}

folhas() {
  local a=()
  for c in "${CABS[@]}"; do
    read -r body cab stay <<< "$c"
    a=()
    for v in mirror_front_dia mirror_side_dia mirror_top_dia mirror_back_dia mirror_front_noite mirror_back_noite; do
      a+=("$RAW/depois_cab_${cab}_${v}.png")
    done
    sheet "$OUT/retrovisor_${cab}.png" 3 "${a[@]}"
  done
  a=()
  for c in "${CABS[@]}"; do
    read -r body cab stay <<< "$c"
    a+=("$RAW/antes_cab_${cab}_mirror_back_dia.png" "$RAW/depois_cab_${cab}_mirror_back_dia.png"
        "$RAW/antes_cab_${cab}_mirror_top_dia.png" "$RAW/depois_cab_${cab}_mirror_top_dia.png")
  done
  sheet "$OUT/retrovisor_antes_depois.png" 4 "${a[@]}"
  a=()
  for p in $STAYS; do
    a+=("$RAW/depois_haste_${p}_dia.png" "$RAW/depois_haste_${p}_noite.png" "$RAW/antes_haste_${p}_raiz.png" "$RAW/depois_haste_${p}_raiz.png")
  done
  sheet "$OUT/retrovisor_6_hastes.png" 4 "${a[@]}"
  a=()
  for c in "${LADDER_TRUCKS[@]}"; do
    read -r body cab lad <<< "$c"
    a+=("$RAW/antes_escada_${body}_${cab}_dia.png" "$RAW/depois_escada_${body}_${cab}_dia.png" "$RAW/depois_escada_${body}_${cab}_perto.png" "$RAW/depois_escada_${body}_${cab}_noite.png")
  done
  sheet "$OUT/escada_antes_depois.png" 4 "${a[@]}"
  a=()
  for lad in ladder_neon ladder_green ladder_chrome; do
    for v in ladder_ref_noite lad_close_dia lad_hi_dia lad_gap_dia lad_back_dia; do
      a+=("$RAW/depois_modelo_${lad}_${v}.png")
    done
  done
  sheet "$OUT/escada_3_modelos.png" 5 "${a[@]}"
  # "referência x resultado" para o Git: só prints nossos, no ângulo das capturas 111–113 (de frente-direita, alto);
  # a comparação lado a lado com as capturas do jogo original fica só local (docs/Referencias/oficina/t263/)
  sheet "$OUT/escada_referencia_x_resultado.png" 3 "$RAW/depois_modelo_ladder_neon_ladder_ref_dia.png"     "$RAW/depois_modelo_ladder_green_ladder_ref_dia.png" "$RAW/depois_modelo_ladder_chrome_ladder_ref_dia.png"     "$RAW/depois_modelo_ladder_neon_ladder_ref_noite.png" "$RAW/depois_modelo_ladder_green_ladder_ref_noite.png"     "$RAW/depois_modelo_ladder_chrome_ladder_ref_noite.png"
  # referência (capturas 111-113, arte de terceiros) x resultado em 6 cabines, SÓ LOCAL (pasta fora do Git):
  # cada linha = referência | dia | perto | noite
  local REF="$ROOT/docs/Referencias/oficina/img"
  a=()
  local k=0
  for c in "base chata ladder_neon" "base jac ladder_green" "base curta ladder_chrome" "base flat_wide ladder_neon"            "pinkbox flat_wide ladder_neon" "tanker curta ladder_chrome"; do
    read -r body cab lad <<< "$c"
    case "$lad" in ladder_neon) r=111 ;; ladder_green) r=112 ;; *) r=113 ;; esac
    a+=("$REF/$r.png" "$RAW/depois_escada_${body}_${cab}_dia.png" "$RAW/depois_escada_${body}_${cab}_perto.png" "$RAW/depois_escada_${body}_${cab}_noite.png")
  done
  "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$ROOT/docs/Referencias/oficina/t263/referencia_x_resultado_escada_cabines.png" --cols=4 --w=480 "${a[@]}" | tail -1
}

case "$WHAT" in
  antes) shoot antes "$ANTES_GAME" ;;
  depois) shoot depois game ;;
  folhas) folhas ;;
  tudo) shoot antes "$ANTES_GAME"; shoot depois game; folhas ;;
esac
