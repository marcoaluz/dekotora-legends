# Análise dos modelos de `docs/Modelos/Road_pontes` (T-159)

Data: 2026-10-20. Pedido do Marco: "quero que analise estes novos modelos que podemos implementar no jogo, como ponte,
outdoor, rodovia e túnel". **Esta tarefa é só análise: nada entrou no jogo.** Cada arquivo foi aberto no Blender 5.2.2 em
segundo plano, sem salvar nada de volta na pasta original (a pasta continua fora do Git).

Imagens (folhas com 4 vistas cada; a **caixa vermelha** é um caminhão de 2,5 x 12 x 3,8 m, para dar a escala):

| Folha | O que mostra |
| --- | --- |
| `docs/capturas_t159/outdoor_placas_eua.png` | Pórtico de placas ("Outdor") |
| `docs/capturas_t159/ponte_a_viaduto_concreto.png` | Ponte A (pasta `Ponte/`) |
| `docs/capturas_t159/ponte_b_pensil.png` | Ponte B (pasta `Outra ponte/`) |
| `docs/capturas_t159/road_kit_beira.png` | Kit de beira de estrada (pasta `road/`) |
| `docs/capturas_t159/tunel_2_faixas.png` | Túnel (pasta `Tunel/`) |
| `docs/capturas_t159/texturas_com_texto.png` | As texturas que têm texto ou placa (para conferir marcas reais) |

As prévias são em modo simples (sem luz de verdade); as cores ficam mais escuras que no jogo.

## Resumo em uma tela

| Pasta | O que é de verdade | Tamanho (m) | Triângulos | Texturas | Textos / marcas reais? | Vale usar? |
| --- | --- | --- | --- | --- | --- | --- |
| `Outdor/Highway+sign.fbx` | **Não é um outdoor (painel de propaganda)**: é um **pórtico de placas** de rodovia americana, 2 colunas + treliça com passarela, 3 placas verdes e 4 luminárias no alto | vão 8,8; altura 6,4; livre embaixo ~3,9 | 177 mil (135 mil em 4 grades pequenas) | embutidas: 3 placas (469–643 px), metal Textures.com 1024 px | **Sim**: fotos de placas reais da Califórnia (I-5, US-99, CA-134, Los Angeles, Glendale, Pasadena, Victory Blvd) | **Não**. Já temos pórticos de treliça maiores (T-146); este é baixo demais para um Dekotora |
| `Ponte/bridge_model.*` ("Ponte A") | **Viaduto de concreto** curvo de pista simples (2 faixas, mão dupla, faixa amarela dupla no meio), pilares únicos em "T", guarda-corpo de concreto com corrimão de metal, 14 postes de luz | 560 de comprido; tabuleiro ~12 de largura; pista 6,5 m (pontas) a 14,5 m (meio) do chão | 414 mil (328 mil só nos 578 postinhos do corrimão) | embutidas no FBX: asfalto 1024, concreto 512, tijolo 1024, ladrilho 225 | Não (só nomes de camadas em vietnamita) | **Sim, em pedaços**: o pilar em "T" e, talvez, a ponte inteira como viaduto que cruza por cima da pista |
| `Outra ponte/Bridge.*` ("Ponte B") | **Ponte pênsil** antiga estilo europeu (2 torres de ferro com pináculos, cabos em treliça, lampiões de época) | 155 de comprido; tabuleiro 4,8 de largura (1 faixa); torres 14 | 636 mil (607 mil no ferro e cabos) | soltas na pasta (não ligadas ao modelo): asfalto, concreto, metal, 2048 px, 10 arquivos | Não | **Não** (estreita demais, estilo europeu, pesadíssima) |
| `road/` (CGTrader) | **Kit pequeno de beira de estrada**: poste de energia de madeira (11 m) com isoladores e 3 fios de 40 m, 2 pedaços de **guard-rail** de 4,36 m, 3 placas europeias (pista escorregadia, curvas, "30"), um piso de 8,8 x 8 m e um monte de terra | peças soltas numa fila de 68 m | 14 mil (7,5 mil só nos isoladores) | 2048 px (PBR completo) + uma de 8192 px (sujeira) | Placas no estilo do Reino Unido (sem nome de lugar) | **Sim, em pedaços**: guard-rail (perfil e textura) e poste com fios |
| `Tunel/` | **O mesmo `Tunnel.obj` da T-130** (confirmado: 13 objetos, 104.814 triângulos, mesmo tamanho de arquivo): túnel redondo de 2 faixas com calçadas e corrimão, luminárias, eletrocalha no teto e 3 pórticos de **semáforo de faixa** | 193 de comprido; 10,9 de largura; 7,5 de altura | 105 mil | o `.blend` agora traz as texturas embutidas (concreto 2048, asfalto 1024, foto do semáforo 1440 x 1920) | Não | **Como referência**: semáforos de faixa, calçada com corrimão e eletrocalha, refeitos por código no nosso túnel curvo |

