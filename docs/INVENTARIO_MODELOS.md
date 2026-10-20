# Inventário dos modelos 3D que o Marco colocou (T-130)

Data: 2026-10-18. Pedido do Marco: "coloquei alguns modelos de carro e estrutura, só não lembro quais são o quê, tipo placa e
sinalização; verificar e aplicar no jogo". Aqui está **o que é cada arquivo**, quanto pesa, se tem placa de veículo ou
sinalização, e o que já entrou no jogo. Medidas feitas abrindo cada arquivo no Blender 5.2.2 em segundo plano (nada foi
alterado nas pastas originais). Análises anteriores: `docs/NOVOS_MODELOS.md` (T-115) e `docs/MODELOS_MELHORADOS.md` (T-123).

## Resumo em uma tela

| Arquivo / pasta | O que é | Triângulos | Placa de veículo? | Sinalização? | No jogo? |
| --- | --- | --- | --- | --- | --- |
| `docs/Modelos Melhorados/2025_fumi_sc.glb` (+ pasta `2025-fumi-sc/` com FBX e 30 texturas) | Carro esportivo vermelho (base TVR Griffith) | 82 mil | Sim: suporte `licenseholder` e a textura `lights_licenseplate.png`, que é **uma foto de uma placa real da Austrália** | Não | Sim: tráfego `car_fumi.glb` (T-124) e 2 peças (aerofólio, rodas, T-126). A foto da placa **não** foi usada |
| `docs/Modelos Melhorados/stylized_opel_ascona.glb` (+ pastas e `.usdz`) | Sedã antigo estilizado (Opel Ascona) | 98 mil | Placa branca lisa pintada na textura (sem número legível) | Não | Sim: tráfego `car_ascona.glb` (T-124) |
| `docs/Modelos Melhorados/stylized_ford_falcon_gt_coupe.glb` (+ pastas e `.usdz`) | Cupê antigo estilizado (Ford Falcon GT) | 94 mil | Placa branca lisa pintada na textura | Não | Sim: tráfego `car_falcon.glb` (T-124) |
| `docs/Modelos Melhorados/carro/low_poly_vehicle_mini_pack_5.*` | 6 SUVs iguais em cores diferentes | 79 mil (13 mil cada) | Não | Não | Sim: tráfego `car_suv.glb` (T-124) |
| `docs/Modelos Melhorados/JAC+1045+Truck.*` (.blend, .fbx, .glb) | Caminhão leve japonês/chinês: só cabine e chassi | 69 mil | Não (só o emblema JAC, já apagado) | Não | Sim: caminhão base **Canter**, cabines **curta** e **jac** (T-125, T-129), rodas e caixa de ferramentas (T-126) |
| `docs/Modelos Melhorados/BUS+JETSET.fbx` / `JETSET.dae` | Ônibus rodoviário (Jetset, Indonésia) | 143 mil | Não | Não (sem letreiro de destino) | Sim: tráfego `car_bus.glb` (T-124) |
| `docs/Modelos Melhorados/kenworth_w990_truck.glb` (+ pasta com `.blend`) | Cavalo mecânico americano Kenworth W990 com carreta | 2,17 milhões | Não | Não | Em parte: cabine **americana** (T-129) e 6 peças (T-126). O resto fica fora (marca, peso) |
| `docs/Modelos Melhorados/nypd_toyota_camry_.blend` | Viatura de polícia de Nova York (Toyota Camry) | 1,53 milhão | Sim: textura com **foto de uma placa real de Nova York** | Só o giroflex | **Sim (T-143)**: viatura `car_police.glb` **só no acidente**, 7,3 mil triângulos, sem NYPD/Toyota/placa/interior, pintura preto/branco genérica e giroflex vermelho nossos |
| `docs/Modelos Melhorados/kaohsiung_circular_light_rail_caf_urbos_3.*` (+ `.usdz`, pastas) | Bonde urbano (CAF Urbos 3), 35 m | 71 mil | Não | Não: **só o vagão**, sem postes, trilhos, plataforma ou placas | **Não** (ver seção 3) |
| `docs/Novos modelos/Cabine/CF_500_complete.*` (.3dm, .stp, .stl + 3 renders) | Cabine "cara chata" International CF500 | 610 mil | Não | Não | Sim: cabine **chata**, a padrão do jogo (T-119) |
| `docs/Novos modelos/Van+01/` (FBX, OBJ, .max, texturas, prévias) | Furgão estilo Peugeot Partner | 504 mil | Não (as "Decal" são grafismos de lataria) | Não | Sim: tráfego `car_van01.glb` (T-121) |
| `docs/Novos modelos/Carro/` (.blend, FBX, OBJ, STL, 198 texturas) | Jipe Suzuki Samurai (Gypsy) | 436 mil | Não | Não | **Sim (T-143)**: tráfego `car_jeep.glb` (5,1 mil triângulos, "SUZUKI" apagado, placa fictícia) |
| `docs/Novas Melhorias/Carro batido/model_download+(24).obj` (T-143) | **Picape com a frente amassada** (malha única sem materiais, UV nem normais) | 80 mil | Não | Não | **Sim (T-143)**: `car_wreck.glb` no acidente (refeita em voxels, 6 mil triângulos, cores lisas) |
| `docs/Novos modelos/Caminhão/canter.obj` | Mitsubishi Canter antigo com baú | 130 mil | Não | Não | **Não**: extraído de outro jogo (Ninja Ripper), risco legal |
| `Downloads\Tunnel.obj` + `Tunnel.mtl` (6,6 MB, **fora do projeto**) | **Túnel** redondo de 2 faixas com calçadas, luminárias, tubulação no teto e **3 pórticos de semáforo de faixa** | 105 mil | Não | Sim: os 3 **semáforos de faixa** (textura `stop-light-ge0a8c105d_1920.png`, ausente) | **Não**: licença desconhecida |
| `Downloads\van.abc` (Alembic, 1,7 MB, **fora do projeto**) | **Não é uma van**: é um **caminhão de carroceria aberta de madeira, 3 eixos (6 rodas)**, estilo Índia/Sudeste Asiático, com chão, estrada e fundo de estúdio | 62 mil (65% são as 6 rodas) | Não | Não | **Não**: licença desconhecida |
| `Downloads\Ge\` (10 arquivos .zip, 380 MB) | **Cópias zipadas** do Fumi, Urbos, Kenworth, Falcon e Ascona (2 zips de cada) | — | — | — | Nada novo: são os mesmos arquivos já extraídos em `docs/Modelos Melhorados/` |

**Resposta curta para "placa e sinalização":** nenhum dos modelos traz placas de trânsito, pórticos, setas ou letreiros que
sirvam para a estrada. Os únicos itens de "placa" são **fotos de placas de carro reais** (Austrália no Fumi, Nova York no Camry),
que **não podem ser usadas** (são de pessoas/estados reais). A única "sinalização" é o conjunto de **semáforos de faixa do
`Tunnel.obj`**, que tem licença desconhecida. Por isso a T-130 fez as placas e a sinalização **por código, com texto
fictício**, sem copiar nada desses arquivos (seção 4).

## 1. Detalhes dos dois arquivos novos de `Downloads`

Nenhum dos dois foi copiado para o projeto. Foram só abertos no Blender em segundo plano para medir.

### `Tunnel.obj` + `Tunnel.mtl`

- Gravado pelo Blender 2.92 a partir de `Tunnel.blend`. 13 objetos, 19 materiais, 104.814 triângulos.
- Medidas: tubo de ~204 m de comprimento, 10,9 m de largura e 7,5 m de altura (uma pista de 2 faixas); por fora, uma caixa de
  29 x 255 x 29 m que fecha a cena. O nosso túnel (`tunnel_3d.gd`) tem 27 m de largura para as 3 faixas + acostamento.
- Peças: paredes do túnel (7 mil), 2 calçadas (23 mil cada), 2 calhas laterais (17 mil cada), tubulação no teto (9 mil),
  2 faixas de luminárias (3 mil cada, material emissivo), pista (900), **3 pórticos de semáforo de faixa** (768 cada).
- Texturas: **não vieram junto**. O `.mtl` aponta para `C:\Users\Lenovo\Downloads\...` (outro PC) e para `New folder\9\`.
  Os nomes indicam as origens: `Concrete042A_2K_*` (ambientCG, normalmente CC0), `TexturesCom_Roads0059_1_seamless_S.jpg`
  (Textures.com, licença própria que proíbe redistribuir a imagem) e `stop-light-ge0a8c105d_1920.png` (nome típico do Pixabay).
- Uso possível, se a licença permitir: referência para luminárias e tubulação no teto do nosso túnel. Os triângulos (105 mil)
  são o dobro de um caminhão; teria que ser reduzido muito. **Precisa do link de onde foi baixado.**

### `van.abc`

- Alembic com 22 objetos, **sem materiais e sem texturas**, 250 quadros de animação.
- O veículo mede 2,6 x 8,7 x 3,3 m: cabine (`CABIN`), carroceria de tábuas (`BODY`, `SHEET`), tanque de diesel (`DIESE`), volante
  (`STERING`), para-lamas (`MUDGUARD`), 6 rodas (`Cylinder_*`, 6,8 mil triângulos cada). Vem também um gramado de 178 m, uma
  estrada e um fundo de estúdio.
- Uso possível, se a licença permitir: caminhão de carga aberto no tráfego (os Dekotora reais nasceram desse tipo de caminhão).
  Precisaria de rodas reduzidas (40 mil → ~3 mil triângulos), materiais e UV. **Precisa do link de onde foi baixado.**

## 2. Placas de veículo encontradas (e por que não servem)

| Modelo | O que tem | Serve? |
| --- | --- | --- |
| Fumi SC | `lights_licenseplate.png`: foto com lanternas e a placa amarela "VDJ·052 NEW SOUTH WALES" | Não: placa real de alguém. O `car_fumi.glb` do jogo usa só cores lisas (conferido: atlas 128 x 128) |
| NYPD Camry | Textura com foto de placa real "ADL 4681 NEW YORK" | Não: placa real e o modelo já estava fora |
| Ascona, Falcon | Retângulo branco liso na textura pintada | Só como lugar da placa; não tem número |
| Caminhões do jogo | Retângulo branco `plate` (0,5 x 0,22 m) atrás do baú; placa branca no para-choque `fb_standard_chrome` | Era só um retângulo branco; agora recebe a placa da T-130 |

## 3. Estruturas aproveitáveis para a sinalização?

- **Bonde Urbos:** o arquivo tem só o vagão (71 objetos `Object_*`, materiais `caf_urbos_*`). Não tem postes da rede aérea,
  trilhos, plataforma nem letreiros. Nada para a estrada.
- **Kenworth, ônibus, carros:** veículos; nenhum traz placa de trânsito, poste ou pórtico.
- **Túnel (`Tunnel.obj`):** os semáforos de faixa e as luminárias seriam úteis, mas a licença é desconhecida. Não foram usados.
- Conclusão: a sinalização nova é toda **feita por código** (formas simples + um atlas de texturas desenhado pelo nosso
  gerador, com a fonte Noto Sans JP que já está no projeto).

## 4. O que a T-130 aplicou no jogo

- **Placas de veículo japonesas fictícias** em todos os caminhões (frente e traseira) e em todos os carros do trânsito
  (frente e traseira): branca com letras verdes (carro particular), amarela (kei), verde com letras brancas (caminhão e
  ônibus comerciais) e preta com letras amarelas (kei comercial). Textos como "湘南 300 さ 12-34", com cidades de Kanto e
  números sorteados (64 placas diferentes, sem repetir entre os carros da mesma corrida enquanto houver placa livre).
- **Sinalização de pista:** limite de velocidade (círculo vermelho), aviso de curva e de túnel (losango amarelo), setas
  chevron vermelhas e brancas nas curvas fortes, placa "出口 EXIT", painéis de distância em km, placa com nome e comprimento
  na boca de cada túnel e "止まれ" + placa de pare antes do pedágio.
- Custo medido (modo médio, 3 rotas): **+3 chamadas de desenho** (1 para todas as placas, 2 para toda a sinalização), +0,2 a
  +2,6 mil triângulos, +0,9 MB de textura, FPS igual (75 no PC).
- Fotos: `docs/capturas_t130/` (placas de perto na garagem, dia e noite; cada rota de dia/entardecer e de noite).
- Detalhes técnicos: `docs/STATUS.md` (T-130) e `docs/DECISOES.md`.

## 5. Pendências para o Marco

1. **`Tunnel.obj` e `van.abc`: de onde vieram?** Mande o link da página de download e o tipo de licença (Royalty Free, CC0,
   CC-BY, "uso pessoal"...). Sem isso, eles ficam só como referência e não entram no jogo. As texturas do túnel também não
   vieram junto (estavam em outro PC).
2. A pasta `Downloads\Ge\` pode ser apagada por você se quiser liberar 380 MB: é só cópia zipada do que já está em
   `docs/Modelos Melhorados/` (eu não apaguei nada).
3. ~~Jipe Suzuki~~ FEITO na T-143 (tráfego), junto com a viatura e o carro batido no acidente. Os três são "Royalty Free
   License (no AI)", confirmado pelo Marco em 2026-10-19 (`game/assets/LICENCAS.md`).


---

# T-146 (2026-10-19): `docs/Novas Melhorias/`: Metais, Placas e Placão

Pedido do Marco: "coloquei novos modelos na pasta docs/Novas Melhorias, quero todos estes itens no jogo". Licença dos três
pacotes: **Royalty Free License (no AI)**, confirmada pelo Marco (créditos em `game/assets/LICENCAS.md`). A pasta continua
fora do Git; só o resultado reduzido entra (`blender/scripts/build_roadside_kit.py`). As pastas "Carroceria" e "Carro batido"
são de outras tarefas.

| Pasta / arquivo | O que é de verdade | Triângulos | Texturas | Textos/marcas reais? | No jogo |
| --- | --- | --- | --- | --- | --- |
| `Metais/` "Metal and Concrete Barriers" (.blend, .fbx, .3ds, .max, .unitypackage, texturas .zip) | **Barreiras de obra**, não guard-rail: 3 blocos de concreto com **listras amarelas e pretas** (New Jersey 0,9 m; muro alto 1,3 m; New Jersey com grade de cano em cima 1,66 m), 2 **cavaletes de metal** em "A" (1,85 e 2,78 m) e 4 pedaços soltos de cantoneira/cano | 1.532 (84 a 536 por peça) | 1 atlas 4096 px (cor, normal, oclusão, rugosidade, metálico; .tga no .zip) | Não | Inteiro: obras, acidente, estreitamento e bocas de túnel |
| `Placas/` "ROAD SIGNS" (.blend, .fbx, texturas) | **74 chapas de placa** em 5 formatos (redonda com borda, triângulo, octógono, losango, retângulo, cantos arredondados), 34 postes com base, 4 postes duplos, 70 braçadeiras e 70 cintas (atrás das placas), 4 parafusos e um boneco de referência | **1,06 milhão** (70% são as braçadeiras: 10,6 mil cada) | Metal azul da Poly Haven (CC0) + **uma captura de tela de propaganda "80+ ROAD SIGNS SVG BUNDLE"** com placas americanas/europeias (STOP, GIVE WAY, km/h…) usada como face | Sim: textos em inglês e placas ocidentais na captura de tela | Chapas (redonda, triângulo, losango, retângulo) e poste, **com as faces japonesas da T-130**. A captura de tela, o octógono, as braçadeiras/cintas (ficam atrás da placa, ninguém vê da pista) e o boneco **não** entram |
| `Placão/nodel.fbx` + `tex.rar` | **Pórtico de treliça** (2 pernas de 7,5 m + viga de 24 m; caixas com textura de treliça recortada) com **2 placas verdes americanas** "I-96 EAST Detroit" e "HORTON / HANOVER / LIBERTY"; exportado de um projeto Unity "main_offrd_oiltanker" | 76 | `tex.rar` (aberto com o 7-Zip): `Grade1.png` (grades, guarda-corpo de vidro, treliça; com alfa) e `Metal.png` (as 2 placas, chapas e parafusos). Falta `Atlas-1.psd` (só as sapatas) | Sim: escudo da Interstate 96 e cidades reais dos EUA | A treliça vira os **pórticos** da pista (medidas da nossa pista, 27 m) e as pernas dos **outdoors**; o vidro com moldura do `Grade1.png` vai na **barreira de som do viaduto**. As placas americanas **não** entram (o pórtico continua com as placas japonesas em kanji) |

## O que entrou no jogo (T-146)

- **Barreiras (Metais)**: obras = fileira contínua de barreiras listradas na borda da faixa fechada depois do afunilamento (no
  lugar dos cones espaçados; a cada 5, uma com grade em cima); acidente = cavaletes de metal atravessados antes dos carros e
  destroços de metal no chão; estreitamento = muro listrado onde a faixa acaba + barreiras ao longo dela; **bocas dos túneis** =
  2 muros listrados na ponta da mureta, dos dois lados. A **mureta contínua** e o guard-rail do litoral continuam os feitos por
  código (seguem as curvas, 0 chamada extra, e o pacote não tem guard-rail de rodovia); a simulação não mudou (as peças ficam
  no mesmo intervalo fechado que ela usa).
- **Placas**: toda a sinalização da T-130 ganhou chapa de verdade (borda, espessura, cantos arredondados) no formato da face
  (limite = redonda, aviso = losango, 止まれ = triângulo de ponta para baixo, apoio/saída/km/chevron = retângulo) e poste
  redondo com base. Juntadas por bloco de 400 m (`MeshBatch`).
- **Placão**: pórtico de treliça no lugar das vigas de caixa; **outdoors** (painel 9,6 x 3,6 m sobre 2 pernas de treliça, com
  passarela e luminárias; no viaduto as pernas descem até o chão) a cada ~1,15 km, fora da mureta, virados para a pista e
  acesos à noite. Arte trocável: `game/assets/scenery/billboards/ad_01..04.png` (1024 x 384) ou `user://billboards/ad_0N.png`.
