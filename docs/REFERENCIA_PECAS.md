# Catálogo de peças a partir do documento do Marco (T-210, passo 1)

Data: 2026-10-24. Pedido do Marco: refazer a personalização de PEÇAS do caminhão a partir das 147 capturas da oficina do
jogo original (Bakusou Dekotora Densetsu / Art Truck Battle) que ele juntou num documento Word.
**Este passo é só pesquisa e plano: nada foi modelado e nenhum código do jogo mudou.** O passo 2 só começa quando o
Marco aprovar (seção 17, "PRECISA DECISÃO").

## 0. Onde estão as imagens (tudo local, fora do Git)

As capturas são arte de terceiros: ficam só no PC, em `docs/Referencias/oficina/` (pasta no `.gitignore`).

| O quê | Caminho |
| --- | --- |
| Documento original | `docs/Modelos/Referencia jogo do camionhão.docx` (a pasta `docs/Modelos Referencia jogo do camionhão`, citada no pedido, não existe) |
| 147 capturas extraídas, na ordem do documento | `docs/Referencias/oficina/img/001.png` … `147.png` (~900 × 410 px; 11 do para-choque são mais largas, ~1460 × 420) |
| Títulos e ordem das imagens | `docs/Referencias/oficina/texto.md` e `index.json` (número → título) |
| Folhas de contato por seção (miniatura 460 px, número da captura no canto) | `docs/Referencias/oficina/folhas/01_…png` a `12_…png` |
| As mesmas folhas pequenas (para o Marco ver rápido, ~950 px de largura) | `docs/Referencias/oficina/folhas/pequenas/` |
| Folhas de 9 em 9 em tamanho maior (as que eu usei para analisar) | `docs/Referencias/oficina/folhas/inspecao/` |
| Regerar tudo (se apagar a pasta) | `python -I docs/Referencias/oficina/scripts/extract_docx.py "docs/Modelos/Referencia jogo do camionhão.docx" docs/Referencias/oficina` e depois `blender -b --factory-startup -P docs/Referencias/oficina/scripts/sheets.py -- <caminho absoluto de docs/Referencias/oficina>` (cópias locais; sem pandoc, sem Pillow) |

Os intervalos conferidos no documento **batem exatamente** com a tabela do pedido:

| # | Título no documento | Capturas | Qtd. | Folha |
| --- | --- | --- | --- | --- |
| 1 | Deck Frontal – parte de cima | 001–028 | 28 | `01_deck_frontal_parte_de_cima_001-028.png` |
| 2 | Viseira – Frontal | 029–042 | 14 | `02_viseira_frontal_029-042.png` |
| 3 | Para choque frontal | 043–062 | 20 | `03_para_choque_frontal_043-062.png` |
| 4 | Traseira | 063–084 | 22 | `04_traseira_063-084.png` |
| 5 | Para choque lateral | 085–094 | 10 | `05_para_choque_lateral_085-094.png` |
| 6 | Foguete | 095–101 | 7 | `06_foguete_095-101.png` |
| 7 | Luz na lateral direita / esquerda / superior | 102 / 103 / 104 | 3 | `07_luzes_do_bau_102-104.png` |
| 8 | Retrovisor | 105–110 | 6 | `08_retrovisor_105-110.png` |
| 9 | Escada | 111–113 | 3 | `09_escada_111-113.png` |
| 10 | Pintura | 114–133 | 20 | `10_pintura_114-133.png` |
| 11 | Pintura no teto | 134–142 | 9 | `11_pintura_no_teto_134-142.png` |
| 12 | "Traseira é focado mais no rosto…" | 143–147 | 5 | `12_pintura_traseira_rosto_143-147.png` |

Duas pequenas correções ao resumo do pedido (vale o documento):
- No deque, **só as capturas 002 e 003** têm o botão "De dia/De noite" (são a mesma peça de dia e de noite); a 001 tem
  "Alterar cor - L/R".
- A escada (111–113) fica **atrás da cabine, na quina da frente do baú**, não na traseira.

### Regra que aparece em todas as seções

- Peça com **neon/LED/cor** mostra "Alterar cor - L/R" (as capturas vêm em pares: versão **preta com neon ciano/verde** e
  versão **prata com azul-marinho**, mesma forma).
- Peça **cromada sem cor** e as **pinturas** mostram "De dia/De noite" (o botão serve para ver as lâmpadas acesas).
- Algumas capturas do para-choque (043–053) estão com a interface em japonês ("L,Rで色変更" = "troca de cor com L/R").
- A captura 118 mostra o menu de temas da pintura: **DRAGÃO, KABUKI, DEMÔNIO, MULHER** (e mais itens cortados).

### Convenções dos números propostos (coerentes com `docs/BALANCEAMENTO.md`)

- **Fama necessária** segue a regra que já existe pelo preço: < 15 mil ¥ = livre · < 30 mil = 20 · < 50 mil = 60 ·
  50 mil ou mais = 120.
- **Raridade** (campo novo, proposta): é só uma etiqueta da mesma faixa de preço, para não criar regra nova:
  **Comum** (< 15 mil) · **Incomum** (15–29 mil) · **Rara** (30–49 mil) · **Lendária** (50 mil ou mais).
  Se o Marco quiser que raridade signifique outra coisa (ganhar do rival, sorteio), ver seção 17.
- **Destaque** (o `fame` do `.tres`): neon/LED rende mais destaque por iene; cromo estrutural rende menos destaque e mais
  durabilidade (mesmo padrão das peças atuais: `skirt_light_bar` 25 × `skirt_chrome` 15).
- **Peso e durabilidade** na mesma escala das atuais: para-choques 120–560 kg, viseiras 40–110 kg, luzes 20–70 kg.
- Pintura (mural, teto, traseira) **não tem durabilidade**: risca na batida (regra atual: −10% do destaque até repintar).
- Peça de lado (saias, retrovisor, escada) é **comprada uma vez e vai nos dois lados**, como as atuais.
- Todos os valores são **proposta para testar**; ficam em `BALANCEAMENTO.md` só depois da aprovação.

### O que o jogo tem hoje (resumo, conferido em 2026-10-24)

- **53 peças** em `game/data/parts/*.tres`, **48 modelos** em `game/assets/vehicles/dekotora/accessories/{front,lighting,sides,rear}/*.glb`,
  catálogo `game/assets/vehicles/dekotora/catalog.json`, 27 encaixes na garagem (`GarageDecoNav.AREAS`).
- **Caminhões**: baú leve/médio/longo e graneleira × cabines chata/jac/curta/americana (16 `.glb`), **Canter** (cabine
  fixa) e **carreta** (guardada, não jogável) em `game/assets/vehicles/dekotora/truck/`. Todos têm os mesmos 38 pontos
  `MOUNT_*`; os escapamentos altos usam pontos criados no jogo (`TruckNode.extra_mounts`).
- **Pintura do baú**: um PNG trocável só (`assets/vehicles/dekotora/murals/mural_side.png`, 1024 × 256) no material
  `mural` das laterais; os 2 murais da loja (`mural_waves`, `mural_lightning`) só põem painéis geométricos por cima. O teto
  e as portas traseiras do baú não têm material próprio (são `paint_white_box` / `box_metal`).
- **Os `.glb` juntam a geometria por material** (nós `truck_chrome`, `truck_andon_panel`…): o espelho, o para-choque e o
  andon de fábrica **não podem ser escondidos sozinhos** hoje. Isso importa para o retrovisor e o deque (seção 13).
- **Dano visual**: `TruckNode.set_part_state` — amassada troca cromo por aço e inclina 3°; quebrada **some** (`visible = false`).

---

## 1. Deque frontal – parte de cima (001–028)