**Regra que vale para tudo:** a nossa pista é **gerada por código e faz curvas** (e sobe e desce). Um modelo reto (ponte,
túnel, pedaço de rodovia) não "encaixa" nela inteiro. Só servem: (1) **peças pequenas repetidas** ao longo da curva (pilar,
poste, semáforo, um pedaço de guard-rail), ou (2) uma estrutura **fora da pista** (cenário, ou cruzando por cima dela num
trecho reto). Foi assim que entraram as barreiras, placas e pórticos da T-146.

## Como foi medido

- Script novo `blender/scripts/inspect_model.py` (só lê o original): importa o arquivo numa cena vazia, grava as medidas
  num `.json` (objetos, triângulos, tamanho, materiais, texturas e resolução), miniaturas das texturas e uma folha 2 x 2.
  Comandos no anexo, no fim.
- Formatos abertos: FBX, OBJ, `.blend` (lido sem abrir, por `libraries.load`), Alembic e STL. O `.3DS` e o `.DAE`
  (Collada) **não** abrem no Blender 5 (o leitor foi retirado); eles têm o mesmo conteúdo do FBX/OBJ ao lado (mesmas
  camadas e materiais).
- Licença: procurei `license`, `readme`, `.txt`, nomes de sites (cgtrader, sketchfab, turbosquid...) e os campos de autor
  dentro dos arquivos (cabeçalho do FBX, do Collada e do `.blend`). Resultado na seção "Licenças".

## Licenças: o que achei nos arquivos

- **Nenhuma pasta tem arquivo de licença ou "leia-me".**
- Única marca de loja: `road/cgtrader_optimized_Models.fbx` (versão "otimizada" automática da **CGTrader**; dentro dele o
  caminho de processamento do site). A licença Royalty Free da CGTrader permite usar em jogo comercial sem dar crédito.
