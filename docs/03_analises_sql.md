# 3. Análises em SQL

[← Voltar ao README](../README.md) · [← 2. Diagnóstico e tratamento](02_diagnostico_e_tratamento.md)

Com o modelo tratado e validado, a análise foi organizada em cinco blocos de negócio, um script por bloco (`sql/05_analysis/`). Os scripts funcionam como **gabarito**: a lógica e os números são validados em SQL antes de serem reproduzidos como medidas DAX no Power BI, para que o dashboard não dependa de cálculos não conferidos.

**Convenções**
- Receita = `OrderQuantity` × `ProductPrice`; margem = `ProductPrice` − `ProductCost` (valores de `DimProduct`; ver [limitações](05_limitacoes.md)).
- Valores monetários em US$ (convenção do AdventureWorks; o dataset não informa a moeda).
- Crescimento sempre comparado no mesmo período (jan–jun), porque os dados terminam em 30/06/2022.

---

## 1. Visão geral (`01_visao_geral.sql`)

**Pergunta:** como está o negócio, de forma resumida?

Consultas: KPIs gerais, taxa de devolução, receita por ano, série mensal e crescimento em período comparável.

Receita total do período: **US$ 24.914.567,18**; 84.174 unidades; taxa de devolução de 2,17%.

| Período | Receita | Meses de dados |
|---|---|---|
| 2020 | 6.404.933,98 | 12 |
| 2021 | 9.324.195,35 | 12 |
| 2022 | 9.185.437,85 | 6 (jan–jun) |

Como 2022 só vai até 30/06, a comparação correta usa o mesmo período em cada ano:

| 1º semestre | Receita | Variação sobre o ano anterior |
|---|---|---|
| 2020 | 3.743.653,85 | — |
| 2021 | 2.952.868,63 | −21,1% |
| 2022 | 9.185.437,85 | +211,1% |

- Crescimento entre anos completos (2021 sobre 2020): +45,6%.
- O crescimento de 2022 deve ser lido junto com o salto de nível de julho/2021 (seção 5).
- As devoluções cobrem de 18/01/2020 a 30/06/2022, período compatível com o das vendas, o que valida a taxa de devolução geral.

---

## 2. Rentabilidade de produto (`02_rentabilidade_produto.sql`)

**Pergunta:** o que vale mais a pena vender, e o que mais vende é também o que mais rende?

Consultas: receita e margem por categoria e subcategoria; volume × margem por produto; top 10 por receita e por margem; taxa de devolução por produto e por categoria.

| Categoria | Receita | Margem % | Taxa de devolução |
|---|---|---|---|
| Bikes | 23.642.500,06 | 41,14% | 3,08% |
| Accessories | 906.656,58 | 62,84% | 1,95% |
| Clothing | 365.410,54 | 44,27% | 2,16% |

- **Os mesmos 10 produtos lideram em receita e em margem total.** Todos são Bikes (6 variações da Mountain-200, 3 da Road-250 e 1 Road-150): receita de 9.803.224,99 (39,4% do total) e margem de 4.338.928,20.
- As seis Mountain-200 somam 7.170.950,38, ou 28,8% da receita total.
- Accessories tem a maior margem percentual, mas pesa 3,6% da receita e não chega ao top 10 em margem total.
- **A margem % é quase uma propriedade do modelo do produto:** só 14 valores distintos entre os 130 produtos vendidos. É compatível com custo definido como proporção fixa do preço por linha de produto (hipótese, não confirmada).
- **Taxa de devolução por produto não é exibida:** cada produto tem de 2 a 8 devoluções, e o percentual oscila demais (por exemplo, 6 devoluções em 51 unidades dão 11,76%).
- Components não tem vendas, e Accessories/Clothing têm 12 meses de dados contra 30 de Bikes: participações de receita entre categorias não são comparáveis diretamente (margens percentuais não são afetadas).
- **Decisão técnica:** a junção direta entre `FactSales` e `FactReturns` pelo produto multiplicava linhas (efeito *fan-out*) e gerava taxas acima de 100%. Cada fato passou a ser agregada separadamente antes da junção.