**O que as imagens mostram.** Câmera em 3/4 pela frente e um pouco acima, olhando o teto da cabine; atrás aparece a
frente do baú (chapa escura com 2 lanternas laranja). A peça é uma **caixa sobre o teto da cabine**, da largura da cabine
(~2,2 m), 0,8–1,2 m de fundo e 0,5–0,9 m de altura, com a frente inclinada para trás. Elementos que se repetem:
- **matriz de LEDs verdes** (quadradinhos em grade, 2 a 4 fileiras) no topo e nas laterais;
- **letreiro de acrílico** com kanji na frente (rosa, creme, azul, vermelho), às vezes com 2 ou 3 letreiros;
- **colunas/moldura de neon ciano** dos lados do letreiro, "sobrancelhas" de neon (016–017), friso vazado tipo renda (012–013);
- painéis pequenos **pintados** (rostos/figuras) nas pontas (008–009, 024);
- 025–028 não são caixas: são **canhões de luz** (tubos horizontais pretos com lente ciano sextavada), 2 ou 5 lado a lado.
Cores: versão preta com LED verde + neon ciano, ou cromada/prata com azul-marinho. Material: chapa cromada ou pintada,
acrílico iluminado, LED.

**Variantes distintas:** 28 capturas = **17 formas** (11 pares preto × prata da mesma forma; 018–021 são a mesma ideia em 2 alturas).

**O que temos hoje** (encaixe `andon`, ponto `MOUNT_ROOF`): `andon_kanji.tres` → `roof_sign_lightbox.glb`;
`andon_big_panel.tres` → `rear_panel_frame.glb`; `andon_ichiban_dx.tres` → `andon_ichiban_dx.glb` (deluxe, com acrílico
e texto trocável). O caminhão base já traz um andon de fábrica (銀河丸) no nó `truck_andon_panel`. Nenhum tem matriz de
LED nem canhões de luz.

**Peças novas** (encaixe `andon`, zona `roof`; nome na loja passa de "Andon" para "Deque frontal"):

| id | Nome (pt-BR) | Capturas | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `deck_cap_trio` | Capa de teto com 3 luzes | 001 | Capa baixa e arredondada, branca ou cromada, com 3 lâmpadas verdes na frente | 35 | 30 | 8 | 9.000 | 0 | Comum |
| `deck_kanji_rail` | Deque com letreiro e grade | 002–003 | Caixa baixa, grade de barras cromadas no topo, letreiro kanji que acende à noite | 70 | 40 | 16 | 18.000 | 20 | Incomum |
| `deck_led_box` | Deque LED com letreiro | 004–005 | Matriz de LED verde em cima e quadro de letreiro central | 85 | 40 | 22 | 26.000 | 20 | Incomum |
| `deck_led_panel` | Deque LED com painel liso | 006 | LED em cima e painel azul liso (lugar para o texto do jogador) | 85 | 45 | 20 | 24.000 | 20 | Incomum |
| `deck_led_cyan` | Deque LED com tela ciano | 007 | LED em cima e tela ciano chanfrada nas pontas | 80 | 40 | 22 | 25.000 | 20 | Incomum |
| `deck_art_band` | Deque com faixa e pinturas | 008–009 | Faixa neon ciano, letreiro vermelho e 2 painéis pintados nas pontas e nas laterais | 100 | 45 | 30 | 36.000 | 60 | Rara |
| `deck_led_columns` | Deque LED com colunas | 010–011 | Grade de LED e letreiro entre 2 colunas (azul ou ciano) | 95 | 45 | 26 | 32.000 | 60 | Rara |
| `deck_lace` | Deque com renda | 012–013 | LED, letreiro creme, colunas neon e friso vazado tipo renda embaixo | 100 | 45 | 28 | 34.000 | 60 | Rara |
| `deck_triple_sign` | Deque de 3 letreiros | 014–015 | 3 fileiras de LED, 2 letreiros em cima e 1 embaixo | 110 | 45 | 32 | 40.000 | 60 | Rara |
| `deck_eyebrow` | Deque com sobrancelhas neon | 016–017 | 2 arcos de neon no topo, LED e letreiro roxo | 95 | 40 | 30 | 38.000 | 60 | Rara |
| `deck_pillars` | Deque de colunas neon | 018–021 | Letreiro rosa entre 2 colunas ciano (variante baixa e alta) | 100 | 45 | 30 | 38.000 | 60 | Rara |
| `deck_cyan_frame` | Deque com moldura neon | 022–023 | Letreiro dentro de uma moldura de neon completa | 105 | 45 | 32 | 42.000 | 60 | Rara |
| `deck_painted_wings` | Deque com asas pintadas | 024 | LED, letreiro azul e painéis laterais com pintura (arte dos nossos murais) | 120 | 50 | 40 | 56.000 | 120 | Lendária |
| `deck_pods_square` | Par de canhões de luz quadrados | 025 | 2 tubos pretos com lente dupla quadrada | 45 | 35 | 14 | 16.000 | 20 | Incomum |
| `deck_pods_round` | Par de canhões de luz redondos | 026 | 2 tubos pretos com lente sextavada e 2 faixas | 45 | 35 | 14 | 16.000 | 20 | Incomum |
| `deck_pods_long` | Par de canhões longos | 027 | 2 tubos compridos com 2 fileiras de faixas neon | 55 | 35 | 18 | 22.000 | 20 | Incomum |
| `deck_pods_five` | Bateria de 5 canhões | 028 | 5 tubos com lente e painel de LED na ponta | 80 | 40 | 26 | 32.000 | 60 | Rara |

Cores (L/R): estrutura preta / cromada / prata com azul-marinho; LED verde ou ciano. Texto do letreiro: ver decisão 9.

---

## 2. Viseira – frontal (029–042)

> **FEITO na T-211/T-214** (as 14 viseiras). A T-233 conferiu: nada faltando.

**O que as imagens mostram.** Câmera de frente, um pouco acima, enquadrando o para-brisa inteiro. A viseira é uma **aba
fina sobre o para-brisa**, da largura da cabine (~2,3 m), 0,15–0,25 m de altura, saindo ~0,3 m para a frente.
Quase todas são a **mesma aba preta** com um desenho diferente de **neon ciano**: pontilhado (030), tracejado (031), 2 linhas
(032), traço-ponto (033), 1 linha (034), **em V** com degraus (035), faixa larga em V (036), V partido (037), 3 chevrons em
V (038), 2 barras (039). Exceções: 029 aba branca com 8 lanternas azuis (de dia), 040 **cromada em V** e 041 **cromada de
lâminas em zigue-zague** (estas duas com "De dia/De noite"), 042 **moldura de neon** que desce pelas colunas da cabine
com pontos verdes.

**Variantes distintas:** **14** (todas diferentes), mas só **4 modelos de base**: aba reta, aba em V, cromada de lâminas e moldura.
O resto é desenho de neon por cima (barato: mesma malha, faixas emissivas diferentes).

**O que temos hoje** (encaixe `visor`, `MOUNT_VISOR`): `visor_basic.tres` e `visor_gold_lights.tres` → `visor_sunshade.glb`;
`kw_visor.tres` → `kw_visor.glb`. Nenhuma com neon em desenho.

**Peças novas** (encaixe `visor`, zona `front`):

