# Setup — preparar o PC do Marco (Windows 10)

Faça na ordem. Cada passo diz como conferir se deu certo. Travou? Copie a mensagem de erro e cole para o Claude.

## 1. Git e Git LFS

1. Baixe e instale o **Git for Windows**: https://git-scm.com/download/win (pode aceitar todas as opções padrão).
2. Abra o **PowerShell** e rode:
   ```powershell
   git --version
   git lfs install
   git config --global user.name "Marco"
   git config --global user.email "SEU_EMAIL_DO_GITHUB"
   ```
   Deu certo se o primeiro comando mostrar `git version ...` e o segundo `Git LFS initialized`.

## 2. Pasta do projeto

1. Crie a pasta `C:\Projetos\` (sem acento, sem espaço).
2. Descompacte o pacote `dekotora-legends.zip` dentro dela. Deve ficar `C:\Projetos\dekotora-legends\CLAUDE.md`.

## 3. Repositório no GitHub (privado)

1. Entre em https://github.com/new
2. Nome: `dekotora-legends` · Visibilidade: **Private** · **Não** marque README, .gitignore nem licença.
3. Clique em **Create repository** e copie a URL (`https://github.com/SEU_USUARIO/dekotora-legends.git`).
4. No PowerShell:
   ```powershell
   cd C:\Projetos\dekotora-legends
   git init -b main
   git add .
   git commit -m "fase-0: estrutura inicial do projeto"
   git remote add origin https://github.com/SEU_USUARIO/dekotora-legends.git
   git push -u origin main
   ```
   Deu certo se a página do repositório no GitHub mostrar as pastas `docs`, `blender`, `game`.

## 4. Godot 4.7

1. Baixe o **Godot 4.7.x – Standard** (não a versão .NET): https://godotengine.org/download/windows/
2. Descompacte em `C:\Ferramentas\Godot\`. Renomeie o executável principal para `godot.exe`
   (o arquivo que termina em `_console.exe` renomeie para `godot_console.exe`).
3. Adicione `C:\Ferramentas\Godot` ao **PATH** do Windows:
   Iniciar → "variáveis de ambiente" → Variáveis de Ambiente → Path (do usuário) → Editar → Novo → colar o caminho → OK.
4. Feche e reabra o PowerShell e rode `godot --version`. Deve mostrar `4.7...`.
5. Abra o Godot, clique em **Importar**, escolha `C:\Projetos\dekotora-legends\game\project.godot`.
6. No editor: menu **Editor → Gerenciar Modelos de Exportação → Baixar e Instalar**.

## 5. Android (para gerar o app)

1. Instale o **Android Studio**: https://developer.android.com/studio
2. Abra, vá em **More Actions → SDK Manager** e instale:
   - Android SDK Platform **36**
   - Android SDK Build-Tools (mais recente)
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools
   - NDK (Side by side)
3. Instale o **OpenJDK 17** (por exemplo, Eclipse Temurin 17): https://adoptium.net/
4. No Godot: **Editor → Configurações do Editor → Export → Android**:
   - *Java SDK Path*: pasta do JDK 17 (ex.: `C:\Program Files\Eclipse Adoptium\jdk-17...`)
   - *Android SDK Path*: `C:\Users\SEU_USUARIO\AppData\Local\Android\Sdk`
5. No celular: ative **Opções do desenvolvedor** (tocar 7× em "Número da versão") e **Depuração USB**.

## 6. Blender

1. Instale o Blender (a versão estável mais recente): https://www.blender.org/download/
   Você já tem o Blender instalado; serve, desde que seja 4.2 ou mais novo.
2. Adicione a pasta do Blender ao **PATH** (ex.: `C:\Program Files\Blender Foundation\Blender 4.x`).
3. Reabra o PowerShell e rode `blender --version`. Deve mostrar a versão.
4. Teste o modo sem tela: `blender -b --python-expr "import bpy, numpy; print('OK', bpy.app.version_string)"`.
   Deve aparecer `OK` seguido da versão.

## 7. Claude Code

1. Instale seguindo a página oficial: https://docs.claude.com/en/docs/claude-code/setup
2. No PowerShell:
   ```powershell
   cd C:\Projetos\dekotora-legends
   claude
   ```
3. Faça login quando pedir.
4. Digite `/model sonnet` (o coordenador; os outros agentes escolhem o próprio modelo sozinhos).
5. Digite `/agents` e confira que aparecem **ajudante-rapido**, **especialista** e **supervisor**.
6. Digite `/tarefa P00` para começar. Veja `docs/AGENTES.md` para entender o time.

## 8. VS Code (opcional, para ler o código)

1. Instale: https://code.visualstudio.com/
2. Instale a extensão **godot-tools**.

## 9. ElevenLabs

1. Crie a conta em https://elevenlabs.io (o plano gratuito serve para testar).
2. Os prompts de som estão em `docs/AUDIO_ELEVENLABS.md`.
3. Salve cada arquivo **com o nome indicado** na pasta indicada em `game/assets/audio/`.

## Checklist final da Fase 0

- [ ] `git --version`, `godot --version`, `blender --version` funcionam no PowerShell
- [ ] Repositório no GitHub com a estrutura inicial
- [ ] Projeto abre no Godot sem erro
- [ ] Claude Code abre na pasta do projeto
- [ ] Celular com Depuração USB ativada
