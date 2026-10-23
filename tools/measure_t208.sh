#!/usr/bin/env bash
# T-208: tempo do clique em Continuar ate o 1o quadro da abertura do duelo e os picos dos primeiros quadros, no PC
# imitando o celular (Compatibility, qualidade media, sem vida do cenario, janela 1280x576 = proporcao do celular).
#   frio   = sem o cache de shaders do Godot (como a 1a corrida depois de instalar o APK);
#   quente = com o cache (2a corrida em diante).
# Caminho de verdade: abre o menu (perfil de teste), espera WAIT s e chama Continuar (tools_dev/measure_load_t208.gd).
#   MODE=goto  -> como antes da T-208: abre a corrida direto (--goto, sem o menu e sem a leitura em segundo plano)
#   EXTRA="--no-prefetch" -> sem a leitura da corrida em segundo plano no menu
# O cache original e guardado e devolvido no fim (nada e apagado).
# Uso (raiz do projeto, Git Bash): GODOT=... bash tools/measure_t208.sh [frio|quente|ambos]
: "${GODOT:?defina GODOT (tools/env.sh)}"
WHICH="${1:-ambos}"
WAIT="${WAIT:-3}"
CACHE="$APPDATA/Godot/app_userdata/Kaido Bakuso/shader_cache"
BAK="$CACHE.t208bak"
COMMON="--quality=1 --life=off"
run() {
  if [ "${MODE:-menu}" = "goto" ]; then
    # shellcheck disable=SC2086
    "$GODOT" --path game --rendering-method gl_compatibility --resolution 1280x576 --quit-after 1100 -- \
        --goto=res://scenes/race/race3d.tscn $COMMON --decorated --route=kanto_1_coast --intro=full $EXTRA 2>&1 \
        | grep -E "LOAD_T208|ABERTURA|SCRIPT ERROR" | head -60 || true
  else
    # shellcheck disable=SC2086
    "$GODOT" --path game --rendering-method gl_compatibility --resolution 1280x576 -s res://tools_dev/measure_load_t208.gd -- \
        --wait="$WAIT" --quit-at=24 $COMMON $EXTRA 2>&1 \
        | grep -E "LOAD_T208|ABERTURA|MEASURE_T208|SCRIPT ERROR" | head -60 || true
  fi
}
if [ "$WHICH" != "quente" ]; then
  if [ -d "$CACHE" ] && [ ! -d "$BAK" ]; then mv "$CACHE" "$BAK"; fi
  echo "== FRIO (sem cache de shaders) MODE=${MODE:-menu} $EXTRA"
  run
fi
if [ "$WHICH" != "frio" ]; then
  echo "== QUENTE (com cache) MODE=${MODE:-menu} $EXTRA"
  run
fi
if [ -d "$BAK" ]; then rm -rf "${CACHE:?}"; mv "$BAK" "$CACHE"; fi
