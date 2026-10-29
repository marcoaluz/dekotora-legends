---
name: blender-pixelart
description: Use SEMPRE que for criar, alterar, rodar ou depurar scripts Python do Blender do Dekotora Legends (blender/scripts/), gerar sprites de pixel art a partir de modelos 3D, renderizar ângulos do caminhão, camadas de peças com holdout, máscaras de brilho, estados de dano ou folhas de contato. Traz uma biblioteca de referência TESTADA (scripts/pxlib.py) e as armadilhas já descobertas.
---

# Blender → pixel art (Dekotora Legends)

Leia também `docs/PIPELINE_ARTE_BLENDER.md` (o "o quê"). Esta skill é o "como", com código testado.

## Ponto de partida obrigatório

- `scripts/pxlib.py` (nesta pasta): biblioteca testada no **Blender 5.2 headless**. Copie para
  `blender/scripts/lib/` na P10 e evolua a partir dela; não reescreva do zero.
- `scripts/demo_pipeline.py`: exemplo completo de ponta a ponta (caminhão provisório + peça + 5 ângulos +
  holdout + glow + folha de contato). Rode-o primeiro para confirmar que o Blender do Marco funciona:
  ```
  blender -b --factory-startup -P .claude/skills/blender-pixelart/scripts/demo_pipeline.py -- --out blender/renders/demo
  ```

## Como rodar no PC do Marco (Windows)

- Sempre `blender -b --factory-startup -P <script> -- <args>`.
  `--factory-startup` ignora preferências e add-ons do Marco (resultado igual em qualquer máquina).
- Argumentos do script vêm depois de `--`: `sys.argv[sys.argv.index("--") + 1:]`.
- Caminhos: use `os.path` e caminhos relativos à raiz do projeto; nada de barra invertida fixa.
- numpy já vem no Blender. **Não** tente `pip install` dentro do Blender.
- Confira a versão no início: `bpy.app.version`. O Marco tem 4.x ou 5.x; o código precisa funcionar nos dois.

## Armadilhas já confirmadas (não repita)

| Problema | Causa | Solução (já em pxlib) |
| --- | --- | --- |
| Vermelho da paleta sai rosa | Cores de nós de material são **lineares**; a paleta é sRGB | `pxlib.lin()` em toda cor de material |
| Cores "lavadas" ou alteradas | View transform AgX/Filmic | `view_transform = "Standard"`, `look = "None"` |
| Pixels lidos com valor diferente do PNG | Conversão de colorspace ao carregar | `img.colorspace_settings.name = "Non-Color"` antes de ler/gravar |
| Nome do motor de render muda | 4.2–4.x: `BLENDER_EEVEE_NEXT`; 5.x: `BLENDER_EEVEE` | `reset_scene()` escolhe o que existir |
| Aviso `Material.use_nodes` obsoleto | No 5.x os nós estão sempre ligados | Só atribuir se existir e estiver desligado |
| Caminhão cortado nas curvas | Ângulo mostra o comprimento | `fit_camera()` com o MESMO zoom em todos os ângulos |
| Caminhão pequeno demais no ângulo reto | `fit_camera` usa o pior caso (curva forte) | Use ângulos menores (±12°/±6°) ou quadro mais largo (ex.: 128×72); decida olhando a folha |
| Imagem de cabeça para baixo | Blender guarda pixels de baixo para cima | `render_rgba`/`save_png` já invertem |
| Avisos "EGL Error" no terminal | Contexto gráfico sem tela | Inofensivos se o PNG foi salvo |
| Caminho relativo em `scene.render.filepath` no Blender em background vai parar na raiz do disco (`C:\blender\...`) | Caminho relativo | Use sempre caminho absoluto |
| Câmera com `to_track_quat('Z', 'Y')`: a imagem sai girada 90° | Eixo de track errado para câmera | `to_track_quat('-Z', 'Y')` é o certo para câmera |

## Regras do pipeline

1. **Determinismo**: `reset_scene(seed)` no início; ruído de dano com semente fixa. Mesmo script → mesmos pixels.
2. **Mesmo quadro para tudo de um caminhão**: base, peças, glow e dano usam o mesmo tamanho, a mesma câmera
   e o mesmo zoom. Nunca recorte cada PNG separadamente: a sobreposição no Godot depende disso.
3. **Camadas**: base = `set_layer(visible=base)`. Peça = `set_layer(visible=peca, holdout=base)`.
   Glow = `set_layer(visible=luzes, holdout=todo_o_resto)`.
4. **Supersample**: renderize `ss`× maior (padrão 4) e reduza com `pixelize()` (cor mais frequente por bloco,
   alfa por cobertura). Fica mais limpo que renderizar direto no tamanho final.
5. **Paleta**: toda cor final vem de `blender/palettes/dekotora.json`. Depois de gerar, confira que todos os
   pixels opacos estão na paleta (snippet abaixo).
6. **Materiais**: só três tipos — `toon_material`, `chrome_material`, `emissive_material`. Nada de texturas
   fotográficas. Detalhe pequeno some em 96 px: modele grande e simples.
7. **Geometria**: prefira `bpy.data` + `bmesh` ou as funções de `pxlib` (`box`, `cylinder_x`). `bpy.ops` exige
   contexto e quebra fácil em modo sem tela; use só os operadores de primitivas e `transform_apply`.
