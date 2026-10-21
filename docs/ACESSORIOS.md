# Biblioteca de acessórios Dekotora 3D

Gerada pelo prompt do Marco (`PROMPT_ACESSORIOS_3D.md`). 32 acessórios originais, modelados por script
no Blender, exportados em `.glb` (materiais PBR embutidos) para o Godot 4.7.

## Onde está cada coisa

| O quê | Caminho (dentro de `game/`) |
| --- | --- |
| Modelos `.glb` | `assets/vehicles/dekotora/accessories/<front\|lighting\|sides\|rear>/<id>.glb` |
| Caminhão base `.glb` (com pontos `MOUNT_*`) | `assets/vehicles/dekotora/truck/dekotora_truck_base_chata.glb` (baú médio + cabine padrão; T-129) |
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

## Peças tiradas de modelos de terceiros (T-126, 2026-10-18)

10 peças a mais, copiadas de pedaços dos modelos de `docs/Modelos Melhorados/` (fora do Git; Royalty Free, créditos em
`game/assets/LICENCAS.md`): `blender/scripts/accessories/thirdparty.py` escolhe as **ilhas** de malha por caixas
(`blender/scripts/lib/extract.py`), troca os materiais pelos nossos, apaga letreiros/emblemas (ilhas pequenas ou caixas de
exclusão), reduz por ilha (peças simples ficam inteiras) e leva para a convenção dos acessórios. Gerar:
`blender -b --factory-startup -P blender/scripts/build_accessories.py -- --thirdparty`.

| id | Peça | Encaixe (slot) | Ponto | Triângulos | Origem |
| --- | --- | --- | --- | --- | --- |
| `kw_exhaust_stacks` | Escapamentos altos cromados (com protetor) | `exhaust_stacks` (novo) | `MOUNT_STACK_R/L` | 2.989 | Kenworth W990 |
| `kw_fuel_tank` | Tanque cromado americano | `side_box` | `MOUNT_SIDE_BOX_R/L` | 2.193 | Kenworth W990 |
| `kw_steps` | Degraus cromados | `steps` | `MOUNT_STEP_R/L` | 1.592 | Kenworth W990 |
| `kw_visor` | Para-sol cromado com 3 lanternas | `visor` | `MOUNT_VISOR` | 2.556 | Kenworth W990 |
| `kw_bumper` | Para-choque americano | `front_bumper` | `MOUNT_FRONT_BUMPER` | 2.398 | Kenworth W990 |
| `kw_grille` | Grade cromada americana (sem o emblema) | `grille` | `MOUNT_FRONT_GRILLE` | 3.591 | Kenworth W990 |
| `fumi_wing` | Aerofólio de teto | `roof_wing` (novo) | `MOUNT_ROOF` | 1.232 | Fumi SC |
| `fumi_sport_rims` | Rodas esportivas douradas (5 raios) | `hubcaps` | `MOUNT_WHEEL_FRONT_FACE_R/L` | 3.246 | Fumi SC |
| `jac_steel_rims` | Rodas de aço cromadas | `hubcaps` | `MOUNT_WHEEL_FRONT_FACE_R/L` | 3.300 | JAC 1045 |
| `jac_toolbox` | Caixa de ferramentas | `side_box` | `MOUNT_SIDE_BOX_R/L` | 204 | JAC 1045 |

- `MOUNT_STACK_R/L` (atrás da cabine) ainda não existe nos .glb: o `TruckNode.add_extra_mounts()` cria o ponto ao montar o
  caminhão (padrão/clássica/aero/alta/chata: onde ficam os escapamentos de fábrica; cabine curta: canto de trás da cabine;
  Canter: entre a cabine e o baú, escala 0,88). Quem carregar o .glb sem o TruckNode chama a mesma função.
- Rodas/calotas (e a `hubcap_decorative`) **giram com o pneu desde a T-133**: o `TruckNode` (`TruckWheels.attach_part`)
  põe uma cópia em cada roda externa (frente, todos os eixos de trás, lado esquerdo espelhado) como filha do pneu; os
  pontos `MOUNT_WHEEL_*_FACE_*` servem só de referência de encaixe. O `AccessoryCatalog.attach` direto (visualizador de
  acessórios, teste de encaixe) continua prendendo no ponto fixo da frente.
- Não entraram (de propósito): tomada de ar do capô do Fumi (pequena demais para a cabine e sem lugar num cab-over),
  escapamento esportivo traseiro (briga com o para-choque traseiro), retrovisores (todas as cabines já têm), bull bar e
  faróis auxiliares (o Kenworth não tem).

