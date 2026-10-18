# Inventário dos modelos 3D que o Marco colocou (T-130)

Data: 2026-10-18. Pedido do Marco: "coloquei alguns modelos de carro e estrutura, só não lembro quais são o quê, tipo placa e
sinalização; verificar e aplicar no jogo". Aqui está **o que é cada arquivo**, quanto pesa, se tem placa de veículo ou
sinalização, e o que já entrou no jogo. Medidas feitas abrindo cada arquivo no Blender 5.2.2 em segundo plano (nada foi
alterado nas pastas originais). Análises anteriores: `docs/NOVOS_MODELOS.md` (T-115) e `docs/MODELOS_MELHORADOS.md` (T-123).

## Resumo em uma tela

| Arquivo / pasta | O que é | Triângulos | Placa de veículo? | Sinalização? | No jogo? |
| --- | --- | --- | --- | --- | --- |
| `docs/Modelos Melhorados/2025_fumi_sc.glb` (+ pasta `2025-fumi-sc/` com FBX e 30 texturas) | Carro esportivo vermelho (base TVR Griffith) | 82 mil | Sim: suporte `licenseholder` e a textura `lights_licenseplate.png`, que é **uma foto de uma placa real da Austrália** | Não | Sim: tráfego `car_fumi.glb` (T-124) e 2 peças (aerofólio, rodas, T-126). A foto da placa **não** foi usada |
| `docs/Modelos Melhorados/stylized_opel_ascona.glb` (+ pastas e `.usdz`) | Sedã antigo estilizado (Opel Ascona) | 98 mil | Placa branca lisa pintada na textura (sem número legível) | Não | Sim: tráfego `car_ascona.glb` (T-124) |
| `docs/Modelos Melhorados/stylized_ford_falcon_gt_coupe.glb` (+ pastas e `.usdz`) | Cupê antigo estilizado (Ford Falcon GT) | 94 mil | Placa branca lisa pintada na textura | Não | Sim: tráfego `car_falcon.glb` (T-124) |
| `docs/Modelos Melhorados/carro/low_poly_vehicle_mini_pack_5.*` | 6 SUVs iguais em cores diferentes | 79 mil (13 mil cada) | Não | Não | Sim: tráfego `car_suv.glb` (T-124) |
| `docs/Modelos Melhorados/JAC+1045+Truck.*` (.blend, .fbx, .glb) | Caminhão leve japonês/chinês: só cabine e chassi | 69 mil | Não (só o emblema JAC, já apagado) | Não | Sim: caminhão base **Canter**, cabines **curta** e **jac** (T-125, T-129), rodas e caixa de ferramentas (T-126) |
| `docs/Modelos Melhorados/BUS+JETSET.fbx` / `JETSET.dae` | Ônibus rodoviário (Jetset, Indonésia) | 143 mil | Não | Não (sem letreiro de destino) | Sim: tráfego `car_bus.glb` (T-124) |
| `docs/Modelos Melhorados/kenworth_w990_truck.glb` (+ pasta com `.blend`) | Cavalo mecânico americano Kenworth W990 com carreta | 2,17 milhões | Não | Não | Em parte: cabine **americana** (T-129) e 6 peças (T-126). O resto fica fora (marca, peso) |
| `docs/Modelos Melhorados/nypd_toyota_camry_.blend` | Viatura de polícia de Nova York (Toyota Camry) | 1,53 milhão | Sim: textura com **foto de uma placa real de Nova York** | Só o giroflex | **Não** (marca, polícia real, peso) |
| `docs/Modelos Melhorados/kaohsiung_circular_light_rail_caf_urbos_3.*` (+ `.usdz`, pastas) | Bonde urbano (CAF Urbos 3), 35 m | 71 mil | Não | Não: **só o vagão**, sem postes, trilhos, plataforma ou placas | **Não** (ver seção 3) |
| `docs/Novos modelos/Cabine/CF_500_complete.*` (.3dm, .stp, .stl + 3 renders) | Cabine "cara chata" International CF500 | 610 mil | Não | Não | Sim: cabine **chata**, a padrão do jogo (T-119) |
| `docs/Novos modelos/Van+01/` (FBX, OBJ, .max, texturas, prévias) | Furgão estilo Peugeot Partner | 504 mil | Não (as "Decal" são grafismos de lataria) | Não | Sim: tráfego `car_van01.glb` (T-121) |
| `docs/Novos modelos/Carro/` (.blend, FBX, OBJ, STL, 198 texturas) | Jipe Suzuki Samurai (Gypsy) | 436 mil | Não | Não | **Ainda não** (pode virar tráfego: precisa apagar "SUZUKI" da grade) |
| `docs/Novos modelos/Caminhão/canter.obj` | Mitsubishi Canter antigo com baú | 130 mil | Não | Não | **Não**: extraído de outro jogo (Ninja Ripper), risco legal |
| `Downloads\Tunnel.obj` + `Tunnel.mtl` (6,6 MB, **fora do projeto**) | **Túnel** redondo de 2 faixas com calçadas, luminárias, tubulação no teto e **3 pórticos de semáforo de faixa** | 105 mil | Não | Sim: os 3 **semáforos de faixa** (textura `stop-light-ge0a8c105d_1920.png`, ausente) | **Não**: licença desconhecida |
| `Downloads\van.abc` (Alembic, 1,7 MB, **fora do projeto**) | **Não é uma van**: é um **caminhão de carroceria aberta de madeira, 3 eixos (6 rodas)**, estilo Índia/Sudeste Asiático, com chão, estrada e fundo de estúdio | 62 mil (65% são as 6 rodas) | Não | Não | **Não**: licença desconhecida |
| `Downloads\Ge\` (10 arquivos .zip, 380 MB) | **Cópias zipadas** do Fumi, Urbos, Kenworth, Falcon e Ascona (2 zips de cada) | — | — | — | Nada novo: são os mesmos arquivos já extraídos em `docs/Modelos Melhorados/` |

**Resposta curta para "placa e sinalização":** nenhum dos modelos traz placas de trânsito, pórticos, setas ou letreiros que
sirvam para a estrada. Os únicos itens de "placa" são **fotos de placas de carro reais** (Austrália no Fumi, Nova York no Camry),
que **não podem ser usadas** (são de pessoas/estados reais). A única "sinalização" é o conjunto de **semáforos de faixa do
`Tunnel.obj`**, que tem licença desconhecida. Por isso a T-130 fez as placas e a sinalização **por código, com texto
fictício**, sem copiar nada desses arquivos (seção 4).

## 1. Detalhes dos dois arquivos novos de `Downloads`

Nenhum dos dois foi copiado para o projeto. Foram só abertos no Blender em segundo plano para medir.

### `Tunnel.obj` + `Tunnel.mtl`

- Gravado pelo Blender 2.92 a partir de `Tunnel.blend`. 13 objetos, 19 materiais, 104.814 triângulos.
- Medidas: tubo de ~204 m de comprimento, 10,9 m de largura e 7,5 m de altura (uma pista de 2 faixas); por fora, uma caixa de
  29 x 255 x 29 m que fecha a cena. O nosso túnel (`tunnel_3d.gd`) tem 27 m de largura para as 3 faixas + acostamento.
- Peças: paredes do túnel (7 mil), 2 calçadas (23 mil cada), 2 calhas laterais (17 mil cada), tubulação no teto (9 mil),
  2 faixas de luminárias (3 mil cada, material emissivo), pista (900), **3 pórticos de semáforo de faixa** (768 cada).
- Texturas: **não vieram junto**. O `.mtl` aponta para `C:\Users\Lenovo\Downloads\...` (outro PC) e para `New folder\9\`.
  Os nomes indicam as origens: `Concrete042A_2K_*` (ambientCG, normalmente CC0), `TexturesCom_Roads0059_1_seamless_S.jpg`
  (Textures.com, licença própria que proíbe redistribuir a imagem) e `stop-light-ge0a8c105d_1920.png` (nome típico do Pixabay).
- Uso possível, se a licença permitir: referência para luminárias e tubulação no teto do nosso túnel. Os triângulos (105 mil)
  são o dobro de um caminhão; teria que ser reduzido muito. **Precisa do link de onde foi baixado.**

### `van.abc`

- Alembic com 22 objetos, **sem materiais e sem texturas**, 250 quadros de animação.
- O veículo mede 2,6 x 8,7 x 3,3 m: cabine (`CABIN`), carroceria de tábuas (`BODY`, `SHEET`), tanque de diesel (`DIESE`), volante
  (`STERING`), para-lamas (`MUDGUARD`), 6 rodas (`Cylinder_*`, 6,8 mil triângulos cada). Vem também um gramado de 178 m, uma
  estrada e um fundo de estúdio.
- Uso possível, se a licença permitir: caminhão de carga aberto no tráfego (os Dekotora reais nasceram desse tipo de caminhão).
  Precisaria de rodas reduzidas (40 mil → ~3 mil triângulos), materiais e UV. **Precisa do link de onde foi baixado.**

## 2. Placas de veículo encontradas (e por que não servem)

| Modelo | O que tem | Serve? |
| --- | --- | --- |
| Fumi SC | `lights_licenseplate.png`: foto com lanternas e a placa amarela "VDJ·052 NEW SOUTH WALES" | Não: placa real de alguém. O `car_fumi.glb` do jogo usa só cores lisas (conferido: atlas 128 x 128) |
| NYPD Camry | Textura com foto de placa real "ADL 4681 NEW YORK" | Não: placa real e o modelo já estava fora |
| Ascona, Falcon | Retângulo branco liso na textura pintada | Só como lugar da placa; não tem número |
| Caminhões do jogo | Retângulo branco `plate` (0,5 x 0,22 m) atrás do baú; placa branca no para-choque `fb_standard_chrome` | Era só um retângulo branco; agora recebe a placa da T-130 |

## 3. Estruturas aproveitáveis para a sinalização?

- **Bonde Urbos:** o arquivo tem só o vagão (71 objetos `Object_*`, materiais `caf_urbos_*`). Não tem postes da rede aérea,
  trilhos, plataforma nem letreiros. Nada para a estrada.
- **Kenworth, ônibus, carros:** veículos; nenhum traz placa de trânsito, poste ou pórtico.
- **Túnel (`Tunnel.obj`):** os semáforos de faixa e as luminárias seriam úteis, mas a licença é desconhecida. Não foram usados.
- Conclusão: a sinalização nova é toda **feita por código** (formas simples + um atlas de texturas desenhado pelo nosso
  gerador, com a fonte Noto Sans JP que já está no projeto).

## 4. O que a T-130 aplicou no jogo

- **Placas de veículo japonesas fictícias** em todos os caminhões (frente e traseira) e em todos os carros do trânsito
  (frente e traseira): branca com letras verdes (carro particular), amarela (kei), verde com letras brancas (caminhão e
  ônibus comerciais) e preta com letras amarelas (kei comercial). Textos como "湘南 300 さ 12-34", com cidades de Kanto e
  números sorteados (64 placas diferentes, sem repetir entre os carros da mesma corrida enquanto houver placa livre).
- **Sinalização de pista:** limite de velocidade (círculo vermelho), aviso de curva e de túnel (losango amarelo), setas
  chevron vermelhas e brancas nas curvas fortes, placa "出口 EXIT", painéis de distância em km, placa com nome e comprimento
  na boca de cada túnel e "止まれ" + placa de pare antes do pedágio.
- Detalhes técnicos, números medidos e capturas: `docs/STATUS.md` (T-130) e `docs/capturas_t130/`.

## 5. Pendências para o Marco

1. **`Tunnel.obj` e `van.abc`: de onde vieram?** Mande o link da página de download e o tipo de licença (Royalty Free, CC0,
   CC-BY, "uso pessoal"...). Sem isso, eles ficam só como referência e não entram no jogo. As texturas do túnel também não
   vieram junto (estavam em outro PC).
2. A pasta `Downloads\Ge\` pode ser apagada por você se quiser liberar 380 MB: é só cópia zipada do que já está em
   `docs/Modelos Melhorados/` (eu não apaguei nada).
3. O jipe Suzuki (`docs/Novos modelos/Carro/`) ainda pode virar carro do trânsito, se você quiser (1 sessão).
