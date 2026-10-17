# Referência: gameplay de Art Truck Battle (Bakusou Dekotora Densetsu, PS1)

Análise feita em T-098 a partir de 4 vídeos do canal "Zerando o PS1" (partidas completas, ~8 h no total).
Só **ideias de mecânica e de clima**; nenhuma arte, música, nome ou texto do original foi copiado.
Os prints em `docs/referencia_atb/` são quadros de baixa resolução (640×328) usados apenas como referência
interna de estudo; não entram no jogo.

| Parte | Vídeo | Duração | O que cobre |
| --- | --- | --- | --- |
| 1 | x7FiLCXu5fw | 2:21:56 | Abertura, menus, 1ª carga, primeiras corridas, loja, rivais, 1º "muro" de dificuldade |
| 2 | y_mqyKSAzgc | 2:22:56 | Mais rivais, 2ª loja, reinícios pela pausa, bifurcação de túneis |
| 3 | eEzN0aWOLNM | ~2:13 | Duelos de dia/noite, lojas (pintura, escapamento), resultados |
| 4 | tXEQKt8x7Ag | ~1:02 | Chefes regionais, fim do jogo, créditos |

Convenção de tempo: `P2 1:12:00` = Parte 2 aos 1h12min do vídeo.
Dinheiro no original se chama "BP"; "lenda" = reputação; "destaque" = nota de decoração do caminhão.

> **Limites da análise:** os quadros são 1 a cada 2 s. Não dá para medir a duração exata da troca de faixa
> nem confirmar números de física; o que está marcado `[incerto]` é leitura visual, não medição.
> Pausa aberta e túnel foram vistos nas folhas de contato, mas não ganharam print próprio.

---

## 1. Controle e troca de faixa

- **Troca de faixa em dois toques** (explicada em diálogo por um rival, P1 9:36–11:12): 1º toque no direcional
  liga a **seta** (pisca-pisca) daquele lado; 2º toque no mesmo lado executa a troca. A troca é **discreta por faixa**,
  não é volante livre. Os 3 ícones acima do velocímetro (seta esquerda · buzina · seta direita) acendem com isso.
- A pista tem **3 faixas por sentido + acostamento** (às vezes 4–5 visíveis na câmera alta). O caminhão se
  **inclina de leve** (~5–10°) ao trocar e a câmera o segue suave, sem girar junto (P1 124:00).
- **Pórticos** com placas "faixa de rodagem / faixa de ultrapassagem" mostram a função de cada faixa (a esquerda é
  para ultrapassar). Dá semântica às faixas: a esquerda é a rápida, mas o rival a disputa.
- Há um **botão de buzina** e botão de troca de câmera (ver §3). Acelerador/freio não aparecem na tela; o jogo
  parece manter a velocidade de cruzeiro alta (100–120 km/h no velocímetro de 0–140) e o jogo real é **escolher faixa**
  em meio ao trânsito.
- **Não existe botão de "bater no rival"**. O contato acontece ao andar colado na mesma faixa ou ao fechar a
  faixa à frente do outro (ver §2). O rival também empurra o jogador para a outra faixa [incerto].
- **Largada**: já em movimento, rival ao lado/à frente; em ~10 s a velocidade vai de ~60 a ~110 km/h.

## 2. Batidas e dano

- **Quase não há batida dura visível.** Em dezenas de minutos de duelo lado a lado, o que se vê é o caminhão
  "empurrado" para a faixa vizinha, às vezes **fumaça/poeira branca nas rodas** de quem raspa, e nada de faísca,
  tremor de tela ou som evidente nas imagens (P3 ~43:00, P4 43:00–58:00).
- **O dano vira dinheiro, não peças**: o resultado mostra "perda de carga" descontada do prêmio. Valores vistos:
  0, −200, −230, −280, −300, −400, −440, −600 (de prêmios de 1000–1500; ou seja, 0% a 40%).
  Quanto mais contato com o rival, maior o desconto: a vitória "limpa" paga mais que a vitória "no braço".
- **Não há medidor de dano na tela.** O único medidor extra é a fileira de **5 retângulos vermelhos** sob o
  velocímetro (função não confirmada; talvez marcha/rotação/turbo) [incerto].
- A carga é anunciada antes da corrida e muda o comportamento: "frágil" (dirigir com cuidado), "perecível"
  (correr), "pesada" (afeta a velocidade). A carga troca a cada corrida, mesmo após derrota.

## 3. Câmera

- **Padrão: atrás e alta.** Câmera ~4–5 m acima do teto e ~10 m atrás; o baú ocupa ~12–20% da largura, no terço
  inferior, centralizado; horizonte a ~1/3 do topo; veem-se 4–6 faixas e muita estrada à frente (print 06).
