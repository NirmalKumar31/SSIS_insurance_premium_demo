# Insurance premium load — SQL Server + SSIS

A small, end-to-end ETL demo: a monthly **premium transactions file** is loaded by an **SSIS** package into SQL Server, validated by a **stored procedure**, and published to a simple reporting model — with **reject handling**, an **idempotent MERGE**, a **load log** and **two layers of error handling**.

All data is synthetic; codes are illustrative.

## How it works

```text
premium_YYYY_MM.csv ─▶ SSIS: LoadPremium.dtsx
                          1 Clear staging   EXEC dbo.usp_clear_staging
                          2 Load file       Flat File ─▶ dbo.stg_premium   ──(on failure)──▶ 4 Log file failure
                          3 Load premium    EXEC dbo.usp_load_premium @file_name
                                              ├─▶ dbo.fact_premium   good rows (MERGE on txn_id)
                                              ├─▶ dbo.reject_rows    bad rows + reason
                                              └─▶ dbo.load_log       SUCCEEDED / FAILED + counts
                                        dbo.vw_premium_summary ◀── report
```

## Data model (6 tables)

| Table | Role |
|---|---|
| `dbo.state_map` | maps carrier state spellings (`N.C.`, `North Carolina`) to standard codes |
| `dbo.dim_coverage` | coverages reported on (AUTO, HOME) |
| `dbo.stg_premium` | staging — every column text, exactly as received |
| `dbo.fact_premium` | one row per premium transaction; PK `txn_id`, FK to `dim_coverage`, `CHECK (premium > 0)` |
| `dbo.reject_rows` | rejected rows with the reason |
| `dbo.load_log` | one row per load: status, rows received / loaded / rejected, error message |

## The load procedure (`dbo.usp_load_premium`)

1. **Validate** every staging row in one `SELECT … CASE`: unmapped state (LEFT JOIN to the mapping), unknown coverage, invalid date or premium (`TRY_CONVERT`), non-positive premium.
2. **Reject** bad rows into `reject_rows` with the reason.
3. **MERGE** good rows into `fact_premium` — existing `txn_id` → update, new → insert (rerun-safe).
4. **Log** received / loaded / rejected counts.

## Error handling

| Layer | Catches | Does |
|---|---|---|
| SQL — `TRY…CATCH` + transaction in the procedure | errors inside the database (e.g. a primary-key violation) | rolls back the whole load, logs `ERROR_MESSAGE()`, re-throws so the SSIS task fails |
| SSIS — failure precedence constraint on *Load file* | the file is missing or unreadable | logs a FAILED row in `load_log` |

## Test files and results

| File | Result |
|---|---|
| `premium_2025_01.csv` | 10 received · 7 loaded · 3 rejected (unmapped state, invalid premium, unknown coverage) |
| `premium_2025_02.csv` | 6 · 5 · 1 (negative premium); txn 1004 re-sent with a corrected premium → **updated** by MERGE |
| `premium_2025_03_broken.csv` | duplicate txn 1017 → primary-key violation → **FAILED**, nothing loaded (rolled back) |
| a missing file name | SSIS failure path → **FAILED** "SSIS could not load the file into staging" |

## Screenshots

_(added below)_

## Run it

1. SQL Server 2022 + SSMS: run `sql/01_create_tables.sql`, then `sql/02_procedures_and_view.sql`.
2. Copy `data/` to `C:\pk1demo\data\`.
3. Optional check without SSIS: `sql/04_load_without_ssis.sql`, then `sql/05_reset.sql`.
4. Open the SSIS project (`ssis/`) in Visual Studio 2022 with the *SQL Server Integration Services Projects* extension, set `User::FileName`, run.
5. Inspect results with `sql/03_demo_queries.sql`.

## Repository layout

```text
data/          three sample monthly files
sql/           01 tables · 02 procedures + view · 03 demo queries · 04 load without SSIS · 05 reset
ssis/          the SSIS project (LoadPremium.dtsx) and its design notes
images/        screenshots of the package and results
```
