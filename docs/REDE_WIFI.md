# Testar o multiplayer em casa (PC servidor + celular na mesma Wi-Fi)

Tudo aqui funciona **sem VPS**: o PC do Marco faz o papel de servidor e o celular entra pela rede local.

## 1. Abrir o servidor no PC

Duas formas (escolha uma):

- **Duplo clique** em `tools\run_server.bat` (usa o Godot de `D:\DEV\Godot`).
- Ou no PowerShell, na pasta do projeto:
  ```powershell
  & "D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path game -- --server
  ```

Deve aparecer `[servidor] escutando na porta UDP 24600`. Deixe a janela aberta.
Porta diferente: acrescente `--port=24700`.

## 2. Descobrir o IP do PC

No PowerShell: `ipconfig` e procure **Endereço IPv4** do adaptador de Wi-Fi/Ethernet,
algo como `192.168.0.15`. (O celular precisa estar na **mesma rede Wi-Fi**.)

## 3. Liberar a porta no Firewall do Windows (uma vez)

Abra o PowerShell **como Administrador** e rode:

```powershell
powershell -ExecutionPolicy Bypass -File tools\firewall_servidor.ps1
```

Isso cria a regra "Kaido Bakuso servidor" liberando **UDP 24600** de entrada (só rede privada).
Para remover depois: `netsh advfirewall firewall delete rule name="Kaido Bakuso servidor"`.

## 4. Conectar

- **No PC (outra janela do jogo)**: Menu → MULTIPLAYER → servidor `127.0.0.1:24600` → CONECTAR.
- **No celular**: Menu → MULTIPLAYER → no campo **Servidor** digite `192.168.0.15:24600`
  (o IP do passo 2) → CONECTAR. O campo de IP manual é o recurso de depuração pedido na P65.

Um cria a sala (CRIAR SALA) e passa o **código de 6 letras** ao outro (ENTRAR). Os dois marcam PRONTO e o
anfitrião toca em INICIAR CORRIDA.

## 5. Se não conectar

| Sintoma | Causa provável | O que fazer |
| --- | --- | --- |
| "Não foi possível conectar" | Firewall bloqueando | Refaça o passo 3; confirme que o Wi-Fi está como rede **Privada** |
| Conecta no PC mas não no celular | IP errado ou redes diferentes | Rode `ipconfig` de novo; celular e PC no mesmo Wi-Fi (não use "rede de convidados") |
| Conecta e cai sozinho | Versão diferente dos dois jogos | Gere as duas builds do mesmo commit |
| Tudo "trava" no celular | Wi-Fi fraco | Aproxime do roteador; o jogo mostra o ping no log |

## 6. Testes automáticos sem celular

`bash tools/net_test.sh` abre 1 servidor + 2 jogadores automáticos e corre a pista inteira.
Com atraso: `bash tools/net_test.sh 150 0.02` (150 ms e 2% de perda de pacotes).