| id | Nome (pt-BR) | Capturas | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `visor_lamp_row` | Viseira com 8 lanternas | 029 | Aba branca/cromada com 8 lanternas pequenas embutidas | 45 | 45 | 10 | 12.000 | 0 | Comum |
| `visor_dash_short` | Viseira neon pontilhada | 030 | Aba preta, neon em pontos curtos | 40 | 40 | 8 | 9.000 | 0 | Comum |
| `visor_dash_long` | Viseira neon tracejada | 031 | Aba preta, neon em traços longos | 40 | 40 | 9 | 10.000 | 0 | Comum |
| `visor_twin_line` | Viseira de 2 linhas | 032 | 2 linhas retas de neon | 40 | 40 | 10 | 11.000 | 0 | Comum |
| `visor_morse` | Viseira traço-ponto | 033 | Neon em traço longo, pontos e traço longo | 40 | 40 | 10 | 11.000 | 0 | Comum |
| `visor_single_line` | Viseira de 1 linha | 034 | 1 linha reta de neon | 40 | 40 | 7 | 8.000 | 0 | Comum |
| `visor_v_step` | Viseira em V com degraus | 035 | Aba em V, neon em degraus | 55 | 45 | 16 | 18.000 | 20 | Incomum |
| `visor_v_band` | Viseira em V larga | 036 | Aba em V com faixa de neon larga | 55 | 45 | 15 | 17.000 | 20 | Incomum |
| `visor_v_split` | Viseira em V partida | 037 | V em 2 metades com degraus | 55 | 45 | 16 | 18.000 | 20 | Incomum |
| `visor_v_chevron` | Viseira de 3 chevrons | 038 | 3 faixas em V sobrepostas | 60 | 45 | 20 | 24.000 | 20 | Incomum |
| `visor_split_bars` | Viseira de 2 barras | 039 | 2 barras retas separadas no meio | 45 | 40 | 12 | 14.000 | 0 | Comum |
| `visor_chrome_v` | Viseira cromada em V | 040 | Aba cromada em V, sem neon | 80 | 70 | 14 | 22.000 | 20 | Incomum |
| `visor_chrome_louver` | Viseira cromada de lâminas | 041 | Várias lâminas cromadas em zigue-zague | 95 | 80 | 22 | 34.000 | 60 | Rara |
| `visor_neon_frame` | Moldura neon da cabine | 042 | Neon que contorna o topo e desce pelas colunas, com pontos verdes | 50 | 35 | 22 | 28.000 | 20 | Incomum |

---

## 3. Para-choque frontal (043–062)

> **FEITO na T-233**: as 11 peças no jogo (`accessories/front_t233.py`), na frente do nariz de fábrica de cada cabine, com a
> faixa do meio que estica/encolhe até o farol mais baixo, seta da frente e caixa da placa na peça.

**O que as imagens mostram.** Câmera em 3/4 pela frente-esquerda, baixa, enquadrando a frente da cabine e a roda
dianteira. 043 é o **de fábrica** (cromado com placa). As outras são para-choques **largos e baixos** que avançam
0,3–0,6 m e passam um pouco da largura da cabine, em 3 famílias:
- **leque baixo** (044–053): frente em leque com faixas azul-marinho/rosa, placa no centro, pares de lâmpadas âmbar,
  vermelhas ou douradas;
- **caixa alta** (054–057): bloco alto com lâmpadas âmbar, faixas ciano, degraus nas pontas;
- **deque com chapa xadrez** (059–062): para-choque em ângulo com tampa de chapa xadrez (dá para pisar), faixas e grade;
  058 é um **cromado liso** inteiro.
Cores: prata + azul-marinho ou preto + ciano.

**Variantes distintas:** 20 capturas = **11 formas novas** + a de fábrica.

**O que temos hoje** (encaixe `front_bumper`, `MOUNT_FRONT_BUMPER`): `fb_basic.tres` → `fb_standard_chrome.glb`;
`fb_chrome_steps.tres` e `fb_gold_wing.tres` → `fb_ornate_steps.glb`; `kw_bumper.tres` → `kw_bumper.glb`. Também
`front_lip` (`bumper_extension_lip`) e `aux_lights` (`aux_round_lamps_pair`) na mesma região.

**Peças novas** (encaixe `front_bumper`, zona `front`):

| id | Nome (pt-BR) | Capturas | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `fb_fan_plate` | Leque baixo com placa | 044–045 | Largo e baixo, faixas azuis, placa central, lâmpadas âmbar pequenas | 280 | 180 | 16 | 26.000 | 20 | Incomum |
| `fb_fan_amber` | Leque com caixas âmbar | 046–047 | 2 caixas de lâmpadas âmbar e faixas | 300 | 190 | 18 | 29.000 | 20 | Incomum |
| `fb_fan_red` | Leque de luz vermelha | 048 | Mais estreito, fileira de lâmpadas vermelhas | 280 | 180 | 16 | 27.000 | 20 | Incomum |
| `fb_fan_gold` | Leque de caixas douradas | 049–050 | 2 caixas douradas e faixas largas | 320 | 200 | 22 | 36.000 | 60 | Rara |
| `fb_fan_stripe` | Leque de faixas rosa | 051, 053 | Faixas rosa e azul nas pontas | 290 | 180 | 18 | 29.000 | 20 | Incomum |
| `fb_fan_chrome` | Leque cromado | 052 | Cromado com faixas azuis e grade central | 330 | 210 | 20 | 38.000 | 60 | Rara |
| `fb_box_amber` | Caixa alta âmbar | 054–055 | Bloco alto, 4 lâmpadas âmbar, faixa colorida | 380 | 240 | 22 | 42.000 | 60 | Rara |
| `fb_box_steps` | Caixa alta com degraus | 056–057 | Bloco com degraus nas pontas e faixas | 400 | 250 | 24 | 46.000 | 60 | Rara |
| `fb_smooth_chrome` | Cromado liso | 058 | Uma peça cromada lisa de ponta a ponta | 350 | 230 | 18 | 36.000 | 60 | Rara |
| `fb_deck_checker` | Deque de chapa xadrez | 059–060 | Em ângulo, tampa de chapa xadrez, faixas e grade | 450 | 260 | 30 | 58.000 | 120 | Lendária |
| `fb_deck_neon` | Deque xadrez com neon largo | 061–062 | Mesmo formato com painéis de neon grandes | 470 | 260 | 34 | 64.000 | 120 | Lendária |

---

## 4. Traseira (063–084)

> **FEITO na T-231 (2026-10-26)**: as 11 peças abaixo estão no jogo (`blender/scripts/accessories/rear_t231.py`), na
> largura do baú de todos os caminhões, com lanternas próprias e caixa da placa (ver `docs/DECISOES.md`, T-231).

**O que as imagens mostram.** Câmera em 3/4 por trás-esquerda, baixa e **inclinada** (horizonte torto), enquadrando as portas
do baú e o para-choque. A peça é o **para-choque traseiro junto com o painel de lanternas**: largura do baú (~2,4 m),
0,4–0,9 m de altura, abaixo das portas. 063 é o **de fábrica** (branco, placa laranja). As outras têm:
fileira de 9 **lanternas quadradas** sobre barra cromada (064), 2 fileiras de **redondas** (065–066), grade de quadradas
(067–068), redondas em grade (069–070), **alvos** com aro e cachos de 6 (071–072), 2 andares (073–074), fileiras com faixas
neon (075–076), placa neon (077–078), lanternas **"bala"** (079–080), bateria de lanternas **"torpedo"** em leque (081–082) e
um **painel grande cromado** com ~40 lanternas (083–084, "De dia/De noite"). Sempre há uma caixa da placa (azul ou ciano)
de um lado. Lanternas vermelhas, aros cromados.

**Variantes distintas:** 22 capturas = **11 formas novas** + a de fábrica.

**O que temos hoje** (`MOUNT_REAR`, `MOUNT_REAR_LAMPS`, `MOUNT_REAR_PLATE`): `rb_basic.tres` e `rb_chrome.tres` →
`rb_decorative.glb` (encaixe `rear_bumper`); `rear_lamp_cluster.tres` e `rear_tail_bar_dx.tres` (encaixe `rear_lamps`);
`rear_plate_custom` (`plate`), `mudflap_designed` (`mudflaps`), `rear_ornament_metal` (`rear_ornament`).

**Peças novas** (encaixe `rear_bumper`, zona `rear`; como no original, **trazem as lanternas**: ocupam também o lugar de
`rear_lamps` e o da placa, ver seção 13):

