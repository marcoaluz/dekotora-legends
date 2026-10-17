# Plano visual e próximos passos — Kaidō Bakusō / Dekotora Legends

Análise de 16/10/2026 sobre o commit `1655473`. Coloque este arquivo em `docs/PLANO_VISUAL.md`.

## Diagnóstico: por que parece "cara de IA"

1. **Tudo no mesmo tom.** Céu, neblina, grama e prédios estão em lilás médio; não há preto profundo nem luz forte. Sem contraste, nada chama o olho.
2. **Superfícies limpas demais.** Asfalto, mureta e baú sem desgaste, sujeira, remendo ou variação.
3. **Objetos genéricos.** Pinheiro, árvore redonda e palmeira low-poly poderiam estar em qualquer jogo; nada diz "rodovia japonesa".
4. **Céu padrão** (`ProceduralSkyMaterial`), sem estrelas, lua, nuvens ou brilho de cidade.
5. **Zebra rosa de autódromo** numa rodovia. Japonês não tem isso; parece placeholder.
6. **Nenhuma luz conta história.** À noite, uma rodovia japonesa é definida pelas luzes de sódio laranja, túneis e letreiros; nada disso aparece.
7. **Sem sensação de velocidade.** Câmera estável, sem linhas de velocidade, rastro de luz ou tremor.

O protótipo `02_prototipo_noite.patch` ataca os itens 1, 4, 5 e 6 em cerca de 60 linhas, só para mostrar a direção.

## Regra técnica que manda em tudo

O jogo usa o renderizador **Compatibility** (leve, para celular). Nele **não existem** reflexos de tela (SSR),
oclusão de ambiente, iluminação global nem neblina volumétrica, e cada objeto recebe no máximo 8 luzes.
Teste confirmado: 30 luzes reais nos postes **não apareceram** no asfalto. Por isso, efeitos devem ser
**truques baratos**: poças de luz pintadas, reflexos falsos, texturas com o brilho "pintado", cromo com matcap.
Cada efeito novo precisa de uma chave em Opções → Qualidade.

## Prioridades

| # | O quê | Por quê |
| --- | --- | --- |
| 1 | Aplicar a correção das rodas | Bug visível em todo caminhão |
| 2 | **APK no celular e medir FPS** (instalar Android SDK + JDK 17) | Nunca foi testado no Android. Antes de pesar o visual, é preciso saber quanto sobra de desempenho |
| 3 | Direção de arte e hora do dia (V1, V2) | Base de todo o resto |
| 4 | Estrada com cara de Japão, dia e noite (V3, V4) | É o que aparece 90% do tempo na tela |
| 5 | Sensação de velocidade (V5) | Transforma "demo" em "jogo de corrida" |
| 6 | Caminhão com cara de Dekotora de verdade (V6, V7) | O coração do jogo |
| 7 | Decisões pendentes de jogo | Hitbox e estatísticas iguais para todos os modelos de baú (STATUS.md) |

## Prompts para o Claude Code (use com `/tarefa`)

### V0 — Aplicar a correção das rodas e o protótipo
```
Aplique os patches 01_correcao_rodas.patch e 02_prototipo_noite.patch (git apply). Rode os testes.
Abra a corrida e confira: rodas girando no eixo certo (inclusive as dianteiras ao virar) e o
ambiente noturno novo. O 02 é PROTÓTIPO: mantenha, mas registre em DECISOES.md que será refeito em V2.
Faça o commit.
```

### V1 — Assinatura visual (decisão do Marco)
```
Carregue a skill arte-dekotora. Monte docs/DIRECAO_ARTE.md com 3 propostas de identidade para a corrida,
cada uma com paleta (8 a 12 cores), referência de luz, céu, materiais e 1 captura de tela tirada do
próprio jogo com ajustes rápidos de ambiente:
A) "Shuto à meia-noite": céu quase preto, luz de sódio laranja, neon rosa e ciano, asfalto molhado.
B) "Hora mágica no litoral": céu laranja-violeta, silhuetas, faróis acesos, mar refletindo.
C) "Verão japonês": dia forte, céu azul com nuvens altas, sombras duras, Monte Fuji ao fundo.
Não implemente nada definitivo. Me mostre as 3 capturas lado a lado e espere eu escolher.
```

