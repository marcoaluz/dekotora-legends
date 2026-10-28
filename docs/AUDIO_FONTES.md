# Fontes de áudio reais (T-220) — o que o Marco baixa

Regra: **só licença CC0** ("Creative Commons 0" na página do som: pode usar, mudar e vender sem dar crédito).
Cada link abaixo foi aberto em 2026-10-26 e a licença foi lida na própria página do Freesound. Antes de baixar,
confira de novo: o autor pode mudar a licença. **Não use** som marcado como "AI generated" (mesma regra dos modelos)
nem som com licença "Attribution" (pede crédito) ou "NonCommercial" (proíbe venda).

Para baixar no Freesound é preciso uma conta grátis (botão **Download** na página do som). Baixe o arquivo original
(wav/flac), não a prévia em mp3.

## Onde colocar

| Pasta | O que vai |
| --- | --- |
| `audio_src/engine/` | gravações de motor (lenta, aceleração, passagem, freio-motor, turbo) — matéria-prima, não vai para o jogo direto |
| `audio_src/sfx/` | freio a ar, buzina, trem |
| `audio_src/ambient/` | cigarras, mar, taiko |

Mantenha o nome do arquivo como veio do Freesound e acrescente o número do som no início
(ex.: `128160_Diesel Truck Idling Front.wav`): assim dá para achar a página e a licença depois.
A pasta `audio_src/` fica na raiz do projeto (fora de `game/`, o Godot não importa).

## 1. Caminhão diesel (motor)

| # | Arquivo (nome no Freesound) | Link | Licença lida | Duração | Para quê |
| --- | --- | --- | --- | --- | --- |
| M1 | Diesel Truck Idling Front.wav (ibirdfilm) | https://freesound.org/people/ibirdfilm/sounds/128160/ | Creative Commons 0 | 34 s | **marcha lenta** (loop `off_700`), a melhor candidata: longa e parada |
| M2 | truck diesel start idle nearby and pull away slow Gaza 2016.wav (kyles) | https://freesound.org/people/kyles/sounds/406885/ | Creative Commons 0 | 34 s | partida + lenta + saída devagar (lenta e primeiros giros) |
| M3 | school bus old rattly idle various diesel truck semi dump.wav (kyles) | https://freesound.org/people/kyles/sounds/450808/ | Creative Commons 0 | 3 min 11 s | várias lentas de ônibus/caminhão (escolher a mais "caminhão japonês") |
| M4 | truck large diesel or military tank APC ... accelerate big rev and pull away ... pass by Saravena, Colombia 2016.flac (kyles) | https://freesound.org/people/kyles/sounds/405086/ | Creative Commons 0 | 1 min 31 s | **aceleração** forte e **passagem** perto (loops `on_*` e referência) |
| M5 | Diesel Start-Idle-Revs MZ000004.wav (DAVESTALKER) | https://freesound.org/people/DAVESTALKER/sounds/443319/ | Creative Commons 0 | 27 s | acelerações paradas (revs) com turbo — é um V8 diesel (Ford F350): guardar para o **V8** (passo 5) |
| M6 | BG SaSc Old Truck Pass By.wav (Profispiesser) | https://freesound.org/people/Profispiesser/sounds/583278/ | Creative Commons 0 | 15 s | **passagem** de caminhão antigo (referência do som dos rivais) |
| M7 | highway traffic nearby facing away from highway trucks and cars pass by engine brakes.flac (kyles) | https://freesound.org/people/kyles/sounds/451149/ | Creative Commons 0 | 3 min 17 s | caminhões passando com **freio-motor (jake brake)** na estrada |
| M8 | Turbo Spooling and Blow Off.WAV (EwanPenman11) | https://freesound.org/people/EwanPenman11/sounds/659544/ | Creative Commons 0 | 5 s | **turbo** enchendo + "pssh" (é de carro; serve para o assobio/alívio) |

Não achei no Freesound CC0 uma gravação de **turbo de caminhão** isolado nem de **jake brake** isolado (M7 tem o jake no
meio do trânsito; M5 tem turbo de picape diesel). Se o Marco achar outro, vale a mesma regra: CC0 na página.

**Recusados** (não baixar): "Air Brake Applied" (chungus43A, 705390) — a página diz "AI generated"; "Isuzu Diesel Engine
Sound" (ithoanglong26, 546740) — está CC0, mas o autor diz que tirou o som do site de uma revendedora Isuzu (direito duvidoso).

## 2. Freio a ar, buzina a ar e trem (`audio_src/sfx/`)

| # | Arquivo | Link | Licença lida | Duração | Para quê |
| --- | --- | --- | --- | --- | --- |
| F1 | bus coach ext pull up brake air release idle.wav (kyles) | https://freesound.org/people/kyles/sounds/454420/ | Creative Commons 0 | 48 s | ônibus chega, **freio a ar** "tssss" e fica em lenta |
| F2 | Street scene, 18 wheeler arrives, air brakes hiss (PostProdDog) | https://freesound.org/people/PostProdDog/sounds/849740/ | Creative Commons 0 | 3 min 41 s | carreta chega, para, **freio a ar** (tem obra no fundo: recortar só o "tssss") |
| F3 | Truck Brakes.wav (KnapfordMaster98) | https://freesound.org/people/KnapfordMaster98/sounds/192170/ | Creative Commons 0 | 28 s | freio a ar chiando e soltando (caminhão de lixo, gravado no iPhone) |
| B1 | air horn close and loud.WAV (goose278) | https://freesound.org/people/goose278/sounds/174819/ | Creative Commons 0 | 6 s | **buzina a ar** de caminhão, de perto |
| T1 | Japanese Railroad Crossing - Gate Closing, Train Passing and Opening (KoimeMatsuchiya) | https://freesound.org/people/KoimeMatsuchiya/sounds/872621/ | Creative Commons 0 | 51 s | **passagem de nível japonesa** (sino "kan-kan" + trem passando) |
| T2 | freight train passing (rifualk) | https://freesound.org/people/rifualk/sounds/613467/ | Creative Commons 0 | 3 min 56 s | **trem de carga** passando (longo, bom para loop) |

