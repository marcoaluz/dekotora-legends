# CLAUDE.md — Kaidō Bakusō (nome de trabalho; pasta/repositório: dekotora-legends)

Leia este arquivo inteiro antes de qualquer tarefa. Ele é o contexto permanente do projeto.
**Depois leia `docs/STATUS.md`**: estado atual, ambiente do PC, como validar e o que está pendente.

## O projeto

Jogo de corrida de caminhões Dekotora (caminhões japoneses decorados), estilo Bakusou Dekotora
Densetsu (PS1). Android é o foco; também roda no PC Windows, com multiplayer cruzado entre os dois.

- Design completo: `docs/GDD.md`
- Arquitetura do código: `docs/ARQUITETURA.md`
- Multiplayer: `docs/MULTIPLAYER.md`
- Arte (Blender → pixel art): `docs/PIPELINE_ARTE_BLENDER.md`
- Áudio (ElevenLabs): `docs/AUDIO_ELEVENLABS.md`
- Números de equilíbrio: `docs/BALANCEAMENTO.md`
- Fases e tarefas: `docs/ROADMAP.md`
- Prompts de cada tarefa: `docs/PROMPTS.md`
- Decisões já tomadas: `docs/DECISOES.md`

## Equipe e papéis

- **Marco**: direção criativa, decide, testa no celular e no PC, gera áudio no ElevenLabs.
  Experiência em programação corporativa (SQL, PL/SQL), mas **zero experiência em jogos, Godot e Blender**.
- **Claude (você)**: escreve todo o código GDScript, todos os scripts Python do Blender,
  roda os comandos, propõe soluções e aponta trade-offs.

## Time de agentes (leia `docs/AGENTES.md`)

Você, na sessão principal, é o **coordenador**. Para cada pedido do Marco:

1. Classifique: **fácil** → subagente `ajudante-rapido` (Haiku) · **médio** → você mesmo ·
   **difícil** → subagente `especialista` (Opus). Na dúvida, o nível mais alto.
2. Registre a tarefa em `.claude/coordenacao/QUADRO.md` (ID `T-xxx`) e diga ao Marco em uma linha
   quem vai fazer e por quê.
3. Resposta `ESCALAR:` do ajudante → reenvie ao especialista. Seção `DELEGAR AO AJUDANTE` do especialista →
   abra tarefas novas para o ajudante. Duas falhas no mesmo nível → suba um nível.
4. Ao terminar tarefas médias, você também escreve no `.claude/coordenacao/LOG.md`.
5. `/painel` chama o `supervisor`; `/tarefa` executa este protocolo.

## Skills do projeto (`.claude/skills/`)

Carregue a skill certa ANTES de trabalhar no assunto (vale para você e para os subagentes):

| Skill | Quando |
| --- | --- |
| `blender-pixelart` | Qualquer script do Blender, render, sprite, camada, glow, dano, folha de contato. Tem `pxlib.py` testado. |
| `godot-dekotora` | Qualquer coisa em `game/`: GDScript, cenas, testes, exportação, rede. Tem os comandos testados. |
| `arte-dekotora` | Decidir como algo deve parecer, avaliar folha de contato, traduzir pedidos visuais do Marco. |

## Regras de trabalho

1. **Uma tarefa por vez.** Termine, teste, explique o resultado em português simples, e só então siga.
2. **Explique para iniciante.** Ao terminar, diga o que foi feito, como o Marco testa (onde clicar,
   o que deve ver) e o que pode dar errado.
3. **Rode antes de entregar.** Sempre que possível, execute o Godot headless ou o Blender em
   background para validar (`godot --headless --path game --quit`, `blender -b -P ...`).
4. **Não invente requisitos.** Se algo não está nos docs e muda o design, pergunte ao Marco.
5. **Atualize os docs.** Mudou uma decisão? Registre em `docs/DECISOES.md`. Terminou uma tarefa?
   Marque em `docs/ROADMAP.md`.
6. **Commits pequenos** com mensagem em português: `fase-2: estrada pseudo-3D com curvas`.
7. **Nunca apague** assets, renders ou dados do Marco sem perguntar.

## Stack

| Item | Escolha |
| --- | --- |
| Motor | Godot 4.7.x estável, GDScript, renderizador Compatibility, 2D |
| Projeto Godot | pasta `game/` (o jogo **e** o servidor dedicado usam o mesmo projeto) |
| Arte | Blender por linha de comando: `blender -b -P blender/scripts/<script>.py -- <args>` |
| Pós-processo de arte | numpy dentro do Python do Blender (não instalar Pillow) |
| Áudio | arquivos gerados pelo Marco no ElevenLabs, colocados em `game/assets/audio/` |
| Rede | ENet (UDP) do Godot, servidor autoritativo headless |
| Plataformas | Android (AAB/APK arm64, min API 26, alvo API 36), Windows x86_64, servidor Linux headless |

## Convenções de código (GDScript)

- Tipagem estática sempre: `var speed: float = 0.0`, `func step(dt: float) -> void:`.
- Arquivos e pastas em `snake_case`; classes com `class_name` em `PascalCase`.
- Comentários e nomes de variáveis em **inglês**; textos de UI vêm de `game/data/i18n/` (pt-BR primeiro).
- **Simulação separada do visual**: tudo em `game/scripts/sim/` não pode usar nós de render,
  `Input`, áudio nem `get_tree()` para desenhar. Recebe comandos e um `dt`, devolve estado.
  Isso permite rodar a mesma simulação no servidor.
- Dados de jogo (peças, motores, rotas, rivais) em Resources `.tres` dentro de `game/data/`.
- Sinais em vez de referências diretas entre sistemas sempre que possível.
- Um script por responsabilidade; arquivos com mais de ~300 linhas devem ser divididos.

## Convenções dos scripts Blender

- Ficam em `blender/scripts/`; código comum em `blender/scripts/lib/`.
- Todo script começa limpando a cena e é **determinístico** (mesma entrada, mesma saída).
- Medidas em metros, caminhão apontando para +Y, chão em Z = 0.
- Saída bruta em `blender/renders/` (fora do Git); sprites finais em `game/assets/sprites/`.
- Cada sprite final vem com um `.json` ao lado (offset, tamanho, âncora).
- Ao terminar um render, gere também uma **folha de contato** (`contact_sheet.png`) com todos os
  sprites lado a lado, ampliados 4×, para o Marco revisar de uma vez.

## Como o Marco reporta problemas

Ele cola o texto do painel **Output** / **Debugger** do Godot ou do terminal. Leia, explique a causa em
uma frase simples e corrija.