8. **Dano**: aplique modificadores antes de deformar; `dent` = deslocar vértices com `mathutils.noise`
   semeado + escurecer cromo; `broken` = esconder subpartes e inclinar a peça.

## Verificar SEMPRE antes de entregar

1. Rode o script e confira que terminou com a mensagem `OK`.
2. **Abra a folha de contato com a ferramenta Read** (ela mostra imagens) e descreva o que vê:
   proporções, cortes, cores estranhas, peças desalinhadas.
3. Rode a checagem de paleta:
   ```python
   # dentro do Blender, depois de gerar
   op = arr[arr[..., 3] > 0][:, :3]
   cores = np.unique(np.round(op * 255).astype(int), axis=0)
   pal = np.round(palette * 255).astype(int)
   assert all((pal == c).all(1).any() for c in cores), "cor fora da paleta"
   ```
4. Gere o JSON ao lado dos sprites: `size`, `anchor` (de `anchor_pixel`), `angles`, `layers`, `glow`.
5. Mostre a folha ao Marco e espere os comentários (prompt G2) antes de seguir para a próxima peça.

## Ferramenta opcional: MCP do Blender

Para *inspecionar* uma cena aberta (não para o pipeline, que é sempre por script), existe o servidor MCP oficial
do Blender Lab (exige Blender 5.1+) e o comunitário "MCP for Blender". Só sugira instalar se o Marco pedir ou se
um problema visual não puder ser entendido pelos renders.

## Caminhão 3D (T-106)

- (T-129) As cabines agora são todas de modelos de arquivo (`cab_chata.py`, `jac_cab.py`, `kw_cab.py`); os módulos de cabine por código
  (`cab_surface.py` etc.) foram apagados. Gerar todos os caminhões: `bash tools/build_all_trucks.sh`. Modelo grande demais (Kenworth,
  2 milhões de triângulos): descarte ilhas < 4 cm ANTES de `extract.decimate_islands` (milhares de ilhas = minutos de `bpy.ops`).
- (histórico T-106) Placas que seguem a casca da cabine usavam `truck3d/cab_surface.py` (função `patch()`). Toda placa precisa de uma
  linha nas dobras da casca; isso já é automático pelo atributo `kinks` da casca.
- Texturas por altura usam `mesh3d.uv_height` (u e v em metros, sujeira sempre embaixo, chuva descendo de cima).
- A folha de conferência sai em `previews/truck_<tag>_sheet.png` (com `--night`, `truck_<tag>_night_sheet.png`).
  O build sem `--no-preview` gera sozinho.
- Para medir triângulos e MB de textura: `python tools/glb_stats.py <arquivos .glb>` (só biblioteca padrão do Python).

## Graneleira (T-145)

- Comando: `blender -b --factory-startup -P blender/scripts/build_truck_3d.py -- --variant graneleira --cab chata|jac|curta|americana --body-src "docs/Modelos/Novas Melhorias/Carroceria/Carroceria_Brasil_Graneleiro.obj"`
- Em worktree, o `--body-src` não acha a pasta (ela é ignorada pelo Git e só existe na pasta principal): passe o caminho absoluto da pasta principal.
- Armadilha: os 64 trincos do original têm 964 triângulos cada; `gran_src._boxify` troca cada um por uma caixa (12 triângulos). Os parafusos de 1–2 cm são descartados de propósito (somem a 10 m).

## Carros de trânsito (T-124)

- (a) Gerar com `blender -b --factory-startup -P blender/scripts/build_traffic_cars.py -- --model all [--preview <pasta absoluta>]`.
- (b) Armadilha: não soldar vértices (`remove_doubles`) antes de separar peças soltas, senão pneu e aro viram uma peça só.
- (c) Armadilha: limpar o cache de imagens entre modelos (`C._IMG_CACHE.clear()`), porque os `.glb` do Sketchfab repetem os nomes `Image_0...`.
- (d) `traffic_kit.decimate(o, n, border_weight=50)` preserva as divisas entre classes de material (a linha preto/branco da viatura fica reta); serve para pintura de duas cores como a viatura. Não usar em malhas com muitas classes: o jipe se desfaz.
- (e) Malha sem materiais ou "esculpida" (carro batido): refazer em voxels (REMESH VOXEL 0,03) e alisar (SMOOTH 4 passadas) antes de reduzir. Código em `lib/traffic_wreck.py` (`_remesh`, `_smooth`).
- (f) Em worktree, passe `--src-dir`, `--new-dir` e `--wreck-dir` com caminho absoluto da pasta principal, por exemplo `blender -b --factory-startup -P blender/scripts/build_traffic_cars.py -- --model police,jeep,wreck --src-dir "<pasta principal>/docs/Modelos/Modelos Melhorados" --new-dir "<pasta principal>/docs/Modelos/Novos modelos" --wreck-dir "<pasta principal>/docs/Modelos/Novas Melhorias"`. Os originais ficam fora do Git.
- (g) Carro batido com `tire_w` (`blender/scripts/lib/traffic_wreck.py`): `_cut_wheels` apaga o pneu e o aro esculpidos do original (faixa de fora de cada roda) e `_round_wheels` põe rodas redondas nossas no lugar (a da frente sai esterçada em -9° depois da batida). `hem_z` corta as lascas penduradas abaixo da soleira, exceto perto das rodas. Os valores do carro batido estão em `build_traffic_cars.py` (`tire_w=0.24`, `hem_z=0.34`).