### V2 — Sistema de hora do dia
```
Crie um Resource TimeOfDay (cores do céu, horizonte, sol/lua, neblina, intensidade das poças de luz,
das janelas dos prédios e dos faróis, exposição e contraste) com presets night, dusk e day, escolhido
por rota em RouteDef. Refaça world_env.gd para usar o preset (substitui o protótipo). Céu por shader:
noite com estrelas, lua e brilho laranja da cidade no horizonte; dia com gradiente, sol e duas camadas
de nuvens que se movem devagar. Postes e faróis acendem só em dusk/night. Capturas dos 3 presets na
mesma posição da pista.
```

### V3 — Estrada com cara de rodovia japonesa
```
Refaça o visual da pista para parecer uma via expressa japonesa (Shuto/Tomei), mantendo a simulação:
- Tirar a zebra de autódromo. Linha branca contínua na borda; linha amarela-laranja onde não pode ultrapassar.
- Marcações pintadas no asfalto como decal: "80", setas, kanji 速度落とせ (reduza a velocidade).
- Delineadores verdes e brancos com refletor nas muretas, "olhos de gato" que brilham com o farol.
- Pórticos verdes sobre a pista com placas em kanji e romaji (texto da fonte com kanji do projeto).
- Barreiras de som translúcidas em trechos urbanos; trecho elevado com pilares de concreto.
- Um TÚNEL com luzes de sódio em fila no teto (cena mais icônica de corrida japonesa à noite).
Use instâncias (MultiMesh) e meça draw calls antes e depois com --fps-log.
```

### V4 — Texturas com mais realidade e desgaste
```
Baixe texturas CC0 do Poly Haven (polyhaven.com) ou ambientCG (ambientcg.com): asfalto, asfalto com
remendos, concreto, metal pintado, metal escovado. Reduza para 512 ou 1024 px (celular) e registre a
origem e a licença em assets/LICENCAS.md. No asfalto: marcas de pneu escuras nas faixas de rolamento,
remendos e rachaduras como decals; variação de cor a cada trecho para não repetir. Mureta e pilares
com manchas de chuva escorrida. Pintura dos caminhões com a sujeira existente um pouco mais visível
embaixo e atrás das rodas. Compare capturas antes/depois.
```

### V5 — Sensação de velocidade
```
Implemente, cada um com chave em Opções → Qualidade:
- O FOV já abre com a velocidade (race_scene_3d.gd, linha ~508): aumentar o efeito e somar um leve
  atraso da câmera nas curvas.
- O tremor hoje só acontece nas batidas (_shake): somar uma vibração sutil e contínua acima de 100 km/h.
- Linhas de velocidade nas bordas da tela acima de 110 km/h (shader de tela barato).
- À noite: rastro de luz das lanternas traseiras dos rivais e do trânsito (trail curto aditivo).
- Reflexo falso do asfalto molhado: faixa vertical esticada e borrada da cor de cada farol, lanterna
  e poste, desenhada no chão (quad aditivo), opcional "chuva" com respingos.
- Faíscas no raspão lateral e flash na tela no Passing.
Grave um vídeo curto (ou sequência de capturas) da corrida a 120 km/h para eu avaliar.
```

### V6 — Cromo que brilha de verdade
```
O cromo fica escuro à noite porque reflete o céu escuro e o Compatibility não tem reflexo de tela.
Crie um material de cromo por matcap (textura esférica com faixas de luz de cidade, laranja e neon),
aplicado a todas as peças cromadas dos caminhões, com opção dia/noite. Compare com o cromo atual na
garagem e na corrida.
```

### V7 — Caminhão com cara de Dekotora
```
Carregue as skills arte-dekotora e blender-pixelart (parte de verificação visual). Use as referências de
docs/dekotora_volvo_3d_references/. Prioridades:
1) Muito mais luzes de marcação (fileiras densas no para-choque, saias, teto, traseira), como Dekotora real.
2) Andon traseiro e de teto iluminados com kanji.
3) Murais laterais com textura: comece com padrões geométricos fortes (ondas, raios, kanji grande).
   Figuras (dragão, carpa, rosto) o Claude não desenha bem: deixe a textura do mural como um arquivo
   PNG trocável para eu colocar uma arte feita por pessoa ou gerada por IA de imagem.
4) Renders de revisão 3/4 frontal, traseira e lateral, à noite, ANTES de exportar o .glb.
```

### V8 — Medir no celular depois de cada etapa
```
Gere o APK, instale no meu celular e meça FPS, draw calls e temperatura em 5 minutos de corrida nos
3 presets de qualidade. Desligue o que custar mais do que entrega no modo médio.
```
