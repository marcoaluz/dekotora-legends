---
description: Executa uma tarefa escolhendo o agente certo pela dificuldade (ajudante, coordenador ou especialista)
argument-hint: <descrição da tarefa ou código do prompt, ex. P11>
---

Tarefa pedida pelo Marco: $ARGUMENTS

Siga o protocolo de `docs/AGENTES.md`:

1. Se for um código de prompt (P00…P81, G1…G6), pegue o texto em `docs/PROMPTS.md`.
2. Classifique o nível (fácil, médio, difícil) pela tabela de roteamento. Na dúvida entre dois níveis, escolha o mais alto.
3. Abra a tarefa em `.claude/coordenacao/QUADRO.md` com novo ID, nível, agente e status `em andamento`.
4. Diga ao Marco em uma linha: `T-xxx → <agente> (<modelo>) porque <motivo>`.
5. Execute:
   - fácil → subagente `ajudante-rapido`
   - médio → você mesmo
   - difícil → subagente `especialista`
   Passe ao subagente: o ID, o texto completo da tarefa e quais docs ler.
6. Trate a resposta:
   - começa com `ESCALAR:` → status `escalada`, reenvie ao `especialista` com o motivo e o que foi descoberto.
   - tem `DELEGAR AO AJUDANTE` → abra uma tarefa nova para cada item e envie ao `ajudante-rapido`.
   - `PRECISA DECISÃO` → status `precisa Marco`, mostre as opções ao Marco e espere.
   - falhou duas vezes no mesmo nível → suba um nível.
7. Feche a tarefa no QUADRO (status e data) e explique ao Marco o resultado e como testar.