- **Primeira pessoa** (botão de troca): só estrada e a coluna curva do para-brisa; HUD igual (print 07). Muitos
  jogadores corriam assim. Marco disse que não quer essa vista (informação vinda da análise anterior; **ainda não está em docs/DECISOES.md**, registrar se confirmado).
- **Cortes de "transmissão"**: na largada, ~1–2 s de câmera lateral baixa (com letterbox preto) antes de ir para a
  câmera de trás (print 14); durante a corrida, cortes curtos (1–2 s) laterais ou frontais mostrando o caminhão do
  jogador (luzes do teto e do para-choque acesas) — cria clima de TV.
- **Chegada**: câmera lateral fixa com banner dourado "chegada"; os dois caminhões aparecem juntos quando é apertado
  (print 10). **Tempo esgotado**: câmera lateral com o caminhão parando e faixa azul de texto (print 11).
- Reação à velocidade/batida: não se nota zoom, FOV ou tremor; é uma câmera calma. A sensação de velocidade vem
  do cenário passando e dos túneis.

## 4. HUD (idêntico em todas as corridas — prints 06, 07, 08)

| Elemento | Posição | Observação |
| --- | --- | --- |
| Tempo de viagem (sobe) | canto sup. direito | escala de viagem: ~1 s real ≈ 1 min de estrada ("4 h 07 min" em ~4 min reais) |
| Tempo restante (desce) | logo abaixo | é o **prazo de entrega**; acabar = derrota ("tempo esgotado") |
| Barra fina de progresso | abaixo dos tempos | 2 marcadores numerados: jogador e rival na rota |
| Velocímetro analógico 0–140 | canto inf. direito | fica **laranja** à noite e nos túneis |
| 3 ícones (seta ◀ · buzina · seta ▶) | acima do velocímetro | acendem ao usar |
| 5 retângulos vermelhos | abaixo do velocímetro | função incerta |
| Faixa vertical translúcida | borda esquerda | tracinhos ciano/vermelho = vizinhança do caminhão (mini radar); vira laranja no túnel |

Não há minimapa. O mapa do Japão só aparece **antes** da corrida (escolha de rodovia). Não há contagem de
posição (1º/2º) em texto: só os marcadores na barra.

## 5. Estrutura da corrida

1. **Tela-base** (print 02): menu à esquerda (partir · loja · salvar · sair), caminhão girando, **slot da carga da
   vez** com ícone, dinheiro e uma caixa de fala do motorista.
2. **Escolha de rodovia** num mapa do Japão (print 03): cada rodovia tem **um rival com retrato e fala própria**.
   Muitos **recusam** ("não corro com novato", "enfeite mais o caminhão", "estou ocupado"). Aceitam depois que o
   jogador sobe de **lenda** e de **destaque** (decoração). Acima dos rivais há **chefes regionais**.
3. **Tela de duelo "VS"** (print 04): animação teatral (dois caminhões, divindades folclóricas, kanji grande de
   "confronto", relâmpago), depois loading com os dois caminhões de frente. Repetitiva em revanches.
4. **Largada** (print 05): banner dourado "partida", rival lado a lado, linhas amarelas pintadas no chão.
5. **Corrida** ~3–5 min reais, ~4 h de "viagem": trânsito (sedans, hatch, esportivos, peruas, caminhões comuns),
   túneis, pórticos, pedágio a 500 m perto do fim.
6. **Chegada** (print 10) — **vence quem chega primeiro E dentro do prazo**. Chegar dentro do prazo mas depois
   do rival = derrota (resultado todo em traços, rival zomba). Pode chegar com 5 min de folga e perder.
7. **Resultado** (print 12): tempo de viagem · pontos de vitória · perda de carga · total · **% de lenda**.
   Fica parado até apertar botão.
8. **Dinheiro**: prêmio fixo por rival (1000 comum, 1100–1500 forte). Lenda sobe de +3% (rival fraco) a +23%
   (chefe). Total gasto na loja → sem renda alternativa o jogador **trava** (ver §9).
9. **Pausa**: caixa pequena no centro com 3 opções — continuar · **revanche** (reinicia na hora) · desistir. Não
   escurece o jogo. Sair no meio não tem penalidade visível. Revanche e repetir sem custo = tentativas infinitas.
10. **Fim do jogo**: derrotar o chefe do extremo norte → fala de passagem de bastão → créditos em caligrafia
    vertical sobre um dekotora iluminado → pergunta de salvar → título.

**Rivais**: mais fortes = mais rápidos em reta, mas **travam no trânsito**; o jogador vence passando pelos
buracos, ficando atrás para pegar vácuo ou **fechando a faixa** quando está à frente. Rivais decorados
(mural no baú, fileira de luzes) andam colados ao lado por minutos.

## 6. Menus, garagem, história e personagens

- **Menu principal** (print 01): 4 botões empilhados (modos) + 2 barras verticais laterais (configurações e diário).
  Em configurações: **editor de pintura original**, teclas, e uma opção de ouvir música tema.
