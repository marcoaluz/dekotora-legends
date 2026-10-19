# Builds de release (P80)

Pesquisado em 2026-10-16 ([Android Developers — target API](https://developer.android.com/google/play/requirements/target-sdk)):
**desde 31/08/2026, apps novos e atualizações no Google Play precisam ter `targetSdk` 36 (Android 16) ou maior**
(prorrogação possível até 01/11/2026 pelo Play Console). O preset **Android** do projeto já usa **min SDK 26 / target SDK 36**.
Confira de novo no site antes de publicar: as regras mudam.

## 1. Instalar as ferramentas (uma vez) — PRECISA MARCO

Siga `docs/SETUP.md`, passo 5 (Android Studio + SDK Platform 36, Build-Tools, Command-line Tools, NDK; JDK 17 Temurin).
No Godot: *Editor → Configurações do Editor → Export → Android*: caminho do JDK e do Android SDK.
Modelos de exportação do Godot 4.7.2: já instalados neste PC (`%APPDATA%\Godot\export_templates\4.7.2.stable`).

## 2. Criar a chave de assinatura (guarde FORA do repositório!)

A chave identifica o jogo para sempre: **se perder, não consegue mais atualizar o app na loja**. Faça cópia
em dois lugares (pendrive e nuvem privada). **Nunca** coloque no Git (o `.gitignore` já bloqueia `*.keystore`).

No PowerShell (o `keytool` vem com o JDK 17):

```powershell
mkdir "$env:USERPROFILE\chaves-kaido"
keytool -genkeypair -v -keystore "$env:USERPROFILE\chaves-kaido\kaido-release.keystore" `
  -alias kaido -keyalg RSA -keysize 2048 -validity 10000
```

Ele pergunta uma **senha do keystore** (anote num gerenciador de senhas), nome, organização etc.
Para exportar sem digitar senha no Godot, use variáveis de ambiente (o Godot as lê):

```powershell
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = "$env:USERPROFILE\chaves-kaido\kaido-release.keystore"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "kaido"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "SUA_SENHA"
```

## 3. Gerar o AAB assinado (Google Play) e o APK

O AAB exige o *build Gradle*: no Godot, *Projeto → Instalar Modelo de Compilação do Android*, e no preset Android
marque **Use Gradle Build** e **Export Format = Export AAB**. Depois:

```powershell
godot --headless --path game --export-release "Android" ../builds/kaido-bakuso.aab
```

APK para testes/itch.io: desmarque *Export AAB* e use `--export-release "Android" ../builds/kaido-bakuso.apk`.
Aumente `version/code` (inteiro) e `version/name` no preset a cada envio.

## 4. Windows

```powershell
godot --headless --path game --export-release "Windows" ../builds/dekotora.exe
```
Gera um `.exe` único (pacote embutido). Opcional: assinar o `.exe` com um certificado de código para tirar o aviso do SmartScreen.

## 5. Requisitos da Play Store a conferir (no dia)

- Conta de desenvolvedor Google Play (taxa única) e, conforme as regras do momento, verificação de identidade.
- **Política de privacidade** com URL pública (`docs/POLITICA_PRIVACIDADE.md` serve de base).
- Questionário de **classificação de conteúdo** e de **segurança de dados** (o jogo guarda um código de jogador e o
  progresso no servidor; sem anúncios nem compras no app).
- Ícone 512×512, imagem de destaque 1024×500, capturas de tela: prontos em `docs/store/`.
- Testes fechados exigidos para contas pessoais novas (verifique o número de testadores/dias atual na Play Console).
- Binários arm64-v8a (o preset já exporta só arm64) e compatibilidade com páginas de memória de 16 KB: confirme na
  versão do Godot usada (4.7.x) nas notas da versão antes de enviar.

## 6. itch.io (mais simples para amigos)

1. Crie a página em itch.io → *Create new project* → tipo **Downloadable**.
2. Envie `dekotora.exe` (Windows) e o `.apk` (Android). Marque *Visibility: Restricted/Draft* até estar pronto.
3. Use os textos de `docs/LOJA.md`.

## APK de teste (feito em 2026-10-18, T-140)

Ferramentas instaladas SEM administrador em `D:\DEV\android-tools\` (JDK 17 Temurin 17.0.20.1, SHA-256 conferido;
Android command-line tools 23.0; SDK Platform 36, Build-Tools 36.0.0, Platform-Tools 37.0.1; licenças aceitas pelo Marco).
O Godot aponta para elas em `%APPDATA%\Godot\editor_settings-4.7.tres` (backup `.bak_2026-10-18` ao lado).
O comando novo do SDK é `android.exe sdk install "pacote;versao"` (o `sdkmanager.bat` quebra nomes com `;`).

- **Chave:** a APK de teste usa a chave de debug (`%APPDATA%\Godot\keystores\debug.keystore`). Para a loja use a chave de release (seção 2).
- **Config do projeto:** `rendering/textures/vram_compression/import_etc2_astc=true` (obrigatório no Android; reimporta texturas em ETC2/ASTC).
- **Gradle desligado** no preset Android: com isso, "Min SDK" e "Target SDK" do preset precisam estar VAZIOS (o Godot recusa valores sem Gradle).
  O preset do repositório guarda `26`/`36` para a versão da loja (AAB, com Gradle). Para gerar o APK de teste, esvazie os dois valores
  numa cópia temporária do `export_presets.cfg` e restaure depois (foi o que se fez).
- **Gerar:** `godot --headless --path game --export-debug "Android" ../builds/kaido-bakuso-debug.apk` (84 MB na T-140; 105 MB em 2026-10-19 com graneleira, kit de beira de estrada e sons novos; `builds/` é ignorado pelo Git).
- **Instalar no celular:** (1) copie o APK para o celular (cabo, nuvem) e abra, permitindo "instalar apps desconhecidos"; ou (2) com cabo e
  "Depuração USB" ligada: `D:\DEV\android-tools\sdk\platform-tools\adb.exe install -r builds\kaido-bakuso-debug.apk`.
- **Pendente:** testar no celular de verdade (FPS e temperatura nos 3 presets de qualidade: T-097); AAB de loja com Gradle + chave de release.
