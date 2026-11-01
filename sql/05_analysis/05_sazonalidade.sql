-- =====================================================================
-- ANÁLISE — Página 5: Sazonalidade e Tendência
-- Pergunta de negócio: Quando o negócio vende mais, e esse padrão se
-- repete de um ano para o outro?
-- Alimenta: linhas sobrepostas de receita mensal por ano, heatmap
-- mês x ano, índice sazonal e taxa de devolução ao longo do tempo.
--
-- LIMITAÇÕES DO DATASET (valem para todo o script):
-- 1) As vendas vão de 01/01/2020 a 30/06/2022. De julho a dezembro só
--    existem 2020 e 2021; 2022 aparece como NULL nesses meses (e não
--    como zero, que seria um dado falso de "venda nula").
-- 2) Só há DOIS anos completos. Com tão pouca história, não dá para
--    separar totalmente sazonalidade de tendência de crescimento. Por
--    isso o script traz o índice sazonal (queries 3 e 5) E o
--    crescimento contra o mesmo mês do ano anterior (query 4), que é
--    imune à sazonalidade.
-- 3) "Ano completo" = qualquer ano anterior ao último ano do dataset.
-- =====================================================================


-- =====================================================================
-- 1. RECEITA MENSAL COM UM ANO POR COLUNA
-- Formato "largo": uma linha por mês, uma coluna por ano. É a base
-- direta das linhas sobrepostas e do heatmap mês x ano.
-- Receita2022 é NULL de julho a dezembro porque não há dados.
-- =====================================================================
WITH ReceitaMensal AS (
    SELECT
        YEAR(f.OrderDate)                         AS Ano,
        MONTH(f.OrderDate)                        AS Mes,
        SUM(f.OrderQuantity * p.ProductPrice)     AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY YEAR(f.OrderDate), MONTH(f.OrderDate)
)
SELECT
    Mes,
    DATENAME(MONTH, DATEFROMPARTS(2000, Mes, 1))  AS NomeMes,
    SUM(CASE WHEN Ano = 2020 THEN Receita END)    AS Receita2020,
    SUM(CASE WHEN Ano = 2021 THEN Receita END)    AS Receita2021,
    SUM(CASE WHEN Ano = 2022 THEN Receita END)    AS Receita2022
FROM ReceitaMensal
GROUP BY Mes
ORDER BY Mes;


-- =====================================================================
-- 2. RECEITA POR TRIMESTRE
-- MesesComVenda deixa explícito quando um trimestre está incompleto.
-- (Aqui o 3º e o 4º trimestres de 2022 simplesmente não existem.)
-- =====================================================================
SELECT
    YEAR(f.OrderDate)                              AS Ano,
    DATEPART(QUARTER, f.OrderDate)                 AS Trimestre,
    COUNT(DISTINCT MONTH(f.OrderDate))             AS MesesComVenda,
    SUM(f.OrderQuantity * p.ProductPrice)          AS Receita,
    SUM(f.OrderQuantity)                           AS UnidadesVendidas
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY YEAR(f.OrderDate), DATEPART(QUARTER, f.OrderDate)
ORDER BY Ano, Trimestre;


