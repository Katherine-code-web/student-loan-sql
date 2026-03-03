-- ============================================================
-- 05_risk_analysis.sql
-- Theme 2: Default Risk Deep Dive
-- "Who is at risk, and what do high-risk schools have in common?"
-- ============================================================

-- ──────────────────────────────────────────────
-- Q6: Risk Tier Classification System
-- Skills: CTE, CASE WHEN, NTILE, multi-level logic
-- Business Value: Build a risk scoring framework
-- ──────────────────────────────────────────────
WITH risk_scored AS (
    SELECT 
        i.unitid,
        i.inst_name,
        i.state,
        i.control_label,
        lo.default_rate_3yr,
        lo.repayment_rate_3yr,
        lo.completion_rate,
        lo.earnings_10yr,
        lo.debt_median,
        -- Individual risk scores (1=best, 5=worst)
        NTILE(5) OVER (ORDER BY lo.default_rate_3yr DESC)    AS default_score,
        NTILE(5) OVER (ORDER BY lo.repayment_rate_3yr ASC)   AS repayment_score,
        NTILE(5) OVER (ORDER BY lo.completion_rate ASC)       AS completion_score,
        NTILE(5) OVER (ORDER BY lo.earnings_10yr ASC)         AS earnings_score
    FROM institutions i
    JOIN loan_outcomes lo ON i.unitid = lo.unitid
    WHERE lo.default_rate_3yr IS NOT NULL
      AND lo.repayment_rate_3yr IS NOT NULL
      AND lo.completion_rate IS NOT NULL
      AND lo.earnings_10yr IS NOT NULL
),
risk_tiered AS (
    SELECT 
        *,
        -- Composite risk score (4=lowest risk, 20=highest risk)
        (default_score + repayment_score + completion_score + earnings_score) AS composite_score,
        CASE 
            WHEN (default_score + repayment_score + completion_score + earnings_score) >= 16 
                THEN '🔴 High Risk'
            WHEN (default_score + repayment_score + completion_score + earnings_score) >= 12 
                THEN '🟡 Moderate Risk'
            WHEN (default_score + repayment_score + completion_score + earnings_score) >= 8 
                THEN '🟢 Low Risk'
            ELSE '🔵 Very Safe'
        END AS risk_tier
    FROM risk_scored
)
SELECT 
    risk_tier,
    COUNT(*)                                            AS num_schools,
    ROUND(AVG(default_rate_3yr) * 100, 1)               AS avg_default_pct,
    ROUND(AVG(repayment_rate_3yr) * 100, 1)             AS avg_repayment_pct,
    ROUND(AVG(completion_rate) * 100, 1)                AS avg_completion_pct,
    ROUND(AVG(earnings_10yr), 0)                        AS avg_earnings,
    ROUND(AVG(debt_median), 0)                          AS avg_debt
FROM risk_tiered
GROUP BY risk_tier
ORDER BY avg_default_pct DESC;


-- ──────────────────────────────────────────────
-- Q7: Top 20 Highest-Risk Schools (Named)
-- Skills: CTE reuse, detailed ranking
-- Business Value: Identify specific problem institutions
-- ──────────────────────────────────────────────
WITH risk_scored AS (
    SELECT 
        i.unitid,
        i.inst_name,
        i.state,
        i.control_label,
        i.ugds,
        lo.default_rate_3yr,
        lo.repayment_rate_3yr,
        lo.completion_rate,
        lo.earnings_10yr,
        lo.debt_median,
        NTILE(5) OVER (ORDER BY lo.default_rate_3yr DESC)    AS default_score,
        NTILE(5) OVER (ORDER BY lo.repayment_rate_3yr ASC)   AS repay_score,
        NTILE(5) OVER (ORDER BY lo.completion_rate ASC)       AS comp_score,
        NTILE(5) OVER (ORDER BY lo.earnings_10yr ASC)         AS earn_score
    FROM institutions i
    JOIN loan_outcomes lo ON i.unitid = lo.unitid
    WHERE lo.default_rate_3yr IS NOT NULL
      AND lo.repayment_rate_3yr IS NOT NULL
      AND lo.earnings_10yr IS NOT NULL
      AND i.ugds >= 200                  -- Meaningful enrollment
)
SELECT 
    RANK() OVER (
        ORDER BY (default_score + repay_score + comp_score + earn_score) DESC
    ) AS risk_rank,
    inst_name,
    state,
    control_label,
    ugds                                            AS enrollment,
    ROUND(default_rate_3yr * 100, 1)                AS default_pct,
    ROUND(repayment_rate_3yr * 100, 1)              AS repayment_pct,
    ROUND(earnings_10yr, 0)                         AS earnings,
    ROUND(debt_median, 0)                           AS debt,
    (default_score + repay_score + comp_score + earn_score) AS risk_score
FROM risk_scored
ORDER BY risk_score DESC
LIMIT 20;