---

## 3. Performance por território (`03_performance_territorio.sql`)

**Pergunta:** onde o negócio está crescendo ou estagnando?

Consultas: receita por região/país/continente (com participação), crescimento por território, ranking de crescimento e taxa de devolução por território.

| Região | País | Receita | Participação |
|---|---|---|---|
| Australia | Australia | 7.416.451,76 | 29,8% |
| Southwest | EUA | 4.822.791,91 | 19,4% |
| Northwest | EUA | 3.095.072,15 | 12,4% |
| United Kingdom | Reino Unido | 2.902.558,90 | 11,7% |
| Germany | Alemanha | 2.524.677,34 | 10,1% |
| France | França | 2.362.641,01 | 9,5% |
| Canada | Canadá | 1.769.243,88 | 7,1% |
| Southeast, Northeast, Central | EUA | 21.130,23 | 0,08% |

- Por continente: América do Norte 39,0%, Europa 31,3%, Pacífico 29,8%. Por país, os EUA lideram (31,9%, soma das cinco regiões), seguidos de Australia (29,8%).
- Australia, Southwest e Northwest somam 61,5% da receita.
- **Southeast, Northeast e Central** vendem 119 unidades no total; os percentuais de crescimento deles não são interpretáveis e ficam fora do ranking.

Crescimento do 1º semestre de 2022 sobre o de 2021 (regiões principais):

| Região | 1S 2022 | 1S 2021 | Crescimento |
|---|---|---|---|
| Canada | 638.084,98 | 100.552,00 | +534,6% |
| Southwest | 1.911.215,24 | 352.765,09 | +441,8% |
| Northwest | 1.208.889,42 | 276.442,63 | +337,3% |
| United Kingdom | 1.119.086,06 | 351.462,10 | +218,4% |
| Germany | 1.015.655,71 | 340.442,97 | +198,3% |
| France | 873.752,86 | 345.895,06 | +152,6% |
| Australia | 2.408.102,24 | 1.178.417,74 | +104,4% |

- **Todas as regiões principais cresceram.** O padrão aponta para o salto geral de julho/2021, não para um fenômeno de território; as diferenças refletem principalmente a base de partida (Canada caiu 76% de 2020 para 2021 antes de disparar).
- A taxa de devolução varia pouco entre as regiões principais: de 2,05% (Germany) a 2,37% (France). Nas três regiões pequenas, 0 ou 1 devolução é só ruído.

---

## 4. Comportamento do cliente: segmentação RFM (`04_segmentacao_cliente_rfm.sql`)

**Pergunta:** quem são os clientes mais valiosos e quem está sendo perdido?

**Metodologia:** cada cliente comprador (17.416) recebe nota de 1 a 5 em Recência, Frequência e Valor monetário; a combinação das notas define o segmento.

- **Recência** é calculada contra o último dia de venda do dataset (+1 dia), e não contra a data atual, que faria todos os clientes parecerem inativos há anos.
- **Frequência** é pontuada por faixas fixas (1, 2, 3, 4–5 e 6+ pedidos), não por `NTILE`: 66% dos clientes têm só 1 pedido, e o `NTILE` separaria clientes idênticos em notas diferentes.
- **Recência e valor** usam `NTILE(5)`, com `CustomerKey` como critério de desempate (ver correções, abaixo), para o resultado ser reproduzível.
- O resultado é exposto ao Power BI pela view `vw_ClienteRFM` (uma linha por cliente), para que a segmentação do dashboard seja exatamente a validada em SQL.

| Segmento | Clientes | % clientes | Receita | % receita |
|---|---|---|---|---|
| Recorrentes | 3.332 | 19,13% | 8.926.495,95 | 35,83% |
| Em Risco | 1.764 | 10,13% | 5.942.269,69 | 23,85% |
| Hibernando | 5.203 | 29,87% | 3.283.070,71 | 13,18% |
| Campeões | 761 | 4,37% | 3.086.268,05 | 12,39% |
| Novos / Promissores | 4.139 | 23,77% | 2.662.226,14 | 10,69% |
| Precisam de Atenção | 2.217 | 12,73% | 1.014.236,64 | 4,07% |

