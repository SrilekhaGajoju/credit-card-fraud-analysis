USE Fraud_analysis;
#Create indexes
CREATE INDEX idx_card  ON fact_transactions(card_number);
CREATE INDEX idx_time  ON fact_transactions(transaction_time);
CREATE INDEX idx_merch ON fact_transactions(merchant_id);
CREATE INDEX idx_fraud ON fact_transactions(fraud_flag);
CREATE INDEX idx_state ON dim_customer(state);


-- Overall KPIs
SELECT
    COUNT(*)                                         AS total_transactions,
    SUM(fraud_flag)                                  AS fraud_transactions,
    ROUND(AVG(fraud_flag) * 100, 3)                  AS fraud_rate_pct,
    ROUND(SUM(amount), 2)                            AS total_value,
    ROUND(SUM(CASE WHEN fraud_flag = 1 THEN amount END), 2) AS fraud_loss,
    ROUND(SUM(CASE WHEN fraud_flag = 1 THEN amount END) / SUM(amount) * 100, 3) AS fraud_value_rate_pct
FROM fact_transactions;

-- Average amount: fraud vs genuine
SELECT fraud_flag,
       COUNT(*)               AS transactions,
       ROUND(AVG(amount), 2)  AS avg_amount,
       ROUND(MAX(amount), 2)  AS max_amount
FROM fact_transactions
GROUP BY fraud_flag;


-- Fraud by category
SELECT m.category,
       COUNT(*)                          AS transactions,
       SUM(f.fraud_flag)                 AS fraud_count,
       ROUND(AVG(f.fraud_flag) * 100, 3) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN f.fraud_flag = 1 THEN f.amount END), 2) AS fraud_loss
FROM fact_transactions f
JOIN dim_merchant m ON f.merchant_id = m.merchant_id
GROUP BY m.category
ORDER BY fraud_rate_pct DESC;

-- Fraud by hour
SELECT `hour`,
       COUNT(*)                          AS transactions,
       SUM(fraud_flag)                   AS fraud_count,
       ROUND(AVG(fraud_flag) * 100, 3)   AS fraud_rate_pct
FROM fact_transactions
GROUP BY `hour`
ORDER BY `hour`;

-- Fraud by state (top 10 by fraud count)
SELECT c.state,
       COUNT(*)                          AS transactions,
       SUM(f.fraud_flag)                 AS fraud_count,
       ROUND(AVG(f.fraud_flag) * 100, 3) AS fraud_rate_pct
FROM fact_transactions f
JOIN dim_customer c ON f.card_number = c.card_number
GROUP BY c.state
ORDER BY fraud_count DESC
LIMIT 10;

-- Fraud by amount band
SELECT amount_band,
       COUNT(*)                          AS transactions,
       SUM(fraud_flag)                   AS fraud_count,
       ROUND(AVG(fraud_flag) * 100, 3)   AS fraud_rate_pct
FROM fact_transactions
GROUP BY amount_band
ORDER BY fraud_rate_pct DESC;


#Risk Index with a CTE
WITH overall AS (
    SELECT AVG(fraud_flag) AS overall_rate FROM fact_transactions
)
SELECT m.category,
       ROUND(AVG(f.fraud_flag) * 100, 3)                    AS fraud_rate_pct,
       ROUND(AVG(f.fraud_flag) / o.overall_rate, 2)         AS risk_index
FROM fact_transactions f
JOIN dim_merchant m ON f.merchant_id = m.merchant_id
CROSS JOIN overall o
GROUP BY m.category, o.overall_rate
ORDER BY risk_index DESC;

#Time gap between a card’s transactions
WITH gaps AS (
    SELECT transaction_id, fraud_flag,
           TIMESTAMPDIFF(MINUTE,
               LAG(transaction_time) OVER (PARTITION BY card_number ORDER BY transaction_time),
               transaction_time) AS mins_since_prev
    FROM fact_transactions
)
SELECT CASE
           WHEN mins_since_prev IS NULL  THEN '1. First transaction'
           WHEN mins_since_prev <= 10    THEN '2. 0-10 min'
           WHEN mins_since_prev <= 60    THEN '3. 11-60 min'
           WHEN mins_since_prev <= 1440  THEN '4. 1-24 hours'
           ELSE                               '5. Over 24 hours'
       END AS gap_band,
       COUNT(*)                          AS transactions,
       SUM(fraud_flag)                   AS fraud_count,
       ROUND(AVG(fraud_flag) * 100, 3)   AS fraud_rate_pct
FROM gaps
GROUP BY gap_band
ORDER BY gap_band;

#Daily trend, running total and rolling 7-day rate
WITH daily AS (
    SELECT DATE(transaction_time) AS txn_date,
           COUNT(*)               AS txns,
           SUM(fraud_flag)        AS frauds,
           SUM(CASE WHEN fraud_flag = 1 THEN amount ELSE 0 END) AS fraud_loss
    FROM fact_transactions
    GROUP BY DATE(transaction_time)
)
SELECT txn_date, txns, frauds, ROUND(fraud_loss, 2) AS fraud_loss,
       ROUND(SUM(fraud_loss) OVER (ORDER BY txn_date), 2) AS cumulative_fraud_loss,
       ROUND(SUM(frauds) OVER (ORDER BY txn_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
           / SUM(txns)   OVER (ORDER BY txn_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) * 100, 3)
           AS rolling_7d_fraud_rate_pct
FROM daily
ORDER BY txn_date;

#Riskiest merchants
SELECT * FROM (
    SELECT m.merchant_name, m.category,
           COUNT(*)                          AS transactions,
           SUM(f.fraud_flag)                 AS fraud_count,
           ROUND(AVG(f.fraud_flag) * 100, 2) AS fraud_rate_pct,
           RANK() OVER (ORDER BY AVG(f.fraud_flag) DESC) AS risk_rank
    FROM fact_transactions f
    JOIN dim_merchant m ON f.merchant_id = m.merchant_id
    GROUP BY m.merchant_id, m.merchant_name, m.category
    HAVING COUNT(*) >= 500
) ranked
WHERE risk_rank <= 10;

#Repeat-fraud cards
SELECT fraud_txns AS fraud_transactions_on_card,
       COUNT(*)   AS cards
FROM (
    SELECT card_number, SUM(fraud_flag) AS fraud_txns
    FROM fact_transactions
    GROUP BY card_number
) t
GROUP BY fraud_txns
ORDER BY fraud_txns;