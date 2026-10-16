---
name: arte-dekotora
description: Use quando for decidir COMO algo do Dekotora Legends deve parecer — desenhar ou modelar um caminhão, peça decorativa, mural, cenário, UI ou ícone; escolher cores; avaliar uma folha de contato; ou traduzir um pedido visual do Marco ("mais brilho", "mais Dekotora") em mudanças concretas. Direção de arte e critérios de qualidade; o como-fazer técnico está nas skills blender-pixelart e godot-dekotora.
---

# Direção de arte — Dekotora Legends

## A identidade em uma frase

Caminhões de trabalho transformados em altares de cromo e luz: **excesso organizado**. Simetria, brilho,
camadas de cromo, fileiras de luzes, pintura lateral dramática, tudo legível em 96 pixels.

## Vocabulário visual (o que faz um caminhão parecer Dekotora)

| Elemento | Onde | Como ler em pixel art |
| --- | --- | --- |
| Para-choque frontal em degraus | Frente, embaixo | Faixas horizontais de cromo alternando claro/escuro |
| Viseira sobre o para-brisa | Topo da cabine | Aba larga, dourada ou cromada, com luzes na borda |
| Fileiras de luzes de marcação | Teto, laterais, para-choques | Pontos de 1 px de cor clara, espaçados igualmente |
| Andon (painel luminoso) | Traseira e topo | Retângulo emissivo com kanji/letras grandes, borda cromada |
| Saias laterais | Embaixo do baú | Faixa longa de cromo com luzes |
| Mural lateral | Lados do baú | Grandes formas de cor: ondas, raios, faixas; contraste forte |
| Escadas e alças cromadas | Traseira | Linhas verticais finas e claras |

Evite: marcas e logotipos reais, nomes de fabricantes, cópia de caminhões famosos identificáveis.

## Regras de legibilidade em pixel art pequena

1. **Silhueta primeiro.** O caminhão tem de ser reconhecível só pela forma preenchida de uma cor.
   Peças maiores mudam a silhueta (para-choque, viseira, luzes de teto) — isso é bom.
2. **Contraste de valor** antes de cor: cromo = escuro + claro lado a lado; nunca cinza médio chapado.
3. **Detalhe mínimo de 1 pixel** no tamanho final. O que tiver menos de ~0,08 m some; aumente ou remova.
4. **Simetria** na vista traseira: Dekotora é simétrico; desalinhar 1 px já parece erro.
5. **Luzes são pontos isolados** com 1 px de espaço entre si; luz grudada vira faixa.
6. **No máximo 3 tons por material** (sombra, base, luz) + contorno. Mais que isso vira ruído.
7. **Contorno** escuro no caminhão e nos carros; sem contorno em luzes, fumaça e cenário distante.

## Paleta

- Fonte única: `blender/palettes/dekotora.json` (40 cores). Grupos: noite, neon, cromo, dourado, pinturas, borracha/asfalto, luzes.
- Noite: fundo nos azuis-violeta; destaque nos neons rosa/ciano e no dourado.
- Pintura base dos caminhões: branco, vermelho, azul ou verde da paleta. Mural usa no máximo 3 cores + cromo.
- Nunca adicione cor fora da paleta sem registrar em `docs/DECISOES.md`.

## Traduzindo pedidos do Marco

| Ele diz | Mudanças concretas para propor |
| --- | --- |
| "Mais Dekotora" | Viseira maior, mais fileiras de luzes, para-choque com mais degraus, andon maior |
| "Mais brilho" | Mais pixels emissivos, glow mais forte no Godot, cromo com faixa clara mais larga |
| "Está apagado/sem vida" | Mais contraste de valor; pintura mais saturada; contorno |
| "Está poluído" | Menos peças pequenas; aumentar espaçamento entre luzes; tirar um tom |
| "Parece de brinquedo" | Proporção mais longa e baixa; rodas menores; menos chanfro |
| "Muito pequeno na tela" | Quadro mais largo ou ângulos de curva menores (ver blender-pixelart) |

Sempre proponha 2 ou 3 variações lado a lado na folha de contato, em vez de uma só.

## Critérios para aprovar uma folha de contato

- [ ] Reconhecível como caminhão Dekotora a 1× (sem ampliar)
- [ ] Os 5 ângulos parecem o mesmo caminhão girando (sem saltos de tamanho ou cor)
- [ ] Peças empilhadas sem buracos nem sobras de pixels
- [ ] Estados `dent` e `broken` diferentes à primeira vista
- [ ] Luzes legíveis à noite com o glow ligado
- [ ] Todas as cores da paleta (checagem automática da skill blender-pixelart)

## Fora do caminhão

- **Cenário**: camadas de parallax com poucas cores; quanto mais longe, mais perto do azul do céu e sem contorno.
- **Carros de tráfego**: genéricos, sem marca, cores sóbrias para não competir com os caminhões.
- **UI**: fonte pixel, molduras finas cromadas, destaques em neon; texto mínimo 8 px de altura na base 480×270.
- **Ícones da garagem**: render frontal 32×32 da peça sozinha, fundo transparente, contorno.
