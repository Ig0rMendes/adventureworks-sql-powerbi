-- =====================================================
-- CLEANING: dimcostumer
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

-- Investigações aprofundadas de incongruÊncias:
SELECT COUNT(*) FROM DimCustomer WHERE Prefix = ''; --Prefixo em branco
SELECT * FROM DimCustomer WHERE BirthDate = (SELECT MIN(BirthDate) FROM DimCustomer); -- investigação de data muito antiga
SELECT DATEPART(YEAR, BirthDate) AS AnoNascimento, COUNT(*) 
FROM DimCustomer 
GROUP BY DATEPART(YEAR, BirthDate) 
ORDER BY AnoNascimento;
--Existem vários clientes mais velhos. Sendo assim, não há porque excluir clientes antigos

-- Decisões tomadas:
UPDATE DimCustomer SET Gender = NULL WHERE Gender = 'NA'; 
-- Retiradas de NULL da coluna

UPDATE DimCustomer 
SET Prefix = NULL 
WHERE Prefix = ' ' OR LTRIM(RTRIM(Prefix)) = '';
-- Retiradas de NULL da coluna
