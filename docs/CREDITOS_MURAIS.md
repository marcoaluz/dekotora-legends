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

## T-242 — murais e traseiras a partir de obras prontas (domínio público / CC0)

Pedido do Marco: imagens mais detalhadas, prontas, sem direito autoral, mantendo o **efeito de luz** da noite só em
pontos escolhidos. Escolha do Claude: as **mesmas peças** da T-232 trocam de arte (mesmo id: quem já comprou ganha a
versão nova; a rede e os rivais não mudam). As outras pinturas da T-232 continuam com a arte por código.

**Regras seguidas**: só acervos com licença escrita na própria ficha da obra — The Met Open Access (campo
`isPublicDomain: true` = CC0) e Cleveland Museum of Art Open Access (campo `share_license_status: CC0`); todas as obras são
de 1668 a 1866 (autores mortos há mais de 125 anos). Nada de jogos, Pinterest, wallpapers ou IA. As imagens originais
**não vão para o Git** (ficam em `blender/renders/t242/fontes/`, baixadas por `python -I tools/fetch_t242_sources.py`);
no jogo só entra o recorte final. Nenhum kanji/assinatura é espelhado (o jogo nunca espelha a arte, e nenhum lado foi
invertido por nós). O Art Institute of Chicago ficou de fora só porque a API bloqueou o acesso automático (Cloudflare).

**O que fizemos em cada obra** (`blender/scripts/build_t242_ukiyoe.py`, tabelas `lib/t242_registry.py` e
`lib/t242_sources.py`): recorte na proporção do baú (4:1 nos murais; a traseira põe o retrato num quadro dourado no meio
com o kanji da T-232 dos lados); esticamento horizontal de no máximo 12% (20% no biombo de Sekkei) e, se ainda faltar,
a borda é completada com a cor da borda esfumada; **tratamento de cor** (`lib/t242_photo.py`, `tone`): níveis pelo
preto/branco da própria obra, papel/seda claro escurecido e tingido de sépia (biombos de seda: forte; gravuras: leve,
para não escurecer os rostos, que são do mesmo papel), saturação +10–25% e gama 1,05–1,12. O desenho não é alterado.
Murais de retratos (Sharaku, Utamaro) são 3 gravuras lado a lado com moldura de neon.

**Brilho noturno desenhado à mão** (só nesses pontos; o resto da obra acende fraco, 20%, como a luz das luzinhas do baú
na T-232, que usava 30% na arte inteira): olhos dos tigres (amarelo-esverdeado ou azul, como pintados), sol nascente de
Ise (só acima do horizonte), lua crescente de Kuniyoshi, 22 vaga-lumes no tríptico de Utamaro (só existem de noite),
o feixe de luz do tríptico de Kuniyoshi, a lâmina da espada de Imai Kanehira (Kunisada), as molduras de neon dos
retratos e o kanji das traseiras. A máscara aparece nas folhas `docs/capturas_t242/` (quadro de baixo de cada lado).

