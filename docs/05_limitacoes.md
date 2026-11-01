# 5. Limitações do data set

[← Voltar ao README](../README.md) · [← 4. Power BI](04_powerbi.md)

O que os dados permitem concluir, e o que não permitem. A mesma lista está na página oculta do dashboard.

## Período e comparações
- **30 meses de dados:** vendas de 01/01/2020 a 30/06/2022. De julho a dezembro só existem 2020 e 2021, e 2022 tem 6 meses.
- **Só dois anos completos:** sazonalidade e tendência não podem ser totalmente separadas. Por isso o índice sazonal geral não foi usado.
- **Comparações de crescimento sempre em jan–jun**, para não comparar 6 meses com 12.

## Receita e margem
- **Receita = quantidade × preço de tabela atual** (`ProductPrice` de `DimProduct`). O dataset não traz preço praticado, descontos nem histórico de preços.
- **Margem usa o custo atual do produto** (`ProductCost`). É margem bruta unitária, sem despesas.
- **Só 14 valores distintos de margem % entre os 130 produtos vendidos**, o que forma as faixas do gráfico de dispersão. É compatível com custo definido como proporção fixa do preço, mas essa causa é hipótese, não confirmada.
- **Moeda:** não informada no dataset; os valores são apresentados em US$ pela convenção do AdventureWorks.

## Produtos e categorias
- **Accessories e Clothing só vendem a partir de 01/07/2021**; Components não tem vendas. Totais por categoria não são comparáveis diretamente (12 meses contra 30 de Bikes).
- **O salto de julho/2021 não é explicado pelos dados.** Bikes cresce 47,8% sobre junho, e as categorias novas respondem por só 3% a 12% da receita.
- **Receita concentrada:** os 10 produtos de maior receita são todos Bikes (seis são Mountain-200) e geram 39% do total.
- **Devolução é medida em unidades.** Por produto não é exibida: cada item tem de 2 a 8 devoluções, e o percentual oscila demais.

## Territórios
- **Southeast, Northeast e Central somam 0,08% da receita** (119 unidades). O crescimento percentual deles não é interpretável e fica fora do ranking.
- O crescimento alto em todas as regiões reflete o salto geral de julho/2021, não um efeito de território.

## Clientes
- **A segmentação RFM usa o período todo**, com a recência medida contra o fim dos dados (30/06/2022), e não contra a data de hoje. Por isso as páginas de cliente não têm segmentações de filtro.
- **17.416 dos 18.148 clientes compraram.** Os outros 732 não têm segmento.
- **`BirthDate` implausível:** idades de 42 a 112 anos, 113 clientes com 90+ e 27 com 100+; nenhum cliente abaixo de 40. Provavelmente dados gerados artificialmente, então a análise etária é só indicativa e não entra no dashboard.
- **Renda anual:** não existe nenhum cliente com renda de 140 mil, e a faixa de 50 mil tem apenas 636 clientes (contra 2.560 em 40 mil e 2.879 em 60 mil).
- **Gênero:** 130 clientes (0,7%) sem informação, convertidos para `NULL`.
- **Clientes atípicos:** 32 clientes com 13 a 26 pedidos e gasto baixo, concentrados numa mesma janela de primeira compra (ago–set/2021). Mantidos na análise (0,18% da base).
- **Variáveis demográficas correlacionadas entre si** (renda, ocupação, escolaridade): os padrões descrevem associação, não causalidade.

---

[← Voltar ao README](../README.md)
