#!/usr/bin/env bash
# Mede a corrida no modo MÉDIO (T-136): chamadas de desenho, triângulos, memória de textura/vídeo e FPS (média a cada 5 s).
# Uso (raiz do projeto, Git Bash): source tools/env.sh && bash tools/measure_box.sh [ROTA] [HORA] [CABINE] [MODELO]
#   padrão: kanto_2_viaduct night chata base. O caminhão é o de fábrica (branco, sem peças), com rivais e trânsito.
#   Sem vsync (o FPS passa de 75 e mostra a folga); 8000 quadros (~30–40 s no PC do Marco).
set -e
: "${GODOT:?rode antes: source tools/env.sh}"
ROUTE="${1:-kanto_2_viaduct}"
TOD="${2:-night}"
CAB="${3:-chata}"
BODY="${4:-base}"
"$GODOT" --path game --resolution 1280x720 --disable-vsync --quit-after 8000 res://scenes/race/race3d.tscn -- --fps-log --quality=1 \
    --decorated --noparts --cab="$CAB" --body="$BODY" --route="$ROUTE" --time="$TOD" --start=300 --start-speed=22 --autoplay \
    2>&1 | grep -E "FPS medio|SUPERFICIES|SCRIPT ERROR|Parse Error" || true
