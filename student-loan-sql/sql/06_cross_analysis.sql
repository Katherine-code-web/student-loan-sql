-- ============================================================
-- 06_cross_analysis.sql
-- Theme 3: Spending Structure × Student Outcomes
-- "Does how a school spends money affect student debt & success?"
-- 🔗 Links directly to Part 1 (college-tuition-analysis)
-- ============================================================

-- ──────────────────────────────────────────────
-- Q11: Admin-Heavy Schools → Higher Default Rates?
-- Skills: CTE, JOIN across datasets, CASE WHEN grouping
-- Hypothesis: Schools spending more on admin have worse outcomes
-- (Tests Part 1 finding: admin share ↑ 3.8%)
-- ──────────────────────────────────────────────
WITH latest_spending AS (
    -- Get most recent year's spending data per school
    SELECT 
        unitid,
        admin_pct,
        instr_pct,
        admin_per_fte,
        instr_per_fte,
        inst_type,
        ROW_NUMBER() OVER (PARTITION BY unitid ORDER BY year DESC) AS rn
    FROM ipeds_spending
    WHERE admin_pct IS NOT NULL
),
spending_current AS (
    SELECT * FROM latest_spending WHERE rn = 1
),
admin_groups AS (
    SELECT 
        sc.*,
        lo.default_rate_3yr,
        lo.earnings_10yr,
        lo.debt_median,
        lo.completion_rate,
        lo.repayment_rate_3yr,
        CASE 
            WHEN sc.admin_pct > 0.25 THEN '🔴 High Admin (>25%)'
            WHEN sc.admin_pct > 0.18 THEN '🟡 Medium Admin (18-25%)'
            ELSE '🟢 Low Admin (<18%)'
        END AS admin_tier
    FROM spending_current sc
    JOIN loan_outcomes lo ON sc.unitid = lo.unitid
    WHERE lo.default_rate_3yr IS NOT NULL
)
SELECT 
    admin_tier,
    COUNT(*) AS num_schools,
    ROUND(AVG(admin_pct) * 100, 1)              AS avg_admin_pct,
    ROUND(AVG(instr_pct) * 100, 1)              AS avg_instr_pct,
    ROUND(AVG(default_rate_3yr) * 100, 1)       AS avg_default_pct,
    ROUND(AVG(repayment_rate_3yr) * 100, 1)     AS avg_repayment_pct,
    ROUND(AVG(earnings_10yr), 0)                AS avg_earnings,
    ROUND(AVG(completion_rate) * 100, 1)        AS avg_completion_pct,
    ROUND(AVG(debt_median), 0)                  AS avg_debt
FROM admin_groups
GROUP BY admin_tier
ORDER BY avg_default_pct DESC;


-- ──────────────────────────────────────────────
-- Q12: Instruction Spending Change vs. Student Outcomes
-- Skills: Window Function (LAG), CTE, JOIN
-- Hypothesis: Schools that cut instruction spending → worse outcomes
-- (Tests Part 1 finding: instruction per FTE ↓ 12.6%)
-- ──────────────────────────────────────────────
WITH spending_change AS (
    SELECT 
        unitid,
        year,
        instr_per_fte,
        LAG(instr_per_fte) OVER (PARTITION BY unitid ORDER BY year) AS prev_instr_fte,
        -- Year-over-year change
        ROUND(
            (instr_per_fte - LAG(instr_per_fte) OVER (PARTITION BY unitid ORDER BY year))
            / NULLIF(LAG(instr_per_fte) OVER (PARTITION BY unitid ORDER BY year), 0) * 100
        , 1) AS instr_change_pct
    FROM ipeds_spending
),
-- Get the average change over the period
avg_change AS (
    SELECT 
        unitid,
        AVG(instr_change_pct) AS avg_annual_change
    FROM spending_change
    WHERE instr_change_pct IS NOT NULL
    GROUP BY unitid
),
change_groups AS (
    SELECT 
        ac.unitid,
        ac.avg_annual_change,
        lo.default_rate_3yr,
        lo.earnings_10yr,
        lo.completion_rate,
        lo.debt_median,
        CASE 
            WHEN ac.avg_annual_change < -5 THEN '📉 Big Cut (>5% decline)'
            WHEN ac.avg_annual_change < 0  THEN '📉 Small Cut (0-5% decline)'
            WHEN ac.avg_annual_change < 5  THEN '📈 Small Increase (0-5%)'
            ELSE '📈 Big Increase (>5%)'
        END AS spending_trend
    FROM avg_change ac
    JOIN loan_outcomes lo ON ac.unitid = lo.unitid
    WHERE lo.default_rate_3yr IS NOT NULL
      AND lo.earnings_10yr IS NOT NULL
)
SELECT 
    spending_trend,
    COUNT(*) AS num_schools,
    ROUND(AVG(avg_annual_change), 1)            AS avg_change_pct,
    ROUND(AVG(default_rate_3yr) * 100, 1)       AS avg_default_pct,
    ROUND(AVG(earnings_10yr), 0)                AS avg_earnings,
    ROUND(AVG(completion_rate) * 100, 1)        AS avg_completion_pct,
    ROUND(AVG(debt_median), 0)                  AS avg_debt