## Bake alta → leve (T-136, baú premium)

- Código: `blender/scripts/bake_box_premium.py` + `lib/bake.py`, `lib/cc0_mats.py`, `lib/meshbuild.py` (UV escrito à mão). Ver `docs/PIPELINE_ARTE_BLENDER.md`.
- (a) Armadilha: com "selected to active", o Blender procura cada pixel em CADA objeto selecionado sem threads: junte a malha alta num objeto só (3× mais rápido).
- (b) Armadilha: o passe DIFFUSE (cor) dá PRETO no metal (cor difusa = cor × (1 − metálico)); grave cor e metálico pelo passe EMIT (`cc0_mats.emit_pass`).
- (c) Oclusão no glTF: grupo de nós "glTF Material Output" com entrada "Occlusion" (`pbr.baked_full`); o Godot vira `ao_texture` canal R.
- (d) No Compatibility, metálico 1,0 sem reflexo fica quase preto: alumínio com 0,55. Texturas novas de `textures/`: conferir no `.import` `compress/mode=2` (e `normal_map=1` nas normais), senão ocupam 4× mais memória.

## Kit de beira de estrada (T-146)

- Comando: `blender -b --factory-startup -P blender/scripts/build_roadside_kit.py -- --src "<repo principal>/docs/Modelos/Novas Melhorias" [--preview]`. Em worktree passe `--src` (o padrão aponta para `<raiz>/docs/Modelos/Novas Melhorias`, pasta que a worktree não tem, pois fica fora do Git).
- Saídas: `game/assets/scenery/kit/*.glb` (só geometria + UV) e `game/assets/textures/kit/*.png`.
- Os .glb saem sem textura (`export_image_format="NONE"`) e o Godot cria os materiais pelo nome (`RoadsideKit.material`).
- Textura nova em `textures/kit/`: conferir no `.import` `compress/mode=2`, senão ocupa 4× mais memória.
- `.rar` (pacote do Placão, `tex.rar`) abre com o 7-Zip em `C:/Program Files/7-Zip/7z.exe`.

## Ferrovia (T-154)

- Comando: `blender -b --factory-startup -P blender/scripts/build_railway_kit.py -- --lrt-src "<pasta principal>/docs/Modelos/Modelos Melhorados/kaohsiung_circular_light_rail_caf_urbos_3.glb" [--preview] [--no-lrt]`.
  - `--preview` gera a folha de contato; `--no-lrt` gera sem o bonde (não precisa do .glb).
- Em worktree, passe `--lrt-src` com o caminho absoluto da pasta principal (a pasta `docs/Modelos/Modelos Melhorados` fica fora do Git).
- Armadilha: ao importar um .glb (`import_scene.gltf`) numa cena que já tem objetos, filtre só os objetos novos
  (conjunto de objetos antes × depois) antes de apagar qualquer coisa. Apagar "tudo que não é do script" pode levar junto os objetos que já estavam na cena.


## Peças deluxe (T-172)

- Comando: `blender -b --factory-startup -P blender/scripts/build_accessories.py -- --deluxe` (gera os .glb, prévias de dia/noite/de perto e `previews/deluxe_contact_sheet.png`); `-- --assembled-deluxe --out-dir PASTA` monta as 6 no caminhão do jogo (importa o .glb, que já tem os `MOUNT_*`).
- Código: `accessories/deluxe.py` (peças) e `lib/deluxe_geo.py` (moldura com perfil `frame`, `sweep_open`, `hex_bolt`, `bulb`, `bus_marker`, `round_tail`, texturas numpy de acrílico e escama "uroko" em mapa de normais).
- Convenção: `tier="deluxe"` no dict da peça vai para o catálogo; orçamento 6.000 triângulos (as outras 4.500). Materiais com nome `glow_*` (quadrado no chão, UV 0..1) e `acrylic_*` (face com textura na cor e na emissão) são tratados pelo `AccessoryGlow` do jogo.
- Armadilha: texto 3D em kanji com `offset` padrão (0,04 x tamanho) engrossa demais e os traços de 番/星 se fundem; use `text3d(..., offset=0.014, resolution=4)`.
- Armadilha: na prévia o chão fica em Z = 0; peça com brilho no chão precisa ficar 1 cm acima (senão o brilho pisca com o chão).

## Cenário T-169 (montanhas, mar, árvore, pontes e viaduto)

- Entradas em `docs/Modelos/` (pasta fora do Git). Os três scripts são determinísticos e gravam direto em `game/assets/`.
- Montanhas e mar: `blender -b --factory-startup -P blender/scripts/build_backdrop_kit.py -- [--snow-src "PASTA/docs/Modelos/Fundo Montanha Gelo/sNOWlaNDSCAPE.fbx"] [--water-src "PASTA/docs/Modelos/Agua/Water_Pack_Ozero.blend"] [--only mountains|water] [--preview]`
  - Padrões: os dois caminhos acima, relativos à raiz. `--only mountains` gera só os 4 maciços (`scenery/backdrop/mountain_a..d.glb`); `--only water` gera só `textures/backdrop/water_waves_nrm.png`.
  - `--preview` grava `blender/renders/t169/backdrop_sheet.png` (o mar aparece 2 × 2 para ver se há emenda).
  - Arquivo não encontrado: para com `ERRO:`.
