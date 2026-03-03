# 📖 Data Dictionary

## Table: `institutions`
| Column | Type | Description |
|--------|------|-------------|
| unitid | INTEGER | IPEDS unique institution ID (Primary Key) |
| inst_name | TEXT | Institution name |
| state | TEXT | U.S. state abbreviation |
| control | INTEGER | 1=Public, 2=Private Non-Profit, 3=Private For-Profit |
| control_label | TEXT | Human-readable school type |
| pred_degree | INTEGER | Predominant degree: 1=Cert, 2=Assoc, 3=Bach, 4=Grad |
| degree_label | TEXT | Human-readable degree type |
| adm_rate | REAL | Admission rate (0.0 to 1.0) |
| ugds | INTEGER | Total undergraduate enrollment |
| sat_verbal_mid | INTEGER | SAT verbal section midpoint |
| sat_math_mid | INTEGER | SAT math section midpoint |
| region | TEXT | U.S. Census region (Northeast, Midwest, South, West) |

## Table: `institution_costs`
| Column | Type | Description |
|--------|------|-------------|
| unitid | INTEGER | Foreign Key → institutions |
| cost_attendance | REAL | Average annual cost of attendance ($) |
| tuition_in | REAL | In-state tuition and fees ($) |
| tuition_out | REAL | Out-of-state tuition and fees ($) |
| pct_fed_loan | REAL | % of students with federal loans (0.0-1.0) |
| pct_pell | REAL | % of students receiving Pell grants (0.0-1.0) |
| avg_net_price | REAL | Average net price after financial aid ($) |

## Table: `loan_outcomes`
| Column | Type | Description |
|--------|------|-------------|
| unitid | INTEGER | Foreign Key → institutions |
| debt_median | REAL | Median cumulative debt at graduation ($) |
| grad_debt_median | REAL | Median debt for completers only ($) |
| default_rate_3yr | REAL | 3-year cohort default rate (0.0-1.0) |
| repayment_rate_3yr | REAL | 3-year loan repayment rate (0.0-1.0) |
| repayment_rate_5yr | REAL | 5-year loan repayment rate (0.0-1.0) |
| earnings_6yr | REAL | Median earnings 6 years after enrollment ($) |
| earnings_10yr | REAL | Median earnings 10 years after enrollment ($) |
| completion_rate | REAL | 150%-time completion rate (0.0-1.0) |

## Table: `ipeds_spending` (from Part 1)
| Column | Type | Description |
|--------|------|-------------|
| unitid | INTEGER | Foreign Key → institutions |
| year | INTEGER | Academic year (2018-2023) |
| admin_spending | REAL | Administrative & general spending ($) |
| instr_spending | REAL | Instructional spending ($) |
| total_spending | REAL | Total institutional spending ($) |
| fte | INTEGER | Full-time equivalent enrollment |
| admin_pct | REAL | Admin as % of total spending |
| instr_pct | REAL | Instruction as % of total spending |
| admin_per_fte | REAL | Admin spending per FTE student ($) |
| instr_per_fte | REAL | Instruction spending per FTE student ($) |
| inst_type | TEXT | "Public" or "Private" |

## Key Derived Metrics in Queries
| Metric | Formula | Meaning |
|--------|---------|---------|
| Debt-to-Earnings Ratio | debt_median / earnings_10yr | Lower = better ROI |
| Debt Burden % | (monthly_payment / monthly_income) × 100 | >20% = severe |
| Earnings per $1K Instruction | earnings_10yr / (instr_per_fte / 1000) | Spending efficiency |
| Composite Risk Score | NTILE scores across 4 dimensions | 4-20 scale, higher = riskier |
