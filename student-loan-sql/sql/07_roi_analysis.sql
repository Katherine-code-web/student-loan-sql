-- ============================================================
-- 07_roi_analysis.sql
-- Theme 4: Return on Investment — Is College Worth It?
-- "Which schools give students the best financial return?"
-- ============================================================

-- ──────────────────────────────────────────────
-- Q15: College ROI Scorecard — Composite Ranking
-- Skills: CTE, Window Function (NTILE, RANK), composite scoring
-- Business Value: Actionable school ranking for prospective students
-- ──────────────────────────────────────────────
WITH roi_metrics AS (
    SELECT 
        i.unitid,
        i.inst_name,
        i.state,
        i.control_label,
        i.degree_label,
        i.ugds,
        lo.debt_median,
        lo.earnings_10yr,
        lo.default_rate_3yr,
        lo.completion_rate,
        lo.repayment_rate_3yr,
        ic.cost_attendance,
        -- Core ROI metric: earnings-to-debt ratio
        ROUND(lo.earnings_10yr / NULLIF(lo.debt_median, 0), 2) AS earnings_to_debt,
        -- Net gain: 10-year earnings minus total cost
        ROUND(lo.earnings_10yr - lo.debt_median, 0) AS net_gain
    FROM institutions i
    JOIN loan_outcomes lo ON i.unitid = lo.unitid
    JOIN institution_costs ic ON i.unitid = ic.unitid
    WHERE lo.earnings_10yr IS NOT NULL
      AND lo.debt_median IS NOT NULL
      AND lo.debt_median > 0
      AND i.ugds >= 500
      AND i.pred_degree = 3            -- Bachelor's degree schools
),
scored AS (
    SELECT 
        *,
        -- Score each dimension (5 = best)
        NTILE(5) OVER (ORDER BY earnings_to_debt)          AS roi_score,
        NTILE(5) OVER (ORDER BY default_rate_3yr DESC)     AS safety_score,
        NTILE(5) OVER (ORDER BY completion_rate)            AS completion_score,
        NTILE(5) OVER (ORDER BY repayment_rate_3yr)         AS repay_score
    FROM roi_metrics
)
SELECT 
    RANK() OVER (
        ORDER BY (roi_score + safety_score + completion_score + repay_score) DESC
    ) AS overall_rank,
    inst_name,
    state,
    control_label,
    ROUND(debt_median, 0)                       AS debt,
    ROUND(earnings_10yr, 0)                     AS earnings_10yr,
    earnings_to_debt                            AS earn_debt_ratio,
    ROUND(default_rate_3yr * 100, 1)            AS default_pct,
    ROUND(completion_rate * 100, 1)             AS completion_pct,
    (roi_score + safety_score + completion_score + repay_score) AS total_score
FROM scored
ORDER BY total_score DESC, earnings_to_debt DESC
LIMIT 30;


-- ──────────────────────────────────────────────
-- Q16: Best Value Schools by State
-- Skills: Window Function (ROW_NUMBER + PARTITION BY), filtering
-- Question: What's the best college ROI in each state?
-- ──────────────────────────────────────────────
WITH state_ranked AS (
    SELECT 
        i.inst_name,
        i.state,
        i.control_label,
        ROUND(lo.debt_median, 0)                            AS debt,
        ROUND(lo.earnings_10yr, 0)                          AS earnings,
        ROUND(lo.earnings_10yr / NULLIF(lo.debt_median, 0), 2) AS earn_debt_ratio,
        ROUND(lo.default_rate_3yr * 100, 1)                 AS default_pct,
        ROUND(lo.completion_rate * 100, 1)                  AS completion_pct,
        ROW_NUMBER() OVER (
            PARTITION BY i.state 
            ORDER BY (lo.earnings_10yr / NULLIF(lo.debt_median, 0)) DESC
        ) AS state_rank
    FROM institutions i
    JOIN loan_outcomes lo ON i.unitid = lo.unitid
    WHERE lo.earnings_10yr IS NOT NULL
      AND lo.debt_median IS NOT NULL
      AND lo.debt_median > 0
      AND i.ugds >= 300
      AND i.pred_degree IN (2, 3)      -- Associate's or Bachelor's
)
SELECT *
FROM state_ranked
WHERE state_rank <= 3               -- Top 3 per state
ORDER BY state, state_rank;


-- ──────────────────────────────────────────────
-- Q17: Debt Burden Index — Who's Drowning?
-- Skills: Subquery, calculated fields, risk classification
-- Metric: Debt as % of first-year earnings (>20% = concerning)
-- ──────────────────────────────────────────────
SELECT 
    i.inst_name,
    i.state,
    i.control_label,
    ROUND(lo.debt_median, 0)                    AS debt,
    ROUND(lo.earnings_6yr, 0)                   AS earnings_6yr,
    -- Debt burden: monthly payment as % of monthly income
    -- Assuming 10-year repayment at 5% interest
    ROUND(
        (lo.debt_median * 0.0053) /             -- Monthly payment (approx)
        NULLIF(lo.earnings_6yr / 12, 0) * 100   -- Monthly income
    , 1) AS debt_burden_pct,
    CASE 
        WHEN (lo.debt_median * 0.0053) / NULLIF(lo.earnings_6yr / 12, 0) > 0.20 
            THEN '🔴 Severe (>20%)'
        WHEN (lo.debt_median * 0.0053) / NULLIF(lo.earnings_6yr / 12, 0) > 0.10 
            THEN '🟡 Heavy (10-20%)'
        ELSE '🟢 Manageable (<10%)'
    END AS burden_level,
    ROUND(lo.default_rate_3yr * 100, 1)         AS default_pct
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
WHERE lo.debt_median IS NOT NULL
  AND lo.earnings_6yr IS NOT NULL
  AND lo.earnings_6yr > 0
  AND i.ugds >= 500