- Árvore: `blender -b --factory-startup -P blender/scripts/build_tree_kit.py -- [--src "PASTA/docs/Modelos/Arvore"] [--preview]`
  - `--src` é a pasta `Arvore` (o script completa o caminho do `.fbx`). Saídas: `scenery/tree_leafy.glb` e `textures/backdrop/tree_leafy_leaves.png`. `--preview` grava `blender/renders/t169/tree_sheet.png`.
- Pontes, poste e viaduto: `blender -b --factory-startup -P blender/scripts/build_road_pontes_kit.py -- [--src "PASTA/docs/Modelos/Road_pontes"] [--pole-src "PASTA/docs/Modelos/poste/Utility_pole.blend"] [--preview]`
  - Gera em `game/assets/scenery/kit/`: `pier_t`, `guardrail_w`, `power_pole`, `power_pole_tr` e, desde a T-164, `overpass_deck.glb` (laje, vigas e corrimão, ~482 triângulos) e `overpass_deck_lite.glb` (68 triângulos).
  - `--preview` grava `blender/renders/t163/contact_sheet.png` (a pasta é `t163`, não `t169`).
  - Armadilha: se `--pole-src` não existir, o script não avisa. Ele volta ao poste antigo, sem caixa nem suporte em U. Confira a linha `NEW_POLE` no terminal.
- Armadilha (worktree): os padrões apontam para a pasta da worktree, que não tem `docs/Modelos`. Passe caminhos absolutos da pasta principal em `--snow-src`, `--water-src`, `--src` e `--pole-src`.
- Armadilha (T-179): `bmesh.ops.recalc_face_normals` numa **casca aberta** (relevo sem fundo, placa, terreno) pode
  escolher "para baixo" como lado de fora. No jogo o objeto fica do avesso (escuro, "lâminas"). Depois do recalc,
  confira a soma de `f.normal.z * f.calc_area()` e use `bmesh.ops.reverse_faces` se for negativa (como em `build_backdrop_kit.py`).
- Armadilha (CRLF): o Python do Windows grava texto com CRLF. Arquivo de texto que o Godot lê (JSON, por exemplo) precisa de `open(..., newline="\n")`, como o `guardrail_w_profile.json` em `build_road_pontes_kit.py`.

## Biblioteca de cenário (T-186)

- Inventário de qualquer pasta de modelos: `bash tools/inventory_models.sh [PASTA] [SAIDA]` (um Blender por arquivo,
  `blender/scripts/inventory_models.py`; .dae, .3ds, .max, .ma/.mb, .3dm, .stp não abrem no Blender 5 e saem com `error`).
- Árvores: `build_tree_kit.py -- [--only a..f] [--preview]` (6 Gleditsias + LOD1; código comum em `lib/tree_atlas.py`);
  `build_tree_species.py` (cedro, coqueiros, LOD1 das antigas); `build_t186_props.py` (poste da Ponte A e pessoa + busto).
- Armadilha: nos FBX da Gleditsia a ordem dos materiais muda entre as variações; o TRONCO é o material com a imagem
  "bark reflect" ("bark2" são os galhos finos). Pegar o material errado espalha os cartões da copa pelo tronco.
- Armadilha: o DECIMATE (collapse) não reduz malha aberta de galhos abaixo de ~2x o alvo, nem com 2 passes; para o LOD1 o
  tronco é trocado por um cone de 6 lados (`_simple_trunk`).
- Armadilha: imagem de "ID" renderizada com emissão sai em sRGB no PNG (0,5 linear = 0,735); compare com o valor convertido
  (`build_t186_props.bust`).

## Texturas do cenário (T-188)

- Comando: `blender -b --factory-startup -P blender/scripts/build_t188_textures.py` (gera as texturas da T-188 por código; por padrão grava em `game/assets/textures/scenic`, e `-- --out PASTA` troca a saída).
- Armadilha (alfa como máscara): ao salvar um PNG com alfa que o Godot usa como máscara, crie o `.import` com `process/fix_alpha_border=false`.

## Modelos de terceiros difíceis (T-193)

- **Prédio feito de milhares de painéis soltos** (vidro em planos com alfa): o Decimate Collapse para num piso (4–80 mil
  tri) e apagar peças pequenas abre buracos. Faça uma casca (Remesh voxel ~1/45 do tamanho, ou caixa subdividida se as
  paredes são planos finos) e **asse** a cor do original nela (Cycles, DIFFUSE só COLOR, selected-to-active, cage
  ~1,6 voxel): `build_t193_city.py`. Cuidado: casco convexo + Subsurf explodiu para 14 milhões de tri.
- **PNG de 16 bits** no Blender: `image.pixels` vem em valores LINEARES (é float); converta para sRGB antes de salvar
  com `save_png` (Non-Color). JPG/8 bits vêm já em sRGB. Use `image.scale()` antes de ler (4096² float = 270 MB).
- **FBX do 3ds Max sem cor nos materiais**: classifique por peça/slot pela geometria (`lib/traffic_groups.py`:
  pneu = slot que toca o chão, vidro = alto e comprido, lanterna = pequeno na ponta, emblema = peça miúda no centro da
  frente/traseira). Ver a frente pela prévia: os 3 carros do CARS e o Skyline vieram com a frente em -Y/-X.
- Vagões: colapso com **solda antes** rasga contêineres; sem solda e com simetria em X fica limpo. Na prévia, cada .glb
  importado cria uma cópia do material (`rail_train.001`...): aplique a textura em todas.

## Reduzir sem derreter (T-195, locomotiva do Marco)

