# Adesivos (decals)

Coloque aqui os PNGs dos adesivos do caminhão. O jogo lista todos os `.png` desta pasta na garagem
(aba **Decoração > Adesivos**), e também os da pasta `decals/` dentro dos dados do jogo (`user://decals/`,
no Windows: `%APPDATA%\Godot\app_userdata\<nome do projeto>\decals\`), que não exigem reimportar o projeto.

**Como fazer uma arte própria (carpa, tigre, máscara...):**
- PNG com fundo **transparente**, desenho em **branco** (o jogo pinta com a cor que você escolher na garagem;
  uma arte colorida também funciona, mas a cor escolhida vai misturar com ela).
- Quadrado (256–512 px) ou retangular (ex.: 512×256). Proporção é mantida.
- Nome do arquivo = nome do adesivo (`carpa.png`). Use letras minúsculas, sem espaço.

**Os 6 adesivos provisórios** (kanji 爆走, kanji 魂, ondas, raio, estrela, sol) foram gerados por
`python tools/gen_decals.py` — pode apagar ou trocar à vontade. Cada adesivo colocado soma +6 de destaque
(máximo 4: lateral esquerda, lateral direita, traseira e cabine).
