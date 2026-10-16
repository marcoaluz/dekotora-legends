# Servidor do multiplayer (Kaido Bakuso)

O servidor é o **mesmo projeto Godot**, exportado como Linux headless e iniciado com `--server`.
Ele decide colisões, dano, Passing, chegada e pagamento, e guarda o perfil de cada jogador
(um JSON por código de jogador). Detalhes do protocolo: `docs/MULTIPLAYER.md`.

| Item | Valor |
| --- | --- |
| Porta | **UDP 24600** (muda com `--port=`) |
| Jogadores | 2 a 4 por sala, várias salas por servidor |
| Memória | ~150 MB; 1 vCPU / 1 GB sobra para dezenas de jogadores |
| Perfis | `~kaido/.local/share/godot/app_userdata/Kaido Bakuso/profiles/<CODIGO>.json` |

## 1. Gerar o binário

No PC do Marco, na pasta do projeto:

```bash
bash server/export_server.sh        # gera builds/dekotora_server.x86_64
```

(Pré-requisito: os modelos de exportação do Godot 4.7.2 instalados — já estão em
`%APPDATA%\Godot\export_templates\4.7.2.stable`.) O preset **Server** já exclui áudio, sprites e fontes.

## 2. Alugar o VPS (decisão do Marco — não contratei nada)

Precisa de: Ubuntu 22.04/24.04, 1 vCPU, 1 GB de RAM, IP público, **região São Paulo** (ping baixo no Brasil).
Preços abaixo foram pesquisados na web em 2026-10-16 e **precisam ser conferidos no site de cada provedor** antes de contratar:

| Provedor | Plano parecido | Preço aprox. | Observações |
| --- | --- | --- | --- |
| **Vultr** (São Paulo) | Cloud Compute 1 vCPU / 1 GB (alta frequência) | ~US$ 9/mês (agregador de preços; o site pode mostrar US$ 6) | Cobrança por hora, painel simples, região São Paulo confirmada. **Minha recomendação** pela simplicidade. |
| **AWS Lightsail** (sa-east-1, São Paulo) | 1 vCPU / 1–2 GB | ~US$ 5–10/mês (não confirmei o valor atual) | Boa estabilidade; mais passos de rede (liberar UDP no firewall do Lightsail). |
| **Oracle Cloud** (região Brasil / São Paulo) | VM pequena ou "Always Free" (ARM) | US$ 0 a ~10/mês | O plano gratuito é o mais barato, mas a disponibilidade de máquinas varia e a conta exige cartão; o binário `x86_64` roda em instância AMD (a ARM exigiria exportar `arm64`). |
| Locaweb (VPS nacional) | VPS entrada | ~R$ 70/mês (promoção) | Pagamento em reais; verificar suporte a UDP e Ubuntu. |

Hetzner/DigitalOcean não aparecem com datacenter em São Paulo nas buscas — não recomendo para este jogo.
Para só testar com amigos em casa, **não precisa de VPS**: veja `docs/REDE_WIFI.md`.

## 3. Instalar no VPS (Ubuntu)

```bash
# no seu PC: copia o binario e os scripts (troque IP_DO_VPS)
scp builds/dekotora_server.x86_64 server/install_ubuntu.sh server/kaido-server.service server/update.sh root@IP_DO_VPS:~
# no VPS:
ssh root@IP_DO_VPS
bash install_ubuntu.sh ./dekotora_server.x86_64
```

O script cria o usuário `kaido`, instala em `/opt/kaido`, registra o serviço **systemd** (reinicia sozinho se
cair), libera **UDP 24600** no `ufw` e inicia. **Também libere UDP 24600 no firewall do painel do provedor.**

## 4. Operação

| Tarefa | Comando |
| --- | --- |
| Ver se está rodando | `systemctl status kaido-server` |
| Ver logs ao vivo | `journalctl -u kaido-server -f` |
| Reiniciar | `sudo systemctl restart kaido-server` |
| Atualizar (binário novo) | copie o novo `.x86_64` e rode `sudo bash update.sh dekotora_server.x86_64` |
| Backup dos perfis | `sudo tar czf perfis.tgz -C /home/kaido/.local/share/godot/app_userdata profiles` (ajuste o caminho) |

Os jogadores digitam `IP_DO_VPS:24600` no campo **Servidor** (Menu → MULTIPLAYER). Todos precisam estar na
**mesma versão do jogo** que o servidor (o servidor recusa versão de protocolo diferente).

## 5. Testar de fora

Do seu PC: `Test-NetConnection IP_DO_VPS -Port 24600` não serve para UDP. O teste real é abrir o jogo,
Menu → MULTIPLAYER → conectar. No VPS, `journalctl -u kaido-server -f` mostra `jogador X conectou`.

## Segurança (resumo)

- O servidor ignora o caminhão que o cliente "diz" ter: monta o caminhão pelo perfil guardado (só aceita a cor).
- Compras e reparos online são refeitos no servidor com as mesmas regras do jogo.
- O código de jogador funciona como senha: quem o souber acessa aquele perfil. Para amigos basta; login de verdade fica para depois.
