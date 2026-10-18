# Pipeline de arte: Blender → pixel art

Toda a arte do jogo é construída por scripts Python no Blender e renderizada como sprites de pixel art.
Os scripts são a **fonte** da arte: para mudar algo, muda-se o script e roda-se de novo.

## Como rodar

```powershell
cd C:\Projetos\dekotora-legends
blender -b -P blender/scripts/build_all.py                 # tudo
blender -b -P blender/scripts/render_truck.py -- --truck base --parts all
```

`-b` = sem abrir a janela. Os argumentos depois de `--` são lidos pelo script.

## Biblioteca comum (`blender/scripts/lib/`)

| Módulo | Faz |
| --- | --- |
| `scene.py` | Limpa a cena, unidades em metros, cor de fundo transparente |
| `materials.py` | Materiais chapados (toon): pintura, cromo, dourado, borracha, vidro, luz emissiva |
| `shapes.py` | Blocos prontos: caixa chanfrada, cilindro, grade em degraus, fileira de luzes, texto 3D |
| `camera_rig.py` | Câmera e luz fixas por ângulo de render; mesmo enquadramento para tudo |
| `render.py` | Renderiza em baixa resolução, com holdout para camadas |
| `pixelize.py` | numpy: reduz à paleta, remove semitransparência, contorno de 1 px, recorta borda vazia |
| `export.py` | Salva PNG + JSON (tamanho, âncora, offset) e a folha de contato |
| `damage.py` | Gera os estados amassado (deforma vértices com ruído determinístico) e quebrado (remove/desloca partes) |
| `palette.py` | Lê `blender/palettes/dekotora.json` |
| `tex_truck.py` | Texturas procedurais (numpy) do caminhão: pintura, plástico, para-brisa, colmeia, fendas, chapa xadrez, pneu |
| `pbr.truck_set` | Materiais exclusivos do caminhão (função `truck_set` em `pbr.py`), acrescentados ao conjunto padrão |

## Convenções do modelo

- Metros. Caminhão aponta para **+Y**, chão em **Z = 0**, centro do eixo traseiro em X = 0.
- Caminhão base: cabine plana japonesa **genérica** (sem marca) + baú. Cerca de 2,5 m de largura, 3,2 m de altura, 12 m de comprimento.
- Cada peça é um objeto separado com nome `part_<slot>_<id>`, já posicionada no lugar certo do caminhão.
- Low-poly: poucas faces, quinas marcadas. Pixel art pequena não mostra detalhe fino.

## Ângulos de render

A câmera fica **atrás** do caminhão, levemente acima, olhando para frente. Para as curvas, o caminhão gira:

| Nome | Rotação (Z) | Uso no jogo |
| --- | --- | --- |
| `L2` | +20° | Curva forte à esquerda |
| `L1` | +10° | Curva leve à esquerda |
| `C` | 0° | Reto |
| `R1` | −10° | Curva leve à direita |
| `R2` | −20° | Curva forte à direita |

Câmera **ortográfica** (sem perspectiva no sprite; a perspectiva vem da estrada). Ajustável depois da Fase 1.

## Camadas e oclusão

Para empilhar peças no Godot sem desenhar todas as combinações:

1. Renderiza o **caminhão base** sozinho → `base_<ângulo>.png`.
2. Para cada peça: a peça visível + o caminhão base como **holdout** (invisível, mas "tampa" o que estiver atrás dele).
   Resultado: só os pixels da peça que realmente aparecem → `part_<id>_<estado>_<ângulo>.png`.
3. Todos os PNGs têm o **mesmo tamanho de tela** e a mesma âncora, então no Godot basta empilhar na ordem:
   base → saias → para-choques → viseira → luzes → andon → efeitos.

## Pós-processamento (pixelize)

1. Render em resolução final pequena (ex.: 128 × 96 para o caminhão).
2. Alfa: < 50% vira transparente, ≥ 50% vira opaco (sem bordas borradas).
3. Cada pixel vai para a cor **mais próxima da paleta**.
4. Contorno: pixels transparentes vizinhos a opacos recebem a cor de contorno da paleta (opcional por asset).
5. Luzes: emissão vira cor clara da paleta; um PNG extra `*_glow.png` guarda só as luzes, para o brilho no Godot.

## Estados de dano

| Estado | Como é gerado |
| --- | --- |
| `ok` | Modelo original |
| `dent` | Vértices deslocados com ruído (semente fixa), cromo mais escuro, algumas luzes apagadas |
| `broken` | Partes removidas, peça inclinada/solta; na corrida a peça cai e some |

## Saída

```
game/assets/sprites/
  truck/base/        base_L2.png ... base_R2.png + .json
  parts/<id>/        part_<id>_ok_C.png, part_<id>_dent_C.png, ... + .json
  bots/<id>/
  traffic/<id>/
  roadside/          poste.png, placa_*.png, pedagio.png, arvore_*.png
  fx/                fumaca_*.png, faisca_*.png, destroco_*.png
  icons/parts/       ícone frontal 32×32 de cada peça para a garagem
game/assets/backgrounds/kanto/
  ceu.png  montanhas.png  cidade.png   (parallax, largura repetível)
blender/renders/     saída bruta e contact_sheet.png (fora do Git)
```

## Revisão pelo Marco

Depois de cada render, o script gera `blender/renders/contact_sheet.png` com tudo ampliado 4×.
O Marco abre a imagem e responde com comentários do tipo "cromo muito escuro", "cabine muito alta".
Claude ajusta parâmetros e roda de novo.

## Paleta

`blender/palettes/dekotora.json`: 40 cores iniciais (noite, neon, cromo, dourado, pinturas). Pode ser trocada
a qualquer momento; basta rodar o render de novo.

## Limitações conhecidas

- Formas orgânicas (dragões, carpas, rostos) ficam rígidas. Murais começam geométricos: ondas, raios, faixas, kanji em fonte.
- Fonte japonesa para kanji: baixar **Noto Sans JP** (licença livre) em `game/assets/fonts/` e usar como objeto de texto no Blender.
- Se a pixel art ficar "sem alma", alternativas: retoque manual no Pixelorama, PixelLab quando houver créditos, ou o plano B (3D estilo PS1 com os mesmos modelos).