- `DECIMATE COLLAPSE` em peça de máquina (capô, cabine) derrete a silhueta: a `train_loco_b` com 5,2 mil tri virou
  uma cunha que o Marco não reconheceu. Primeiro `bmesh.ops.dissolve_limit` (planar, 2°, `delimit={"MATERIAL"}`) e
  depois COLLAPSE só num grupo de vértices das partes pequenas (truques/rodas, abaixo de `LOCO_LOW_Z`).
- Pintura por face com polígonos grandes (laterais inteiras) dá manchas diagonais. Use uma tira vertical no atlas e
  UV por vértice = altura (`livery_uv`); a célula é escrita no PNG pelo próprio script (mesmos pixels sempre).
- PNG de 8 bits: `Image.pixels` já vem em sRGB / 255 (não converter de linear).

## Texto 3D em placas (T-199)

- `M.text3d(..., size, ...)` (`lib/mesh3d.py`): `size` NÃO é a altura da letra em metros (size 0,55 deu kanji de ~0,3 m
  e "東京 TOKYO" de ~1,3 m de largura). Confira na prévia (`previews/scenery_<nome>_34.png`). Com size grande, baixe
  `offset` (engrossa o traço proporcional ao tamanho; 0,04 vira borrão; use 0,008–0,012).
- Regerar só um modelo do cenário: `blender -b --factory-startup -P blender/scripts/build_scenery_3d.py -- --only sign_green`
  e depois `godot --headless --path game --import`.

## Oficina: encaixes e peças por papel (T-211)

- Encaixes: `build_sockets.py` (+ `lib/truck_measure.py`, `lib/socket_rules.py`) importa cada `.glb` do jogo e mede por
  vértices (numpy), em coordenadas do GODOT. Determinístico: rodar de novo não muda os JSON (`git status` limpo = ok).
- Peças: `build_t211_parts.py` + `accessories/t211_kit.py` (Face = plano com u/v/normal para pendurar LED, letreiro, neon).
  Na FRENTE da peça o eixo u é **-X** (quem olha de frente vê o +X do caminhão à esquerda): senão o letreiro sai espelhado.
- Armadilha: `bmesh.ops.recalc_face_normals` num **quadrado solto** (1 face) pode virar a face para dentro; no Godot ela
  some (culling). O Blender mostra as duas faces, então só aparece no jogo. `mesh_from` só recalcula com 2+ faces.
- Armadilha: `pixels.foreach_set` com array float64 dá "incorrect sequence item type": converter para float32.
- Exportar sem imagem (`export_image_format="NONE"`) quando o jogo põe a textura compartilhada (atlas); senão cada `.glb`
  carrega uma cópia.
- Loop de comparação: `--mounted PASTA --compare PASTA` (mesmo ângulo da captura, `VIEW` no script). As folhas com as
  capturas são de terceiros: só em `docs/Referencias/oficina/comparacao/` (fora do Git).

## Refino do deque/viseira (T-214)

- Grades de apoio por raios (`lib/truck_measure.surfaces`, BVHTree): `build_sockets.py` grava `<modelo>.surf.json` ao lado
  do JSON de encaixes. Determinístico (rodar 2× = arquivos idênticos).
- Armadilha: `M.cylinder(..., axis="Y", seg=6)` com `rotation_euler.y = 0` deixa uma QUINA embaixo (o canhão "em V" boiava
  2 cm no teto); 30° = face chata embaixo (conferido pelos raios do teste). Para seg=4, 45°.
- Canhões: objetos `POD<k>_*` são juntados num objeto por canhão (`_join_pods`) para virar o nó `POD<k>` no jogo.
- Textura de detalhe da estrutura: `t214_textures.py` (`--textures` regera); no `.import`: `compress/mode=2`,
  `mipmaps/generate=true` e `normal_map=1` na normal.

## Caminhões de homenagem (T-218)

- Build completo (raiz do projeto, Git Bash): `source tools/env.sh && bash tools/build_t218.sh [PASTA_ABS]`.
  Com a pasta, também gera as prévias (frente, lateral, traseira, 3/4, dia e noite) e as folhas de contato.
  Um processo por vez (memória). O uso exato está no topo de `tools/build_t218.sh`.
- Scripts: `blender/scripts/build_t218_trucks.py` (gera os 5 caminhões, LOD0/1/2), `truck3d/t218_cab.py` (cabine plana larga,
  4 faróis), `truck3d/t218_bodies.py` (5 carrocerias), `lib/tex_mural_t218.py` (mural da gueixa com emissão).
- Saída: `game/assets/vehicles/dekotora/truck/` (LOD0, com os pontos MOUNT_*) e os LODs em `truck/lod/` (o `TruckNode` troca sozinho pela distância).
- Armadilha: casca sem vértices no meio parece não ter teto para `lib/truck_measure.py`. Corte a cada 10 cm com
  `bisect_plane` para achar o teto de verdade.
- Armadilha: luz no teto da cabine impede o deque de encostar. Mantenha a luz fora da área do deque.
- Armadilha: teto acima de ~3,15 m estoura o limite de 4,55 m do deque de 2 níveis. Confira a altura antes de gerar.

## Vídeo antes/depois do peso (T-219)

