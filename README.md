# Card Fraud, Credit Risk & Portfolio Analytics

An end-to-end analytics project on a **synthetic** retail credit card portfolio: a MySQL 8.0 database, 100 business SQL questions, automated data-quality checks, and matching dashboards in Power BI and Tableau.

> **All data in this repository is synthetic.** Every record was generated for this project. It is **not Barclays data**, not real customer information, and does not reflect Barclays' internal methodology. The project is inspired by common retail banking challenges.

---

## Dashboards

| Page | Power BI | Tableau |
|---|---|---|
| Fraud Overview / Timing & Concentration | ![Power BI fraud overview](FRAUD%20OVERVIEW%20-%20POWERBI%20DASHBOARD.png) | ![Tableau fraud timing](FRAUD%20TIMING%20%26%20CONCENTRATION%20-%20TABLEAU%20DASHBOARD.png) |
| Credit Risk & Collections | ![Power BI credit risk](CREDIT%20RISK%20%26%20COLLECTIONS%20-%20POWERBI%20DASHBOARD.png) | ![Tableau credit risk](CREDIT%20RISK%20%26%20COLLECTIONS%20-%20TABLEAU%20DASHBOARD.png) |
| Portfolio & Strategy | ![Power BI portfolio](PORTFOLIO%20%26%20STRATEGIES%20-%20POWERBI%20DASHBOARD.png) | ![Tableau portfolio](PORTFOLIO%20%26%20STRATEGIES%20-%20TABLEAU%20DASHBOARD.png) |

