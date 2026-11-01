-- =====================================================
-- PROFILING: DimCustomer
-- Autor: Igor Mendes | Data: 05/10/2026
-- =====================================================

--Visão geral: Número de referência para comparar após a limpeza, avaliando se algum dado se perdeu no caminho
SELECT COUNT (*) AS TotalLinhas FROM DimCustomer; 


--Avaliando nulos por coluna
SELECT
    SUM(CASE WHEN Prefix IS NULL THEN 1 ELSE 0 END) AS Nulos_Prefix,
    SUM(CASE WHEN FirstName IS NULL THEN 1 ELSE 0 END) AS Nulos_FirstName,
    SUM(CASE WHEN LastName IS NULL THEN 1 ELSE 0 END) AS Nulos_LastName,
    SUM(CASE WHEN BirthDate IS NULL THEN 1 ELSE 0 END) AS Nulos_BirthDate,
    SUM(CASE WHEN MaritalStatus IS NULL THEN 1 ELSE 0 END) AS Nulos_MaritalStatus,
    SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS Nulos_Gender,
    SUM(CASE WHEN EmailAddress IS NULL THEN 1 ELSE 0 END) AS Nulos_Email,
    SUM(CASE WHEN AnnualIncome IS NULL THEN 1 ELSE 0 END) AS Nulos_Income,
    SUM(CASE WHEN TotalChildren IS NULL THEN 1 ELSE 0 END) AS Nulos_TotalChildren,
    SUM(CASE WHEN EducationLevel IS NULL THEN 1 ELSE 0 END) AS Nulos_Education,
    SUM(CASE WHEN Occupation IS NULL THEN 1 ELSE 0 END) AS Nulos_Occupation,
    SUM(CASE WHEN HomeOwner IS NULL THEN 1 ELSE 0 END) AS Nulos_HomeOwner
FROM DimCustomer; 

--Avaliando consistÊncia de colunas categóricas (Ex: Estados Unidos, EUA, USA, América) o ideal é não ter diferença entre 
SELECT Gender, COUNT(*) AS Qtd FROM DimCustomer GROUP BY Gender ORDER BY Qtd DESC; 
SELECT MaritalStatus, COUNT(*) AS Qtd FROM DimCustomer GROUP BY MaritalStatus ORDER BY Qtd DESC;
SELECT EducationLevel, COUNT(*) AS Qtd FROM DimCustomer GROUP BY EducationLevel ORDER BY Qtd DESC;
SELECT Occupation, COUNT(*) AS Qtd FROM DimCustomer GROUP BY Occupation ORDER BY Qtd DESC;
SELECT HomeOwner, COUNT(*) AS Qtd FROM DimCustomer GROUP BY HomeOwner ORDER BY Qtd DESC;
SELECT Prefix, COUNT(*) AS Qtd FROM DimCustomer GROUP BY Prefix ORDER BY Qtd DESC; 
-- Comentários: Coluna Gender possui 130 valores listados como NA

--Avaliando faixa de valores para detecção de valores estranhos
SELECT 
    MIN(BirthDate) AS MenorData, MAX(BirthDate) AS MaiorData, -- Data do ano de 1910 detectada
    MIN(AnnualIncome) AS MenorRenda, MAX(AnnualIncome) AS MaiorRenda,
    MIN(TotalChildren) AS MinFilhos, MAX(TotalChildren) AS MaxFilhos
FROM DimCustomer;
-- Comentários: A menor data de nascimento detectada foi de 1910. Esse valor deve ser investigado

--Avaliando duplicidades de cadastros
SELECT EmailAddress, COUNT(*) AS Qtd
FROM DimCustomer
WHERE EmailAddress IS NOT NULL
GROUP BY EmailAddress
HAVING COUNT(*) > 1; 

--ConsistÊncia de colunas expecíficas
SELECT COUNT(*) FROM DimCustomer WHERE TotalChildren > 0 AND MaritalStatus IS NULL; --Informações do mesmo bloco de coleta, a consulta checa consistÊncia disso
SELECT COUNT(*) FROM DimCustomer 
WHERE EmailAddress IS NOT NULL 
AND EmailAddress NOT LIKE '%_@__%.__%';

--Espaços em branco em formatações de texto
SELECT COUNT(*) FROM DimCustomer WHERE FirstName != TRIM(FirstName);
SELECT COUNT(*) FROM DimCustomer WHERE LastName != TRIM(LastName);
SELECT COUNT(*) FROM DimCustomer WHERE EmailAddress != TRIM(EmailAddress);

