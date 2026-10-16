# Multiplayer

Objetivo: Marco e 1 a 3 amigos correm juntos, no celular ou no PC, batendo caminhão contra caminhão.

## Decisões

| Tema | Decisão | Motivo |
| --- | --- | --- |
| Modelo | **Servidor dedicado autoritativo** | Todos veem a mesma batida e o mesmo dano; ninguém "trapaceia" o dano |
| Servidor | O próprio projeto Godot exportado headless (`--server`) | Um só código para jogo e servidor |
| Transporte | ENet (UDP) do Godot | Baixo atraso, já embutido |
| Jogadores por sala | 2 a 4 humanos; bots completam até 4 | Escopo do MVP |
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
   │◄── race_start(seed, rota, regras, garagens) ────►│
   │ commands (30/s) ───►│◄─────────── commands (30/s)│
   │◄── snapshot (20/s) ─┼──── snapshot (20/s) ──────►│
   │◄── race_end(resultados, dano, pagamento) ───────►│
```

## O que trafega

**Cliente → servidor (30 por segundo)**: `tick`, `steer` (−1..1), `throttle` (0..1), `brake` (0..1), `passing` (bool).
Cerca de 12 bytes.

**Servidor → clientes (20 por segundo)**: para cada caminhão `id`, `z`, `x`, `speed`, `lateral_vel`, `rpm`, `gear`,
`boost`, mais **eventos** do tick (colisão com zona e força, peça quebrada, Passing). O dano completo só vai
quando muda.

## Suavidade no cliente

- **Predição**: o cliente roda a simulação do próprio caminhão com os próprios comandos, sem esperar o servidor.
  Quando chega um snapshot, ele corrige: volta ao estado do servidor e reaplica os comandos ainda não confirmados.
- **Interpolação**: os outros caminhões são desenhados ~100 ms no passado, entre dois snapshots, para não tremer.
- **Colisão**: o cliente pode mostrar a batida na hora (faísca, som), mas o **dano** só vale o que o servidor mandar.

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
