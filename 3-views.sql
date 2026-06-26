USE CarManagement_Final;
GO

-- views
-- available cars for employees and costumers
DROP VIEW IF EXISTS vw_AvailableCars;
GO
CREATE VIEW vw_AvailableCars AS
SELECT 
    c.CarID, 
    c.VIN, 
    m.Name AS Brand, 
    c.Model, 
    c.BuildYear, 
    c.CarAge, 
    c.DailyRentPrice, 
    c.BaseSalePrice
FROM Car c
JOIN Manufacturer m ON c.ManufacturerID = m.ManufacturerID
WHERE c.CurrentStatus = 'Available';
GO

-- ROI for manager
DROP VIEW IF EXISTS vw_CarROI_Analysis;
GO
CREATE VIEW vw_CarROI_Analysis AS
SELECT 
    c.CarID,
    c.VIN,
    c.Model,
    ISNULL((SELECT SUM(TotalAmount) FROM Reservation WHERE CarID = c.CarID AND Status = 'Completed'), 0) AS TotalRentIncome,
    ISNULL((SELECT SUM(Cost) FROM Repair WHERE CarID = c.CarID), 0) AS TotalRepairCost,
    (ISNULL((SELECT SUM(TotalAmount) FROM Reservation WHERE CarID = c.CarID AND Status = 'Completed'), 0) - 
     ISNULL((SELECT SUM(Cost) FROM Repair WHERE CarID = c.CarID), 0)) AS NetProfit
FROM Car c;
GO

-- good customers for manager
DROP VIEW IF EXISTS vw_CustomerFinancialStatus;
GO
CREATE VIEW vw_CustomerFinancialStatus AS
SELECT 
    CustomerID,
    FullName, 
    NationalCode,
    WalletBalance,
    AccountStatus
FROM Customer;
GO

-- classification of customers
DROP VIEW IF EXISTS vw_CustomerRanking;
GO
CREATE VIEW vw_CustomerRanking AS
SELECT 
    CustomerID,
    FullName, 
    WalletBalance,
    CASE 
        WHEN WalletBalance >= 1000 THEN 'VIP Customer'
        WHEN WalletBalance >= 0 AND WalletBalance < 1000 THEN 'Normal Customer'
        ELSE 'Debtor (Requires Follow-up)'
    END AS CustomerCategory,
    ROW_NUMBER() OVER (ORDER BY WalletBalance DESC) AS WealthRank
FROM Customer;
GO

-- total of a payment for each brand
DROP VIEW IF EXISTS vw_IncomeReportByBrand;
GO
CREATE VIEW vw_IncomeReportByBrand AS
SELECT 
    ISNULL(m.Name, '--- Grand Total ---') AS BrandName,
    SUM(p.Amount) AS TotalRevenue
FROM Payment p
LEFT JOIN Reservation r ON p.ReservationID = r.ReservationID
LEFT JOIN Car c ON r.CarID = c.CarID
LEFT JOIN Manufacturer m ON c.ManufacturerID = m.ManufacturerID
WHERE p.ReservationID IS NOT NULL
GROUP BY ROLLUP(m.Name);
GO

-- commission of each employee
DROP VIEW IF EXISTS vw_EmployeeCommissionReport;
GO
CREATE VIEW vw_EmployeeCommissionReport AS
SELECT 
    e.EmployeeID,
    e.FullName, 
    e.Position,
    COUNT(s.SaleID) AS TotalSalesContracts,
    ISNULL(SUM(s.FinalPrice), 0) AS TotalSalesVolume,
    ISNULL(SUM(s.FinalPrice * (e.CommissionRate / 100)), 0) AS EarnedCommission
FROM Employee e
LEFT JOIN Sale s ON e.EmployeeID = s.EmployeeID
GROUP BY 
    e.EmployeeID, 
    e.FullName, 
    e.Position, 
    e.CommissionRate;
GO

-- Sales Revenue by Brand and Payment Method
DROP VIEW IF EXISTS vw_Pivot_Sales_By_PaymentMethod;
GO
CREATE VIEW vw_Pivot_Sales_By_PaymentMethod AS
SELECT * FROM (
    SELECT 
        m.Name AS Brand, 
        p.Method AS PaymentMethod, 
        p.Amount
    FROM Payment p
    JOIN Sale s ON p.SaleID = s.SaleID
    JOIN Car c ON s.CarID = c.CarID
    JOIN Manufacturer m ON c.ManufacturerID = m.ManufacturerID
) AS SourceData
PIVOT (
    SUM(Amount) 
    FOR PaymentMethod IN ([Cash], [Credit Card], [Bank Transfer])
) AS PivotTable;
GO

-- Comprehensive Sales Analysis by Brand and Year
DROP VIEW IF EXISTS vw_Cube_RevenueAnalysis;
GO
CREATE VIEW vw_Cube_RevenueAnalysis AS
SELECT 
    ISNULL(m.Name, '--- All Brands ---') AS Brand,
    ISNULL(CAST(c.BuildYear AS NVARCHAR), '--- All Years ---') AS BuildYear,
    SUM(s.FinalPrice) AS TotalSalesRevenue
FROM Sale s
JOIN Car c ON s.CarID = c.CarID
JOIN Manufacturer m ON c.ManufacturerID = m.ManufacturerID
GROUP BY CUBE(m.Name, c.BuildYear);
GO

-- Find customers who only rent, but never buy
DROP VIEW IF EXISTS vw_RentOnlyCustomers;
GO
CREATE VIEW vw_RentOnlyCustomers AS
SELECT CustomerID, FullName, NationalCode 
FROM Customer
WHERE CustomerID IN (
    SELECT CustomerID FROM Reservation
    EXCEPT
    SELECT CustomerID FROM Sale
);
GO