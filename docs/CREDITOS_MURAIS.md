# Créditos dos murais

| artista | título | data | museu | número do objeto | link | licença | o que mudamos |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Kaidō Bakusō (Claude, por código) | Gueixa, grande onda e sol nascente (baú rosa, T-218) | 2026-10-26 | — | — | `blender/scripts/lib/tex_mural_t218.py` | nossa (feita por código, sem imagem de terceiros) | arte original: formas geométricas em numpy (gueixa com coque e kanzashi, onda com garras de espuma, Fuji, sakura, seigaiha) + tubos de neon com mapa de emissão próprio (`mural_geisha_emit.png`). Sem texto/kanji. Mesma arte nos dois lados (a UV do lado esquerdo é espelhada para a composição ler igual) |

Um mural por lado (esquerdo e direito são artes diferentes); kanji/texto NUNCA espelhado. Obras só de domínio público/CC0, repintadas por nós.

## T-232 — 12 murais (2 lados cada), 12 traseiras e 9 tetos

**Toda a arte é nossa, desenhada por código** (`blender/scripts/lib/paint2d.py` + `lib/t232_*.py`, numpy, determinística;
`blender/scripts/build_t232_paint.py`). **Nenhuma imagem de terceiros foi baixada, recortada, traçada nem repintada**: as
obras abaixo serviram só de referência de tipo e composição (pose, tema), olhadas e não usadas como pixels. Escolha do
Claude: o mural da gueixa (T-218, aprovado) mostrou que o estilo vetorial de aerógrafo por código fica coerente no jogo,
e assim não entra pixel de terceiros (licença mais limpa) e tudo se regera a partir do repositório. Kanji: fonte de pincel
**Yuji Syuku** (Kinuta Font Factory, SIL OFL 1.1, `blender/fonts/`), cada caractere conferido na tabela `cmap` da fonte
(sem tofu). Nenhum kanji é espelhado (o jogo garante u × v = normal em todas as faces).

| peça | o que é | referência de tipo/composição (domínio público; só olhada) | o que fizemos |
| --- | --- | --- | --- |
| `mural_ryu_kumo` | dragão verde nas nuvens (dir.: lua cheia e pérola; esq.: tempestade com raios) | dragões nas nuvens da tradição de Hokusai e Kawanabe Kyōsai (tipo, sem obra específica) | corpo em tubo com escamas e placas por código, cabeça, juba, chifres, bigodes, garras, nuvens ruyi |
| `mural_ryu_nami` | dragão azul saindo do mar (dir.); dragão dourado sobre redemoinho e Fuji (esq.) | Hokusai, *Sob a onda de Kanagawa*, c. 1830–32, The Met JP1847, [link](https://www.metmuseum.org/art/collection/search/45434) (Open Access, domínio público; conferido) | onda desenhada por nós (forma própria, a mesma do mural da T-218), dragão, sol, seigaiha |
| `mural_tora_take` | tigre rugindo no bambuzal (dir.); rosto do tigre (esq.) | Kishi Ganku, *Tigre*, rolo, início do séc. XIX, The Met 36.100.11, [link](https://www.metmuseum.org/art/collection/search/49063) e *Tigre*, 1790, The Met 14.76.21, [link](https://www.metmuseum.org/art/collection/search/49061) (Open Access) | tigre de formas unidas por código, listras procedurais, bambu, sol |
| `mural_tora_yuki` | tigre saltando na neve sob a lua (dir.); tigre e pinheiro nevado com Fuji (esq.) | escola de Hokusai, *Tigre*, séc. XIX, The Met 38.106.4, [link](https://www.metmuseum.org/art/collection/search/57300) (Open Access) | tigre, neve, pinheiro e lua por código |
| `mural_nami_fuji` | grande onda e Fuji ao amanhecer com barcos (dir.); ondas, redemoinhos e lua (esq.) | Hokusai, *Sob a onda de Kanagawa* (acima) | onda/redemoinho/seigaiha nossos; barcos simplificados |
| `mural_kabuki` | ator com kumadori vermelho (dir.); leão do kabuki de juba branca entre peônias (esq.) | retratos de atores de Sharaku (1794) e o *renjishi* (tipo) | rosto simétrico e maquiagem por código |
| `mural_musha` | samurai azul com chifres dourados entre chamas (dir.); samurai vermelho com lua crescente (esq.) | guerreiros de Kuniyoshi (*108 heróis do Suikoden*, tipo) | elmo, máscara, armadura em lâminas, espada e estandartes (brasões inventados, sem texto) |
| `mural_bijin_ogi` | dama com leque, quimono de sakura e Fuji (dir.); dama de quimono de ondas sob a lua (esq.) | bijin-ga de Utamaro e Eishi (tipo) | figura de frente por código (mesmo traço da gueixa da T-218) |
| `mural_bijin_tsuki` | dama de cabelo solto com sombrinha, glicínias e lua (dir.); dama no rio com vaga-lumes (esq.) | bijin-ga (tipo) | idem |
| `mural_hoo` | fênix sobre nuvens douradas (dir.); grous sobre o mar com pinheiro (esq.) | aves e flores de Hokusai/Hiroshige (tipo) | penas, plumas com olhos e asas por código |
| `mural_men` | hannya e oni entre chamas e raio (dir.); kitsune, Noh e tengu com lanternas (esq.) | máscaras tradicionais de Noh/kyōgen e de festival (tipo) | máscaras simétricas por código |
| `mural_koi` | carpa subindo a cachoeira (dir.); carpas num lago com nenúfares (esq.) | carpa na cachoeira (tema tradicional, tipo) | carpas em tubo com escamas, nenúfares |
| `rearpaint_*` (12) | rosto no meio + kanji vertical dos 2 lados + fresta das portas: dragão 昇龍/天翔, tigre 猛虎/咆哮, hannya 般若/夜叉, oni 鬼神/豪胆, raposa 稲荷/狐火, tengu 天狗/鞍馬, Noh 能楽/幽玄, kabuki 歌舞伎/見得, gueixa 花魁/夜桜, leão 獅子/牡丹, fênix 鳳凰/瑞祥, carpas 錦鯉/登龍門 | as mesmas acima | arte separada do mural (decisão 8 do Marco) |
| `roofpaint_01..09` | 一番星, 男花道, 爆走, 御意見無用, 唯我独尊, 義理人情, 浪漫街道, 天下御免, 夜明けまで (decisão 7) em caligrafia vertical sobre fundo pintado | — | texto Yuji Syuku com contorno e halo neon; fundos por código |
