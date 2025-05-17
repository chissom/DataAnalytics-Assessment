-- Assessment_Q3.sql
-- Flag active accounts (savings or investment) with no inflow in the past 365 days.

WITH last_txns AS (
  /* Find each plan’s most recent inflow transaction */
  SELECT
    plan_id,
    MAX(verification_transaction_date) AS last_transaction_date
  FROM adashi_staging.savings_savingsaccount
  WHERE confirmed_amount > 0           -- only inflows
  GROUP BY plan_id
)

SELECT
  p.id   AS plan_id,
  p.owner_id,
  CASE
    WHEN p.is_regular_savings = 1 THEN 'Savings'
    WHEN p.is_a_fund         = 1 THEN 'Investment'
    ELSE 'Other'
  END AS type,
  lt.last_transaction_date,
  DATEDIFF(CURRENT_DATE, lt.last_transaction_date) AS inactivity_days
FROM adashi_staging.plans_plan AS p
JOIN adashi_staging.users_customuser AS u
  ON u.id = p.owner_id
  AND u.is_active = 1                   -- only active customers
LEFT JOIN last_txns AS lt
  ON lt.plan_id = p.id
WHERE p.is_deleted = 0                  -- only active plans
  AND lt.last_transaction_date < DATE_SUB(CURRENT_DATE, INTERVAL 365 DAY)
ORDER BY inactivity_days DESC;
