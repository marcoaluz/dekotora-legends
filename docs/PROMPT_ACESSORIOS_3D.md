# Prompt do Marco para as peças (usar no P40)

> Colado pelo Marco em 2026-10-16 ("aguarda este prompt que vai usar para criar as peças").
> **Vale no lugar do texto do P40 em `PROMPTS.md`.** Ver decisão em `DECISOES.md` e o plano de
> reconciliação com o pipeline de pixel art em `docs/STATUS.md`.

# BLOCO — BIBLIOTECA MODULAR DE ACESSÓRIOS DEKOTORA 3D PARA GODOT

## 1. OBJETIVO

Desenvolver uma biblioteca modular de acessórios 3D inspirados no estilo japonês Dekotora (デコトラ), para utilização no meu jogo desenvolvido em Godot.

O objetivo NÃO é criar somente um caminhão completo ou uma imagem ilustrativa. Quero produzir modelos 3D reais, utilizáveis no jogo, separados por peça, com materiais, geometria, pivôs e encaixes consistentes.

Utilize o Blender como ferramenta de modelagem, preferencialmente por scripts Python executados pelo próprio Blender, quando isso for viável.

## 2. REGRA OBRIGATÓRIA: ANALISAR O PROJETO ANTES DE MODIFICAR

Antes de desenvolver:

1. Analise a estrutura atual do repositório.
2. Leia os arquivos de contexto e instruções existentes, incluindo CLAUDE.md e CONTEXTO.md, caso existam.
3. Identifique a versão da Godot, o estilo visual, o sistema de coordenadas, a escala dos veículos e a organização atual dos assets.
4. Localize o modelo do caminhão que deverá receber os acessórios, caso já exista.
5. Identifique os padrões atuais de materiais, iluminação, importação e organização de cenas.
6. Não substitua modelos, cenas, scripts ou configurações existentes sem necessidade.
7. Se o caminhão-base não existir, crie somente um modelo técnico provisório para testar escala e encaixes, claramente identificado como placeholder.

Não presuma que o projeto utiliza determinada versão da Godot ou que o Blender está instalado. Verifique o ambiente e informe eventuais dependências ausentes.

## 3. REFERÊNCIAS VISUAIS

Utilize referências fotográficas de caminhões Dekotora reais para estudar:

- Para-choques cromados e grades ornamentadas.
- Quebra-sóis e extensões superiores.
- Suportes de faróis e iluminação no teto.
- Lanternas laterais e traseiras.
- Saias laterais e extensões de para-lamas.
- Calotas, degraus e frisos metálicos.
- Painéis artísticos japoneses.
- Placas decorativas e ornamentos.
- Combinações de metal polido, pintura perolizada e iluminação colorida.

Referências iniciais:
https://commons.wikimedia.org/wiki/Category:Dekotora

As referências servem para compreender formas e proporções. Não reproduza modelos comerciais, logotipos, personagens, pinturas artísticas protegidas ou veículos específicos de terceiros de forma indistinguível. Crie designs originais inspirados nas características gerais do estilo.

Registre as fontes e as licenças dos arquivos externos utilizados. Não baixe nem incorpore texturas sem verificar seus direitos de utilização.

## 4. PRIMEIRA ENTREGA: 32 ACESSÓRIOS

Produza oito peças para cada categoria.

### A. Frente
1. Para-choque cromado padrão.
2. Para-choque ornamentado.
3. Grade frontal com moldura metálica.
4. Quebra-sol superior.
5. Extensão decorativa de para-choque.
6. Par de faróis auxiliares redondos.
7. Conjunto de frisos frontais.
8. Ornamento frontal original.

### B. Teto e iluminação
9. Suporte de iluminação para o teto.
10. Barra de luzes retangulares.
11. Conjunto de faróis redondos.
12. Conjunto de lanternas pequenas.
13. Suporte de antena decorativa.
14. Placa luminosa personalizável.
15. Moldura luminosa para teto.
16. Ornamento superior original.

### C. Laterais e rodas
17. Saia lateral metálica.
18. Saia lateral com iluminação.
19. Extensão de para-lama.
20. Calota decorativa.
21. Degrau metálico.
22. Conjunto de frisos laterais.
23. Caixa ou acabamento lateral decorativo.
24. Ornamento lateral original.

### D. Traseira e decoração
25. Para-choque traseiro decorativo.
26. Painel traseiro com moldura.
27. Conjunto de lanternas traseiras.
28. Painel lateral decorativo.
29. Placa decorativa personalizável.
30. Para-barro com desenho original.
31. Ornamento traseiro metálico.
32. Painel decorativo com tema japonês original.

Cada item deve ser um modelo 3D independente, com nome único e identificável.

Quando uma peça for naturalmente simétrica, prefira um único modelo reutilizável com espelhamento ou posicionamento controlado pelo sistema de montagem.

## 5. QUALIDADE DA MODELAGEM

Crie modelos com aparência de jogo 3D, não primitivas genéricas sem acabamento.

Utilize:
- Geometria adequada à silhueta de cada acessório.
- Chanfros nas bordas metálicas importantes.
- Espessura realista em chapas e suportes.
- Parafusos e detalhes pequenos apenas quando contribuírem visualmente.
- Normais consistentes e ausência de faces acidentais.
- Topologia limpa onde isso for relevante.
- UVs quando houver necessidade de texturas.
- Materiais PBR com valores adequados de metallic e roughness.
- Materiais emissivos para elementos luminosos.
- Geometria e materiais otimizados para uso em tempo real.

O metal cromado deve ter reflexão visual convincente, mas não dependa exclusivamente de reflexos complexos que possam não existir no ambiente do jogo.

Não utilize excesso de polígonos em peças pequenas. Evite modelar parafusos invisíveis a distância.

