-- =====================================================
-- PROFILING: DimDate
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

--Visão Geral
SELECT COUNT(*) AS TotalLinhas FROM DimDate;

--Intervalo coberto
SELECT MIN([Date]) AS DataInicial, MAX([Date]) AS DataFinal
FROM DimDate;

--Detecção de 'Buracos' na tabela 
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