-- =====================================================================
-- 3. ÍNDICE SAZONAL GERAL (apenas anos completos)
-- ATENÇÃO — RESULTADO NÃO CONCLUSIVO NESTE DATASET: em 01/07/2021
-- duas categorias novas (Accessories e Clothing) passaram a vender, o
-- que quebrou o nível da receita no meio de 2021. Os dois anos têm
-- perfis opostos (2020 forte no 1º semestre; 2021 forte no 2º), então
-- o índice médio mistura efeito de lançamento com sazonalidade. Não
-- usar como "sazonalidade geral"; ver queries 7, 8 e 9.
-- Para cada ano completo, divide a receita de cada mês pela média
-- mensal daquele mesmo ano: 1,00 = mês na média; 1,20 = 20% acima;
-- 0,80 = 20% abaixo. Normalizar por ano remove o efeito do crescimento
-- entre um ano e outro. Depois, tira-se a média dos anos.
-- IndiceMin e IndiceMax mostram os dois anos separados: se estiverem
-- próximos, o padrão se repete e a sazonalidade é mais confiável; se
-- estiverem distantes, o "padrão" pode ser coincidência.
-- =====================================================================
WITH ReceitaMensal AS (
    SELECT
        YEAR(f.OrderDate)                         AS Ano,
        MONTH(f.OrderDate)                        AS Mes,
        SUM(f.OrderQuantity * p.ProductPrice)     AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    WHERE YEAR(f.OrderDate) < (SELECT YEAR(MAX(OrderDate)) FROM FactSales)
    GROUP BY YEAR(f.OrderDate), MONTH(f.OrderDate)
),
IndicePorAno AS (
    SELECT
        Ano, Mes, Receita,
        Receita / AVG(Receita) OVER (PARTITION BY Ano)  AS Indice
    FROM ReceitaMensal
)
SELECT
    Mes,
    DATENAME(MONTH, DATEFROMPARTS(2000, Mes, 1))        AS NomeMes,
    CAST(AVG(Indice) AS DECIMAL(6,3))                   AS IndiceSazonal,
    CAST(MIN(Indice) AS DECIMAL(6,3))                   AS IndiceMin,
    CAST(MAX(Indice) AS DECIMAL(6,3))                   AS IndiceMax
FROM IndicePorAno
GROUP BY Mes
ORDER BY Mes;


-- =====================================================================
-- 4. CRESCIMENTO CONTRA O MESMO MÊS DO ANO ANTERIOR
-- Compara cada mês só com o mesmo mês do ano anterior, então a
-- sazonalidade não interfere. Mostra a TENDÊNCIA: o negócio está
-- crescendo, estável ou encolhendo, mês a mês?
-- Cobertura: 2021 vs 2020 (12 meses) e 2022 vs 2021 (janeiro a junho).
-- =====================================================================
WITH ReceitaMensal AS (
    SELECT
        YEAR(f.OrderDate)                         AS Ano,
        MONTH(f.OrderDate)                        AS Mes,
        SUM(f.OrderQuantity * p.ProductPrice)     AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY YEAR(f.OrderDate), MONTH(f.OrderDate)
)
SELECT
    Ano,
    Mes,
    Receita,
    LAG(Receita) OVER (PARTITION BY Mes ORDER BY Ano)   AS ReceitaMesmoMesAnoAnterior,
    CAST(
        (Receita - LAG(Receita) OVER (PARTITION BY Mes ORDER BY Ano)) * 100.0
        / NULLIF(LAG(Receita) OVER (PARTITION BY Mes ORDER BY Ano), 0)
    AS DECIMAL(7,2))                                    AS CrescimentoPercentual
FROM ReceitaMensal
ORDER BY Ano, Mes;


-- =====================================================================
-- 5a. DIAGNÓSTICO: MESES COM VENDA POR CATEGORIA E ANO
-- Rodar ANTES da 5b. Se uma categoria só começou a vender no meio de
-- um ano, o índice sazonal dela para esse ano não é confiável (o
-- "crescimento de zero a algo" seria lido como sazonalidade).
-- =====================================================================
SELECT
    pc.CategoryName,
    YEAR(f.OrderDate)                              AS Ano,
    COUNT(DISTINCT MONTH(f.OrderDate))             AS MesesComVenda,
    MIN(f.OrderDate)                               AS PrimeiraVenda
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
GROUP BY pc.CategoryName, YEAR(f.OrderDate)
ORDER BY pc.CategoryName, Ano;


