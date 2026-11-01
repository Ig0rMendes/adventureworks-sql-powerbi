-- =====================================================================
-- VALIDAÇÃO DE INTEGRIDADE — Modelo AdventureWorksAnalysis
-- Objetivo: confirmar, a qualquer momento, que o modelo de dados segue
-- íntegro (sem órfãos de FK, sem buracos de calendário, sem duplicidade
-- e com volumetria condizente com o esperado).
-- Pode ser rodado como um "teste de regressão" após qualquer nova carga
-- ou alteração no banco.
-- Autor: Igor Mendes | Data: 10/10/2026
-- =====================================================================

-- =====================================================================
-- 1. VOLUMETRIA GERAL
-- Objetivo: ter um retrato rápido do tamanho de cada tabela, para
-- detectar qualquer variação inesperada (ex: linhas perdidas ou
-- duplicadas em uma nova carga).
-- =====================================================================
SELECT 'DimDate'               AS Tabela, COUNT(*) AS Linhas FROM DimDate
UNION ALL SELECT 'DimTerritory',            COUNT(*) FROM DimTerritory
UNION ALL SELECT 'DimProductCategory',      COUNT(*) FROM DimProductCategory
UNION ALL SELECT 'DimProductSubcategory',   COUNT(*) FROM DimProductSubcategory
UNION ALL SELECT 'DimProduct',              COUNT(*) FROM DimProduct
UNION ALL SELECT 'DimCustomer',             COUNT(*) FROM DimCustomer
UNION ALL SELECT 'FactSales',               COUNT(*) FROM FactSales
UNION ALL SELECT 'FactReturns',             COUNT(*) FROM FactReturns;


-- =====================================================================
-- 2. ÓRFÃOS DE CHAVE ESTRANGEIRA (FactSales → Dimensões)
-- Objetivo: confirmar que toda linha de venda referencia um produto,
-- cliente, território e data que realmente existem nas dimensões.
-- Resultado esperado: 0 em todas as consultas.
-- =====================================================================
SELECT COUNT(*) AS Orfaos_Sales_Product FROM FactSales f
LEFT JOIN DimProduct p ON f.ProductKey = p.ProductKey
WHERE p.ProductKey IS NULL;

SELECT COUNT(*) AS Orfaos_Sales_Customer FROM FactSales f
LEFT JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
WHERE c.CustomerKey IS NULL;

SELECT COUNT(*) AS Orfaos_Sales_Territory FROM FactSales f
LEFT JOIN DimTerritory t ON f.SalesTerritoryKey = t.SalesTerritoryKey
WHERE t.SalesTerritoryKey IS NULL;

SELECT COUNT(*) AS Orfaos_Sales_OrderDate FROM FactSales f
LEFT JOIN DimDate d ON f.OrderDate = d.[Date]
WHERE d.[Date] IS NULL;

-- =====================================================================
-- 3. ÓRFÃOS DE CHAVE ESTRANGEIRA (FactReturns → Dimensões)
-- Resultado esperado: 0 em todas as consultas.
-- =====================================================================
SELECT COUNT(*) AS Orfaos_Returns_Product FROM FactReturns r
LEFT JOIN DimProduct p ON r.ProductKey = p.ProductKey
WHERE p.ProductKey IS NULL;

SELECT COUNT(*) AS Orfaos_Returns_Territory FROM FactReturns r
LEFT JOIN DimTerritory t ON r.SalesTerritoryKey = t.SalesTerritoryKey
WHERE t.SalesTerritoryKey IS NULL;

SELECT COUNT(*) AS Orfaos_Returns_ReturnDate FROM FactReturns r
LEFT JOIN DimDate d ON r.ReturnDate = d.[Date]
WHERE d.[Date] IS NULL;

-- =====================================================================
-- 4. ÓRFÃOS DE CHAVE ESTRANGEIRA (dimensões hierárquicas)
-- Objetivo: confirmar que a hierarquia Categoria → Subcategoria →
-- Produto permanece íntegra.
-- Resultado esperado: 0 em todas as consultas.
-- =====================================================================
SELECT COUNT(*) AS Orfaos_Subcategory_Category FROM DimProductSubcategory ps
LEFT JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
WHERE pc.ProductCategoryKey IS NULL;

