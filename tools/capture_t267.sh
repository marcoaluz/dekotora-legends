#!/usr/bin/env bash
# T-267: escada na quina da frente da carga (americana e Canter). Prints do jogo (janela, sem --headless) e folhas.
# Uso (Git Bash, raiz do projeto): bash tools/capture_t267.sh [prints|folhas|tudo]
# Saída: docs/capturas_t267/*.png (folhas); prints crus em builds/capturas_t267_raw/.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
WHAT="${1:-tudo}"
ROOT="$(pwd -W)"
RAW="$ROOT/builds/capturas_t267_raw"
OUT="$ROOT/docs/capturas_t267"
mkdir -p "$RAW" "$OUT"
# carga + cabine + escada (as 3 escadas se revezam)
TRUCKS=("base americana ladder_neon" "leve americana ladder_green" "longo americana ladder_chrome"
        "alubox americana ladder_green" "pinkbox americana ladder_neon" "graneleira americana ladder_chrome"
        "tarp americana ladder_neon" "dump americana ladder_green" "canter canter ladder_chrome")

batch() {
  local f="$RAW/batch.txt"
  : > "$f"
  for c in "${TRUCKS[@]}"; do
    read -r body cab lad <<< "$c"
    for v in lad_34 lad_side lad_close lad_hi; do
      echo "--body=$body --cab=$cab --parts=$lad --view=$v --out=$RAW/${body}_${cab}_${v}_dia.png" >> "$f"
    done
    for v in lad_34 lad_hi; do
      echo "--body=$body --cab=$cab --parts=$lad --view=$v --night --out=$RAW/${body}_${cab}_${v}_noite.png" >> "$f"
    done
  done
  for lad in ladder_neon ladder_green ladder_chrome; do      # as 3 escadas no Canter e na americana
    for v in lad_34 lad_hi; do
      echo "--body=canter --cab=canter --parts=$lad --view=$v --out=$RAW/modelo_${lad}_canter_${v}_dia.png" >> "$f"
      echo "--body=canter --cab=canter --parts=$lad --view=$v --night --out=$RAW/modelo_${lad}_canter_${v}_noite.png" >> "$f"
      echo "--body=base --cab=americana --parts=$lad --view=$v --out=$RAW/modelo_${lad}_americana_${v}_dia.png" >> "$f"
      echo "--body=base --cab=americana --parts=$lad --view=$v --night --out=$RAW/modelo_${lad}_americana_${v}_noite.png" >> "$f"
    done
  done
  # tanque com americana: sem escada (lateral curva); vista geral para conferir
  echo "--body=tanker --cab=americana --parts=ladder_neon --view=side --out=$RAW/tanker_americana_sem_escada.png" >> "$f"
  echo "$f"
}

shoot() {
  local f
  f="$(batch)"
  "$GODOT" --path game --resolution 640x480 -s res://tools_dev/shot_t231.gd -- --batch="$f" 2>&1 | grep -c "^SHOT" || true
}

sheet() {   # $1 = saída  $2 = colunas  resto = arquivos
  local o="$1" c="$2"
  shift 2
  "$BLENDER" -b --factory-startup -P tools/sheet_grid.py -- "$o" "$c" "$@" 2>&1 | grep "^FOLHA" || true
}

folhas() {
  local a=() b=() n=() k=()
  for c in "${TRUCKS[@]}"; do
    read -r body cab lad <<< "$c"
    a+=("$RAW/${body}_${cab}_lad_34_dia.png")
    n+=("$RAW/${body}_${cab}_lad_34_noite.png")
    b+=("$RAW/${body}_${cab}_lad_side_dia.png")
    k+=("$RAW/${body}_${cab}_lad_close_dia.png" "$RAW/${body}_${cab}_lad_hi_dia.png" "$RAW/${body}_${cab}_lad_hi_noite.png")
  done
  sheet "$OUT/cargas_dia.png" 3 "${a[@]}"
  sheet "$OUT/cargas_noite.png" 3 "${n[@]}"
  sheet "$OUT/cargas_lado.png" 3 "${b[@]}"
  sheet "$OUT/cargas_perto.png" 3 "${k[@]}"
  a=()
  for lad in ladder_neon ladder_green ladder_chrome; do
    for t in canter americana; do
      a+=("$RAW/modelo_${lad}_${t}_lad_34_dia.png" "$RAW/modelo_${lad}_${t}_lad_hi_dia.png" "$RAW/modelo_${lad}_${t}_lad_hi_noite.png")
    done
  done
  sheet "$OUT/escadas_canter_americana.png" 3 "${a[@]}"
}

case "$WHAT" in
  prints) shoot ;;
  folhas) folhas ;;
  tudo) shoot; folhas ;;
  *) echo "uso: $0 [prints|folhas|tudo]"; exit 1 ;;
esac
ls "$OUT"
