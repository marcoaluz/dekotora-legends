#!/usr/bin/env bash
# Capturas da T-266 (imagens "Praia" do Marco no grupo Wallpapers) no jogo e folhas de contato.
# Uso (raiz do projeto, Git Bash):  bash tools/capture_t266.sh [PASTA_ABS]   (padrão: docs/capturas_t266)
# Um processo Godot por vez: primeiro os prints (janela, sem --headless), depois as folhas (headless).
# Prints crus em blender/renders/t266/shots (fora do Git; caminho sem espaços: o --batch separa por espaço).
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
OUT="${1:-$(pwd -W)/docs/capturas_t266}"
RAW="${RAW:-$(pwd -W)/blender/renders/t266/shots}"
mkdir -p "$RAW" "$OUT"
BATCH="$RAW/batch.txt"
: > "$BATCH"
MURALS="wall_praia_raposa_dourada wall_praia_raposa_tropical wall_praia_amigas"
REARS="wallrear_praia_verao wallrear_praia_amigas"
ROOF="wallroof_praia_raposa"
# todos os baús com porta traseira fechada (a pintura da traseira só existe neles; a cabine não muda a traseira)
BOXES=("base chata" "leve jac" "longo curta" "alubox chata" "pinkbox chata" "canter canter" "carreta chata")
for r in $REARS; do
  for bc in "${BOXES[@]}"; do
    read -r body cab <<< "$bc"
    # de perto (fov 24) e sem para-choque de painel: as barras dele cobrem o rosto
    echo "--body=$body --cab=$cab --parts=$r --view=back --fov=24 --out=$RAW/tras_${r}_${body}_dia.png" >> "$BATCH"
    echo "--body=$body --cab=$cab --parts=$r --view=back --fov=24 --night --out=$RAW/tras_${r}_${body}_noite.png" >> "$BATCH"
  done
  echo "--body=base --cab=chata --parts=$r,rb_grand_panel,$ROOF --view=back34 --out=$RAW/tras_${r}_q_dia.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$r,rb_grand_panel,$ROOF --view=back34 --night --out=$RAW/tras_${r}_q_noite.png" >> "$BATCH"
done
for m in $MURALS; do
  echo "--body=base --cab=chata --parts=$m --view=side --out=$RAW/mural_${m}_dir.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$m --view=side_l --out=$RAW/mural_${m}_esq.png" >> "$BATCH"
  echo "--body=base --cab=chata --parts=$m --view=side --night --out=$RAW/mural_${m}_noite.png" >> "$BATCH"
  echo "--body=canter --cab=canter --parts=$m --view=side --out=$RAW/mural_${m}_canter.png" >> "$BATCH"
  echo "--body=carreta --cab=chata --parts=$m --view=side --out=$RAW/mural_${m}_carreta.png" >> "$BATCH"
done
for bc in "base chata" "leve jac" "carreta chata"; do
  read -r body cab <<< "$bc"
  echo "--body=$body --cab=$cab --parts=$ROOF,wall_praia_amigas --view=roof --out=$RAW/teto_${body}_dia.png" >> "$BATCH"
  echo "--body=$body --cab=$cab --parts=$ROOF,wall_praia_amigas --view=roof_back --night --out=$RAW/teto_${body}_noite.png" >> "$BATCH"
done
"$GODOT" --path game --resolution 640x400 -s res://tools_dev/shot_t231.gd -- --batch="$BATCH" 2>&1 | grep -c "^SHOT" || true

# garagem (loja): grupo Wallpapers aberto, peça em prévia antes de comprar (dia e noite)
garage() {   # garage ARQUIVO argumentos...
  local f="$1"
  shift
  timeout 90 "$GODOT" --path game --resolution 960x540 res://scenes/garage/garage.tscn -- --demo --paint-filter=wallpapers \
    --shot="$RAW/$f" "$@" 2>&1 | grep -E "CAPTURA|SCRIPT ERROR" || true
}
garage gar_tras_amigas_dia.png --day --preview=wallrear_praia_amigas --view=rear
garage gar_tras_verao_noite.png --preview=wallrear_praia_verao --view=rear
garage gar_mural_dia.png --day --preview=wall_praia_amigas --view=side
garage gar_teto_dia.png --day --preview=wallroof_praia_raposa --view=roof

sheet() {   # sheet SAIDA COLS LARGURA arquivos...
  local out="$1" cols="$2" w="$3"
  shift 3
  "$GODOT" --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out="$OUT/$out" --cols="$cols" --w="$w" "$@" 2>&1 \
    | grep -E "ERROR" || true
}
for r in $REARS; do
  files=()
  for bc in "${BOXES[@]}"; do
    read -r body cab <<< "$bc"
    files+=("$RAW/tras_${r}_${body}_dia.png" "$RAW/tras_${r}_${body}_noite.png")
  done
  files+=("$RAW/tras_${r}_q_dia.png" "$RAW/tras_${r}_q_noite.png")
  sheet "traseira_${r}_todos_os_baus.png" 4 400 "${files[@]}"
done
files=(); for m in $MURALS; do files+=("$RAW/mural_${m}_dir.png" "$RAW/mural_${m}_esq.png" "$RAW/mural_${m}_noite.png"); done
sheet "murais_dois_lados_e_noite.png" 3 480 "${files[@]}"
files=(); for m in $MURALS; do files+=("$RAW/mural_${m}_canter.png" "$RAW/mural_${m}_carreta.png"); done
sheet "murais_canter_e_carreta.png" 2 560 "${files[@]}"
files=(); for b in base leve carreta; do files+=("$RAW/teto_${b}_dia.png" "$RAW/teto_${b}_noite.png"); done
sheet "teto.png" 2 480 "${files[@]}"
sheet "garagem_wallpapers.png" 2 800 "$RAW/gar_tras_amigas_dia.png" "$RAW/gar_tras_verao_noite.png" \
  "$RAW/gar_mural_dia.png" "$RAW/gar_teto_dia.png"
ls "$OUT"
