USE PK1Demo;
EXEC dbo.usp_clear_staging;
BULK INSERT dbo.stg_premium
FROM 'C:\pk1demo\data\premium_2025_01.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a');
EXEC dbo.usp_load_premium @file_name = 'premium_2025_01.csv';
SELECT * FROM dbo.load_log;