- Peso: 60–280 triângulos por peça; texturas 1024 px (barreira, treliça) e 512 px (ORM, normal, metal), comprimidas na VRAM
  (S3TC no PC, ETC2/ASTC no Android); +3,2 MB de memória de textura, ~4,7 MB de PNG no projeto. Medidas em `docs/STATUS.md` (T-146).
- Capturas: `docs/capturas_t146/` (`litoral|viaduto|montanha_dia_noite.png`, `antes_depois_dia.png`, `kit_modelos.png`).


---

# T-154 (2026-10-19): ferrovia ao lado da rodovia e busca por arquivos novos

Pedido do Marco: "coloquei novos modelos nas pastas de docs/ (Novas Melhorias e outras), entre eles peças de FERROVIA".

## O que a busca encontrou (2026-10-19, à tarde)

Procurei em `docs/Novas Melhorias/`, `docs/Novos modelos/`, `docs/Modelos Melhorados/`, nas outras pastas de `docs/`, em
`C:\Users\Marco Aurelio Luz\` (Downloads, Desktop, Documentos, Imagens, OneDrive, 3D Objects) e em `D:\DEV`, por data (arquivos
novos desde 2026-10-17) e por nome (rail, trilho, ferrovia, train, trem, tunnel, wagon, catenary, locomotive...).

| Onde | O que tem | Resultado |
| --- | --- | --- |
| `docs/Novas Melhorias/` | As mesmas 5 pastas de antes (Carro batido, Carroceria, Metais, Placas, Placão), sem arquivo novo desde 18/10 21:46 | Tudo já no jogo (T-143, T-145, T-146) |
| `docs/Novos modelos/` | Cabine, Caminhão (Canter), Carro (jipe), Van+01; nada novo desde 17/10 | No jogo, menos o Canter (extraído de outro jogo) |
| `docs/Modelos Melhorados/` | Nada novo desde 18/10; o único item de trilho é o **bonde CAF Urbos 3** | **Entrou agora** como o bonde amarelo (abaixo) |
| `Downloads` | **Vazia** (só `desktop.ini`). `Tunnel.obj`, `van.abc` e a pasta `Ge\` (zips) **não estão mais lá** nem em outra pasta procurada | Continuam fora do jogo (sem arquivo e sem licença) |
| Resto do disco | Nenhum modelo de trilho, trem, poste de catenária, muro ou estação | — |

**Conclusão: não há peças de ferrovia de terceiros no PC.** Se o Marco baixou um pacote de ferrovia, ele não foi salvo em nenhuma
dessas pastas (talvez tenha ficado só no navegador ou ido para outra unidade). Por isso a ferrovia foi feita **por código**, como a
tarefa pedia para esse caso.

## O que entrou no jogo (T-154)

| Item | Veio de | Triângulos | Textura | Onde |
| --- | --- | --- | --- | --- |
| **Bonde amarelo** (2 carros engatados, 70 m) | **Arquivo do Marco**: `docs/Modelos Melhorados/kaohsiung_circular_light_rail_caf_urbos_3.glb` (licença SKETCHFAB Standard no `license.txt`: royalty free, crédito não obrigatório). Sem o interior (43 mil triângulos), verde de Kaohsiung trocado por amarelo, logotipos "CAF" e da linha apagados | 71 mil → **6,9 mil** | 1024 + 512 px (do próprio arquivo, repintadas) | Trem principal da cidade (viaduto); às vezes no litoral e na montanha |
| **Trem de carga** (locomotiva vermelha + 8 vagões com contêineres coloridos, 186 m) | **Por código** (`blender/scripts/build_railway_kit.py`) | 316 (loco), 204–216 (vagão) | atlas 512 px | Trem principal do litoral e da montanha; sempre no viaduto que cruza a pista |
| Via dupla: lastro com dormentes, 4 trilhos, muro do lado da pista, fios da catenária | Por código (malha montada no jogo seguindo a curva da pista, seções de 4 m) | ~3,2 mil por 300 m (com os pórticos) | `rail_bed.png` 1024 px | Linhas paralelas |
| Pórtico de catenária (2 colunas + viga + braços e isoladores) a cada 50 m | Por código | 112 | a mesma da via | Todas as linhas |
| Viaduto de concreto com guarda-corpo, pilares e travessas | Por código | 8 + 12 por pilar | a mesma da via | Linha da cidade e os 2 cruzamentos |
| Boca de túnel ferroviário + morro de grama (ou bloco de concreto na cidade) | Por código | 66 + ~20 | a mesma da via / grama | Fim da linha do litoral, entrada e saída do túnel da montanha, pontas dos cruzamentos |

Todas as texturas novas são comprimidas na VRAM (S3TC no PC, ETC2/ASTC no Android) com mipmaps.

## Onde fica a ferrovia em cada rota

| Rota | Linha paralela (lado esquerdo, o da terra) | Viaduto de trem por cima da pista | Fica livre |
| --- | --- | --- | --- |
| Litoral (3 km) | 0 → 2.150 m, a 36 m do centro da pista, no chão, com muro; termina numa boca de túnel num morro | Não (do outro lado é o mar) | 2.270–2.890 m (ponte e trecho de 2 faixas da T-153) |
| Viaduto/cidade (2,75 km) | A rota inteira, elevada na altura da via expressa, a 40 m (passa ao lado da caixa de concreto do túnel) | Em 1.500 m (entre o túnel e o pórtico de 1.620 m), 8,5 m acima da pista, com prédios-estação nas pontas | Os prédios que cairiam em cima do viaduto de trem são retirados |
| Montanha (2,8 km) | 1.240 → 2.080 m (entra no morro do túnel da pista por uma boca própria) e 2.380 → fim (sai do morro) | Em 240 m (logo depois do pedágio), 8,5 m acima da pista, entre duas bocas de túnel | 650–1.190 m (túnel antigo de 2 faixas da T-153) e o túnel da pista |

## Propostas para o que ainda não entrou

| Item | Proposta |
| --- | --- |
| `Tunnel.obj` (sumiu de Downloads) | Se o Marco achar o arquivo e a licença: luminárias e tubulação do teto no nosso túnel, e os semáforos de faixa na boca |
| `van.abc` (sumiu de Downloads) | Se voltar com licença: caminhão aberto antigo no trânsito (a origem dos Dekotora) |
| Carreta do Kenworth W990 | Pode virar uma carreta no trânsito lento (pesada: precisa reduzir muito) |
| Bonde no menu | O fundo "B rodovia" da tela inicial pode ganhar a ferrovia com o bonde passando (falta o Marco escolher o fundo do menu, T-138) |
| Trem na garagem/posto | Não faz sentido (não há trilho perto da garagem); fica só na estrada |


---

# T-159 (2026-10-20): `docs/Modelos/Road_pontes/` (ponte, "outdoor", rodovia e túnel) — só análise

Pedido do Marco: "analise estes novos modelos que podemos implementar no jogo, como ponte, outdoor, rodovia e túnel".
**Nada entrou no jogo.** Análise completa, folhas de prévia e a tabela "O que fazer" em **`docs/ANALISE_ROAD_PONTES.md`**
(folhas em `docs/capturas_t159/`). Medido com o script novo `blender/scripts/inspect_model.py` (só lê o original).

**Mudança de lugar:** as pastas de terceiros agora ficam todas em **`docs/Modelos/`** (`Modelos Melhorados`, `Novas
Melhorias`, `Novos modelos` e `Road_pontes`). A pasta continua fora do Git (`.gitignore`: `docs/Modelos/`).

| Pasta / arquivo | O que é de verdade | Triângulos | Texturas | Textos/marcas reais? | Recomendação |
| --- | --- | --- | --- | --- | --- |
| `Outdor/Highway+sign.fbx` | **Pórtico de placas** de rodovia dos EUA (não é outdoor de propaganda): 2 colunas, treliça de 8,8 m de vão com passarela, 3 placas e 4 luminárias; só ~3,9 m livres embaixo | 177 mil | embutidas: 3 placas (até 643 px) + metal Textures.com 1024 | **Sim**: fotos de placas reais da Califórnia (I-5, US-99, CA-134, Los Angeles, Pasadena) | Não usar (já temos pórticos e outdoors da T-146) |
| `Ponte/bridge_model.*` (FBX certo; OBJ 10x menor) | **Viaduto de concreto** curvo de 560 m, pista simples de 2 faixas de mão dupla, 15 pilares únicos em "T", mureta com corrimão, 14 postes; projeto vietnamita ("Cau Vinh") | 414 mil (328 mil nos postinhos do corrimão; pilar 694 cada) | embutidas no FBX: asfalto/tijolo 1024, concreto 512, ladrilho 225 | Não | **Pilar em "T"** nas pontes/viadutos (alta); ponte inteira como viaduto cruzando por cima da pista (média, decisão do Marco) |
| `Outra ponte/Bridge.*` (FBX, OBJ, ABC iguais; DAE não abre) | **Ponte pênsil** europeia antiga de 155 m, tabuleiro de 4,8 m (1 faixa), torres de ferro e lampiões | 636 mil | 10 soltas de 2048 px (não ligadas ao modelo), origem não identificada | Não | Não usar |
| `road/` (CGTrader, "Trim Sheet") | **Kit de beira de estrada**: poste de energia de madeira de 11 m com isoladores e 3 fios, 2 guard-rails em "W" de 4,36 m, 3 placas do Reino Unido, piso e terra | 14 mil | 21 de 2048 px (PBR) + sujeira 8192 px | Placas estilo Reino Unido ("30"), sem nomes | **Guard-rail em "W"** com a textura (alta); **postes com fios** pintados de concreto (média, decisão do Marco) |
| `Tunel/` (.blend, .fbx, .obj, .stl iguais) | **O mesmo `Tunnel.obj` da T-130** (mesmos 104.814 triângulos, 13 objetos, 19 materiais, mesmo tamanho de arquivo): túnel reto de 2 faixas, 193 x 10,9 x 7,5 m, calçadas com corrimão, eletrocalha, 3 pórticos de semáforo de faixa. O `.blend` agora traz as texturas | 105 mil | concreto ambientCG 2048 (CC0), asfalto Textures.com 1024, foto Pixabay do semáforo | Não | Só como referência: **semáforos de faixa** e calçada com corrimão feitos por código no nosso túnel curvo (média) |

**Licença:** nenhuma pasta tem arquivo de licença; só o `road` traz o nome da CGTrader. Nada contradiz "Royalty Free
License (no AI)" nem pede crédito. Texturas de terceiros que vieram dentro (Textures.com, Pixabay) **não** devem ser
copiadas; as propostas usam as nossas. **Falta o Marco confirmar** a licença do túnel (ficou fora na T-130) e dos outros.
