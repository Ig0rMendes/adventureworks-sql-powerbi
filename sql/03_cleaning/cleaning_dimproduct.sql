-- =====================================================
-- CLEANING:  dimproduct
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================
--Convertendo '0' em NULL
UPDATE DimProduct
SET ProductSize = NULL
FROM DimProduct p
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
WHERE p.ProductSize = '0' 
AND pc.CategoryName IN ('Components', 'Accessories');

--QUal roupa apresenta tamanho '0'?
SELECT p.ProductKey, p.ProductName, p.ProductSKU, p.ProductColor, p.ProductSize, p.ProductStyle
FROM DimProduct p
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
WHERE p.ProductSize = '0' AND pc.CategoryName = 'Clothing';
--Trata-se de um boné de tamanho único.
--Sendo assim, vamos converte-lo para NULL
UPDATE DimProduct
SET ProductSize = NULL
WHERE ProductSize = '0';

--Investigando tamanhos '0' em Product Style
SELECT p.ProductKey, p.ProductName, p.ProductSKU, pc.CategoryName
FROM DimProduct p
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
WHERE p.ProductStyle = '0'
ORDER BY pc.CategoryName, p.ProductName;
--São acessórios sem numeção específica
-- Conversão para NULL
UPDATE DimProduct
SET ProductStyle = NULL
WHERE ProductStyle = '0';

