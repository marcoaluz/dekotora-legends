# Prompts do Claude Code

Como usar:

1. Abra o PowerShell em `C:\Projetos\dekotora-legends` e rode `claude`.
2. Copie **um** prompt por vez (o bloco de texto inteiro) e cole.
3. Espere terminar, teste como o Claude explicar, responda com o resultado ou o erro.
4. Só passe para o próximo quando o atual estiver aprovado.
5. Ao final de cada prompt, peça: **"faça o commit e o push"** (ou use o prompt G3).

Os prompts já mandam o Claude ler os docs certos. Não precisa colar os docs junto.

**Atalho recomendado:** em vez de colar, digite `/tarefa P11` (com o código do prompt). O coordenador
escolhe sozinho o agente certo — Haiku para tarefas fáceis, Opus para as difíceis — e registra tudo no
quadro. `/painel` mostra o que cada agente está fazendo. Detalhes em `docs/AGENTES.md`.

---

## Prompts gerais (use a qualquer momento)

### G1 — Reportar erro
```
Deu este erro ao testar. Explique a causa em uma frase simples e corrija.
Depois me diga exatamente como testar de novo.

<COLE AQUI O TEXTO DO ERRO>
```

### G2 — Ajuste visual depois de ver um render
```
Olhei a folha de contato em blender/renders/contact_sheet.png. Ajustes que quero:
- <ex.: cabine mais baixa>
- <ex.: cromo mais claro>
- <ex.: luzes de teto mais grossas>
Ajuste os scripts, renderize de novo e gere uma nova folha de contato. Mostre o antes e depois lado a lado.
```

### G3 — Fechar a tarefa
```
Revise o que mudou nesta tarefa, rode os testes/validações possíveis, atualize docs/ROADMAP.md
(marque o item) e docs/DECISOES.md se alguma decisão mudou. Faça o commit com mensagem em português
no formato "fase-N: descrição" e o push.
```

### G4 — Onde estamos?
```
Leia docs/ROADMAP.md e o histórico do git. Me diga em 5 linhas: o que já está pronto, o que é o
próximo prompt e se há algo pendente ou quebrado.
```

### G5 — Revisão de código
```
Faça uma revisão do código de game/scripts/<pasta>. Procure: bugs, código que viola a regra
"simulação separada do visual" (CLAUDE.md), arquivos grandes demais e coisas difíceis de manter.
Liste os problemas por gravidade e corrija só os graves, explicando cada um.
```

### G6 — Explicar para aprender
```
Me explique, como para quem nunca fez jogo, como funciona <ex.: o renderizador da estrada>.
Use o código real do projeto como exemplo, em no máximo 15 linhas de texto.
```

---

## Fase 0 — Setup

### P00 — Conhecer o projeto e conferir o ambiente
```
Leia CLAUDE.md e todos os arquivos de docs/. Depois:
1. Resuma em 10 linhas o que é o jogo e como vamos trabalhar.
2. Confira se estes comandos funcionam e mostre a versão de cada um: git, git lfs, godot, blender.
3. Teste o Blender em modo sem tela importando bpy e numpy.
4. Teste o Godot headless abrindo o projeto em game/ e saindo (--headless --quit).
5. Liste o que estiver faltando ou errado, com o passo exato de docs/SETUP.md para corrigir.
Não crie código de jogo ainda.
```

### P01 — Configurar o projeto Godot
```
Configure o projeto Godot em game/ conforme docs/ARQUITETURA.md e CLAUDE.md:
- Renderizador Compatibility, resolução base 480x270, stretch mode "viewport", escala inteira,
  filtro de textura padrão Nearest, orientação paisagem.
- Input Map: steer_left, steer_right, throttle, brake, passing, pause — com teclado (WASD e setas,
  Espaço, Esc) e controle (analógico, gatilhos, botão A, Start).
- Autoloads vazios (só a estrutura com comentários): GameState, Settings, Net, AudioBus.
- Presets de exportação: Android (arm64, min SDK 26, target SDK 36, paisagem), Windows (x86_64) e
  Server (Linux, headless; sem a pasta assets/audio e sem sprites).
- Leitura do argumento --server no main.gd (por enquanto só imprime "modo servidor").
Valide abrindo o projeto em modo headless. Me explique onde ver cada configuração no editor.
```

