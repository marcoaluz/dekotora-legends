# Modelos de `docs/Modelos Melhorados/`: análise (T-123)

> **Atualização (T-125, 2026-10-18):** o Marco confirmou que todos os modelos desta pasta são Royalty Free. O **JAC 1045 já
> virou o caminhão base Canter e a cabine curta** (`blender/scripts/truck3d/jac_src.py`, `jac_parts.py`, `jac_cab.py`,
> `canter.py`; gerar: `build_truck_3d.py -- --variant canter` e `-- --variant base|leve|longo --cab curta`). Medido: 37,6 mil
> triângulos do JAC (cabine + chassi) -> 18,3 mil; Canter inteiro 48 mil; cabine curta 11,8 mil (modelos `*_curta` 49–73 mil).
> Escala usada: 0,74 (Canter, 6,9 m) e 0,84 (cabine curta: eixo dianteiro cai exatamente no nosso). Capturas em `docs/capturas_t125/`.

Data: 2026-10-18. Pedido do Marco: "pegar para criar novos carros de NPC, cabine e caminhão dentro do jogo; analisa cada arquivo".
**Só análise e prévias. Nada foi convertido nem entrou no jogo ainda**, porque a licença precisa da sua confirmação (seção 3).
A pasta é pesada (~700 MB) e **não deve ir para o Git** (adicionar ao `.gitignore`, como `docs/Novos modelos/`).
Medidas feitas no Blender 5.2.2 e lendo os `.glb` diretamente. Prévias em `docs/direcao_arte/modelos_melhorados/`.

## Resumo

| Modelo | O que é | Triângulos | Peças separadas | Licença no arquivo | Uso possível |
| --- | --- | --- | --- | --- | --- |
| `stylized_opel_ascona.glb` | Sedã antigo estilizado (Opel Ascona) | 98 mil, 1 malha, 1 material, 1 textura 4K | Não (malha única) | Sketchfab Standard (illustros) | **Tráfego** (precisa decimar e separar rodas) |
| `stylized_ford_falcon_gt_coupe.glb` | Cupê esportivo antigo (Ford Falcon GT) | 94 mil, 1 malha, 1 material | Não | Sketchfab Standard (illustros) | **Tráfego/rival esportivo** |
| `2025_fumi_sc.glb` | Superesportivo vermelho (base TVR Griffith), com interior e motor | 82 mil, 62 peças, 25 materiais, 24 texturas | Sim (rodas, capô, vidros, interior) | Sketchfab Standard (T3STAR) | **Tráfego raro** ("carro rápido"); interior e motor podem ser apagados |
| `JAC+1045+Truck` (.glb/.fbx/.blend) | Caminhão leve **só chassi e cabine** (estilo Canter), 84 peças com nome (cabine, chassi, rodas, motor, lanternas) | 69 mil | **Sim, muito bem separado** | **Nenhuma** | **Caminhão base "Canter" (T-120)** e cabine pequena. É o melhor encaixe da pasta |
| `BUS+JETSET.fbx` / `JETSET.dae` | Ônibus rodoviário (Jetset, Indonésia) | 143 mil (assentos 44 mil, carroceria 41 mil) | Sim (carroceria, rodas, vidros, luzes) | **Nenhuma** (parece o AdiPutro, citado na T-122) | **Tráfego pesado** (some assentos, painel, escadas: cai para ~8 mil) |
| `kenworth_w990_truck.glb` | Cavalo mecânico Kenworth com carreta | **2,17 milhões** (80 MB) | 85 peças, sem nome | Sketchfab Standard (Henry S) | **Só cabine como referência**: marca Kenworth visível, 2,2 M de triângulos |
| `nypd_toyota_camry_.blend` | Viatura NYPD (Toyota Camry) | **1,5 milhão**, 70 peças | Sim | **Nenhuma** | **Não**: viatura de polícia real, marcas NYPD e Toyota, pesada demais |
| `carro/low_poly_vehicle_mini_pack_5` | 6 SUVs (tipo Lexus RX) em cores diferentes, "low poly" | 79 mil no total (~13 mil por SUV), texturas 4K (zip de 250 MB) | Sim, 1 peça por carro | Sketchfab Standard (Vladek) | **Tráfego** (um SUV serve; 6 cores já vêm) |
| `kaohsiung_circular_light_rail…` | Bonde urbano (CAF Urbos 3) com 35 m | 71 mil | Sim | Sketchfab Standard (JoTrain) | **Não**: é trilho, não combina com a estrada |

## 1. Observações técnicas

