-- Assessment_Q1.sql
WITH
  -- Identifies all savings plans per customer (funded or not)
  all_savings_plans AS (
    SELECT
      p.owner_id,
      COUNT(DISTINCT p.id) AS total_savings_count
    FROM adashi_staging.plans_plan AS p
    WHERE p.is_regular_savings = 1
    GROUP BY p.owner_id
  ),
  
  -- Identifies all investment plans per customer (funded or not)
  all_investment_plans AS (
    SELECT
      p.owner_id,
      COUNT(DISTINCT p.id) AS total_investment_count
    FROM adashi_staging.plans_plan AS p
    WHERE p.is_a_fund = 1
    GROUP BY p.owner_id
  ),
  
  -- Identifies only funded savings plans
  funded_savings_plans AS (
    SELECT
      p.owner_id,
      COUNT(DISTINCT p.id) AS funded_savings_count
    FROM adashi_staging.plans_plan AS p
    JOIN adashi_staging.savings_savingsaccount AS sa ON sa.plan_id = p.id
    WHERE 
      p.is_regular_savings = 1
      AND sa.confirmed_amount > 0  -- Ensures the plan is funded
    GROUP BY p.owner_id
  ),
  
  -- Identifies only funded investment plans
  funded_investment_plans AS (
    SELECT
      p.owner_id,
      COUNT(DISTINCT p.id) AS funded_investment_count
    FROM adashi_staging.plans_plan AS p
    JOIN adashi_staging.savings_savingsaccount AS sa ON sa.plan_id = p.id
    WHERE 
      p.is_a_fund = 1
      AND sa.confirmed_amount > 0  -- Ensures the plan is funded
    GROUP BY p.owner_id
  ),
  
  -- Calculates total deposits across all plans
  customer_deposits AS (
    SELECT
      p.owner_id,
      SUM(sa.confirmed_amount) AS total_kobo
    FROM adashi_staging.plans_plan AS p
    JOIN adashi_staging.savings_savingsaccount AS sa ON sa.plan_id = p.id
    WHERE sa.confirmed_amount > 0
    GROUP BY p.owner_id
  )

SELECT
  u.id AS owner_id,
  CONCAT(u.first_name, ' ', u.last_name) AS name,
  COALESCE(asp.total_savings_count, 0) AS total_savings_count,
  COALESCE(fsp.funded_savings_count, 0) AS funded_savings_count,
  COALESCE(aip.total_investment_count, 0) AS total_investment_count,
  COALESCE(fip.funded_investment_count, 0) AS funded_investment_count,
  ROUND(COALESCE(cd.total_kobo, 0) / 100.0, 2) AS total_deposits
FROM adashi_staging.users_customuser AS u
-- Join with plans data ensuring we only get customers with both product types
JOIN all_savings_plans AS asp ON u.id = asp.owner_id
JOIN all_investment_plans AS aip ON u.id = aip.owner_id
-- Ensure at least one savings plan is funded
JOIN funded_savings_plans AS fsp ON u.id = fsp.owner_id
-- Ensure at least one investment plan is funded
JOIN funded_investment_plans AS fip ON u.id = fip.owner_id
-- Include deposit data
LEFT JOIN customer_deposits AS cd ON u.id = cd.owner_id
ORDER BY total_deposits DESC;