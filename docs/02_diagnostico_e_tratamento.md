# 2. Diagnóstico e tratamento dos dados

[← Voltar ao README](../README.md) · [← 1. Modelo e carga](01_modelo_e_carga.md)

Com o modelo carregado e estruturalmente validado (chaves, tipos, integridade referencial), a etapa seguinte foi o *profiling*: examinar os valores dentro de cada coluna para garantir que fazem sentido para análise, e não só que a estrutura está correta.

**Convenção adotada:** ausência de informação é representada por `NULL` real, nunca por um código de texto arbitrário (`"NA"`, `"0"`, espaço em branco). Isso facilita filtros e evita distorção em análises de segmentação.

## DimCustomer

### Metodologia
- **Visão geral:** contagem total (18.148 registros).
- **Completude:** nulos coluna a coluna. Nenhum `NULL` técnico.
- **Cardinalidade:** `GROUP BY` nas colunas categóricas (`Gender`, `MaritalStatus`, `EducationLevel`, `Occupation`, `HomeOwner`, `Prefix`), para revelar valores inesperados atrás de um tipo de dado válido.
- **Faixa de valores:** `MIN`/`MAX` em colunas numéricas e de data.
- **Duplicidade por campo não-chave:** e-mails repetidos entre `CustomerKey` diferentes.
- **Consistência cruzada:** `TotalChildren` preenchido sem `MaritalStatus` preenchido.
- **Formatação:** espaços no início ou fim dos campos de texto (`TRIM`).

### Achados e decisões

| Achado | Diagnóstico | Decisão |
|---|---|---|
| `Gender = 'NA'` em 130 registros | Texto arbitrário representando ausência, invisível à checagem de `NULL`. | Convertido para `NULL`. |
| `Prefix` em branco em 130 registros | String vazia ou espaço, também invisível a `IS NULL`. | Convertido para `NULL`. |
| `Prefix`: MR. / MRS. / MS. | Investigado se seriam grafias inconsistentes da mesma categoria. | São 3 títulos distintos; mantidos sem agrupamento. |
| `BirthDate` mínima em 1910 | Vários clientes com datas antigas, não um caso isolado. A análise etária posterior mostrou idades de 42 a 112 anos, 27 clientes com 100+ e nenhum abaixo de 40. | Mantido (as compras são válidas), mas a coluna é tratada como pouco confiável. |
| E-mail duplicado | Nenhum `CustomerKey` distinto compartilha e-mail. | Sem ação. |
| Espaços em texto | Nenhuma inconsistência. | Sem ação. |

Consulta de consistência cruzada (filhos cadastrados sem estado civil): nenhuma inconsistência relevante.

```sql
SELECT COUNT(*) FROM DimCustomer
WHERE TotalChildren > 0 AND MaritalStatus IS NULL;
```

### Correções aplicadas
```sql
UPDATE DimCustomer SET Gender = NULL WHERE Gender = 'NA';

UPDATE DimCustomer
SET Prefix = NULL
WHERE Prefix = ' ' OR LTRIM(RTRIM(Prefix)) = '';
```

## DimProduct

### Metodologia
- Contagem (293 registros) e nulos por coluna: nenhum `NULL` técnico.
- `GROUP BY` em `ProductColor`, `ProductSize` e `ProductStyle`.
- `MIN`/`MAX` de `ProductCost` e `ProductPrice`, com margem absoluta e percentual.
- Regra de negócio: produto vendido com prejuízo (`ProductCost > ProductPrice`).
- Duplicidade de `ProductSKU` entre `ProductKey` diferentes.
- Investigação dos produtos nos extremos de custo e preço.

### Achados e decisões

| Achado | Diagnóstico | Decisão |
|---|---|---|
| `ProductSize = '0'` em 84 registros (55 Components, 28 Accessories, 1 Clothing) | Componentes e acessórios não têm tamanho no sentido de vestuário; o único de Clothing era um boné ("AWC Logo Cap"), de tamanho único. | `NULL`: "0" significava "não aplicável". |
| `ProductStyle = '0'` em 84 registros | Mesmo padrão do tamanho. | `NULL`. |
| `ProductSKU` duplicado | Nenhum. | Sem ação. |
| Custo maior que preço | Nenhum registro. | Sem ação. |
| Suspeita de outlier em custo e preço | Os produtos de maior valor são itens de catálogo genuinamente mais caros, sem erro de escala ou digitação. | Mantido: não eram outliers de dado. |

```sql
UPDATE DimProduct SET ProductSize = NULL WHERE ProductSize = '0';
UPDATE DimProduct SET ProductStyle = NULL WHERE ProductStyle = '0';
```

## Demais dimensões