| id | Nome (pt-BR) | Capturas | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `rb_square_row` | Fileira de lanternas quadradas | 064 | 9 lanternas quadradas sobre barra cromada | 140 | 110 | 12 | 16.000 | 20 | Incomum |
| `rb_round_twin` | Duas fileiras redondas | 065–066 | 2 fileiras de lanternas redondas e caixa da placa | 220 | 150 | 20 | 28.000 | 20 | Incomum |
| `rb_square_grid` | Grade de quadradas | 067–068 | Blocos de lanternas quadradas 2 × 3 e placa | 230 | 150 | 20 | 29.000 | 20 | Incomum |
| `rb_round_grid` | Grade de redondas | 069–070 | Lanternas redondas em grade e placa | 230 | 150 | 22 | 31.000 | 60 | Rara |
| `rb_target` | Lanternas alvo | 071–072 | Lanternas com aro cromado e 2 cachos de 6 | 260 | 160 | 26 | 36.000 | 60 | Rara |
| `rb_double_deck` | Dois andares | 073–074 | 2 andares de redondas com friso cromado | 260 | 170 | 26 | 38.000 | 60 | Rara |
| `rb_neon_rows` | Fileiras com neon | 075–076 | Fileiras de lanternas e faixas de neon | 240 | 150 | 26 | 36.000 | 60 | Rara |
| `rb_neon_plate` | Placa neon | 077–078 | Placa iluminada e lanternas quadradas | 230 | 150 | 24 | 34.000 | 60 | Rara |
| `rb_bullet` | Lanternas bala | 079–080 | Lanternas compridas em pé e painéis | 270 | 170 | 30 | 44.000 | 60 | Rara |
| `rb_torpedo` | Bateria torpedo | 081–082 | ~24 lanternas compridas em leque | 300 | 170 | 36 | 52.000 | 120 | Lendária |
| `rb_grand_panel` | Painel grande cromado | 083–084 | Painel cromado alto com ~40 lanternas e frisos | 380 | 240 | 40 | 72.000 | 120 | Lendária |

---

## 5. Para-choque lateral (085–094)

> **FEITO na T-233**: as 8 saias no jogo (`accessories/skirt_t233.py`), só nos trechos livres entre as rodas (o tanque e a
> bateria de fábrica ficam de fora), em todos os caminhões.

**O que as imagens mostram.** Câmera **de lado, reta**, enquadrando o baú inteiro e o chassi. A peça vai **embaixo do baú,
entre as rodas** e depois da roda de trás (em 2 pedaços), ~0,3–0,5 m de altura, colada à longarina. 085 é **sem peça**
(fábrica); 086–087 são **barras cromadas** (3 trilhos; a mesma peça de noite e de dia); 088–094 são **neon**: 2 linhas
ciano (088), corrente de losangos (089), tracejado duplo (090), linhas com **arco na roda** (091), traços verdes + ciano
(092), "pedras" de luz ciano entre traços verdes (093), setas duplas com marcadores verdes (094).

**Variantes distintas:** **8 novas** + sem peça.

**O que temos hoje** (encaixe `side_skirts`, `MOUNT_SIDE_R/L`): `skirt_chrome.tres` → `skirt_chrome_panel.glb`,
`skirt_light_bar.tres` → `skirt_lit_neon.glb`, `side_bumper_dx.tres` → `side_bumper_dx.glb`. Também `underglow`
(`underglow_neon_dx`) e `side_box` (tanque, caixa) na mesma faixa. **Problema conhecido**: as saias têm 4,2 m fixos e
passam da frente do baú no Canter e no baú leve (`docs/ACESSORIOS.md`, T-172).

**Peças novas** (encaixe `side_skirts`, zonas `left` e `right`):

| id | Nome (pt-BR) | Capturas | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `skirt_chrome_rails` | Trilhos cromados | 086–087 | 3 barras cromadas entre as rodas | 240 | 190 | 14 | 28.000 | 20 | Incomum |
| `skirt_neon_twin` | Neon de 2 linhas | 088 | 2 linhas de neon | 120 | 80 | 16 | 20.000 | 20 | Incomum |
| `skirt_neon_diamond` | Corrente de losangos | 089 | Losangos de luz em fila | 130 | 80 | 18 | 24.000 | 20 | Incomum |
| `skirt_neon_dash` | Neon tracejado duplo | 090 | 2 fileiras de traços | 130 | 80 | 18 | 24.000 | 20 | Incomum |
| `skirt_neon_arch` | Neon com arco da roda | 091 | Linhas que contornam o arco da roda | 140 | 85 | 22 | 30.000 | 60 | Rara |
| `skirt_neon_green` | Traços verdes e ciano | 092 | Traços verdes em cima, faixa ciano embaixo | 130 | 80 | 18 | 25.000 | 20 | Incomum |
| `skirt_neon_gems` | Pedras de luz | 093 | Losangos ciano entre traços verdes | 150 | 85 | 22 | 32.000 | 60 | Rara |
| `skirt_neon_arrows` | Setas duplas | 094 | 2 fileiras de setas com marcadores verdes | 150 | 85 | 24 | 34.000 | 60 | Rara |

---

## 6. Foguete (095–101)

> **FEITO na T-231**: os 7 foguetes estão no jogo (`accessories/rocket_t231.py`), um par por compra, esticados pelo
> comprimento do baú (encaixes `rocket_r`/`rocket_l` medidos por raios). Só baú fechado.

**O que as imagens mostram.** Câmera em 3/4 por cima do baú, por trás. A peça são **2 tubos ao longo das bordas do teto
do baú**, do comprimento do baú, ~0,15–0,25 m de diâmetro, pretos ou cromados, com **ponta de neon ciano** atrás: tubos
redondos (095), quadrados com ponta dupla (096), 2 pares (097), tubo com fita de **LED verde** (098), calhas baixas com
neon tracejado (099), tubos com neon tracejado (100) e uma **moldura** em volta do teto com faixa de neon e luzes atrás (101).

**Variantes distintas:** **7**.

**O que temos hoje:** nada (o `fumi_wing` do encaixe `roof_wing` é um aerofólio da cabine). Ponto mais próximo:
`MOUNT_BODY_ROOF` (teto do baú) e `MOUNT_REAR_ROOF`.

**Peças novas** (encaixe novo `rocket`, zona `roof`; **estica no comprimento do baú**, seção 13):

| id | Nome (pt-BR) | Capturas | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `rocket_round` | Foguete redondo | 095 | 2 tubos redondos com ponta neon | 60 | 50 | 10 | 12.000 | 0 | Comum |
| `rocket_square` | Foguete quadrado | 096 | 2 tubos quadrados com ponta dupla | 65 | 50 | 11 | 13.000 | 0 | Comum |
| `rocket_twin` | Foguete duplo | 097 | 2 pares de tubos | 90 | 60 | 14 | 18.000 | 20 | Incomum |
| `rocket_led` | Foguete com LED | 098 | Tubos com fita de LED verde | 70 | 45 | 16 | 20.000 | 20 | Incomum |
| `rocket_flat_neon` | Calha neon | 099 | Calhas baixas com neon tracejado | 55 | 40 | 16 | 19.000 | 20 | Incomum |
| `rocket_neon_dash` | Foguete neon tracejado | 100 | Tubos redondos com neon tracejado | 65 | 45 | 18 | 22.000 | 20 | Incomum |
| `rocket_frame` | Moldura de teto | 101 | Moldura em volta do teto com neon e luzes atrás | 110 | 60 | 26 | 34.000 | 60 | Rara |

---

## 7. Luzes do baú: lateral direita, lateral esquerda, superior (102, 103, 104)

> **FEITO na T-231**: os 3 contornos estão no jogo (módulo de 0,30 m repetido nas faixas medidas por raios em cada
> caminhão, `box_light_*`). Só baú fechado.

**O que as imagens mostram.** 102 de lado (direita), 103 de lado (esquerda, aparece a porta lateral do baú), 104 de cima.
É um **contorno tracejado de LED verde** nas 4 bordas de cada face do baú, colado na quina, sem relevo.

**Variantes distintas:** **1 desenho em 3 lugares** (cor trocável).

**O que temos hoje:** nada no baú (`roof_light_frame_halo`, encaixe `roof_frame`, é uma moldura no teto da **cabine**).