ORDER BY debt_burden_pct DESC
LIMIT 30;


-- ──────────────────────────────────────────────
-- Q18: The Million Dollar Question — 
--       Expensive Schools vs. Affordable Schools: Who Wins?
-- Skills: CTE with NTILE, grouped comparison
-- ──────────────────────────────────────────────
WITH cost_tiers AS (
    SELECT 
        i.unitid,
        i.inst_name,
        i.control_label,
        ic.cost_attendance,
        lo.debt_median,
        lo.earnings_10yr,
        lo.default_rate_3yr,
        lo.completion_rate,
        NTILE(4) OVER (ORDER BY ic.cost_attendance) AS cost_quartile
    FROM institutions i
    JOIN institution_costs ic ON i.unitid = ic.unitid
    JOIN loan_outcomes lo ON i.unitid = lo.unitid
    WHERE ic.cost_attendance IS NOT NULL
      AND lo.earnings_10yr IS NOT NULL
      AND lo.debt_median IS NOT NULL
      AND i.pred_degree = 3
)
SELECT 
    CASE cost_quartile
        WHEN 1 THEN '💚 Q1: Most Affordable'
        WHEN 2 THEN '💛 Q2: Below Average Cost'
        WHEN 3 THEN '🟠 Q3: Above Average Cost'
        WHEN 4 THEN '❤️ Q4: Most Expensive'
    END AS cost_tier,
    COUNT(*) AS num_schools,
    ROUND(AVG(cost_attendance), 0)              AS avg_cost,
    ROUND(AVG(debt_median), 0)                  AS avg_debt,
    ROUND(AVG(earnings_10yr), 0)                AS avg_earnings,
    ROUND(AVG(default_rate_3yr) * 100, 1)       AS avg_default_pct,
    ROUND(AVG(completion_rate) * 100, 1)        AS avg_completion_pct,
    -- ROI ratio
    ROUND(AVG(earnings_10yr) / NULLIF(AVG(debt_median), 0), 2) AS roi_ratio,
    -- Net value
    ROUND(AVG(earnings_10yr) - AVG(debt_median), 0) AS net_value
FROM cost_tiers
GROUP BY cost_quartile
ORDER BY cost_quartile;


-- ──────────────────────────────────────────────
-- Q19: Hidden Gems — High Earnings, Low Debt, Under the Radar
-- Skills: Multiple conditions, subquery filtering
-- Business Value: Actionable recommendations for students
-- ──────────────────────────────────────────────
SELECT 
    i.inst_name,
    i.state,
    i.control_label,
    i.ugds                                      AS enrollment,
    ROUND(lo.debt_median, 0)                    AS debt,
    ROUND(lo.earnings_10yr, 0)                  AS earnings_10yr,
    ROUND(lo.earnings_10yr / lo.debt_median, 1) AS roi_ratio,
    ROUND(lo.default_rate_3yr * 100, 1)         AS default_pct,
    ROUND(lo.completion_rate * 100, 1)          AS completion_pct,
    ROUND(ic.cost_attendance, 0)                AS cost
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
JOIN institution_costs ic ON i.unitid = ic.unitid
WHERE 
    -- High outcomes
    lo.earnings_10yr > (SELECT AVG(earnings_10yr) * 1.2 FROM loan_outcomes WHERE earnings_10yr IS NOT NULL)
    -- Low debt
    AND lo.debt_median < (SELECT AVG(debt_median) FROM loan_outcomes WHERE debt_median IS NOT NULL)
    -- Low default
    AND lo.default_rate_3yr < 0.05
    -- Decent completion
    AND lo.completion_rate > 0.50
    -- Not tiny
    AND i.ugds >= 500
    -- Affordable
    AND ic.cost_attendance < (SELECT AVG(cost_attendance) * 1.1 FROM institution_costs WHERE cost_attendance IS NOT NULL)
ORDER BY roi_ratio DESC
LIMIT 20;


-- ──────────────────────────────────────────────
-- Q20: Summary Dashboard View — Key Metrics at a Glance
-- Skills: UNION ALL, aggregation, full dataset summary
-- Purpose: Quick reference numbers for README and presentation
-- ──────────────────────────────────────────────
SELECT '🏫 Total Institutions' AS metric, 
       CAST(COUNT(*) AS TEXT) AS value 
FROM institutions

UNION ALL

SELECT '📊 With Loan Data', 
       CAST(COUNT(*) AS TEXT) 
FROM loan_outcomes WHERE debt_median IS NOT NULL

UNION ALL

SELECT '💰 Overall Median Debt', 
       '$' || CAST(ROUND(AVG(debt_median), 0) AS TEXT) 
FROM loan_outcomes WHERE debt_median IS NOT NULL

UNION ALL

SELECT '📉 Overall Avg Default Rate', 
       CAST(ROUND(AVG(default_rate_3yr) * 100, 1) AS TEXT) || '%' 
FROM loan_outcomes WHERE default_rate_3yr IS NOT NULL

UNION ALL

SELECT '💵 Overall Median Earnings (10yr)', 
       '$' || CAST(ROUND(AVG(earnings_10yr), 0) AS TEXT) 
FROM loan_outcomes WHERE earnings_10yr IS NOT NULL

UNION ALL

SELECT '🔴 High-Risk Schools (Default >15%)', 
       CAST(COUNT(*) AS TEXT) 
FROM loan_outcomes WHERE default_rate_3yr > 0.15

UNION ALL

SELECT '🟢 Low-Risk Schools (Default <5%)', 
       CAST(COUNT(*) AS TEXT) 
FROM loan_outcomes WHERE default_rate_3yr < 0.05;
