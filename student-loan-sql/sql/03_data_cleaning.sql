-- ============================================================
-- 03_data_cleaning.sql
-- Data Validation & Cleaning Queries
-- Run these after importing to verify data quality
-- ============================================================

-- Check row counts per table
SELECT 'institutions' AS tbl, COUNT(*) AS rows FROM institutions
UNION ALL SELECT 'institution_costs', COUNT(*) FROM institution_costs
UNION ALL SELECT 'loan_outcomes', COUNT(*) FROM loan_outcomes;

-- Check NULL rates for key columns
SELECT 
    COUNT(*) AS total,
    SUM(CASE WHEN debt_median IS NULL THEN 1 ELSE 0 END) AS null_debt,
    SUM(CASE WHEN default_rate_3yr IS NULL THEN 1 ELSE 0 END) AS null_default,
    SUM(CASE WHEN earnings_10yr IS NULL THEN 1 ELSE 0 END) AS null_earnings,
    SUM(CASE WHEN completion_rate IS NULL THEN 1 ELSE 0 END) AS null_completion,
    ROUND(100.0 * SUM(CASE WHEN debt_median IS NOT NULL 
        AND default_rate_3yr IS NOT NULL 
        AND earnings_10yr IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) 
        AS pct_complete_records
FROM loan_outcomes;

-- Check for outliers in debt
SELECT 
    MIN(debt_median) AS min_debt,
    AVG(debt_median) AS avg_debt,
    MAX(debt_median) AS max_debt,
    MIN(default_rate_3yr) AS min_default,
    MAX(default_rate_3yr) AS max_default,
    MIN(earnings_10yr) AS min_earn,
    MAX(earnings_10yr) AS max_earn
FROM loan_outcomes
WHERE debt_median IS NOT NULL;

-- Verify school type distribution
SELECT 
    control_label, 
    COUNT(*) AS cnt,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM institutions), 1) AS pct
FROM institutions
GROUP BY control_label
ORDER BY cnt DESC;

-- Check for duplicate unitids
SELECT unitid, COUNT(*) AS cnt
FROM institutions
GROUP BY unitid
HAVING COUNT(*) > 1;