### P02 — Primeira build no celular e no PC
```
Crie uma cena de teste em game/scenes/main.tscn que mostra, na resolução 480x270:
- fundo azul-noite da paleta (blender/palettes/dekotora.json),
- o texto "DEKOTORA LEGENDS" grande e um contador de FPS,
- um quadrado que segue o dedo/mouse.
Gere a build Windows e me guie, passo a passo, para gerar e instalar o APK no meu celular pelo
cabo USB usando o botão de deploy do Godot. Se a build Android falhar, leia o erro e corrija a
configuração. Ao final, me diga o que eu devo ver nos dois.
```

---

## Fase 1 — Teste do pipeline Blender

### P10 — Biblioteca comum do Blender
```
Carregue a skill blender-pixelart. Primeiro rode o demo_pipeline.py dela para confirmar que o meu
Blender funciona e me mostre a folha de contato. Depois, partindo do pxlib.py testado da skill (não
reescreva do zero), leia docs/PIPELINE_ARTE_BLENDER.md e crie a biblioteca em blender/scripts/lib/ com os módulos
scene, materials, shapes, camera_rig, render, pixelize, export, damage e palette, exatamente
como descrito. Requisitos:
- Tudo roda com "blender -b -P", sem abrir janela, e é determinístico (sementes fixas).
- pixelize.py usa só numpy (já vem no Blender): alfa binário, cor mais próxima da paleta,
  contorno opcional, recorte de borda.
- export.py salva PNG + JSON (tamanho, âncora, offset) e monta blender/renders/contact_sheet.png
  ampliada 4x com o nome de cada sprite embaixo.
Crie também blender/scripts/test_lib.py que monta um cubo cromado e uma esfera vermelha,
renderiza nos 5 ângulos e gera a folha de contato. Rode e me mostre o resultado.
```

### P11 — Caminhão base
```
Crie blender/scripts/build_truck_base.py e render_truck.py seguindo docs/PIPELINE_ARTE_BLENDER.md:
- Caminhão japonês de cabine plana GENÉRICO (sem marca, sem logotipo), com baú, ~12 m de comprimento,
  ~2,5 m de largura, ~3,2 m de altura. Low-poly, quinas marcadas.
- Detalhes que importam vistos de trás: porta traseira do baú com dobradiças, para-lama, pneus duplos
  traseiros, lanternas traseiras, faixa refletiva, escada.
- Pintura base branca com faixa da paleta; vidros escuros.
- Render nos 5 ângulos (L2, L1, C, R1, R2), câmera ortográfica atrás e levemente acima, sprite final
  em torno de 96x72 px no ângulo C. Também um render de 3/4 de frente ampliado só para revisão.
- Saída em game/assets/sprites/truck/base/ + folha de contato.
Rode, olhe as imagens geradas e descreva o que ficou bom e o que você mesmo mudaria. Depois espere
meus comentários.
```

### P12 — Três peças de teste com dano
```
Crie os scripts das peças fb_chrome_steps (para-choque frontal em degraus cromados — visível nas
laterais em curva), roof_lights_row (fileira de luzes no teto da cabine) e andon_kanji (painel
luminoso traseiro com o kanji 一番星 em fonte Noto Sans JP; se a fonte não estiver em
game/assets/fonts/, me diga onde baixar e use texto latino provisório).
Para cada peça:
- Modelo posicionado no caminhão base.
- 3 estados: ok, dent, broken (lib/damage.py).
- Render em camada com o caminhão como holdout, nos 5 ângulos, mesmo tamanho de tela da base.
- Luzes geram também *_glow.png.
Saída em game/assets/sprites/parts/<id>/. Folha de contato mostrando a base sozinha e a base com
as 3 peças empilhadas, nos 3 estados.
```

### P13 — Visualizador de camadas no Godot
```
Crie a cena game/scenes/tools/truck_viewer.tscn que:
- Monta o caminhão em camadas (truck_view.gd) a partir dos PNG + JSON da Fase 1.
- Setas esquerda/direita (ou botões na tela) trocam o ângulo L2..R2.
- Botões ligam/desligam cada peça e trocam o estado (ok/dent/broken).
- Fundo noturno; as camadas *_glow ganham brilho (WorldEnvironment glow ou shader simples).
- Escala 4x, pixels nítidos.
Rode no PC e gere a build Android para eu ver no celular. Esse é o teste de aprovação do visual.
```

---

