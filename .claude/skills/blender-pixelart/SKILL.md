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
