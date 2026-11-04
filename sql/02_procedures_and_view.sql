USE PK1Demo;
GO

CREATE OR ALTER PROCEDURE dbo.usp_clear_staging
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE dbo.stg_premium;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_load_premium @file_name VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @received INT, @rejected INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT s.txn_id, s.policy_no, m.state_code, s.coverage_code,
               TRY_CONVERT(date, s.txn_date)          AS txn_date,
               TRY_CONVERT(decimal(10,2), s.premium)  AS premium,
               CASE WHEN TRY_CONVERT(int, s.txn_id) IS NULL         THEN 'invalid txn_id'
                    WHEN m.state_code IS NULL                       THEN 'unmapped state: ' + ISNULL(s.state, '')
                    WHEN c.coverage_code IS NULL                    THEN 'unknown coverage: ' + ISNULL(s.coverage_code, '')
                    WHEN TRY_CONVERT(date, s.txn_date) IS NULL      THEN 'invalid date'
                    WHEN TRY_CONVERT(decimal(10,2), s.premium) IS NULL THEN 'invalid premium: ' + ISNULL(s.premium, '')
                    WHEN TRY_CONVERT(decimal(10,2), s.premium) <= 0 THEN 'premium must be positive'
               END AS reject_reason
        INTO #checked
        FROM dbo.stg_premium s
        LEFT JOIN dbo.state_map    m ON m.source_value  = s.state
        LEFT JOIN dbo.dim_coverage c ON c.coverage_code = s.coverage_code;

        INSERT INTO dbo.reject_rows (file_name, txn_id, reason)
        SELECT @file_name, txn_id, reject_reason
        FROM #checked
        WHERE reject_reason IS NOT NULL;

        MERGE dbo.fact_premium AS t
        USING (SELECT CONVERT(int, txn_id) AS txn_id, policy_no, state_code, coverage_code, txn_date, premium
               FROM #checked
               WHERE reject_reason IS NULL) AS s
           ON t.txn_id = s.txn_id
        WHEN MATCHED THEN
            UPDATE SET t.policy_no = s.policy_no, t.state_code = s.state_code, t.coverage_code = s.coverage_code,
                       t.txn_date = s.txn_date, t.premium = s.premium, t.file_name = @file_name, t.loaded_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (txn_id, policy_no, state_code, coverage_code, txn_date, premium, file_name)
            VALUES (s.txn_id, s.policy_no, s.state_code, s.coverage_code, s.txn_date, s.premium, @file_name);

        SELECT @received = COUNT(*),
               @rejected = ISNULL(SUM(CASE WHEN reject_reason IS NOT NULL THEN 1 ELSE 0 END), 0)
        FROM #checked;

        INSERT INTO dbo.load_log (file_name, status, rows_received, rows_loaded, rows_rejected)
        VALUES (@file_name, 'SUCCEEDED', @received, @received - @rejected, @rejected);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO dbo.load_log (file_name, status, error_message)
        VALUES (@file_name, 'FAILED', ERROR_MESSAGE());

        THROW;
    END CATCH
END;
GO

CREATE OR ALTER VIEW dbo.vw_premium_summary AS
SELECT f.state_code, c.coverage_name,
       COUNT(*)       AS transactions,
       SUM(f.premium) AS total_premium
FROM dbo.fact_premium f
JOIN dbo.dim_coverage c ON c.coverage_code = f.coverage_code
GROUP BY f.state_code, c.coverage_name;
GO