- **Concentração:** Campeões, Recorrentes e Em Risco são 34% dos clientes e geram 72% da receita. Os clientes de 1 pedido são 66% da base e 28% da receita.
- **Em Risco:** 1.764 clientes (23,85% da receita), recência média de 248 dias e o maior ticket por pedido (1.619,15, contra 1.036,70 em Campeões). É o grupo de maior valor potencial de reativação.
- Campeões gastam mais no total por comprarem mais vezes (média de 3,9 pedidos), não por terem pedidos maiores.
- **32 clientes atípicos:** 13 a 26 pedidos, primeira compra entre 01/08/2021 e 28/09/2021 e gasto total de 757,56 a 1.838,99 (compram muito e gastam pouco). Mantidos na análise (0,18% da base).
- Os segmentos nomeiam o comportamento observado: "Recorrentes" (e não "Fiéis") porque a frequência média é cerca de 2 pedidos; "Hibernando" (e não "Perdidos") porque o dado só mostra ausência de compra recente, não abandono.

### Perfil demográfico dos clientes compradores

| Faixa etária | Clientes | % da receita | Ticket por pedido | Gasto por cliente |
|---|---|---|---|---|
| 40 a 49 anos | 3.126 | 14,6% | 838,04 | 1.164,57 |
| 50 a 59 anos | 6.009 | 39,7% | 1.102,91 | 1.647,11 |
| 60 a 69 anos | 4.606 | 29,0% | 1.077,58 | 1.570,28 |
| 70 anos ou mais | 3.675 | 16,6% | 807,16 | 1.127,60 |

| Renda anual | Clientes | Gasto por cliente |
|---|---|---|
| 10 a 30 mil | 4.922 | 1.094 |
| 40 a 60 mil | 6.075 | 1.283 |
| 70 a 90 mil | 4.348 | 1.752 |
| 100 mil ou mais | 2.071 | 1.986 |

- Clientes de 50 a 69 anos são 61% da base e geram 69% da receita; o ticket por pedido deles é cerca de 30% maior que o das faixas extremas.
- O gasto por cliente cresce com a renda: de 1.094 na faixa mais baixa a 1.986 na mais alta (cerca de 1,8 vez).
- Gasto médio por ocupação: Professional 1.622, Management 1.590, Clerical 1.451, Skilled Manual 1.260, Manual 1.083. Por escolaridade: Bachelors 1.651, Graduate Degree 1.556, Partial College 1.375, High School 1.256, Partial High School 959.
- Ocupação, escolaridade e renda são correlacionadas entre si; os padrões descrevem associação, não causalidade. O cruzamento ocupação × escolaridade gera grupos pequenos (o primeiro do ranking tem 130 clientes), então a análise usa cada variável separadamente.
- A análise etária é indicativa, pela qualidade da `BirthDate`. Idade não é usada no dashboard.

---

## 5. Sazonalidade e tendência (`05_sazonalidade.sql`)

**Pergunta:** quando o negócio vende mais, e esse padrão se repete?

Consultas: receita mensal com um ano por coluna, trimestres, índice sazonal, crescimento sobre o mesmo mês do ano anterior, receita por categoria, variação mês a mês e taxa de devolução mensal.