Crie variações de cor e material sem duplicar desnecessariamente a geometria.

## 6. PADRÃO TÉCNICO E ENCAIXES

Antes de produzir os 32 modelos, determine o padrão de escala usando o caminhão-base existente.

Utilize metros como unidade de referência e respeite o sistema de coordenadas esperado pelo projeto Godot.

Defina para cada acessório:
- Dimensões aproximadas em metros.
- Origem e pivô coerentes com o ponto de montagem.
- Orientação consistente.
- Nome exclusivo.
- Categoria.
- Tipo de ponto de encaixe.
- Indicação de simetria, quando aplicável.
- Material e texturas necessários.

Crie pontos de montagem identificáveis, como:
- FRONT_BUMPER
- FRONT_GRILLE
- ROOF
- ROOF_LIGHTS
- SIDE_LEFT
- SIDE_RIGHT
- REAR
- WHEEL_FRONT
- WHEEL_REAR

Esses nomes são uma proposta inicial. Adapte-os ao sistema de coordenadas e à estrutura real do veículo encontrado no projeto.

Não invente dimensões definitivas sem verificar o caminhão-base. Quando não houver modelo disponível, estabeleça dimensões provisórias e documente-as.

Evite que as peças atravessem a cabine, as rodas, os vidros ou a carroceria. Verifique as folgas e a compatibilidade com o modelo de referência.

## 7. BLENDER E AUTOMAÇÃO

Se o Blender estiver disponível, crie scripts Python reproduzíveis que:

1. Gerem ou importem a geometria.
2. Configurem os materiais.
3. Organizem objetos e coleções por categoria.
4. Definam nomes e origens.
5. Apliquem transformações necessárias.
6. Verifiquem dimensões, nomes e materiais.
7. Salvem os arquivos .blend editáveis.
8. Exportem os modelos em .glb.

Não considere uma execução de script bem-sucedida como prova de que os modelos estão corretos. Inspecione os resultados, confira os arquivos exportados e corrija problemas detectados.

Não crie 32 variações quase idênticas apenas para atingir a quantidade solicitada. Cada peça deve apresentar uma função e uma forma visual distinguíveis.

Se o Blender não estiver instalado ou não puder ser executado, prepare os scripts e documente o que falta para executá-los. Não declare modelos prontos se os arquivos não tiverem sido realmente gerados.

## 8. INTEGRAÇÃO COM GODOT

Verifique a versão e a estrutura do projeto.

Prefira arquivos .glb com materiais incorporados quando apropriado, seguindo o fluxo de importação compatível com a versão encontrada.

Organize os arquivos, inicialmente, assim:

```
assets/
  vehicles/
    dekotora/
      accessories/
        front/
        lighting/
        sides/
        rear/
      materials/
      textures/
      source_blend/
      previews/
      catalog.json
```

Adapte a estrutura se o repositório já tiver uma convenção estabelecida.

Crie um catálogo JSON contendo, para cada acessório:
- ID estável.
- Nome.
- Categoria.
- Caminho do modelo.
- Ponto de encaixe.
- Dimensões.
- Compatibilidade.
- Materiais disponíveis.

Se necessário, desenvolva um pequeno script ou cena de demonstração na Godot para carregar os modelos e verificar o posicionamento nos pontos de encaixe.

Não implemente um sistema completo de loja, economia ou interface de personalização nesta etapa. O foco é a biblioteca de modelos e a validação técnica.

## 9. CENAS DE TESTE E VALIDAÇÃO

Crie uma cena de demonstração que mostre:

- Os acessórios agrupados por categoria.
- Uma vista frontal, lateral e traseira do veículo de teste.
- As peças montadas em seus pontos de encaixe.
- As peças isoladas para inspeção.
- Os materiais metálicos e emissivos em condições de iluminação adequadas.

Verifique:
- Escala e orientação.
- Geometria e normais.
- Materiais e texturas.
- Ausência de arquivos ausentes.
- Compatibilidade com a versão real da Godot.
- Desempenho razoável para um jogo em tempo real.
- Ausência de modificações não relacionadas ao escopo.

Não afirme que houve validação visual se apenas o script foi executado sem inspeção.

## 10. ORDEM DE EXECUÇÃO

Trabalhe em etapas e valide cada uma antes de avançar.

ETAPA 1 — Inspecionar o projeto e identificar o caminhão-base.

ETAPA 2 — Definir a escala, os encaixes e os materiais.

ETAPA 3 — Modelar três protótipos:
- Um para-choque frontal.
- Um suporte de luzes de teto.
- Uma saia lateral.

ETAPA 4 — Exportar os protótipos para .glb e validar a importação na Godot.

ETAPA 5 — Corrigir escala, materiais, pivôs e desempenho conforme os testes.

ETAPA 6 — Produzir os outros acessórios mantendo o padrão aprovado.

ETAPA 7 — Criar catálogo, cena de demonstração e documentação.

Não avance automaticamente para a produção completa se os três protótipos apresentarem problemas.

## 11. ENTREGA FINAL

Ao concluir, apresente:
1. Lista dos modelos efetivamente criados.
2. Caminho de cada arquivo .blend e .glb.
3. Scripts utilizados.
4. Catálogo de acessórios.
5. Cena de demonstração.
6. Resultado dos testes executados.
7. Problemas conhecidos e itens ainda pendentes.
8. Instruções para adicionar novos acessórios no futuro.

Priorize qualidade visual, modularidade, compatibilidade e manutenção. Preserve o código e os recursos existentes do jogo.

Comece pela inspeção do repositório e apresente um plano curto baseado no que realmente encontrar. Não altere arquivos do projeto antes de compreender a estrutura existente.
