-- =====================================================
-- CRIAÇÃO DE TABELAS
-- Autor: Igor Mendes | Data: 04/10/2026
-- =====================================================
-- 1. DIMENSÃO DATA
CREATE TABLE DimDate (
    [Date] DATE NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY ([Date])
);

-- 2. DIMENSÃO TERRITÓRIO
CREATE TABLE DimTerritory (
    SalesTerritoryKey INT NOT NULL,
    Region VARCHAR(50) NOT NULL,
    Country VARCHAR(50) NOT NULL,
    Continent VARCHAR(50) NOT NULL,
    CONSTRAINT PK_DimTerritory PRIMARY KEY (SalesTerritoryKey)
);

-- 3. DIMENSÃO CATEGORIA DE PRODUTO
CREATE TABLE DimProductCategory (
    ProductCategoryKey INT NOT NULL,
    CategoryName VARCHAR(50) NOT NULL,
    CONSTRAINT PK_DimProductCategory PRIMARY KEY (ProductCategoryKey)
);

-- 4. DIMENSÃO SUBCATEGORIA (depende de DimProductCategory)
CREATE TABLE DimProductSubcategory (
    ProductSubcategoryKey INT NOT NULL,
    SubcategoryName VARCHAR(50) NOT NULL,
    ProductCategoryKey INT NOT NULL,
    CONSTRAINT PK_DimProductSubcategory PRIMARY KEY (ProductSubcategoryKey),
    CONSTRAINT FK_Subcategory_Category FOREIGN KEY (ProductCategoryKey)
        REFERENCES DimProductCategory(ProductCategoryKey)
);

-- 5. DIMENSÃO PRODUTO (depende de DimProductSubcategory)
CREATE TABLE DimProduct (
    ProductKey INT NOT NULL,
    ProductSubcategoryKey INT NOT NULL,
    ProductSKU VARCHAR(20) NOT NULL,
    ProductName VARCHAR(100) NOT NULL,
    ModelName VARCHAR(50) NULL,
    ProductDescription VARCHAR(500) NULL,
    ProductColor VARCHAR(20) NULL,
    ProductSize VARCHAR(10) NULL,
    ProductStyle VARCHAR(10) NULL,
    ProductCost DECIMAL(10,4) NOT NULL,
    ProductPrice DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_DimProduct PRIMARY KEY (ProductKey),
    CONSTRAINT FK_Product_Subcategory FOREIGN KEY (ProductSubcategoryKey)
        REFERENCES DimProductSubcategory(ProductSubcategoryKey)
);

-- 6. DIMENSÃO CLIENTE
CREATE TABLE DimCustomer (
    CustomerKey INT NOT NULL,
    Prefix VARCHAR(10) NULL,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    BirthDate DATE NOT NULL,
    MaritalStatus CHAR(1) NULL,
    Gender CHAR(1) NULL,
    EmailAddress VARCHAR(100) NULL,
    AnnualIncome DECIMAL(12,2) NULL,
    TotalChildren TINYINT NULL,
    EducationLevel VARCHAR(30) NULL,
    Occupation VARCHAR(30) NULL,
    HomeOwner CHAR(1) NULL,
    CONSTRAINT PK_DimCustomer PRIMARY KEY (CustomerKey)
);

-- 7. FATO VENDAS (as 3 planilhas de anos vão entrar AQUI, unidas)
CREATE TABLE FactSales (
    OrderDate DATE NOT NULL,
    StockDate DATE NOT NULL,
    OrderNumber VARCHAR(20) NOT NULL,
    ProductKey INT NOT NULL,
    CustomerKey INT NOT NULL,
    SalesTerritoryKey INT NOT NULL,
    OrderLineItem INT NOT NULL,
    OrderQuantity INT NOT NULL,
    CONSTRAINT PK_FactSales PRIMARY KEY (OrderNumber, OrderLineItem),
    CONSTRAINT FK_Sales_Product FOREIGN KEY (ProductKey)
        REFERENCES DimProduct(ProductKey),
    CONSTRAINT FK_Sales_Customer FOREIGN KEY (CustomerKey)
        REFERENCES DimCustomer(CustomerKey),
    CONSTRAINT FK_Sales_Territory FOREIGN KEY (SalesTerritoryKey)
        REFERENCES DimTerritory(SalesTerritoryKey),
    CONSTRAINT FK_Sales_OrderDate FOREIGN KEY (OrderDate)
        REFERENCES DimDate([Date])
);

-- 8. FATO DEVOLUÇÕES (sem PK natural -> surrogate key)
CREATE TABLE FactReturns (
    ReturnID INT IDENTITY(1,1) NOT NULL,
    ReturnDate DATE NOT NULL,
    SalesTerritoryKey INT NOT NULL,
    ProductKey INT NOT NULL,
    ReturnQuantity INT NOT NULL,
    CONSTRAINT PK_FactReturns PRIMARY KEY (ReturnID),
    CONSTRAINT FK_Returns_Product FOREIGN KEY (ProductKey)
        REFERENCES DimProduct(ProductKey),
    CONSTRAINT FK_Returns_Territory FOREIGN KEY (SalesTerritoryKey)
        REFERENCES DimTerritory(SalesTerritoryKey),
    CONSTRAINT FK_Returns_Date FOREIGN KEY (ReturnDate)
        REFERENCES DimDate([Date])
);
