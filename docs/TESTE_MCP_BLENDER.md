# Teste do MCP do Blender (T-105)

Data: 2026-10-17. MCP usado: **"MCP for Blender"** (comunidade, MIT), add-on 1.8, Blender 5.2.2 LTS.
O Blender Lab MCP oficial foi pesquisado, mas a página dele não cita Claude Code nem lista ferramentas;
Marco aprovou a versão da comunidade.

## O que foi feito

A **frente de um Dekotora à noite**, modelada só por código Python enviado ao Blender aberto
(`execute_blender_code`), com a referência `docs/dekotora_volvo_3d_references/01_dekotora_front_bumper.png`:
cabine com carenagem, para-brisa com neon, grade com 5 fileiras de LED, faróis, para-choque cromado com
6 lâminas de neon anguladas, placa central, espelhos cromados, andon "龍王丸" (fonte japonesa do Windows),
fileiras de luzes no teto, asfalto molhado, placas de rua e luzes de cidade ao fundo, glare no compositor.
Tudo com blocos simples (279 objetos, ~1.900 faces). Resultado: `docs/direcao_arte/mcp_blender_frente_cycles.png`.
Arquivo de trabalho (fora do Git): `blender/renders/mcp_teste/frente_dekotora_mcp.blend`.

Comparar com o visual atual do Godot: `docs/direcao_arte/dekotora_v7_34.png`.

## Veredito honesto

**O que o Cycles faz melhor que o Godot (Compatibility):**
- Cromo reflete o entorno de verdade (letreiros, luzes), sem truque de matcap.
- Asfalto molhado com reflexo real das luzes e dos letreiros, que é o que dá o "clima" da referência.
- Brilho (bloom) em volta de neon e faróis, saturação alta sem ficar chapado.

**O que não ficou bom:**
- A forma ainda é uma **caixa**: a cabine não tem a curvatura de um Volvo FH. Os dois lados (modelo e render) têm o mesmo problema
  de proporção; o render bonito não esconde isso. Bom render não substitui bom modelo.
- Falta o que dá o ar da referência: dragões/murais, grades cromadas ornamentadas, textura de pintura, pessoas e ruas reais.
- O 1º render saiu pastel (curva AgX + emissivo forte) e o 2º cortou o enquadramento: foram 3 renders até chegar neste.

**Custo/limites do MCP:**
- Render no PC do Marco (i3-8100, sem GPU compatível): **95–135 s** por imagem 1280×720 com 64 amostras. O MCP move chamadas acima de
  120 s para segundo plano e avisa ao terminar.
- Cada chamada de código começa sem memória das anteriores (variáveis somem); usar arquivo auxiliar ou refazer o contexto.
- Blender 5: o compositor mudou (`scene.compositing_node_group`, nó de grupo de saída); `scene.node_tree` não existe mais.
- Subagentes (ajudante/especialista) **não têm** as ferramentas do MCP; só a sessão principal.

## Conclusão

- O MCP funciona bem para **iterar a aparência olhando o resultado** (`look` mostra a cena; muda e vê em segundos).
- Para o jogo, o caminho atual (scripts em `blender/scripts/` rodados em linha de comando, determinísticos) continua melhor para
  produzir os `.glb`: é repetível e roda sem o Blender aberto.
- Uso recomendado do MCP: **protótipo e direção de arte** (testar luz, cor e reflexo, ver o alvo de qualidade) e depois trazer o que
  funcionou para os scripts. Os valores que deram certo aqui (emissivo ~3 com bloom, vidro preto, luzes de preenchimento fracas e coloridas)
  servem de referência para a luz do Godot.
- Renders em tempo real (Godot) não chegam no reflexo real; a distância pode ser reduzida com matcap (V6, feito) e reflexo falso (V5, feito).
  Renderizar Cycles só vale para arte de loja e tela de título.
