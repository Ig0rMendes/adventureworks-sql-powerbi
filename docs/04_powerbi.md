# 4. Power BI: modelo, medidas e dashboard

[← Voltar ao README](../README.md) · [← 3. Análises SQL](03_analises_sql.md)

O dashboard foi construído sobre os números já validados em SQL: cada medida DAX foi conferida contra a consulta equivalente antes de virar visual.

## Modelo

- **Modo:** Importar (conexão com o SQL Server, banco `AdventureWorksAnalysis`).
- **Relacionamentos:** 9 de um para muitos (dimensão → fato, filtro em um sentido) e 1 de um para um entre `vw_ClienteRFM` e `DimCustomer` (filtro nos dois sentidos), para o segmento do cliente filtrar as vendas.
- **`DimDate`** marcada como tabela de datas. Coluna calculada `_Ano-Mês` (texto, `2021-07`) para eixos cronológicos.
- **Tabela `Medidas`:** concentra todas as medidas DAX.
- **Moeda:** valores apresentados em dólares (US$), convenção do AdventureWorks; o dataset não informa a moeda.

```dax
_Ano-Mês = YEAR ( DimDate[Date] ) & "-" & FORMAT ( MONTH ( DimDate[Date] ), "00" )
```

### Por que a view `vw_ClienteRFM`
A segmentação RFM usa `NTILE` e regras de segmento já validadas em SQL. Recriar a lógica em DAX arriscaria divergência entre as duas camadas. A view entrega uma linha por cliente que comprou (17.416) com recência, frequência, valor, as três notas e o segmento, na mesma lógica do script `04_segmentacao_cliente_rfm.sql`. A conferência da view contra a consulta de segmentação foi o que revelou o problema do `NTILE` não determinístico (ver [análises SQL](03_analises_sql.md)).

## Medidas

### Base
```dax
Receita Total = SUMX ( FactSales, FactSales[OrderQuantity] * RELATED ( DimProduct[ProductPrice] ) )
Quantidade Vendida = SUM ( FactSales[OrderQuantity] )
Total de Pedidos = DISTINCTCOUNT ( FactSales[OrderNumber] )
Ticket Médio por Pedido = DIVIDE ( [Receita Total], [Total de Pedidos] )
Unidades Devolvidas = SUM ( FactReturns[ReturnQuantity] )
Taxa de Devolução = DIVIDE ( [Unidades Devolvidas], [Quantidade Vendida] )
Custo Total = SUMX ( FactSales, FactSales[OrderQuantity] * RELATED ( DimProduct[ProductCost] ) )
Margem Total = [Receita Total] - [Custo Total]
Margem % = DIVIDE ( [Margem Total], [Receita Total] )
```