- Os outros só trazem o programa e a pasta do PC de quem fez (sem nome de autor):
  - Outdor: Cinema 4D R21, agosto de 2023, `C:\Users\PC\Desktop\bridge\highway sign fbx\`;
  - Ponte A: 3ds Max 2020, 15/01/2021, `E:\Projects_Done\Cau Vinh\3D for CG\model.max` ("Cầu Vĩnh" = "ponte Vĩnh", projeto
    vietnamita; as camadas têm nomes em vietnamita: Lancan = guarda-corpo, Matcau = tabuleiro, Detru = base do pilar,
    Goicau = aparelho de apoio, Denduong = poste de luz);
  - Ponte B: Blender 3.3, `F:\The Whole Blender Thingy\Blender Projects\Bridge.blend`;
  - road: `G:\Modular\Trim Sheet\Y6\Model\Models.blend`;
  - Túnel: Blender 2.92 (como na T-130).
- **Nada contradiz** o que o Marco disse ("Royalty Free License (no AI)") e **nada pede crédito**.
- **Atenção às texturas de terceiros que vieram dentro** (não precisamos delas; o plano é usar as nossas):
  - Outdor e Túnel usam texturas da **Textures.com** (`TexturesCom_MetalSheet_Aged`, `TexturesCom_Roads0059`): a licença
    deles não deixa redistribuir o arquivo da textura. Não copiar para o jogo.
  - Túnel: a foto do semáforo `stop-light-ge0a8c105d_1920.png` tem nome típico do **Pixabay** (uso livre, mas é foto de
    um semáforo real); o concreto `Concrete042A` é da **ambientCG** (CC0, livre).
  - Ponte B: texturas `*_xtm.jpg` sem origem identificável.
- **Placas reais**: as 3 placas do "Outdor" são **fotos de placas reais da Califórnia** (escudos das rodovias I-5, US-99 e
  CA-134, nomes de cidades). **Não podem ir para o jogo** (mesma regra da T-130/T-146: só texto fictício japonês).
- **Túnel**: na T-130 ele ficou fora por falta de licença. Agora o Marco o colocou na pasta de modelos para usar;
  **precisa confirmar** que este túnel também é "Royalty Free (no AI)" (pergunta no fim).

---

## 1. "Outdor" (`Outdor/Highway+sign.fbx`)

**O que é:** um **pórtico de sinalização** de rodovia dos EUA, não um outdoor de propaganda. Duas colunas cônicas de
3,8 m com base de concreto, treliça de 8,8 m de vão com passarela e guarda-corpo, 3 placas verdes penduradas e uma
luminária dupla no alto de cada coluna. Vem com um piso cinza de 16 x 23 m.

| Item | Valor |
| --- | --- |
| Arquivo | FBX 6,8 MB (Cinema 4D), 226 objetos, 11 materiais |
| Triângulos | 177 mil; **135 mil em 4 grades de 1,1 x 1,5 m** no alto das colunas, 13 mil nas 4 luminárias, o resto (treliça, passarela, parafusos) ~29 mil |
| Altura livre | ~3,9 m embaixo da treliça: a caixa do caminhão (3,8 m) **encosta** (folha, vista de frente). Um Dekotora com luzes no teto não passa |
| Texturas | 3 placas (643 x 347, 469 x 348, 469 x 348, feitas no Photoshop em 2023) + metal velho Textures.com 1024 px (cor, normal, rugosidade) |
| Textos | I-5 SOUTH, US-99, "Golden State", "Los Angeles", "ONLY", CA-134 "Glendale Pasadena", I-5 NORTH "Victory Blvd". Uma das placas está espelhada no modelo |

**Comparação com o jogo:** a T-146 já pôs **pórticos de treliça** (do pacote "Placão") com 27 m de vão, na medida da
nossa pista de 3 faixas, com placas japonesas em kanji, e **outdoors de propaganda** de 9,6 x 3,6 m com arte trocável.
Este modelo é menor (9 m de vão, baixo), americano e mais pesado.

**Vale a pena?** **Não.** Usar exigiria esticar o vão 3 vezes, subir as colunas ~1,5 m, trocar as 3 placas por faces
japonesas e reduzir 177 mil → ~1 mil triângulos: dá o mesmo resultado que já temos. O que dá para **aproveitar como
ideia** (feito por código, sem copiar): a **passarela com guarda-corpo** e as **luminárias no topo das colunas** nos nossos
pórticos. Esforço P, prioridade baixa.

## 2. Ponte A (`Ponte/bridge_model.*`)

**O que é:** um **viaduto de concreto** de 560 m, curvo para o lado e em lombada (as pontas a 6,5 m do chão, o meio a
14,5 m), de **pista simples com 2 faixas de mão dupla** (linhas brancas de borda a 7 m uma da outra e faixa amarela dupla
no meio; asfalto de 11,7 m e tabuleiro de ~12 m). Embaixo: vigas, aparelhos de apoio, 15 **pilares únicos em "T"** (8 a
12,5 m de altura, 5,4 m de largura no topo) com base. Em cima: mureta de concreto com **corrimão de metal** e 14 **postes
de luz** de 9 m. As pontas terminam em muros de contenção. É um modelo de engenharia (camadas em vietnamita).

| Item | Valor |
| --- | --- |
| Arquivos | FBX 16 MB (o certo: medidas em metros), OBJ 34 MB (**10 vezes menor** e com os eixos trocados: não usar), 3DS e DAE (não abrem no Blender 5) |
| Triângulos | 414 mil: **postinhos do corrimão 328 mil** (578 x 568), corrimãos 24 mil, vigas 27 mil, pista e faixas 15 mil, pilares 6,7 mil (**694 por pilar**), tabuleiro 5 mil, postes 7,5 mil (~540 cada) |
| Texturas | embutidas no FBX: asfalto 1024, concreto 512 x 355, tijolo em espinha 1024 e ladrilho 225 (os dois últimos nas pontas). O OBJ procura `maps\` que **não veio** |
| Textos/marcas | Nenhum |

**Comparação com o jogo:**

- **Ponte do litoral (T-153)** e **viaduto antigo**: feitos por código, seguem a curva e a lombada da pista; pilares =
  **2 colunas de caixa** + viga em cima a cada 30 m; mureta com corrimão já existe. Funcionam, mas os pilares parecem
  blocos (`docs/capturas_t153/kanto_1_coast_ponte_fora_day/t01_1.png`).
- **Viaduto da cidade** (rota inteira a 9 m) e viaduto antigo: já têm um "T", mas feito de **2 caixas** (coluna
  quadrada de 3 m + viga reta, a cada 32 m; `RoadFurniture._viaduct`).
- O **pilar em "T"** desta ponte (coluna arredondada que abre em leque até a viga, com base) é exatamente o tipo usado
  nas vias expressas japonesas (Shuto e Hanshin) e ficaria bem melhor nos três lugares.

**Vale a pena?** **Sim, em pedaços:**

1. **Pilar em "T"** nas pontes e viadutos (substitui as caixas). Tirar 1 pilar do arquivo, separar topo e
   coluna (a coluna estica para a altura de cada lugar; o topo alarga para o tabuleiro: 12 m na ponte de 2 faixas, ~27 m
   no viaduto da cidade, como nos viadutos de Tóquio), reduzir 694 → ~300 triângulos, concreto com a **nossa** textura
   (`concrete_streaks.png`). Custo no modo médio: ~10 a 20 pilares visíveis = **+3 a 6 mil triângulos** (hoje cada
   pilar de caixa tem 24 a 36), **+0 a 1 chamada** (entra no mesmo lote de concreto). Esforço **P/M**. Risco baixo (só
   visual; a simulação não muda).
2. **A ponte inteira como "viaduto que passa por cima"** da pista (outra estrada cruzando no alto, cena típica de via
   expressa): colocar o trecho do meio (o mais alto, 14,5 m) atravessando a pista num ponto reto, longe dos viadutos de
   trem. Precisa reduzir 414 mil → ~12 mil (trocar os 578 postinhos por 2 tubos e postes simples, juntar as vigas,
   cortar as pontas que ninguém vê), trocar as texturas pelas nossas e escolher um lugar onde nenhum pilar caia na
   pista (os pilares ficam a ~40 m um do outro; a pista com acostamento tem 29 m). Custo: **+8 a 12 mil triângulos e
   +2 a 3 chamadas** quando à vista. Esforço **M**. Risco médio (lugar livre de prédios, trem e pórticos).
3. Ponte inteira **como a pista**: **não**. É de mão dupla com 2 faixas, curva e lombada próprias; a nossa pista é de mão
   única com 3 faixas e a ponte do litoral já segue a pista de verdade.
4. Postes e corrimão: **não precisa** (já temos `lamp_post.glb`, 420 triângulos, e corrimão por código).

## 3. Ponte B (`Outra ponte/Bridge.*`)

**O que é:** uma **ponte pênsil antiga** (estilo europeu do século 19): 155 m, 2 torres de ferro com pináculos sobre
bases de concreto, cabos em treliça, guarda-corpo de ferro trabalhado e **lampiões de época**. O tabuleiro tem **4,8 m de
largura** (cabe 1 caminhão; na folha, a caixa vermelha ocupa metade da pista).

| Item | Valor |
| --- | --- |
| Arquivos | FBX 18 MB, OBJ 49 MB, Alembic 42 MB, DAE 100 MB: **o mesmo modelo** (8 objetos, 635.788 triângulos nos três que abrem) |
| Triângulos | 636 mil: torres + cabos + guarda-corpo + lampiões num objeto só (**607 mil**), resto 29 mil |
| Texturas | 10 arquivos 2048 px na pasta `Textures/` (asfalto, concreto, metal: cor, normal, rugosidade, metálico), **não ligados** ao modelo (na prévia eu liguei pelo nome, só na memória) |
| Textos/marcas | Nenhum |

**Comparação com o jogo:** não temos ponte pênsil. A ponte do litoral é baixa, de concreto, no mesmo perfil da pista.

**Vale a pena?** **Não.** Estreita demais para a pista (precisaria de 11 m no trecho de 2 faixas), estilo europeu antigo
(lampiões, pináculos) que não combina com via expressa japonesa, e 636 mil triângulos (mais que 8 caminhões juntos). Como
**cenário distante** (do outro lado da baía do litoral) seria pequena demais (155 m) e teria de ser reduzida a ~15 mil.
Se o Marco quiser uma ponte pênsil de fundo, é melhor uma moderna e branca (estilo Rainbow Bridge), feita por código ou
outro modelo. Esforço se insistir: **M/G**; prioridade baixa.

## 4. Kit "road" (`road/`, da CGTrader)

**O que é:** um kit pequeno de beira de estrada (arquivo "Trim Sheet"), com as peças em fila:

| Peça | Tamanho (m) | Triângulos | Observação |
| --- | --- | --- | --- |
| Poste de energia de madeira com travessa e **isoladores de porcelana** | 0,56 x 4 x 11 | 1.434 + 7.452 (isoladores) | estilo rural (EUA/Reino Unido); no Japão o poste é de concreto cinza |
| 3 fios (cabos) do poste | 40 de vão | 2.304 | caídos em curva |
| **Guard-rail** em "W" com 2 suportes (2 peças iguais) | 4,36 x 0,41 x 1,22 | 372 cada | textura 2048 px com faixa refletiva amarela, ferrugem e sujeira |
| Placas: pista escorregadia (triângulo), curvas (losango amarelo), velocidade "30" (redonda) | 0,7–0,8 x 2,2 | 512–584 cada | estilo do Reino Unido |
| Piso de estrada (sem textura) e monte de terra | 8,8 x 8 / 2 x 2 | 356 / 191 | — |

Arquivos: o mesmo conteúdo em `cgtrader_optimized_Models.fbx`, `Model/Models.fbx`, `.obj` e `.blend` (14.093 triângulos
em todos). Texturas: 21 arquivos 2048 px (cor, normal, rugosidade, metálico, altura, oclusão) + `Dirt1.jpg` de 8192 px
(só sujeira na rugosidade dos fios). Sem textos de lugar; só o "30".

**Comparação com o jogo:**

- **Guard-rail**: o do litoral é uma **lâmina lisa** feita por código (segue a curva sem emenda), e nas curvas há o
  `guardrail.glb` (feito por código, 372 triângulos). O do kit tem o **perfil em "W"** e uma textura bem melhor.
- **Placas**: as nossas já são japonesas (T-130) com chapa do pacote "Placas" (T-146). As do kit não servem.
- **Poste com fios**: **não existe** no jogo. Postes de energia com fios (電柱) ao lado da estrada são uma das imagens
  mais típicas das estradas japonesas fora da via expressa (montanha de Hakone, litoral).

**Vale a pena?** **Sim, em pedaços:**

1. **Guard-rail em "W"**: gerar o perfil em W por código ao longo da curva (como hoje, sem emenda) e usar a **textura do
   kit** reduzida para 512–1024 px (comprimida). Custo: +0 chamada (mesmo material do pedaço de estrada), +~1–2 mil
   triângulos visíveis, +~0,5 MB de textura. Esforço **P**. Risco baixo.
2. **Postes de energia com fios** na montanha e no litoral (do lado da terra, fora da mureta, longe da ferrovia da
   T-154): o poste reduzido de 8,9 mil → ~300 triângulos (isoladores viram caixinhas), **pintado de concreto cinza**
   (jeito japonês), em MultiMesh a cada ~35 m; os fios feitos por código seguindo a pista (como a catenária do trem).
   Custo: ~20 postes visíveis = **+6 mil triângulos + ~1 mil dos fios, +1 a 2 chamadas**. Esforço **M**. Risco baixo
   (só visual), mas é **elemento novo de cenário**: o Marco decide.
3. Placas, piso e terra: **não**.

## 5. Túnel (`Tunel/`)

**O que é:** o **mesmo túnel da T-130** (`Tunnel.obj` que estava em Downloads): confirmado pelo tamanho do OBJ
(6.596.734 bytes), 13 objetos, 19 materiais, **104.814 triângulos** e os mesmos caminhos de textura do PC "Lenovo". Túnel
redondo de **2 faixas** (pista de 8,8 m) com 2 calçadas elevadas com **corrimão**, 2 fileiras de luminárias, uma
**eletrocalha no teto** e **3 pórticos de semáforo de faixa** (seta verde / X). Por fora, uma caixa de 29 x 255 x 29 m que
fecha a cena (escondida na prévia). Novidade: o `.blend` (23,6 MB) agora traz **as texturas embutidas** (na T-130 elas
faltavam), 27 luzes de área e os 5 formatos (blend, fbx, obj, stl) têm o mesmo modelo.

| Item | Valor |
| --- | --- |
| Medidas | tubo de 193 m, **10,9 m de largura e 7,5 m de altura** (reto) |
| Triângulos | calçadas 23 mil cada, corrimãos 17 mil cada, eletrocalha 8,8 mil, paredes 7 mil, luminárias 2,9 mil cada, pista 900, semáforos **768 cada** |
| Texturas (no `.blend`) | concreto ambientCG 2048 px (5 mapas), asfalto Textures.com 1024 px, foto do semáforo (Pixabay) 1440 x 1920 |

**Comparação com o jogo:**

- **Túnel antigo 湯坂隧道 (T-153/T-155)**: 2 faixas, nas curvas do começo da montanha, arco feito por código que segue a
  pista, ~10,8 m entre as muretas e 6,6 m de altura: **quase a mesma seção** deste modelo. Tem lâmpadas nas paredes e
  muros listrados nas bocas; **não tem** calçada com corrimão, eletrocalha nem semáforo de faixa.
- **Túneis novos** (`Tunnel3D`, 3 faixas, 27 m de largura): grandes demais para este modelo.

**Vale a pena?** **Como referência, sim; o modelo em si, não** (é reto e a nossa pista faz curva dentro do túnel). Ideias,
todas feitas por código seguindo a curva, sem copiar textura:

1. **Semáforos de controle de faixa** (車線規制信号: seta verde ↓ / X vermelho) num pórtico na boca e a cada ~200 m
   dentro dos túneis (antigo e novos), como nos túneis japoneses. Bônus de jogo: quando um evento (obra, acidente) fecha
   uma faixa perto do túnel, o sinal daquela faixa fica em **X vermelho**. Custo: ~100 triângulos por pórtico, +0 a 1
   chamada (lote das placas), sem luz real (emissão). Esforço **P** (só visual) ou **M** (ligado aos eventos).
2. **Calçada de inspeção com corrimão** junto às paredes do túnel antigo (degrau de 0,3 m + tubo): +~2 triângulos por
   metro, +0 chamada (material do túnel). Esforço **P**.
3. **Eletrocalha no teto** do túnel antigo: mesma ideia, esforço P, prioridade baixa.
4. Trocar o nosso túnel por este: **não** (reto, 193 m, a nossa pista curva).

---

## O que fazer (tabela final)

Esforço: **P** = até meia sessão, **M** = 1 sessão, **G** = 2 ou mais. Custo = estimativa no modo médio (o jogo hoje
roda ~280–470 chamadas e ~185–240 mil triângulos por quadro no PC; a meta é cada novidade ficar abaixo de +5 chamadas e
+15 mil triângulos). Nada disso foi feito ainda.

| # | Ideia | Onde | Vem de | Custo estimado | Esforço | Prioridade | Precisa decisão do Marco? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Pilar em "T"** no lugar dos pilares de caixa | Ponte do litoral, viaduto antigo e viaduto da cidade | Ponte A (1 pilar, 694 → ~300 tri, nossa textura) | +3 a 6 mil tri, +0–1 chamada | P/M | **Alta** | Não (melhora visual do que já existe); só olhar as capturas |
| 2 | **Guard-rail em "W"** com a textura do kit | Litoral (lado do mar) e curvas | Kit road (perfil + textura 512–1024 px) | +1–2 mil tri, +0 chamada, +0,5 MB | P | **Alta** | Não |
| 3 | **Semáforos de faixa** no túnel (seta verde / X vermelho) | Túnel antigo da montanha e túneis novos | Referência do Túnel (feito por código) | +~0,5 mil tri, +0–1 chamada | P (visual) / M (ligado aos eventos) | **Média** | Sim: ligar o X vermelho aos eventos? |
| 4 | **Postes de energia com fios** (電柱), concreto cinza | Montanha (Hakone) e litoral, lado da terra | Kit road (poste reduzido) + fios por código | +7 mil tri, +1–2 chamadas | M | **Média** | Sim: elemento novo de cenário |
| 5 | **Viaduto que cruza por cima** da pista | Cidade ou entrada do litoral, num trecho reto | Ponte A inteira reduzida (414 mil → ~12 mil) | +8–12 mil tri, +2–3 chamadas (só quando à vista) | M | Média | Sim: quer a cena e onde |
| 6 | Calçada com corrimão e eletrocalha no túnel antigo | Túnel 湯坂隧道 | Referência do Túnel (por código) | +~1 mil tri, +0 chamada | P | Baixa | Não |
| 7 | Passarela e luminárias no topo dos nossos pórticos | Pórticos da T-146 | Ideia do "Outdor" (por código) | +~0,5 mil tri por pórtico, +0 chamada | P | Baixa | Não |
| 8 | Pórtico "Outdor" com as placas americanas | — | — | — | — | **Não fazer** | — (placas reais dos EUA; já temos pórticos melhores) |
| 9 | Ponte B (pênsil) | — | — | — | — | **Não fazer** | Só se o Marco quiser uma ponte pênsil de fundo (melhor uma moderna) |
| 10 | Usar os modelos de ponte/túnel inteiros como pista | — | — | — | — | **Não fazer** | — (a pista é gerada e curva) |

Sugestão de ordem: 1 e 2 juntos (uma sessão, só melhoram o que já existe), depois 3, depois 4 e 5 se o Marco gostar.

## Perguntas para o Marco

1. O **Túnel** (`Tunel/`) é o mesmo arquivo que ficou fora na T-130 por falta de licença. Ele também é "Royalty Free
   (no AI)"? (Mesmo que sim, a proposta usa só a ideia, refeita por código; nenhuma textura dele entra.)
2. Os outros (Ponte A, Ponte B, Outdor, road) vieram da CGTrader com "Royalty Free License (no AI)"? Algum pede crédito?
   (Nos arquivos não há licença; só o "road" tem o nome da CGTrader.)
3. Você chamou de "outdoor" o arquivo `Highway+sign`: ele é um **pórtico de placas**, não um painel de propaganda. Se você
   queria **outdoors de propaganda** novos, eles já existem desde a T-146 (com arte trocável); quer mais modelos/artes?
4. Quer os **postes de energia com fios** (ideia 4) e o **viaduto cruzando por cima** (ideia 5)?
5. No túnel, o **X vermelho** do semáforo deve acompanhar os eventos (faixa fechada) ou ser só enfeite?

## Anexo: comandos usados (para repetir)

Em worktree, passe o caminho absoluto da pasta principal (`docs/Modelos/` fica fora do Git):

```
blender -b --factory-startup -P blender/scripts/inspect_model.py -- --file "<pasta principal>/docs/Modelos/Road_pontes/Ponte/bridge_model.FBX" --out PASTA --name ponteA --truck 160,48.8,13.9 --truck-yaw -84 --views "34;side;222,22,5,192,55,8,28;100,46.5,16.5,200,54.7,15.5,24"
blender ... -- --file ".../Outdor/Highway+sign.fbx" --name outdoor --truck 6.6,-9,0 --truck-yaw 0 --views "34;front;4.6,-10,2.2,4.6,1,4.9,35;-6,-14,1.5,4.6,1,4.0,24"
blender ... -- --file ".../Outra ponte/Bridge.fbx" --texdir ".../Outra ponte/Textures" --name ponteB --truck 0.9,-45,2.6 --truck-yaw 0 --views "34;side;14,-55,7,0,-36,7,28;0.9,-82,4.4,0.9,0,5,24"
blender ... -- --file ".../road/Model/Model/Models.blend" --name road --truck 22,-4.5,0 --truck-yaw 90 --views "34;side;-2,-7,1.6,-0.5,0,1.1,30;15,-9,7,10.9,0,9.6,30"
blender ... -- --file ".../Tunel/Tunnel.blend" --hide "^Cube\.002" --name tunel --truck 1.8,-60,0 --truck-yaw 0 --views "34;front;1.8,-2,2.8,1.8,-60,2.2,24;1.2,-15,3.0,0,-25.1,5.4,30"
```

Só as medidas (sem render): acrescente `--no-render`. Cada execução grava `NOME_stats.json`, `NOME_tex/` (miniaturas das
texturas), `NOME_v0..3.png` e `NOME_folha.png` em `PASTA`.
