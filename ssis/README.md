# SSIS package

The Visual Studio project `PK1Demo_SSIS/` (`LoadPremium.dtsx`, `.dtproj`, `.sln`) goes in this folder.

Package design:

| # | Task | Type | What it runs |
|---|---|---|---|
| 1 | Clear staging | Execute SQL | `EXEC dbo.usp_clear_staging` |
| 2 | Load file | Data Flow | Flat File Source (`FF_Premium`) → OLE DB Destination `dbo.stg_premium` (fast load) |
| 3 | Load premium | Execute SQL | `EXEC dbo.usp_load_premium ?`; parameter 0 = `User::FileName` |
| 4 | Log file failure | Execute SQL, on the **failure** path of task 2 | `INSERT INTO dbo.load_log (file_name, status, error_message) VALUES (?, 'FAILED', 'SSIS could not load the file into staging')` |

- Variable: `User::FileName` (String), e.g. `premium_2025_01.csv`
- `FF_Premium` ConnectionString expression: `"C:\\pk1demo\\data\\" + @[User::FileName]`; header and row delimiter `{LF}`; columns `DT_STR`; `DelayValidation = True`
- OLE DB connection: Microsoft OLE DB Driver for SQL Server, `localhost`, Windows authentication, database `PK1Demo`, Trust Server Certificate = True
