# Servidor do multiplayer

O servidor é o próprio projeto Godot (`game/`) rodando sem tela, com o argumento `--server`.
Este arquivo será completado no prompt **P66**. Por enquanto, para testar no PC:

```powershell
cd C:\Projetos\dekotora-legends\game
godot --headless -- --server          # janela 1: servidor
godot                                  # janela 2: cliente (rode duas vezes para 2 jogadores)
```

Porta UDP padrão do jogo: **24600**.

Os perfis ficam na pasta de dados do usuário do servidor (`user://profiles/`), um JSON por jogador, fora do Git.