- Script: `tools/video_t219.py` (raiz do projeto, não é de `blender/scripts/`). Uso:
  `blender -b --factory-startup -P tools/video_t219.py -- ANTES DEPOIS SAIDA [casos...] [--tiras]`.
  Gera MP4 lado a lado com o som do "depois" e as tiras de quadros. As sequências vêm de `tools/capture_t219.sh`.
- Não há ffmpeg instalado no PC: o Blender faz o MP4 pelo FFmpeg que vem com ele.
- Armadilhas do Blender 5:
  - `image_settings.media_type = "VIDEO"` antes de `file_format = "FFMPEG"`.
  - Use `se.strips` (não `sequences`) no editor de sequência.
  - `view_settings.view_transform = "Standard"`; com AgX as cores dos quadros do jogo desbotam.

## Oficina lote 2 (T-231)

- Script: `blender/scripts/build_t231_parts.py` (traseira, foguete e contorno do baú). Kit: `accessories/t231_kit.py`
  e `accessories/rocket_t231.py`.
- Medidas: `truck_measure.box_edges` (`lib/truck_measure.py`) mede o plano da face da lataria por raios na malha real.
  Não use os vértices do baú para isso: eles não batem com a face real.
- Armadilha: NÃO importe `build_t211_parts.py` de outro script. Ele chama `main()` ao ser importado e roda tudo de novo.
- Nos `.sh` que passam caminhos ao Godot, use `pwd -W` (caminho Windows); senão o Godot não acha a pasta.
- `_drop_module_ends` (no `build_t231_parts.py`) apaga as tampas escondidas nas pontas do módulo do meio (tubo, trilho):
  menos triângulos por metro.

## Pinturas (T-232)

- Script: `blender/scripts/build_t232_paint.py`. Rodar na raiz do projeto:
  `blender -b --factory-startup -P blender/scripts/build_t232_paint.py -- [--only id1,id2] [--sheets PASTA_ABS] [--no-art]`
  (`--sheets`: folhas de contato das artes, dia e noite; `--no-art`: só letras e folhas, sem regravar as artes).
- Saídas: `game/assets/vehicles/dekotora/paint_t232/{mural,rear,roof}/*.png` (cor + `_emit` para a noite). Determinístico.
- Biblioteca: `blender/scripts/lib/paint2d.py` (desenho em numpy, PNG sem metadados) e `lib/t232_*.py` (murais, traseira,
  teto, texto, glifos, kit). Tabela única das 33 pinturas (id, nome, preço, função que desenha): `lib/t232_registry.py`.
- Faces do baú: `lib/paint_measure.py` mede por raios na malha o retângulo de cada face (o jogo põe a arte 5 mm para fora).
- Armadilha: o Blender desenha um glifo reserva, sem erro, quando a fonte não tem o caractere (sai "tofu").
  Conferir os kanji com `lib/font_cmap.py` (tabela `cmap` da fonte) antes de aceitar o build.
- Depois do build, importar as três pastas (caminho de disco, não `res://`):
  `bash tools/import_textures_3d.sh game/assets/vehicles/dekotora/paint_t232/mural game/assets/vehicles/dekotora/paint_t232/rear game/assets/vehicles/dekotora/paint_t232/roof`
  (VRAM + mipmaps).
- `--batch` do Godot separa os argumentos por espaço: por isso os prints crus ficam em `blender/renders/t232/shots`
  (caminho sem espaço). Não use pasta com espaço nesse caminho.

## Oficina lote 4 (T-233)

- Script: `blender/scripts/build_t233_parts.py` (para-choques da frente, retrovisores, escadas e saias). Kit: `accessories/front_t233.py`,
  `accessories/mirror_t233.py`, `accessories/ladder_t233.py`, `accessories/skirt_t233.py`. Rodar na raiz do projeto:
  `blender -b --factory-startup -P blender/scripts/build_t233_parts.py -- [--only id1,id2] [--no-preview]`
- Saída: `accessories/front_t233/<id>.glb` (grupos `TOP_`/`MID_`/`BOT_`/`CEN_` + pontos `SIGNAL_L`/`SIGNAL_R`; o jogo ajusta a altura).
- Armadilha 1 (nomes): o Blender renomeia empties repetidos (`SIGNAL_L.006` vira o nó `SIGNAL_L_006` no Godot).
  Quem procura esses pontos no jogo tem que usar curinga (`SIGNAL_L*`). Ver a parte do Godot.
- Armadilha 3 (tanque): o tanque de combustível de fábrica sai ~0,1 m para fora do baú. Por isso as saias
  (`skirt_t233.py`) só entram nos trechos livres entre as rodas, medidos por raios, e deixam o tanque e a bateria de fora.
  (Medido pela T-233: tanque e bateria de fábrica saem 0,1 m para fora do baú; ver docs/DECISOES.md, entrada T-233.)

## Cabine trocável: kits de cabine e carroceria (T-240)

- Script: `blender -b --factory-startup -P blender/scripts/build_t240_kits.py -- [--cabs chata,jac,...] [--bodies alubox,...,base]`
  Saída `game/assets/vehicles/dekotora/truck/kit/{cab,body}_<id>.glb` + `kit/lod/` (baús antigos sem LOD).
- `build_sockets.py` mede as combinações do kit sozinho (`KIT_COMBOS`; importa carroceria + cabine com
  `truck_measure.import_truck([body, (cab, dy)])`, a cabine deslocada pelo comprimento do baú).