## Fase 2 — Protótipo da estrada

### P20 — Simulação da pista e do caminhão
```
Leia docs/ARQUITETURA.md (seções "simulação separada" e "modelo de mundo") e docs/BALANCEAMENTO.md.
Implemente em game/scripts/sim/: commands.gd, track.gd, engine_model.gd (versão simples: torque fixo
por enquanto), truck_sim.gd e race_sim.gd, com passo fixo de 1/30 s.
- A pista de teste tem retas, curvas para os dois lados e uma subida (gerada em código por enquanto).
- O caminhão acelera, freia, vira, sente a curva empurrando para fora e perde velocidade no acostamento.
- NENHUM nó visual, Input ou áudio nesses arquivos.
Crie testes simples em game/tests/ que rodam em headless: acelerar 10 s em reta atinge velocidade
coerente; curva sem virar leva o caminhão para fora; frear para o caminhão. Rode os testes.
```

### P21 — Renderizador pseudo-3D
```
Implemente game/scripts/road/ (road_renderer.gd e sprite_projector.gd) e a cena race.tscn:
- Estrada estilo OutRun: segmentos projetados, faixas alternadas de asfalto, zebra nas bordas,
  linhas de faixa, curvas e subidas visíveis.
- O caminhão do jogador (camadas da Fase 1) embaixo e no centro, trocando de ângulo conforme a curva
  e o volante.
- Câmera atrás e acima; sensação de velocidade (faixas passando rápido).
- 60 FPS: desenhe com o mínimo de nós possível (um _draw ou uma malha).
Por enquanto, controles só por teclado. Rode e me diga o FPS no PC.
```

### P22 — Controles
```
Implemente game/scripts/input/local_input.gd e touch_controls.tscn conforme o GDD (seção Controles):
- Android: botões ◀ ▶ à esquerda; acelerar (grande), frear e Passing à direita; opção de inclinação
  (acelerômetro) em Settings.
- PC: teclado e controle pelo Input Map.
- Tudo vira Commands (steer, throttle, brake, passing). Botões semitransparentes, ajustáveis em tamanho.
Gere a build Android para eu testar no celular.
```

### P23 — Cenário de teste
```
Crie no Blender (blender/scripts/build_roadside_test.py) uma versão simples de: céu noturno,
silhueta de montanhas, skyline de cidade (3 camadas de parallax, largura repetível), poste de luz,
placa verde de rodovia, árvore, guard-rail. Renderize como pixel art com a mesma paleta.
No Godot, coloque o parallax reagindo à curva e os objetos na beira da estrada pelo projetor de sprites.
Ao final, faça uma gravação de tela ou capturas e me diga o que avaliar para decidirmos entre o plano A
(pseudo-3D) e o plano B (3D estilo PS1).
```

---

## Fase 3 — Corrida contra bots

### P30 — Tráfego
```
Implemente traffic_sim.gd (sim) e a visualização: carros comuns em faixas, mais lentos que os
caminhões, que trocam de faixa às vezes. Use quadrados coloridos se ainda não houver sprites.
Densidade leve/normal/pesada configurável. Colisão com tráfego reduz velocidade e (por enquanto)
só imprime no console.
```

### P31 — Bots rivais
```
Implemente bot_driver.gd: o bot gera Commands como um jogador. Comportamento: seguir a pista,
frear antes de curvas fortes, desviar do tráfego, tentar ultrapassar, às vezes fechar o jogador.
3 níveis de dificuldade. Até 3 bots na corrida, com caminhões base em cores diferentes.
Teste headless: 3 bots completam a pista de teste sem sair dela mais de 2 vezes.
```

### P32 — Colisões e dano por zona
```
Leia docs/GDD.md (Mecânicas) e docs/BALANCEAMENTO.md (Fórmulas e Distribuição do dano).
Implemente collision.gd e damage_model.gd na simulação:
- Contato entre caminhões (lado, traseira), impulso proporcional ao peso, empurrão lateral.
- Zona atingida → peças da zona perdem durabilidade → sobra vai para motor/direção/carga.
- Peça com durabilidade 0 vira "broken" e cai.
- Eventos de colisão emitidos para a apresentação (zona, força, peça quebrada).
Na apresentação: o caminhão troca o estado das camadas (ok/dent/broken).
Testes headless para a distribuição de dano com os números do BALANCEAMENTO.
```

