WITH txn_summary AS (
    SELECT 
        owner_id,
        COUNT(*) AS total_transactions,
        SUM(confirmed_amount) AS total_transaction_value
    FROM savings_savingsaccount
    WHERE confirmed_amount > 0
    GROUP BY owner_id
),
tenure AS (
    SELECT 
        id AS customer_id,
        CONCAT(first_name, ' ', last_name) AS name,
        TIMESTAMPDIFF(MONTH, date_joined, CURRENT_DATE()) AS tenure_months
    FROM users_customuser
),
clv_calc AS (
    SELECT 
        ten.customer_id,
        ten.name,
        ten.tenure_months,
        tx.total_transactions,
        ROUND( 
            (tx.total_transactions / ten.tenure_months) * 12 *
            ((tx.total_transaction_value / tx.total_transactions) * 0.001)
        , 2) AS estimated_clv
    FROM tenure ten
    JOIN txn_summary tx ON ten.customer_id = tx.owner_id
    WHERE ten.tenure_months > 0
)
SELECT *
FROM clv_calc
ORDER BY estimated_clv DESC;