- **Orçamento do jogo** (de `NOVOS_MODELOS.md`): carros de tráfego hoje ~2,7 mil triângulos e 6 a 7 materiais; dezenas na pista ao
  mesmo tempo. Um carro novo deve ficar em **3 a 6 mil** triângulos, 3 materiais, rodas separadas (`wheel_*`) e pintura trocável
  (`paint_white`). Tudo aqui precisa de **decimação forte** (o Ascona e o Falcon têm 20× o orçamento).
- **Falcon e Ascona**: malha única fundida, textura 4K de 6,7 MB cada. Para virar tráfego: separar rodas por região, decimar para
  ~4 mil, trocar a textura 4K por uma de 512 ou por cor lisa. Os dois têm cara "anos 70" que combina com o clima retrô.
- **Fumi SC**: 62 peças; jogar fora interior, motor e freios (cerca de 50 mil dos 82 mil triângulos); ficam carroceria, vidros,
  4 rodas. Bom como "carro esportivo de passagem rápida" (`speed` maior no tráfego).
- **JAC 1045**: unidade em escala 0,1 (precisa ×~70 para ficar com ~6 m); vem **sem caçamba/baú** (só chassi + cabine), o que é
  ótimo: o baú é o nosso (`cargo_box`). Cabine ~2,5 mil triângulos, chassi 3 mil, rodas ~2,5 mil cada (decimar para ~600).
  Materiais "Paint Gloss", "Aluminum" etc. viram os nossos (`paint`, `chrome`, `glass`). A grade tem um plano de fundo (`malla_fondo`)
  que deve ser apagado.
- **Ônibus**: 16 peças, 10 materiais. Sem assentos (44 mil) e painel, a carroceria + rodas ficam em ~60 mil e decimam bem
  (superfície lisa). Comprimento 13,3 m, altura 3,9 m. Serve como tráfego lento e grande, que obriga a trocar de faixa.
- **Kenworth**: pesado demais e cheio de marca. Útil só para olhar proporção do "bico longo" americano.

## 2. O que dá para fazer, por pedido do Marco

| Pedido | Candidato | Esforço | Observação |
| --- | --- | --- | --- |
| **Caminhão** novo | **JAC 1045** como base "Canter" (T-120): cabine pequena + chassi, baú nosso | médio/alto (1 sessão) | Substitui construir o Canter "do zero" por código; mas **licença desconhecida** |
| **Cabine** nova | Cabine do JAC (cabine curta japonesa); cabine do Kenworth só como referência | médio | A "cara chata" já está em T-119 (outra sessão) |
| **Carros de NPC** | Ascona, Falcon, SUV do mini pack, Fumi SC, ônibus | 1 sessão para os 3 primeiros em lote (mesmo script) | Entram na lista do `traffic_3d.gd`; exigem LOD ou limite de quantidade |
| Descartar | Bonde, NYPD Camry, Kenworth completo | — | Sem uso (bonde), marca policial real, peso |

## 3. Licença (precisa do Marco)

A regra vigente em `DECISOES.md` (2026-10-17/18) aceita só **Royalty Free** do CGTrader, com marca apagada, modelo reduzido,
`.pck` criptografado e crédito em `game/assets/LICENCAS.md`. Aqui aparece um tipo novo:

- **Sketchfab Standard** (Opel, Falcon, Fumi, SUVs, Kenworth, bonde): permite uso comercial, em todo tipo de mídia e em obras
  derivadas (um jogo é obra derivada), mas **proíbe redistribuir o modelo "como está"**, então vale a mesma proteção: modelo
  reduzido/modificado e `.pck` criptografado, crédito ao autor. **É uma extensão da regra; só entra com o seu OK.**
- **Sem licença no arquivo** (JAC 1045, ônibus Jetset, Camry NYPD): não sabemos. Preciso do **link da página de download e do
  rótulo** (como foi feito com a van e a CF500). O ônibus parece ser o "AdiPutro" da T-122 (rótulo já informado?).
- **Marcas**: Ascona (logo Opel na grade), Falcon (Ford), Camry (Toyota/NYPD), Kenworth: apagar emblemas e nomes, como combinado.

## 4. Proposta de passos (cada um vira tarefa; nenhum começou)

1. Marco confirma: (a) Sketchfab Standard vale como o Royalty Free na regra? (b) links/rótulos do JAC 1045 e do ônibus.
2. **Lote de tráfego** (Ascona, Falcon, SUV, ônibus): script único de conversão (decimar, separar rodas, 3 materiais, `.glb` em
   `game/assets/vehicles/traffic/`), entrar em `traffic_3d.gd`, medir chamadas de desenho. Aproveita `blender/renders/t115/scripts/convert.py`.
3. **JAC 1045 → caminhão base Canter** (T-120): trocar o plano da T-120 "por código" por "a partir da malha", se a licença permitir.
4. Fumi SC como carro raro de tráfego.
