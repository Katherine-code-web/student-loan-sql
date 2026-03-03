"""
setup_db.py — Import College Scorecard CSV into SQLite database
Run: python setup_db.py
"""
import sqlite3
import pandas as pd
import os
import sys

DB_PATH = 'student_loans.db'
DATA_DIR = 'data'
SCORECARD_FILE = os.path.join(DATA_DIR, 'scorecard.csv')
IPEDS_FILE = os.path.join(DATA_DIR, 'ipeds_spending.csv')

# State → Region mapping
REGION_MAP = {
    'CT': 'Northeast', 'ME': 'Northeast', 'MA': 'Northeast', 'NH': 'Northeast',
    'RI': 'Northeast', 'VT': 'Northeast', 'NJ': 'Northeast', 'NY': 'Northeast', 'PA': 'Northeast',
    'IL': 'Midwest', 'IN': 'Midwest', 'MI': 'Midwest', 'OH': 'Midwest', 'WI': 'Midwest',
    'IA': 'Midwest', 'KS': 'Midwest', 'MN': 'Midwest', 'MO': 'Midwest',
    'NE': 'Midwest', 'ND': 'Midwest', 'SD': 'Midwest',
    'DE': 'South', 'FL': 'South', 'GA': 'South', 'MD': 'South', 'NC': 'South',
    'SC': 'South', 'VA': 'South', 'DC': 'South', 'WV': 'South',
    'AL': 'South', 'KY': 'South', 'MS': 'South', 'TN': 'South',
    'AR': 'South', 'LA': 'South', 'OK': 'South', 'TX': 'South',
    'AZ': 'West', 'CO': 'West', 'ID': 'West', 'MT': 'West', 'NV': 'West',
    'NM': 'West', 'UT': 'West', 'WY': 'West', 'AK': 'West', 'CA': 'West',
    'HI': 'West', 'OR': 'West', 'WA': 'West',
}

CONTROL_LABELS = {1: 'Public', 2: 'Private Non-Profit', 3: 'Private For-Profit'}
DEGREE_LABELS = {
    0: 'Not classified', 1: 'Certificate', 2: "Associate's",
    3: "Bachelor's", 4: 'Graduate'
}

def safe_numeric(val):
    """Convert to float, treating 'NULL', 'PrivacySuppressed' as None."""
    if pd.isna(val) or val in ('NULL', 'PrivacySuppressed'):
        return None
    try:
        return float(val)
    except (ValueError, TypeError):
        return None

def load_scorecard(filepath):
    """Load and clean College Scorecard CSV."""
    print(f"📖 Reading {filepath}...")
    df = pd.read_csv(filepath, low_memory=False, na_values=['NULL', 'PrivacySuppressed'])

    # Standardize column names to uppercase
    df.columns = df.columns.str.upper()

    # Select and rename columns
    cols_map = {
        'UNITID': 'unitid', 'INSTNM': 'inst_name', 'STABBR': 'state',
        'CONTROL': 'control', 'PREDDEG': 'pred_degree', 'ADM_RATE': 'adm_rate',
        'UGDS': 'ugds', 'SATVRMID': 'sat_verbal_mid', 'SATMTMID': 'sat_math_mid',
        'COSTT4_A': 'cost_attendance', 'TUITIONFEE_IN': 'tuition_in',
        'TUITIONFEE_OUT': 'tuition_out', 'PCTFLOAN': 'pct_fed_loan',
        'PCTPELL': 'pct_pell', 'NPT4_PUB': 'avg_net_price_pub',
        'NPT4_PRIV': 'avg_net_price_priv',
        'DEBT_MDN': 'debt_median', 'GRAD_DEBT_MDN': 'grad_debt_median',
        'CDR3': 'default_rate_3yr',
        'RPY_3YR_RT_SUPP': 'repayment_rate_3yr',
        'RPY_5YR_RT_SUPP': 'repayment_rate_5yr',
        'MD_EARN_WNE_P6': 'earnings_6yr', 'MD_EARN_WNE_P10': 'earnings_10yr',
        'C150_4': 'completion_rate',
    }

    available = {k: v for k, v in cols_map.items() if k in df.columns}
    df_clean = df[list(available.keys())].rename(columns=available)

    # Convert numeric columns
    numeric_cols = ['adm_rate', 'ugds', 'sat_verbal_mid', 'sat_math_mid',
                    'cost_attendance', 'tuition_in', 'tuition_out',
                    'pct_fed_loan', 'pct_pell', 'debt_median', 'grad_debt_median',
                    'default_rate_3yr', 'repayment_rate_3yr', 'repayment_rate_5yr',
                    'earnings_6yr', 'earnings_10yr', 'completion_rate']
    for col in numeric_cols:
        if col in df_clean.columns:
            df_clean[col] = df_clean[col].apply(safe_numeric)

    # Add derived columns
    df_clean['control'] = pd.to_numeric(df_clean['control'], errors='coerce')
    df_clean['control_label'] = df_clean['control'].map(CONTROL_LABELS)
    df_clean['pred_degree'] = pd.to_numeric(df_clean['pred_degree'], errors='coerce')
    df_clean['degree_label'] = df_clean['pred_degree'].map(DEGREE_LABELS)
    df_clean['region'] = df_clean['state'].map(REGION_MAP)

    # Combine net price
    if 'avg_net_price_pub' in df_clean.columns:
        df_clean['avg_net_price'] = df_clean['avg_net_price_pub'].fillna(df_clean.get('avg_net_price_priv'))
    else:
        df_clean['avg_net_price'] = None

    print(f"   ✅ Loaded {len(df_clean)} institutions")
    return df_clean

