-- =====================================================================
-- ANÁLISE — Página 4: Comportamento do Cliente (Segmentação RFM)
-- Pergunta de negócio: Quem são meus clientes mais valiosos, e quem
-- estou perdendo?
-- Alimenta: quadrante/matriz RFM, distribuição de clientes por
-- segmento e ticket médio por perfil demográfico.
--
-- NOTAS METODOLÓGICAS:
-- 1) Data de referência: o dataset termina em 2022, então a recência
--    NÃO pode ser calculada contra GETDATE() (todos os clientes
--    pareceriam "inativos há anos"). Usamos a última data de venda do
--    próprio dataset + 1 dia, como se a análise fosse feita "no dia
--    seguinte" ao fim dos dados.
-- 2) A data de referência é obtida via subquery dentro das CTEs, e não
--    via DECLARE, para o script rodar inteiro de uma vez no DBeaver
--    sem o erro de variável fora de escopo.
-- 3) Só entram na análise clientes que compraram pelo menos uma vez
--    (quem está em DimCustomer mas nunca aparece em FactSales não tem
--    recência/frequência/valor para calcular).
-- 4) Usa apenas FactSales (nenhuma junção entre duas tabelas fato),
--    evitando o efeito fan-out visto no script 02.
-- =====================================================================


-- =====================================================================
-- 1. DISTRIBUIÇÃO DE FREQUÊNCIA (diagnóstico antes de pontuar)
-- Objetivo: ver quantos pedidos cada cliente costuma fazer. Se a
-- grande maioria tiver 1 ou 2 pedidos, muitos clientes empatam em
-- frequência e a divisão em 5 faixas (NTILE) vai separar clientes
-- iguais de forma arbitrária — vale conhecer isso antes de interpretar.
-- =====================================================================
WITH PedidosPorCliente AS (
    SELECT CustomerKey, COUNT(DISTINCT OrderNumber) AS Frequencia
    FROM FactSales
    GROUP BY CustomerKey
)
SELECT Frequencia, COUNT(*) AS QtdClientes
FROM PedidosPorCliente
GROUP BY Frequencia
ORDER BY Frequencia;


-- =====================================================================
-- 1b. INVESTIGAÇÃO: CLIENTES DE FREQUÊNCIA MUITO ALTA
-- A distribuição acima mostra um vazio entre 8 e 12 pedidos e um grupo
-- isolado de clientes com 13 a 26 pedidos. Pode ser um perfil legítimo
-- (compradores recorrentes/revendedores) ou um artefato dos dados.
-- Esta query lista esses clientes com seu perfil, para decidir se
-- entram na análise normalmente ou se são tratados como grupo à parte.
-- =====================================================================
WITH PedidosPorCliente AS (
    SELECT
        f.CustomerKey,
        COUNT(DISTINCT f.OrderNumber)                AS Frequencia,
        SUM(f.OrderQuantity)                         AS UnidadesCompradas,
        SUM(f.OrderQuantity * p.ProductPrice)        AS ValorMonetario,
        MIN(f.OrderDate)                             AS PrimeiraCompra,
        MAX(f.OrderDate)                             AS UltimaCompra
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY f.CustomerKey
)
SELECT
    pc.CustomerKey,
    c.Occupation,
    c.EducationLevel,
    c.AnnualIncome,
    pc.Frequencia,
    pc.UnidadesCompradas,
    pc.ValorMonetario,
    pc.PrimeiraCompra,
    pc.UltimaCompra
FROM PedidosPorCliente pc
JOIN DimCustomer c ON pc.CustomerKey = c.CustomerKey
WHERE pc.Frequencia >= 13
ORDER BY pc.Frequencia DESC;