-- =====================================================================
-- 5b. ÍNDICE SAZONAL POR CATEGORIA (apenas anos completos)
-- Mesma lógica da query 3, separada por categoria. Em um negócio de
-- bicicletas, é esperado que categorias diferentes tenham ritmos
-- diferentes — esta query testa essa hipótese com dados.
-- A média mensal usa só os meses com venda de cada categoria; se a
-- 5a mostrar categorias com meses faltantes, interpretar com cautela.
-- =====================================================================
WITH ReceitaMensalCategoria AS (
    SELECT
        pc.CategoryName,
        YEAR(f.OrderDate)                          AS Ano,
        MONTH(f.OrderDate)                         AS Mes,
        SUM(f.OrderQuantity * p.ProductPrice)      AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
    JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
    WHERE YEAR(f.OrderDate) < (SELECT YEAR(MAX(OrderDate)) FROM FactSales)
    GROUP BY pc.CategoryName, YEAR(f.OrderDate), MONTH(f.OrderDate)
),
IndicePorAno AS (
    SELECT
        CategoryName, Ano, Mes,
        Receita / AVG(Receita) OVER (PARTITION BY CategoryName, Ano)  AS Indice,
        COUNT(*) OVER (PARTITION BY CategoryName, Ano)                AS MesesNoAno
    FROM ReceitaMensalCategoria
)
SELECT
    CategoryName,
    Mes,
    CAST(AVG(Indice) AS DECIMAL(6,3))              AS IndiceSazonal,
    COUNT(*)                                       AS AnosConsiderados
FROM IndicePorAno
WHERE MesesNoAno = 12   -- ignora categoria-ano parcial (ex.: Accessories/Clothing em 2021)
GROUP BY CategoryName, Mes
ORDER BY CategoryName, Mes;


-- =====================================================================
-- 6a. DIAGNÓSTICO: PERÍODO COBERTO POR DEVOLUÇÕES
-- Confirma se FactReturns cobre o mesmo intervalo de FactSales.
-- =====================================================================
SELECT
    MIN(ReturnDate) AS PrimeiraDevolucao,
    MAX(ReturnDate) AS UltimaDevolucao
FROM FactReturns;


-- =====================================================================
-- 6b. TAXA DE DEVOLUÇÃO POR MÊS
-- Vendas e devoluções são agregadas SEPARADAMENTE por mês antes de
-- serem unidas (evita o efeito fan-out do script 02). FULL OUTER JOIN
-- de propósito: se existir mês com devolução e sem venda (ou o
-- contrário), ele aparece com NULL em vez de sumir silenciosamente.
-- Atenção: a devolução ocorre DEPOIS da venda, então a taxa mensal é
-- uma aproximação (devoluções do mês / vendas do mês), e não a taxa de
-- devolução das vendas daquele mês.
-- =====================================================================
WITH VendasMes AS (
    SELECT
        YEAR(OrderDate)       AS Ano,
        MONTH(OrderDate)      AS Mes,
        SUM(OrderQuantity)    AS UnidadesVendidas
    FROM FactSales
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
),
DevolucoesMes AS (
    SELECT
        YEAR(ReturnDate)      AS Ano,
        MONTH(ReturnDate)     AS Mes,
        SUM(ReturnQuantity)   AS UnidadesDevolvidas
    FROM FactReturns
    GROUP BY YEAR(ReturnDate), MONTH(ReturnDate)
)
SELECT
    COALESCE(v.Ano, d.Ano)                              AS Ano,
    COALESCE(v.Mes, d.Mes)                              AS Mes,
    v.UnidadesVendidas,
    ISNULL(d.UnidadesDevolvidas, 0)                     AS UnidadesDevolvidas,
    CAST(
        ISNULL(d.UnidadesDevolvidas, 0) * 100.0 / NULLIF(v.UnidadesVendidas, 0)
    AS DECIMAL(5,2))                                    AS TaxaDevolucaoPercentual
FROM VendasMes v
FULL OUTER JOIN DevolucoesMes d ON v.Ano = d.Ano AND v.Mes = d.Mes
ORDER BY Ano, Mes;