- Armadilha: a função `add` passada aos construtores precisa DEVOLVER o objeto (`jac_cab._badge` usa o retorno).
- Armadilha: no baú antigo a chapa do baú usa o material da cabine (`paint_white_panel`); na medição do kit ela é
  renomeada para `truck_paint_white_box` (senão a cabine HAYATE, que é mais curta, "come" a frente do baú).
- Os .glb não saem byte a byte iguais entre rodadas (ordem de alguns índices muda); a geometria é a mesma.
- (T-251/T-252) O `build_t240_kits.py` grava `kit/<nome>.json` ao lado de cada .glb: `front`/`gap`/`y0` da carroceria (onde a
  frente e o vão começam, altura do chão) e `back` da cabine. Também separa o chassi em malhas `frame_*` (não estica
  com a carga). `truck_measure.import_truck` aceita `(glb, dy, (y0, front, ext, shift))` para esticar a carga como o jogo.
- **Armadilha (matriz velha)**: depois de esticar ou mover objetos, chame `bpy.context.view_layer.update()` antes de ler
  `matrix_world`. Sem isso o andon do leve/longo foi parar a ~7 m (T-252).

## Oficina lote 5 (T-234)

- Script: `blender/scripts/build_t234_parts.py` (grades, escapamentos, buzinas, calotas, interiores e adesivos). Rodar na raiz do projeto:
  `blender -b --factory-startup -P blender/scripts/build_t234_parts.py -- [--only id1,id2] [--no-preview] [--no-art]`
  (`--no-art`: não refaz interiores nem adesivos; `--no-preview`: não grava as folhas).
- Capturas e folhas: `bash tools/capture_t234.sh [PASTA_ABS]` (Git Bash, com janela). Testes do jogo: `-- --only=t234`.
- Encaixes no jogo: `Lot5Fit` (`fits` grille, stack, horn, wheel) e `PaintFit` (interior, com `alpha` e `grid`). Ver a skill do Godot.
- **Armadilha (medida de peça de malha)**: `PartFit.aabb_in` de um MeshInstance3D devolve caixa vazia. No Blender a medida
  certa vem de `M.torus`/objetos já girados: não sobrescreva `rotation_euler` depois de `M.torus(axis=...)` (ele já gira o objeto).
- **Armadilha (commit compartilhado)**: se outra tarefa tem mudanças não commitadas no mesmo arquivo, não use `git add` (levaria tudo).
  Monte o blob só com a sua parte: `git hash-object -w ARQ` e `git update-index --cacheinfo 100644,HASH,CAMINHO`; depois `git commit`.

## Murais com imagens prontas (T-242)

- Fontes (obras de domínio público): `python -I tools/fetch_t242_sources.py [chave ...]` (Python do sistema, `-I`; só baixa o que falta;
  links e licenças em `blender/scripts/lib/t242_sources.py`; o download vai para `blender/renders/t242/fontes/`).
- Ukiyo-e (acervo): `blender -b --factory-startup -P blender/scripts/build_t242_ukiyoe.py -- --sheets PASTA_ABS` (`--only a,b` filtra).
- Anime (arte do Marco): `blender -b --factory-startup -P blender/scripts/build_t242_anime.py -- [--grid] [--sheet PASTA_ABS]`.
- Brilho `key` (`lib/t242_photo.py`, `g.key(col, ...)`): precisa da arte; a função recebe a arte carregada (`PH.load`) antes de ser chamada.
- `docs/Murais/*` fica fora do Git (`.gitignore`; só `docs/Murais/README.md` entra). Não commite as artes do Marco.
- Use caminho absoluto em `--sheets` e `--sheet`.

## Wallpapers (T-258)

- Build (raiz do projeto): `blender -b --factory-startup -P blender/scripts/build_t258_wallpapers.py -- [--src PASTA] [--sheet PASTA_ABS] [--install]`.
  `--src` (padrão `docs/Murais/wallpaper`); `--sheet` grava `wallpaper_proposta.png` na PASTA_ABS dada (sem ele, não há folha);
  a arte vai para `blender/renders/t258/`. Com `--install` grava no jogo (`paint_wall/`) e o `wallpapers.json`. Rode sem `--install` primeiro.
- Dados: `python -I tools/gen_t258_data.py [--dry] [--manifest CAMINHO]`. `--dry` confere sem gravar nada; `--manifest` aponta outro
  `wallpapers.json`. Sem o manifesto, o script para e pede para rodar o build antes.
- **Armadilha (patch em Python)**: num patch feito com um script Python, a sequência `\\n` dentro do texto procurado pode não casar
  com o arquivo (vira barra-invertida literal). Confira o trecho com `grep` antes de rodar o script que grava.

## Retrovisor colado e escada ao lado da porta (T-263)

- Medidas em `lib/truck_measure.py`: `pillar` (coluna do para-brisa por raios, chapa inteira na lataria, nunca no vidro
  nem na porta; 2 passadas: a 1ª acha a lateral de referência, a 2ª mede sem os pedaços do espelho de fábrica),
  `_stock_islands` (pedaços do espelho de fábrica por ilha da malha + material; peça grande que só passa ali = só a parte
  de fora da cabine; lanterna/vidro nunca), `ladder_side` (lateral atrás da porta e do vidro dela, acima da roda + 12 cm,
  reta pela lateral = `lean`, vão por altura = `gaps`). `ladder_front` ficou (1ª leitura, não usada).
