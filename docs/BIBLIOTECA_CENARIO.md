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
