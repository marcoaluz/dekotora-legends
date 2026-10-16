# Biblioteca de acessórios Dekotora 3D

Gerada pelo prompt do Marco (`PROMPT_ACESSORIOS_3D.md`). 32 acessórios originais, modelados por script
no Blender, exportados em `.glb` (materiais PBR embutidos) para o Godot 4.7.

## Onde está cada coisa

| O quê | Caminho (dentro de `game/`) |
| --- | --- |
| Modelos `.glb` | `assets/vehicles/dekotora/accessories/<front\|lighting\|sides\|rear>/<id>.glb` |
| Caminhão base `.glb` (com pontos `MOUNT_*`) | `assets/vehicles/dekotora/truck/dekotora_truck_base.glb` |
| Fontes `.blend` editáveis | `assets/vehicles/dekotora/source_blend/` (tem `.gdignore`: o Godot não importa) |
| Prévias (imagens) | `assets/vehicles/dekotora/previews/` (`<id>_34.png` e `assembled_<categoria>_*.png`) |
| Catálogo | `assets/vehicles/dekotora/catalog.json` |
| Scripts Blender | `blender/scripts/build_truck_3d.py`, `build_accessories.py`, `accessories/*.py`, `lib/{mesh3d,pbr,preview}.py` |
| Código Godot | `scripts/truck/accessory_catalog.gd`, `accessory_materials.gd`, `truck_node.gd`; demo: `scenes/tools/accessory_viewer.tscn` |
| Testes | `tests/test_accessories.gd` (6 testes) |

## Como ver

- **Demonstração:** `godot --path game res://scenes/tools/accessory_viewer.tscn`
  `Espaço` alterna caminhão montado / vitrine das peças isoladas · `Tab` muda de categoria · `1-4` vistas
  (frente, lado, traseira, 3/4) · setas ou botão esquerdo do mouse giram · roda do mouse aproxima ·
  `A` liga/desliga as peças montadas · `M` troca a variante de material.
- **Prévias do Blender:** abra `previews/assembled_front_34.png` etc.

## As 32 peças

Convenção: modelo com origem no **ponto de montagem**; peças de lado são do lado direito e o esquerdo é o
mesmo modelo espelhado (`scale.x = -1`, ponto `MOUNT_*_L`). Várias peças disputam o mesmo ponto
(são alternativas): monte uma por ponto.

**A. Frente** — `fb_standard_chrome` (para-choque cromado padrão), `fb_ornate_steps` (para-choque ornamentado em degraus),
`grille_frame_chrome` (grade com moldura), `visor_sunshade` (quebra-sol), `bumper_extension_lip` (extensão/chin),
`aux_round_lamps_pair` (par de faróis auxiliares), `front_trim_set` (frisos frontais), `front_crest_ornament` (sol e asas).

**B. Teto e iluminação** — `roof_light_bracket` (suporte), `roof_light_bar_rect` (barra retangular),
`roof_round_lamps_set` (5 faróis redondos), `roof_marker_small_lamps` (lanternas pequenas),
`antenna_decor_mount` (antenas), `roof_sign_lightbox` (placa luminosa, texto editável `SIGN_TEXT`),
`roof_light_frame_halo` (moldura neon), `roof_torii_ornament` (torii com lanterna).

**C. Laterais e rodas** — `skirt_chrome_panel`, `skirt_lit_neon`, `fender_extension`, `hubcap_decorative`,
`step_metal`, `side_trim_set`, `side_box_decor`, `side_ornament_wave`.

**D. Traseira e decoração** — `rb_decorative`, `rear_panel_frame`, `rear_lamp_cluster`, `side_panel_decor`,
`rear_plate_custom` (texto editável `PLATE_TEXT`), `mudflap_designed`, `rear_ornament_metal`, `panel_japanese_theme`.

Dimensões, triângulos (todas ≤ 4.500), pontos de montagem e materiais permitidos de cada uma estão no `catalog.json`.

## Pontos de montagem (`MOUNT_*`)

