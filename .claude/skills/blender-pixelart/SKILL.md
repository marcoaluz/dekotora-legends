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
