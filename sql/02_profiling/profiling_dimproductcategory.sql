-- =====================================================
-- PROFILING: DimProductCategory
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

--Visão Geral
SELECT COUNT(*) AS TotalLinhas FROM DimProductCategory;

--Contagem de Nulos
SELECT
    SUM(CASE WHEN CategoryName IS NULL THEN 1 ELSE 0 END) AS Nulos_CategoryName
FROM DimProductCategory;

-- Avaliação da tabela
SELECT ProductCategoryKey, CategoryName, LEN(CategoryName) AS Tamanho
FROM DimProductCategory
ORDER BY ProductCategoryKey;

--Procura de 'órfãos'
SELECT DISTINCT ps.ProductCategoryKey
FROM DimProductSubcategory ps
LEFT JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
WHERE pc.ProductCategoryKey IS NULL;