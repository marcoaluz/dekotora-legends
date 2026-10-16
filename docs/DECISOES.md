# Registro de decisões

Mais recente no topo. Toda decisão que muda o design ou a stack entra aqui.

| Data | Decisão | Motivo |
| --- | --- | --- |
| 2026-10-16 | **Salto de qualidade visual: apresentação em 3D real (plano B) com modelos PBR (.glb)**, mantendo a simulação igual. O plano A (sprites pixel art, `scenes/race/race.tscn`) continua no repositório como alternativa | Marco: "quero muito mais qualidade nas imagens finais" + pediu biblioteca de acessórios 3D PBR para Godot. A simulação é separada do visual, então trocar a apresentação não refaz a lógica. Decisão inferida dos pedidos: Marco confirma ou volta ao plano A |
| 2026-10-16 | Suposições de pagamento (docs/GDD não define): 1 Fama = 50 ¥ de bônus; cada ultrapassagem = 2 Fama; vácuo = +20% tração e +2 m/s; barra de Passing enche 4%/s acima de 70% da velocidade máxima e gasta 35%/s | Preencher lacunas do GDD para poder testar; ajustar jogando |
| 2026-10-16 | P40 (peças) segue `docs/PROMPT_ACESSORIOS_3D.md`: biblioteca de 32 acessórios 3D modulares (.glb + .blend + catálogo) em vez das 16 peças só em sprite. **Os sprites 2D continuam saindo desses mesmos modelos** (render ortográfico do pipeline atual), então plano A e plano B usam a mesma arte | Pedido do Marco. O texto de BALANCEAMENTO (16 peças com preço/peso) fica como base de dados; os 32 acessórios novos precisam de linhas de balanceamento (Claude propõe, Marco aprova) |
| 2026-10-15 | Nome do jogo: **Kaidō Bakusō — Chrome Legends** (tela: "KAIDO BAKUSO"). Pasta/repositório continuam `dekotora-legends`; "Dekotora" continua como nome do gênero | Pedido do Marco: nome novo com homenagem discreta ao original. "Bakusō" (爆走) vem de *Bakusō Dekotora Densetsu*; "Kaidō" = estrada; "Legends" = Densetsu. Provisório até o Marco aprovar |
| 2026-10-15 | Perfis do servidor em JSON (um por jogador), não SQLite | O Godot não traz SQLite embutido; para poucos amigos JSON basta; addon godot-sqlite se crescer |
| 2026-10-15 | Skills do projeto: blender-pixelart (com pxlib testado no Blender 5.2), godot-dekotora (comandos testados no Godot 4.7.1), arte-dekotora | Menos tentativa e erro; armadilhas já descobertas ficam registradas |
| 2026-10-15 | Time de agentes: coordenador (Sonnet), ajudante-rapido (Haiku), especialista (Opus), supervisor (Sonnet), com quadro e log compartilhados | Usar o modelo certo para cada esforço e dar visão total ao Marco |
| 2026-10-15 | Arte toda feita no Blender por scripts Python do Claude, renderizada como pixel art | Sem créditos no PixelLab; modelos 3D garantem ângulos e peças consistentes; teste de como o Claude se sai |
| 2026-10-15 | Multiplayer online 2–4 jogadores, servidor dedicado autoritativo em Godot headless | Jogar contra os amigos, com batidas e dano iguais para todos |
| 2026-10-15 | PC Windows além de Android, com jogo cruzado; foco continua no Android | Amigos podem jogar de qualquer lugar |
| 2026-10-15 | Peças têm peso, durabilidade e Fama; dano por zona; reparo custa dinheiro | Equilíbrio entre caminhão pesado/resistente e leve/frágil |
| 2026-10-15 | Peças de motor: 3 motores, 3 turbos, escape, freio-motor; som em camadas no ElevenLabs | Variedade de desempenho e de som |
| 2026-10-15 | Projeto pessoal, sem prazo | Fazer bem feito e aprender |
| 2026-10-14 | Godot 4 em vez de Unity; estrada pseudo-3D como plano A | Mais leve, grátis, melhor para 2D no celular |

## 2026-10-16 — Mercado de fretes com contratos (etapa G da UI premium; Marco: "pode seguir e fazer todos")

- Contrato = trecho + origem/destino (cidades do trecho, campo `places` do RouteDef) + tipo de carga (`data/cargo/*.tres`) + peso + valor.
- Capacidade do baú: leve 6 t, médio 12 t, longo 16 t (`Contracts.CAPACITY_T`). Contrato mais pesado que o baú aparece como "BAÚ PEQUENO".
- Valor = frete do trecho × multiplicador da carga × (0,8 + 0,6 × peso relativo na faixa da carga), de 50 em 50.
- O peso da carga entra na massa do caminhão do jogador (mais pesado = mais lento); a fragilidade multiplica o dano na carga
  (eletrônicos 1,8; louça 2,2; aço 0,5). Bots e multiplayer continuam com a carga padrão (4 t).
- O quadro é sorteado com semente salva no perfil: muda ao concluir um frete e ao tocar ATUALIZAR (sem custo).
  "Continuar" pega o contrato de maior valor do próximo trecho que caiba no baú.
- Suposições a revisar com o Marco: pesos, multiplicadores e se ATUALIZAR deve custar algo.