### P33 — Passing, vácuo, carga, chegada e pagamento
```
Implemente: barra de Passing (bots abrem espaço; contra humanos só tremor e som), vácuo em reta,
integridade da carga, linha de chegada, ordem final e pagamento pela fórmula do GDD.
Tela de resultado simples com posição, carga, pagamento, Fama e lista de danos.
```

### P34 — HUD
```
Crie o HUD da corrida em pixel art: velocímetro, RPM e marcha, barra de turbo, barra de Passing,
posição (1º/4º), distância até o destino, integridade da carga e um mini-diagrama do caminhão
com as zonas coloridas por dano. Funciona em 480x270 e não cobre os botões de toque.
```

### P35 — Efeitos de batida
```
No Blender, renderize sprites de faíscas, fumaça (3 tamanhos) e destroços cromados. No Godot,
mostre faíscas no contato, fumaça quando o motor está danificado e a peça quebrada caindo e
ficando para trás na pista. Leve tremida de tela em batidas fortes.
```

---

## Fase 4 — Garagem e economia

### P40 — Todas as peças do MVP no Blender
```
Usando os scripts das peças de teste como modelo, crie TODAS as peças de docs/BALANCEAMENTO.md
(tabela "Peças decorativas"), com 3 estados de dano, camadas e glow. Murais: padrões geométricos
(ondas, raios) aplicados como textura nas laterais do baú. Gere também os ícones 32x32 de cada peça
para a garagem (render frontal). Uma folha de contato por slot.
```

### P41 — Dados em Resources
```
Crie as classes PartDef, EngineDef, TurboDef, ExhaustDef, RouteDef e RivalDef (ARQUITETURA.md) e um
.tres para cada item do BALANCEAMENTO.md em game/data/. Crie um teste que carrega todos e confere
se os sprites existem.
```

### P42 — Tela da garagem
```
Crie a garagem: caminhão grande no centro (visualizador da P13), lista de slots, peças possuídas e
à venda, com peso, durabilidade, Fama e preço. Mostra o efeito na aceleração e no peso total antes
de comprar. Funciona no toque e no mouse. Visual na paleta, fonte pixel.
```

### P43 — Reparo
```
Na garagem, mostre o dano de cada peça e sistema, o custo de reparo pela fórmula do BALANCEAMENTO,
"Reparar tudo" e reparo individual. Peça quebrada: reparar ou comprar nova. Murais riscados: repintar.
```

### P44 — Motor, turbo, escape e freio-motor
```
Substitua o torque fixo por engine_model.gd completo: curva de torque por RPM, 6 marchas automáticas,
turbo com atraso e pressão (boost), escape direto, freio-motor, perda de potência por dano.
Valores do BALANCEAMENTO. Os motores entram na garagem. Testes headless comparando aceleração 0-100
de cada combinação.
```

### P45 — Save e campanha de Kanto
```
Implemente GameState com save em user://profile.json (dinheiro, Fama, peças, montagem, dano,
progresso). Crie a campanha de Kanto: 3 trechos em RouteDef (rodovia costeira, viaduto urbano,
montanha) e o rival-chefe no terceiro. Menu principal → Campanha / Garagem / Opções.
```

### P46 — Bots, tráfego e cenário de Kanto no Blender
```
No Blender: 3 caminhões de bot (variações de cor e peças), 4 carros de tráfego genéricos (sem marca),
cenário de Kanto (céu, skyline de Tóquio genérico, mar e montanhas) e objetos de beira de estrada
(pedágio, placas verdes, postes, árvores, guard-rail). Integre nas 3 rotas.
```

---

## Fase 5 — Áudio

### P50 — Preparar e importar áudio
```
Confira os arquivos em game/assets/audio/ contra a lista de docs/AUDIO_ELEVENLABS.md. Liste os
que faltam. Para os loops: encontre um ponto de loop limpo (ou aplique crossfade curto), normalize
volume e converta a música para OGG com loop ativado no import do Godot. Me avise se algum som
estiver ruim para eu gerar de novo.
```

### P51 — Som do motor em camadas
```
Implemente engine_audio.gd conforme o GDD (Som do motor em camadas): 4 loops por motor misturados
por RPM com ajuste de tom, camada do turbo seguindo o boost, "pssh" ao soltar o acelerador com
turbo cheio, freio-motor, escape direto e chacoalho de dano. Crie uma cena de teste com sliders de
RPM, boost e dano para eu ouvir cada combinação.
```