**Peças novas** (3 encaixes novos `box_light_r`, `box_light_l`, `box_light_top`, zonas `right`, `left`, `roof`; geradas
pelo tamanho do baú, então servem em qualquer caminhão):

| id | Nome (pt-BR) | Captura | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `boxlight_dash_r` | Contorno de luz – direita | 102 | LED tracejado em volta da lateral direita | 12 | 15 | 6 | 6.000 | 0 | Comum |
| `boxlight_dash_l` | Contorno de luz – esquerda | 103 | Idem, lateral esquerda (contorna a porta) | 12 | 15 | 6 | 6.000 | 0 | Comum |
| `boxlight_dash_top` | Contorno de luz – teto | 104 | Idem, borda do teto | 12 | 15 | 6 | 6.000 | 0 | Comum |

Cores (L/R): verde, ciano, rosa, âmbar.

---

## 8. Retrovisor (105–110)

> **FEITO na T-233**: as 6 hastes no jogo (`accessories/mirror_t233.py`), até 0,50 m para fora e 0,60 m à frente da cabine;
> o espelho de fábrica some quando a haste está montada.

**O que as imagens mostram.** Câmera em 3/4 pela frente-esquerda, enquadrando a cabine. São **hastes grandes de retrovisor**
(ミラーステー) que saem da quina da cabine e avançam ~0,4–0,9 m para a frente e para o lado: haste em L simples (105),
**treliçada** (106), moldura retangular (107), moldura grossa (108), treliça vazada tipo corrente (109) e uma moldura
**gigante treliçada** que vai até a frente da cabine (110). Cromadas, todas com "De dia/De noite".

**Variantes distintas:** **6**.

**O que temos hoje:** nada como peça. Os espelhos de fábrica fazem parte da malha da cabine (nós por material), então
não dá para trocar o espelho sem regerar os `.glb` (seção 13).

**Peças novas** (encaixe novo `mirror_stay`, zona `front`, dos 2 lados):

| id | Nome (pt-BR) | Capturas | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `mirror_stay_l` | Haste em L | 105 | Haste cromada simples em L | 25 | 40 | 6 | 7.000 | 0 | Comum |
| `mirror_stay_truss` | Haste treliçada | 106 | Haste de treliça cromada | 35 | 40 | 10 | 12.000 | 0 | Comum |
| `mirror_stay_frame` | Moldura retangular | 107 | Moldura em retângulo em volta do espelho | 35 | 45 | 9 | 11.000 | 0 | Comum |
| `mirror_stay_box` | Moldura grossa | 108 | Moldura quadrada de tubo grosso | 45 | 55 | 10 | 14.000 | 0 | Comum |
| `mirror_stay_chain` | Treliça vazada | 109 | Treliça vazada tipo corrente | 40 | 40 | 12 | 16.000 | 20 | Incomum |
| `mirror_stay_grand` | Moldura gigante | 110 | Moldura treliçada larga até a frente da cabine | 60 | 45 | 18 | 26.000 | 20 | Incomum |

---

## 9. Escada (111–113)

> **FEITO na T-233**: as 3 escadas no jogo (`accessories/ladder_t233.py`), na lateral do baú atrás da quina da frente, por
> fora do contorno de LED. Só baú fechado.

**O que as imagens mostram.** Câmera em 3/4 pela frente, alta. **Escadas verticais** presas na quina da frente do baú,
logo atrás da cabine, do chassi até o topo do baú (~2,5 m), 0,2–0,3 m de largura: com **trilhos de neon ciano** (111),
com **luzes verdes** nos degraus (112) e **cromada treliçada** (113). Aparece uma de cada lado.

**Variantes distintas:** **3**.

**O que temos hoje:** nada (o encaixe `steps` é o degrau da porta da cabine).

**Peças novas** (encaixe novo `ladder`, zonas `left` e `right`):

| id | Nome (pt-BR) | Capturas | Descrição | Peso kg | Durab. | Destaque | Preço ¥ | Fama | Raridade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `ladder_neon` | Escada de neon | 111 | Trilhos de neon ciano | 30 | 30 | 12 | 14.000 | 0 | Comum |
| `ladder_green` | Escada de luzes verdes | 112 | Degraus com luzes verdes | 30 | 30 | 12 | 14.000 | 0 | Comum |
| `ladder_chrome` | Escada cromada | 113 | Treliça cromada | 45 | 50 | 10 | 16.000 | 20 | Incomum |

---

## 10. Pintura (mural das laterais) (114–133)

**O que as imagens mostram.** Câmera **de lado, reta**, o baú inteiro (proporção ~2,6 : 1) com o mural ocupando a lateral.
Pintura em aerógrafo, cheia até as bordas, com figura grande, fundo de nuvens/ondas em degradê e contorno claro.
Temas: **dragão** (114–117, verde/azul em nuvens e ondas), **kabuki** (118–123, rosto pintado de ator com cabeleira
branca ou vermelha, flores), **demônio/hannya** (124–125, máscara com chifres), **mulher de quimono** (126–129, cabelo
longo, leque, montanhas), **ave/fênix** (130), **tigre** (131), **onda grande** (132) e **guerreiro/deus** (133).

**Variantes distintas:** **20** (8 temas).

**O que temos hoje:** encaixe `mural` (zonas `left`/`right`, sem durabilidade): `mural_waves.tres` → `panel_japanese_theme.glb`
e `mural_lightning.tres` → `side_panel_decor.glb` (painéis geométricos), mais o PNG único `murals/mural_side.png` (1024 × 256)
no material `mural`. Brilho à noite pronto (`MuralGlow`, T-155).

**Peças novas:** 12 murais nossos (plano na seção 14). **As capturas do documento não serão usadas nem recortadas.**

**FEITO (T-232):** 12 murais `mural_*` com desenho diferente em cada lado, arte nossa por código (`docs/CREDITOS_MURAIS.md`,
`docs/capturas_t232/`).

---

## 11. Pintura no teto (134–142)

**O que as imagens mostram.** Vista de cima do teto do baú (a cabine aparece na borda esquerda). Cada uma é um
**letreiro de caligrafia** em kanji grandes (pincel, com contorno branco) sobre **fundo pintado** de flores, ondas ou
nuvens em degradê. Proporção ~2,4 : 1.

**Variantes distintas:** **9**.

**O que temos hoje:** nada. O teto do baú não tem material próprio (`paint_white_box`). **Na nossa câmera de corrida, que
fica atrás e acima do baú, o teto aparece muito**: é uma peça barata com muito retorno.

**Peças novas** (encaixe novo `roof_paint`, zona `roof`, sem durabilidade; arte gerada por nós com fonte livre, seção 15):
9 letreiros, `roofpaint_01` … `roofpaint_09`. Peso 0, destaque 10–16, preço 12.000–20.000 ¥ (Fama 0 ou 20; Comum ou
Incomum). As **frases** são decisão do Marco (seção 17, decisão 7).

**FEITO (T-232):** `roofpaint_01` … `roofpaint_09` com as 9 frases aprovadas, na vertical ao longo do teto (Yuji Syuku).

---

## 12. Pintura da traseira, "focado no rosto" (143–147)

**O que as imagens mostram.** Vista de trás, reta, só as **portas do baú** (proporção ~0,9 : 1, com as frestas das portas
visíveis). As 5 são **dragões** com a **cabeça centralizada** e kanji na lateral.

**Variantes distintas:** **5** (todas do tema dragão).

**O que temos hoje:** nada. As portas são cinza lisas (`box_metal`). É o que o jogador mais vê na corrida.

**Peças novas** (encaixe novo `rear_paint`, zona `rear`, sem durabilidade): uma por mural, **recortada do nosso mural
com o rosto no centro** + frestas e ferragens das portas por cima (`rearpaint_<tema>`). Destaque 14–24, preço
15.000–28.000 ¥.