- Regras em `lib/socket_rules.py`: `mirror_stay_*` com 2 caixas (base e braços) e `_clear_pads` (encolhe na altura);
  `ladder_*` com caixa que inclui o estribo (`LADDER_STEP`) e a caixa de LED (`LEDBOX_H`), para embaixo do deque.
- Peças: `accessories/mirror_t233.py` (grupos `PADF_`/`PADS_`, `pads` vão para o catálogo pelo `build_t233_parts.py`),
  `accessories/ladder_t233.py` (estribo + caixa de LED no `TOP_`).
- Ordem: `build_t233_parts.py -- --only ...` → `build_sockets.py` → `godot --headless --path game --import`.

## Escada na quina da frente da carga (T-267)

- Só cabine `americana` e `canter` (`truck_measure.CARGO_LADDER_CABS`): `build_sockets.py` troca `ladder_side` por
  `truck_measure.ladder_cargo(m, _cargo_trees(), sx, strips, edge_min)` (lateral da carga atrás da quina, por fora do
  contorno de LED `box_light_*`, entre as luzes de marcação; `lean` 0, vão a cada 1 cm, `sp_free` = alturas livres
  para espaçador). `socket_rules` grava 2+ caixas (`boxes`: escada + espaçadores) e `"on": "cargo"`.
- Depurar por que não coube: `ladder_cargo(..., dbg=lista)` junta (largura, z, motivo, y): "lateral curta", "luz/vidro",
  "acima da borda", "torta". Tanque com americana fica sem (lateral curva).
- Regerar só esses: `blender -b --factory-startup -P blender/scripts/build_sockets.py -- --only base_americana,leve_americana,longo_americana,graneleira_americana,alubox_americana,tarp_americana,pinkbox_americana,tanker_americana,dump_americana,canter`
- Armadilha: lanterna de 8 cm passa entre colunas de raio espaçadas de 9 cm. Para "não cobrir luz", use colunas a cada 2 cm.

## Saias grandes (T-265)

- Medida: `truck_measure.skirt_band(tree, m, sx)` (chamada no `front_side`): colunas de 2 cm da frente à traseira do baú;
  em cada coluna a saia vai de max(`SKIRT_FLOOR` 0,22, arco da roda) até 2 cm abaixo do baú; raios de fora só nessa
  altura. Arcos `skirt_arcs` (pneu + `SKIRT_CLR` 7 cm, um por eixo) crescem de 1 em 1 cm até `SKIRT_ARC_GROW` para
  contornar o para-lama de fábrica (`truck_plastic_black`, anel ~0,61 m nos baús antigos). `blocked` = o que cortou.
- Regras: `socket_rules.skirt_boxes` (degraus de 3 cm, maior caixa primeiro) e `zone_hit` (zona da roda com `round` =
  cilindro). O print do `build_sockets` tem a linha `T-265 saia dir ... arcos ... bloqueado ...`.
- Peças: `build_t265_parts.py` + `accessories/skirt_t265.py` exportam só os enfeites `MOTIF_<forma>_<material>` e as
  amostras `MAT_<material>`; o desenho (`skirt`) vai para o catálogo e o jogo monta o resto. Apague os objetos depois
  de exportar cada peça, senão a próxima sai com `.001` no nome e o jogo não acha o enfeite.
- Triângulos do catálogo: medir no jogo (`tools_dev/measure_t265.gd -- --out=ARQ.json`) e rodar `build_t265_parts.py --
  --tris ARQ.json`.
- Armadilha: face côncava (rabo da seta) em leque a partir da PONTA (a ponta enxerga todos os cantos); não pule triângulo.

## Para-choques grandes (T-264)

- Peças: `blender -b --factory-startup -P blender/scripts/build_t264_parts.py -- [--only id1,id2] [--no-preview]` (gera
  `accessories/front_t264/<id>.glb`, previews `t264_*` e entradas `deco` do `catalog.json`). Rode antes o `build_sockets.py`
  (abas medidas por raios em `lib/truck_measure.py`; regras em `lib/socket_rules.py`).
- Desenho das abas em `accessories/front_t264.py`; grupos TOP_/MID_/BOT_/CEN_ e LOD LTOP_/LMID_/LBOT_/LCEN_.
- Folha genérica (Blender + numpy, sem Pillow): `blender -b --factory-startup -P tools/sheet_t264.py -- SAIDA.png COLUNAS LARGURA_CELULA img1.png ...`.
- Armadilha: parafuso na face de CIMA no grupo CEN sobe acima do topo; a lâmpada na lateral da aba sai da caixa (a aba só tem a espessura).

## Murais praia (T-266)

- `blender -b --factory-startup -P blender/scripts/build_t266_praia.py -- [--sheet PASTA_ABS] [--install]`. Recortes, rosto e
  brilho noturno em `lib/t266_praia.py`; ajuda de desenho 2D em `lib/paint2d.py`. Sem `--install` só saem as folhas e a arte em
  `blender/renders/t266/arte`; com `--install` grava em `game/assets/vehicles/dekotora/paint_wall/` e o `blender/renders/t266/praia.json`.
- Depois: `python -I tools/gen_t258_data.py --manifest blender/renders/t266/praia.json` e
  `bash tools/import_textures_3d.sh game/assets/vehicles/dekotora/paint_wall/mural game/assets/vehicles/dekotora/paint_wall/rear game/assets/vehicles/dekotora/paint_wall/roof`.
- Build determinístico (mesmas imagens = mesmos bytes).
