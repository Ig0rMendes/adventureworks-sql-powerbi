-- =====================================================================
-- ANÁLISE — Página 3: Performance por Território
-- Pergunta de negócio: Onde o negócio está crescendo ou estagnando?
-- Alimenta: mapa de receita por país/região, comparação de
-- crescimento entre territórios, e tabela detalhada por região.
-- =====================================================================


-- =====================================================================
-- 1. RECEITA POR TERRITÓRIO (visão geral — alimenta o mapa)
-- =====================================================================
SELECT
    t.Continent,
    t.Country,
    t.Region,
    SUM(f.OrderQuantity)                                AS QuantidadeVendida,
    SUM(f.OrderQuantity * p.ProductPrice)               AS ReceitaTotal,
    COUNT(DISTINCT f.OrderNumber)                       AS TotalPedidos,
    SUM(f.OrderQuantity * p.ProductPrice) 
        / NULLIF(COUNT(DISTINCT f.OrderNumber), 0)      AS TicketMedio
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimTerritory t ON f.SalesTerritoryKey = t.SalesTerritoryKey
GROUP BY t.Continent, t.Country, t.Region
ORDER BY ReceitaTotal DESC;


-- =====================================================================
-- 2. RECEITA POR CONTINENTE (visão agregada, mais macro)
-- =====================================================================
SELECT
    t.Continent,
    SUM(f.OrderQuantity)                                AS QuantidadeVendida,
    SUM(f.OrderQuantity * p.ProductPrice)               AS ReceitaTotal,
    CAST(
        SUM(f.OrderQuantity * p.ProductPrice) * 100.0
        / SUM(SUM(f.OrderQuantity * p.ProductPrice)) OVER()
    AS DECIMAL(5,2))                                    AS ParticipacaoPercentual
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimTerritory t ON f.SalesTerritoryKey = t.SalesTerritoryKey
GROUP BY t.Continent
ORDER BY ReceitaTotal DESC;


-- =====================================================================
-- 3. CRESCIMENTO ANO A ANO POR TERRITÓRIO
-- Objetivo: identificar territórios em expansão vs. estagnados —
-- pergunta mais estratégica do que apenas "quem vende mais".
-- Usa a função de janela LAG() para comparar com o ano anterior,
-- dentro de cada território (PARTITION BY Region).
-- =====================================================================
WITH ReceitaPorTerritorioAno AS (
    SELECT
        t.Region,
        t.Country,
        YEAR(f.OrderDate)                              AS Ano,
        SUM(f.OrderQuantity * p.ProductPrice)          AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    JOIN DimTerritory t ON f.SalesTerritoryKey = t.SalesTerritoryKey
    GROUP BY t.Region, t.Country, YEAR(f.OrderDate)
)
SELECT
    Region,
    Country,
    Ano,
    Receita,
    LAG(Receita) OVER (PARTITION BY Region, Country ORDER BY Ano)   AS ReceitaAnoAnterior,
    CAST(
        (Receita - LAG(Receita) OVER (PARTITION BY Region, Country ORDER BY Ano)) * 100.0
        / NULLIF(LAG(Receita) OVER (PARTITION BY Region, Country ORDER BY Ano), 0)
    AS DECIMAL(5,2))                                    AS CrescimentoPercentual
FROM ReceitaPorTerritorioAno
ORDER BY Region, Country, Ano;


-- =====================================================================
-- 4. RANKING DE TERRITÓRIOS POR CRESCIMENTO NO ÚLTIMO ANO COMPLETO
-- Objetivo: destacar quem mais cresceu (ou mais caiu) na comparação
-- do último ano disponível contra o anterior — resumo direto pra um
-- card/ranking de "destaques" na página.
-- =====================================================================
WITH ReceitaPorTerritorioAno AS (
    SELECT
        t.Region,
        YEAR(f.OrderDate)                              				AS Ano,
        SUM(f.OrderQuantity * p.ProductPrice)          				AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    JOIN DimTerritory t ON f.SalesTerritoryKey = t.SalesTerritoryKey
    GROUP BY t.Region, YEAR(f.OrderDate)
),
ComCrescimento AS (
    SELECT
        Region,
        Ano,
        Receita,
        LAG(Receita) OVER (PARTITION BY Region ORDER BY Ano)        AS ReceitaAnoAnterior
    FROM ReceitaPorTerritorioAno
)
SELECT
    Region,
    Ano,
    Receita,
    ReceitaAnoAnterior,
    CAST(
        (Receita - ReceitaAnoAnterior) * 100.0 / NULLIF(ReceitaAnoAnterior, 0)
    AS DECIMAL(5,2))                                                 AS CrescimentoPercentual
FROM ComCrescimento
WHERE Ano = (SELECT MAX(Ano) FROM ReceitaPorTerritorioAno)
  AND ReceitaAnoAnterior IS NOT NULL
ORDER BY CrescimentoPercentual DESC;


-- =====================================================================
-- 5. TAXA DE DEVOLUÇÃO POR TERRITÓRIO
-- Mesma lógica de agregação separada que corrigimos no script anterior
-- (02_rentabilidade_produto.sql) — agrega FactSales e FactReturns
-- cada uma isoladamente antes de unir, evitando o efeito fan-out.
-- =====================================================================
WITH VendasPorTerritorio AS (
    SELECT SalesTerritoryKey, SUM(OrderQuantity) 		 AS QuantidadeVendida
    FROM FactSales
    GROUP BY SalesTerritoryKey
),
DevolucoesPorTerritorio AS (
    SELECT SalesTerritoryKey, SUM(ReturnQuantity) 		 AS QuantidadeDevolvida
    FROM FactReturns
    GROUP BY SalesTerritoryKey
)
SELECT
    t.Region,
    t.Country,
    v.QuantidadeVendida,
    ISNULL(d.QuantidadeDevolvida, 0)                     AS QuantidadeDevolvida,
    CAST(
        ISNULL(d.QuantidadeDevolvida, 0) * 100.0 / NULLIF(v.QuantidadeVendida, 0)
    AS DECIMAL(5,2))                                     AS TaxaDevolucaoPercentual
FROM VendasPorTerritorio v
JOIN DimTerritory t ON v.SalesTerritoryKey = t.SalesTerritoryKey
LEFT JOIN DevolucoesPorTerritorio d ON v.SalesTerritoryKey = d.SalesTerritoryKey
ORDER BY TaxaDevolucaoPercentual DESC;