### Comparação no mesmo período
```dax
Receita Mesmo Período =
VAR MesCorte = MONTH ( CALCULATE ( MAX ( FactSales[OrderDate] ), REMOVEFILTERS () ) )
RETURN CALCULATE ( [Receita Total], DimDate[Mês Nº] <= MesCorte )

Receita Mesmo Período Ano Anterior =
CALCULATE ( [Receita Mesmo Período], DimDate[Ano] = MAX ( DimDate[Ano] ) - 1 )

Crescimento Mesmo Período =
IF ( HASONEVALUE ( DimDate[Ano] ),
    DIVIDE ( [Receita Mesmo Período] - [Receita Mesmo Período Ano Anterior], [Receita Mesmo Período Ano Anterior] ) )

Receita Período Comum =
VAR UltimaData = CALCULATE ( MAX ( FactSales[OrderDate] ), REMOVEFILTERS () )
VAR Inicio = EDATE ( UltimaData, -12 ) + 1
RETURN CALCULATE ( [Receita Total], REMOVEFILTERS ( DimDate ), DimDate[Date] >= Inicio, DimDate[Date] <= UltimaData )

Receita Ano Atual Parcial =
VAR UltimaData = CALCULATE ( MAX ( FactSales[OrderDate] ), REMOVEFILTERS () )
VAR AnoUlt = YEAR ( UltimaData )
VAR MesCorte = MONTH ( UltimaData )
RETURN CALCULATE ( [Receita Total], REMOVEFILTERS ( DimDate ), DimDate[Ano] = AnoUlt, DimDate[Mês Nº] <= MesCorte )

Receita Ano Anterior Parcial =
VAR UltimaData = CALCULATE ( MAX ( FactSales[OrderDate] ), REMOVEFILTERS () )
VAR AnoUlt = YEAR ( UltimaData )
VAR MesCorte = MONTH ( UltimaData )
RETURN CALCULATE ( [Receita Total], REMOVEFILTERS ( DimDate ), DimDate[Ano] = AnoUlt - 1, DimDate[Mês Nº] <= MesCorte )

Crescimento Parcial % =
DIVIDE ( [Receita Ano Atual Parcial] - [Receita Ano Anterior Parcial], [Receita Ano Anterior Parcial] )

Receita Mesmo Mês Ano Anterior = CALCULATE ( [Receita Total], SAMEPERIODLASTYEAR ( DimDate[Date] ) )

Crescimento vs Mesmo Mês Ano Anterior % =
DIVIDE ( [Receita Total] - [Receita Mesmo Mês Ano Anterior], [Receita Mesmo Mês Ano Anterior] )
```

### Produto e território
```dax
Receita Top 10 Produtos =
SUMX ( TOPN ( 10, ALLSELECTED ( DimProduct[ProductName] ), [Receita Total] ), [Receita Total] )

Participação Top 10 Produtos =
DIVIDE ( [Receita Top 10 Produtos], CALCULATE ( [Receita Total], ALLSELECTED ( DimProduct ) ) )

Participação Mountain-200 =
DIVIDE (
    CALCULATE ( [Receita Total],
        FILTER ( ALL ( DimProduct[ProductName] ), LEFT ( DimProduct[ProductName], 12 ) = "Mountain-200" ) ),
    CALCULATE ( [Receita Total], ALLSELECTED ( DimProduct ) ) )

Participação % =
DIVIDE ( [Receita Total], CALCULATE ( [Receita Total], REMOVEFILTERS ( DimTerritory ) ) )

Região Líder =
MAXX ( TOPN ( 1, VALUES ( DimTerritory[Region] ), [Receita Total] ), DimTerritory[Region] )

Participação 3 Maiores Regiões =
DIVIDE ( SUMX ( TOPN ( 3, VALUES ( DimTerritory[Region] ), [Receita Total] ), [Receita Total] ), [Receita Total] )
```
A medida da Mountain-200 usa o nome do produto de forma fixa: é um destaque deliberado da análise.

### Clientes (RFM)
```dax
Clientes = DISTINCTCOUNT ( vw_ClienteRFM[CustomerKey] )
% Clientes = DIVIDE ( [Clientes], CALCULATE ( [Clientes], REMOVEFILTERS ( vw_ClienteRFM ) ) )
% Receita = DIVIDE ( [Receita Total], CALCULATE ( [Receita Total], REMOVEFILTERS ( vw_ClienteRFM ) ) )
Valor Médio por Cliente = DIVIDE ( [Receita Total], [Clientes] )
Recência Média (dias) = AVERAGE ( vw_ClienteRFM[RecenciaDias] )
Frequência Média = AVERAGE ( vw_ClienteRFM[Frequencia] )
% Clientes de Compra Única = DIVIDE ( CALCULATE ( [Clientes], vw_ClienteRFM[Frequencia] = 1 ), [Clientes] )
```