-- =====================================================================
-- 2. TABELA RFM POR CLIENTE (valores brutos + notas de 1 a 5)
-- Nota 5 = melhor em todas as dimensões:
--   Recência: quanto MENOR o número de dias, MAIOR a nota
--   Valor: quanto MAIOR o número, MAIOR a nota
--   Frequência: faixas FIXAS (1, 2, 3, 4-5, 6+ pedidos) e não NTILE.
--     Motivo: 66% dos clientes têm exatamente 1 pedido; o NTILE
--     dividiria clientes empatados em notas diferentes de forma
--     arbitrária. Recência e valor têm poucos empates, então seguem
--     com NTILE.
-- =====================================================================
WITH RFMBruto AS (
    SELECT
        f.CustomerKey,
        DATEDIFF(DAY, MAX(f.OrderDate),
                 DATEADD(DAY, 1, (SELECT MAX(OrderDate) FROM FactSales)))   AS RecenciaDias,
        COUNT(DISTINCT f.OrderNumber)                                        AS Frequencia,
        SUM(f.OrderQuantity * p.ProductPrice)                                AS ValorMonetario
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY f.CustomerKey
)
SELECT
    CustomerKey,
    RecenciaDias,
    Frequencia,
    ValorMonetario,
    NTILE(5) OVER (ORDER BY RecenciaDias DESC, CustomerKey)    AS NotaR,
    CASE
        WHEN Frequencia = 1  THEN 1
        WHEN Frequencia = 2  THEN 2
        WHEN Frequencia = 3  THEN 3
        WHEN Frequencia <= 5 THEN 4
        ELSE                      5
    END                                           AS NotaF,
    NTILE(5) OVER (ORDER BY ValorMonetario ASC, CustomerKey)   AS NotaM
FROM RFMBruto
ORDER BY ValorMonetario DESC;


-- =====================================================================
-- 3. SEGMENTAÇÃO: CLASSIFICA CADA CLIENTE EM UM GRUPO DE NEGÓCIO
-- A ordem dos WHEN importa: o primeiro critério atendido define o
-- segmento do cliente.
--
-- Sobre os nomes: "Recorrentes" (e não "Fiéis") porque a frequência
-- média do segmento é ~2 pedidos; "Hibernando" (e não "Perdidos")
-- porque o dado só mostra ausência de compra recente, não abandono.
--
-- Sobre TicketMedioPorPedido: é a razão entre as somas (receita total
-- / pedidos totais do segmento), ou seja, ponderada. Separa o efeito
-- "compra mais vezes" (ValorMedioPorCliente) do efeito "cada pedido
-- vale mais" (ticket).
-- =====================================================================
WITH RFMBruto AS (
    SELECT
        f.CustomerKey,
        DATEDIFF(DAY, MAX(f.OrderDate),
                 DATEADD(DAY, 1, (SELECT MAX(OrderDate) FROM FactSales)))   AS RecenciaDias,
        COUNT(DISTINCT f.OrderNumber)                                        AS Frequencia,
        SUM(f.OrderQuantity * p.ProductPrice)                                AS ValorMonetario
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY f.CustomerKey
),
RFMNotas AS (
    SELECT
        CustomerKey, RecenciaDias, Frequencia, ValorMonetario,
        NTILE(5) OVER (ORDER BY RecenciaDias DESC, CustomerKey)    AS NotaR,
        CASE
            WHEN Frequencia = 1  THEN 1
            WHEN Frequencia = 2  THEN 2
            WHEN Frequencia = 3  THEN 3
            WHEN Frequencia <= 5 THEN 4
            ELSE                      5
        END                                           AS NotaF,
        NTILE(5) OVER (ORDER BY ValorMonetario ASC, CustomerKey)   AS NotaM
    FROM RFMBruto
),
RFMSegmentado AS (
    SELECT *,
        CASE
            WHEN NotaR >= 4 AND NotaF >= 3                THEN 'Campeões'
            WHEN NotaR >= 3 AND NotaF >= 2                THEN 'Recorrentes'
            WHEN NotaR >= 4 AND NotaF = 1                 THEN 'Novos / Promissores'
            WHEN NotaR <= 2 AND NotaF >= 2                THEN 'Em Risco'
            WHEN NotaR <= 2 AND NotaF = 1                 THEN 'Hibernando'
            ELSE                                               'Precisam de Atenção'
        END AS Segmento
    FROM RFMNotas
)
SELECT
    Segmento,
    COUNT(*)                                          AS QtdClientes,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2))   AS PercentualClientes,
    SUM(ValorMonetario)                               AS ReceitaTotal,
    CAST(SUM(ValorMonetario) * 100.0 / SUM(SUM(ValorMonetario)) OVER() AS DECIMAL(5,2)) AS PercentualReceita,
    AVG(ValorMonetario)                               AS ValorMedioPorCliente,
    SUM(ValorMonetario) / NULLIF(SUM(Frequencia), 0)  AS TicketMedioPorPedido,
    AVG(RecenciaDias * 1.0)                           AS RecenciaMediaDias,
    AVG(Frequencia * 1.0)                             AS FrequenciaMedia