**FEITO (T-232), com a decisão 8 do Marco (arte separada, não recorte do mural):** 12 traseiras `rearpaint_*` (rostos e
máscaras: dragão, tigre, hannya, oni, kitsune, tengu, Noh, kabuki, gueixa, leão do kabuki, fênix, carpas) com kanji vertical.

---

## 13. Plano de encaixe (sockets) em todos os caminhões

Problema de hoje: cada peça é um `.glb` de tamanho fixo pendurado num ponto `MOUNT_*`. Num baú mais curto ou numa cabine
mais estreita ela sobra (saias no Canter), e nada impede duas peças de ocuparem o mesmo espaço.

### 13.1 Encaixe = ponto + caixa-limite + regra de escala

Para **cada caminhão** (16 combinações baú × cabine, Canter, carreta) o script do Blender que já gera os `.glb`
(`build_truck_3d.py`) passa a medir a cabine e o baú e grava um arquivo ao lado:
`truck/<modelo>.sockets.json`. Para cada encaixe:

| Campo | O que é |
| --- | --- |
| `node` | ponto de montagem (`MOUNT_*` existente, ou novo: `MOUNT_MIRROR_R/L`, `MOUNT_LADDER_R/L`, `MOUNT_ROCKET`, `MOUNT_BOX_TOP`) |
| `box` | **caixa-limite** (volume) no espaço do caminhão, onde a peça tem de caber |
| `span` | medidas úteis: comprimento do baú, largura da cabine, altura livre |
| `exclusive` | encaixes que dividem o mesmo volume de propósito (ex.: deque × luzes de teto) |

Os pontos novos são criados no jogo a partir do JSON (como o `TruckNode.extra_mounts` da T-126), **sem regerar os 20
`.glb`** para isso. Os únicos `.glb` que precisam ser regerados são os da seção 13.4.

Caixas-limite iniciais (caminhão base com cabine chata; o script calcula as dos outros):

| Encaixe | Onde | Volume aproximado (largura × altura × fundo) |
| --- | --- | --- |
| `andon` (deque) | teto da cabine | 2,3 × 1,0 × 1,6 m |
| `roof_lights` | faixa da frente do teto da cabine | 2,3 × 0,35 × 0,3 m |
| `visor` | sobre o para-brisa | 2,4 × 0,45 × 0,5 m |
| `mirror_stay` (cada lado) | quina da frente da cabine | 0,6 × 1,4 × 1,0 m |
| `front_bumper` | frente, embaixo | 2,7 × 0,8 × 0,7 m |
| `ladder` (cada lado) | quina da frente do baú, atrás da cabine | 0,35 × 2,6 × 0,25 m |
| `rocket` | bordas do teto do baú | largura do baú × 0,35 × comprimento do baú |
| `box_light_*` | casca de 3 cm sobre cada face do baú | face inteira |
| `side_skirts` (cada lado) | entre as rodas e atrás da roda | 0,35 × 0,6 × (vão entre eixos) |
| `rear_bumper` (com lanternas) | traseira, embaixo das portas | 2,5 × 1,0 × 0,45 m |
| `mural`, `roof_paint`, `rear_paint` | material da face do baú | sem volume (textura) |

### 13.2 Regras que o teste garante

1. As caixas-limite de encaixes diferentes **não se cruzam**, exceto os pares declarados em `exclusive`.
2. Par exclusivo (ex.: deque alto × coroa de luzes de teto × aerofólio; para-choque traseiro com lanternas × `rear_lamps`
   × placa; escada × escapamentos altos atrás da cabine): ao instalar um, a garagem tira o outro **com aviso**
   ("Este deque ocupa o lugar das luzes de teto"). Nada some sem o jogador ver.
3. Toda peça, depois da escala, cabe **inteira** na caixa do seu encaixe (folga 2 cm).
4. Nenhuma peça entra na lataria (cabine, baú, rodas, para-brisa), com a mesma folga que o Blender já checa na biblioteca.
5. Peças de lado são simétricas (L = espelho de R).

### 13.3 Escala automática

Cada peça leva no `catalog.json` uma regra `fit`:

| Regra | Para quê | Como |
| --- | --- | --- |
| `stretch9` | saias, foguete, contorno do baú, moldura de teto | a peça vem em 3 pedaços (ponta, meio, ponta); só o meio estica até o comprimento do baú; as pontas não deformam |
| `repeat` | fileiras de lâmpadas, LED, degraus da escada | o módulo se repete a cada N cm (lâmpada redonda nunca vira oval) |
| `uniform` | deque, viseira, para-choques, retrovisor | escala igual nos 3 eixos para a largura da cabine, limitada a 0,85–1,15; fora disso o encaixe mostra "não cabe neste caminhão" |
| `face` | contorno do baú, pinturas | gerado pelo tamanho da face (sempre cabe) |

Casos conhecidos: **Canter** (cabine curta e baú de ~4 m; escala ~0,88, como os escapamentos), **cabine curta/jac**
(mais estreitas), **americana** (capô: viseira e deque mais altos), **graneleira** (não tem baú fechado: foguete, contorno
e pinturas do baú **não se aplicam**; mostra "só para baú"), **carreta** (está guardada; o JSON é gerado, mas o teste só
vira obrigatório quando ela for jogável).

### 13.4 O que precisa regerar nos `.glb` do caminhão (passo 2)

- Separar em nós próprios o que uma peça nova substitui: **espelhos de fábrica** (`STOCK_MIRROR_R/L`), **andon de fábrica
  da frente** (`STOCK_ANDON_FRONT`), **para-choques de fábrica** e **lanternas de fábrica**. Assim a peça esconde só o de fábrica.
- Materiais novos com UV na face: `mural_roof` (teto do baú) e `mural_rear` (portas traseiras), além do `mural` atual.
  O `mural` atual passa a ter **um PNG por lado** (esquerda/direita), se o Marco quiser (decisão 6).
- Comando de sempre: `bash tools/build_all_trucks.sh` (20 `.glb`, ~2,8–3,1 MB cada).

### 13.5 Teste automático e relatório

- `game/tests/test_part_fit.gd` (sem tela): para **cada caminhão × cada peça**: monta, aplica a escala, mede a caixa da peça
  (AABB da malha) e confere as regras 1–5 da 13.2. Falha se alguma peça sair do volume ou cruzar outro encaixe.
- `game/tools_dev/report_part_fit.gd` grava **`docs/REPORT_ENCAIXE.md`**: uma tabela caminhão × encaixe com OK / escala
  usada / "não cabe" / conflito, e a lista de pares exclusivos. O Marco abre esse arquivo para saber o que serve em qual caminhão.
- Folha de contato por caminhão com todas as peças de um lote montadas (frente, lado, trás, 3/4; dia e noite), no padrão
  das folhas da T-172.

### 13.6 Dano sem buraco

Hoje a peça quebrada **some** (`visible = false`). Se ela escondeu a peça de fábrica, fica um buraco. Proposta:

| Estado | O que aparece |
| --- | --- |
| Inteira | a peça |
| Amassada | cromo vira aço fosco, lâmpadas a 50%, inclinação de 2–4°, leve deformação (já existe em parte) |
| Quebrada | **versão quebrada** da peça (malha gerada no Blender: torta 6–10°, metade das lâmpadas apagadas, pedaço faltando) **ou**, se a peça ficar pequena demais, volta a **peça de fábrica amassada**; nunca o vazio |
| Ao quebrar | pedaços voando (efeito que já existe, `impact_fx`) |

O teste confere que, para todo encaixe, o estado "quebrada" deixa geometria visível no lugar.

---

## 14. Plano dos murais (12 iniciais, 2 por tema)

**Regras:** nenhuma imagem do documento é usada ou recortada. Os murais são **arte nossa** feita a partir de obras de
**domínio público** (gravuras ukiyo-e e pinturas japonesas de artistas mortos há mais de 100 anos), baixadas de acervos
que liberam a imagem para uso comercial, e **repintadas** pelo nosso processo. Cada uma é registrada em
**`docs/CREDITOS_MURAIS.md`** (artista, título, data, museu, número do objeto, link, licença, o que mudamos).