## Peças deluxe — amostras de acabamento fino (T-172, 2026-10-21)

Pedido do Marco: "muito detalhe: neon, pisca, estura (lido como **estrutura lateral** e **estribo**), baú/andon em cima da
cabine como no Bakusou Dekotora Densetsu". 6 amostras feitas por código, com cromo de verdade (moldura com espessura,
coroa e bisel), parafusos sextavados, lâmpadas por revolução com lente em degraus (Fresnel), acrílico leitoso iluminado
por dentro, inox com escama "uroko" em mapa de normais e brilho do neon no asfalto. Marcadas `"tier": "deluxe"` no
catálogo; orçamento 6.000 triângulos por peça.

| id | Peça | Encaixe (slot) | Ponto | Triângulos | Materiais (chamadas por lado) |
| --- | --- | --- | --- | --- | --- |
| `andon_ichiban_dx` | Andon de cabine 一番星 (caixa de luz alta no teto da cabine; texto trocável `SIGN_TEXT`) | `andon` | `MOUNT_ROOF` | 5.304 | 6 |
| `marker_crown_dx` | Coroa de 9 lanternas de ônibus âmbar (piscam com o padrão de luzes) | `roof_lights` | `MOUNT_ROOF_LIGHTS` | 4.180 | 3 |
| `underglow_neon_dx` | Neon de chão: tubo em canaleta + brilho no asfalto | `underglow` (novo) | `MOUNT_SIDE_R/L` | 958 | 4 |
| `side_bumper_dx` | Estrutura lateral cromada (サイドバンパー): trilhos, painel "uroko", 10 lâmpadas + 6 lanternas | `side_skirts` | `MOUNT_SIDE_R/L` | 3.292 | 4 |
| `step_lit_dx` | Estribo cromado de 2 degraus, piso xadrez, LED e luz de cortesia no chão | `steps` | `MOUNT_STEP_R/L` | 634 | 6 |
| `rear_tail_bar_dx` | Barra traseira de 16 lanternas (âmbar em cima pisca, vermelha embaixo) | `rear_lamps` | `MOUNT_REAR_LAMPS` | 5.196 | 3 |

- **Gerar**: `blender -b --factory-startup -P blender/scripts/build_accessories.py -- --deluxe` (≈ 1 min; grava também
  `previews/<id>_{day,night,detail}_34.png` e a folha `previews/deluxe_contact_sheet.png`). Caminhão montado no Blender:
  `-- --assembled-deluxe --out-dir PASTA`. Código: `accessories/deluxe.py`, `lib/deluxe_geo.py`, `deluxe_previews.py`.
- **No jogo**: `AccessoryGlow` (`scripts/truck/accessory_glow.gd`) troca os materiais `glow_*` por um shader aditivo (mancha
  de luz calculada pela UV, na cor da lâmpada da peça) e controla a emissão do `acrylic_*`; a força segue
  `TruckNode.set_lights_on` (noite/túnel acende; de dia o chão quase some e o acrílico fica em 1/4).
- **Ver**: `godot --path game res://scenes/tools/accessory_viewer.tscn -- --cat=deluxe` (Tab até "Deluxe"; [N] luzes
  acesas/apagadas; `--day` começa de dia). Garagem: `-- --demo --body=base --cab=chata --parts=andon_ichiban_dx,...`.
  Capturas `docs/capturas_t172/` (`antes_depois_garagem_noite.png`, `antes_depois_garagem_dia.png`,
  `antes_depois_corrida.png`; `GODOT=... bash tools/capture_t172.sh PASTA_ABS` e `bash tools/sheet_t172.sh PASTA_ABS`).
- **Custo medido** (`bash tools/measure_t172.sh`: viaduto à noite, modo médio, sem vsync, caminhão de demonstração com
  as antigas → com as 6 deluxe no lugar das antigas do mesmo encaixe): chamadas de desenho do caminhão 212 → 229
  (+17; corrida 373–460 → 390–477), triângulos +7,9 mil por quadro, textura 51,1 → 52,0 MB, FPS no ruído
  (213–238 → 209–236).
- **Limites conhecidos**: as peças de lado têm 4,2 m (como as saias antigas) e passam da frente do baú no Canter e no baú
  leve (`docs/capturas_t172/canter/`; as saias antigas fazem igual); o brilho no chão fica 11 cm acima do chão do
  caminhão (para aparecer em cima da plataforma da garagem).