FROM RFMSegmentado
GROUP BY Segmento
ORDER BY ReceitaTotal DESC;


-- =====================================================================
-- 4. TICKET MÉDIO POR FAIXA ETÁRIA
-- A idade é calculada na data de referência (fim do dataset), não na
-- data de hoje, para refletir a idade do cliente no período analisado.
-- DATEDIFF(YEAR) conta viradas de ano-calendário, então é uma
-- aproximação (pode errar em 1 ano para quem ainda não fez aniversário
-- no ano) — suficiente para agrupar em faixas.
-- =====================================================================
WITH GastoPorCliente AS (
    SELECT
        f.CustomerKey,
        COUNT(DISTINCT f.OrderNumber)                AS Pedidos,
        SUM(f.OrderQuantity * p.ProductPrice)        AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY f.CustomerKey
),
ClienteComFaixa AS (
    SELECT
        g.*,
        DATEDIFF(YEAR, c.BirthDate, (SELECT MAX(OrderDate) FROM FactSales)) AS Idade
    FROM GastoPorCliente g
    JOIN DimCustomer c ON g.CustomerKey = c.CustomerKey
)
SELECT
    CASE
        WHEN Idade < 30 THEN '1. Até 29 anos'
        WHEN Idade < 40 THEN '2. 30 a 39 anos'
        WHEN Idade < 50 THEN '3. 40 a 49 anos'
        WHEN Idade < 60 THEN '4. 50 a 59 anos'
        WHEN Idade < 70 THEN '5. 60 a 69 anos'
        ELSE                 '6. 70 anos ou mais'
    END                                              AS FaixaEtaria,
    COUNT(*)                                         AS QtdClientes,
    SUM(Receita)                                     AS ReceitaTotal,
    SUM(Receita) / NULLIF(SUM(Pedidos), 0)           AS TicketMedioPorPedido,
    AVG(Receita)                                     AS GastoMedioPorCliente
FROM ClienteComFaixa
GROUP BY
    CASE
        WHEN Idade < 30 THEN '1. Até 29 anos'
        WHEN Idade < 40 THEN '2. 30 a 39 anos'
        WHEN Idade < 50 THEN '3. 40 a 49 anos'
        WHEN Idade < 60 THEN '4. 50 a 59 anos'
        WHEN Idade < 70 THEN '5. 60 a 69 anos'
        ELSE                 '6. 70 anos ou mais'
    END
ORDER BY FaixaEtaria;


