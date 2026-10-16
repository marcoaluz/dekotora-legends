# Time de agentes

O trabalho no Claude Code é dividido entre quatro papéis, cada um com o modelo adequado ao esforço.

| Papel | Quem é | Modelo | Faz |
| --- | --- | --- | --- |
| **Coordenador** | A sessão principal, a que conversa com o Marco | Sonnet (recomendado) | Classifica cada tarefa, distribui, faz as médias, mantém o quadro |
| **ajudante-rapido** | Subagente | Haiku (o mais leve) | Tarefas fáceis e mecânicas |
| **especialista** | Subagente | Opus (o mais forte) | Tarefas difíceis, escaladas e revisões |
| **supervisor** | Subagente | Sonnet | Painel: mostra quem faz o quê, alertas, pendências |

Arquivos: `.claude/agents/` (definição de cada agente), `.claude/coordenacao/QUADRO.md` (tarefas),
`.claude/coordenacao/LOG.md` (relatos), `.claude/commands/` (comandos `/tarefa` e `/painel`).

## Como os agentes conversam

No Claude Code, um subagente não chama outro diretamente: **toda conversa passa pelo coordenador**,
e tudo fica registrado no quadro e no log, que todos leem.

```
                Marco
                  │  /tarefa P11      /painel
                  ▼                     │
          ┌── COORDENADOR (Sonnet) ◄────┘
          │   classifica e registra no QUADRO
          │
   fácil  │  médio: faz ele mesmo     difícil
     ▼    │                              ▼
 ajudante-rapido (Haiku)  ──ESCALAR──►  especialista (Opus)
     ▲                                   │
     └──────── DELEGAR AO AJUDANTE ◄─────┘
          │
          ▼  todos escrevem no LOG ao terminar
     QUADRO.md + LOG.md + git  ◄── lidos pelo supervisor (Sonnet) → PAINEL
```

- **Subir de nível:** o ajudante responde `ESCALAR: motivo` quando a tarefa é mais difícil do que parecia;
  o coordenador reenvia ao especialista com o que já foi descoberto.
- **Descer de nível:** o especialista lista partes mecânicas em `DELEGAR AO AJUDANTE`; o coordenador
  abre tarefas novas e manda ao ajudante. Assim o modelo caro não gasta tempo com trabalho braçal.
- **Duas falhas no mesmo nível** → sobe um nível automaticamente.
- **Decisão de design** → ninguém decide sozinho; status `precisa Marco`.

## Tabela de roteamento

| Nível | Agente | Exemplos |
| --- | --- | --- |
| **Fácil** | ajudante-rapido (Haiku) | Conferir arquivos de áudio/sprite, marcar ROADMAP, registrar DECISOES, criar .tres a partir de tabelas, textos de UI, renomear/mover arquivos, buscar no projeto, resumo do git, commit e push |
| **Médio** | coordenador (Sonnet) | Setup e configuração do Godot, telas de menu, HUD, garagem, ligar sistemas prontos entre si, peças novas no Blender copiando um script que já existe, bugs simples |
| **Difícil** | especialista (Opus) | Arquitetura, simulação (física, colisão, dano), multiplayer, renderizador pseudo-3D, som do motor em camadas, biblioteca do Blender (render, pixelização, holdout, dano), bug que resistiu a 2 tentativas, revisões de código (G5), decisões com trade-off |

Na dúvida entre dois níveis, usa-se o **mais alto**.

## Prompts por nível (ponto de partida)

| Nível | Prompts |
| --- | --- |
| Fácil | G3 (fechar tarefa), G4 (onde estamos), conferências da P41 e da P50 |
| Médio | P00, P01, P02, P13, P22, P23, P30, P34, P35, P40, P42, P43, P45, P46, P52, P65, P71, P72, P80, P81 |
| Difícil | P10, P11, P12, P20, P21, P31, P32, P33, P44, P51, P60, P61, P62, P63, P64, P66, P70, G5 |

## Como o Marco usa

| Quero… | Digito no Claude Code |
| --- | --- |
| Rodar um prompt do roadmap | `/tarefa P11` |
| Pedir algo avulso | `/tarefa conferir se todos os sons do motor V8 estão na pasta` |
| Ver o painel | `/painel` |
| Forçar um agente | "use o especialista para …" ou "use o ajudante-rapido para …" |
| Ver os agentes rodando agora | A lista de tarefas/agentes do próprio Claude Code mostra cada subagente ativo |
| Trocar o modelo do coordenador | `/model sonnet` (padrão recomendado) ou `/model opus` num dia de tarefas pesadas |
| Ver ou editar os agentes | `/agents` |

## Formato do LOG

```
## <AAAA-MM-DD HH:MM> · <ID> · <agente> · <CONCLUÍDA | ESCALADA | PRECISA DECISÃO | ERRO>
- Feito: <uma ou duas linhas>
- Arquivos: <lista curta>
- Validação: <o que foi rodado> (especialista e coordenador)
- Observação / Decisão pendente: <texto ou "nada">
```
