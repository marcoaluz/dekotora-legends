# Rodada de testes com amigos (P72)

## O que mandar

| Plataforma | Arquivo | Como gerar |
| --- | --- | --- |
| **Windows** | `builds/dekotora.exe` (arquivo único, ~130 MB) | `godot --headless --path game --export-release "Windows" ../builds/dekotora.exe` (já gerado) |
| **Android** | `builds/dekotora.apk` | **PRECISA MARCO**: instalar Android SDK + JDK 17 (`docs/SETUP.md`, passo 5) e rodar `godot --headless --path game --export-debug "Android" ../builds/dekotora.apk` |
| Servidor | PC do Marco (`docs/REDE_WIFI.md`) ou VPS (`server/README.md`) | — |

Todos precisam estar na **mesma versão** do jogo e do servidor. No Windows o amigo pode ver um aviso do SmartScreen
("editor desconhecido"): *Mais informações → Executar assim mesmo* (o arquivo não é assinado).

## Mensagem para os amigos (copie e cole)

> Oi! Vem testar meu jogo de corrida de caminhões decorados, o **Kaidō Bakusō**. 🚛✨
> 1. Instale: (Windows) abra o `dekotora.exe` · (Android) instale o `.apk` (pode pedir "permitir apps desconhecidos").
> 2. Abra o jogo → **MULTIPLAYER**. Em **Servidor** digite: `___.___.___.___:24600` (eu passo o endereço).
> 3. Digite seu nome, toque em **CONECTAR**. Eu crio a sala e te mando o código de 6 letras; você toca em **ENTRAR**.
> 4. Marque **PRONTO**. Eu inicio a corrida.
> Antes disso, vale dar uma volta na **GARAGEM** e na **CAMPANHA**.
> Quando terminar, responda o formulário abaixo (pode ser só colar no WhatsApp).

## Checklist do que testar

**Instalação e abertura**
- [ ] O jogo abre em até 15 s e mostra o menu com música
- [ ] O texto e os botões estão legíveis (celular e PC)

**Garagem e economia**
- [ ] Comprei uma peça e ela apareceu no caminhão 3D
- [ ] Os números (peso, 0–100 km/h) mudaram como esperado antes de comprar
- [ ] Reparar / Reparar tudo cobrou o valor certo
- [ ] Consegui trocar motor, turbo e escape

**Corrida (sozinho)**
- [ ] Controles responderam bem (toque / teclado / controle)
- [ ] Bati em carro, em rival e na lateral: vi faísca, ouvi o som, o dano apareceu no HUD
- [ ] Ultrapassagem, Passing (buzina) e vácuo funcionaram
- [ ] Tela de resultado correta (posição, pagamento, danos)
- [ ] FPS bom? (Opções → *Mostrar FPS*; se travar, Opções → Qualidade → Baixa)

**Multiplayer**
- [ ] Conectei, criei/entrei na sala e todos aparecem na lista
- [ ] A corrida começou junto para todos
- [ ] Vi os outros caminhões andando suave (sem teletransporte)
- [ ] Batidas aconteceram para todos ao mesmo tempo, com o mesmo dano
- [ ] Resultado final igual para todos; o dinheiro foi para o perfil

## Modelo de relato de problema (peça para eles copiarem)

```
Aparelho: (ex.: Galaxy A54 / PC Windows 11)
Versão do jogo: (data do arquivo)
Onde: (Menu / Garagem / Corrida / Lobby / Resultado)
O que fiz: ...
O que esperava: ...
O que aconteceu: ...
Aconteceu de novo? (sempre / às vezes / uma vez)
Foto ou vídeo (se der): ...
```

## Depois que o Marco colar o retorno

Peça ao Claude: **"Transforme este retorno em uma lista priorizada de correções e ajustes de equilíbrio"**
e cole os relatos. A lista deve vir em 3 grupos: *quebra o jogo*, *incomoda*, *ajuste de equilíbrio*
(números em `docs/BALANCEAMENTO.md`; constantes de equilíbrio principais: `engine_model.gd`, `damage_model.gd`,
`race_rules.gd`, `data/parts`).
