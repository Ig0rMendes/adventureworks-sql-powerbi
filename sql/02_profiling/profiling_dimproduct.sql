-- =====================================================
-- PROFILING: DimProduct
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

--Total de linhas da tabela
SELECT COUNT(*) AS TotalLinhas FROM DimProduct;
--293 linhas

--Avaliação de nulos
SELECT
    SUM(CASE WHEN ProductSubcategoryKey IS NULL THEN 1 ELSE 0 END) AS Nulos_Subcategoria,
    SUM(CASE WHEN ProductSKU IS NULL THEN 1 ELSE 0 END) AS Nulos_SKU,
    SUM(CASE WHEN ProductName IS NULL THEN 1 ELSE 0 END) AS Nulos_Nome,
    SUM(CASE WHEN ModelName IS NULL THEN 1 ELSE 0 END) AS Nulos_Modelo,
    SUM(CASE WHEN ProductColor IS NULL THEN 1 ELSE 0 END) AS Nulos_Cor,
    SUM(CASE WHEN ProductSize IS NULL THEN 1 ELSE 0 END) AS Nulos_Tamanho,
    SUM(CASE WHEN ProductStyle IS NULL THEN 1 ELSE 0 END) AS Nulos_Estilo,
    SUM(CASE WHEN ProductCost IS NULL THEN 1 ELSE 0 END) AS Nulos_Custo,
    SUM(CASE WHEN ProductPrice IS NULL THEN 1 ELSE 0 END) AS Nulos_Preco
FROM DimProduct;
--Não há registros de nulos

--Cardinallidade das Colunas
SELECT ProductColor, COUNT(*) AS Qtd FROM DimProduct GROUP BY ProductColor ORDER BY Qtd DESC;
SELECT ProductSize, COUNT(*) AS Qtd FROM DimProduct GROUP BY ProductSize ORDER BY Qtd DESC;
SELECT ProductStyle, COUNT(*) AS Qtd FROM DimProduct GROUP BY ProductStyle ORDER BY Qtd DESC;
--Presença de valores NA na coluna ProductColor
--Coluna ProductSize tem tamanho "0",84 registros, e possui números e letras na composição
--Coluna ProductStyle possui 84 rergistros de "0"

--Investigação de faixa de valores
SELECT 
    MIN(ProductCost) AS MenorCusto, 
    MAX(ProductCost) AS MaiorCusto,
    MIN(ProductPrice) AS MenorPreco, 
    MAX(ProductPrice) AS MaiorPreco,
    MIN((ProductPrice - ProductCost) / NULLIF(ProductPrice, 0)) AS MenorMargem_Percentual,
    MAX((ProductPrice - ProductCost) / NULLIF(ProductPrice, 0)) AS MaiorMargem_Percentual
FROM DimProduct;
--Valores adequados

-- Investigação de venda com prejuízo
SELECT COUNT(*) FROM DimProduct WHERE ProductCost > ProductPrice;
--Não houve

--Duplicidade por SKU
SELECT ProductSKU, COUNT(*) FROM DimProduct GROUP BY ProductSKU HAVING COUNT(*) > 1;
--Não houve

-- Investigação de '0' em tamanhos de equipamentos
SELECT pc.CategoryName, COUNT(*) AS Qtd
FROM DimProduct p
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
WHERE p.ProductSize = '0'
GROUP BY pc.CategoryName
ORDER BY Qtd DESC;
-- FOi observado que a concentração de zeros são da categoria 'Components' e 'Acessories',
--dando a entender que se trata de produtos de tamanho não aplicável, logo, tamanho '0'

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

