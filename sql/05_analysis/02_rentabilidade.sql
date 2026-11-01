-- =====================================================================
-- ANÁLISE — Página 2: Rentabilidade de Produto
-- Pergunta de negócio: O que vale mais a pena vender?
-- Alimenta: gráfico de receita por categoria/subcategoria, scatter de
-- volume x margem, e rankings de produtos (top receita / top margem).
-- =====================================================================


-- =====================================================================
-- 1. RECEITA E MARGEM POR CATEGORIA
-- Visão de alto nível: as 4 categorias do catálogo (Bikes, Components,
-- Clothing, Accessories), comparando volume, receita e margem %.
-- =====================================================================
SELECT
    pc.CategoryName,
    SUM(f.OrderQuantity)                                            AS QuantidadeVendida,
    SUM(f.OrderQuantity * p.ProductPrice)                            AS ReceitaTotal,
    SUM(f.OrderQuantity * (p.ProductPrice - p.ProductCost))          AS MargemTotal,
    CAST(
        SUM(f.OrderQuantity * (p.ProductPrice - p.ProductCost)) * 100.0
        / NULLIF(SUM(f.OrderQuantity * p.ProductPrice), 0)
    AS DECIMAL(5,2))                                                 AS MargemPercentual
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
GROUP BY pc.CategoryName
ORDER BY ReceitaTotal DESC;


-- =====================================================================
-- 2. RECEITA E MARGEM POR SUBCATEGORIA
-- Mesmo cálculo, um nível mais detalhado — útil para identificar
-- qual subcategoria dentro de uma categoria "puxa" o resultado.
-- =====================================================================
SELECT
    pc.CategoryName,
    ps.SubcategoryName,
    SUM(f.OrderQuantity)                                            AS QuantidadeVendida,
    SUM(f.OrderQuantity * p.ProductPrice)                            AS ReceitaTotal,
    CAST(
        SUM(f.OrderQuantity * (p.ProductPrice - p.ProductCost)) * 100.0
        / NULLIF(SUM(f.OrderQuantity * p.ProductPrice), 0)
    AS DECIMAL(5,2))                                                 AS MargemPercentual
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
GROUP BY pc.CategoryName, ps.SubcategoryName
ORDER BY ReceitaTotal DESC;


-- =====================================================================
-- 3. VOLUME x MARGEM POR PRODUTO (alimenta o gráfico de dispersão)
-- Objetivo: revelar produtos de alto volume/baixa margem vs. baixo
-- volume/alta margem — o insight central dessa página.
-- =====================================================================
SELECT
    p.ProductKey,
    p.ProductName,
    pc.CategoryName,
    SUM(f.OrderQuantity)                                            AS QuantidadeVendida,
    SUM(f.OrderQuantity * p.ProductPrice)                            AS ReceitaTotal,
    CAST(
        (p.ProductPrice - p.ProductCost) * 100.0 / NULLIF(p.ProductPrice, 0)
    AS DECIMAL(5,2))                                                 AS MargemPercentualUnitaria
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
GROUP BY p.ProductKey, p.ProductName, pc.CategoryName, p.ProductPrice, p.ProductCost
ORDER BY QuantidadeVendida DESC;


-- =====================================================================
-- 4. TOP 10 PRODUTOS POR RECEITA
-- =====================================================================
SELECT TOP 10
    p.ProductName,
    pc.CategoryName,
    SUM(f.OrderQuantity)                                AS QuantidadeVendida,
    SUM(f.OrderQuantity * p.ProductPrice)                AS ReceitaTotal
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
GROUP BY p.ProductName, pc.CategoryName
ORDER BY ReceitaTotal DESC;


-- =====================================================================
-- 5. TOP 10 PRODUTOS POR MARGEM PERCENTUAL
-- ATENÇÃO (após rodar): a margem % tem muitos empates (query 8: só 14
-- valores distintos entre os produtos vendidos), então este top 10 é
-- arbitrário entre os empatados. Já o ranking por margem TOTAL (query 7)
-- traz os mesmos 10 produtos do top 10 por receita (query 4).
-- =====================================================================
SELECT TOP 10
    p.ProductName,
    pc.CategoryName,
    p.ProductCost,
    p.ProductPrice,
    CAST(
        (p.ProductPrice - p.ProductCost) * 100.0 / NULLIF(p.ProductPrice, 0)
    AS DECIMAL(5,2))                                     AS MargemPercentual
FROM DimProduct p
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
-- Considera apenas produtos efetivamente vendidos, para não trazer
-- itens de catálogo sem movimento nenhum
WHERE p.ProductKey IN (SELECT DISTINCT ProductKey FROM FactSales)
ORDER BY MargemPercentual DESC;


