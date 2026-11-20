Use Fraud_analysis;
CREATE VIEW vw_daily_fraud AS
SELECT DATE(transaction_time) AS txn_date,
       COUNT(*)               AS txns,
       SUM(fraud_flag)        AS frauds,
       SUM(CASE WHEN fraud_flag = 1 THEN amount ELSE 0 END) AS fraud_loss
FROM fact_transactions
GROUP BY DATE(transaction_time);

CREATE VIEW vw_merchant_risk AS
SELECT m.merchant_name, m.category,
       COUNT(*)          AS transactions,
       SUM(f.fraud_flag) AS fraud_count,
       ROUND(AVG(f.fraud_flag) * 100, 3) AS fraud_rate_pct
FROM fact_transactions f
JOIN dim_merchant m ON f.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.category;

CREATE VIEW vw_card_risk AS
SELECT f.card_number, c.state, c.gender,
       COUNT(*)                  AS transactions,
       SUM(f.fraud_flag)         AS fraud_count,
       ROUND(SUM(f.amount), 2)   AS total_spend
FROM fact_transactions f
JOIN dim_customer c ON f.card_number = c.card_number
GROUP BY f.card_number, c.state, c.gender;