-- =====================================================================
-- 5. TICKET MÉDIO POR ESCOLARIDADE E OCUPAÇÃO
-- Mesmo cálculo de ticket, agora por atributos demográficos da
-- DimCustomer, para identificar perfis que gastam mais.
-- =====================================================================
WITH GastoPorCliente AS (
    SELECT
        f.CustomerKey,
        COUNT(DISTINCT f.OrderNumber)                AS Pedidos,
        SUM(f.OrderQuantity * p.ProductPrice)        AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY f.CustomerKey
)
SELECT
    c.EducationLevel,
    c.Occupation,
    COUNT(*)                                         AS QtdClientes,
    SUM(g.Receita)                                   AS ReceitaTotal,
    SUM(g.Receita) / NULLIF(SUM(g.Pedidos), 0)       AS TicketMedioPorPedido,
    AVG(g.Receita)                                   AS GastoMedioPorCliente
FROM GastoPorCliente g
JOIN DimCustomer c ON g.CustomerKey = c.CustomerKey
GROUP BY c.EducationLevel, c.Occupation
ORDER BY GastoMedioPorCliente DESC;


-- =====================================================================
-- 5b. OCUPAÇÃO E ESCOLARIDADE ANALISADAS SEPARADAMENTE
-- Cruzar as duas variáveis (query 5) gera 25 combinações, várias com
-- poucos clientes — grupos pequenos dominam o topo do ranking por
-- gasto médio. Olhar cada variável isolada dá grupos maiores e uma
-- leitura mais estável.
-- =====================================================================
WITH GastoPorCliente AS (
    SELECT
        f.CustomerKey,
        COUNT(DISTINCT f.OrderNumber)                AS Pedidos,
        SUM(f.OrderQuantity * p.ProductPrice)        AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY f.CustomerKey
)
SELECT 'Ocupação' AS Dimensao, c.Occupation AS Categoria,
       COUNT(*) AS QtdClientes, SUM(g.Receita) AS ReceitaTotal,
       SUM(g.Receita) / NULLIF(SUM(g.Pedidos), 0) AS TicketMedioPorPedido,
       AVG(g.Receita) AS GastoMedioPorCliente
FROM GastoPorCliente g
JOIN DimCustomer c ON g.CustomerKey = c.CustomerKey
GROUP BY c.Occupation
UNION ALL
SELECT 'Escolaridade', c.EducationLevel,
       COUNT(*), SUM(g.Receita),
       SUM(g.Receita) / NULLIF(SUM(g.Pedidos), 0),
       AVG(g.Receita)
FROM GastoPorCliente g
JOIN DimCustomer c ON g.CustomerKey = c.CustomerKey
GROUP BY c.EducationLevel
ORDER BY Dimensao, GastoMedioPorCliente DESC;


-- =====================================================================
-- 6. GASTO POR RENDA ANUAL
-- Objetivo: verificar se a renda é o fator que está por trás dos
-- padrões de escolaridade e ocupação (que costumam ser correlacionados
-- com renda). Se o gasto crescer de forma clara com a renda, as outras
-- duas variáveis podem ser apenas "proxies" dela.
-- =====================================================================
WITH GastoPorCliente AS (
    SELECT
        f.CustomerKey,
        COUNT(DISTINCT f.OrderNumber)                AS Pedidos,
        SUM(f.OrderQuantity * p.ProductPrice)        AS Receita
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY f.CustomerKey
)
SELECT
    c.AnnualIncome,
    COUNT(*)                                         AS QtdClientes,
    SUM(g.Receita)                                   AS ReceitaTotal,
    SUM(g.Receita) / NULLIF(SUM(g.Pedidos), 0)       AS TicketMedioPorPedido,
    AVG(g.Receita)                                   AS GastoMedioPorCliente
FROM GastoPorCliente g
JOIN DimCustomer c ON g.CustomerKey = c.CustomerKey
GROUP BY c.AnnualIncome
ORDER BY c.AnnualIncome;