| artista | título | data | museu | número do objeto | link | licença | onde está |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Yamaguchi Sekkei (1644–1732) | Lions and Tigers in Peony and Bamboo (par de biombos; usamos o dos tigres) | 1668 | Cleveland Museum of Art | 1972.10 | [página](https://clevelandart.org/art/1972.10) · [imagem](https://openaccess-cdn.clevelandart.org/1972.10/1972.10_print.jpg) | CC0 (`share_license_status: CC0`) | `mural_tora_take` lado esq. |
| Soga Nichokuan (ativo c. 1625–1660) | Tiger (biombo) | early to mid-1600s | Cleveland Museum of Art | 1985.134.2 | [página](https://clevelandart.org/art/1985.134.2) · [imagem](https://openaccess-cdn.clevelandart.org/1985.134.2/1985.134.2_print.jpg) | CC0 (`share_license_status: CC0`) | `mural_tora_take` lado dir. |
| Kishi Ganku (1749/56–1838) | Tiger Family (biombo da direita do par) | early 1800s | Cleveland Museum of Art | 1983.3.1 | [página](https://clevelandart.org/art/1983.3.1) · [imagem](https://openaccess-cdn.clevelandart.org/1983.3.1/1983.3.1_print.jpg) | CC0 (`share_license_status: CC0`) | `mural_tora_yuki` lado dir. |
| Kishi Ganku (1749/56–1838) | Tiger Family (biombo da esquerda do par) | early 1800s | Cleveland Museum of Art | 1983.3.2 | [página](https://clevelandart.org/art/1983.3.2) · [imagem](https://openaccess-cdn.clevelandart.org/1983.3.2/1983.3.2_print.jpg) | CC0 (`share_license_status: CC0`) | `mural_tora_yuki` lado esq. |
| Kishi Ganku (1749–1838) | Tiger (rolo vertical) | early 19th century | The Metropolitan Museum of Art | 36.100.11 | [página](https://www.metmuseum.org/art/collection/search/49063) · [imagem](https://images.metmuseum.org/CRDImages/as/original/36_100_11_O2.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `rearpaint_tora` traseira |
| Tōshūsai Sharaku | Ichikawa Omezō I as Yakko Ippei | 1794 | The Metropolitan Museum of Art | JP196 | [página](https://www.metmuseum.org/art/collection/search/36673) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP130177.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_kabuki` lado dir. |
| Tōshūsai Sharaku | Bandō Hikosaburō III as Sagisaka Sanai | 1794 | The Metropolitan Museum of Art | JP2823 | [página](https://www.metmuseum.org/art/collection/search/37359) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP130229.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_kabuki` lado dir. |
| Tōshūsai Sharaku | Ichikawa Komazō III as Shiga Daishichi | 1794 | The Metropolitan Museum of Art | JP2649 | [página](https://www.metmuseum.org/art/collection/search/37352) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP130222.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_kabuki` lado dir. |
| Tōshūsai Sharaku | Ichikawa Ebizō (Danjūrō V) as Takemura Sadanoshin | 1794 | The Metropolitan Museum of Art | JP3114 | [página](https://www.metmuseum.org/art/collection/search/37368) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP130194.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_kabuki` lado esq. |
| Tōshūsai Sharaku | Sakata Hangorō III as Fujikawa Mizuemon | 1794 | The Metropolitan Museum of Art | JP1522 | [página](https://www.metmuseum.org/art/collection/search/37331) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP130188.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_kabuki` lado esq. |
| Tōshūsai Sharaku | Bandō Mitsugorō II as Ishii Genzō | ca. 1794 | The Metropolitan Museum of Art | JP3113 | [página](https://www.metmuseum.org/art/collection/search/37367) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP130249.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_kabuki` lado esq. |
| Tōshūsai Sharaku | Ōtani Oniji III as Yakko Edobei | 1794 | The Metropolitan Museum of Art | JP2822 | [página](https://www.metmuseum.org/art/collection/search/37358) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP130228.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `rearpaint_kabuki` traseira |
| Kitagawa Utamaro | A Courtesan | c. 1790s | The Metropolitan Museum of Art | JP1663 | [página](https://www.metmuseum.org/art/collection/search/40601) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP135592.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_bijin_ogi` lado dir. |
| Kitagawa Utamaro | Woman Holding Up a Parasol (Ten Classes of Women's Physiognomy) | ca. 1792–93 | The Metropolitan Museum of Art | JP2730 | [página](https://www.metmuseum.org/art/collection/search/55319) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP141292.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_bijin_ogi` lado dir. |
| Kitagawa Utamaro | The Courtesan Konosumi (Beauties of the Southern Quarter) | ca. 1793–94 | The Metropolitan Museum of Art | JP1367 | [página](https://www.metmuseum.org/art/collection/search/53689) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP135598.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_bijin_ogi` lado dir. |
| Kitagawa Utamaro | Women Worshipping the Rising Sun between the Twin Rocks at Ise (tríptico) | c. 1790s | The Metropolitan Museum of Art | JP1680 | [página](https://www.metmuseum.org/art/collection/search/37340) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP144590.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_bijin_ogi` lado esq. |
| Utagawa Kuniyoshi | Autumn, from Women's Pleasures of the Four Seasons (tríptico) | ca. 1844–46 | The Metropolitan Museum of Art | JP3136 | [página](https://www.metmuseum.org/art/collection/search/56684) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP146825.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_bijin_tsuki` lado dir. |
| Kitagawa Utamaro | Catching Fireflies (Hotaru gari) (tríptico) | ca. 1796–97 | The Metropolitan Museum of Art | JP151 | [página](https://www.metmuseum.org/art/collection/search/36630) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP144584.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_bijin_tsuki` lado esq. |
| Kitagawa Utamaro | Hanaōgi of the Gomeirō (Comparing the Charms of Beauties) | ca. 1794–95 | The Metropolitan Museum of Art | JP1676 | [página](https://www.metmuseum.org/art/collection/search/53654) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP141287.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `rearpaint_bijin` traseira |
| Tsukioka Yoshitoshi | Masakiyo's Challenging Battle, from Taiheiki (tríptico) | 1866 | The Metropolitan Museum of Art | 2005.351a–c | [página](https://www.metmuseum.org/art/collection/search/72829) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP147714.jpg) | CC0 (Open Access, `isPublicDomain: true`) |  |
| Utagawa Kuniyoshi | Shōtoku Taishi Destroying Mononobe no Moriya (tríptico) | 1852 | The Metropolitan Museum of Art | JP1115.3a–c | [página](https://www.metmuseum.org/art/collection/search/893319) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP149160.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_musha` lado esq. |
| Utagawa Kunisada | Battle of Awazugahara (tríptico) | mid-19th century | The Metropolitan Museum of Art | JP1115.5a–c | [página](https://www.metmuseum.org/art/collection/search/893321) · [imagem](https://images.metmuseum.org/CRDImages/as/original/DP149162.jpg) | CC0 (Open Access, `isPublicDomain: true`) | `mural_musha` lado dir. |

## Como o Marco adiciona imagens

1. **Onde achar** (só estes, ou outro acervo que escreva CC0/Public Domain na ficha da obra): The Met
   (metmuseum.org, filtro "Open Access"), Cleveland Museum of Art (clevelandart.org, filtro "Open Access"/CC0),
   Art Institute of Chicago (artic.edu, "Public Domain"), Rijksmuseum (CC0), Wikimedia Commons só com etiqueta
   "PD-old"/"Public domain" de obra antiga. Dica: trípticos de Kuniyoshi, Kunisada, Utamaro (largos) e biombos (byōbu).
   **Nunca**: jogos, Pinterest, wallpapers, sites sem licença escrita, imagens feitas por IA.
2. **Formato**: JPG ou PNG, o maior que o acervo der. Mural de lado: obra larga (ideal 4:1, mínimo 2048 x 512 no trecho
   usado); traseira: ~5:4 ou retrato vertical (mínimo 1280 x 1024 no trecho usado); teto: 1:4 (mínimo 512 x 2048).
3. **Onde colocar**: na pasta `docs/Murais/` (ex.: `docs/Murais/kuniyoshi_baleia.jpg`) e, no mesmo pedido, me mande o
   **link da página da obra** (é de lá que eu confiro e anoto a licença).
4. **O que eu faço** (Claude): anoto a obra em `blender/scripts/lib/t242_sources.py` (arquivo, link, autor, data, museu,
   número, licença), escolho o recorte e o lado em `lib/t242_registry.py` e desenho a máscara de brilho (olhos, lua, sol,
   chamas, lanternas, raios) por coordenadas. Depois:
   ```
   python -I tools/fetch_t242_sources.py                     (obras que vêm de link; as da docs/Murais já estão lá)
   blender -b --factory-startup -P blender/scripts/build_t242_ukiyoe.py -- --sheets <PASTA_ABS>/docs/capturas_t242
   bash tools/import_textures_3d.sh game/assets/vehicles/dekotora/paint_t232/mural game/assets/vehicles/dekotora/paint_t232/rear
   python -I tools/gen_t242_data.py                           (nome na loja e licença no catálogo)
   ```
   O build procura a imagem primeiro em `docs/Murais/` e depois em `blender/renders/t242/fontes/`. Imagens grandes em
   `docs/Murais/` entram no Git se forem commitadas: prefira deixar só o link anotado e a imagem fora do commit.

## T-242 (ampliação) — murais estilo anime gerados pelo Marco (EXCEÇÃO dele; proposta, ainda fora do jogo)

Origem de todos: **gerada pelo Marco (Gemini)**, uso por decisão dele (registrado em `docs/DECISOES.md`, T-242). Sem link de
museu. Só personagens adultas, sem nudez explícita; nenhum texto/kanji nas imagens. Arquivos em `docs/Murais/` (fora do
Git). Recortes e brilho: `blender/scripts/lib/t242_anime.py`; folha para aprovar: `docs/capturas_t242/anime_proposta.png`.

| arquivo (docs/Murais) | tamanho | peça proposta | lado | recorte |
| --- | --- | --- | --- | --- |
| `laterado D.jpeg` | 2064 x 512 | `mural_anime_neon` | direito | inteira |
| `lateral esquerdo.jpeg` | 2064 x 512 | `mural_anime_neon` | esquerdo | inteira |
| `lateral 4.jpeg` | 2064 x 512 | `mural_anime_quimono` | direito | inteira |
| `lateral esquerdo 2.jpeg` | 2064 x 512 | `mural_anime_quimono` | esquerdo | inteira |
| `lateral.png` | 1536 x 1024 (tarja preta) | `mural_anime_lua` | direito | faixa do meio 19–62% da altura |
| `lateral 2.png` | 1536 x 1024 (tarja preta) | `mural_anime_cyber` | direito | faixa do meio 17–60% da altura |
| `lateral 3.png` (4 faixas) | 1536 x 1024 | `mural_anime_kitsune` (faixas 1 e 4), `mural_anime_cyber` (faixa 2), `mural_anime_lua` (faixa 3) | ver peça | cada faixa cortada em 4:1 mantendo a personagem |

## T-258 — grupo "Wallpapers" (arte digital criada pelo Marco) — como colocar

As pinturas da garagem (mural, traseira, teto) ficam em dois grupos: **Pinturas** (obras de museu, arte por código e os
murais anime já montados) e **Wallpapers** (arte digital criada: ilustração, anime, neon, realista). Na garagem há os
botões Todos / Pinturas / Wallpapers. Origem nos créditos: **"gerada pelo Marco (Gemini)"**, uso por decisão dele.
Regras: só personagens adultas, sem nudez explícita; texto/kanji pode existir na imagem (o jogo nunca espelha a arte).

1. Pasta: `docs/Murais/wallpaper/` (fora do Git).
2. Nome do arquivo = `<nome>_<tipo>.png` (ou .jpg), `<nome>` em minúsculas, números e `_`:
   | tipo | arquivo | tamanho ideal |
   | --- | --- | --- |
   | mural, lado direito | `<nome>_mural_d.png` | 2048 x 512 (4:1) |
   | mural, lado esquerdo | `<nome>_mural_e.png` (obrigatório junto com o direito) | 2048 x 512 (4:1) |
   | traseira (portas) | `<nome>_traseira.png` | 1280 x 1024 (5:4) |
   | teto (o alto da imagem = frente do caminhão) | `<nome>_teto.png` | 512 x 2048 (1:4) |
   Ex.: `dragao_neon_mural_d.png` + `dragao_neon_mural_e.png` viram o mural `wall_dragao_neon`.
3. Brilho noturno (opcional): `<arquivo>_brilho.png` do mesmo tamanho, branco onde acende (lua, olhos, neon). Sem ela,
   acende só o que já é luz forte e colorida na imagem (nunca a pele).
4. O que eu (Claude) rodo:
   ```
   blender -b --factory-startup -P blender/scripts/build_t258_wallpapers.py -- --sheet <PASTA_ABS>/docs/capturas_t258
   (o Marco aprova docs/capturas_t258/wallpaper_proposta.png; depois:)
   blender -b --factory-startup -P blender/scripts/build_t258_wallpapers.py -- --install
   python -I tools/gen_t258_data.py
   bash tools/import_textures_3d.sh game/assets/vehicles/dekotora/paint_wall/mural game/assets/vehicles/dekotora/paint_wall/rear game/assets/vehicles/dekotora/paint_wall/roof
   ```
   Imagem com nome fora do padrão é ignorada (o build avisa qual).

**Sugestão para os 5 murais anime pendentes (T-242, `anime_proposta.png`)**: entram no grupo **Wallpapers** (são imagens
criadas, não pinturas), assim que o Marco aprovar.