FROM change_groups
GROUP BY spending_trend
ORDER BY avg_change_pct;


-- ──────────────────────────────────────────────
-- Q13: Instruction Spending Efficiency — $1 Spent = ? Earnings
-- Skills: JOIN, calculated metrics, ranking
-- Question: Which schools get the most "bang for the buck" in instruction?
-- ──────────────────────────────────────────────
WITH latest_spending AS (
    SELECT unitid, instr_per_fte, admin_per_fte, inst_type,
           ROW_NUMBER() OVER (PARTITION BY unitid ORDER BY year DESC) AS rn
    FROM ipeds_spending
    WHERE instr_per_fte IS NOT NULL AND instr_per_fte > 0
),
efficiency AS (
    SELECT 
        i.inst_name,
        i.state,
        i.control_label,
        sp.instr_per_fte,
        sp.admin_per_fte,
        lo.earnings_10yr,
        lo.debt_median,
        lo.default_rate_3yr,
        lo.completion_rate,
        -- Earnings per $1,000 of instruction spending
        ROUND(lo.earnings_10yr / (sp.instr_per_fte / 1000), 1) AS earnings_per_1k_instr,
        -- Admin overhead ratio
        ROUND(sp.admin_per_fte / NULLIF(sp.instr_per_fte, 0), 2) AS admin_to_instr_ratio
    FROM latest_spending sp
    JOIN institutions i ON sp.unitid = i.unitid
    JOIN loan_outcomes lo ON sp.unitid = lo.unitid
    WHERE sp.rn = 1
      AND lo.earnings_10yr IS NOT NULL
      AND i.ugds >= 500
)
SELECT 
    *,
    RANK() OVER (ORDER BY earnings_per_1k_instr DESC) AS efficiency_rank
FROM efficiency
ORDER BY earnings_per_1k_instr DESC
LIMIT 25;


-- ──────────────────────────────────────────────
-- Q14: Public vs Private — Spending Matters Differently?
-- Skills: CTE, GROUP BY multiple dimensions, CASE
-- Tests Part 1 finding: Private admin share is 1.9× Public
-- ──────────────────────────────────────────────
WITH latest AS (
    SELECT unitid, admin_pct, instr_pct, inst_type,
           ROW_NUMBER() OVER (PARTITION BY unitid ORDER BY year DESC) AS rn
    FROM ipeds_spending
),
combined AS (
    SELECT 
        sp.inst_type,
        CASE 
            WHEN sp.admin_pct > 0.20 THEN 'Admin Heavy (>20%)'
            ELSE 'Admin Lean (≤20%)'
        END AS admin_category,
        lo.default_rate_3yr,
        lo.earnings_10yr,
        lo.completion_rate,
        lo.debt_median
    FROM latest sp
    JOIN loan_outcomes lo ON sp.unitid = lo.unitid
    WHERE sp.rn = 1
      AND sp.admin_pct IS NOT NULL
      AND lo.default_rate_3yr IS NOT NULL
)
SELECT 
    inst_type,
    admin_category,
    COUNT(*) AS num_schools,
    ROUND(AVG(default_rate_3yr) * 100, 1)       AS avg_default_pct,
    ROUND(AVG(earnings_10yr), 0)                AS avg_earnings,
    ROUND(AVG(completion_rate) * 100, 1)        AS avg_completion_pct,
    ROUND(AVG(debt_median), 0)                  AS avg_debt
FROM combined
GROUP BY inst_type, admin_category
ORDER BY inst_type, admin_category;
