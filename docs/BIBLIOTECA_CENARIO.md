# Biblioteca de cenário (tudo o que existe em docs/Modelos e onde está no jogo)

Pedido do Marco na T-159 / T-186: catálogo de TODOS os modelos de `docs/Modelos/` (pasta fora do Git, todos "Royalty
Free, sem IA, sem crédito obrigatório", decisão de 2026-10-20) e das peças prontas no jogo. Atualizado na **T-186
(2026-10-21)**. Inventário refeito por script: `bash tools/inventory_models.sh` (um `.json` por arquivo em
`blender/renders/t186/inventory/`, com triângulos, tamanho, texturas, esqueleto e animações; nada é alterado na pasta).

## 1. Inventário de docs/Modelos (821 arquivos, 6,8 GB, 9 pastas)

Um modelo por linha; os formatos repetidos (FBX = OBJ = BLEND...) estão juntos. Tamanho em metros (largura x
comprimento x altura) depois de corrigir a unidade do arquivo. "Anim." = esqueleto (armature) ou animação.

| Pasta / arquivo | Modelo | Tipo | Triângulos | Tamanho (m) | Textura | Anim. | Onde vai usar / está |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Arvore/…/Gledista_Triacanthos.fbx` (.obj, .blend) | Gleditsia v01 | árvore (folhosa) | 436 mil | 6,1 x 7,0 x 9,0 | sim (casca, folha, flor) | não | `tree_leafy` (6,5 m): litoral (lado da terra), cidade |
| `…_2.fbx` | Gleditsia v02 | árvore | 813 mil | 8,0 x 7,9 x 9,8 | sim | não | `tree_leafy_b` (7,2 m): litoral, cidade |
| `…_3.fbx` | Gleditsia v03 (folha clara, vagens) | árvore | 1,13 mi | 8,3 x 10,0 x 11,5 | sim | não | `tree_leafy_c` (7,6 m): os 3 biomas |
| `…_4.fbx` | Gleditsia v04 adulta | árvore | 869 mil | 12,1 x 10,5 x 23,5 | sim | não | `tree_leafy_d` (11,9 m): montanha |
| `…_5.fbx` | Gleditsia v05 adulta | árvore | 777 mil | 14,6 x 10,8 x 22,2 | sim | não | `tree_leafy_e` (11,3 m): montanha, cidade |
| `…_6.fbx` | Gleditsia v06 adulta | árvore | 853 mil | 13,5 x 11,5 x 24,1 | sim | não | `tree_leafy_f` (12,5 m): montanha |
| `Arvore/…/*.max` (GrowFX, Corona, V-Ray, Arnold) | as mesmas 6 | — | — | — | — | — | não abrem no Blender; repetem os FBX |
| `poste/Utility_pole.*` (blend, fbx, glb, obj, stl, usdc) | poste de concreto com caixa e cabos | poste de energia | 346 mil | 0,6 x 24,6 x 11 (cabos de 24 m) | só placas de ônibus (não ligadas) | não | coluna/caixa/suporte nos postes com fios (T-163) |
| `Road_pontes/Ponte/bridge_model.FBX` (.obj) | "Ponte A" (viaduto curvo de 560 m) | ponte + **poste de luz** | 414 mil | 560 x 97 x 26 | sim (asfalto, concreto) | não | pilar em T, viaduto por cima (T-163/164); **poste de luz `lamp_bridge` (T-186)** |
| `Road_pontes/road/` (Models.blend/fbx/obj) | kit de beira de estrada (CGTrader) | guard-rail, poste de madeira | 14 mil | 10 peças | sim (2048 px) | não | guard-rail em W, travessa do poste (T-163) |
| `Road_pontes/Tunel/Tunnel.*` | túnel reto de 2 faixas | túnel | 105 mil | 29 x 255 x 29 | sim | não | referência dos semáforos de faixa (T-164); o túnel do jogo é por código |
| `Road_pontes/Outra ponte/Bridge.*` | ponte pênsil europeia | ponte | 636 mil | 6,6 x 155 x 14 | soltas (não ligadas) | não | **não usada** (1 faixa, estilo europeu, pesada) |
| `Road_pontes/Outdor/Highway+sign.fbx` | pórtico de placas dos EUA | pórtico | 177 mil | 16 x 23 x 6,4 | sim | não | **não usado** (decisão do Marco, T-159) |
| `Novas Melhorias/Placas/ROAD+SIGNS.*` | 74 placas, postes, braçadeiras + **boneco** | placas + **personagem** | 0,94–1,06 mi | — (boneco 1,66 m) | sim (captura de tela) | não | chapas e postes (T-146); **boneco = pessoa do jogo (T-186)** |
| `Novas Melhorias/Metais/*` (.blend, .fbx, .3ds, .max) | barreiras de concreto e metal | prop de obra | 1,5 mil | até 2,8 m | sim (zip) | não | barreiras e destroços (T-146) |
| `Novas Melhorias/Placão/nodel.fbx` (+ tex.rar) | treliça de pórtico | pórtico | 76 | 4,5 x 24 x 9,5 | sim (rar) | não | pórticos (T-146) |
| `Novas Melhorias/Carroceria/*` | carroceria graneleira | veículo (peça) | 81 mil | 2,2 x 6,1 x 2,2 | sim | não | graneleira (T-145) |
| `Novas Melhorias/Carro batido/*.obj` | carro amassado | veículo | 80 mil | ~4,4 m | não | não | `car_wreck` (T-143/T-183) |
| `Modelos Melhorados/kenworth*` | Kenworth W990 | caminhão | 2,17 mi | 2,8 x 19,4 x 4,0 | sim | esqueleto no .blend | cabine americana e peças (T-126/129) |
| `Modelos Melhorados/JAC+1045+Truck.*` | JAC 1045 | caminhão | 69 mil | 3,5 x 9,4 x 3,1 | não | não | cabine JAC (T-129) |
| `Modelos Melhorados/2025_fumi_sc.*` | esportivo vermelho | carro | 82 mil | 2,1 x 4,7 x 1,4 | sim (placa real) | não | `car_fumi` e rodas (T-124/126) |
| `Modelos Melhorados/stylized_*` (Falcon, Ascona) | 2 carros antigos | carro | 94/98 mil | 1 m (escala x4,5) | sim | não | `car_falcon`, `car_ascona` (T-124) |
| `Modelos Melhorados/carro/low_poly_vehicle_mini_pack_5.*` | 6 SUVs | carro | 79 mil | 4,7 m cada | sim | não | `car_suv` (T-124) |
| `Modelos Melhorados/BUS+JETSET.fbx` (JETSET.dae) | ônibus | veículo | 143 mil | 3,0 x 13,3 x 3,9 | sim | não | `car_bus` (T-124) |
| `Modelos Melhorados/nypd_toyota_camry_.blend` | viatura | carro | 298 mil | ~4,9 m | sim (placa real) | esqueleto | `car_police` (T-143) |
| `Modelos Melhorados/kaohsiung*` (glb, gltf, blend, usdz) | bonde CAF Urbos | trem | 71 mil | 3,0 x 35 x 5,2 | sim | **animação** (portas, truques) | bonde amarelo da ferrovia (T-154); animação não usada (o bonde não para) |
| `Novos modelos/Carro/*` (blend, fbx, obj, stl) | jipe Suzuki | carro | 436 mil | ~3,95 m | sim (50 de 4K) | não | `car_jeep` (T-143) |
| `Novos modelos/Van+01/*` (FBX, obj, max) | van | carro | 504–718 mil | ~4,7 m | sim | não | van do trânsito (T-130) |
| `Novos modelos/Cabine/CF_500_complete.*` (stl, stp, 3dm) | International CF500 | cabine | 610 mil | unidade errada (cm) | não | não | referência da cabine chata (refeita por código) |
| `Novos modelos/Caminhão/canter.obj` | Mitsubishi Canter | caminhão | 130 mil | 7,4 x 2,5 x 3,2 | não | não | **não usado: extraído de outro jogo** |
| `Fundo Montanha Gelo/sNOWlaNDSCAPE.*` | relevo nevado | montanha | 6,27 mi | 53 x 53 x 6,6 (relevo) | sim | não | 4 maciços do horizonte (T-169/179) |
| `Agua/Water_Pack_Ozero.blend` | placa de ondas | água | 280 mil | 33 x 33 x 1 | não | ação vazia (0 quadros) | mapa de normais do mar (T-169) |

**Não existem em docs/Modelos** (procurado no disco D: e na pasta do usuário em 2026-10-21): outras espécies de
árvore (coqueiro, pinheiro, cedro, arbusto), um segundo poste de luz em arquivo próprio, prédios, e personagens além do
boneco do pacote ROAD SIGNS. Por isso, na T-186: coqueiros (3 formas), cedro, pinheiro, árvore redonda e arbusto são
**feitos por código** (`build_scenery_3d.py`, `build_tree_species.py`); o 2º poste de luz é o da Ponte A; a pessoa é o
boneco. Prédios: só os do jogo, caixas por código de 12 triângulos (LOD não se aplica).

## 2. Peças prontas no jogo

Custo = triângulos por cópia e chamadas de desenho (modo médio). Todas só visuais (nada na simulação nem na rede).

### Vegetação (T-186: `RoadsideTrees`, bosques por bioma)

| Peça | Arquivo | Triângulos perto / longe | Onde | Observação |
| --- | --- | --- | --- | --- |
| 6 Gleditsias | `scenery/tree_leafy[_b.._f].glb` + `_lod1` + `textures/backdrop/tree_leafy*_leaves.png` | 279–655 / 36 | litoral (terra), cidade, montanha | recorte por alfa; atlas próprio de cada uma |
| Coqueiros: palm, palm_tall, palm_bent | `scenery/palm*.glb` + `_lod1` | 512–690 / 104–112 | litoral (os dois lados) | por código, **refeitos na T-192**: tronco com anéis, 12–16 folhas em V com textura de folíolos, cocos, folhas secas embaixo |
| Pinheiro, cedro (sugi), árvore redonda, arbusto | `scenery/tree_pine/tree_cedar/tree_round/bush.glb` + `_lod1` | 152–738 / 50–84 | montanha (pinheiro, cedro), cidade (redonda), todos (arbusto) | por código, **refeitos na T-192**: galhos em cartões (agulhas/tufos de folhas) em volta de um miolo escuro, silhueta irregular |

**T-192 (folhagem em camadas)**: `blender -b --factory-startup -P blender/scripts/build_foliage_t192.py -- [--only nome] [--preview]`
gera os 7 modelos acima + `_lod1` e o atlas `textures/backdrop/foliage_leaves.png` (512 px: ramo de agulhas, tufo de
folhas, folha de coqueiro; pintado com numpy em `lib/tex_foliage.py`). No jogo eles usam os mesmos materiais das
Gleditsias (`BackdropKit.tree_mesh_of`: casca = cor por vértice, folhas = atlas × cor por vértice, recorte por alfa) e
cada árvore ganha um tom próprio (`Roadside3D.tree_tint`, cor por cópia do MultiMesh). Prévia:
`blender/renders/t192/foliage_sheet.png`. Os antigos (cones/esferas) estão no histórico do Git (commit anterior a 96187ed).
| Pedra | `scenery/rock.glb` | 124 | pé da mureta (montanha), praia | sem LOD |

Mistura (`RoadsideTrees.MIX`, pesos): **litoral** palm 16, palm_tall 14, palm_bent 10, arbusto 14, Gleditsia a/b/c
9/8/6, redonda 4 (folhosas só do lado da terra); **cidade** Gleditsia a/b/c/e 16/15/12/8, redonda 14, pinheiro 8,
arbusto 12; **montanha** pinheiro 20, cedro 22, Gleditsia d/e/f/c 10/9/9/7, arbusto 8. Bosques de 1 a 7 árvores (30%
de outra espécie no meio), 15–34 m da pista, espaçamento mínimo 3,2 m, intervalo de 14–46 m entre bosques, escala
0,8–1,3, giro aleatório. Fora de túnel, ponte, viaduto, fios e ferrovia paralela. LOD: o bloco de 150 m troca para a
versão leve a partir de 140 m (`Roadside3D.TREE_LOD_M`). `--old-trees` volta às árvores antigas; `--no-tree-lod` só o
LOD 0. Contagem: `godot --headless --path game -s res://tools_dev/probe_groves.gd`.

### Beira de estrada

| Peça | Arquivo | Custo | Onde liga | Desliga |
| --- | --- | --- | --- | --- |
| Poste de luz antigo (braço longo) | `scenery/lamp_post.glb` | 420 tri | praça do pedágio (0–420 m) e litoral no nível do chão | — |
| Poste de luz da Ponte A (T-186) | `scenery/lamp_bridge.glb` | 545 tri, 9,5 m | viaduto da cidade, serra (montanha), pontes | `--old-lamps` |
| Poste de energia com fios (電柱) | `kit/power_pole.glb`, `power_pole_tr.glb` | 222/256 tri | `PowerLineLayout.runs_for` | `--no-poles` |
| Guard-rail em W | `kit/guardrail_w.glb` | ~14 tri / 4 m | `RoadMesh`, `Roadside3D` | `--no-pontes-kit` |
| Barreiras, cavaletes, destroços | `kit/barrier_*.glb`, `debris_metal.glb` | 84–536 tri | eventos e túneis (T-146) | `--no-kit` |
| Placas japonesas, pórtico, outdoors | `kit/sign_*.glb`, `gantry_truss.glb`, `billboard_*.glb` | 60–120 tri | `RoadSigns`, `RoadFurniture`, `KitProps3D` | `--no-kit` |
| Pedágio, placa verde | `toll_gate.glb`, `sign_green.glb` | — | `Track.decorate_roadside` | — |

### Pessoas (T-186: `PeopleKit`)

| Peça | Arquivo | Custo | Onde |
| --- | --- | --- | --- |
| Pessoa em pé | `scenery/people/person.glb` (800 tri) e `person_lod1.glb` (200 tri) | 1 chamada por grupo; perto até 70 m, leve até 320 m | pedágio (4 funcionários de uniforme azul + 1 trabalhador de colete laranja), viaduto por cima (5 espectadores na cidade e 5 na montanha), abertura do duelo (os 2 motoristas ao lado das cabines, camisa na cor do caminhão; 5 clientes na área de descanso ou 3 funcionários no pedágio) |
| Retrato do motorista | `textures/people/bust_base.png` + `bust_shirt.png` (256 px) | — | faixa do duelo (G1): busto com a camisa na cor do caminhão, kanji do brasão num selo |

Camisa, calça e pele mudam por pessoa (shader); "parado" (idle) = balanço de peso e respiração no shader (o modelo não
tem esqueleto). `--no-people` tira tudo.

### Fundo, chão e estruturas

| Peça | Arquivo | Custo | Onde liga | Desliga |
| --- | --- | --- | --- | --- |
| Montanhas nevadas (4 maciços) | `scenery/backdrop/mountain_a..d.glb` | 899 tri cada | `CityBuilder._massifs` | `--no-backdrop` |
| Mar com ondas | `textures/backdrop/water_waves_nrm.png` | 1 chamada | `CityBuilder._add_ground` (litoral) | `--no-backdrop` |
| Pilar em "T" | `kit/pier_t.glb` | 302 tri | `PierT.append` | `--no-pontes-kit` |
| Viaduto por cima | `kit/overpass_deck*.glb` | 5–10 mil tri | `OverpassLayout.for_route` | `--no-overpass` |
| Semáforos de faixa | por código | ~40 tri | `TunnelSignals3D` | `--no-lane-signals` |
| Ferrovia, trens | `scenery/rail/*` | — | `RailwayLayout.lines_for` | `--no-rail` |
| Prédios | por código (caixa, 12 tri) | MultiMesh | `CityBuilder.build` | — |

## 3. Como regerar

- Árvores Gleditsia: `blender -b --factory-startup -P blender/scripts/build_tree_kit.py -- [--src ".../docs/Modelos/Arvore"] [--only a,b,c,d,e,f] [--preview]`
- Espécies por código e LOD1 das antigas: `blender -b --factory-startup -P blender/scripts/build_tree_species.py -- [--only nome,...] [--preview]`
- Poste da Ponte A e pessoa (+ retrato): `blender -b --factory-startup -P blender/scripts/build_t186_props.py -- [--root PASTA_PRINCIPAL] [--only lamp,person]`
- Folha de contato dos modelos com os materiais do jogo: `godot --path game --resolution 640x480 -s res://tools_dev/model_sheet_t186.gd -- --out=PASTA_ABS [--only=a,b]`

## 4. T-193 (2026-10-22): pastas novas de docs/Modelos

Inventário por script (`blender/scripts/inventory_models.py`, um `.json` por arquivo em `blender/renders/t193/inventory/`;
prévias de cada modelo em `blender/renders/t193/inspect/`). Nada foi alterado em `docs/Modelos`. Tamanho em metros
(largura x comprimento x altura) **depois** de corrigir a escala. Folha dos modelos com os materiais do jogo:
`docs/capturas_t193/folha_modelos.png`.

| Pasta / arquivo | Modelo | Tipo | Triângulos (original → jogo) | Tamanho (m) | Textura | Anim. | Onde está no jogo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `train/3d-model.fbx` (= `.obj`) | locomotiva diesel americana (cabine + capô longo) | trem | 10,6 mil → 5,2 mil | 3,1 x 18,9 x 3,9 (arquivo em escala errada: 2,3 m / OBJ 92 m) | não (cores lisas) | não | `scenery/rail/train_loco_b.glb`: 2ª locomotiva dos trens de carga (azul com faixa creme) |
| `train/Rail+Track.FBX` (= `.obj`) | trilho em 551 peças de 4 m | via | 57 mil | 4 x 0,5 m por peça (OBJ 400 m) | não ligada | não | **não usado**: a via do jogo já é uma malha contínua com textura (1 chamada por bloco) |
| `Vagoes/wagons.fbx/Logging car.fbx` (= `.obj`) | vagão de toras (vazio) | vagão | 12,9 mil → 2,3 mil | 2,9 x 16,1 x 4,3 (×1,87) | `Strips.png` (falta no pacote) | não | `train_wagon_log.glb`, carga de toras feita por código |
| `Vagoes/…/Platform car.fbx` | vagão plataforma com 2 contêineres | vagão | 18,8 mil → 2,2 mil | 2,9 x 15,8 x 4,7 | idem | não | `train_wagon_flat.glb` (contêineres verde-água) |
| `Vagoes/…/Semi - platform car.fbx` | gôndola de bordas baixas | vagão | 13,2 mil → 2,0 mil | 3,0 x 16,1 x 2,3 | idem | não | `train_wagon_semi.glb` (marrom) |
| `Vagoes/…/Transporter car.fbx` | vagão rebaixado com contêiner grande | vagão | 16,6 mil → 2,2 mil | 2,9 x 18,9 x 4,0 | idem | não | `train_wagon_box.glb` (vermelho) e `train_wagon_box_b.glb` (azul) |
| `Vagoes/…/Rails.fbx` + `Textures/Sleepers.png` | trilho + dormentes | via | 812 | 1,7 x 12,2 | sim | não | **não usado** (mesmo motivo do Rail+Track) |
| `CARS/…/Low Poly Cars Set.fbx` (= `.obj`, `.max`) | 3 carros, cada um repetido 3-4 vezes (10 objetos) | carro | 2,6 mi no total | — | jpg soltos (não ligados; um é logotipo Land Rover) | não | ver as 3 linhas abaixo |
| ↳ `desirefx.me_001` | cupê 4 portas | carro | 341 mil → 5,7 mil | 1,9 x 4,45 x 1,3 | cores lisas (atlas) | não | `car_lp_coupe.glb`: trânsito e ruas da cidade; emblemas apagados |
| ↳ `desirefx.me_003` | hatch arredondado | carro | 249 mil → 5,5 mil | 2,0 x 4,15 x 1,45 | idem | não | `car_lp_hatch.glb`: trânsito e ruas da cidade |
| ↳ `desirefx.me_002` | SUV | carro | 163 mil | 2,2 x 4,6 x 1,7 | — | não | **não usado**: a malha rasga ao reduzir para ~5 mil tri (o jogo já tem `car_suv`) |
| `Unico, apenas um carro/Skyline…FBX.fbx` (= `.obj`) | cupê esportivo azul estilo R34 (526 peças) | carro | 222 mil → 9,5 mil | 2,1 x 4,6 x 1,3 (arquivo ×2; OBJ com um plano de 20 km) | não (cores lisas) | não | `car_skyline.glb`: **carro único** (`UniqueCar`), estacionado 1 vez por corrida; bancos, volante e emblemas apagados |
| `Cidade/Buildings-FBX/*.fbx` (= `Buildings-OBJ`, falta o `Building-Big-01.obj`) | 8 prédios com textura assada 4K | prédio | 40 mil – 752 mil → 770 – 1,6 mil | 12–38 x 12–26 x 28–103 | sim (`Textures_no`, 4096 px 16 bits; também AO, normal, alpha...) | ações vazias | `scenery/city/bldg_*.glb` + `textures/city/bldg_atlas.png`: quarteirões da cidade (`CityModels`) |
| `Cidade/city.fbx` + `texture/cty1, cty2x.jpg` | "The City": bloco de torres low poly | cidade | 10,5 mil | 620 x 606 x 314 (×251; jogo ×0,7) | sim (fachadas) | não | `scenery/city/city_skyline.glb`: 3 blocos a ~820 m da pista na rota da cidade |
| `Cidade/The+City.obj` | o mesmo "The City" sem textura (com chão) | cidade | 11,8 mil | 2.277 x 2.124 x 871 | não | não | **não usado** (repete o city.fbx, sem textura) |
| `Cidade/FBX/CIT.fbx` (= `OBJ/CIT.obj`) + jpgs | cidade gerada de mapa OSM + céu em plano | cidade | 403 mil | 469 x 588 x 244 | 9 jpgs TexturesCom (não ligados no FBX) | não | **não usado**: pesado, layout de mapa real que não casa com a pista, e o jogo já tem quarteirões + os 8 prédios |
| `Letras Japones e neon/NeonText.blend` | painel com letreiros neon (texto, curvas, gato da sorte) | neon | 180 mil (+ textos/curvas) | 16 x 13 m o painel | `lines_albedo.png` + materiais neon | não | `textures/scenic/neon_t193_atlas.png` (1024): 大切に思ってる, 幻想通り, 夜空, 無限, 招き猫, 祈, 人 renderizados com os materiais neon do próprio arquivo; 1 em 3 letreiros da cidade |
| `Letras Japones e neon/…Neon Sign Pack Volume.1/Neon Signs.c4d` | pacote de neons (Cinema 4D + Octane) | neon | — | — | — | — | **não usado**: formato .c4d não abre no Blender nem no Godot |

### Peças novas no jogo (T-193)

| Peça | Arquivo | Custo | Onde | Desliga |
| --- | --- | --- | --- | --- |
| Locomotiva b + 5 vagões | `scenery/rail/train_loco_b`, `train_wagon_log/flat/semi/box/box_b.glb` (material único `rail_train`, atlas da T-154) | 2,0–5,2 mil tri; 1 MultiMesh por modelo, só desenha o que está à vista | trens de carga: locomotiva sorteada + 6–9 vagões em grupos de 1–3 iguais (`RailTraffic.make_train(tipo, rng)`) | `--no-rail` |
| 2 carros | `vehicles/traffic/car_lp_coupe/hatch.glb` | 5,5–5,7 mil tri, 4 superfícies | trânsito (`Traffic3D.MODELS_BY_KIND`), acidentados da T-183 (mesmo visual), ruas da cidade (`LifeStreets`) | `--traffic-classic` |
| 8 prédios | `scenery/city/bldg_*.glb` + `textures/city/bldg_atlas.png` (2048 x 1024) | 770–1,6 mil tri; 1 chamada por trecho de 250 m (até 420 m); depois caixa com o shader de fachada | lotes dos quarteirões (`CityModels`, 30/40/45% dos lotes nas fileiras 0/1/2+, metade no celular); janelas escuras acendem à noite | `--no-city-models` |
| Skyline | `scenery/city/city_skyline.glb` + `textures/city/skyline_facades.png` (1024) | 10,5 mil tri, 1 chamada cada (3) | rota da cidade, a 820 m da pista | `--no-city-models` |
| Neon kanji | `textures/scenic/neon_t193_atlas.png` | +1 chamada (2º MultiMesh do `NeonSigns`) | 1 em 3 letreiros (vertical, telhado, quadrado) | — |
| Carro único | `vehicles/traffic/car_skyline.glb` | 9,5 mil tri, 1 vez por corrida | litoral km 1,35 (lado do mar), cidade km 0,645 (no chão ao lado do viaduto, onde não há muro), montanha km 1,26 (lado do morro) | `--no-unique-car` |

### Como regerar (T-193)

- Carros: `blender -b --factory-startup -P blender/scripts/build_traffic_cars.py -- --model lp_coupe,lp_hatch,skyline [--preview PASTA_ABS]`
  (classe de cada peça pela geometria: `lib/traffic_groups.py`, porque os materiais do FBX vêm sem cor).
- Trens: `blender -b --factory-startup -P blender/scripts/build_t193_rail.py -- [--only nome] [--preview]`.
- Prédios (um processo por prédio: a textura 4K de 16 bits ocupa ~270 MB):
  `for k in big01 bigwide01 bigwide02 med01 med02 small sky01 sky02; do blender -b --factory-startup -P blender/scripts/build_t193_city.py -- --building $k; done`,
  depois `-- --atlas` e `-- --skyline`.
- Neon: `blender -b --factory-startup -P blender/scripts/build_t193_neon.py` (abre o .blend só para ler).
- Folha dos modelos (precisa de janela): `godot --path game --resolution 640x480 -s res://tools_dev/model_sheet_t193.gd -- --out=PASTA_ABS`.
- Onde fica o carro único: `godot --headless --path game -s res://tools_dev/probe_unique_t193.gd`.