-- =====================================================================
-- 7. VERIFICAÇÃO DE SANIDADE: DISTRIBUIÇÃO DE IDADE
-- A query 4 não retornou nenhuma faixa abaixo de 40 anos e mostrou
-- ~21% dos clientes com 70+. Esta query mostra os extremos reais, para
-- decidir como apresentar a análise etária e se a BirthDate é confiável
-- o suficiente para isso.
-- =====================================================================
WITH Idades AS (
    SELECT
        c.CustomerKey,
        DATEDIFF(YEAR, c.BirthDate, (SELECT MAX(OrderDate) FROM FactSales)) AS Idade
    FROM DimCustomer c
    WHERE c.CustomerKey IN (SELECT DISTINCT CustomerKey FROM FactSales)
)
SELECT
    COUNT(*)                                          AS ClientesCompradores,
    MIN(Idade)                                        AS IdadeMinima,
    MAX(Idade)                                        AS IdadeMaxima,
    SUM(CASE WHEN Idade < 40  THEN 1 ELSE 0 END)      AS Abaixo40,
    SUM(CASE WHEN Idade >= 90 THEN 1 ELSE 0 END)      AS Acima90,
    SUM(CASE WHEN Idade >= 100 THEN 1 ELSE 0 END)     AS Acima100
FROM Idades;


-- =====================================================================
-- 8. VIEW PARA O POWER BI: UMA LINHA POR CLIENTE COM O SEGMENTO RFM
-- NTILE com CustomerKey como desempate: sem ele, clientes com mesma
-- recência ou mesmo valor são distribuídos entre as faixas de forma
-- arbitrária, e cada execução pode dar um resultado diferente.
-- Por que uma view: o NTILE e as regras de segmentação já foram validados
-- em SQL. Recriá-los em DAX arrisca divergência entre os dois. Com a view,
-- o Power BI só importa o resultado pronto, com a mesma lógica da query 3.
-- Relacionamento no modelo: vw_ClienteRFM[CustomerKey] -> DimCustomer.
-- Execute o CREATE VIEW sozinho (selecione só ele no DBeaver).
-- =====================================================================
CREATE VIEW dbo.vw_ClienteRFM AS
WITH RFMBruto AS (
    SELECT
        f.CustomerKey,
        DATEDIFF(DAY, MAX(f.OrderDate),
                 DATEADD(DAY, 1, (SELECT MAX(OrderDate) FROM FactSales)))   AS RecenciaDias,
        COUNT(DISTINCT f.OrderNumber)                                        AS Frequencia,
        SUM(f.OrderQuantity * p.ProductPrice)                                AS ValorMonetario
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY f.CustomerKey
),
RFMNotas AS (
    SELECT
        CustomerKey, RecenciaDias, Frequencia, ValorMonetario,
        NTILE(5) OVER (ORDER BY RecenciaDias DESC, CustomerKey)    AS NotaR,
        CASE
            WHEN Frequencia = 1  THEN 1
            WHEN Frequencia = 2  THEN 2
            WHEN Frequencia = 3  THEN 3
            WHEN Frequencia <= 5 THEN 4
            ELSE                      5
        END                                           AS NotaF,
        NTILE(5) OVER (ORDER BY ValorMonetario ASC, CustomerKey)   AS NotaM
    FROM RFMBruto
)
SELECT *,
    CASE
        WHEN NotaR >= 4 AND NotaF >= 3                THEN 'Campeões'
        WHEN NotaR >= 3 AND NotaF >= 2                THEN 'Recorrentes'
        WHEN NotaR >= 4 AND NotaF = 1                 THEN 'Novos / Promissores'
        WHEN NotaR <= 2 AND NotaF >= 2                THEN 'Em Risco'
        WHEN NotaR <= 2 AND NotaF = 1                 THEN 'Hibernando'
        ELSE                                               'Precisam de Atenção'
    END AS Segmento
FROM RFMNotas;

-- Conferência: deve reproduzir QtdClientes e ReceitaTotal da query 3.
SELECT Segmento, COUNT(*) AS QtdClientes, SUM(ValorMonetario) AS ReceitaTotal
FROM dbo.vw_ClienteRFM
GROUP BY Segmento
ORDER BY ReceitaTotal DESC;