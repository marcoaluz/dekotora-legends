# Biblioteca de cenário (peças prontas para fases novas)

Pedido do Marco na T-159: os modelos servem de referência para fases novas; cada fase não precisa ter todos os itens.
Aqui ficam as peças **já prontas no jogo**, com o custo e onde ligar. Atualizado na T-169 (2026-10-21).
Custo = triângulos por cópia e chamadas de desenho (modo médio). Todas só visuais (nada na simulação nem na rede).

## Fundo e chão

| Peça | Arquivo | Custo | Onde liga / como escolher | Desliga |
| --- | --- | --- | --- | --- |
| Montanhas nevadas (4 maciços) | `assets/scenery/backdrop/mountain_a..d.glb` | 899 tri cada; 4 chamadas no total | `CityBuilder._massifs` (quantidade por cenário; neve por `BackdropKit.snow_for`) | `--no-backdrop` |
| Cones de montanha (antigo) | por código | 14 tri cada; 1 chamada | `CityBuilder._mountains` (sem o kit) | — |
| Mar com ondas | `assets/textures/backdrop/water_waves_nrm.png` | 1 chamada (plano) | `CityBuilder._add_ground` (cenário `coast`) | `--no-backdrop` |
| Skyline do outro lado da baía | por código | MultiMesh | `CityBuilder.build` (litoral) | — |

## Vegetação

| Peça | Arquivo | Custo | Onde liga | Observação |
| --- | --- | --- | --- | --- |
| Árvore de folhas (Gleditsia) | `assets/scenery/tree_leafy.glb` + `textures/backdrop/tree_leafy_leaves.png` | 279 tri; 2 chamadas por bloco de 150 m | `Roadside3D._tree_model` | 6,5 m; recorte por alfa |
| Pinheiro, árvore redonda, palmeira, arbusto, pedra | `assets/scenery/tree_pine/tree_round/palm/bush/rock.glb` | 124–1.272 tri | `Roadside3D._tree_model`, `_extras` | — |

## Beira de estrada

| Peça | Arquivo | Custo | Onde liga | Desliga |
| --- | --- | --- | --- | --- |
| Poste de energia com fios (concreto, 電柱) | `assets/scenery/kit/power_pole.glb`, `power_pole_tr.glb` (transformador) | 222/256 tri; 1 chamada postes + 1 fios por bloco de 400 m | `PowerLineLayout.runs_for` (trechos por rota) | `--no-poles` |
| Guard-rail em W | `guardrail_w.glb` + perfil `guardrail_w_profile.json` + `textures/kit/guardrail_*.png` | ~14 tri por 4 m (na malha da pista) | `RoadMesh` (litoral) e `Roadside3D` (curvas) | `--no-pontes-kit` |
| Barreiras listradas, cavaletes, destroços | `kit/barrier_*.glb`, `debris_metal.glb` | 84–536 tri | eventos e bocas de túnel (T-146) | `--no-kit` |
| Placas japonesas (chapas e postes) | `kit/sign_plate_*.glb`, `sign_post.glb` + atlas | 60–120 tri | `RoadSigns` (T-130/T-146) | `--no-kit` |
| Pórtico de treliça, outdoors | `kit/gantry_truss.glb`, `billboard_*.glb` | — | `RoadFurniture._gantry`, `KitProps3D` | `--no-kit` |
| Poste de luz, pedágio, placa verde | `lamp_post.glb`, `toll_gate.glb`, `sign_green.glb` | 420–2.088 tri | `Track.decorate_roadside` | — |

## Estruturas

| Peça | Arquivo | Custo | Onde liga | Desliga |
| --- | --- | --- | --- | --- |
| Pilar em "T" (Ponte A) | `kit/pier_t.glb` | 302 tri, deformado por pilar (mesma malha do concreto) | `PierT.append` (ponte do litoral, viaduto da cidade, viaduto antigo, viaduto por cima) | `--no-pontes-kit` |
| Viaduto rodoviário por cima da pista | `kit/overpass_deck.glb` (482 tri / 10 m), `overpass_deck_lite.glb` (68 tri) | ~5–10 mil tri por viaduto; 1 chamada | `OverpassLayout.for_route` (z e ângulo; achar retas com `tools_dev/find_overpass_spots.gd`) | `--no-overpass` |
| Semáforos de faixa nos túneis | por código (atlas gerado) | ~40 tri por pórtico; 2 chamadas por túnel | `TunnelSignals3D` (todo túnel; X vermelho pelos eventos) | `--no-lane-signals` |
| Túneis (novo 3 faixas e antigo 2 faixas) | por código | — | `RouteDef.tunnels`, `lane_sections` (`look: tunnel`) | — |
| Ferrovia, trens, viaduto de trem | `assets/scenery/rail/*` | — | `RailwayLayout.lines_for` | `--no-rail` |

## Não usados (referência)

Pórtico "Outdor" (placas reais dos EUA), ponte pênsil, túnel reto do arquivo, carreta do Kenworth (pesada demais; boa
candidata a carreta no trânsito lento), Canter `canter.obj` (extraído de outro jogo). Ver `docs/INVENTARIO_MODELOS.md`.