def insert_data(conn, df):
    """Insert cleaned data into normalized tables."""
    cur = conn.cursor()

    # institutions
    inst_cols = ['unitid', 'inst_name', 'state', 'control', 'control_label',
                 'pred_degree', 'degree_label', 'adm_rate', 'ugds',
                 'sat_verbal_mid', 'sat_math_mid', 'region']
    inst_df = df[[c for c in inst_cols if c in df.columns]].drop_duplicates('unitid')
    inst_df.to_sql('institutions', conn, if_exists='replace', index=False)
    print(f"   📌 institutions: {len(inst_df)} rows")

    # institution_costs
    cost_cols = ['unitid', 'cost_attendance', 'tuition_in', 'tuition_out',
                 'pct_fed_loan', 'pct_pell', 'avg_net_price']
    cost_df = df[[c for c in cost_cols if c in df.columns]].drop_duplicates('unitid')
    cost_df.to_sql('institution_costs', conn, if_exists='replace', index=False)
    print(f"   💰 institution_costs: {len(cost_df)} rows")

    # loan_outcomes
    loan_cols = ['unitid', 'debt_median', 'grad_debt_median', 'default_rate_3yr',
                 'repayment_rate_3yr', 'repayment_rate_5yr', 'earnings_6yr',
                 'earnings_10yr', 'completion_rate']
    loan_df = df[[c for c in loan_cols if c in df.columns]].drop_duplicates('unitid')
    loan_df.to_sql('loan_outcomes', conn, if_exists='replace', index=False)
    print(f"   📊 loan_outcomes: {len(loan_df)} rows")

def load_ipeds(conn, filepath):
    """Load IPEDS spending data from Part 1 (optional)."""
    if not os.path.exists(filepath):
        print(f"   ⚠️  IPEDS file not found at {filepath} — skipping (optional)")
        return
    print(f"📖 Reading IPEDS data from {filepath}...")
    df = pd.read_csv(filepath, low_memory=False)
    df.to_sql('ipeds_spending', conn, if_exists='replace', index=False)
    print(f"   📌 ipeds_spending: {len(df)} rows")

def main():
    if not os.path.exists(SCORECARD_FILE):
        print(f"❌ File not found: {SCORECARD_FILE}")
        print(f"   Please download the College Scorecard data first.")
        print(f"   See data/download_instructions.md for details.")
        sys.exit(1)

    # Remove old database
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)

    # Load and insert scorecard data
    df = load_scorecard(SCORECARD_FILE)
    insert_data(conn, df)

    # Load IPEDS data (optional — from Part 1)
    load_ipeds(conn, IPEDS_FILE)

    # Verify
    cur = conn.cursor()
    print("\n📋 Database Summary:")
    for table in ['institutions', 'institution_costs', 'loan_outcomes', 'ipeds_spending']:
        try:
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            count = cur.fetchone()[0]
            print(f"   {table}: {count:,} rows")
        except:
            print(f"   {table}: (not loaded)")

    conn.close()
    print(f"\n✅ Database created: {DB_PATH}")
    print(f"   Now run the SQL analysis files in sql/ folder!")

if __name__ == '__main__':
    main()
