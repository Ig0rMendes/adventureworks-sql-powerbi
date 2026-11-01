-- =====================================================
-- PROFILING: FactSales
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

-- Visão Geral
SELECT COUNT(*) AS TotalLinhas FROM FactSales;
SELECT MIN(OrderDate) AS DataInicial, MAX(OrderDate) AS DataFinal FROM FactSales;

--Identificação de Nulos
SELECT
    SUM(CASE WHEN OrderDate IS NULL THEN 1 ELSE 0 END) AS Nulos_OrderDate,
    SUM(CASE WHEN StockDate IS NULL THEN 1 ELSE 0 END) AS Nulos_StockDate,
    SUM(CASE WHEN ProductKey IS NULL THEN 1 ELSE 0 END) AS Nulos_ProductKey,
    SUM(CASE WHEN CustomerKey IS NULL THEN 1 ELSE 0 END) AS Nulos_CustomerKey,
    SUM(CASE WHEN SalesTerritoryKey IS NULL THEN 1 ELSE 0 END) AS Nulos_Territory,
    SUM(CASE WHEN OrderQuantity IS NULL THEN 1 ELSE 0 END) AS Nulos_Quantity
FROM FactSales;

--Regra de negócio: Coerência entre Datas
SELECT COUNT(*) FROM FactSales WHERE OrderQuantity <= 0;

--Regra de negócio: Coerência entre datas
SELECT COUNT(*) FROM FactSales WHERE OrderDate < StockDate;

--Duplicatas de pedidos
SELECT OrderNumber, OrderLineItem, COUNT(*)
FROM FactSales
GROUP BY OrderNumber, OrderLineItem
HAVING COUNT(*) > 1;

--Órfãos
SELECT COUNT(*) FROM FactSales f
LEFT JOIN DimProduct p ON f.ProductKey = p.ProductKey
WHERE p.ProductKey IS NULL;

SELECT COUNT(*) FROM FactSales f
LEFT JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
WHERE c.CustomerKey IS NULL;

SELECT COUNT(*) FROM FactSales f
LEFT JOIN DimTerritory t ON f.SalesTerritoryKey = t.SalesTerritoryKey
WHERE t.SalesTerritoryKey IS NULL;

--Erros de lançamento de vendas
SELECT OrderNumber, ProductKey, COUNT(*) AS Qtd
FROM FactSales
GROUP BY OrderNumber, ProductKey
HAVING COUNT(*) > 1;

--Identificação de outliers (Método IQR)
WITH Quartis AS (
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY OrderQuantity) OVER() AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY OrderQuantity) OVER() AS Q3
    FROM FactSales
),
Limites AS (
    SELECT DISTINCT 
        Q1, Q3, (Q3 - Q1) AS IQR,
        Q1 - 1.5 * (Q3 - Q1) AS LimiteInferior,
        Q3 + 1.5 * (Q3 - Q1) AS LimiteSuperior
    FROM Quartis
)
SELECT f.*
FROM FactSales f, Limites l
WHERE f.OrderQuantity < l.LimiteInferior OR f.OrderQuantity > l.LimiteSuperior;

--Análise de outlier de receita por linha de pedido
SELECT TOP 20 
    f.OrderNumber, f.OrderQuantity, p.ProductName, p.ProductPrice,
    (f.OrderQuantity * p.ProductPrice) AS ReceitaLinha
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
ORDER BY ReceitaLinha DESC;

--Análise de outlier por volume de vendas por dia
SELECT OrderDate, COUNT(*) AS QtdPedidosNoDia, SUM(OrderQuantity) AS UnidadesVendidasNoDia
FROM FactSales
GROUP BY OrderDate
ORDER BY UnidadesVendidasNoDia DESC;
