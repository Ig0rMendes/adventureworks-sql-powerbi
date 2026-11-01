-- =====================================================
-- PROFILING: DimProductSubcategory
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

--Visão Geral
SELECT COUNT(*) AS TotalLinhas FROM DimProductSubcategory;

--Contagem de Nulos
SELECT
    SUM(CASE WHEN SubcategoryName IS NULL THEN 1 ELSE 0 END) AS Nulos_SubcategoryName,
    SUM(CASE WHEN ProductCategoryKey IS NULL THEN 1 ELSE 0 END) AS Nulos_ProductCategoryKey
FROM DimProductSubcategory;

--TEste de hierarquia
SELECT ps.ProductSubcategoryKey, ps.SubcategoryName, pc.CategoryName
FROM DimProductSubcategory ps
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
ORDER BY pc.CategoryName, ps.SubcategoryName;

--Duplicidade de nomes
SELECT ProductCategoryKey, SubcategoryName, COUNT(*)
FROM DimProductSubcategory
GROUP BY ProductCategoryKey, SubcategoryName
HAVING COUNT(*) > 1;

--Procura de 'órfãos'
SELECT DISTINCT p.ProductSubcategoryKey
FROM DimProduct p
LEFT JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
WHERE ps.ProductSubcategoryKey IS NULL;

--Formatação de texto
SELECT * FROM DimProductSubcategory 
WHERE SubcategoryName != TRIM(SubcategoryName);
