#!/usr/bin/env bash
# Mede a corrida no modo MEDIO nas 3 rotas (T-146: barreiras, placas, porticos e paineis): chamadas de desenho,
# triangulos, memoria de textura e FPS (media a cada 5 s), com o caminhao andando sozinho pelo mesmo trecho.
# Uso (raiz do projeto, Git Bash): source tools/env.sh && bash tools/measure_roadside.sh [QUADROS] [extra...]
#   QUADROS padrao 2400 (~10 s sem vsync). Os argumentos extras vao para o jogo (ex.: --no-kit para comparar).
: "${GODOT:?rode antes: source tools/env.sh}"
FRAMES="${1:-2400}"
shift || true
for ROUTE in kanto_1_coast kanto_2_viaduct kanto_3_mountain; do
  echo "== $ROUTE $*"
  "$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after "$FRAMES" res://scenes/race/race3d.tscn -- \
      --fps-log --quality=1 --route="$ROUTE" --start=300 --start-speed=22 --autoplay "$@" \
      2>&1 | grep -E "FPS medio|SUPERFICIES|SCRIPT ERROR|Parse Error|KIT:" || true
done