-- ──────────────────────────────────────────────
-- Q8: What Do High-Default Schools Have in Common?
-- Skills: CTE, GROUP BY, comparative analysis
-- Business Value: Identify structural patterns behind risk
-- ──────────────────────────────────────────────
WITH school_groups AS (
    SELECT 
        i.*,
        lo.default_rate_3yr,
        lo.earnings_10yr,
        lo.debt_median,
        lo.completion_rate,
        ic.pct_fed_loan,
        ic.pct_pell,
        ic.cost_attendance,
        CASE 
            WHEN lo.default_rate_3yr >= 0.15 THEN 'High Default (≥15%)'
            WHEN lo.default_rate_3yr >= 0.07 THEN 'Medium Default (7-15%)'
            ELSE 'Low Default (<7%)'
        END AS default_group
    FROM institutions i
    JOIN loan_outcomes lo ON i.unitid = lo.unitid
    JOIN institution_costs ic ON i.unitid = ic.unitid
    WHERE lo.default_rate_3yr IS NOT NULL
)
SELECT 
    default_group,
    COUNT(*) AS num_schools,
    
    -- School type composition
    ROUND(100.0 * SUM(CASE WHEN control = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) 
        AS pct_public,
    ROUND(100.0 * SUM(CASE WHEN control = 2 THEN 1 ELSE 0 END) / COUNT(*), 1) 
        AS pct_private_np,
    ROUND(100.0 * SUM(CASE WHEN control = 3 THEN 1 ELSE 0 END) / COUNT(*), 1) 
        AS pct_for_profit,
    
    -- Financial profile
    ROUND(AVG(cost_attendance), 0)          AS avg_cost,
    ROUND(AVG(debt_median), 0)              AS avg_debt,
    ROUND(AVG(pct_fed_loan) * 100, 1)       AS avg_pct_loans,
    ROUND(AVG(pct_pell) * 100, 1)           AS avg_pct_pell,
    
    -- Outcomes
    ROUND(AVG(earnings_10yr), 0)            AS avg_earnings,
    ROUND(AVG(completion_rate) * 100, 1)    AS avg_completion_pct,
    
    -- Degree composition
    ROUND(100.0 * SUM(CASE WHEN pred_degree = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS pct_certificate,
    ROUND(100.0 * SUM(CASE WHEN pred_degree = 3 THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS pct_bachelors
FROM school_groups
GROUP BY default_group
ORDER BY 
    CASE default_group
        WHEN 'High Default (≥15%)' THEN 1
        WHEN 'Medium Default (7-15%)' THEN 2
        ELSE 3
    END;


-- ──────────────────────────────────────────────
-- Q9: For-Profit Schools: Are They Worth It?
-- Skills: Subquery, CASE WHEN, comparative metrics
-- Business Value: Data-driven perspective on for-profit debate
-- ──────────────────────────────────────────────
SELECT 
    i.control_label,
    i.degree_label,
    COUNT(*) AS num_schools,
    ROUND(AVG(lo.debt_median), 0)                       AS avg_debt,
    ROUND(AVG(lo.default_rate_3yr) * 100, 1)            AS avg_default_pct,
    ROUND(AVG(lo.earnings_10yr), 0)                     AS avg_earnings,
    ROUND(AVG(lo.completion_rate) * 100, 1)             AS avg_completion_pct,
    -- Net value: earnings minus debt
    ROUND(AVG(lo.earnings_10yr) - AVG(lo.debt_median), 0) AS earnings_minus_debt,
    -- Are students better off? (earnings > debt threshold)
    ROUND(100.0 * SUM(
        CASE WHEN lo.earnings_10yr > lo.debt_median * 1.5 THEN 1 ELSE 0 END
    ) / COUNT(*), 1) AS pct_good_roi
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
WHERE lo.debt_median IS NOT NULL
  AND lo.earnings_10yr IS NOT NULL
  AND i.degree_label IS NOT NULL
GROUP BY i.control_label, i.degree_label
HAVING COUNT(*) >= 10
ORDER BY i.control_label, avg_default_pct DESC;


-- ──────────────────────────────────────────────
-- Q10: Default Rate Trend Comparison — Selective vs Open Admission
-- Skills: CASE WHEN, subgroup analysis
-- Question: Do more selective schools protect students from default?
-- ──────────────────────────────────────────────
SELECT 
    CASE 
        WHEN i.adm_rate < 0.25 THEN '1. Highly Selective (<25%)'
        WHEN i.adm_rate < 0.50 THEN '2. Selective (25-50%)'
        WHEN i.adm_rate < 0.75 THEN '3. Moderate (50-75%)'
        WHEN i.adm_rate <= 1.0  THEN '4. Open (75-100%)'
        ELSE '5. Unknown'
    END AS selectivity_tier,
    COUNT(*) AS num_schools,
    ROUND(AVG(lo.default_rate_3yr) * 100, 2)    AS avg_default_pct,
    ROUND(AVG(lo.debt_median), 0)                AS avg_debt,
    ROUND(AVG(lo.earnings_10yr), 0)              AS avg_earnings,
    ROUND(AVG(lo.completion_rate) * 100, 1)      AS avg_completion_pct,
    ROUND(AVG(lo.debt_median) / NULLIF(AVG(lo.earnings_10yr), 0), 2) 
                                                 AS debt_to_earn_ratio
FROM institutions i
JOIN loan_outcomes lo ON i.unitid = lo.unitid
WHERE i.adm_rate IS NOT NULL
  AND lo.default_rate_3yr IS NOT NULL
GROUP BY selectivity_tier
ORDER BY selectivity_tier;
