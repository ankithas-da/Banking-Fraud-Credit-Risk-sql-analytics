#==============================================================================#
#  BARCLAYS-STYLE CARD RISK ANALYTICS: FIVE BUSINESS PROBLEMS, 100 SQL QUESTIONS #
#  Level: Medium and Advanced. Data is SYNTHETIC. Not Barclays data.              #
#  Run after loading dump files 01, 02 and 03. MySQL 8.0 or later.              #
#==============================================================================#
USE barclays_card_risk;

#==============================================================================#
#  PROBLEM 1: CARD FRAUD LOSSES
#  Scenario: The fraud team loses money to card fraud every month. It needs to know where the fraud is concentrated so it can add controls where they matter most.
#==============================================================================#

#Q001 Card fraud
#Problem : Establishes whether fraud exposure is rising, falling or stable before any segment analysis.
#Question: How have monthly fraud rate and fraud value moved across all 60 months?

SELECT DATE_FORMAT(t.transaction_datetime, '%Y-%m') AS calendar_month,
       COUNT(*) AS total_transactions,
       SUM(t.is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(t.amount_gbp), 2) AS total_value_gbp,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp,
       ROUND(100.0 * SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END)
             / NULLIF(SUM(t.amount_gbp), 0), 3) AS fraud_value_share_pct
FROM transactions t
GROUP BY DATE_FORMAT(t.transaction_datetime, '%Y-%m')
ORDER BY calendar_month;

#Q002 Card fraud
#Problem : Headline sizing for the fraud exposure statement to management.
#Question: What is the overall fraud volume and value across the full five-year window?

SELECT COUNT(*) AS total_transactions,
       SUM(t.is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(t.amount_gbp), 2) AS total_value_gbp,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp,
       ROUND(100.0 * SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END)
             / NULLIF(SUM(t.amount_gbp), 0), 3) AS fraud_value_share_pct,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END)
             / NULLIF(SUM(t.is_fraud_label), 0), 2) AS average_fraud_ticket_gbp,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 0 THEN t.amount_gbp ELSE 0 END)
             / NULLIF(SUM(CASE WHEN t.is_fraud_label = 0 THEN 1 ELSE 0 END), 0), 2) AS average_genuine_ticket_gbp
FROM transactions t;

#Q003 Card fraud
#Problem : Channel is the first control point.
#Question: Which transaction channels carry the highest fraud rate and fraud value?

SELECT t.transaction_channel AS channel,
       COUNT(*) AS transaction_count,
       SUM(t.is_fraud_label) AS fraud_count,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp,
       RANK() OVER (ORDER BY SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0) DESC) AS fraud_rate_rank,
       RANK() OVER (ORDER BY SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) DESC) AS fraud_value_rank
FROM transactions t
GROUP BY t.transaction_channel
ORDER BY fraud_rate_rank, channel;

#Q004 Card fraud
#Problem : Merchant category drives merchant-level controls, acquirer risk conversations and category-specific velocity limits.
#Question: Which merchant categories concentrate fraud by rate and by value?

WITH category_fraud AS (
    SELECT m.merchant_category,
           COUNT(*) AS transaction_count,
           SUM(t.is_fraud_label) AS fraud_count,
           SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) AS fraud_value_gbp
    FROM transactions t
    INNER JOIN merchants m ON m.merchant_id = t.merchant_id
    GROUP BY m.merchant_category
)
SELECT merchant_category,
       transaction_count,
       fraud_count,
       ROUND(100.0 * fraud_count / NULLIF(transaction_count, 0), 3) AS fraud_rate_pct,
       ROUND(fraud_value_gbp, 2) AS fraud_value_gbp,
       ROUND(100.0 * fraud_value_gbp / NULLIF(SUM(fraud_value_gbp) OVER (), 0), 3) AS fraud_value_share_pct
FROM category_fraud
ORDER BY fraud_value_gbp DESC;

#Q005 Card fraud
#Problem : Cross-border transactions usually face extra checks.
#Question: How does fraud differ between UK merchants and international merchants, and by merchant country?

SELECT m.merchant_country_code,
       t.is_international,
       COUNT(*) AS transaction_count,
       SUM(t.is_fraud_label) AS fraud_count,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp
FROM transactions t
INNER JOIN merchants m ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_country_code, t.is_international
HAVING COUNT(*) >= 500
ORDER BY fraud_rate_pct DESC, m.merchant_country_code;

#Q006 Card fraud
#Problem : Time-of-day is a common monitoring feature.
#Question: Does fraud concentrate in overnight hours, and does weekend trading change the pattern?

SELECT CASE
           WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 THEN '1 Overnight (00-05)'
           WHEN HOUR(t.transaction_datetime) BETWEEN 6 AND 11 THEN '2 Morning (06-11)'
           WHEN HOUR(t.transaction_datetime) BETWEEN 12 AND 17 THEN '3 Afternoon (12-17)'
           ELSE '4 Evening (18-23)'
       END AS time_band,
       CASE WHEN DAYOFWEEK(t.transaction_datetime) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       COUNT(*) AS transaction_count,
       SUM(t.is_fraud_label) AS fraud_count,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp
FROM transactions t
GROUP BY time_band, day_type
ORDER BY time_band, day_type;

#Q007 Card fraud
#Problem : Individual high-value cases are the most actionable items for a fraud investigation queue.
#Question: Which 25 fraud-labelled transactions carry the highest value, and what do they have in common?

SELECT ROW_NUMBER() OVER (ORDER BY t.amount_gbp DESC, t.transaction_id) AS value_rank,
       t.transaction_id,
       t.account_id,
       t.transaction_datetime,
       t.amount_gbp,
       t.transaction_channel,
       m.merchant_name,
       m.merchant_category,
       m.merchant_country_code,
       t.is_international,
       a.account_status_as_of
FROM transactions t
INNER JOIN merchants m ON m.merchant_id = t.merchant_id
INNER JOIN accounts a ON a.account_id = t.account_id
WHERE t.is_fraud_label = 1
ORDER BY t.amount_gbp DESC, t.transaction_id
LIMIT 25;

#Q008 Card fraud
#Problem : Regional patterns can reveal compromise hotspots or differences in customer behaviour that inform regional customer-contact and fraud-awareness campaigns.
#Question: How do fraud rate and fraud value vary by customer region?

SELECT c.region,
       COUNT(*) AS transaction_count,
       SUM(t.is_fraud_label) AS fraud_count,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END)
             / NULLIF(SUM(t.is_fraud_label), 0), 2) AS average_fraud_ticket_gbp
FROM transactions t
INNER JOIN accounts a ON a.account_id = t.account_id
INNER JOIN customers c ON c.customer_id = a.customer_id
GROUP BY c.region
ORDER BY fraud_value_gbp DESC;

#Q009 Card fraud
#Problem : Repeated fraud on one account suggests a compromised card or credentials, which usually needs a card reissue, not just individual transaction reversal.
#Question: Which accounts have repeated fraud-labelled transactions (three or more)?

SELECT t.account_id,
       COUNT(*) AS fraud_transaction_count,
       ROUND(SUM(t.amount_gbp), 2) AS fraud_value_gbp,
       COUNT(DISTINCT t.merchant_id) AS distinct_merchants,
       COUNT(DISTINCT t.transaction_channel) AS distinct_channels,
       MIN(DATE(t.transaction_datetime)) AS first_fraud_date,
       MAX(DATE(t.transaction_datetime)) AS last_fraud_date,
       a.account_status_as_of
FROM transactions t
INNER JOIN accounts a ON a.account_id = t.account_id
WHERE t.is_fraud_label = 1
GROUP BY t.account_id, a.account_status_as_of
HAVING COUNT(*) >= 3
ORDER BY fraud_transaction_count DESC, fraud_value_gbp DESC
LIMIT 50;

#Q010 Card fraud
#Problem : Band thresholds are the basis for amount-based step-up rules.
#Question: How do fraud rates and fraud value change across amount bands?

SELECT CASE
           WHEN t.amount_gbp < 25 THEN 'A: under 25'
           WHEN t.amount_gbp < 100 THEN 'B: 25 to 99.99'
           WHEN t.amount_gbp < 250 THEN 'C: 100 to 249.99'
           WHEN t.amount_gbp < 500 THEN 'D: 250 to 499.99'
           WHEN t.amount_gbp < 1000 THEN 'E: 500 to 999.99'
           ELSE 'F: 1000 and above'
       END AS amount_band,
       CASE
           WHEN t.amount_gbp < 25 THEN 1
           WHEN t.amount_gbp < 100 THEN 2
           WHEN t.amount_gbp < 250 THEN 3
           WHEN t.amount_gbp < 500 THEN 4
           WHEN t.amount_gbp < 1000 THEN 5
           ELSE 6
       END AS band_order,
       COUNT(*) AS transaction_count,
       SUM(t.is_fraud_label) AS fraud_count,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp
FROM transactions t
GROUP BY amount_band, band_order
ORDER BY band_order;

#Q011 Card fraud
#Problem : Separates frequency from financial loss.
#Question: Comparing each channel's share of transactions with its share of fraud count and fraud value, which channels are over- or under-represented in fraud?

WITH channel_totals AS (
    SELECT t.transaction_channel AS channel,
           COUNT(*) AS transaction_count,
           SUM(t.is_fraud_label) AS fraud_count,
           SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) AS fraud_value_gbp
    FROM transactions t
    GROUP BY t.transaction_channel
)
SELECT channel,
       transaction_count,
       ROUND(100.0 * transaction_count / NULLIF(SUM(transaction_count) OVER (), 0), 2) AS pct_of_transactions,
       fraud_count,
       ROUND(100.0 * fraud_count / NULLIF(SUM(fraud_count) OVER (), 0), 2) AS pct_of_fraud_count,
       ROUND(fraud_value_gbp, 2) AS fraud_value_gbp,
       ROUND(100.0 * fraud_value_gbp / NULLIF(SUM(fraud_value_gbp) OVER (), 0), 2) AS pct_of_fraud_value,
       ROUND(100.0 * fraud_count / NULLIF(transaction_count, 0), 3) AS fraud_rate_pct
FROM channel_totals
ORDER BY pct_of_fraud_value DESC;

#Q012 Card fraud
#Problem : Early warning for sudden spikes that may indicate a new attack pattern or a data breach at a merchant.
#Question: What is the month-over-month change in fraud count and fraud value?

WITH monthly_fraud AS (
    SELECT DATE_FORMAT(t.transaction_datetime, '%Y-%m') AS calendar_month,
           SUM(t.is_fraud_label) AS fraud_count,
           SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) AS fraud_value_gbp
    FROM transactions t
    GROUP BY DATE_FORMAT(t.transaction_datetime, '%Y-%m')
),
monthly_with_lag AS (
    SELECT calendar_month,
           fraud_count,
           LAG(fraud_count) OVER (ORDER BY calendar_month) AS previous_fraud_count,
           ROUND(fraud_value_gbp, 2) AS fraud_value_gbp,
           ROUND(LAG(fraud_value_gbp) OVER (ORDER BY calendar_month), 2) AS previous_fraud_value_gbp
    FROM monthly_fraud
)
SELECT calendar_month,
       fraud_count,
       previous_fraud_count,
       fraud_count - previous_fraud_count AS fraud_count_change,
       ROUND(100.0 * (fraud_count - previous_fraud_count) / NULLIF(previous_fraud_count, 0), 2) AS fraud_count_change_pct,
       fraud_value_gbp,
       previous_fraud_value_gbp,
       ROUND(100.0 * (fraud_value_gbp - previous_fraud_value_gbp) / NULLIF(previous_fraud_value_gbp, 0), 2) AS fraud_value_change_pct
FROM monthly_with_lag
ORDER BY calendar_month;

#Q013 Card fraud
#Problem : The 1,000-transaction minimum prevents small categories from creating false alarms.
#Question: Which merchant categories have a fraud rate at least twice the portfolio average, using at least 1,000 transactions?

WITH category_rates AS (
    SELECT m.merchant_category,
           COUNT(*) AS transaction_count,
           SUM(t.is_fraud_label) AS fraud_count,
           SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) AS fraud_value_gbp
    FROM transactions t
    INNER JOIN merchants m ON m.merchant_id = t.merchant_id
    GROUP BY m.merchant_category
    HAVING COUNT(*) >= 1000
)
SELECT cr.merchant_category,
       cr.transaction_count,
       cr.fraud_count,
       ROUND(100.0 * cr.fraud_count / cr.transaction_count, 3) AS fraud_rate_pct,
       ROUND(100.0 * (SELECT SUM(is_fraud_label) FROM transactions) / (SELECT COUNT(*) FROM transactions), 3) AS portfolio_fraud_rate_pct,
       ROUND((cr.fraud_count / cr.transaction_count)
             / NULLIF((SELECT SUM(is_fraud_label) / COUNT(*) FROM transactions), 0), 2) AS rate_multiple,
       ROUND(cr.fraud_value_gbp, 2) AS fraud_value_gbp
FROM category_rates cr
WHERE (cr.fraud_count / cr.transaction_count)
      >= 2 * (SELECT SUM(is_fraud_label) / COUNT(*) FROM transactions)
ORDER BY rate_multiple DESC;

#Q014 Card fraud
#Problem : If a small share of accounts holds most fraud value, targeted account-level monitoring is more efficient than portfolio-wide rules.
#Question: How concentrated is fraud value across accounts (Pareto analysis by decile)?