**Acervos aceitos (imagem liberada para uso comercial):**

| Acervo | Licença das imagens de domínio público |
| --- | --- |
| The Met (Open Access) | uso livre, inclusive comercial ([política](https://www.metmuseum.org/hubs/open-access)) |
| Art Institute of Chicago | CC0 ([política](https://www.artic.edu/open-access/open-access-images)) |
| Rijksmuseum, Cleveland Museum of Art, Smithsonian Open Access | CC0 / domínio público (conferir a marcação de cada obra) |
| Wikimedia Commons | só arquivos marcados como domínio público **e** vindos de um dos acervos acima |

**Temas propostos (6 × 2 = 12) e obras-base candidatas** (a escolha final de cada obra e o link entram no
`CREDITOS_MURAIS.md` na hora de fazer; só o primeiro item foi conferido nesta pesquisa):

| Tema | Mural A | Mural B | Obras-base candidatas (domínio público) |
| --- | --- | --- | --- |
| Ondas / Fuji | `mural_nami_fuji` (onda grande e Fuji) | `mural_nami_uzu` (redemoinho) | Hokusai, *Sob a onda de Kanagawa*, c. 1830–32, The Met, objeto JP1847 ([link](https://www.metmuseum.org/art/collection/search/45434), conferido); Hiroshige, redemoinhos de Naruto |
| Dragão | `mural_ryu_kumo` (dragão nas nuvens) | `mural_ryu_nami` (dragão e ondas) | dragões do *Hokusai Manga*; dragões de Kawanabe Kyōsai (m. 1889) |
| Tigre | `mural_tora_take` (tigre no bambu) | `mural_tora_yuki` (tigre na neve) | tigres de Kishi Ganku e Maruyama Ōkyo; Kuniyoshi, *Katō Kiyomasa caçando o tigre* |
| Guerreiro / kabuki | `mural_musha` (guerreiro) | `mural_kabuki` (ator) | Kuniyoshi, série dos *108 heróis do Suikoden*; Sharaku, retratos de atores (1794) |
| Mulher de quimono | `mural_bijin_ogi` (com leque) | `mural_bijin_tsuki` (sob a lua) | Utamaro e Eishi, retratos de mulheres (bijin-ga) |
| Fênix / aves | `mural_hoo` (fênix) | `mural_tsuru` (grous) | fênix do *Hokusai Manga*; aves e flores de Hiroshige |
| Reserva | `mural_hannya` (demônio) | `mural_koi` (carpas) | Hokusai, *Warai-hannya* (série *Hyaku monogatari*, c. 1831) |

**Processo (Blender + numpy, determinístico, sem Pillow):**
1. Baixar a obra em alta para `docs/Referencias/murais_pd/` (local) e anotar o crédito.
2. Script `blender/scripts/build_murals.py`: recorta a figura, compõe no formato do baú (figura grande a 55–65% da largura,
   como no original), **estende o fundo por código** (nuvens, ondas seigaiha, degradê do céu, flores), ajusta as cores
   para a paleta Dekotora (saturação de aerógrafo, azul-noite, rosa/ciano, dourado), põe o **contorno claro** em volta da
   figura e a moldura.
3. Saídas por mural: lateral 2048 × 512 (PC Ultra) e 1024 × 256 (celular), recorte da **traseira com o rosto no centro**
   (512 × 512, seção 12) e miniatura para a loja. Folha de contato com os 12 para o Marco aprovar antes de entrar no jogo.

**Pintura do teto (9):** gerada por código: fundo pintado (flores, ondas, nuvens) + caligrafia com uma fonte livre de
estilo pincel (família **Yuji** — Yuji Syuku, Yuji Boku, Yuji Mai — da Kinuta Font Factory, licença OFL, no Google Fonts;
entra em `game/assets/fonts/` com a licença, como a Noto Sans JP) + contorno branco. As frases são decisão do Marco.

## 15. Texturas: procedurais primeiro

Tudo o que der é feito por código, sem foto:

| Superfície | Como | Já existe? |
| --- | --- | --- |
| Cromo | matcap de estúdio (`matcap_chrome_studio.png`) | sim (T-138) |
| Inox escamado "uroko" | mapa de normais numpy | sim (T-172, `side_bumper_dx`) |
| Chapa xadrez (para-choque deque) | mapa de normais numpy | sim (`diamond_plate` dos caminhões) |
| Matriz de LED (deque, foguete) | **um shader** com grade de pontos pela UV (liga/desliga em padrão, cor por parâmetro) | novo |
| Neon (faixas, tracejados, setas, losangos) | tiras emissivas + brilho aditivo (`AccessoryGlow`) | sim (T-172) |
| Acrílico do letreiro com kanji | atlas de letreiros 1024² gerado por código com Noto Sans JP / Yuji | parecido (`andon_ichiban_dx`) |
| Lanternas (redonda, quadrada, bala, torpedo, alvo) | lente por revolução com degraus (Fresnel) | sim (`lib/deluxe_geo.py`) |
| Pinturas (mural, teto, traseira) | seção 14 | novo |

## 16. Desempenho, esforço e ordem de entrega

### 16.1 Custo de desempenho (meta, a medir no passo 2)

Hoje o caminhão decorado já custa ~212–229 chamadas de desenho (T-172). As peças novas não podem dobrar isso.

| Regra | Como |
| --- | --- |
| Triângulos por peça | ≤ 4.500 (≤ 6.000 nas "lendárias"); caminhão com tudo novo instalado ≤ +35 mil triângulos |
| Materiais por peça | no máximo 3, todos compartilhados: cromo, pintura (cor por vértice) e neon/LED (**um** material para todas as cores, cor por vértice). Meta: caminhão completo ≤ +15 chamadas sobre o decorado de hoje |
| LOD | malha LOD1 (≤ 35% dos triângulos) a partir de ~35 m (os rivais quase sempre estão longe); peças pequenas (retrovisor, escada, contorno do baú) somem a ~90 m com esmaecimento, como as rodas de peça |
| Atlas | 1 atlas de letreiros e painéis pintados (1024², comprimido) para todos os deques; murais 1024 × 256 no celular (~0,3 MB cada na memória de vídeo, comprimido) e 2048 × 512 só no PC Ultra; só 2 caminhões no duelo = 2 murais carregados |
| Luzes | nenhuma luz real nova; tudo emissão + brilho aditivo (custo zero de sombra) |
| Medida | `measure_t172.sh` adaptado: corrida noturna, modo médio, caminhão "tudo instalado" × caminhão de hoje; celular quando o Marco testar o APK |

### 16.2 Esforço e ordem (sessões do especialista; "sessão" = uma tarefa grande como a T-172)

Ordem pensada no que a câmera da corrida mais mostra (atrás e acima do baú).

| Etapa | O quê | Peças | Esforço |
| --- | --- | --- | --- |
| 2 | Base: `sockets.json`, caixas-limite, escala automática, separar peças de fábrica nos `.glb`, materiais do teto/traseira, dano sem buraco, teste + `REPORT_ENCAIXE.md` | 0 | 2 sessões |
| 3 | Traseira + foguete + contorno do baú — **FEITO (T-231)** | 11 + 7 + 3 = 21 | 2 sessões |
| 4 | Murais + pintura da traseira + pintura do teto (com `CREDITOS_MURAIS.md`) — **FEITO (T-232)** | 12 + 12 + 9 = 33 | 2–3 sessões |
| 5 | Deque frontal (shader de LED, atlas de letreiros) | 17 | 2 sessões |
| 6 | Frente: viseira (4 bases), para-choque, retrovisor, escada, saias — **FEITO (T-211 viseiras; T-233 o resto)** | 14 + 11 + 6 + 3 + 8 = 42 | 3 sessões |
| 7 | Cor L/R por peça, raridade, filtros da loja, rede (descritor + protocolo novo), APK, medida no celular | — | 1–2 sessões |
| **Total** | | **113 peças** | **12–14 sessões** |

O trabalho mecânico (113 `.tres`, textos pt-BR, folhas de contato, conferências) vai para o ajudante.

## 17. PRECISA DECISÃO (perguntas ao Marco; nada disso foi decidido)

1. **"Refazer toda a personalização"**: as 53 peças de hoje **saem** ou **ficam** junto com as novas?
   Recomendação: ficam no save (ninguém perde peça comprada) e saem da loja aos poucos como "Clássicas"; as que repetem
   uma forma nova (ex.: `visor_basic`) viram a "de fábrica".
2. **Lacunas: o documento não tem** rodas/calotas, escapamento, grade/frente da cabine, buzina, interior, adesivos.
   Para cada uma: (a) fica como está hoje (6 calotas, escapamento visual + 4 sons, 2 grades, 6 buzinas, 6 adesivos,
   sem interior), (b) o Marco manda outro documento com capturas, ou (c) eu proponho com base na pesquisa da T-190
   (`docs/REFERENCIA_PERSONALIZACAO.md`).
3. **Caçamba** ("estruturas de metal polido atrás e protetor de escapamento cromado"): não há seção disso no documento.
   É a estrutura do chassi atrás do baú? A graneleira? Mande uma foto ou o número de uma captura.
4. **Raridade**: só etiqueta da faixa de preço (proposta) ou um jeito de conseguir a peça (vencer rival, sorteio)?
5. **Cor L/R**: quais conjuntos? Proposta: estrutura preta / cromo / prata-azul / dourado e neon ciano / verde / rosa /
   âmbar / branco, **sem custo** para trocar. (Precisa ir para a rede para os outros jogadores verem.)
6. **Murais**: os 6 temas da seção 14 servem (dragão, tigre, ondas/Fuji, guerreiro-kabuki, mulher de quimono, fênix/aves;
   hannya e carpas de reserva)? Pode usar obra de domínio público **como base repintada** (não idêntica)? Um mural para
   os 2 lados ou **um por lado**?
7. **Pintura do teto**: quais 9 frases? Sugestões: 一番星 (estrela número um), 男花道 (caminho de honra), 爆走 (corrida
   louca), 御意見無用 (dispenso opinião), 唯我独尊 (único no mundo), 義理人情 (dever e coração), 浪漫街道 (estrada romântica),
   天下御免 (licença do mundo), 夜明けまで (até o amanhecer). Pode adicionar a fonte Yuji (OFL) ao projeto?
8. **Pintura da traseira**: recortar do mural lateral escolhido (automático, como proposto) ou arte separada?
9. **Letreiro do deque**: texto livre digitado pelo jogador ou lista de nomes prontos?
10. **Quantidade e ordem**: 113 peças é muito. Começar pela ordem da seção 16.2 (traseira, foguete, contorno, murais) e
    parar a cada lote para o Marco aprovar a folha de contato?
11. **Carreta**: entra agora (está guardada) ou só quando ela virar jogável?
12. **Conflitos**: tirar a peça que conflita **com aviso** (proposto) ou não deixar instalar até o jogador tirar?

---

## 18. Cores L/R e preços (T-211, PROPOSTA para o Marco aprovar; já está no jogo para testar)

Decisão 5 do Marco: trocar a cor TEM preço. Cada peça da oficina vem com uma **cor de fábrica** (de graça; voltar para
ela também é de graça). Trocar para outra cor da tabela custa o preço da cor, a cada troca. Uma "cor" pinta os 4 papéis
da peça: estrutura, painel, matriz de LED e neon (como os pares preto + ciano / prata + azul-marinho das capturas).
Dados: `game/data/deco_colors/*.tres` (gerados por `python tools/gen_t211_data.py`).

| Cor | Faixa | Preço ¥ | Estrutura | Painel | LED | Neon |
| --- | --- | --- | --- | --- | --- | --- |
| Preto + ciano | comum | 2.000 | preto laca | preto | verde | ciano |
| Preto + verde | comum | 2.000 | preto laca | preto | verde | verde |
| Branco + azul | comum | 2.000 | branco | azul-marinho | azul | azul |
| Prata + azul-marinho | comum | 2.000 | prata | azul-marinho | verde | azul |
| Cromo + ciano | metálica | 6.000 | cromo | preto | verde | ciano |
| Cromo + rosa | metálica | 6.000 | cromo | preto | rosa | rosa |
| Dourado + âmbar | metálica | 6.000 | dourado | preto | âmbar | âmbar |
| Grafite + violeta | metálica | 6.000 | grafite | preto | violeta | violeta |
| Preto + rosa neon | neon | 8.000 | preto laca | preto | rosa | rosa |
| Vermelho + amarelo neon | neon | 8.000 | vermelho | preto | amarelo | amarelo |

Referência de preço: a peça mais barata do lote custa 8.000 ¥ e um frete de Kanto paga 20–45 mil ¥ (`BALANCEAMENTO.md`):
a cor comum é ~1/4 da peça barata, a metálica ~1/2, a neon ~2/3. Letreiro do deque (lista de 12 nomes prontos:
銀河丸, 一番星, 爆走丸, 龍神丸, 桜吹雪, 天翔丸, 浪花節, 男一匹, 夜桜, 鳳凰丸, 雷神丸, 唐獅子): **de graça** (proposta).

## 19. Proposta para as lacunas (rodas, escapamento, grade, buzina, interior, adesivos) — **FEITO (T-234)**

T-234: as 3 propostas de cada categoria viraram peças (grade refeita pela referência do Marco, buzina em cima da
viseira); ver `docs/DECISOES.md` (T-234) e `docs/capturas_t234/`.

Decisão 2 do Marco: propor um design novo no estilo das capturas, mostrar em folha ANTES de modelar. Esboços de forma
e cor (blocos simples, de noite para ver o neon): **`docs/capturas_t211/proposta_lacunas.png`** (uma imagem por
categoria em `proposta_<categoria>.png`). Gerar: `blender -b --factory-startup -P blender/scripts/t211_proposals.py --
--out PASTA_ABS`. Todas com cor L/R pela mesma tabela da seção 18 e luzes que acendem de noite.

| Categoria | 1 | 2 | 3 | Encaixe / observação |
| --- | --- | --- | --- | --- |
| Rodas | Disco cromado de 10 furos com **anel de LED** na borda | Estrela de 8 raios cromados sobre aro dourado | Calota funda cromada com **lábio de neon** e "spinner" dourado | `hubcaps`: nas rodas de fora (gira com o pneu, T-133); isenta da zona da roda |
| Escapamento | Chaminé dupla cromada com **ponta neon** e protetor dourado | Chaminé em J com protetor perfurado e **fendas de luz âmbar** | Saída lateral tripla com ponta acesa | `exhaust_stacks_r/l` (vão cabine–baú) ou embaixo; som segue `ExhaustDef.sound_profile` |
| Grade | Barras verticais cromadas com **friso de LED** em cima | Colmeia dourada com **sol aceso** no meio | Lâminas douradas inclinadas com colunas de neon nos lados | `grille`: entre os faróis, sem cobrir faróis/setas/placa |
| Buzina | Corneta tripla cromada (3 notas) | Par de cornetas longas douradas | Buzina de navio com aro âmbar | No teto ou atrás da cabine; o som é o `HornCatalog` (6 buzinas de hoje) |
| Interior | Cortina franzida vermelha com varão dourado (aparece pelo para-brisa) | **Lustre** de cristal âmbar no teto da cabine | Estofado capitonê vermelho com botões dourados e friso neon | `interior`: dentro da cabine, visto de fora pelo vidro (custo baixo) |
| Adesivos | Kanji de pincel (天下御免 etc., fonte Yuji) | Labaredas | Sol nascente | `decals` (sistema de hoje, `DecalPlacer`), com as frases da decisão 7 |
