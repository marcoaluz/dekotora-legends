# Multiplayer

Objetivo: Marco e 1 a 3 amigos correm juntos, no celular ou no PC, batendo caminhão contra caminhão.

## Decisões

| Tema | Decisão | Motivo |
| --- | --- | --- |
| Modelo | **Servidor dedicado autoritativo** | Todos veem a mesma batida e o mesmo dano; ninguém "trapaceia" o dano |
| Servidor | O próprio projeto Godot exportado headless (`--server`) | Um só código para jogo e servidor |
| Transporte | ENet (UDP) do Godot | Baixo atraso, já embutido |
| Jogadores por sala | 2 a 4 humanos; bots completam até 4; 3–4 humanos = "comboio" (trânsito mais leve, T-156) | Escopo do MVP; campanha offline é 1 contra 1 |
| Entrada na sala | Código de 6 letras | Simples para amigos |
| Jogo cruzado | Android ↔ Windows | Mesmo protocolo |
| Perfis | Guardados no servidor, um arquivo JSON por jogador (o Godot não traz SQLite; se crescer, usar o addon godot-sqlite) | Mesmo caminhão no celular e no PC |
| Hospedagem | Fases de dev: PC do Marco. Online: VPS Linux pequeno | Custo só quando precisar |

## Fluxo de uma partida

```
Cliente A            Servidor                   Cliente B
   │ create_room ──────►│                            │
   │◄── código "KX4T9Q" ─│                            │
   │                     │◄─────── join_room KX4T9Q ──│
   │◄── lobby_update ────┼──── lobby_update ─────────►│
   │ ready ─────────────►│◄──────────────────── ready │
   │◄── race_start(seed, rota, regras, garagens, eventos) ►│
   │ commands (30/s) ───►│◄─────────── commands (30/s)│
   │◄── snapshot (20/s) ─┼──── snapshot (20/s) ──────►│
   │◄── race_end(resultados, dano, pagamento) ───────►│
```

## O que trafega

**Início da corrida** (protocolo versão 2, T-139): o `race_setup` leva também `events`, a lista de eventos de pista
(acidente, obras, estreitamento) que o **servidor** sorteou (fixos da rota + sorteio pela semente). O cliente monta a
mesma pista com essa lista; nada mais é enviado durante a corrida por causa deles (o dano vai na atualização normal).
Regra da sala `events: false` = pista livre.
**Protocolo versão 5** (T-153): o `race_setup` leva também `lane_sections`, os trechos de 2 faixas da pista
(`{start, end, lanes, taper, look}`, os da rota). O cliente usa a lista do servidor no lugar da rota dele; os trechos não
vão em `events` e continuam com `events: false` (são a pista, não um evento).

**Protocolo versão 6** (T-156): o `race_setup` leva `intro` (`full` = abertura frente a frente, `short` = só a contagem)
e `countdown_total` (segundos da contagem do servidor = abertura + 3 s: 9,4 s ou 3 s). O servidor fica em COUNTDOWN
esse tempo todo e só então larga (RACING). Cada cliente toca a abertura pelo **relógio do servidor**: segundos desde o
começo da contagem = (`countdown_total` − `countdown` do setup) + (agora − hora em que o setup chegou) + ping/2
(`DuelPlan.online_elapsed`); por isso quem carregou a cena mais devagar entra na abertura já adiantada e todos largam
juntos. O número da contagem segue o mesmo relógio e fica em "1" até chegar o RACING do servidor (ou 0,4 s depois da
hora prevista, se o aviso se perdeu); se o RACING chega antes do fim da abertura, ela acaba na hora. Pular a abertura
online deixa o jogador esperando na largada ("LARGADA EM N"). Quem decide a versão é o servidor: **2 jogadores** (ou 1
jogador contra 1 bot) = cheia, os dois humanos frente a frente; **3–4 jogadores** = curta, todos lado a lado (até 3 por
fileira, o 4º atrás) e **comboio**: trânsito um nível mais leve que a regra da sala (vai em `rules.traffic` do setup,
com `rules.convoy = true`). Mesma rota e mesmas pessoas da corrida anterior = curta (pronto para quando a sala voltar ao
lobby; hoje a sala acaba no fim da corrida). **Grid** (`StartGrid`, igual no servidor e na predição): lado a lado a
30 m do começo da pista. Medido no `tools/net_test.sh` (linha `LARGADA:`): o servidor larga X ms depois da hora que o
cliente previu (ver STATUS, T-156).

