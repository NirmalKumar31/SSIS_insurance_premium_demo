USE PK1Demo;

SELECT log_id, file_name, status, rows_received, rows_loaded, rows_rejected, error_message, logged_at
FROM dbo.load_log ORDER BY log_id;

SELECT file_name, txn_id, reason FROM dbo.reject_rows ORDER BY reject_id;

SELECT * FROM dbo.fact_premium ORDER BY txn_id;

SELECT * FROM dbo.vw_premium_summary ORDER BY state_code, coverage_name;

SELECT file_name, status, rows_received, rows_loaded + rows_rejected AS loaded_plus_rejected,
       CASE WHEN rows_received = rows_loaded + rows_rejected THEN 'OK' ELSE 'CHECK' END AS reconciled
FROM dbo.load_log WHERE status = 'SUCCEEDED';