### P52 — Efeitos e música
```
Ligue todos os efeitos aos eventos da simulação (batidas por força, peça quebrando, pneus na curva,
marcha, Passing, buzina da peça instalada) e a música por tela (menu, garagem, corrida dia/noite,
chefe, resultado). Volume de música e efeitos separados em Opções. Som dos outros caminhões com
volume pela distância.
```

---

## Fase 6 — Multiplayer

### P60 — Servidor e salas
```
Leia docs/MULTIPLAYER.md. Implemente server_main.gd e room.gd (modo --server) e Net (cliente):
criar sala com código de 6 letras, entrar com código, lobby com nomes, caminhões e "pronto",
regras da sala (rota, dano real/só na corrida, bots, tráfego, horário). Ainda sem corrida.
Me ensine a abrir o servidor e dois clientes no mesmo PC para testar.
```

### P61 — Corrida sincronizada
```
Ligue a corrida à rede: clientes mandam Commands a 30/s, servidor roda race_sim e manda snapshots
a 20/s (snapshot.gd compacto). Cliente desenha o estado recebido, ainda sem predição. Bots e tráfego
rodam no servidor. Teste com servidor + 2 clientes no mesmo PC.
```

### P62 — Predição e interpolação
```
Implemente client_sync.gd: predição do próprio caminhão com reconciliação, interpolação dos outros
~100 ms atrás. Adicione uma opção de debug para simular 150 ms de atraso e 2% de perda de pacotes.
Me mostre como comparar com e sem predição.
```

### P63 — Colisão e dano no servidor
```
Garanta que colisão, dano, peças quebradas, Passing, chegada e pagamento são decididos só no
servidor e chegam como eventos. O cliente mostra faísca/som na hora, mas aplica o dano do servidor.
Regra "Dano: Só na corrida" não grava dano. Jogador que sai vira bot até o fim.
```

### P64 — Perfis e jogo cruzado
```
Implemente profile_store.gd (um JSON por jogador em user://profiles/, escrita atômica) e o código de jogador conforme MULTIPLAYER.md. Compras e
reparos online validados pelo servidor. Campanha offline salva local e sincroniza ao conectar.
Teste: mesmo código de jogador no PC e no celular mostra a mesma garagem.
```

### P65 — Teste em Wi-Fi
```
Me guie para rodar o servidor no meu PC e conectar o celular pela mesma rede Wi-Fi (IP local,
firewall do Windows liberando a porta UDP). Adicione na tela de conexão um campo de IP manual
só para debug.
```

### P66 — Servidor no VPS
```
Escreva server/README.md completo e scripts em server/: exportar o preset Server, instalar num VPS
Ubuntu, abrir a porta UDP, rodar como serviço systemd com reinício automático, ver logs, atualizar.
Compare 2 ou 3 provedores de VPS com região em São Paulo (pesquise preços atuais) e recomende um.
Não contrate nada: eu decido.
```

---

## Fase 7 — Polimento

### P70 — Desempenho no celular
```
Meça FPS e uso de memória na build Android com 4 caminhões, tráfego pesado e noite. Encontre os
gargalos (draw calls, sprites, áudio, rede) e otimize até 60 FPS estáveis. Me diga o que mudou.
```

### P71 — Menus e UI finais
```
Refaça menus, lobby, garagem e resultado com visual final: fonte pixel, paleta, transições curtas,
sons de UI, suporte a toque/mouse/controle, textos em pt-BR vindos de game/data/i18n/.
```

### P72 — Rodada de testes
```
Gere builds Android e Windows de teste, um checklist do que os amigos devem testar e um modelo de
mensagem para eles reportarem problemas. Depois que eu colar o retorno, transforme em uma lista
priorizada de correções e ajustes de equilíbrio.
```

---

## Fase 8 — Publicação (opcional)

### P80 — Builds de release
```
Me guie para criar a chave de assinatura Android (e guardá-la com segurança fora do repositório),
gerar o AAB assinado e o .exe de release. Confira os requisitos atuais da Play Store antes.
```

### P81 — Loja
```
Prepare textos (pt-BR e inglês), lista de capturas de tela, ícone e banner (renderizados no Blender),
política de privacidade simples (o jogo guarda perfil no servidor) e o passo a passo da Play Console
e do itch.io.
```
