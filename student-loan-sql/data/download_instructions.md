# 📥 Data Download Instructions

## 1. College Scorecard Data (Primary)

### Option A: Download from Official Site (Recommended)
1. Go to: https://collegescorecard.ed.gov/data
2. Click **"All data"** → Download the ZIP file
3. Extract and find: `Most-Recent-Cohorts-Institution.csv`
4. Rename to `scorecard.csv` and place in this `/data` folder

### Option B: Download from Kaggle
1. Go to: https://www.kaggle.com/datasets/kaggle/college-scorecard
2. Download the dataset
3. Use `most-recent-cohorts.csv`

### Key Columns We Need:
| Column Name | Description |
|------------|-------------|
| `UNITID` | Unique institution ID (links to IPEDS) |
| `INSTNM` | Institution name |
| `STABBR` | State abbreviation |
| `CONTROL` | 1=Public, 2=Private Non-Profit, 3=Private For-Profit |
| `PREDDEG` | Predominant degree: 1=Certificate, 2=Associate, 3=Bachelor's, 4=Graduate |
| `UGDS` | Undergraduate enrollment |
| `COSTT4_A` | Average cost of attendance (academic year) |
| `TUITIONFEE_IN` | In-state tuition and fees |
| `TUITIONFEE_OUT` | Out-of-state tuition and fees |
| `DEBT_MDN` | Median debt at graduation |
| `GRAD_DEBT_MDN` | Median debt for completers |
| `CDR3` | 3-year cohort default rate |
| `RPY_3YR_RT_SUPP` | 3-year repayment rate |
| `RPY_5YR_RT_SUPP` | 5-year repayment rate |
| `MD_EARN_WNE_P10` | Median earnings 10 years after entry |
| `MD_EARN_WNE_P6` | Median earnings 6 years after entry |
| `C150_4` | 4-year completion rate (150% time) |
| `PCTFLOAN` | Percent receiving federal loans |
| `PCTPELL` | Percent receiving Pell grants |
| `ADM_RATE` | Admission rate |
| `SATVRMID` | SAT verbal midpoint |
| `SATMTMID` | SAT math midpoint |

## 2. IPEDS Spending Data (From Part 1)

If you have your `panel_2018_2023.csv` from the college-tuition-analysis project:
1. Copy it to this `/data` folder
2. Rename to `ipeds_spending.csv`

This allows us to JOIN spending structure data with student outcome data.

## 3. After Download

Your `/data` folder should contain:
```
data/
├── scorecard.csv              # College Scorecard data
├── ipeds_spending.csv         # IPEDS spending (from Part 1) [optional]
└── download_instructions.md   # This file
```

Then run: `python setup_db.py` to build the database.
