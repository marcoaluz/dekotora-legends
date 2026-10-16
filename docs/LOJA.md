# Material para a loja (P81)

Nome de trabalho: **Kaidō Bakusō — Chrome Legends** (provisório até o Marco aprovar).
Arquivos visuais prontos em `docs/store/`: `icon_512.png`, `feature_graphic_1024x500.png`, `screen_1…5_*.png`
(1440×810, gerados no próprio jogo; refaça com `tools/image_resize.py` e `store_art.tscn` se mudar o visual).

## Textos — Português (Brasil)

**Título (30 caracteres):** Kaidō Bakusō: Chrome Legends

**Descrição curta (80):** Corrida de caminhões decorados com cromo, neon, batidas e multiplayer entre amigos.

**Descrição completa:**
> Entregue a carga, bata de frente com os rivais e deixe seu caminhão brilhar!
>
> **Kaidō Bakusō** é uma corrida arcade de caminhões decorados no estilo japonês dekotora: cromo, neon,
> andons luminosos e muito exagero. Cada peça muda o peso, a resistência e a Fama do seu caminhão — e, quando
> quebra, o conserto sai do seu bolso.
>
> • **Garagem completa:** 30+ acessórios 3D (para-choques, saias, luzes de teto, calotas, murais…), motores, turbo,
>   escape direto e freio-motor.
> • **Batidas com consequência:** dano por zona, peças que quebram e caem, carga que perde valor.
> • **Campanha de Kanto:** 3 trechos noturnos (costa, viaduto e montanha) e um rival-chefe.
> • **Multiplayer:** salas por código para 2 a 4 jogadores, no celular ou no PC (jogo cruzado). Bots completam as vagas.
> • **Som de verdade:** motor em camadas, turbo que assobia, "pssh" ao soltar o acelerador, buzinas musicais.
>
> Sessões de 3 a 5 minutos. Feito com carinho por um estúdio de duas pessoas (um humano e uma IA).

**Palavras-chave:** corrida, caminhão, dekotora, arcade, neon, tuning, multiplayer, japão, city pop.

## Texts — English

**Title:** Kaidō Bakusō: Chrome Legends

**Short description:** Decorated-truck arcade racing with chrome, neon, crashes and multiplayer with friends.

**Full description:**
> Deliver the cargo, ram your rivals and make your truck shine!
>
> **Kaidō Bakusō** is an arcade racer about Japanese *dekotora* art trucks: chrome, neon, glowing andon signs and
> pure excess. Every part changes your truck's weight, durability and Fame — and when it breaks, repairs come out of your pocket.
>
> • **Full garage:** 30+ 3D accessories (bumpers, skirts, roof lights, hubcaps, murals…), engines, turbo, straight-pipe exhaust and engine brake.
> • **Crashes matter:** zone damage, parts that break off, cargo that loses value.
> • **Kanto campaign:** 3 night routes (coast, viaduct, mountain) and a boss rival.
> • **Multiplayer:** private rooms by code for 2–4 players on phone or PC (cross-play). Bots fill empty slots.
> • **Layered engine audio:** whining turbo, blow-off "pssh", musical air horns.
>
> 3 to 5 minute sessions.

## Capturas de tela (ordem sugerida)

| # | Arquivo | Legenda PT | Caption EN |
| --- | --- | --- | --- |
| 1 | `screen_4_race_city.png` | Corra por Tóquio à noite | Race through Tokyo at night |
| 2 | `screen_2_garage.png` | Monte o caminhão dos sonhos | Build your dream truck |
| 3 | `screen_5_race_mountain.png` | Trechos de costa, cidade e montanha | Coast, city and mountain routes |
| 4 | `screen_3_repair.png` | Batidas custam caro: conserte na garagem | Crashes are costly: repair in the garage |
| 5 | `screen_1_menu.png` | Jogue com amigos, celular ou PC | Play with friends on phone or PC |

Para a Play Store, tire também capturas de **celular de verdade** (paisagem) quando tiver o APK.

## Classificação / dados (rascunho)

- Violência: apenas batidas de veículos, sem pessoas (esperado: Livre/Everyone 10+ — responda o questionário oficial).
- Compras no app: **nenhuma**. Anúncios: **nenhum**.
- Dados coletados: nome de exibição e código de jogador (aleatório), progresso do jogo (dinheiro, peças), endereço IP nos registros do servidor.

## Política de privacidade

Texto-base em `docs/POLITICA_PRIVACIDADE.md` (publique em uma URL: GitHub Pages, Notion público ou o próprio itch.io).

## Passo a passo — Play Console

1. Criar app → idioma padrão **Português (Brasil)**, tipo *Jogo*, *Gratuito*.
2. **Configurar o app**: política de privacidade (URL), acesso (sem login), anúncios (não), classificação de conteúdo,
   público-alvo (13+ ou 18+ conforme o questionário), segurança de dados (código de jogador, progresso).
3. **Loja**: textos acima, ícone 512, imagem de destaque 1024×500, capturas de tela.
4. **Produção ou teste fechado**: *Testes → Teste fechado* → criar faixa → enviar `kaido-bakuso.aab` (`docs/RELEASE_ANDROID.md`)
   → adicionar testadores (e-mails) → enviar para revisão.
5. Quando as regras de testadores forem cumpridas, promover para produção.

## Passo a passo — itch.io

1. *Upload new project*: título, URL, tipo **Downloadable**, preço "Free" ou "Pay what you want".
2. Envie `dekotora.exe` (marque *Windows*) e o `.apk` (marque *Android*).
3. Textos e capturas desta página; deixe a visibilidade em *Draft* até revisar.
