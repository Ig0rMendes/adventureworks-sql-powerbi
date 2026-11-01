-- =====================================================================
-- ANÁLISE — Página 1: Visão Geral de Performance
-- Pergunta de negócio: Como está o negócio, de forma resumida?
-- Alimenta: cards de KPI (receita, quantidade, ticket médio, taxa de
-- devolução) e o gráfico de tendência de receita ao longo do tempo.
-- =====================================================================


-- =====================================================================
-- 1. KPIs GERAIS (cards do topo da página)
-- Receita total, quantidade vendida, número de pedidos e ticket médio.
-- Observação: a receita é calculada via JOIN com DimProduct, já que
-- FactSales guarda apenas a quantidade — o valor financeiro depende
-- do ProductPrice vigente em DimProduct.
-- =====================================================================
SELECT
    SUM(f.OrderQuantity * p.ProductPrice) AS ReceitaTotal,
    SUM(f.OrderQuantity)                  AS QuantidadeTotalVendida,
    COUNT(DISTINCT f.OrderNumber)         AS TotalPedidos,
    SUM(f.OrderQuantity * p.ProductPrice) 
        / NULLIF(COUNT(DISTINCT f.OrderNumber), 0) AS TicketMedioPorPedido,
    SUM(f.OrderQuantity * p.ProductPrice) 
        / NULLIF(SUM(f.OrderQuantity), 0) AS PrecoMedioPorUnidade
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey;


-- =====================================================================
-- 2. TAXA DE DEVOLUÇÃO GERAL
-- Relação entre unidades devolvidas e unidades vendidas, no período
-- completo. Métrica importante de qualidade/satisfação.
-- =====================================================================
SELECT
    (SELECT SUM(ReturnQuantity) FROM FactReturns)       AS TotalUnidadesDevolvidas,
    (SELECT SUM(OrderQuantity) FROM FactSales)          AS TotalUnidadesVendidas,
    CAST(
        (SELECT SUM(ReturnQuantity) FROM FactReturns) * 100.0
        / NULLIF((SELECT SUM(OrderQuantity) FROM FactSales), 0)
    AS DECIMAL(5,2))                                    AS TaxaDevolucaoPercentual;


-- =====================================================================
-- 3. RECEITA POR ANO (comparação simples entre os 3 anos do dataset)
-- =====================================================================
SELECT
    YEAR(f.OrderDate)                     AS Ano,
    SUM(f.OrderQuantity * p.ProductPrice) AS ReceitaAno,
    SUM(f.OrderQuantity)                  AS QuantidadeAno,
    COUNT(DISTINCT f.OrderNumber)         AS PedidosAno
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY YEAR(f.OrderDate)
ORDER BY Ano;


-- =====================================================================
-- 4. RECEITA MENSAL (série temporal — alimenta o gráfico de linha)
-- Granularidade mês a mês, para visualizar tendência e sazonalidade
-- ao longo de todo o período coberto pelo dataset.
-- =====================================================================
SELECT
    YEAR(f.OrderDate)                               			AS Ano,
    MONTH(f.OrderDate)                               			AS Mes,
    DATEFROMPARTS(YEAR(f.OrderDate), MONTH(f.OrderDate), 1) 	AS AnoMes,
    SUM(f.OrderQuantity * p.ProductPrice)           			AS ReceitaMes,
    SUM(f.OrderQuantity)                              			AS QuantidadeMes
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY YEAR(f.OrderDate), MONTH(f.OrderDate)
ORDER BY Ano, Mes;


-- =====================================================================
-- 5. CRESCIMENTO ANO A ANO (variação percentual, para contextualizar
-- se o negócio está em expansão ou retração)
-- =====================================================================
WITH ReceitaPorAno AS (
    SELECT 
        YEAR(f.OrderDate) 						AS Ano,
        SUM(f.OrderQuantity * p.ProductPrice) 	AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY YEAR(f.OrderDate)
)
SELECT 
    Ano,
    Receita,
    LAG(Receita) OVER (ORDER BY Ano)            AS ReceitaAnoAnterior,
    CAST(
        (Receita - LAG(Receita) OVER (ORDER BY Ano)) * 100.0
        / NULLIF(LAG(Receita) OVER (ORDER BY Ano), 0)
    AS DECIMAL(5,2))                            AS CrescimentoPercentual
FROM ReceitaPorAno
ORDER BY Ano;