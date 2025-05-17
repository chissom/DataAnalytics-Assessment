-- Assessment_Q2.sql

WITH monthly_txn_counts AS (
  /* Count all transactions per customer per calendar month using transaction_date */
  SELECT
    owner_id,
    YEAR(verification_transaction_date)  AS txn_year,
    MONTH(verification_transaction_date) AS txn_month,
    COUNT(*)                AS txn_count
  FROM adashi_staging.savings_savingsaccount
  GROUP BY owner_id, txn_year, txn_month
),

avg_txn_per_customer AS (
  /* Compute each customer’s average transactions per month */
  SELECT
    owner_id,
    AVG(txn_count) AS avg_txn_per_month
  FROM monthly_txn_counts
  GROUP BY owner_id
),

categorized AS (
  /* Assign frequency category based on the average */
  SELECT
    owner_id,
    avg_txn_per_month,
    CASE
      WHEN avg_txn_per_month >= 10 THEN 'High Frequency'
      WHEN avg_txn_per_month BETWEEN 3 AND 9 THEN 'Medium Frequency'
      ELSE 'Low Frequency'
    END AS frequency_category
  FROM avg_txn_per_customer
)

SELECT
  frequency_category,
  COUNT(*)                         AS customer_count,
  ROUND(AVG(avg_txn_per_month), 1) AS avg_transactions_per_month
FROM categorized
GROUP BY frequency_category
ORDER BY 
  CASE frequency_category
    WHEN 'High Frequency'   THEN 1
    WHEN 'Medium Frequency' THEN 2
    WHEN 'Low Frequency'    THEN 3
  END;