- **Escolha de caminhão**: baú cinza liso girando; ~5 modelos de cabine; **3 selos** = faixa de velocidade em que
  é forte (baixa/arranque, média, alta/final). A escolha define o perfil de desempenho.
- **Nome do motorista** e do caminhão (teclado na tela com silabários).
- **Loja/oficina** (print 13): dono com retrato que comenta cada peça em tom de mestre. Menu por região do
  caminhão: deque frontal (caixa luminosa no teto), viseira, para-choques (frontal/traseiro/lateral), pintura
  (baú/laterais/teto), escada traseira, lâmpadas, luzes laterais, rodas de alumínio, escapamento, volante, buzina,
  "foguete" decorativo (o dono avisa "não ataca"). Setas ◀▶ trocam o modelo; **L/R muda a cor**; botão
  **dia/noite** alterna a prévia (luzes acesas!); câmera dá zoom na região; custo da reforma soma ao vivo;
  confirmação sim/não.
  - Indicadores: dinheiro · custo da reforma · **destaque %** · **lenda %**. Cada peça sobe o destaque
    (pintura é o que mais sobe); a lenda só sobe por corridas.
  - **Peças NÃO mudam o desempenho.** O dono diz explicitamente que trocar escapamento não melhora nada, só
    o som e o visual. Peças compradas **acendem à noite na corrida** e aparecem no loading/VS/chegada.
  - **Melhoria de motor** vem de evento narrativo gratuito (o dono pergunta qual faixa de velocidade reforçar),
    não de compra.
- **Mapa e hierarquia**: rival de rodovia → chefe regional → chefe final. Cada região tem retrato e fala. Os
  derrotados dão conselhos e anunciam o próximo ("o chefe é fulano").
- **Tom**: japonês de rua, honra, "o número 1 do país"; rivais zombam ao vencer e elogiam ao perder.

## 7. Cenário e hora do dia

- **Dia** (azul com nuvens, serra, chá com Fuji ao fundo, campos, taludes gramados em degraus, muro antirruído,
  passarelas/viadutos, trem amarelo em paralelo, lens flare do sol): print 06.
- **Noite** (céu quase preto, faróis desenham mancha branca alongada no asfalto, faróis de carros vindos de
  trás também; cidade com janelas acesas): print 08. Fim de madrugada: azul-escuro.
- **Túneis**: curtos e longos (até ~2 min reais), dois tubos lado a lado em bifurcação, **iluminação de sódio
  laranja** em tudo (inclusive velocímetro); na saída, disco claro/estourado e adaptação de luz.
- **Marcações**: zebra/hachurado branco na entrada/saída de faixa, setas no chão, chevrons laranja de curva,
  placas xadrez verde-branco na mureta antes do túnel, pórticos verdes de 2–3 placas, pedágio a 500 m.
- Cidades: prédios baixos, muros antirruído altos dos dois lados, palmeiras no sul, pinheiros no norte.

## 8. Observações de design (resumo)

1. A graça é **escolher faixa no trânsito** e **disputar espaço com um rival que anda colado**, não acelerar.
2. O **prazo** (tempo restante) cria tensão sem precisar de combate; a perda de carga pune o contato.
3. **Reputação + decoração destravam rivais**: ligação direta entre garagem (estética) e progressão. Muito alinhado
   com o nosso conceito Dekotora.
4. As peças são **só visuais**, mas o jogo as torna importantes (acendem à noite, mudam o destaque, destravam rivais).
5. O jogo **trava o jogador** sem dinheiro e sem renda alternativa (várias dezenas de tentativas seguidas na
   mesma corrida nas Partes 1–3). Nosso mercado de fretes já resolve isso.
6. Muitas telas de teatro (VS, resultado parado, diálogo) dão personalidade, mas repetem e cansam em revanche.

## 9. O que aplicar no nosso jogo

Esforço: P pequeno · M médio · G grande. Prioridade: A alta · M média · B baixa.