- De julho a dezembro só existem 2020 e 2021; 2022 aparece como `NULL` nesses meses (e não como zero, que afirmaria venda nula).
- Bikes é a única categoria com vendas desde 01/01/2020. Accessories e Clothing começam em 01/07/2021, e Components não tem vendas.
- **Salto de nível em julho/2021:** a receita de Bikes sobe 47,8% sobre junho (de 533.825 para 788.987). As categorias novas respondem por apenas 3% a 12% da receita (pico de 12,2% em agosto/2021; 7,0% em junho/2022), então não explicam o salto. A causa não é identificável nos dados.
- **Média mensal:** US$ 519.878 de jan/2020 a jun/2021 (18 meses) contra US$ 1.296.397 de jul/2021 a jun/2022 (12 meses), ou 2,5 vezes. A maior receita mensal é de junho/2022 (1.826.984,91).
- **Crescimento sobre o mesmo mês do ano anterior:** no 1º semestre de 2021, queda de 11% a 27% (só Bikes vendia); a partir de julho/2021 todos os meses crescem de +49,9% a +247,2% (junho/2022: +242,2%). Só em Bikes, de +160% a +218% no 1º semestre de 2022.
- **Dezembro é o único padrão repetido nos dois anos:** +72,6% (2020) e +44,2% (2021) sobre novembro, seguido de queda de 23,3% e 22,1% em janeiro. Em 2021, dezembro sobe em todas as categorias (Bikes +47%, Accessories +21%, Clothing +21%). Com dois anos, é uma pista e não uma conclusão.
- **O índice sazonal geral foi descartado:** os dois anos têm perfis opostos (janeiro: 1,097 em 2020 e 0,557 em 2021), então o índice mistura mudança de nível com sazonalidade.

---

## Correções de método e revisões de decisão

Registro das situações em que o resultado de uma consulta levou a corrigir a própria metodologia ou uma decisão anterior.

| Situação | Problema encontrado | Correção ou decisão |
|---|---|---|
| Taxa de devolução por produto | A junção direta entre `FactSales` e `FactReturns` multiplicava linhas (*fan-out*) e produzia taxas acima de 100%. | Agregar cada fato separadamente antes de unir; aplicado também aos scripts 03 e 05. |
| Crescimento com 2022 parcial | O dataset termina em 30/06/2022; comparar 2022 com anos de 12 meses mostrava uma queda inexistente. | Comparar sempre o mesmo período (jan–jun) e, em separado, apenas anos completos. |
| Frequência no RFM | 66% dos clientes têm 1 pedido; o `NTILE` dava notas diferentes a clientes idênticos. | Faixas fixas de pedidos; `NTILE` mantido em recência e valor. |
| Data de referência da recência | A data atual faria todos os clientes parecerem inativos há anos. | Usar o último dia de venda do dataset + 1. |
| **`NTILE` não determinístico** | Ao conferir a view contra a consulta de segmentação, os segmentos divergiam em poucos clientes (por exemplo, Recorrentes com 3.337 e 3.330). Clientes empatados em recência ou valor eram distribuídos de forma arbitrária entre as faixas, e o resultado mudava de uma execução para outra. | `CustomerKey` como critério de desempate no `NTILE`; view e consulta passaram a dar o mesmo resultado, e todos os números do RFM foram atualizados. |
| Salto de julho/2021 | Hipótese: o lançamento de Accessories e Clothing explicaria o salto. | Testada com a receita por categoria: respondem por 3% a 12%. Hipótese descartada; causa desconhecida. |
| Crescimento por território | A nota inicial atribuía o crescimento a Accessories e Clothing. | Corrigida: todos os territórios sobem após o salto geral de julho/2021, e as categorias novas explicam pouco. |
| Índice sazonal geral | Perfis opostos entre 2020 e 2021. | Descartado do dashboard; substituído por variação mês a mês e crescimento só de Bikes. |
| `BirthDate` em `DimCustomer` | Inicialmente mantida como "distribuição real da base"; a análise etária mostrou idades de 42 a 112 anos, 27 clientes com 100+ e nenhum abaixo de 40. | Dados mantidos (as compras são válidas), mas a coluna é tratada como pouco confiável e fica fora do dashboard. |
| Taxa de devolução por produto no dashboard | 2 a 8 devoluções por produto geram percentuais instáveis. | Mantida só a taxa por categoria. |

---

Próximo: [4. Power BI →](04_powerbi.md)
