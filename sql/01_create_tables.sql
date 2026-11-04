IF DB_ID('PK1Demo') IS NULL CREATE DATABASE PK1Demo;
GO
USE PK1Demo;
GO

DROP TABLE IF EXISTS dbo.fact_premium, dbo.reject_rows, dbo.load_log, dbo.stg_premium, dbo.state_map, dbo.dim_coverage;
GO

CREATE TABLE dbo.state_map (
    source_value VARCHAR(30) PRIMARY KEY,
    state_code   CHAR(2)     NOT NULL
);
INSERT INTO dbo.state_map VALUES
 ('NC','NC'), ('N.C.','NC'), ('North Carolina','NC'),
 ('SC','SC'), ('S.C.','SC'),
 ('GA','GA');

CREATE TABLE dbo.dim_coverage (
    coverage_code VARCHAR(10) PRIMARY KEY,
    coverage_name VARCHAR(40) NOT NULL
);
INSERT INTO dbo.dim_coverage VALUES ('AUTO','Personal auto'), ('HOME','Homeowners');

CREATE TABLE dbo.stg_premium (
    txn_id        VARCHAR(20),
    policy_no     VARCHAR(20),
    state         VARCHAR(30),
    coverage_code VARCHAR(10),
    txn_date      VARCHAR(20),
    premium       VARCHAR(20)
);

CREATE TABLE dbo.fact_premium (
    txn_id        INT           PRIMARY KEY,
    policy_no     VARCHAR(20)   NOT NULL,
    state_code    CHAR(2)       NOT NULL,
    coverage_code VARCHAR(10)   NOT NULL REFERENCES dbo.dim_coverage(coverage_code),
    txn_date      DATE          NOT NULL,
    premium       DECIMAL(10,2) NOT NULL CHECK (premium > 0),
    file_name     VARCHAR(100)  NOT NULL,
    loaded_at     DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.reject_rows (
    reject_id   INT IDENTITY(1,1) PRIMARY KEY,
    file_name   VARCHAR(100) NOT NULL,
    txn_id      VARCHAR(20)  NULL,
    reason      VARCHAR(100) NOT NULL,
    rejected_at DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.load_log (
    log_id        INT IDENTITY(1,1) PRIMARY KEY,
    file_name     VARCHAR(100)   NOT NULL,
    status        VARCHAR(10)    NOT NULL,
    rows_received INT            NULL,
    rows_loaded   INT            NULL,
    rows_rejected INT            NULL,
    error_message NVARCHAR(4000) NULL,
    logged_at     DATETIME2(0)   NOT NULL DEFAULT SYSDATETIME()
);
GO