### Tendência
```dax
Média Mensal Antes de Jul/2021 =
VAR Corte = DATE ( 2021, 7, 1 )
VAR Primeira = CALCULATE ( MIN ( FactSales[OrderDate] ), REMOVEFILTERS () )
VAR Meses = DATEDIFF ( Primeira, Corte, MONTH )
RETURN DIVIDE ( CALCULATE ( [Receita Total], DimDate[Date] < Corte ), Meses )

Média Mensal Desde Jul/2021 =
VAR Corte = DATE ( 2021, 7, 1 )
VAR Ultima = CALCULATE ( MAX ( FactSales[OrderDate] ), REMOVEFILTERS () )
VAR Meses = DATEDIFF ( Corte, Ultima, MONTH ) + 1
RETURN DIVIDE ( CALCULATE ( [Receita Total], DimDate[Date] >= Corte ), Meses )

Maior Receita Mensal = MAXX ( VALUES ( DimDate[_Ano-Mês] ), [Receita Total] )
```
As datas de corte das duas médias (01/07/2021) são fixas porque marcam a quebra de patamar identificada na análise.

## Validação

Cada medida foi conferida contra o resultado SQL antes de virar visual. Números de referência:

| Medida | Valor |
|---|---|
| Receita Total | 24.914.567,18 |
| Quantidade Vendida | 84.174 |
| Taxa de Devolução | 2,17% |
| Margem % | 41,97% |
| Receita Período Comum (jul/2021 a jun/2022) | 15.556.764,57 |
| Clientes que compraram | 17.416 |
| Participação Top 10 Produtos | 39,35% |
| Participação Mountain-200 | 28,78% |
| Participação 3 Maiores Regiões | 61,55% |
| Média mensal antes / desde jul/2021 | 519.877,92 / 1.296.397,05 |

**Um erro que a validação encontrou:** a receita aparecia igual (24.914.567,18) em todos os segmentos de cliente. Causa: o relacionamento entre a view e `DimCustomer` não existia, e o filtro do segmento não chegava às vendas. Corrigido com o relacionamento um para um, filtro nos dois sentidos.

## Páginas

| Página | Visuais principais |
|---|---|
| Resumo Executivo | 4 KPIs, 3 achados em números destacados, 3 recomendações |
| 1. Visão Geral | 4 KPIs, receita mensal, receita no mesmo período por ano e crescimento sobre o ano anterior |
| 2. Rentabilidade de Produto | 3 KPIs, margem e devolução por categoria, dispersão volume × margem, top 10 produtos |
| 3. Performance por Território | 3 KPIs, mapa por país, treemap por região, crescimento por região, tabela de detalhe |
| 4. Comportamento do Cliente (RFM) | 3 KPIs, % de clientes vs. % de receita por segmento, matriz de calor recência × frequência, tabela de perfil por segmento |
| 5. Tendência e Sazonalidade | 3 KPIs, linhas de receita mensal por ano, crescimento sobre o mesmo mês do ano anterior, receita mensal por categoria (área empilhada) |
| Limitações do data set (oculta) | Lista das limitações em quatro blocos |

### Princípios de design
- **Números primeiro, texto curto:** cada visual tem título e subtítulo com a conclusão; as notas de limitação ficam numa linha no rodapé; o detalhe fica na página oculta e neste repositório.
- **Variedade de formatos:** linhas, colunas, dispersão, mapa, treemap, matriz de calor e área empilhada, escolhidos pela pergunta que cada visual responde.
- **Barra lateral padrão** com navegação entre páginas e segmentações.

### Segmentações por página
Nem toda segmentação vale em toda página: algumas medidas ignoram datas de propósito, e o RFM é calculado sobre o período inteiro.

| Página | Ano | Categoria | Continente |
|---|---|---|---|
| Resumo Executivo | não | não | não |
| 1. Visão Geral | sim | sim | sim |
| 2. Rentabilidade | sim | sim | sim |
| 3. Território | não | sim | sim |
| 4. Cliente / RFM | não | não | não |
| 5. Tendência | não | sim | sim |

- A segmentação de **Ano** é desligada nos visuais de comparação no mesmo período e de crescimento, que precisam mostrar os três anos (**Editar interações**).
- A segmentação de **Categoria** esconde Components, que não tem vendas (filtro `Receita Total` não está em branco no visual).

---

Próximo: [5. Limitações →](05_limitacoes.md)
