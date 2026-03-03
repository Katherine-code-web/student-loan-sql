-- ============================================================
-- 01_schema.sql
-- Database Schema for Student Loan Risk Analysis
-- Author: Katherine (YUN TING SU)
-- ============================================================

-- Drop existing tables if re-running
DROP TABLE IF EXISTS loan_outcomes;
DROP TABLE IF EXISTS institution_costs;
DROP TABLE IF EXISTS ipeds_spending;
DROP TABLE IF EXISTS institutions;

-- ============================================================
-- Table 1: institutions (基本資料)
-- Core institutional information
-- ============================================================
CREATE TABLE institutions (
    unitid          INTEGER PRIMARY KEY,        -- IPEDS unique ID
    inst_name       TEXT NOT NULL,               -- Institution name
    state           TEXT,                        -- State abbreviation
    control         INTEGER,                     -- 1=Public, 2=Private NP, 3=Private FP
    control_label   TEXT,                        -- Human-readable label
    pred_degree     INTEGER,                     -- Predominant degree awarded
    degree_label    TEXT,                        -- e.g., 'Bachelor''s', 'Associate'
    adm_rate        REAL,                        -- Admission rate (0-1)
    ugds            INTEGER,                     -- Undergraduate enrollment
    sat_verbal_mid  INTEGER,                     -- SAT verbal midpoint
    sat_math_mid    INTEGER,                     -- SAT math midpoint
    region          TEXT                         -- Census region (derived from state)
);

-- ============================================================
-- Table 2: institution_costs (學費與費用)
-- Tuition, cost of attendance, financial aid
-- ============================================================
CREATE TABLE institution_costs (
    unitid          INTEGER PRIMARY KEY,
    cost_attendance REAL,                        -- Average annual cost of attendance
    tuition_in      REAL,                        -- In-state tuition
    tuition_out     REAL,                        -- Out-of-state tuition
    pct_fed_loan    REAL,                        -- % students with federal loans
    pct_pell        REAL,                        -- % students with Pell grants
    avg_net_price   REAL,                        -- Average net price after aid
    FOREIGN KEY (unitid) REFERENCES institutions(unitid)
);

-- ============================================================
-- Table 3: loan_outcomes (學貸與成果)
-- Debt, repayment, default rates, earnings
-- ============================================================
CREATE TABLE loan_outcomes (
    unitid              INTEGER PRIMARY KEY,
    debt_median         REAL,                    -- Median debt at graduation
    grad_debt_median    REAL,                    -- Median debt for completers
    default_rate_3yr    REAL,                    -- 3-year cohort default rate
    repayment_rate_3yr  REAL,                    -- 3-year repayment rate
    repayment_rate_5yr  REAL,                    -- 5-year repayment rate
    earnings_6yr        REAL,                    -- Median earnings 6 years after
    earnings_10yr       REAL,                    -- Median earnings 10 years after
    completion_rate     REAL,                    -- 150% time completion rate
    FOREIGN KEY (unitid) REFERENCES institutions(unitid)
);

-- ============================================================
-- Table 4: ipeds_spending (支出結構 — from Part 1)
-- Links to college-tuition-analysis project
-- ============================================================
CREATE TABLE ipeds_spending (
    unitid          INTEGER,
    year            INTEGER,
    admin_spending  REAL,                        -- Administrative spending
    instr_spending  REAL,                        -- Instructional spending
    research_spend  REAL,                        -- Research spending
    total_spending  REAL,                        -- Total spending
    fte             INTEGER,                     -- Full-time equivalent students
    admin_pct       REAL,                        -- Admin as % of total
    instr_pct       REAL,                        -- Instruction as % of total
    admin_per_fte   REAL,                        -- Admin spending per FTE
    instr_per_fte   REAL,                        -- Instruction spending per FTE
    inst_type       TEXT,                        -- Public / Private
    PRIMARY KEY (unitid, year),
    FOREIGN KEY (unitid) REFERENCES institutions(unitid)
);

-- ============================================================
-- Indexes for query performance
-- ============================================================
CREATE INDEX idx_inst_state ON institutions(state);
CREATE INDEX idx_inst_control ON institutions(control);
CREATE INDEX idx_loan_default ON loan_outcomes(default_rate_3yr);
CREATE INDEX idx_loan_earnings ON loan_outcomes(earnings_10yr);
CREATE INDEX idx_ipeds_year ON ipeds_spending(year);
CREATE INDEX idx_ipeds_type ON ipeds_spending(inst_type);
