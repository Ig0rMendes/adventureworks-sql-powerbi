-- =====================================================
-- PROFILING: DImTerritory
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

--Visão geral
SELECT COUNT(*) AS TotalLinhas FROM DimTerritory;

--Acompanhamento de Nulos
SELECT
    SUM(CASE WHEN Region IS NULL THEN 1 ELSE 0 END) AS Nulos_Region,
    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS Nulos_Country,
    SUM(CASE WHEN Continent IS NULL THEN 1 ELSE 0 END) AS Nulos_Continent
FROM DimTerritory;

--Avaliação de dados (Tabela curta, da para ver de uma vez)
SELECT Region, Country, Continent FROM DimTerritory ORDER BY Continent, Country, Region;

--Investigação de formatação de valores
SELECT * FROM DimTerritory 
WHERE Region != TRIM(Region) 
   OR Country != TRIM(Country) 
   OR Continent != TRIM(Continent);

--Procura de 'órfãos'
SELECT DISTINCT f.SalesTerritoryKey
FROM FactSales f
LEFT JOIN DimTerritory t ON f.SalesTerritoryKey = t.SalesTerritoryKey
WHERE t.SalesTerritoryKey IS NULL;