-- =====================================================================
-- 6. PRODUTOS COM MAIOR TAXA DE DEVOLUÇÃO
-- Cruza FactReturns com FactSales por produto, para identificar itens
-- com problema de qualidade/satisfação relativo ao volume vendido.
--
-- ATENÇÃO (erro corrigido): juntar FactSales e FactReturns diretamente
-- pelo ProductKey causa um efeito "fan-out" — cada linha de venda é
-- combinada com cada linha de devolução daquele mesmo produto,
-- multiplicando (inflando) os dois lados do SUM() e produzindo taxas
-- de devolução impossíveis (ex: acima de 100%). A correção agrega
-- cada tabela fato SEPARADAMENTE antes de unir os totais já prontos,
-- garantindo uma relação 1-para-1 (ou 1-para-0) por produto.
-- =====================================================================
WITH VendasPorProduto AS (
    SELECT ProductKey, SUM(OrderQuantity) AS QuantidadeVendida
    FROM FactSales
    GROUP BY ProductKey
),
DevolucoesPorProduto AS (
    SELECT ProductKey, SUM(ReturnQuantity) AS QuantidadeDevolvida
    FROM FactReturns
    GROUP BY ProductKey
)
SELECT
    p.ProductName,
    pc.CategoryName,
    v.QuantidadeVendida,
    ISNULL(d.QuantidadeDevolvida, 0)                                AS QuantidadeDevolvida,
    CAST(
        ISNULL(d.QuantidadeDevolvida, 0) * 100.0 / NULLIF(v.QuantidadeVendida, 0)
    AS DECIMAL(5,2))                                                AS TaxaDevolucaoPercentual
FROM VendasPorProduto v
JOIN DimProduct p ON v.ProductKey = p.ProductKey
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
LEFT JOIN DevolucoesPorProduto d ON v.ProductKey = d.ProductKey
ORDER BY TaxaDevolucaoPercentual DESC;


-- =====================================================================
-- 7. TOP 10 PRODUTOS POR MARGEM TOTAL (lucro bruto)
-- Alternativa ao ranking por margem % (query 5): a margem % tem muitos
-- empates entre produtos (várias subcategorias com exatamente 62,60%),
-- o que torna um "top 10" por esse critério arbitrário. A margem total
-- (receita - custo) não sofre desse problema e responde diretamente se
-- os produtos mais vendidos são também os que mais geram lucro.
-- =====================================================================
SELECT TOP 10
    p.ProductName,
    pc.CategoryName,
    SUM(f.OrderQuantity)                                                AS QuantidadeVendida,
    SUM(f.OrderQuantity * p.ProductPrice)                               AS ReceitaTotal,
    SUM(f.OrderQuantity * (p.ProductPrice - p.ProductCost))             AS MargemTotal,
    CAST(
        SUM(f.OrderQuantity * (p.ProductPrice - p.ProductCost)) * 100.0
        / NULLIF(SUM(f.OrderQuantity * p.ProductPrice), 0)
    AS DECIMAL(5,2))                                                    AS MargemPercentual
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
GROUP BY p.ProductName, pc.CategoryName
ORDER BY MargemTotal DESC;


-- =====================================================================
-- 8. DIAGNÓSTICO: DISTRIBUIÇÃO DA MARGEM % UNITÁRIA ENTRE PRODUTOS
-- Na análise por subcategoria, 10 de 17 subcategorias apareceram com
-- margem exatamente igual a 62,60%. Esta query conta quantos produtos
-- vendidos têm cada valor de margem unitária. Se poucos valores
-- concentrarem muitos produtos, o custo provavelmente é definido como
-- proporção fixa do preço no dataset, e as diferenças de margem entre
-- essas categorias podem refletir a construção dos dados, e não o
-- negócio. Registrar como limitação, se confirmado.
-- =====================================================================
SELECT
    CAST((p.ProductPrice - p.ProductCost) * 100.0 / NULLIF(p.ProductPrice, 0) AS DECIMAL(5,2)) AS MargemPercentualUnitaria,
    COUNT(*)                                                                                   AS QtdProdutos
FROM DimProduct p
WHERE p.ProductKey IN (SELECT DISTINCT ProductKey FROM FactSales)
GROUP BY CAST((p.ProductPrice - p.ProductCost) * 100.0 / NULLIF(p.ProductPrice, 0) AS DECIMAL(5,2))
ORDER BY QtdProdutos DESC;


-- =====================================================================
-- 9. TAXA DE DEVOLUÇÃO POR CATEGORIA
-- Gabarito do gráfico de barras da Página 2. Vendas e devoluções são
-- agregadas SEPARADAMENTE por categoria antes de serem unidas (evita o
-- efeito fan-out da versão original da query 6).
-- =====================================================================
WITH VendasPorCategoria AS (
    SELECT pc.CategoryName, SUM(f.OrderQuantity) AS QuantidadeVendida
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
    JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
    GROUP BY pc.CategoryName
),
DevolucoesPorCategoria AS (
    SELECT pc.CategoryName, SUM(r.ReturnQuantity) AS QuantidadeDevolvida
    FROM FactReturns r
    JOIN DimProduct p ON r.ProductKey = p.ProductKey
    JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
    JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
    GROUP BY pc.CategoryName
)
SELECT
    v.CategoryName,
    v.QuantidadeVendida,
    ISNULL(d.QuantidadeDevolvida, 0)                                AS QuantidadeDevolvida,
    CAST(
        ISNULL(d.QuantidadeDevolvida, 0) * 100.0 / NULLIF(v.QuantidadeVendida, 0)
    AS DECIMAL(5,2))                                                AS TaxaDevolucaoPercentual
FROM VendasPorCategoria v
LEFT JOIN DevolucoesPorCategoria d ON v.CategoryName = d.CategoryName
ORDER BY TaxaDevolucaoPercentual DESC;