**Interactive Tableau dashboards:** [Tableau Public link](https://public.tableau.com/) *(replace with your published workbook link)*

**Headline figures (reporting period 1 Oct 2021 to 30 Sep 2026, as-of 30 Sep 2026):**

| Measure | Value |
|---|---|
| Fraud-labelled share of transactions | 1.8% |
| Fraud-labelled value | £557,155 |
| 30+ days-past-due rate (payment obligations) | 1.4% |
| Overdue amount | £217,011 |
| Total transaction value | £13,585,136 |

---

## Business problems

1. **Fraud detection and loss analysis:** where fraud concentrates by channel, merchant category, location, time and amount band.
2. **Credit risk and account segmentation:** utilisation, credit-score and income bands, and transparent rule-based risk tiers.
3. **Payment delinquency and collections:** DPD buckets, collection rate, overdue ageing and collection priorities.
4. **Transaction monitoring and suspicious behaviour:** baseline deviations, velocity, repeat patterns and the false-positive trade-off of monitoring thresholds.
5. **Portfolio performance and strategy:** volume and value trends, account status, utilisation, exposure and a management scorecard.

Each problem has 20 questions (Q001 to Q100), each with a business rationale, executable MySQL solution and interpretation guide. See `docs/QUESTIONS_AND_SOLUTIONS.html`.

---

## Dataset

| Item | Detail |
|---|---|
| Reporting period | 1 October 2021 to 30 September 2026 (exactly 60 calendar months) |
| As-of date | 30 September 2026 (used for days past due) |
| Customers | 10,000+ |
| Accounts | 12,000 to 18,000 |
| Transactions | about 150,000 |
| Payment obligations | about 327,000 |
| Merchants | 25 to 30 |
| Random seed | Fixed, so the dataset regenerates identically |

Dates are generated from the underlying events and business rules: account opening, billing cycles, due dates and payment dates are kept logically consistent, and nothing falls outside the reporting period. Unpaid obligations have a NULL payment date.

---

## Repository structure

```
Banking-Fraud-Credit-Risk-sql-analytics/
├── README.md
├── DATA_DICTIONARY.md
├── .gitignore
├── data/                  CSV source tables (zipped in csv.zip)
├── dump/                  Full SQL dump: schema and all records (Data Set sql.zip)
├── sql/
│   ├── 01_create_schema.sql
│   ├── 02_load_or_import_data.sql
│   ├── 03_data_quality_checks.sql
│   ├── 04_fraud_analysis.sql
│   ├── 05_credit_risk_analysis.sql
│   ├── 06_collections_analysis.sql
│   ├── 07_transaction_monitoring.sql
│   ├── 08_portfolio_analysis.sql
│   ├── 09_dashboard_views.sql
│   └── 10_business_solutions.sql
├── scripts/
│   ├── generate_dataset.py
│   └── validate_dataset.py
├── docs/
│   └── QUESTIONS_AND_SOLUTIONS.html
├── dashboards/
│   ├── images/            Dashboard screenshots
│   ├── powerbi_dashboard_spec.md
│   ├── tableau_dashboard_spec.md
│   ├── Card Fraud, Credit Risk & Portfolio Dashboard.pbit
│   └── CARD FRAUD, CREDIT RISK & PORTFOLIO DASHBOARD.twb
```

---

## Database schema

Database name: `barclays_card_risk`

| Table | Grain (one row per) | Key relationships |
|---|---|---|
| `customers` | customer | Parent of `accounts` |
| `accounts` | account | `customer_id` to `customers` |
| `merchants` | merchant | Parent of `transactions` |
| `transactions` | transaction | `account_id` to `accounts`; `merchant_id` to `merchants` |
| `payments` | payment obligation (billing cycle) | `account_id` to `accounts` |
| `date_dimension` | calendar day, 1 Oct 2021 to 30 Sep 2026 | Joined on date keys |

Money is stored as `DECIMAL`, never `FLOAT`. Primary keys, foreign keys, `NOT NULL` and `CHECK` constraints are defined in `sql/01_create_schema.sql`. Column definitions are in `DATA_DICTIONARY.md`.

---

## How to run

**Option A: restore the full dump (quickest)**

1. Unzip `Data Set sql.zip`.
2. Run the dump in MySQL 8.0 or later:
   ```bash
   mysql -u root -p < dump/Banking-Fraud-Credit-Risk-sql-analytics.sql
   ```
3. Confirm the database exists: `USE barclays_card_risk; SHOW TABLES;`

**Option B: build from the CSV files**

1. Unzip `csv.zip` into `data/`.
2. Run `sql/01_create_schema.sql`, then `sql/02_load_or_import_data.sql`.

**Then:**

4. Run `sql/03_data_quality_checks.sql`. Every check should return PASS.
5. Run `sql/04` through `sql/10` in order. Each script is independent after the views in `09` are created.
6. Open the dashboards (see below).

To regenerate the data from scratch:

```bash
python scripts/generate_dataset.py
python scripts/validate_dataset.py
```

---

## Dashboards

**Power BI:** open the `.pbit` template. When prompted, select the folder containing the CSV files (or point it at the MySQL views in `sql/09_dashboard_views.sql`). Save as `.pbix`.

**Tableau:** the `.twb` workbook stores data-source paths from the original machine. Place the CSV files in the same folder structure, or use the Tableau Public link above.

Dashboard specifications, including KPI definitions, filters and pitfalls, are in `dashboards/powerbi_dashboard_spec.md` and `dashboards/tableau_dashboard_spec.md`.

---

## KPI definitions

| KPI | Definition |
|---|---|
| Fraud rate | Fraud-labelled transactions ÷ total transactions |
| Fraud value | Sum of amounts on fraud-labelled transactions |
| Overdue amount | Outstanding balance on obligations with days past due > 0 |
| 30+ DPD rate | Obligations with days past due ≥ 30 ÷ total obligations |
| Collection rate | Amount paid ÷ amount due |
| Weighted utilisation | Sum of current balances ÷ sum of credit limits |
| Precision (monitoring rule) | Fraud captured ÷ transactions flagged |
| Recall (monitoring rule) | Fraud captured ÷ all fraud-labelled transactions |

---

## Key limitations and assumptions

- **Synthetic data.** Fraud labels are a synthetic ground-truth field for demonstration. They are not a production fraud model.
- **Rule-based risk tiers, not a validated credit score.** Correlations shown in the analysis are not causal.
- **No revenue, interchange, interest, recovery or chargeback data.** These are not generated, so no profitability figures are reported.
- **No month-end balance snapshots** beyond what is in the dataset. Roll-rate analysis is limited to what the records support.
- **Monitoring thresholds** (for example, £250 for online and phone-order transactions) are illustrative. The trade-off is shown, not an optimised rule.

---

## Verification status

| Check | Status |
|---|---|
| Dataset generation (`generate_dataset.py`) | Executed |
| Dataset validation (`validate_dataset.py`) | Executed |
| SQL data-quality checks (`03`) | Executed on MariaDB 10.11 |
| SQL analysis scripts (`04` to `10`) | Executed on MariaDB 10.11 |
| Full run on MySQL 8.0 | **Pending. Not yet verified on MySQL 8.0** |
| Dashboards (Power BI, Tableau) | Built and reviewed against the SQL views |

The queries are written for MySQL 8.0+. Where MySQL-specific behaviour matters, it is noted in the script comments.

---

## Reproducibility

The generator uses a fixed random seed, so running `generate_dataset.py` reproduces the same records. Python dependencies are listed at the top of the generator script.

---

## Using this project in a portfolio

Start with the Tableau or Power BI dashboards for a quick overview. Then open `sql/03_data_quality_checks.sql` to show the validation approach, and `docs/QUESTIONS_AND_SOLUTIONS.html` to show how each business question links to a decision.