**Cliente → servidor (30 por segundo)**: `tick`, `steer` (−1..1), `throttle` (0..1), `brake` (0..1), `passing` (bool),
`horn` (bool, buzina segurada, T-144). Cerca de 13 bytes.

**Servidor → clientes (20 por segundo)**: para cada caminhão `id`, `z`, `x`, `speed`, `lateral_vel`, `rpm`, `gear`,
`boost`, flags (Passing, acostamento, chegou, **buzina**, **freada forte**, **empurrado** — fumaça nos pneus, **lado do
tranco** — 2 bits, T-152), **tranco** (u8, ticks que faltam, T-152), mais
**eventos** do tick (colisão com zona e força, peça quebrada, Passing, carro arremessado, freada). Cada carro do trânsito
leva `z`, `x`, **giro** (s16, milirradianos) e **altura** (u8, 2 cm) — o carro arremessado é desenhado igual em todos
(T-141). O dano completo só vai quando muda. **Protocolo versão 6** (4 = T-152, 5 = T-153, 6 = T-156; cliente e servidor precisam da mesma versão: gere o APK de novo).

## Suavidade no cliente

- **Predição**: o cliente roda a simulação do próprio caminhão com os próprios comandos, sem esperar o servidor.
  Quando chega um snapshot, ele corrige: volta ao estado do servidor e reaplica os comandos ainda não confirmados.
- **Faixas (ATB-1)**: o comando `steer` é a direção SEGURADA (-1/0/+1); a simulação detecta o toque (borda 0 → lado).
  Por isso o snapshot leva também faixa alvo, seta, tempo da seta, toque anterior e tempo de troca (5 bytes por caminhão),
  senão a predição do cliente discordaria do servidor.
- **Interpolação**: os outros caminhões são desenhados ~100 ms no passado, entre dois snapshots, para não tremer.
- **Colisão**: o cliente pode mostrar a batida na hora (faísca, som), mas o **dano** só vale o que o servidor mandar.
- **Batida no trânsito (T-152)**: a penalidade de velocidade e o tranco são calculados só no servidor (o cliente vê o
  trânsito ~100 ms no passado e não prevê a batida). O snapshot leva o tranco em ticks, então a predição bloqueia o
  acelerador nos mesmos ticks que o servidor. No 1º snapshot com o tranco o caminhão "volta" Δv × RTT (1–3 m a 150 ms);
  nesse snapshot a correção é suave até 6 m (`ClientSync.JOLT_SMOOTH_Z`) em vez de teleportar: na tela parece a freada da
  batida. Medido (`tools/net_test.sh 150 0.02`, com batidas de 26% e 32%): erro de predição máximo 2,5–2,6 m, médio ~0,3 m.

## Perfis e economia

- Cada jogador tem um **código de jogador** gerado na primeira abertura (salvo no aparelho).
  Para usar o mesmo perfil no PC, o jogador digita esse código (MVP; login de verdade depois).
- O servidor guarda: dinheiro, Fama, peças possuídas, montagem atual, dano atual.
- Compra e reparo passam pelo servidor quando online. Offline (campanha), salvam local e sincronizam ao conectar.
- Regra de sala **Dano: Só na corrida** → o servidor não grava o dano no fim.

## Etapas de implementação (Fase 6)

1. Duas janelas do Godot no mesmo PC: uma `--server`, outra cliente. Sala e lobby funcionando.
2. Corrida com 2 clientes locais, sem predição (vai parecer travado; é esperado).
3. Predição e interpolação.
4. Colisão e dano decididos no servidor.
5. Simular atraso: usar a opção de latência do ENet / um proxy local para testar 100–200 ms.
6. Perfis em JSON no servidor.
7. Celular na mesma rede Wi-Fi conectando no PC do Marco.
8. Servidor num VPS Linux; amigos jogando de casa.

## Servidor em produção (resumo; detalhes em `server/README.md`)

- Exportar preset `Server` (Linux, headless).
- VPS com Ubuntu, abrir a porta UDP do jogo (ex.: 24600).
- Rodar como serviço `systemd` que reinicia sozinho.
- Uma instância aguenta várias salas pequenas.

## Riscos

| Risco | Plano |
| --- | --- |
| Lag de celular em 4G | Predição; servidor em região próxima (São Paulo) |
| Diferença de resultado entre cliente e servidor | Servidor sempre manda; cliente corrige suavemente |
| Jogador sai no meio | Bot assume o caminhão até o fim |
| Abuso de economia | Compras e reparos validados no servidor |