## 3. Ambiente (`audio_src/ambient/`)

| # | Arquivo | Link | Licença lida | Duração | Para quê |
| --- | --- | --- | --- | --- | --- |
| A1 | Tokyo_Cicada.wav (sound pro) | https://freesound.org/people/sound%20pro/sounds/483360/ | Creative Commons 0 | 23 s | **cigarras** de Tóquio, tarde de verão (48 kHz/24 bits) |
| A2 | Japanese Cicada (macdaddyno1) | https://freesound.org/people/macdaddyno1/sounds/321591/ | Creative Commons 0 | 9 s | cigarra em Tóquio (curta, para variar) |
| A3 | Cicadas in Japan.wav (cartoonrob) | https://freesound.org/people/cartoonrob/sounds/643877/ | Creative Commons 0 | 4 s | cigarras em Hiroshima (curta) |
| A4 | Ocean waves crushing on the chilean shore. (felix.blume) | https://freesound.org/people/felix.blume/sounds/155641/ | Creative Commons 0 | 3 min | **mar** batendo nas pedras (litoral com rochas) |
| A5 | Waves, Atlantic ocean, on pebbly shore, PEI, 2011.wav (TRP) | https://freesound.org/people/TRP/sounds/577326/ | Creative Commons 0 | 3 min 6 s | **mar** em praia de pedrinhas (mais calmo) |
| A6 | Taiko drummers short performance.wav (kyles) | https://freesound.org/people/kyles/sounds/629930/ | Creative Commons 0 | 2 min 4 s | **taiko** ao vivo (grupo tocando) |
| A7 | Taiko Drumloop 001 (120) (Xinematix) | https://freesound.org/people/Xinematix/sounds/491277/ | Creative Commons 0 | 8 s | **taiko** em loop de 120 BPM (para a abertura do duelo / música) |

## 4. Como transformar a gravação em loop do motor

O jogo precisa de loops em RPM fixo: **lenta (700)** e acelerando/sem acelerar em **1000, 1400, 1900 e 2500 rpm**
(10 arquivos por motor). A ferramenta mede o RPM pela batida das explosões (6 cil.: frequência × 20), escolhe o trecho
mais estável, ajusta o tom para o ponto mais perto e faz a emenda sem clique.

1. Baixe M1 e M4 para `audio_src/engine/`.
2. Escreva `audio_src/engine/cortes.txt` (uma linha por loop; `-` = automático):
   ```
   # arquivo                                         voz  tipo  rpm   inicio  duracao
   "audio_src/engine/128160_Diesel Truck Idling Front.wav"   i6   off   auto  2       10
   ```
   Nome com espaço vai entre aspas. `rpm` = `auto` (medido) ou o número, se você souber.
3. Rode na raiz do projeto (Git Bash): `python tools/cut_loops.py --list audio_src/engine/cortes.txt`
4. Cada loop sai em `game/assets/audio/engines/rec_i6_<tipo>_<rpm>.wav` com uma imagem `_check.png` ao lado
   (emenda e espectro) e uma linha em `cut_loops_log.txt` terminando em **CONFERE** (fundamental certa) ou
   **NAO CONFERE** (não use esse trecho; tente outro início).
5. O jogo só troca para as gravações quando **os 10** arquivos `rec_i6_*` existirem. Até lá, use a cena de teste
   para ouvir cada um.

**Limite honesto**: gravações livres quase sempre têm lenta e acelerações rápidas, raramente o motor parado num giro
alto. A lenta sai fácil (M1); os loops acelerando em giro fixo podem não ter trecho estável longo. Nesse caso o
caminho é o modo **Mistura** (o sintetizador dá o ritmo e os graves; a gravação, a textura dos médios e agudos).

## 5. Gravações já usadas no jogo (T-260)

Os 4 mp3 de `docs/som caminhão/` (SFX Jar) são do **BigSoundBank (Joseph Sardin), CC0**: um Iveco Daily 3.0 HPI
(4 cilindros) parado, em marcha lenta e acelerando em vazio. O jogo usa os WAV originais:

1. `bash tools/fetch_t260_sources.sh` baixa os 4 WAV para `audio_src/engine/` (fora do Git).
2. `python -P tools/rec_engine_t260.py` gera os 30 loops `rec_i4_*`, `rec_i6_*`, `rec_i6t_*` em
   `game/assets/audio/engines/` e o relatório `docs/audio_t260/gerar_log.txt` (uma linha por loop, CONFERE / NAO CONFERE)
   com as folhas `docs/audio_t260/loops/*_check.png`. Depois: `godot --headless --path game --import`.
3. `python -P tools/demo_engine_t260.py` grava as prévias `docs/audio_t260/demo_<voz>_<rec|syn>.wav` (mesmo roteiro de
   20 s: lenta, acelera trocando marcha, segura, solta, acelera de leve, lenta; `rec` = gravação, `syn` = sintetizado).
4. Análise das gravações: `python -P tools/audio_t260_analyze.py audio_src/engine` → `docs/audio_t260/analise.txt` + PNG.

(`-P` em vez de `-I`: o `-I` esconde o numpy instalado no usuário.)