| # | Ideia | Onde aparece | Esforço | Prioridade | Precisa decisão do Marco |
| --- | --- | --- | --- | --- | --- |
| 1 | **Prazo de entrega** (tempo restante que desce) como limite da corrida, ligado ao contrato de frete | HUD, P1 12:00; derrota P1 16:00 | P | A | Sim (vira regra de derrota) |
| 2 | **Vence quem chega primeiro E dentro do prazo**; derrota = 0 dinheiro e 0 fama | P1 61:36 | P | A | Sim |
| 3 | **Perda de carga proporcional ao contato** (0–40% do prêmio) mostrada no resultado | Resultado, P2 104:48 | M | A | Não (já temos integridade da carga; só ajustar a escala) |
| 4 | Troca de faixa discreta com **seta antes** (aviso de 1 toque, executa no 2º) como opção de controle de toque | P1 9:36 | M | M | Sim (muda o controle atual) |
| 5 | **Rival que trava no trânsito** (IA rápida em reta, lenta atrás de carros) em vez de "borracha" | P1 93:36, P2 32:48 | M | A | Não |
| 6 | Rival **colado ao lado** que fecha a faixa e empurra | P4 43:00, P3 130:00 | M | A | Não |
| 7 | **Rivais recusam** por falta de fama/decoração (diálogo curto); desbloqueio por reputação + "destaque" | P1 24:00, 48:00 | M | A | Sim (liga garagem a progressão) |
| 8 | **Nota de destaque** calculada pelas peças/pintura do caminhão, mostrada na loja ao vivo | Loja, P1 48:00 | M | A | Sim |
| 9 | Prévia **dia/noite** na garagem com luzes acesas | Loja, P1 46:00 | P | A | Não (já temos galpão 3D; falta alternar luz) |
| 10 | Peças que **acendem à noite na corrida** e aparecem na tela de chegada/VS | P2 22:24 | P | A | Não (já temos luzes V7; ligar à noite) |
| 11 | **Pintura/mural** como maior fonte de destaque + editor próprio | Loja, P4 14:00; menu | G | M | Sim |
| 12 | Tela **VS** curta antes da corrida (sem repetir longa nas revanches) | P1 11:12 | M | M | Sim |
| 13 | **Revanche/continuar/desistir** na pausa, sem escurecer e sem penalidade | P2 68:00 | P | A | Não |
| 14 | **Cortes de câmera de transmissão** (lateral 1–2 s na largada e em momentos-chave) | P1 18:48, P2 62:00 | M | M | Não |
| 15 | Banner dourado de **partida/chegada** em caligrafia e câmera lateral na chegada | P1 22:24 | P | M | Não |
| 16 | Radar de vizinhança na borda esquerda (tracinhos dos carros próximos) | HUD | M | B | Sim |
| 17 | Barra de progresso fina com 2 marcadores (jogador e rival) | HUD | P | A | Não |
| 18 | Resultado parado até apertar, com fala do rival (vitória/derrota) | P1 17:36 | P | M | Não |
| 19 | Escala de prêmio por rival (1000 comum → 1500 forte) e **lenda de +3% a +23%** conforme a força | Resultados | P | M | Sim (entra em BALANCEAMENTO.md) |
| 20 | **Perfil do caminhão por faixa de velocidade** (baixa/média/alta) mostrado com selos na escolha | P1 4:48, P2 39:12 | M | M | Sim |
| 21 | **Melhoria de motor como evento gratuito** do mestre da oficina, não por compra | P3 88:00, P4 14:00 | P | B | Sim |
| 22 | **Separar peça visual de peça de desempenho** na loja (no original só destaque/preço; nós já temos motor/turbo/escape com efeito, ver DECISOES 2026-10-15) | Loja, P3 92:00 | P | M | Sim |
| 23 | **Renda alternativa** para não travar (frete sem rival) | P2 52:00 | P | A | Não (mercado de fretes já cobre) |
| 24 | Rotas com **túneis longos** de iluminação laranja, bifurcação de túneis e saída estourada | P2 76:00 | M | M | Não (túnel já existe; falta bifurcação e adaptação de luz) |
| 25 | **Adaptação de luz** ao sair do túnel (clarão e volta) | P1 52:48 | P | M | Não |
| 26 | Faróis do jogador desenhando **mancha branca no asfalto** e de carros atrás | P1 27:12 | P | A | Não (V5 já faz reflexo; revisar mancha à frente) |
| 27 | Hachurado de entrada de faixa, chevrons de curva, placas xadrez antes do túnel, pedágio a 500 m | P1 43:12, P2 134:00 | P | B | Não |
| 28 | Chefes regionais e **mapa com rival por rodovia** (retrato e fala) | P1 48:00, P4 | G | M | Sim (muda estrutura de campanha) |
| 29 | Pergunta/aviso de **carga** antes da corrida ("frágil, pesada, perecível" muda o jeito de dirigir) | P1 8:48, 17:36 | M | A | Não (já temos contratos; ligar o aviso à física) |
| 30 | Primeira pessoa | P1 80:00 | — | **Descartar** | Sim (confirmar a recusa) |

### Sugestão de ordem

1. **Mais barato e de maior retorno:** #1, #2, #13, #17, #23 (prazo, regra de vitória, pausa, barra de progresso, renda de reserva).
2. **Alma Dekotora:** #8, #7, #9, #10 (destaque, rivais que recusam, luz à noite na garagem e na pista).
3. **Sensação de disputa:** #5, #6, #3, #14 (rival que trava no trânsito, colado, perda de carga proporcional, cortes de câmera).
4. Depois, caso a caso: #4, #11, #12, #20, #28.