Nós vazios dentro do `.glb` do caminhão (Blender: +Y frente; Godot: frente = −Z). Lista completa e
coordenadas Godot em `catalog.json > truck > mount_points_godot_xyz`. Principais: `FRONT_BUMPER`,
`FRONT_GRILLE`, `FRONT_ORNAMENT`, `VISOR`, `ROOF`, `ROOF_LIGHTS`, `BODY_ROOF`, `SIDE_R/L`, `FENDER_R/L`,
`WHEEL_FRONT_FACE_R/L`, `STEP_R/L`, `SIDE_TRIM_R/L`, `SIDE_BOX_R/L`, `SIDE_ORNAMENT_R/L`, `SIDE_PANEL_R/L`,
`MUDFLAP_R/L`, `REAR`, `REAR_LAMPS`, `REAR_PLATE`, `REAR_PANEL`, `REAR_ROOF`.

## Como usar no código

```gdscript
var catalog := AccessoryCatalog.get_instance()
var truck := (load(TruckNode.MODEL_PATH) as PackedScene).instantiate() as Node3D
catalog.attach(truck, "fb_ornate_steps")           # lado R (ou peça central)
catalog.attach(truck, "skirt_chrome_panel", "R")
catalog.attach(truck, "skirt_chrome_panel", "L")   # espelhada
catalog.swap_material(node, "chrome", "paint_gold")  # variante sem duplicar geometria
```

## Como adicionar um acessório novo

1. Abra o módulo da categoria em `blender/scripts/accessories/` (`front.py`, `lighting.py`, `sides.py` ou `rear.py`).
2. Escreva `def minha_peca(m): ...` que devolve a lista de objetos usando `lib/mesh3d.py` (`box`, `cylinder`,
   `torus`, `plane_extrude`, `profile_extrude`, `tube`, `text3d`) e os materiais `m["chrome"]`, `m["lamp_pink"]`...
   (origem do mundo = ponto de montagem; +Y frente; +X direita; +Z cima; metros).
3. Registre um dict na lista `ACCESSORIES` (id, name, category, mount, mirror, build, materials).
4. Se precisar de um ponto novo, acrescente em `_MOUNTS_*` de `blender/scripts/build_truck_3d.py` e rode
   `blender -b --factory-startup -P blender/scripts/build_truck_3d.py`.
5. `blender -b --factory-startup -P blender/scripts/build_accessories.py -- --only minha_peca`
   (gera `.glb`, `.blend`, prévia e atualiza o catálogo; avisa de penetração no caminhão e de orçamento).
6. `godot --headless --path game --import` e `godot --headless --path game -s res://tests/run_tests.gd`.

## Resultado dos testes

- Blender: 32 peças geradas, todas dentro do orçamento (≤ 4.500 triângulos) e sem penetração acima de 0,12 m
  no caminhão (checagem de folga contra cabine, baú, para-brisa e rodas).
- Godot headless: catálogo carrega; os 32 `.glb` instanciam; todos os pontos `MOUNT_*` existem no caminhão;
  montagem e espelhamento funcionam; todos os materiais do catálogo têm definição.
- Inspeção visual feita: prévias do Blender das 4 categorias montadas e capturas da cena de demonstração no Godot
  (protótipos montados nas vistas de frente, teto e lateral; vitrine da categoria Frente).

## Problemas conhecidos / pendentes

- O cromo reflete o céu noturno escuro: de noite fica escuro. Para parecer mais cromo, o ambiente precisa de faixas
  claras para refletir (poste de luz, neon, painel do céu). Ajuste em `scripts/road3d/world_env.gd` (cores do céu)
  ou use um `ReflectionProbe`/céu panorâmico depois de ver no celular.
- Dano visual dos acessórios em 3D (amassado/quebrado) ainda não existe: a simulação já calcula (`DamageModel.part_state`);
  falta trocar material/deformar e soltar a peça (P35 faz só os detritos genéricos).
- Peças ainda não ligadas ao `loadout` da simulação nem à garagem (P41/P42): o catálogo é só a biblioteca de modelos.
- A maioria dos acessórios é geométrica; ornamentos orgânicos (dragões, carpas) não foram modelados. Texturas externas: nenhuma
  usada, então não há licenças a registrar (a fonte Noto Sans JP é OFL e fica em `assets/fonts/`).
- Referências: o prompt sugere estudar fotos da categoria Dekotora no Wikimedia Commons; **não** foram baixadas imagens
  (sem acesso interativo). Os desenhos são originais, inspirados nas características gerais do estilo.