WITH account_fraud AS (
    SELECT t.account_id,
           SUM(t.amount_gbp) AS fraud_value_gbp
    FROM transactions t
    WHERE t.is_fraud_label = 1
    GROUP BY t.account_id
),
account_deciles AS (
    SELECT account_id,
           fraud_value_gbp,
           NTILE(10) OVER (ORDER BY fraud_value_gbp DESC) AS account_decile
    FROM account_fraud
),
decile_summary AS (
    SELECT account_decile,
           COUNT(*) AS accounts_in_decile,
           SUM(fraud_value_gbp) AS decile_fraud_value_gbp
    FROM account_deciles
    GROUP BY account_decile
)
SELECT account_decile,
       accounts_in_decile,
       ROUND(decile_fraud_value_gbp, 2) AS decile_fraud_value_gbp,
       ROUND(100.0 * decile_fraud_value_gbp / NULLIF(SUM(decile_fraud_value_gbp) OVER (), 0), 2) AS decile_share_of_fraud_value_pct,
       ROUND(100.0 * SUM(decile_fraud_value_gbp) OVER (ORDER BY account_decile
                                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / NULLIF(SUM(decile_fraud_value_gbp) OVER (), 0), 2) AS cumulative_share_of_fraud_value_pct
FROM decile_summary
ORDER BY account_decile;

#Q015 Card fraud
#Problem : Behavioural anomaly detection compares each transaction with that customer's own pattern, not the portfolio average.
#Question: Are transactions that are unusually large for their own account more likely to be fraud?

WITH txn_baseline AS (
    SELECT t.transaction_id,
           t.amount_gbp,
           t.is_fraud_label,
           COUNT(*) OVER (PARTITION BY t.account_id) AS account_txn_count,
           (SUM(t.amount_gbp) OVER (PARTITION BY t.account_id) - t.amount_gbp)
             / NULLIF(COUNT(*) OVER (PARTITION BY t.account_id) - 1, 0) AS other_txns_avg_amount
    FROM transactions t
)
SELECT CASE WHEN amount_gbp >= 3 * other_txns_avg_amount
            THEN 'Anomaly: at least 3x own average'
            ELSE 'Within normal range' END AS anomaly_flag,
       COUNT(*) AS transaction_count,
       SUM(is_fraud_label) AS fraud_count,
       ROUND(100.0 * SUM(is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(AVG(amount_gbp), 2) AS average_amount_gbp
FROM txn_baseline
WHERE account_txn_count >= 5
GROUP BY anomaly_flag
ORDER BY anomaly_flag;

#Q016 Card fraud
#Problem : Rapid identical repeats are a classic card-testing or duplicate-charge pattern.
#Question: Do repeat transactions for the same account with an identical amount within ten minutes carry higher fraud rates?

WITH ordered_txn AS (
    SELECT t.transaction_id,
           t.account_id,
           t.transaction_datetime,
           t.amount_gbp,
           t.is_fraud_label,
           LAG(t.transaction_datetime) OVER (PARTITION BY t.account_id
                                             ORDER BY t.transaction_datetime, t.transaction_id) AS previous_datetime,
           LAG(t.amount_gbp) OVER (PARTITION BY t.account_id
                                   ORDER BY t.transaction_datetime, t.transaction_id) AS previous_amount_gbp
    FROM transactions t
),
flagged_txn AS (
    SELECT transaction_id,
           amount_gbp,
           is_fraud_label,
           CASE WHEN previous_datetime IS NOT NULL
                 AND TIMESTAMPDIFF(MINUTE, previous_datetime, transaction_datetime) BETWEEN 0 AND 10
                 AND amount_gbp = previous_amount_gbp
                THEN 'Repeat identical amount within 10 min'
                ELSE 'Other transactions' END AS repeat_pattern_flag
    FROM ordered_txn
)
SELECT repeat_pattern_flag,
       COUNT(*) AS transaction_count,
       SUM(is_fraud_label) AS fraud_count,
       ROUND(100.0 * SUM(is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN is_fraud_label = 1 THEN amount_gbp ELSE 0 END), 2) AS fraud_value_gbp
FROM flagged_txn
GROUP BY repeat_pattern_flag
ORDER BY repeat_pattern_flag;

#Q017 Card fraud
#Problem : New accounts are often targeted for first-party or synthetic-identity fraud; older accounts can be compromised through credential reuse.
#Question: Is fraud frequency related to how long the account has been open?

SELECT CASE
           WHEN TIMESTAMPDIFF(MONTH, a.account_open_date, DATE(t.transaction_datetime)) < 6 THEN '1 Under 6 months'
           WHEN TIMESTAMPDIFF(MONTH, a.account_open_date, DATE(t.transaction_datetime)) < 12 THEN '2 6-11 months'
           WHEN TIMESTAMPDIFF(MONTH, a.account_open_date, DATE(t.transaction_datetime)) < 24 THEN '3 12-23 months'
           WHEN TIMESTAMPDIFF(MONTH, a.account_open_date, DATE(t.transaction_datetime)) < 36 THEN '4 24-35 months'
           WHEN TIMESTAMPDIFF(MONTH, a.account_open_date, DATE(t.transaction_datetime)) < 48 THEN '5 36-47 months'
           ELSE '6 48 months and over'
       END AS account_age_band,
       COUNT(*) AS transaction_count,
       SUM(t.is_fraud_label) AS fraud_count,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp
FROM transactions t
INNER JOIN accounts a ON a.account_id = t.account_id
GROUP BY account_age_band
ORDER BY account_age_band;

#Q018 Card fraud
#Problem : The mean alone hides skew.
#Question: What does the distribution of fraud-labelled amounts look like, by decile?

WITH fraud_amounts AS (
    SELECT t.amount_gbp,
           NTILE(10) OVER (ORDER BY t.amount_gbp) AS amount_decile
    FROM transactions t
    WHERE t.is_fraud_label = 1
)
SELECT amount_decile,
       COUNT(*) AS fraud_count,
       MIN(amount_gbp) AS min_amount_gbp,
       MAX(amount_gbp) AS max_amount_gbp,
       ROUND(AVG(amount_gbp), 2) AS average_amount_gbp,
       ROUND(SUM(amount_gbp), 2) AS total_fraud_value_gbp
FROM fraud_amounts
GROUP BY amount_decile
ORDER BY amount_decile;

#Q019 Card fraud
#Problem : Quarterly reporting smooths month-to-month noise and matches management and regulatory reporting cycles.
#Question: How do fraud count and fraud value trend by year and quarter?

WITH quarterly AS (
    SELECT YEAR(t.transaction_datetime) AS fraud_year,
           QUARTER(t.transaction_datetime) AS fraud_quarter,
           COUNT(*) AS transaction_count,
           SUM(t.is_fraud_label) AS fraud_count,
           SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) AS fraud_value_gbp
    FROM transactions t
    GROUP BY YEAR(t.transaction_datetime), QUARTER(t.transaction_datetime)
)
SELECT fraud_year,
       fraud_quarter,
       CONCAT(fraud_year, ' Q', fraud_quarter) AS quarter_label,
       fraud_count,
       ROUND(fraud_value_gbp, 2) AS fraud_value_gbp,
       ROUND(100.0 * fraud_count / NULLIF(transaction_count, 0), 3) AS fraud_rate_pct,
       RANK() OVER (ORDER BY fraud_value_gbp DESC) AS value_rank_across_quarters
FROM quarterly
ORDER BY fraud_year, fraud_quarter;

#Q020 Card fraud
#Problem : Combining channel and category shows where a single rule would catch the most fraud value.
#Question: Which channel and merchant-category combinations are the most actionable fraud-monitoring opportunities?

WITH segment_fraud AS (
    SELECT t.transaction_channel AS channel,
           m.merchant_category,
           COUNT(*) AS transaction_count,
           SUM(t.is_fraud_label) AS fraud_count,
           SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) AS fraud_value_gbp
    FROM transactions t
    INNER JOIN merchants m ON m.merchant_id = t.merchant_id
    GROUP BY t.transaction_channel, m.merchant_category
    HAVING COUNT(*) >= 500
)
SELECT DENSE_RANK() OVER (ORDER BY sf.fraud_value_gbp DESC) AS priority_rank,
       sf.channel,
       sf.merchant_category,
       sf.transaction_count,
       sf.fraud_count,
       ROUND(100.0 * sf.fraud_count / sf.transaction_count, 3) AS fraud_rate_pct,
       ROUND(sf.fraud_value_gbp, 2) AS fraud_value_gbp,
       ROUND(100.0 * sf.fraud_value_gbp / NULLIF(SUM(sf.fraud_value_gbp) OVER (), 0), 3) AS fraud_value_share_pct,
       CASE
           WHEN sf.fraud_value_gbp >= 5000 AND sf.fraud_count * 1.0 / sf.transaction_count >= 0.02 THEN 'High: high value and high rate'
           WHEN sf.fraud_value_gbp >= 5000 THEN 'Medium: high value, moderate rate'
           WHEN sf.fraud_count * 1.0 / sf.transaction_count >= 0.02 THEN 'Medium: high rate, low value'
           ELSE 'Low: monitor only'
       END AS monitoring_priority
FROM segment_fraud sf
ORDER BY priority_rank, sf.channel, sf.merchant_category
LIMIT 30;

#==============================================================================#
#  PROBLEM 2: CREDIT RISK EXPOSURE
#  Scenario: The credit team must find the accounts and customer groups that carry the most risk, before those accounts fall into arrears.
#==============================================================================#

#Q021 Credit risk
#Problem : Score bands are the first segmentation lens used in credit policy reviews.
#Question: How are customers and open accounts distributed across credit-score bands?

SELECT CASE
           WHEN c.credit_score < 580 THEN 'Poor'
           WHEN c.credit_score < 670 THEN 'Fair'
           WHEN c.credit_score < 740 THEN 'Good'
           WHEN c.credit_score < 800 THEN 'Very Good'
           ELSE 'Excellent'
       END AS score_band,
       CASE
           WHEN c.credit_score < 580 THEN 1
           WHEN c.credit_score < 670 THEN 2
           WHEN c.credit_score < 740 THEN 3
           WHEN c.credit_score < 800 THEN 4
           ELSE 5
       END AS score_band_order,
       COUNT(*) AS open_accounts,
       COUNT(DISTINCT c.customer_id) AS customers_with_open_accounts,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS share_of_open_accounts_pct
FROM accounts a
INNER JOIN customers c ON c.customer_id = a.customer_id
WHERE a.account_close_date IS NULL
GROUP BY score_band, score_band_order
ORDER BY score_band_order;

#Q022 Credit risk
#Problem : Utilisation is a core exposure driver.
#Question: How is open-account credit-limit utilisation distributed across utilisation bands?

SELECT CASE
           WHEN a.utilisation_as_of < 0.10 THEN '1 Under 10%'
           WHEN a.utilisation_as_of < 0.30 THEN '2 10% to 29%'
           WHEN a.utilisation_as_of < 0.60 THEN '3 30% to 59%'
           WHEN a.utilisation_as_of < 0.80 THEN '4 60% to 79%'
           WHEN a.utilisation_as_of <= 1.00 THEN '5 80% to 100%'
           ELSE '6 Over 100% (over limit)'
       END AS utilisation_band,
       COUNT(*) AS accounts,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS share_of_accounts_pct,
       ROUND(SUM(a.current_balance_gbp), 2) AS balance_gbp,
       ROUND(100.0 * SUM(a.current_balance_gbp) / NULLIF(SUM(SUM(a.current_balance_gbp)) OVER (), 0), 2) AS share_of_balance_pct
FROM accounts a
WHERE a.account_close_date IS NULL
GROUP BY utilisation_band
ORDER BY utilisation_band;

#Q023 Credit risk
#Problem : High utilisation concentrated in one product may reflect product design or limit policy rather than customer-level stress.
#Question: Which products and regions hold the most high-utilisation accounts (80% or more of limit)?

SELECT a.product_type,
       c.region,
       COUNT(*) AS open_accounts,
       SUM(CASE WHEN a.utilisation_as_of >= 0.80 THEN 1 ELSE 0 END) AS high_utilisation_accounts,
       ROUND(100.0 * SUM(CASE WHEN a.utilisation_as_of >= 0.80 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS high_utilisation_rate_pct,
       ROUND(SUM(CASE WHEN a.utilisation_as_of >= 0.80 THEN a.current_balance_gbp ELSE 0 END), 2) AS high_utilisation_balance_gbp
FROM accounts a
INNER JOIN customers c ON c.customer_id = a.customer_id
WHERE a.account_close_date IS NULL
GROUP BY a.product_type, c.region
HAVING COUNT(*) >= 100
ORDER BY high_utilisation_rate_pct DESC, high_utilisation_balance_gbp DESC;

#Q024 Credit risk
#Problem : Tests whether the score separates delinquent accounts.
#Question: What share of open accounts is 30+ days past due, by credit-score band?

SELECT CASE
           WHEN c.credit_score < 580 THEN 'Poor'
           WHEN c.credit_score < 670 THEN 'Fair'
           WHEN c.credit_score < 740 THEN 'Good'
           WHEN c.credit_score < 800 THEN 'Very Good'
           ELSE 'Excellent'
       END AS score_band,
       CASE
           WHEN c.credit_score < 580 THEN 1
           WHEN c.credit_score < 670 THEN 2
           WHEN c.credit_score < 740 THEN 3
           WHEN c.credit_score < 800 THEN 4
           ELSE 5
       END AS score_band_order,
       COUNT(*) AS open_accounts,
       SUM(CASE WHEN a.max_dpd_as_of >= 30 THEN 1 ELSE 0 END) AS accounts_30_plus_dpd,
       ROUND(100.0 * SUM(CASE WHEN a.max_dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct
FROM accounts a
INNER JOIN customers c ON c.customer_id = a.customer_id
WHERE a.account_close_date IS NULL
GROUP BY score_band, score_band_order
ORDER BY score_band_order;

#Q025 Credit risk
#Problem : Income and region are standard segment lenses for credit risk and for fairness monitoring.
#Question: What is the 30+ DPD account rate by income band and region?

SELECT c.income_band,
       c.region,
       COUNT(*) AS open_accounts,
       SUM(CASE WHEN a.max_dpd_as_of >= 30 THEN 1 ELSE 0 END) AS accounts_30_plus_dpd,
       ROUND(100.0 * SUM(CASE WHEN a.max_dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct
FROM accounts a
INNER JOIN customers c ON c.customer_id = a.customer_id
WHERE a.account_close_date IS NULL
GROUP BY c.income_band, c.region
HAVING COUNT(*) >= 100
ORDER BY rate_30_plus_dpd_pct DESC, c.income_band, c.region;

#Q026 Credit risk
#Problem : Status drives operational treatment (suspension, collections, closure).
#Question: How are accounts distributed across status values, and what balance sits in each status?

SELECT a.account_status_as_of AS account_status,
       COUNT(*) AS accounts,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS share_of_accounts_pct,
       ROUND(SUM(a.current_balance_gbp), 2) AS balance_gbp,
       ROUND(100.0 * AVG(a.utilisation_as_of), 2) AS average_utilisation_pct
FROM accounts a
GROUP BY a.account_status_as_of
ORDER BY accounts DESC;

#Q027 Credit risk
#Problem : A transparent tiering rule gives management a common language for exposure and monitoring.
#Question: How are open accounts distributed across the four rule-based risk tiers, and what balance sits in each tier?

WITH open_account_risk AS (
    SELECT a.account_id,
           a.current_balance_gbp,
           CASE
               WHEN a.max_dpd_as_of >= 30 OR a.utilisation_as_of > 1.00 THEN 'Tier 1 High'
               WHEN a.utilisation_as_of >= 0.60 OR c.credit_score < 580 THEN 'Tier 2 Elevated'
               WHEN a.utilisation_as_of >= 0.30 OR c.credit_score < 670 THEN 'Tier 3 Moderate'
               ELSE 'Tier 4 Low'
           END AS risk_tier
    FROM accounts a
    INNER JOIN customers c ON c.customer_id = a.customer_id
    WHERE a.account_close_date IS NULL
)
SELECT risk_tier,
       COUNT(*) AS open_accounts,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS share_of_accounts_pct,
       ROUND(SUM(current_balance_gbp), 2) AS balance_gbp,
       ROUND(100.0 * SUM(current_balance_gbp) / NULLIF(SUM(SUM(current_balance_gbp)) OVER (), 0), 2) AS share_of_balance_pct,
       ROUND(AVG(current_balance_gbp), 2) AS average_balance_gbp
FROM open_account_risk
GROUP BY risk_tier
ORDER BY risk_tier;

#Q028 Credit risk
#Problem : If a band holds more balance than its account count suggests, its accounts carry larger balances and deserve closer limit review.
#Question: Which credit-score bands hold a bigger share of open balance than their share of open accounts?

WITH banded AS (
    SELECT CASE WHEN c.credit_score < 580 THEN '1. Poor (below 580)'
                WHEN c.credit_score < 670 THEN '2. Fair (580-669)'
                WHEN c.credit_score < 740 THEN '3. Good (670-739)'
                ELSE '4. Very good or better (740+)' END AS score_band,
           a.current_balance_gbp
    FROM accounts a
    JOIN customers c ON a.customer_id = c.customer_id
    WHERE a.account_status_as_of <> 'Closed'
),
by_band AS (
    SELECT score_band,
           COUNT(*) AS open_accounts,
           SUM(current_balance_gbp) AS open_balance_gbp
    FROM banded
    GROUP BY score_band
)
SELECT score_band,
       open_accounts,
       ROUND(100.0 * open_accounts / SUM(open_accounts) OVER (), 1) AS account_share_pct,
       ROUND(open_balance_gbp, 2) AS open_balance_gbp,
       ROUND(100.0 * open_balance_gbp / SUM(open_balance_gbp) OVER (), 1) AS balance_share_pct,
       ROUND(100.0 * open_balance_gbp / SUM(open_balance_gbp) OVER ()
             - 100.0 * open_accounts / SUM(open_accounts) OVER (), 1) AS balance_vs_account_share_pts
FROM by_band
ORDER BY score_band;

#Q029 Credit risk
#Problem : Shows whether lower-score customers hold larger balances relative to their limits.
#Question: What are the average balance, limit and utilisation by credit-score band?

SELECT CASE
           WHEN c.credit_score < 580 THEN 'Poor'
           WHEN c.credit_score < 670 THEN 'Fair'
           WHEN c.credit_score < 740 THEN 'Good'
           WHEN c.credit_score < 800 THEN 'Very Good'
           ELSE 'Excellent'
       END AS score_band,
       COUNT(*) AS open_accounts,
       ROUND(AVG(a.current_balance_gbp), 2) AS average_balance_gbp,
       ROUND(AVG(a.credit_limit_gbp), 2) AS average_limit_gbp,
       ROUND(100.0 * AVG(a.utilisation_as_of), 2) AS average_utilisation_pct
FROM accounts a
INNER JOIN customers c ON c.customer_id = a.customer_id
WHERE a.account_close_date IS NULL
GROUP BY score_band
ORDER BY MIN(c.credit_score) DESC;

#Q030 Credit risk
#Problem : Exposure is the amount at risk.
#Question: What is total credit exposure (limit, balance, unused limit) by account status?

SELECT a.account_status_as_of AS account_status,
       ROUND(SUM(a.credit_limit_gbp), 2) AS total_limit_gbp,
       ROUND(SUM(a.current_balance_gbp), 2) AS total_balance_gbp,
       ROUND(SUM(GREATEST(a.credit_limit_gbp - a.current_balance_gbp, 0)), 2) AS unused_limit_gbp,
       ROUND(100.0 * SUM(a.current_balance_gbp) / NULLIF(SUM(a.credit_limit_gbp), 0), 2) AS utilisation_pct
FROM accounts a
WHERE a.account_close_date IS NULL
GROUP BY a.account_status_as_of
ORDER BY total_balance_gbp DESC;

#Q031 Credit risk
#Problem : Shows whether high-risk exposure sits in a segment that the business targets for growth.
#Question: How is Tier 1 (High) risk concentrated across customer segments?

WITH account_tier AS (
    SELECT c.customer_segment,
           a.current_balance_gbp,
           CASE WHEN a.max_dpd_as_of >= 30 OR a.utilisation_as_of > 1.00 THEN 1 ELSE 0 END AS is_tier1
    FROM accounts a
    INNER JOIN customers c ON c.customer_id = a.customer_id
    WHERE a.account_close_date IS NULL
)
SELECT customer_segment,
       COUNT(*) AS open_accounts,
       SUM(is_tier1) AS tier1_accounts,
       ROUND(100.0 * SUM(is_tier1) / NULLIF(COUNT(*), 0), 2) AS tier1_rate_pct,
       ROUND(SUM(CASE WHEN is_tier1 = 1 THEN current_balance_gbp ELSE 0 END), 2) AS tier1_balance_gbp,
       ROUND(100.0 * SUM(CASE WHEN is_tier1 = 1 THEN current_balance_gbp ELSE 0 END)
             / NULLIF(SUM(current_balance_gbp), 0), 2) AS tier1_share_of_segment_balance_pct
FROM account_tier
GROUP BY customer_segment
ORDER BY tier1_rate_pct DESC;

#Q032 Credit risk
#Problem : Exposure is measured per customer, not per account.
#Question: How many customers hold multiple open accounts, and what is their combined exposure and worst delinquency?

WITH customer_accounts AS (
    SELECT a.customer_id,
           COUNT(*) AS open_account_count,
           SUM(a.current_balance_gbp) AS customer_balance_gbp,
           MAX(a.max_dpd_as_of) AS customer_max_dpd
    FROM accounts a
    WHERE a.account_close_date IS NULL
    GROUP BY a.customer_id
)
SELECT open_account_count,
       COUNT(*) AS customers,
       ROUND(SUM(customer_balance_gbp), 2) AS total_balance_gbp,
       ROUND(AVG(customer_balance_gbp), 2) AS average_balance_per_customer_gbp,
       SUM(CASE WHEN customer_max_dpd >= 30 THEN 1 ELSE 0 END) AS customers_with_30_plus_dpd,
       ROUND(100.0 * SUM(CASE WHEN customer_max_dpd >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_customers_30_plus_dpd_pct
FROM customer_accounts
GROUP BY open_account_count
ORDER BY open_account_count;

#Q033 Credit risk
#Problem : Utilisation is a common early-warning indicator.
#Question: How does the 30+ DPD rate change across utilisation bands (descriptive relationship only)?

SELECT CASE
           WHEN a.utilisation_as_of < 0.10 THEN '1 Under 10%'
           WHEN a.utilisation_as_of < 0.30 THEN '2 10% to 29%'
           WHEN a.utilisation_as_of < 0.60 THEN '3 30% to 59%'
           WHEN a.utilisation_as_of < 0.80 THEN '4 60% to 79%'
           WHEN a.utilisation_as_of <= 1.00 THEN '5 80% to 100%'
           ELSE '6 Over 100%'
       END AS utilisation_band,
       CASE
           WHEN a.utilisation_as_of < 0.10 THEN 1
           WHEN a.utilisation_as_of < 0.30 THEN 2
           WHEN a.utilisation_as_of < 0.60 THEN 3
           WHEN a.utilisation_as_of < 0.80 THEN 4
           WHEN a.utilisation_as_of <= 1.00 THEN 5
           ELSE 6
       END AS band_order,
       COUNT(*) AS open_accounts,
       SUM(CASE WHEN a.max_dpd_as_of >= 30 THEN 1 ELSE 0 END) AS accounts_30_plus_dpd,
       ROUND(100.0 * SUM(CASE WHEN a.max_dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct
FROM accounts a
WHERE a.account_close_date IS NULL
GROUP BY utilisation_band, band_order
ORDER BY band_order;

#Q034 Credit risk
#Problem : Over-limit balances are either authorisation failures or a sign of stress.
#Question: Which open accounts are above their credit limit, and how much balance sits above limit?

SELECT a.product_type,
       SUM(CASE WHEN a.current_balance_gbp > a.credit_limit_gbp THEN 1 ELSE 0 END) AS over_limit_accounts,
       ROUND(SUM(CASE WHEN a.current_balance_gbp > a.credit_limit_gbp THEN a.current_balance_gbp ELSE 0 END), 2) AS over_limit_balance_gbp,
       ROUND(SUM(GREATEST(a.current_balance_gbp - a.credit_limit_gbp, 0)), 2) AS amount_above_limit_gbp,
       ROUND(100.0 * AVG(a.utilisation_as_of), 2) AS average_utilisation_pct
FROM accounts a
WHERE a.account_close_date IS NULL
GROUP BY a.product_type
ORDER BY amount_above_limit_gbp DESC;

#Q035 Credit risk
#Problem : A points score is explainable to credit committees and easy to audit, unlike a black-box model.
#Question: Which open accounts rank highest on a transparent risk-points score?

WITH scored AS (
    SELECT a.account_id,
           a.customer_id,
           a.utilisation_as_of,
           a.max_dpd_as_of,
           a.current_balance_gbp,
           CASE WHEN a.max_dpd_as_of >= 90 THEN 4
                WHEN a.max_dpd_as_of >= 30 THEN 3
                WHEN a.max_dpd_as_of >= 1 THEN 1
                ELSE 0 END AS dpd_points,
           CASE WHEN a.utilisation_as_of > 1.00 THEN 3
                WHEN a.utilisation_as_of >= 0.80 THEN 2
                WHEN a.utilisation_as_of >= 0.60 THEN 1
                ELSE 0 END AS utilisation_points,
           CASE WHEN c.credit_score < 580 THEN 2
                WHEN c.credit_score < 670 THEN 1
                ELSE 0 END AS score_points
    FROM accounts a
    INNER JOIN customers c ON c.customer_id = a.customer_id
    WHERE a.account_close_date IS NULL
),
ranked AS (
    SELECT s.*,
           (s.dpd_points + s.utilisation_points + s.score_points) AS risk_points,
           DENSE_RANK() OVER (ORDER BY (s.dpd_points + s.utilisation_points + s.score_points) DESC) AS risk_rank
    FROM scored s
)
SELECT risk_rank,
       account_id,
       customer_id,
       risk_points,
       dpd_points,
       utilisation_points,
       score_points,
       ROUND(100.0 * utilisation_as_of, 2) AS utilisation_pct,
       max_dpd_as_of,
       current_balance_gbp
FROM ranked
WHERE risk_rank <= 20
ORDER BY risk_rank, current_balance_gbp DESC, account_id;

#Q036 Credit risk
#Problem : Early-life accounts may show different risk profiles from mature accounts.
#Question: How does the Tier 1 (High) rate vary with account age?

WITH account_age AS (
    SELECT TIMESTAMPDIFF(MONTH, a.account_open_date, DATE '2026-09-30') AS age_months,
           CASE WHEN a.max_dpd_as_of >= 30 OR a.utilisation_as_of > 1.00 THEN 1 ELSE 0 END AS is_tier1
    FROM accounts a
    WHERE a.account_close_date IS NULL
)
SELECT CASE
           WHEN age_months < 12 THEN '1 Under 12 months'
           WHEN age_months < 24 THEN '2 12-23 months'
           WHEN age_months < 36 THEN '3 24-35 months'
           ELSE '4 36 months and over'
       END AS account_age_band,
       COUNT(*) AS open_accounts,
       SUM(is_tier1) AS tier1_accounts,
       ROUND(100.0 * SUM(is_tier1) / NULLIF(COUNT(*), 0), 3) AS tier1_rate_pct
FROM account_age
GROUP BY account_age_band
ORDER BY account_age_band;

#Q037 Credit risk
#Problem : Shows whether lower-income customers are over-represented in higher tiers.
#Question: How is the rule-based risk tier distributed across income bands?

WITH account_tier AS (
    SELECT c.income_band,
           CASE
               WHEN a.max_dpd_as_of >= 30 OR a.utilisation_as_of > 1.00 THEN 'Tier 1'
               WHEN a.utilisation_as_of >= 0.60 OR c.credit_score < 580 THEN 'Tier 2'
               WHEN a.utilisation_as_of >= 0.30 OR c.credit_score < 670 THEN 'Tier 3'
               ELSE 'Tier 4'
           END AS risk_tier
    FROM accounts a
    INNER JOIN customers c ON c.customer_id = a.customer_id
    WHERE a.account_close_date IS NULL
)
SELECT income_band,
       COUNT(*) AS open_accounts,
       ROUND(100.0 * SUM(CASE WHEN risk_tier = 'Tier 1' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS tier1_pct,
       ROUND(100.0 * SUM(CASE WHEN risk_tier = 'Tier 2' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS tier2_pct,
       ROUND(100.0 * SUM(CASE WHEN risk_tier = 'Tier 3' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS tier3_pct,
       ROUND(100.0 * SUM(CASE WHEN risk_tier = 'Tier 4' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS tier4_pct
FROM account_tier
GROUP BY income_band
ORDER BY FIELD(income_band, '<20k', '20k-40k', '40k-70k', '70k-120k', '120k+');

#Q038 Credit risk
#Problem : A segment can hold many accounts with small balances, or few accounts with large balances.
#Question: How do account count and outstanding balance compare by customer segment?

SELECT c.customer_segment,
       COUNT(*) AS open_accounts,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS share_of_accounts_pct,
       ROUND(SUM(a.current_balance_gbp), 2) AS balance_gbp,
       ROUND(100.0 * SUM(a.current_balance_gbp) / NULLIF(SUM(SUM(a.current_balance_gbp)) OVER (), 0), 2) AS share_of_balance_pct,
       ROUND(AVG(a.current_balance_gbp), 2) AS balance_per_account_gbp
FROM accounts a
INNER JOIN customers c ON c.customer_id = a.customer_id
WHERE a.account_close_date IS NULL
GROUP BY c.customer_segment
ORDER BY balance_gbp DESC;

#Q039 Credit risk
#Problem : Identifies portfolio pockets for targeted action rather than portfolio-wide tightening.
#Question: Which product and region combinations are the most vulnerable (30+ DPD rate and Tier 1 balance)?

WITH pocket AS (
    SELECT a.product_type,
           c.region,
           COUNT(*) AS open_accounts,
           SUM(CASE WHEN a.max_dpd_as_of >= 30 THEN 1 ELSE 0 END) AS dpd30_accounts,
           SUM(CASE WHEN a.max_dpd_as_of >= 30 OR a.utilisation_as_of > 1.00 THEN a.current_balance_gbp ELSE 0 END) AS tier1_balance_gbp
    FROM accounts a
    INNER JOIN customers c ON c.customer_id = a.customer_id
    WHERE a.account_close_date IS NULL
    GROUP BY a.product_type, c.region
    HAVING COUNT(*) >= 100
)
SELECT product_type,
       region,
       open_accounts,
       ROUND(100.0 * dpd30_accounts / NULLIF(open_accounts, 0), 3) AS rate_30_plus_dpd_pct,
       ROUND(tier1_balance_gbp, 2) AS tier1_balance_gbp,
       RANK() OVER (ORDER BY dpd30_accounts / NULLIF(open_accounts, 0) DESC, tier1_balance_gbp DESC) AS vulnerability_rank
FROM pocket
ORDER BY vulnerability_rank, product_type, region
LIMIT 25;

#Q040 Credit risk
#Problem : Converts the risk analysis into an operational workload that management can resource.
#Question: How many open accounts need each review action, and what balance sits behind each action?

WITH action_assignment AS (
    SELECT a.account_id,
           a.current_balance_gbp,
           CASE
               WHEN a.max_dpd_as_of >= 30 THEN 'A Collections follow-up'
               WHEN a.utilisation_as_of > 1.00 THEN 'B Credit limit review'
               WHEN a.utilisation_as_of >= 0.80 THEN 'C Monitor for limit pressure'
               ELSE 'D No action'
           END AS recommended_action
    FROM accounts a
    WHERE a.account_close_date IS NULL
)
SELECT recommended_action,
       CAST(SUBSTRING(recommended_action, 1, 1) AS CHAR(1)) AS priority_order,
       COUNT(*) AS accounts,
       ROUND(SUM(current_balance_gbp), 2) AS balance_gbp,
       ROUND(100.0 * SUM(current_balance_gbp) / NULLIF(SUM(SUM(current_balance_gbp)) OVER (), 0), 2) AS share_of_balance_pct
FROM action_assignment
GROUP BY recommended_action
ORDER BY recommended_action;

#==============================================================================#
#  PROBLEM 3: COLLECTIONS AND OVERDUE PAYMENTS
#  Scenario: Money is overdue on many accounts. The collections team must recover it and decide which customers to contact first.
#==============================================================================#

#Q041 Collections
#Problem : The DPD bucket structure drives collections treatment and provisioning discussions.
#Question: How much outstanding balance sits in each days-past-due bucket as of 30 Sep 2026?

SELECT p.dpd_bucket_as_of AS dpd_bucket,
       CASE p.dpd_bucket_as_of
           WHEN 'Current' THEN 1 WHEN '1-29' THEN 2 WHEN '30-59' THEN 3
           WHEN '60-89' THEN 4 WHEN '90+' THEN 5 ELSE 9 END AS bucket_order,
       COUNT(*) AS obligations,
       COUNT(DISTINCT p.account_id) AS accounts,
       ROUND(SUM(p.outstanding_gbp), 2) AS outstanding_gbp,
       ROUND(100.0 * SUM(p.outstanding_gbp) / NULLIF(SUM(SUM(p.outstanding_gbp)) OVER (), 0), 2) AS share_of_outstanding_pct
FROM payments p
WHERE p.outstanding_gbp > 0
GROUP BY p.dpd_bucket_as_of
ORDER BY bucket_order;

#Q042 Collections
#Problem : Shows whether late and unpaid obligations are rising, falling or stable over time.
#Question: How have delinquency outcomes evolved by due month (cohort view, 60 months)?

SELECT DATE_FORMAT(p.due_date, '%Y-%m') AS due_month,
       COUNT(*) AS obligations,
       ROUND(100.0 * SUM(CASE WHEN p.payment_status = 'PAID_ON_TIME' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS on_time_pct,
       ROUND(100.0 * SUM(CASE WHEN p.payment_status = 'PAID_LATE' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS late_paid_pct,
       ROUND(100.0 * SUM(CASE WHEN p.payment_status = 'PARTIALLY_PAID' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS partial_pct,
       ROUND(100.0 * SUM(CASE WHEN p.payment_status = 'UNPAID' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS unpaid_pct,
       ROUND(100.0 * SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct
FROM payments p
WHERE p.due_date <= '2026-09-30'
GROUP BY DATE_FORMAT(p.due_date, '%Y-%m')
ORDER BY due_month;

#Q043 Collections
#Problem : Repeated serious arrears on the same account mean the problem is structural, not a one-off missed payment.
#Question: Which accounts have three or more obligations that are 30 or more days past due, and how much do they owe?

SELECT p.account_id,
       a.product_type,
       a.account_status_as_of,
       SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) AS serious_obligations_30_plus,
       ROUND(SUM(p.outstanding_gbp), 2) AS total_outstanding_gbp,
       MAX(p.dpd_as_of) AS worst_dpd_days
FROM payments p
JOIN accounts a ON p.account_id = a.account_id
GROUP BY p.account_id, a.product_type, a.account_status_as_of
HAVING SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) >= 3
ORDER BY serious_obligations_30_plus DESC, total_outstanding_gbp DESC
LIMIT 50;

#Q044 Collections
#Problem : Collection rate (paid divided by billed) is the headline measure of collections performance.
#Question: What is the payment collection rate overall and by payment status?

SELECT COALESCE(r.status_raw, 'ALL STATUSES') AS payment_status,
       r.obligations,
       r.amount_due_gbp,
       r.amount_paid_gbp,
       r.collection_rate_pct
FROM (
    SELECT p.payment_status AS status_raw,
           COUNT(*) AS obligations,
           ROUND(SUM(p.amount_due_gbp), 2) AS amount_due_gbp,
           ROUND(SUM(p.amount_paid_gbp), 2) AS amount_paid_gbp,
           ROUND(100.0 * SUM(p.amount_paid_gbp) / NULLIF(SUM(p.amount_due_gbp), 0), 2) AS collection_rate_pct
    FROM payments p
    GROUP BY p.payment_status WITH ROLLUP
) r
ORDER BY (r.status_raw IS NULL), r.status_raw;

#Q045 Collections
#Problem : Quarterly due-versus-paid shows whether payment behaviour keeps pace with billing growth.
#Question: How do amount due and amount paid compare by statement quarter?

SELECT YEAR(p.statement_date) AS statement_year,
       QUARTER(p.statement_date) AS statement_quarter,
       COUNT(*) AS obligations,
       ROUND(SUM(p.amount_due_gbp), 2) AS amount_due_gbp,
       ROUND(SUM(p.amount_paid_gbp), 2) AS amount_paid_gbp,
       ROUND(SUM(p.amount_due_gbp - p.amount_paid_gbp), 2) AS shortfall_gbp,
       ROUND(100.0 * SUM(p.amount_paid_gbp) / NULLIF(SUM(p.amount_due_gbp), 0), 2) AS collection_rate_pct
FROM payments p
GROUP BY YEAR(p.statement_date), QUARTER(p.statement_date)
ORDER BY statement_year, statement_quarter;

#Q046 Collections
#Problem : Regional collections strategy, contact channels and staffing depend on regional delinquency.
#Question: How do 30+ DPD obligations and outstanding balances vary by customer region?

SELECT c.region,
       COUNT(*) AS obligations,
       SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) AS obligations_30_plus_dpd,
       ROUND(100.0 * SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct,
       ROUND(SUM(CASE WHEN p.dpd_as_of >= 30 THEN p.outstanding_gbp ELSE 0 END), 2) AS outstanding_30_plus_gbp
FROM payments p
INNER JOIN accounts a ON a.account_id = p.account_id
INNER JOIN customers c ON c.customer_id = a.customer_id
GROUP BY c.region
ORDER BY rate_30_plus_dpd_pct DESC;

#Q047 Collections
#Problem : Income is a common affordability lens.
#Question: How do 30+ DPD obligations and outstanding balances vary by income band?

SELECT c.income_band,
       COUNT(*) AS obligations,
       ROUND(100.0 * SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct,
       ROUND(SUM(p.outstanding_gbp), 2) AS outstanding_gbp,
       ROUND(AVG(CASE WHEN p.outstanding_gbp > 0 THEN p.outstanding_gbp END), 2) AS average_outstanding_gbp
FROM payments p
INNER JOIN accounts a ON a.account_id = p.account_id
INNER JOIN customers c ON c.customer_id = a.customer_id
GROUP BY c.income_band
ORDER BY FIELD(c.income_band, '<20k', '20k-40k', '40k-70k', '70k-120k', '120k+');

#Q048 Collections
#Problem : Tests whether the score predicts payment behaviour at the obligation level, not only at the account level.
#Question: How do delinquency and collection rates vary by credit-score band?

SELECT CASE
           WHEN c.credit_score < 580 THEN 'Poor'
           WHEN c.credit_score < 670 THEN 'Fair'
           WHEN c.credit_score < 740 THEN 'Good'
           WHEN c.credit_score < 800 THEN 'Very Good'
           ELSE 'Excellent'
       END AS score_band,
       CASE
           WHEN c.credit_score < 580 THEN 1
           WHEN c.credit_score < 670 THEN 2
           WHEN c.credit_score < 740 THEN 3
           WHEN c.credit_score < 800 THEN 4
           ELSE 5
       END AS score_band_order,
       COUNT(*) AS obligations,
       ROUND(100.0 * SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct,
       ROUND(100.0 * SUM(p.amount_paid_gbp) / NULLIF(SUM(p.amount_due_gbp), 0), 2) AS collection_rate_pct
FROM payments p
INNER JOIN accounts a ON a.account_id = p.account_id
INNER JOIN customers c ON c.customer_id = a.customer_id
GROUP BY score_band, score_band_order
ORDER BY score_band_order;

#Q049 Collections
#Problem : Late-payment frequency is an early warning, often before an account reaches 30 DPD.
#Question: How often are obligations paid late, and how many accounts have had late payments?

WITH late_per_account AS (
    SELECT p.account_id,
           SUM(CASE WHEN p.payment_status = 'PAID_LATE' THEN 1 ELSE 0 END) AS late_payments
    FROM payments p
    GROUP BY p.account_id
)
SELECT late_payments AS late_payments_per_account,
       COUNT(*) AS accounts,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS share_of_accounts_pct
FROM late_per_account
GROUP BY late_payments
ORDER BY late_payments;

#Q050 Collections
#Problem : These are the balances most at risk of loss and most urgent for recovery.
#Question: What are the unpaid obligations as of 30 Sep 2026 (no payment received), by age?

SELECT COUNT(*) AS unpaid_obligations,
       COUNT(DISTINCT p.account_id) AS accounts,
       ROUND(SUM(p.amount_due_gbp), 2) AS unpaid_amount_gbp,
       MIN(p.due_date) AS oldest_due_date,
       ROUND(AVG(p.dpd_as_of), 1) AS average_dpd_days,
       MAX(p.dpd_as_of) AS max_dpd_days
FROM payments p
WHERE p.payment_status = 'UNPAID'
  AND p.payment_date IS NULL;

#Q051 Collections
#Problem : Repeated problems indicate a pattern rather than a one-off missed payment.
#Question: Which accounts have repeated late or unpaid obligations (three or more problem cycles)?

SELECT p.account_id,
       SUM(CASE WHEN p.payment_status <> 'PAID_ON_TIME' THEN 1 ELSE 0 END) AS problem_cycles,
       SUM(CASE WHEN p.payment_status = 'PAID_LATE' THEN 1 ELSE 0 END) AS late_cycles,
       SUM(CASE WHEN p.payment_status = 'UNPAID' THEN 1 ELSE 0 END) AS unpaid_cycles,
       SUM(CASE WHEN p.payment_status = 'PARTIALLY_PAID' THEN 1 ELSE 0 END) AS partial_cycles,
       ROUND(SUM(p.outstanding_gbp), 2) AS outstanding_gbp,
       a.account_status_as_of
FROM payments p
INNER JOIN accounts a ON a.account_id = p.account_id
GROUP BY p.account_id, a.account_status_as_of
HAVING SUM(CASE WHEN p.payment_status <> 'PAID_ON_TIME' THEN 1 ELSE 0 END) >= 3
ORDER BY problem_cycles DESC, outstanding_gbp DESC, p.account_id
LIMIT 100;

#Q052 Collections
#Problem : Validates that status labels reflect payment behaviour.
#Question: How does payment performance differ by account status?

SELECT a.account_status_as_of AS account_status,
       COUNT(*) AS obligations,
       ROUND(100.0 * SUM(CASE WHEN p.payment_status = 'PAID_ON_TIME' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS on_time_pct,
       ROUND(100.0 * SUM(CASE WHEN p.payment_status = 'PAID_LATE' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS late_pct,
       ROUND(100.0 * SUM(CASE WHEN p.payment_status IN ('UNPAID', 'PARTIALLY_PAID') THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS unpaid_or_partial_pct,
       ROUND(100.0 * SUM(p.amount_paid_gbp) / NULLIF(SUM(p.amount_due_gbp), 0), 2) AS collection_rate_pct
FROM payments p
INNER JOIN accounts a ON a.account_id = p.account_id
GROUP BY a.account_status_as_of
ORDER BY collection_rate_pct;

#Q053 Collections
#Problem : Larger minimum payments usually come from larger balances.
#Question: Is the size of the minimum payment related to the likelihood of delinquency?

SELECT CASE
           WHEN p.amount_due_gbp < 50 THEN 'A: under 50'
           WHEN p.amount_due_gbp < 100 THEN 'B: 50 to 99.99'
           WHEN p.amount_due_gbp < 250 THEN 'C: 100 to 249.99'
           WHEN p.amount_due_gbp < 500 THEN 'D: 250 to 499.99'
           ELSE 'E: 500 and above'
       END AS due_amount_band,
       COUNT(*) AS obligations,
       ROUND(100.0 * SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct,
       ROUND(AVG(p.amount_due_gbp), 2) AS average_due_gbp
FROM payments p
GROUP BY due_amount_band
ORDER BY MIN(p.amount_due_gbp);

#Q054 Collections
#Problem : Tracks whether the overdue amount generated by each billing month is growing or shrinking.
#Question: How do overdue balances change month over month, by due-month cohort?

WITH cohort_overdue AS (
    SELECT DATE_FORMAT(p.due_date, '%Y-%m') AS due_month,
           ROUND(SUM(CASE WHEN p.dpd_as_of > 0 THEN p.outstanding_gbp ELSE 0 END), 2) AS overdue_outstanding_gbp
    FROM payments p
    WHERE p.due_date <= '2026-09-30'
    GROUP BY DATE_FORMAT(p.due_date, '%Y-%m')
)
SELECT due_month,
       overdue_outstanding_gbp,
       LAG(overdue_outstanding_gbp) OVER (ORDER BY due_month) AS previous_month_overdue_gbp,
       ROUND(overdue_outstanding_gbp - LAG(overdue_outstanding_gbp) OVER (ORDER BY due_month), 2) AS change_gbp,
       ROUND(100.0 * (overdue_outstanding_gbp - LAG(overdue_outstanding_gbp) OVER (ORDER BY due_month))
             / NULLIF(LAG(overdue_outstanding_gbp) OVER (ORDER BY due_month), 0), 2) AS change_pct
FROM cohort_overdue
ORDER BY due_month;

#Q055 Collections
#Problem : Vintage ageing shows whether older billing cohorts are still unpaid, which is the core recovery question.
#Question: How is outstanding value aged by the quarter in which obligations fell due (vintage ageing)?

SELECT YEAR(p.due_date) AS due_year,
       QUARTER(p.due_date) AS due_quarter,
       COUNT(*) AS obligations,
       ROUND(SUM(p.outstanding_gbp), 2) AS outstanding_gbp,
       ROUND(100.0 * SUM(p.outstanding_gbp) / NULLIF(SUM(p.amount_due_gbp), 0), 2) AS outstanding_share_of_due_pct
FROM payments p
GROUP BY YEAR(p.due_date), QUARTER(p.due_date)
ORDER BY due_year, due_quarter;

#Q056 Collections
#Problem : Segment-level collection rates show where collections effort is being converted into cash.
#Question: How does collection performance compare across customer segments and products?

SELECT c.customer_segment,
       a.product_type,
       COUNT(*) AS obligations,
       ROUND(100.0 * SUM(p.amount_paid_gbp) / NULLIF(SUM(p.amount_due_gbp), 0), 2) AS collection_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 3) AS rate_30_plus_dpd_pct
FROM payments p
INNER JOIN accounts a ON a.account_id = p.account_id
INNER JOIN customers c ON c.customer_id = a.customer_id
GROUP BY c.customer_segment, a.product_type
HAVING COUNT(*) >= 200
ORDER BY collection_rate_pct ASC, rate_30_plus_dpd_pct DESC;

#Q057 Collections
#Problem : Shows persistence of problems.
#Question: How do accounts move between payment outcomes from one statement cycle to the next (transition matrix)?

WITH cycle_state AS (
    SELECT p.account_id,
           p.statement_date,
           CASE p.payment_status
               WHEN 'PAID_ON_TIME' THEN 'Clean'
               WHEN 'PAID_LATE' THEN 'Late paid'
               WHEN 'PARTIALLY_PAID' THEN 'Partial'
               ELSE 'Unpaid'
           END AS cycle_state
    FROM payments p
),
state_pairs AS (
    SELECT cs.cycle_state AS current_cycle_state,
           LAG(cs.cycle_state) OVER (PARTITION BY cs.account_id ORDER BY cs.statement_date) AS previous_cycle_state
    FROM cycle_state cs
)
SELECT sp.previous_cycle_state,
       sp.current_cycle_state,
       COUNT(*) AS transitions,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY sp.previous_cycle_state), 0), 2) AS pct_of_previous_state
FROM state_pairs sp
WHERE sp.previous_cycle_state IS NOT NULL
GROUP BY sp.previous_cycle_state, sp.current_cycle_state
ORDER BY sp.previous_cycle_state, sp.current_cycle_state;

#Q058 Collections
#Problem : Shortfall is the value the collections function is trying to recover.
#Question: How much payment shortfall (due but not paid) arises by product and payment status?

WITH shortfall AS (
    SELECT a.product_type,
           p.payment_status,
           SUM(p.amount_due_gbp - p.amount_paid_gbp) AS shortfall_gbp
    FROM payments p
    INNER JOIN accounts a ON a.account_id = p.account_id
    GROUP BY a.product_type, p.payment_status
)
SELECT product_type,
       payment_status,
       ROUND(shortfall_gbp, 2) AS shortfall_gbp,
       ROUND(100.0 * shortfall_gbp / NULLIF(SUM(shortfall_gbp) OVER (), 0), 2) AS share_of_total_shortfall_pct
FROM shortfall
WHERE shortfall_gbp > 0
ORDER BY shortfall_gbp DESC;

#Q059 Collections
#Problem : Gives collections teams an ordered work queue ranked by balance at risk.
#Question: Which accounts most urgently need collection follow-up (30+ DPD with the largest outstanding balance)?

WITH overdue_accounts AS (
    SELECT p.account_id,
           COUNT(*) AS overdue_obligations,
           ROUND(SUM(p.outstanding_gbp), 2) AS overdue_outstanding_gbp,
           MAX(p.dpd_as_of) AS oldest_dpd_days
    FROM payments p
    WHERE p.outstanding_gbp > 0
      AND p.dpd_as_of >= 30
    GROUP BY p.account_id
)
SELECT DENSE_RANK() OVER (ORDER BY oa.overdue_outstanding_gbp DESC, oa.account_id) AS collection_rank,
       oa.account_id,
       oa.overdue_obligations,
       oa.overdue_outstanding_gbp,
       oa.oldest_dpd_days,
       a.account_status_as_of
FROM overdue_accounts oa
INNER JOIN accounts a ON a.account_id = oa.account_id
ORDER BY collection_rank
LIMIT 100;

#Q060 Collections
#Problem : Turns the delinquency picture into a practical treatment plan with workload sizing.
#Question: What collections action should apply to each DPD bucket, and how much balance does each action cover?

SELECT p.dpd_bucket_as_of AS dpd_bucket,
       CASE p.dpd_bucket_as_of
           WHEN 'Current' THEN 1 WHEN '1-29' THEN 2 WHEN '30-59' THEN 3
           WHEN '60-89' THEN 4 WHEN '90+' THEN 5 ELSE 9 END AS bucket_order,
       CASE p.dpd_bucket_as_of
           WHEN 'Current' THEN 'Courtesy reminder before due date'
           WHEN '1-29' THEN 'Automated reminder and payment options'
           WHEN '30-59' THEN 'Agent contact and arrangement'
           WHEN '60-89' THEN 'Intensive contact and hardship review'
           WHEN '90+' THEN 'Recovery referral and credit-risk review'
           ELSE 'No action' END AS recommended_collections_action,
       COUNT(*) AS obligations,
       COUNT(DISTINCT p.account_id) AS accounts,
       ROUND(SUM(p.outstanding_gbp), 2) AS outstanding_gbp
FROM payments p
WHERE p.outstanding_gbp > 0
GROUP BY p.dpd_bucket_as_of
ORDER BY bucket_order;

#==============================================================================#
#  PROBLEM 4: TRANSACTION MONITORING AND ALERT REVIEW
#  Scenario: Analysts can only review a limited number of transactions each day. The monitoring team must choose which transactions and accounts to review first.
#==============================================================================#

#Q061 Transaction monitoring
#Problem : Sets the threshold for an "unusually large for this account" rule and shows the trade-off between catching fraud and alert volume.
#Question: How do precision, recall and alert volume change when a transaction is flagged at 3x, 5x or 10x its account's own average (leave-one-out)?

WITH baseline AS (
    SELECT t.transaction_id,
           t.account_id,
           t.amount_gbp AS amount,
           t.is_fraud_label AS is_fraud,
           COUNT(*) OVER (PARTITION BY t.account_id) AS account_txn_count,
           (SUM(t.amount_gbp) OVER (PARTITION BY t.account_id) - t.amount_gbp)
             / NULLIF(COUNT(*) OVER (PARTITION BY t.account_id) - 1, 0) AS other_txns_avg
    FROM transactions t
),
eligible AS (
    SELECT b.transaction_id, b.account_id, b.amount, b.is_fraud,
           b.account_txn_count, b.other_txns_avg
    FROM baseline b
    WHERE b.account_txn_count >= 5
),
thresholds AS (
    SELECT 3 AS multiple_of_own_average
    UNION ALL SELECT 5
    UNION ALL SELECT 10
),
flagged AS (
    SELECT th.multiple_of_own_average,
           e.is_fraud,
           e.amount
    FROM eligible e
    CROSS JOIN thresholds th
    WHERE e.amount >= th.multiple_of_own_average * e.other_txns_avg
),
total_fraud AS (
    SELECT SUM(is_fraud) AS fraud_in_population FROM eligible
)
SELECT f.multiple_of_own_average,
       COUNT(*) AS flagged_transactions,
       SUM(f.is_fraud) AS fraud_flagged,
       COUNT(*) - SUM(f.is_fraud) AS genuine_flagged,
       ROUND(100.0 * SUM(f.is_fraud) / NULLIF(COUNT(*), 0), 2) AS precision_pct,
       ROUND(100.0 * SUM(f.is_fraud) / NULLIF(MAX(tf.fraud_in_population), 0), 2) AS recall_pct
FROM flagged f
CROSS JOIN total_fraud tf
GROUP BY f.multiple_of_own_average
ORDER BY f.multiple_of_own_average;

#Q062 Transaction monitoring
#Problem : Rapid repeated use of one card is a standard monitoring signal.
#Question: How does fraud rate change with transaction velocity (number of transactions on the same account in the trailing 24 hours)?

WITH velocity AS (
    SELECT t.transaction_id,
           t.is_fraud_label,
           (SELECT COUNT(*)
            FROM transactions t2
            WHERE t2.account_id = t.account_id
              AND t2.transaction_datetime >= t.transaction_datetime - INTERVAL 24 HOUR
              AND t2.transaction_datetime <= t.transaction_datetime) AS txns_last_24h
    FROM transactions t
)
SELECT CASE
           WHEN txns_last_24h = 1 THEN '1 Only transaction in 24h'
           WHEN txns_last_24h <= 3 THEN '2 2 to 3 in 24h'
           WHEN txns_last_24h <= 5 THEN '3 4 to 5 in 24h'
           ELSE '4 6 or more in 24h'
       END AS velocity_band,
       COUNT(*) AS transactions,
       SUM(is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct
FROM velocity
GROUP BY velocity_band
ORDER BY velocity_band;

#Q063 Transaction monitoring
#Problem : Repeat use at one merchant is normally genuine (for example a regular grocer).
#Question: Does repeated use of the same merchant by the same account within seven days carry a higher fraud rate?

WITH repeat_merchant AS (
    SELECT t.transaction_id,
           t.is_fraud_label,
           (SELECT COUNT(*)
            FROM transactions t2
            WHERE t2.account_id = t.account_id
              AND t2.merchant_id = t.merchant_id
              AND t2.transaction_datetime >= t.transaction_datetime - INTERVAL 7 DAY
              AND t2.transaction_datetime <= t.transaction_datetime) - 1 AS prior_same_merchant_7d
    FROM transactions t
)
SELECT CASE
           WHEN prior_same_merchant_7d = 0 THEN '0 First use in 7 days'
           WHEN prior_same_merchant_7d = 1 THEN '1 One prior use'
           WHEN prior_same_merchant_7d = 2 THEN '2 Two prior uses'
           ELSE '3 Three or more prior uses'
       END AS prior_same_merchant_band,
       COUNT(*) AS transactions,
       SUM(is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct
FROM repeat_merchant
GROUP BY prior_same_merchant_band
ORDER BY prior_same_merchant_band;

#Q064 Transaction monitoring
#Problem : Overnight activity is a common monitoring feature.
#Question: How much of each channel's activity happens overnight (00:00-05:59), and how does its fraud rate compare with daytime?

SELECT t.transaction_channel AS channel,
       ROUND(100.0 * SUM(CASE WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS overnight_share_pct,
       ROUND(100.0 * SUM(CASE WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 THEN t.is_fraud_label ELSE 0 END)
             / NULLIF(SUM(CASE WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 THEN 1 ELSE 0 END), 0), 3) AS overnight_fraud_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN HOUR(t.transaction_datetime) NOT BETWEEN 0 AND 5 THEN t.is_fraud_label ELSE 0 END)
             / NULLIF(SUM(CASE WHEN HOUR(t.transaction_datetime) NOT BETWEEN 0 AND 5 THEN 1 ELSE 0 END), 0), 3) AS daytime_fraud_rate_pct,
       ROUND((SUM(CASE WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 THEN t.is_fraud_label ELSE 0 END)
              / NULLIF(SUM(CASE WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 THEN 1 ELSE 0 END), 0))
             / NULLIF(SUM(CASE WHEN HOUR(t.transaction_datetime) NOT BETWEEN 0 AND 5 THEN t.is_fraud_label ELSE 0 END)
                      / NULLIF(SUM(CASE WHEN HOUR(t.transaction_datetime) NOT BETWEEN 0 AND 5 THEN 1 ELSE 0 END), 0), 0), 2) AS overnight_to_daytime_ratio
FROM transactions t
GROUP BY t.transaction_channel
ORDER BY overnight_to_daytime_ratio DESC;

#Q065 Transaction monitoring
#Problem : Cross-border spread is a monitoring signal.
#Question: Do accounts that transact in several merchant countries carry higher fraud rates?

WITH account_countries AS (
    SELECT t.account_id,
           COUNT(DISTINCT m.merchant_country_code) AS countries_used
    FROM transactions t
    INNER JOIN merchants m ON m.merchant_id = t.merchant_id
    GROUP BY t.account_id
)
SELECT CASE
           WHEN ac.countries_used = 1 THEN '1 One country'
           WHEN ac.countries_used = 2 THEN '2 Two countries'
           WHEN ac.countries_used <= 4 THEN '3 Three to four countries'
           ELSE '4 Five or more countries'
       END AS countries_used_band,
       COUNT(DISTINCT ac.account_id) AS accounts,
       COUNT(*) AS transactions,
       SUM(t.is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct
FROM transactions t
INNER JOIN account_countries ac ON ac.account_id = t.account_id
GROUP BY countries_used_band
ORDER BY countries_used_band;

#Q066 Transaction monitoring
#Problem : Channel usage intensity sets realistic alert baselines for each channel.
#Question: How often does each channel get used per active account-month?

SELECT t.transaction_channel AS channel,
       COUNT(*) AS transactions,
       COUNT(DISTINCT t.account_id, DATE_FORMAT(t.transaction_datetime, '%Y-%m')) AS active_account_months,
       ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT t.account_id, DATE_FORMAT(t.transaction_datetime, '%Y-%m')), 0), 2) AS transactions_per_account_month
FROM transactions t
GROUP BY t.transaction_channel
ORDER BY transactions_per_account_month DESC;

#Q067 Transaction monitoring
#Problem : Very short gaps between transactions on one account are typical of automated card testing.
#Question: How does fraud rate depend on the time gap between an account's consecutive transactions?

WITH gaps AS (
    SELECT t.transaction_id,
           t.is_fraud_label,
           TIMESTAMPDIFF(SECOND,
                         LAG(t.transaction_datetime) OVER (PARTITION BY t.account_id
                                                           ORDER BY t.transaction_datetime, t.transaction_id),
                         t.transaction_datetime) AS gap_seconds
    FROM transactions t
)
SELECT CASE
           WHEN gap_seconds < 60 THEN 'A: under 1 minute'
           WHEN gap_seconds < 300 THEN 'B: 1 to 5 minutes'
           WHEN gap_seconds < 1800 THEN 'C: 5 to 30 minutes'
           WHEN gap_seconds < 7200 THEN 'D: 30 minutes to 2 hours'
           ELSE 'E: 2 hours or more'
       END AS gap_band,
       COUNT(*) AS transactions,
       SUM(is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct
FROM gaps
WHERE gap_seconds IS NOT NULL
GROUP BY gap_band
ORDER BY gap_band;

#Q068 Transaction monitoring
#Problem : Stable accounts make deviations easier to spot.
#Question: Do accounts with very variable spending (high coefficient of variation) show higher fraud rates?

WITH account_variation AS (
    SELECT t.account_id,
           COUNT(*) AS n,
           AVG(t.amount_gbp) AS mean_amount,
           STDDEV_SAMP(t.amount_gbp) AS sd_amount
    FROM transactions t
    GROUP BY t.account_id
    HAVING COUNT(*) >= 5
),
account_cv AS (
    SELECT account_id,
           sd_amount / NULLIF(mean_amount, 0) AS coefficient_of_variation
    FROM account_variation
)
SELECT CASE
           WHEN acv.coefficient_of_variation < 0.5 THEN 'A: under 0.50 (stable)'
           WHEN acv.coefficient_of_variation < 1.0 THEN 'B: 0.50 to 0.99'
           WHEN acv.coefficient_of_variation < 1.5 THEN 'C: 1.00 to 1.49'
           ELSE 'D: 1.50 and above (variable)'
       END AS variability_band,
       COUNT(DISTINCT acv.account_id) AS accounts,
       COUNT(t.transaction_id) AS transactions,
       SUM(t.is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(t.is_fraud_label) / NULLIF(COUNT(t.transaction_id), 0), 3) AS fraud_rate_pct
FROM account_cv acv
INNER JOIN transactions t ON t.account_id = acv.account_id
GROUP BY variability_band
ORDER BY variability_band;

#Q069 Transaction monitoring
#Problem : Sudden change in ticket size relative to the previous transaction is a behavioural change signal.
#Question: How do fraud rates differ when a transaction's amount jumps sharply (4x or more) or drops sharply (to 25% or less) versus the account's previous transaction?

WITH amount_changes AS (
    SELECT t.transaction_id,
           t.is_fraud_label,
           t.amount_gbp,
           LAG(t.amount_gbp) OVER (PARTITION BY t.account_id
                                   ORDER BY t.transaction_datetime, t.transaction_id) AS previous_amount_gbp
    FROM transactions t
)
SELECT CASE
           WHEN amount_gbp >= 4 * previous_amount_gbp THEN 'Sharp increase (4x or more)'
           WHEN amount_gbp <= 0.25 * previous_amount_gbp THEN 'Sharp decrease (25% or less)'
           ELSE 'Typical change' END AS amount_change_flag,
       COUNT(*) AS transactions,
       SUM(is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct
FROM amount_changes
WHERE previous_amount_gbp IS NOT NULL
  AND previous_amount_gbp > 0
GROUP BY amount_change_flag
ORDER BY amount_change_flag;

#Q070 Transaction monitoring
#Problem : Merchant-channel pairs are the most specific place to apply a rule without penalising the whole merchant or channel.
#Question: Which merchant and channel combinations have fraud rates at least twice the portfolio average, with at least 300 transactions?

SELECT m.merchant_name,
       m.merchant_category,
       t.transaction_channel,
       COUNT(*) AS transactions,
       SUM(t.is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(t.is_fraud_label) / COUNT(*), 3) AS fraud_rate_pct,
       ROUND((SUM(t.is_fraud_label) / COUNT(*))
             / NULLIF((SELECT SUM(is_fraud_label) / COUNT(*) FROM transactions), 0), 2) AS rate_multiple_vs_portfolio
FROM transactions t
INNER JOIN merchants m ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_name, m.merchant_category, t.transaction_channel
HAVING COUNT(*) >= 300
   AND SUM(t.is_fraud_label) / COUNT(*) >= 2 * (SELECT SUM(is_fraud_label) / COUNT(*) FROM transactions)
ORDER BY rate_multiple_vs_portfolio DESC, transactions DESC
LIMIT 25;

#Q071 Transaction monitoring
#Problem : Multiple weak indicators together are more useful than any single rule.
#Question: Which accounts show three or more observable risk indicators at once?

WITH account_activity AS (
    SELECT t.account_id,
           COUNT(*) AS transactions,
           SUM(t.amount_gbp) AS total_spend_gbp,
           MAX(CASE WHEN t.is_international = 1 AND t.amount_gbp >= 500 THEN 1 ELSE 0 END) AS high_value_international,
           CASE WHEN SUM(CASE WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 THEN 1 ELSE 0 END) / COUNT(*) >= 0.25
                THEN 1 ELSE 0 END AS overnight_majority
    FROM transactions t
    GROUP BY t.account_id
),
daily_peaks AS (
    SELECT t.account_id,
           MAX(daily_count) AS max_txns_one_day
    FROM (
        SELECT account_id, DATE(transaction_datetime) AS txn_day, COUNT(*) AS daily_count
        FROM transactions
        GROUP BY account_id, DATE(transaction_datetime)
    ) AS t
    GROUP BY t.account_id
),
indicators AS (
    SELECT aa.account_id,
           aa.transactions,
           aa.total_spend_gbp,
           aa.high_value_international,
           aa.overnight_majority,
           CASE WHEN dp.max_txns_one_day >= 5 THEN 1 ELSE 0 END AS high_velocity_day,
           CASE WHEN a.utilisation_as_of >= 0.80 THEN 1 ELSE 0 END AS utilisation_at_least_80,
           CASE WHEN a.max_dpd_as_of >= 30 THEN 1 ELSE 0 END AS dpd_30_plus
    FROM account_activity aa
    INNER JOIN daily_peaks dp ON dp.account_id = aa.account_id
    INNER JOIN accounts a ON a.account_id = aa.account_id
)
SELECT account_id,
       (high_value_international + overnight_majority + high_velocity_day
        + utilisation_at_least_80 + dpd_30_plus) AS indicator_count,
       high_value_international,
       overnight_majority,
       high_velocity_day,
       utilisation_at_least_80,
       dpd_30_plus,
       transactions,
       ROUND(total_spend_gbp, 2) AS total_spend_gbp
FROM indicators
WHERE (high_value_international + overnight_majority + high_velocity_day
       + utilisation_at_least_80 + dpd_30_plus) >= 3
ORDER BY indicator_count DESC, total_spend_gbp DESC, account_id
LIMIT 100;

#Q072 Transaction monitoring
#Problem : Identical amounts repeated many times can indicate card testing, subscription abuse or a standard payment that is itself suspicious.
#Question: How often do accounts repeat exactly the same transaction amount, and what share of those repeats are fraud?

WITH amount_groups AS (
    SELECT t.account_id,
           t.amount_gbp,
           COUNT(*) AS repeats,
           SUM(t.is_fraud_label) AS fraud_in_group
    FROM transactions t
    GROUP BY t.account_id, t.amount_gbp
    HAVING COUNT(*) >= 3
)
SELECT CASE
           WHEN repeats BETWEEN 3 AND 4 THEN '1 Three to four times'
           WHEN repeats BETWEEN 5 AND 9 THEN '2 Five to nine times'
           ELSE '3 Ten or more times'
       END AS repeat_count_band,
       COUNT(*) AS amount_repeat_groups,
       SUM(repeats) AS transactions_in_groups,
       SUM(fraud_in_group) AS fraud_transactions,
       ROUND(100.0 * SUM(fraud_in_group) / NULLIF(SUM(repeats), 0), 3) AS fraud_rate_pct
FROM amount_groups
GROUP BY repeat_count_band
ORDER BY repeat_count_band;

#Q073 Transaction monitoring
#Problem : A heavy-use account near its limit has less buffer if it is compromised.
#Question: Which accounts combine high transaction frequency (50+ transactions) with utilisation of 60% or more?

SELECT t.account_id,
       COUNT(*) AS transactions,
       ROUND(SUM(t.amount_gbp), 2) AS total_spend_gbp,
       ROUND(100.0 * a.utilisation_as_of, 2) AS utilisation_pct,
       SUM(t.is_fraud_label) AS fraud_transactions,
       a.product_type
FROM transactions t
INNER JOIN accounts a ON a.account_id = t.account_id
WHERE a.utilisation_as_of >= 0.60
GROUP BY t.account_id, a.utilisation_as_of, a.product_type
HAVING COUNT(*) >= 50
ORDER BY transactions DESC, utilisation_pct DESC, t.account_id
LIMIT 50;

#Q074 Transaction monitoring
#Problem : Weekend patterns differ for some channels (for example leisure spending).
#Question: How do fraud rates compare between weekend and weekday transactions in each channel?

SELECT t.transaction_channel AS channel,
       SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) NOT IN (1, 7) THEN 1 ELSE 0 END) AS weekday_transactions,
       ROUND(100.0 * SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) NOT IN (1, 7) THEN t.is_fraud_label ELSE 0 END)
             / NULLIF(SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) NOT IN (1, 7) THEN 1 ELSE 0 END), 0), 3) AS weekday_fraud_rate_pct,
       SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) IN (1, 7) THEN 1 ELSE 0 END) AS weekend_transactions,
       ROUND(100.0 * SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) IN (1, 7) THEN t.is_fraud_label ELSE 0 END)
             / NULLIF(SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) IN (1, 7) THEN 1 ELSE 0 END), 0), 3) AS weekend_fraud_rate_pct,
       ROUND((SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) IN (1, 7) THEN t.is_fraud_label ELSE 0 END)
              / NULLIF(SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) IN (1, 7) THEN 1 ELSE 0 END), 0))
             / NULLIF(SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) NOT IN (1, 7) THEN t.is_fraud_label ELSE 0 END)
                      / NULLIF(SUM(CASE WHEN DAYOFWEEK(t.transaction_datetime) NOT IN (1, 7) THEN 1 ELSE 0 END), 0), 0), 2) AS weekend_to_weekday_ratio
FROM transactions t
GROUP BY t.transaction_channel
ORDER BY weekend_to_weekday_ratio DESC;

#Q075 Transaction monitoring
#Problem : A customer-level baseline catches behaviour change that an account-level baseline would miss when a customer splits spend across cards.
#Question: Which transactions are at least three times larger than the customer's other transactions across all of their accounts (leave-one-out, customer level)?

WITH customer_baseline AS (
    SELECT a.customer_id,
           t.transaction_id,
           t.amount_gbp,
           t.is_fraud_label,
           COUNT(*) OVER (PARTITION BY a.customer_id) AS customer_txn_count,
           (SUM(t.amount_gbp) OVER (PARTITION BY a.customer_id) - t.amount_gbp)
             / NULLIF(COUNT(*) OVER (PARTITION BY a.customer_id) - 1, 0) AS other_txns_avg
    FROM transactions t
    INNER JOIN accounts a ON a.account_id = t.account_id
)
SELECT CASE WHEN amount_gbp >= 3 * other_txns_avg THEN 'Anomaly: at least 3x customer average'
            ELSE 'Within normal range' END AS flag,
       COUNT(*) AS transactions,
       SUM(is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(AVG(amount_gbp), 2) AS average_amount_gbp
FROM customer_baseline
WHERE customer_txn_count >= 5
GROUP BY flag
ORDER BY flag;

#Q076 Transaction monitoring
#Problem : Single features are weak; combinations of channel, time and amount give more specific and explainable rules.
#Question: Which suspicious combinations of channel, time and amount carry the highest fraud rates?

WITH combos AS (
    SELECT t.transaction_channel,
           t.amount_gbp,
           t.is_fraud_label,
           CASE
               WHEN t.transaction_channel IN ('Online', 'Phone Order') AND HOUR(t.transaction_datetime) BETWEEN 0 AND 5 AND t.amount_gbp >= 250
                   THEN 'A: Card-not-present, overnight, 250+'
               WHEN t.transaction_channel IN ('Online', 'Phone Order') AND HOUR(t.transaction_datetime) BETWEEN 0 AND 5
                   THEN 'B: Card-not-present, overnight, under 250'
               WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 AND t.amount_gbp >= 250
                   THEN 'C: Card-present, overnight, 250+'
               WHEN t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 250
                   THEN 'D: Card-not-present, daytime, 250+'
               ELSE 'E: All other transactions'
           END AS combination_label
    FROM transactions t
)
SELECT combination_label,
       COUNT(*) AS transactions,
       SUM(is_fraud_label) AS fraud_transactions,
       ROUND(100.0 * SUM(is_fraud_label) / NULLIF(COUNT(*), 0), 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN is_fraud_label = 1 THEN amount_gbp ELSE 0 END), 2) AS fraud_value_gbp
FROM combos
GROUP BY combination_label
ORDER BY combination_label;

#Q077 Transaction monitoring
#Problem : Investigation capacity is limited, so ranking by explainable points focuses analysts on the top accounts first.
#Question: Which accounts rank highest for investigation using a transparent points rule built only from observable signals?

WITH account_points AS (
    SELECT t.account_id,
           SUM(CASE WHEN t.transaction_channel IN ('Online', 'Phone Order') AND HOUR(t.transaction_datetime) BETWEEN 0 AND 5 THEN 1 ELSE 0 END) AS card_not_present_overnight_txns,
           SUM(CASE WHEN t.is_international = 1 AND t.amount_gbp >= 250 THEN 1 ELSE 0 END) AS international_250_plus_txns,
           SUM(CASE WHEN t.amount_gbp >= 500 THEN 1 ELSE 0 END) AS high_value_500_plus_txns,
           COUNT(*) AS transactions,
           SUM(t.is_fraud_label) AS post_hoc_fraud_transactions
    FROM transactions t
    GROUP BY t.account_id
),
scored AS (
    SELECT ap.account_id,
           (2 * ap.card_not_present_overnight_txns + ap.international_250_plus_txns + ap.high_value_500_plus_txns) AS risk_points,
           ap.card_not_present_overnight_txns,
           ap.international_250_plus_txns,
           ap.high_value_500_plus_txns,
           ap.transactions,
           ap.post_hoc_fraud_transactions
    FROM account_points ap
)
SELECT DENSE_RANK() OVER (ORDER BY s.risk_points DESC, s.account_id) AS investigation_rank,
       s.account_id,
       s.risk_points,
       s.card_not_present_overnight_txns,
       s.international_250_plus_txns,
       s.high_value_500_plus_txns,
       s.transactions,
       s.post_hoc_fraud_transactions
FROM scored s
WHERE s.risk_points > 0
ORDER BY investigation_rank, s.account_id
LIMIT 25;

#Q078 Transaction monitoring
#Problem : A rule that catches fraud but flags many genuine customers creates friction, cost and complaints.
#Question: How do three candidate monitoring rules compare on fraud captured, genuine transactions flagged and precision?

WITH rule_flags AS (
    SELECT t.transaction_id,
           t.is_fraud_label,
           CASE WHEN t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 500 THEN 1 ELSE 0 END AS r1_card_not_present_500,
           CASE WHEN HOUR(t.transaction_datetime) BETWEEN 0 AND 5 AND t.is_international = 1 THEN 1 ELSE 0 END AS r2_overnight_international,
           CASE WHEN (SELECT COUNT(*)
                      FROM transactions t2
                      WHERE t2.account_id = t.account_id
                        AND t2.transaction_datetime >= t.transaction_datetime - INTERVAL 24 HOUR
                        AND t2.transaction_datetime <= t.transaction_datetime) >= 5 THEN 1 ELSE 0 END AS r3_velocity_5_in_24h
    FROM transactions t
),
totals AS (
    SELECT COUNT(*) AS all_txns,
           SUM(is_fraud_label) AS all_fraud,
           COUNT(*) - SUM(is_fraud_label) AS all_genuine
    FROM rule_flags
)
SELECT 'R1 Card-not-present and 500+' AS rule_name,
       SUM(rf.r1_card_not_present_500) AS flagged_transactions,
       SUM(CASE WHEN rf.r1_card_not_present_500 = 1 THEN rf.is_fraud_label ELSE 0 END) AS fraud_captured,
       SUM(CASE WHEN rf.r1_card_not_present_500 = 1 AND rf.is_fraud_label = 0 THEN 1 ELSE 0 END) AS genuine_flagged,
       ROUND(100.0 * SUM(CASE WHEN rf.r1_card_not_present_500 = 1 THEN rf.is_fraud_label ELSE 0 END) / NULLIF(SUM(rf.r1_card_not_present_500), 0), 2) AS precision_pct,
       ROUND(100.0 * SUM(CASE WHEN rf.r1_card_not_present_500 = 1 THEN rf.is_fraud_label ELSE 0 END) / NULLIF(MAX(tt.all_fraud), 0), 2) AS recall_pct,
       ROUND(100.0 * SUM(CASE WHEN rf.r1_card_not_present_500 = 1 AND rf.is_fraud_label = 0 THEN 1 ELSE 0 END) / NULLIF(MAX(tt.all_genuine), 0), 2) AS false_positive_rate_pct
FROM rule_flags rf CROSS JOIN totals tt
UNION ALL
SELECT 'R2 Overnight and international',
       SUM(rf.r2_overnight_international),
       SUM(CASE WHEN rf.r2_overnight_international = 1 THEN rf.is_fraud_label ELSE 0 END),
       SUM(CASE WHEN rf.r2_overnight_international = 1 AND rf.is_fraud_label = 0 THEN 1 ELSE 0 END),
       ROUND(100.0 * SUM(CASE WHEN rf.r2_overnight_international = 1 THEN rf.is_fraud_label ELSE 0 END) / NULLIF(SUM(rf.r2_overnight_international), 0), 2),
       ROUND(100.0 * SUM(CASE WHEN rf.r2_overnight_international = 1 THEN rf.is_fraud_label ELSE 0 END) / NULLIF(MAX(tt.all_fraud), 0), 2),
       ROUND(100.0 * SUM(CASE WHEN rf.r2_overnight_international = 1 AND rf.is_fraud_label = 0 THEN 1 ELSE 0 END) / NULLIF(MAX(tt.all_genuine), 0), 2)
FROM rule_flags rf CROSS JOIN totals tt
UNION ALL
SELECT 'R3 Five or more in trailing 24 hours',
       SUM(rf.r3_velocity_5_in_24h),
       SUM(CASE WHEN rf.r3_velocity_5_in_24h = 1 THEN rf.is_fraud_label ELSE 0 END),
       SUM(CASE WHEN rf.r3_velocity_5_in_24h = 1 AND rf.is_fraud_label = 0 THEN 1 ELSE 0 END),
       ROUND(100.0 * SUM(CASE WHEN rf.r3_velocity_5_in_24h = 1 THEN rf.is_fraud_label ELSE 0 END) / NULLIF(SUM(rf.r3_velocity_5_in_24h), 0), 2),
       ROUND(100.0 * SUM(CASE WHEN rf.r3_velocity_5_in_24h = 1 THEN rf.is_fraud_label ELSE 0 END) / NULLIF(MAX(tt.all_fraud), 0), 2),
       ROUND(100.0 * SUM(CASE WHEN rf.r3_velocity_5_in_24h = 1 AND rf.is_fraud_label = 0 THEN 1 ELSE 0 END) / NULLIF(MAX(tt.all_genuine), 0), 2)
FROM rule_flags rf CROSS JOIN totals tt;

#Q079 Transaction monitoring
#Problem : Rule performance drifts as fraud patterns and customer behaviour change.
#Question: How does monitoring performance for the card-not-present 250+ rule change month by month?

SELECT DATE_FORMAT(t.transaction_datetime, '%Y-%m') AS calendar_month,
       COUNT(*) AS transactions,
       SUM(CASE WHEN t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 250 THEN 1 ELSE 0 END) AS flagged_transactions,
       SUM(CASE WHEN t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 250 THEN t.is_fraud_label ELSE 0 END) AS fraud_flagged,
       SUM(CASE WHEN t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 250 AND t.is_fraud_label = 0 THEN 1 ELSE 0 END) AS genuine_flagged,
       ROUND(100.0 * SUM(CASE WHEN t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 250 THEN t.is_fraud_label ELSE 0 END)
             / NULLIF(SUM(CASE WHEN t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 250 THEN 1 ELSE 0 END), 0), 2) AS precision_pct,
       ROUND(100.0 * SUM(CASE WHEN t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 250 THEN t.is_fraud_label ELSE 0 END)
             / NULLIF(SUM(t.is_fraud_label), 0), 2) AS monthly_fraud_recall_pct
FROM transactions t
GROUP BY DATE_FORMAT(t.transaction_datetime, '%Y-%m')
ORDER BY calendar_month;

#Q080 Transaction monitoring
#Problem : Turns the monitoring analysis into an operational plan with alert volumes that analysts can staff against.
#Question: How should investigation effort be prioritised across four tiers, and what weekly alert volume does each tier create?

WITH tiered AS (
    SELECT t.is_fraud_label,
           CASE
               WHEN t.transaction_channel IN ('Online', 'Phone Order') AND HOUR(t.transaction_datetime) BETWEEN 0 AND 5 AND t.amount_gbp >= 250
                   THEN 'P1 Card-not-present overnight 250+'
               WHEN (t.transaction_channel IN ('Online', 'Phone Order') AND t.amount_gbp >= 500)
                 OR (HOUR(t.transaction_datetime) BETWEEN 0 AND 5 AND t.is_international = 1)
                   THEN 'P2 Card-not-present 500+ or overnight international'
               WHEN t.is_international = 1 AND t.amount_gbp >= 250
                   THEN 'P3 International 250+'
               ELSE 'P4 No rule matched'
           END AS priority_tier,
           t.amount_gbp
    FROM transactions t
),
tier_summary AS (
    SELECT priority_tier,
           COUNT(*) AS transactions,
           SUM(is_fraud_label) AS fraud_transactions
    FROM tiered
    GROUP BY priority_tier
)
SELECT priority_tier,
       transactions,
       fraud_transactions,
       ROUND(100.0 * fraud_transactions / NULLIF(transactions, 0), 3) AS precision_pct,
       ROUND(transactions / (DATEDIFF(DATE '2026-09-30', DATE '2021-10-01') / 7), 1) AS average_weekly_alerts,
       ROUND(100.0 * fraud_transactions / NULLIF(SUM(fraud_transactions) OVER (), 0), 2) AS share_of_fraud_captured_pct
FROM tier_summary
ORDER BY priority_tier;

#==============================================================================#
#  PROBLEM 5: PORTFOLIO PERFORMANCE AND STRATEGY
#  Scenario: Leadership wants to know whether the card book is growing, how healthy it is, and which segments need action.
#==============================================================================#

#Q081 Portfolio
#Problem : The base activity series for every portfolio KPI and for forecasting.
#Question: What are monthly transaction volume and total transaction value across all 60 months?

SELECT DATE_FORMAT(t.transaction_datetime, '%Y-%m') AS calendar_month,
       COUNT(*) AS transactions,
       ROUND(SUM(t.amount_gbp), 2) AS total_value_gbp,
       ROUND(SUM(t.amount_gbp) / NULLIF(COUNT(*), 0), 2) AS average_ticket_gbp
FROM transactions t
GROUP BY DATE_FORMAT(t.transaction_datetime, '%Y-%m')
ORDER BY calendar_month;

#Q082 Portfolio
#Problem : 2021 and 2026 are partial years.
#Question: How do annual transaction volume and value compare once partial years are adjusted for months covered?

WITH annual AS (
    SELECT YEAR(t.transaction_datetime) AS calendar_year,
           COUNT(DISTINCT DATE_FORMAT(t.transaction_datetime, '%Y-%m')) AS months_covered,
           COUNT(*) AS transactions,
           SUM(t.amount_gbp) AS total_value_gbp
    FROM transactions t
    GROUP BY YEAR(t.transaction_datetime)
)
SELECT calendar_year,
       months_covered,
       transactions,
       ROUND(total_value_gbp, 2) AS total_value_gbp,
       ROUND(transactions / NULLIF(months_covered, 0), 0) AS transactions_per_month,
       ROUND(total_value_gbp / NULLIF(months_covered, 0), 2) AS value_per_month_gbp,
       ROUND(100.0 * (total_value_gbp / NULLIF(months_covered, 0)
                      - LAG(total_value_gbp / NULLIF(months_covered, 0)) OVER (ORDER BY calendar_year))
             / NULLIF(LAG(total_value_gbp / NULLIF(months_covered, 0)) OVER (ORDER BY calendar_year), 0), 2) AS value_per_month_change_pct
FROM annual
ORDER BY calendar_year;

#Q083 Portfolio
#Problem : All 20 quarters from 2021-Q4 to 2026-Q3 are complete, so this is the cleanest trend view.
#Question: How do transaction value and volume trend quarter by quarter, with quarter-on-quarter growth?

WITH quarterly AS (
    SELECT YEAR(t.transaction_datetime) AS yr,
           QUARTER(t.transaction_datetime) AS qtr,
           COUNT(*) AS transactions,
           SUM(t.amount_gbp) AS total_value_gbp
    FROM transactions t
    GROUP BY YEAR(t.transaction_datetime), QUARTER(t.transaction_datetime)
)
SELECT CONCAT(yr, ' Q', qtr) AS quarter_label,
       transactions,
       ROUND(total_value_gbp, 2) AS total_value_gbp,
       ROUND(100.0 * (transactions - LAG(transactions) OVER (ORDER BY yr, qtr))
             / NULLIF(LAG(transactions) OVER (ORDER BY yr, qtr), 0), 2) AS transactions_qoq_change_pct,
       ROUND(100.0 * (total_value_gbp - LAG(total_value_gbp) OVER (ORDER BY yr, qtr))
             / NULLIF(LAG(total_value_gbp) OVER (ORDER BY yr, qtr), 0), 2) AS value_qoq_change_pct
FROM quarterly
ORDER BY yr, qtr;

#Q084 Portfolio
#Problem : Mix by product shows which product lines carry the weakest account health.
#Question: How is the account-status mix (Active, Delinquent, Suspended, Closed) distributed across products?

SELECT a.product_type,
       a.account_status_as_of AS account_status,
       COUNT(*) AS accounts,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY a.product_type), 0), 2) AS share_within_product_pct
FROM accounts a
GROUP BY a.product_type, a.account_status_as_of
ORDER BY a.product_type, accounts DESC;

#Q085 Portfolio
#Problem : Portfolio balance and utilisation show how much of the authorised limit is in use.
#Question: What are the total balance, credit limit, unused limit and utilisation of open accounts by product?

SELECT a.product_type,
       COUNT(*) AS open_accounts,
       ROUND(SUM(a.credit_limit_gbp), 2) AS total_limit_gbp,
       ROUND(SUM(a.current_balance_gbp), 2) AS total_balance_gbp,
       ROUND(SUM(GREATEST(a.credit_limit_gbp - a.current_balance_gbp, 0)), 2) AS unused_limit_gbp,
       ROUND(100.0 * SUM(a.current_balance_gbp) / NULLIF(SUM(a.credit_limit_gbp), 0), 2) AS utilisation_pct
FROM accounts a
WHERE a.account_close_date IS NULL
GROUP BY a.product_type
ORDER BY total_balance_gbp DESC;

#Q086 Portfolio
#Problem : Growth of the customer base is a strategic KPI and the denominator for many other metrics.
#Question: How have new customers and new accounts grown each quarter, and what is the cumulative base?

WITH customer_q AS (
    SELECT YEAR(c.customer_join_date) AS yr, QUARTER(c.customer_join_date) AS qtr, COUNT(*) AS new_customers
    FROM customers c
    GROUP BY YEAR(c.customer_join_date), QUARTER(c.customer_join_date)
),
account_q AS (
    SELECT YEAR(a.account_open_date) AS yr, QUARTER(a.account_open_date) AS qtr, COUNT(*) AS new_accounts
    FROM accounts a
    GROUP BY YEAR(a.account_open_date), QUARTER(a.account_open_date)
),
all_quarters AS (
    SELECT yr, qtr FROM customer_q
    UNION
    SELECT yr, qtr FROM account_q
)
SELECT CONCAT(aq.yr, ' Q', aq.qtr) AS quarter_label,
       COALESCE(cq.new_customers, 0) AS new_customers,
       SUM(COALESCE(cq.new_customers, 0)) OVER (ORDER BY aq.yr, aq.qtr ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_customers,
       COALESCE(aq2.new_accounts, 0) AS new_accounts,
       SUM(COALESCE(aq2.new_accounts, 0)) OVER (ORDER BY aq.yr, aq.qtr ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_accounts
FROM all_quarters aq
LEFT JOIN customer_q cq ON cq.yr = aq.yr AND cq.qtr = aq.qtr
LEFT JOIN account_q aq2 ON aq2.yr = aq.yr AND aq2.qtr = aq.qtr
ORDER BY aq.yr, aq.qtr;

#Q087 Portfolio
#Problem : A channel can look large in total but be small per transaction.
#Question: How does each channel's average transaction value compare with the portfolio average in each year?

WITH yearly_channel AS (
    SELECT YEAR(t.transaction_datetime) AS calendar_year,
           t.transaction_channel AS channel,
           COUNT(*) AS channel_transactions,
           AVG(t.amount_gbp) AS channel_avg_ticket
    FROM transactions t
    GROUP BY YEAR(t.transaction_datetime), t.transaction_channel
),
yearly_portfolio AS (
    SELECT YEAR(t.transaction_datetime) AS calendar_year,
           AVG(t.amount_gbp) AS portfolio_avg_ticket
    FROM transactions t
    GROUP BY YEAR(t.transaction_datetime)
)
SELECT yc.calendar_year,
       yc.channel,
       yc.channel_transactions,
       ROUND(yc.channel_avg_ticket, 2) AS channel_avg_ticket_gbp,
       ROUND(yp.portfolio_avg_ticket, 2) AS portfolio_avg_ticket_gbp,
       ROUND(100.0 * yc.channel_avg_ticket / NULLIF(yp.portfolio_avg_ticket, 0), 1) AS index_vs_portfolio
FROM yearly_channel yc
JOIN yearly_portfolio yp ON yc.calendar_year = yp.calendar_year
ORDER BY yc.calendar_year, yc.channel;

#Q088 Portfolio
#Problem : Revenue and profit are common management asks, so the answer must be explicit about what the data can and cannot support.
#Question: What revenue or profitability can the portfolio report from this data?

SELECT 'Total spend base (NOT revenue)' AS metric,
       ROUND(SUM(t.amount_gbp), 2) AS value,
       'Input to an interchange calculation only. Interchange rates are not in the data.' AS status
FROM transactions t
UNION ALL
SELECT 'Interchange income', NULL,
       'NOT AVAILABLE: no interchange rates or merchant fee ledger in dataset'
UNION ALL
SELECT 'Interest and fee income', NULL,
       'NOT AVAILABLE: no interest, fee or revolving-rate data in dataset'
UNION ALL
SELECT 'Recoveries and chargebacks', NULL,
       'NOT AVAILABLE: no recovery or chargeback ledger in dataset'
UNION ALL
SELECT 'Net fraud loss', NULL,
       'NOT AVAILABLE: fraud label is a synthetic flag, not a loss ledger';

#Q089 Portfolio
#Problem : Fraud exposure as a proportion of value is comparable across years and channels, unlike raw totals.
#Question: What share of transaction value is fraud-labelled, by year and channel?

SELECT YEAR(t.transaction_datetime) AS calendar_year,
       t.transaction_channel,
       ROUND(SUM(t.amount_gbp), 2) AS total_value_gbp,
       ROUND(SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END), 2) AS fraud_value_gbp,
       ROUND(100.0 * SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) / NULLIF(SUM(t.amount_gbp), 0), 3) AS fraud_value_share_pct
FROM transactions t
GROUP BY YEAR(t.transaction_datetime), t.transaction_channel
ORDER BY calendar_year, fraud_value_share_pct DESC;

#Q090 Portfolio
#Problem : Shows which segment-product pockets hold the delinquent balance, so limits and collections effort can follow the money.
#Question: How is 30+ DPD outstanding exposure distributed across customer segments and products?

WITH pocket_exposure AS (
    SELECT c.customer_segment,
           a.product_type,
           SUM(CASE WHEN p.dpd_as_of >= 30 THEN p.outstanding_gbp ELSE 0 END) AS outstanding_30_plus_gbp,
           SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) AS obligations_30_plus,
           COUNT(*) AS obligations
    FROM payments p
    INNER JOIN accounts a ON a.account_id = p.account_id
    INNER JOIN customers c ON c.customer_id = a.customer_id
    GROUP BY c.customer_segment, a.product_type
)
SELECT customer_segment,
       product_type,
       ROUND(outstanding_30_plus_gbp, 2) AS outstanding_30_plus_gbp,
       ROUND(100.0 * outstanding_30_plus_gbp / NULLIF(SUM(outstanding_30_plus_gbp) OVER (), 0), 2) AS share_of_30_plus_outstanding_pct,
       ROUND(100.0 * obligations_30_plus / NULLIF(obligations, 0), 3) AS rate_30_plus_dpd_pct
FROM pocket_exposure
ORDER BY outstanding_30_plus_gbp DESC;

#Q091 Portfolio
#Problem : One regional table lets management see the trade-offs between growth, risk and fraud by region.
#Question: How do the regions compare on portfolio size, balance, fraud rate and 30+ DPD rate in one scorecard?

WITH region_accounts AS (
    SELECT c.region,
           COUNT(*) AS open_accounts,
           ROUND(SUM(a.current_balance_gbp), 2) AS open_balance_gbp
    FROM accounts a
    INNER JOIN customers c ON c.customer_id = a.customer_id
    WHERE a.account_close_date IS NULL
    GROUP BY c.region
),
region_fraud AS (
    SELECT c.region,
           COUNT(*) AS transactions,
           SUM(t.is_fraud_label) AS fraud_transactions
    FROM transactions t
    INNER JOIN accounts a ON a.account_id = t.account_id
    INNER JOIN customers c ON c.customer_id = a.customer_id
    GROUP BY c.region
),
region_dpd AS (
    SELECT c.region,
           COUNT(*) AS obligations,
           SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) AS obligations_30_plus
    FROM payments p
    INNER JOIN accounts a ON a.account_id = p.account_id
    INNER JOIN customers c ON c.customer_id = a.customer_id
    GROUP BY c.region
)
SELECT ra.region,
       ra.open_accounts,
       ra.open_balance_gbp,
       rf.transactions,
       ROUND(100.0 * rf.fraud_transactions / NULLIF(rf.transactions, 0), 3) AS fraud_rate_pct,
       rd.obligations,
       ROUND(100.0 * rd.obligations_30_plus / NULLIF(rd.obligations, 0), 3) AS rate_30_plus_dpd_pct
FROM region_accounts ra
INNER JOIN region_fraud rf ON rf.region = ra.region
INNER JOIN region_dpd rd ON rd.region = ra.region
ORDER BY ra.open_balance_gbp DESC;

#Q092 Portfolio
#Problem : Category performance shapes merchant strategy, acquirer conversations and category-level controls.
#Question: How do merchant categories compare on spend share, average ticket and fraud rate?

WITH category_summary AS (
    SELECT m.merchant_category,
           COUNT(*) AS transactions,
           SUM(t.amount_gbp) AS spend_gbp,
           SUM(t.is_fraud_label) AS fraud_transactions
    FROM transactions t
    INNER JOIN merchants m ON m.merchant_id = t.merchant_id
    GROUP BY m.merchant_category
)
SELECT merchant_category,
       transactions,
       ROUND(spend_gbp, 2) AS spend_gbp,
       ROUND(100.0 * spend_gbp / NULLIF(SUM(spend_gbp) OVER (), 0), 2) AS share_of_spend_pct,
       ROUND(spend_gbp / NULLIF(transactions, 0), 2) AS average_ticket_gbp,
       ROUND(100.0 * fraud_transactions / NULLIF(transactions, 0), 3) AS fraud_rate_pct
FROM category_summary
ORDER BY spend_gbp DESC;

#Q093 Portfolio
#Problem : Month-on-month shows momentum.
#Question: What are the month-over-month and year-over-year changes in transaction value?

WITH monthly_value AS (
    SELECT DATE_FORMAT(t.transaction_datetime, '%Y-%m') AS calendar_month,
           SUM(t.amount_gbp) AS total_value_gbp
    FROM transactions t
    GROUP BY DATE_FORMAT(t.transaction_datetime, '%Y-%m')
)
SELECT calendar_month,
       ROUND(total_value_gbp, 2) AS total_value_gbp,
       ROUND(100.0 * (total_value_gbp - LAG(total_value_gbp, 1) OVER (ORDER BY calendar_month))
             / NULLIF(LAG(total_value_gbp, 1) OVER (ORDER BY calendar_month), 0), 2) AS mom_change_pct,
       ROUND(LAG(total_value_gbp, 12) OVER (ORDER BY calendar_month), 2) AS value_same_month_last_year_gbp,
       ROUND(100.0 * (total_value_gbp - LAG(total_value_gbp, 12) OVER (ORDER BY calendar_month))
             / NULLIF(LAG(total_value_gbp, 12) OVER (ORDER BY calendar_month), 0), 2) AS yoy_change_pct
FROM monthly_value
ORDER BY calendar_month;

#Q094 Portfolio
#Problem : Top and bottom segments show where practices work and where support is needed.
#Question: Which regions are the top three and bottom three performers on collection rate?

WITH region_collection AS (
    SELECT c.region,
           COUNT(*) AS obligations,
           100.0 * SUM(p.amount_paid_gbp) / NULLIF(SUM(p.amount_due_gbp), 0) AS collection_rate_pct,
           RANK() OVER (ORDER BY SUM(p.amount_paid_gbp) / NULLIF(SUM(p.amount_due_gbp), 0) DESC) AS best_rank,
           RANK() OVER (ORDER BY SUM(p.amount_paid_gbp) / NULLIF(SUM(p.amount_due_gbp), 0) ASC) AS worst_rank
    FROM payments p
    INNER JOIN accounts a ON a.account_id = p.account_id
    INNER JOIN customers c ON c.customer_id = a.customer_id
    GROUP BY c.region
)
SELECT 'Top 3' AS performance_group, region, obligations, ROUND(collection_rate_pct, 2) AS collection_rate_pct
FROM region_collection
WHERE best_rank <= 3
UNION ALL
SELECT 'Bottom 3', region, obligations, ROUND(collection_rate_pct, 2)
FROM region_collection
WHERE worst_rank <= 3
ORDER BY performance_group DESC, collection_rate_pct DESC;

#Q095 Portfolio
#Problem : High concentration means more of the risk depends on a few accounts or categories.
#Question: How concentrated is the portfolio (top 10% of accounts by balance, and merchant-category spend concentration measured by Herfindahl index)?

WITH balance_deciles AS (
    SELECT a.account_id,
           a.current_balance_gbp,
           NTILE(10) OVER (ORDER BY a.current_balance_gbp DESC) AS balance_decile
    FROM accounts a
    WHERE a.account_close_date IS NULL
),
top_decile AS (
    SELECT ROUND(100.0 * SUM(CASE WHEN balance_decile = 1 THEN current_balance_gbp ELSE 0 END)
                 / NULLIF(SUM(current_balance_gbp), 0), 2) AS top_decile_balance_share_pct
    FROM balance_deciles
),
category_shares AS (
    SELECT m.merchant_category,
           SUM(t.amount_gbp) AS spend_gbp
    FROM transactions t
    INNER JOIN merchants m ON m.merchant_id = t.merchant_id
    GROUP BY m.merchant_category
),
category_share_pct AS (
    SELECT merchant_category,
           100.0 * spend_gbp / NULLIF(SUM(spend_gbp) OVER (), 0) AS share_pct
    FROM category_shares
),
hhi AS (
    SELECT ROUND(SUM(POWER(share_pct, 2)), 1) AS hhi_points
    FROM category_share_pct
)
SELECT 'Top 10% of open accounts: share of open balance (%)' AS concentration_measure,
       td.top_decile_balance_share_pct AS value,
       'Share of balance held by the largest tenth of open accounts' AS interpretation_note
FROM top_decile td
UNION ALL
SELECT 'Merchant-category spend HHI (0-10,000)', h.hhi_points,
       'Sum of squared category spend shares. Above 2,500 is typically read as highly concentrated.'
FROM hhi h;

#Q096 Portfolio
#Problem : Cohorts show whether newer customers behave differently from older ones.
#Question: How do customer cohorts (by join quarter) compare on average balance, 30+ DPD rate and collection rate?

WITH cohort_customers AS (
    SELECT c.customer_id,
           CONCAT(YEAR(c.customer_join_date), ' Q', QUARTER(c.customer_join_date)) AS join_quarter_label,
           YEAR(c.customer_join_date) AS join_year,
           QUARTER(c.customer_join_date) AS join_qtr
    FROM customers c
),
cohort_accounts AS (
    SELECT cc.join_quarter_label, cc.join_year, cc.join_qtr,
           COUNT(DISTINCT cc.customer_id) AS customers,
           COUNT(a.account_id) AS open_accounts,
           SUM(a.current_balance_gbp) AS open_balance_gbp
    FROM cohort_customers cc
    LEFT JOIN accounts a ON a.customer_id = cc.customer_id AND a.account_close_date IS NULL
    GROUP BY cc.join_quarter_label, cc.join_year, cc.join_qtr
),
cohort_payments AS (
    SELECT CONCAT(YEAR(c.customer_join_date), ' Q', QUARTER(c.customer_join_date)) AS join_quarter_label,
           COUNT(*) AS obligations,
           SUM(CASE WHEN p.dpd_as_of >= 30 THEN 1 ELSE 0 END) AS obligations_30_plus,
           SUM(p.amount_paid_gbp) AS paid_gbp,
           SUM(p.amount_due_gbp) AS due_gbp
    FROM payments p
    INNER JOIN accounts a ON a.account_id = p.account_id
    INNER JOIN customers c ON c.customer_id = a.customer_id
    GROUP BY CONCAT(YEAR(c.customer_join_date), ' Q', QUARTER(c.customer_join_date))
)
SELECT ca.join_quarter_label,
       ca.customers,
       ca.open_accounts,
       ROUND(ca.open_balance_gbp / NULLIF(ca.open_accounts, 0), 2) AS average_open_balance_gbp,
       ROUND(100.0 * cp.obligations_30_plus / NULLIF(cp.obligations, 0), 3) AS rate_30_plus_dpd_pct,
       ROUND(100.0 * cp.paid_gbp / NULLIF(cp.due_gbp, 0), 2) AS collection_rate_pct
FROM cohort_accounts ca
LEFT JOIN cohort_payments cp ON cp.join_quarter_label = ca.join_quarter_label
ORDER BY ca.join_year, ca.join_qtr;

#Q097 Portfolio
#Problem : Gives a single comparable number per segment to rank risk-adjusted attractiveness.
#Question: How do customer segments compare on a risk-cost PROXY (30+ DPD outstanding plus fraud value, as a share of spend)?

WITH seg_spend AS (
    SELECT c.customer_segment,
           SUM(t.amount_gbp) AS spend_gbp,
           SUM(CASE WHEN t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) AS fraud_value_gbp
    FROM transactions t
    INNER JOIN accounts a ON a.account_id = t.account_id
    INNER JOIN customers c ON c.customer_id = a.customer_id
    GROUP BY c.customer_segment
),
seg_dpd AS (
    SELECT c.customer_segment,
           SUM(CASE WHEN p.dpd_as_of >= 30 THEN p.outstanding_gbp ELSE 0 END) AS outstanding_30_plus_gbp
    FROM payments p
    INNER JOIN accounts a ON a.account_id = p.account_id
    INNER JOIN customers c ON c.customer_id = a.customer_id
    GROUP BY c.customer_segment
),
proxy AS (
    SELECT ss.customer_segment,
           ss.spend_gbp,
           ss.fraud_value_gbp,
           sd.outstanding_30_plus_gbp,
           100.0 * (ss.fraud_value_gbp + sd.outstanding_30_plus_gbp) / NULLIF(ss.spend_gbp, 0) AS risk_cost_proxy_pct_of_spend
    FROM seg_spend ss
    INNER JOIN seg_dpd sd ON sd.customer_segment = ss.customer_segment
)
SELECT customer_segment,
       ROUND(spend_gbp, 2) AS spend_gbp,
       ROUND(fraud_value_gbp, 2) AS fraud_value_gbp,
       ROUND(outstanding_30_plus_gbp, 2) AS outstanding_30_plus_gbp,
       ROUND(risk_cost_proxy_pct_of_spend, 3) AS risk_cost_proxy_pct_of_spend,
       DENSE_RANK() OVER (ORDER BY risk_cost_proxy_pct_of_spend DESC) AS risk_proxy_rank
FROM proxy
ORDER BY risk_proxy_rank, customer_segment;

#Q098 Portfolio
#Problem : Threshold choice is the main lever for the trade-off between fraud caught and customer friction.
#Question: How do alternative amount thresholds change fraud captured, genuine transactions flagged and precision for a card-not-present rule?

WITH threshold_parameters AS (
    SELECT 100 AS threshold_gbp
    UNION ALL SELECT 250
    UNION ALL SELECT 500
    UNION ALL SELECT 750
    UNION ALL SELECT 1000
),
card_not_present AS (
    SELECT t.amount_gbp, t.is_fraud_label
    FROM transactions t
    WHERE t.transaction_channel IN ('Online', 'Phone Order')
),
totals AS (
    SELECT SUM(t.is_fraud_label) AS all_fraud_in_channel
    FROM transactions t
    WHERE t.transaction_channel IN ('Online', 'Phone Order')
)
SELECT tp.threshold_gbp,
       COUNT(*) AS flagged_transactions,
       SUM(cnp.is_fraud_label) AS fraud_captured,
       COUNT(*) - SUM(cnp.is_fraud_label) AS genuine_flagged,
       ROUND(100.0 * SUM(cnp.is_fraud_label) / NULLIF(COUNT(*), 0), 2) AS precision_pct,
       ROUND(100.0 * SUM(cnp.is_fraud_label) / NULLIF(MAX(tt.all_fraud_in_channel), 0), 2) AS recall_pct,
       ROUND(SUM(CASE WHEN cnp.is_fraud_label = 1 THEN cnp.amount_gbp ELSE 0 END), 2) AS fraud_value_captured_gbp,
       ROUND(SUM(CASE WHEN cnp.is_fraud_label = 0 THEN cnp.amount_gbp ELSE 0 END), 2) AS genuine_value_flagged_gbp
FROM threshold_parameters tp
CROSS JOIN card_not_present cnp
CROSS JOIN totals tt
WHERE cnp.amount_gbp >= tp.threshold_gbp
GROUP BY tp.threshold_gbp
ORDER BY tp.threshold_gbp;

#Q099 Portfolio
#Problem : Value-based friction matters to customers and operations.
#Question: At the 250 GBP card-not-present threshold, how much fraud value is flagged compared with genuine value flagged, by channel?

WITH flagged_value AS (
    SELECT t.transaction_channel,
           SUM(CASE WHEN t.amount_gbp >= 250 AND t.is_fraud_label = 1 THEN t.amount_gbp ELSE 0 END) AS fraud_value_flagged_gbp,
           SUM(CASE WHEN t.amount_gbp >= 250 AND t.is_fraud_label = 0 THEN t.amount_gbp ELSE 0 END) AS genuine_value_flagged_gbp
    FROM transactions t
    WHERE t.transaction_channel IN ('Online', 'Phone Order')
    GROUP BY t.transaction_channel
)
SELECT fv.transaction_channel,
       ROUND(fv.fraud_value_flagged_gbp, 2) AS fraud_value_flagged_gbp,
       ROUND(fv.genuine_value_flagged_gbp, 2) AS genuine_value_flagged_gbp,
       ROUND(100.0 * fv.fraud_value_flagged_gbp / NULLIF(fv.fraud_value_flagged_gbp + fv.genuine_value_flagged_gbp, 0), 2) AS value_precision_pct,
       ROUND(100.0 * fv.fraud_value_flagged_gbp / NULLIF(SUM(fv.fraud_value_flagged_gbp) OVER (), 0), 2) AS flagged_fraud_value_share_of_all_fraud_pct
FROM flagged_value fv
ORDER BY value_precision_pct DESC;

#Q100 Portfolio
#Problem : One page that summarises fraud, credit risk, collections, monitoring and portfolio health, with each metric traced to its source question.
#Question: What does the integrated management scorecard show across the five business problems?

SELECT 'BP1 Fraud' AS business_problem,
       'Fraud rate (% of transactions)' AS metric,
       (SELECT ROUND(100.0 * SUM(is_fraud_label) / COUNT(*), 3) FROM transactions) AS value,
       'Q002' AS source_question
UNION ALL
SELECT 'BP1 Fraud', 'Fraud value (GBP)',
       (SELECT ROUND(SUM(amount_gbp), 2) FROM transactions WHERE is_fraud_label = 1), 'Q002'
UNION ALL
SELECT 'BP2 Credit risk', 'Open accounts',
       (SELECT COUNT(*) FROM accounts WHERE account_close_date IS NULL), 'Q026'
UNION ALL
SELECT 'BP2 Credit risk', 'Tier 1 High share of open balance (%)',
       (SELECT ROUND(100.0 * SUM(CASE WHEN max_dpd_as_of >= 30 OR utilisation_as_of > 1.00 THEN current_balance_gbp ELSE 0 END)
                     / NULLIF(SUM(current_balance_gbp), 0), 2)
          FROM accounts WHERE account_close_date IS NULL), 'Q027'
UNION ALL
SELECT 'BP2 Credit risk', 'Accounts over credit limit (open)',
       (SELECT COUNT(*) FROM accounts WHERE account_close_date IS NULL AND current_balance_gbp > credit_limit_gbp), 'Q034'
UNION ALL
SELECT 'BP3 Collections', 'Rate of obligations 30+ DPD (%)',
       (SELECT ROUND(100.0 * SUM(CASE WHEN dpd_as_of >= 30 THEN 1 ELSE 0 END) / COUNT(*), 3) FROM payments), 'Q042'
UNION ALL
SELECT 'BP3 Collections', 'Overdue outstanding (GBP, DPD above 0)',
       (SELECT ROUND(SUM(CASE WHEN dpd_as_of > 0 THEN outstanding_gbp ELSE 0 END), 2) FROM payments), 'Q041'
UNION ALL
SELECT 'BP3 Collections', 'Collection rate (% of billed minimum payments paid)',
       (SELECT ROUND(100.0 * SUM(amount_paid_gbp) / SUM(amount_due_gbp), 2) FROM payments), 'Q044'
UNION ALL
SELECT 'BP4 Monitoring', 'Card-not-present 250+ rule: precision (%)',
       (SELECT ROUND(100.0 * SUM(CASE WHEN is_fraud_label = 1 THEN 1 ELSE 0 END)
                     / NULLIF(SUM(CASE WHEN transaction_channel IN ('Online', 'Phone Order') AND amount_gbp >= 250 THEN 1 ELSE 0 END), 0), 2)
          FROM transactions
          WHERE transaction_channel IN ('Online', 'Phone Order') AND amount_gbp >= 250), 'Q079'
UNION ALL
SELECT 'BP5 Portfolio', 'Transaction value, full five-year window (GBP)',
       (SELECT ROUND(SUM(amount_gbp), 2) FROM transactions), 'Q081'
UNION ALL
SELECT 'BP5 Portfolio', 'Suspended accounts (count, as of 30 Sep 2026)',
       (SELECT COUNT(*) FROM accounts WHERE account_status_as_of = 'Suspended'), 'Q084';