SELECT COUNT(*) AS Orfaos_Product_Subcategory FROM DimProduct p
LEFT JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
WHERE ps.ProductSubcategoryKey IS NULL;

-- =====================================================================
-- 5. DUPLICIDADE DE CHAVE PRIMÁRIA / CAMPOS ÚNICOS
-- Objetivo: confirmar ausência de duplicidade em chaves primárias e
-- em campos que deveriam ser únicos na prática (SKU, e-mail).
-- Resultado esperado: nenhuma linha retornada em todas as consultas.
-- =====================================================================
SELECT CustomerKey, COUNT(*) FROM DimCustomer
GROUP BY CustomerKey HAVING COUNT(*) > 1;

SELECT ProductSKU, COUNT(*) FROM DimProduct
GROUP BY ProductSKU HAVING COUNT(*) > 1;

SELECT EmailAddress, COUNT(*) FROM DimCustomer
WHERE EmailAddress IS NOT NULL
GROUP BY EmailAddress HAVING COUNT(*) > 1;

SELECT OrderNumber, OrderLineItem, COUNT(*) FROM FactSales
GROUP BY OrderNumber, OrderLineItem HAVING COUNT(*) > 1;


-- =====================================================================
-- 6. CALENDÁRIO (DimDate) — AUSÊNCIA DE BURACOS
-- Objetivo: garantir que não existe nenhum dia faltando entre a data
-- mínima e a máxima do calendário (pré-requisito para qualquer FK de
-- data nas tabelas fato).
-- Resultado esperado: nenhuma linha retornada.
-- =====================================================================
WITH Limites AS (
    SELECT MIN([Date]) AS DataInicial, MAX([Date]) AS DataFinal
    FROM DimDate
),
Sequencia AS (
    SELECT DataInicial AS DataEsperada, DataFinal
    FROM Limites
    UNION ALL
    SELECT DATEADD(DAY, 1, DataEsperada), DataFinal
    FROM Sequencia
    WHERE DataEsperada < DataFinal
)
SELECT s.DataEsperada
FROM Sequencia s
LEFT JOIN DimDate d ON s.DataEsperada = d.[Date]
WHERE d.[Date] IS NULL
OPTION (MAXRECURSION 0);


-- =====================================================================
-- 7. REGRAS DE NEGÓCIO (FactSales / FactReturns)
-- Objetivo: confirmar que as quantidades e datas continuam plausíveis.
-- Resultado esperado: 0 em todas as consultas.
-- =====================================================================
SELECT COUNT(*) AS Quantidade_Invalida_Sales FROM FactSales WHERE OrderQuantity <= 0;

SELECT COUNT(*) AS StockDate_Posterior_OrderDate FROM FactSales WHERE OrderDate < StockDate;

SELECT COUNT(*) AS Quantidade_Invalida_Returns FROM FactReturns WHERE ReturnQuantity <= 0;

SELECT COUNT(*) AS Produto_Vendido_Com_Prejuizo FROM DimProduct WHERE ProductCost > ProductPrice;


-- =====================================================================
-- 8. DEVOLUÇÃO SUPERIOR À VENDA (regra de negócio entre as duas fatos)
-- Objetivo: nenhuma combinação Produto/Território pode ter devolvido
-- mais unidades do que foi vendido.
-- Resultado esperado: nenhuma linha retornada.
-- =====================================================================
SELECT r.ProductKey, r.SalesTerritoryKey, SUM(r.ReturnQuantity) AS TotalDevolvido
FROM FactReturns r
GROUP BY r.ProductKey, r.SalesTerritoryKey
HAVING SUM(r.ReturnQuantity) > (
    SELECT ISNULL(SUM(s.OrderQuantity), 0)
    FROM FactSales s
    WHERE s.ProductKey = r.ProductKey AND s.SalesTerritoryKey = r.SalesTerritoryKey
);