Perfiladas com a mesma metodologia (completude, cardinalidade, duplicidade, formatação, órfãos de FK), de forma mais enxuta por serem pequenas.

| Tabela | Registros | Resultado |
|---|---|---|
| `DimTerritory` | 10 | Hierarquia Região / País / Continente verificada; sem anomalias. |
| `DimProductCategory` | 4 | Bikes, Components, Clothing, Accessories; sem espaços ocultos (`LEN`) nem órfãos. |
| `DimProductSubcategory` | 37 | Cada subcategoria sob a categoria-pai correta; sem duplicidade nem órfãos. |
| `DimDate` | — | Calendário completo, sem buracos (validação abaixo). |

### DimDate: validação de "buracos" no calendário
Uma CTE recursiva gera a sequência completa de dias entre a data mínima e a máxima e compara com o que existe na tabela. Nenhuma data faltante: o calendário cobre integralmente o período de `FactSales` e `FactReturns`.

```sql
WITH Limites AS (
    SELECT MIN([Date]) AS DataInicial, MAX([Date]) AS DataFinal
    FROM DimDate
),
Sequencia AS (
    SELECT DataInicial AS DataEsperada, DataFinal FROM Limites
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
```

## FactSales

Para tabelas fato o foco muda: menos "a categoria está bem escrita?" e mais "os números e as datas fazem sentido de negócio?".

- **Visão geral:** contagem e intervalo de datas (01/01/2020 a 30/06/2022).
- **Completude:** nulos em todas as colunas, inclusive chaves estrangeiras.
- **Regras de negócio:** quantidade vendida válida (`OrderQuantity <= 0`) e coerência de datas (`OrderDate` anterior a `StockDate`).
- **Duplicidade:** além da PK composta, múltiplas linhas para o mesmo pedido e produto.
- **Órfãos:** `ProductKey`, `CustomerKey` e `SalesTerritoryKey` contra as dimensões.
- **Outliers:** IQR sobre `OrderQuantity`, receita por linha, volume por dia, volume por cliente e Z-score como método complementar.

**Resultado:** nenhuma anomalia. Sem nulos, quantidades inválidas, inconsistência de datas, duplicidade além da esperada ou órfãos; os outliers estatísticos são compatíveis com o comportamento plausível do negócio.

## FactReturns

- Visão geral, completude, regra de negócio (`ReturnQuantity <= 0`) e órfãos, com a mesma lógica da `FactSales`.
- Outliers: IQR sobre `ReturnQuantity`.
- Devolução para combinação Produto/Território sem venda correspondente.
- Quantidade devolvida superior à vendida, por Produto/Território.

**Achado:** o IQR sinalizou 19 registros com `ReturnQuantity = 2`. A distribuição mostra que quase todas as devoluções têm quantidade 1, então qualquer valor levemente maior é estatisticamente incomum numa base de variabilidade baixíssima: limitação conhecida do IQR em distribuições muito concentradas.
**Decisão:** mantido. É outlier estatístico, não de negócio; devolver 2 unidades é plausível.

**Demais resultados:** sem nulos, sem quantidades inválidas, sem órfãos, sem devolução sem venda correspondente e sem caso de devolução maior que a venda.

## Validações de integridade

Executadas após a carga completa (`sql/04_validation/integrity_checks.sql`):

```sql
-- Órfãos: FK em FactSales/FactReturns sem correspondência na dimensão
SELECT COUNT(*) FROM FactSales f
LEFT JOIN DimProduct p ON f.ProductKey = p.ProductKey
WHERE p.ProductKey IS NULL;

-- Volumetria geral por tabela
SELECT 'DimCustomer' AS Tabela, COUNT(*) AS Linhas FROM DimCustomer
UNION ALL SELECT 'DimProduct', COUNT(*) FROM DimProduct
UNION ALL SELECT 'FactSales', COUNT(*) FROM FactSales
UNION ALL SELECT 'FactReturns', COUNT(*) FROM FactReturns;
```

## Resumo consolidado

| Tabela | Resultado |
|---|---|
| `DimCustomer` | Tratada: `Gender` "NA" → `NULL`; `Prefix` em branco → `NULL` |
| `DimProduct` | Tratada: `ProductSize` "0" → `NULL`; `ProductStyle` "0" → `NULL` |
| `DimTerritory` | Limpa, sem ação |
| `DimProductCategory` | Limpa, sem ação |
| `DimProductSubcategory` | Limpa, sem ação |
| `DimDate` | Limpa, calendário completo sem buracos |
| `FactSales` | Limpa; regras de negócio e outliers validados |
| `FactReturns` | Limpa; outlier estatístico identificado como variação normal de negócio |

---

Próximo: [3. Análises SQL →](03_analises_sql.md)
