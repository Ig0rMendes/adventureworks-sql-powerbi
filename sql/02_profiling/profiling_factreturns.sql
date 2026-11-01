-- =====================================================
-- PROFILING: FactReturns
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

-- Visão Geral
SELECT COUNT(*) AS TotalLinhas FROM FactReturns;
SELECT MIN(ReturnDate) AS DataInicial, MAX(ReturnDate) AS DataFinal FROM FactReturns;

--Identificação de Nulos
SELECT
    SUM(CASE WHEN ReturnDate IS NULL THEN 1 ELSE 0 END) AS Nulos_ReturnDate,
    SUM(CASE WHEN ProductKey IS NULL THEN 1 ELSE 0 END) AS Nulos_ProductKey,
    SUM(CASE WHEN SalesTerritoryKey IS NULL THEN 1 ELSE 0 END) AS Nulos_Territory,
    SUM(CASE WHEN ReturnQuantity IS NULL THEN 1 ELSE 0 END) AS Nulos_Quantity
FROM FactReturns;

--Regra de negócio: Quantidade devolvida válida
SELECT COUNT(*) FROM FactReturns WHERE ReturnQuantity <= 0;

--Órfãos
SELECT COUNT(*) FROM FactReturns r
LEFT JOIN DimProduct p ON r.ProductKey = p.ProductKey
WHERE p.ProductKey IS NULL;

SELECT COUNT(*) FROM FactReturns r
LEFT JOIN DimTerritory t ON r.SalesTerritoryKey = t.SalesTerritoryKey
WHERE t.SalesTerritoryKey IS NULL;

--Erros de lançamento de vendas
SELECT OrderNumber, ProductKey, COUNT(*) AS Qtd
FROM FactSales
GROUP BY OrderNumber, ProductKey
HAVING COUNT(*) > 1;

--Identificação de outliers (Método IQR)
WITH Quartis AS (
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ReturnQuantity) OVER() AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ReturnQuantity) OVER() AS Q3
    FROM FactReturns
),
Limites AS (
    SELECT DISTINCT Q1, Q3, 
        Q1 - 1.5 * (Q3 - Q1) AS LimiteInferior,
        Q3 + 1.5 * (Q3 - Q1) AS LimiteSuperior
    FROM Quartis
)
SELECT r.*
FROM FactReturns r, Limites l
WHERE r.ReturnQuantity < l.LimiteInferior OR r.ReturnQuantity > l.LimiteSuperior;
--Foram detectados os valores em que se devolveu mais de um produto por vez. Devido ao
--grande voluam de devoluções unitárias, devoluções >1 foram interpretadas como outliers
--conforme observado na função abaixo:
SELECT ReturnQuantity, COUNT(*) AS Qtd
FROM FactReturns
GROUP BY ReturnQuantity
ORDER BY ReturnQuantity;
--a grande maioria dos dados são de devoluções únicas

--Devolução sem venda correspondente
SELECT DISTINCT r.ProductKey, r.SalesTerritoryKey
FROM FactReturns r
LEFT JOIN FactSales s 
    ON r.ProductKey = s.ProductKey 
    AND r.SalesTerritoryKey = s.SalesTerritoryKey
WHERE s.ProductKey IS NULL;

--Devolução maior que o total vendido
SELECT r.ProductKey, r.SalesTerritoryKey, 
    SUM(r.ReturnQuantity) AS TotalDevolvido
FROM FactReturns r
GROUP BY r.ProductKey, r.SalesTerritoryKey
HAVING SUM(r.ReturnQuantity) > (
    SELECT ISNULL(SUM(s.OrderQuantity), 0)
    FROM FactSales s
    WHERE s.ProductKey = r.ProductKey AND s.SalesTerritoryKey = r.SalesTerritoryKey
);