-- =====================================================================
-- 7. RECEITA MENSAL POR CATEGORIA E PARTICIPAÇÃO DAS CATEGORIAS NOVAS
-- A 5a mostrou que Accessories e Clothing só vendem a partir de
-- 01/07/2021 (e que Components não tem nenhuma venda). Esta query
-- separa a receita de cada categoria mês a mês e calcula quanto da
-- receita vem das duas categorias novas — é o que permite dizer quanto
-- do salto de 2021 é lançamento e quanto é crescimento de Bikes.
-- =====================================================================
WITH ReceitaMensalCategoria AS (
    SELECT
        pc.CategoryName,
        YEAR(f.OrderDate)                          AS Ano,
        MONTH(f.OrderDate)                         AS Mes,
        SUM(f.OrderQuantity * p.ProductPrice)      AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
    JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
    GROUP BY pc.CategoryName, YEAR(f.OrderDate), MONTH(f.OrderDate)
),
Pivotado AS (
    SELECT
        Ano,
        Mes,
        ISNULL(SUM(CASE WHEN CategoryName = 'Bikes'       THEN Receita END), 0) AS Bikes,
        ISNULL(SUM(CASE WHEN CategoryName = 'Accessories' THEN Receita END), 0) AS Accessories,
        ISNULL(SUM(CASE WHEN CategoryName = 'Clothing'    THEN Receita END), 0) AS Clothing
    FROM ReceitaMensalCategoria
    GROUP BY Ano, Mes
)
SELECT
    Ano,
    Mes,
    Bikes,
    Accessories,
    Clothing,
    Bikes + Accessories + Clothing                                   AS Total,
    CAST((Accessories + Clothing) * 100.0
         / NULLIF(Bikes + Accessories + Clothing, 0) AS DECIMAL(5,2)) AS PercentualCategoriasNovas
FROM Pivotado
ORDER BY Ano, Mes;


-- =====================================================================
-- 8. CRESCIMENTO CONTRA O MESMO MÊS DO ANO ANTERIOR — SÓ BIKES
-- Bikes é a única categoria que vende desde 01/01/2020, então é a
-- única em que a comparação ano contra ano é "igual contra igual".
-- Mostra o crescimento real do negócio-base, sem o efeito do
-- lançamento das outras categorias.
-- =====================================================================
WITH ReceitaMensalBikes AS (
    SELECT
        YEAR(f.OrderDate)                          AS Ano,
        MONTH(f.OrderDate)                         AS Mes,
        SUM(f.OrderQuantity * p.ProductPrice)      AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    JOIN DimProductSubcategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
    JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
    WHERE pc.CategoryName = 'Bikes'
    GROUP BY YEAR(f.OrderDate), MONTH(f.OrderDate)
)
SELECT
    Ano,
    Mes,
    Receita,
    LAG(Receita) OVER (PARTITION BY Mes ORDER BY Ano)   AS ReceitaMesmoMesAnoAnterior,
    CAST(
        (Receita - LAG(Receita) OVER (PARTITION BY Mes ORDER BY Ano)) * 100.0
        / NULLIF(LAG(Receita) OVER (PARTITION BY Mes ORDER BY Ano), 0)
    AS DECIMAL(7,2))                                    AS CrescimentoPercentual
FROM ReceitaMensalBikes
ORDER BY Ano, Mes;


-- =====================================================================
-- 9. VARIAÇÃO CONTRA O MÊS ANTERIOR (receita total)
-- Mostra, mês a mês, onde há picos e quedas em relação ao mês
-- imediatamente anterior. Útil para checar se dezembro se destaca em
-- relação a novembro e ao janeiro seguinte, nos dois anos em que há
-- dezembro disponível.
-- =====================================================================
WITH ReceitaMensal AS (
    SELECT
        YEAR(f.OrderDate)                          AS Ano,
        MONTH(f.OrderDate)                         AS Mes,
        SUM(f.OrderQuantity * p.ProductPrice)      AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY YEAR(f.OrderDate), MONTH(f.OrderDate)
)
SELECT
    Ano,
    Mes,
    Receita,
    CAST(
        (Receita - LAG(Receita) OVER (ORDER BY Ano, Mes)) * 100.0
        / NULLIF(LAG(Receita) OVER (ORDER BY Ano, Mes), 0)
    AS DECIMAL(7,2))                                    AS VariacaoVsMesAnteriorPercentual
FROM ReceitaMensal
ORDER BY Ano, Mes;