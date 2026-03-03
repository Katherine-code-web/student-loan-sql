-- ============================================================
-- 04_overview_analysis.sql
-- Theme 1: Student Loan Landscape Overview
-- "How much do students borrow across the U.S.?"
-- ============================================================

-- ──────────────────────────────────────────────
-- Q1: State-Level Loan Burden Ranking
-- Skills: JOIN, Window Function (RANK), Aggregation
-- Question: Which states have the highest median student debt?
-- ──────────────────────────────────────────────
SELECT 
    i.state,
    COUNT(*)                                    AS num_schools,
    ROUND(AVG(lo.debt_median), 0)               AS avg_median_debt,
    ROUND(AVG(lo.default_rate_3yr) * 100, 1)    AS avg_default_rate_pct,
    ROUND(AVG(lo.earnings_10yr), 0)             AS avg_earnings_10yr,
    RANK() OVER (ORDER BY AVG(lo.debt_median) DESC) AS debt_rank
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
WHERE lo.debt_median IS NOT NULL
GROUP BY i.state
HAVING COUNT(*) >= 10          -- Only states with sufficient data
ORDER BY avg_median_debt DESC
LIMIT 20;


-- ──────────────────────────────────────────────
-- Q2: Public vs Private Non-Profit vs For-Profit Comparison
-- Skills: GROUP BY, CASE WHEN, multiple aggregations
-- Question: How do debt & outcomes differ by school type?
-- ──────────────────────────────────────────────
SELECT 
    i.control_label                                     AS school_type,
    COUNT(*)                                            AS num_schools,
    ROUND(AVG(lo.debt_median), 0)                       AS avg_debt,
    ROUND(AVG(lo.default_rate_3yr) * 100, 1)            AS avg_default_pct,
    ROUND(AVG(lo.repayment_rate_3yr) * 100, 1)          AS avg_repayment_pct,
    ROUND(AVG(lo.earnings_10yr), 0)                     AS avg_earnings_10yr,
    ROUND(AVG(lo.completion_rate) * 100, 1)             AS avg_completion_pct,
    ROUND(AVG(ic.pct_fed_loan) * 100, 1)                AS avg_pct_with_loans,
    -- Debt-to-Earnings Ratio (lower = better)
    ROUND(AVG(lo.debt_median) / NULLIF(AVG(lo.earnings_10yr), 0), 2) AS debt_to_earnings
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
JOIN institution_costs ic ON i.unitid = ic.unitid
WHERE lo.debt_median IS NOT NULL
GROUP BY i.control_label
ORDER BY avg_default_pct DESC;


-- ──────────────────────────────────────────────
-- Q3: Debt Distribution by Degree Level
-- Skills: CASE WHEN, grouped aggregation
-- Question: Do Bachelor's programs lead to more debt than Associate's?
-- ──────────────────────────────────────────────
SELECT 
    i.degree_label                              AS degree_type,
    COUNT(*)                                    AS num_schools,
    ROUND(AVG(lo.debt_median), 0)               AS avg_debt,
    ROUND(MIN(lo.debt_median), 0)               AS min_debt,
    ROUND(MAX(lo.debt_median), 0)               AS max_debt,
    ROUND(AVG(lo.earnings_10yr), 0)             AS avg_earnings,
    ROUND(AVG(lo.completion_rate) * 100, 1)     AS avg_completion_pct,
    -- Payback period estimate (years)
    ROUND(AVG(lo.debt_median) / NULLIF(AVG(lo.earnings_10yr) * 0.1, 0), 1) 
                                                AS est_payback_years
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
WHERE lo.debt_median IS NOT NULL
  AND i.degree_label IS NOT NULL
GROUP BY i.degree_label
ORDER BY avg_debt DESC;


-- ──────────────────────────────────────────────
-- Q4: Regional Comparison with Multiple Metrics
-- Skills: JOIN, Window Function (DENSE_RANK), Subquery
-- Question: Which U.S. regions have the best/worst student outcomes?
-- ──────────────────────────────────────────────
SELECT 
    i.region,
    COUNT(*)                                            AS num_schools,
    ROUND(AVG(lo.debt_median), 0)                       AS avg_debt,
    ROUND(AVG(lo.default_rate_3yr) * 100, 1)            AS avg_default_pct,
    ROUND(AVG(lo.earnings_10yr), 0)                     AS avg_earnings,
    DENSE_RANK() OVER (ORDER BY AVG(lo.earnings_10yr) DESC)   AS earnings_rank,
    DENSE_RANK() OVER (ORDER BY AVG(lo.default_rate_3yr))     AS safety_rank
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
WHERE i.region IS NOT NULL
  AND lo.debt_median IS NOT NULL
GROUP BY i.region
ORDER BY avg_earnings DESC;


-- ──────────────────────────────────────────────
-- Q5: Top 20 Schools with Highest Debt Burden
-- Skills: Multiple JOINs, composite sorting
-- Question: Which specific schools send students out with the most debt?
-- ──────────────────────────────────────────────
SELECT 
    i.inst_name,
    i.state,
    i.control_label,
    ROUND(lo.debt_median, 0)                    AS median_debt,
    ROUND(lo.default_rate_3yr * 100, 1)         AS default_rate_pct,
    ROUND(lo.earnings_10yr, 0)                  AS earnings_10yr,
    ROUND(lo.completion_rate * 100, 1)          AS completion_pct,
    ROUND(ic.cost_attendance, 0)                AS cost_attendance,
    -- Flag: high debt + low earnings = danger zone
    CASE 
        WHEN lo.debt_median > 30000 AND lo.earnings_10yr < 40000 
            THEN '⚠️ HIGH RISK'
        WHEN lo.debt_median > 25000 AND lo.earnings_10yr < 50000 
            THEN '⚡ MODERATE'
        ELSE '✅ OK'
    END AS risk_flag
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
JOIN institution_costs ic ON i.unitid = ic.unitid
WHERE lo.debt_median IS NOT NULL
  AND lo.earnings_10yr IS NOT NULL
  AND i.ugds >= 500                 -- Focus on meaningful-size schools
ORDER BY lo.debt_median DESC
LIMIT 20;
