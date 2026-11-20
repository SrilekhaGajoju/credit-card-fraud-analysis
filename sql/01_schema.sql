CREATE DATABASE Fraud_analysis;
Use Fraud_analysis;

CREATE TABLE dim_customer (
    card_number   VARCHAR(20) PRIMARY KEY,
    gender        CHAR(1),
    city          VARCHAR(60),
    state         CHAR(2),
    city_pop      INT,
    customer_lat  DECIMAL(9,6),
    customer_long DECIMAL(9,6)
);

CREATE TABLE dim_merchant (
    merchant_id   INT PRIMARY KEY,
    merchant_name VARCHAR(100),
    category      VARCHAR(30)
);

CREATE TABLE fact_transactions (
    transaction_id   CHAR(32) PRIMARY KEY,
    card_number      VARCHAR(20),
    merchant_id      INT,
    transaction_time DATETIME,
    amount           DECIMAL(10,2),
    fraud_flag       TINYINT,
    hour             TINYINT,
    day_of_week      VARCHAR(10),
    month            VARCHAR(10),
    is_weekend       TINYINT,
    age              TINYINT,
    age_group        VARCHAR(10),
    time_of_day      VARCHAR(12),
    amount_band      VARCHAR(10),
    distance_km      DECIMAL(8,2),
    merchant_lat     DECIMAL(9,6),
    merchant_long    DECIMAL(9,6),
    FOREIGN KEY (card_number) REFERENCES dim_customer(card_number),
    FOREIGN KEY (merchant_id) REFERENCES dim_merchant(merchant_id)
);

Select 'dim_customer', count(*) from dim_customer
Union all Select 'dim_merchat', count(*) from dim_merchant
Union all Select 'fact_transaction', count(*) from fact_transactions;

Select count(*) from fact_transactions;
Select SUM(fraud_flag) from fact_transactions;



