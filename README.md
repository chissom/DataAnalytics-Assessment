## Question 1: High-Value Customers with Multiple Products

**Objective:**  
Identify customers who have at least one funded savings plan **and** one funded investment plan, then report for each:
- Total number of savings plans opened
- Number of those savings plans that are funded
- Total number of investment plans opened
- Number of those investment plans that are funded
- Sum of all deposit amounts (converted from kobo to NGN)

### Approach

1. **All Plans vs. Funded Plans**  
   - I first used CTEs to capture:
     - **`all_savings_plans`** / **`all_investment_plans`**: counts of every plan a customer has opened, regardless of funding status.
     - **`funded_savings_plans`** / **`funded_investment_plans`**: counts of only those plans that have at least one deposit (`confirmed_amount > 0`).
2. **Deposit Aggregation**  
   - In **`customer_deposits`**, I summed up every `confirmed_amount` from the savings transactions table, giving total deposits in kobo.
3. **Filtering & Joining**  
   - I joined only those customers who appear in both the all-savings and all-investment CTEs, and also in both funded-plans CTEs, guaranteeing each has ≥ 1 funded plan in each category.
4. **Name Resolution**  
   - I concatenated `first_name` and `last_name` to produce a display name.
5. **Final Output**  
   - Converted kobo to NGN with `ROUND(total_kobo/100.0, 2)` and ordered by descending deposit value.

### Challenges & Resolutions

- **Null `name` Field**  
  When I ran the initial query, the `name` column returned all `NULL`. Names are crucial for reporting, so I switched to using the `first_name` and `last_name` columns and concatenated them to form each customer’s full name.

- **Desire for Deeper Insight**  
  After ensuring that customers had at least one funded savings and investment plan, I wondered: _how many of their plans were actually funded?_  
  A customer might open 10 savings plans but fund only 3.  
  By adding `funded_savings_count` and `funded_investment_count`, we gain visibility into funding rates per customer.  
  This extra layer of analysis can help Cowrywise focus on improving plan funding success—identifying customers who open plans but never fund them, and tailoring engagement accordingly.





## Question 2: Transaction Frequency Analysis

**Objective:**  
Segment customers by how frequently they transact on their savings accounts, classifying them into:
- **High Frequency** (≥10 transactions/month)  
- **Medium Frequency** (3–9 transactions/month)  
- **Low Frequency** (≤2 transactions/month)  

For each segment, report:
- `frequency_category`
- `customer_count`
- `avg_transactions_per_month`

---

### Approach

1. **Bucket by Year–Month**  
   - Used the `verification_transaction_date` timestamp in `savings_savingsaccount` to extract both `YEAR(verification_transaction_date)` and `MONTH(verification_transaction_date)`.  
   - Grouped by `owner_id`, year, and month to count each customer’s total transactions per calendar month.

2. **Compute Individual Averages**  
   - Averaged those monthly counts per customer to get `avg_txn_per_month`.  

3. **Categorize**  
   - Applied a `CASE` expression on each customer’s average:
     - ≥10 → **High Frequency**  
     - 3–9 → **Medium Frequency**  
     - ≤2 → **Low Frequency**  

4. **Aggregate for Reporting**  
   - Grouped by `frequency_category` to count customers in each bucket (`customer_count`) and to compute the segment’s overall average transactions per month (`avg_transactions_per_month`), rounded to one decimal.

---

### Challenges & Resolutions

- **No Explicit “Month” Column**  
  The table lacked a dedicated month field, so I couldn’t directly group by “month.”  
  **Solution:** I extracted the year and month components from the `verification_transaction_date` timestamp using `YEAR(verification_transaction_date)` and `MONTH(verification_transaction_date)`. This allowed me to accurately bucket transactions into calendar months for each customer.

- **Ensuring Accurate Boundaries**  
  With the derived year–month buckets, it was critical to verify there were no off-by-one errors at the category edges (2→3 and 9→10 transactions). The clear `CASE` logic (with `>=`, `BETWEEN`, and `ELSE`) ensures every average value falls into exactly one category.

By deriving month information from `verification_transaction_date` and carefully structuring the CTEs, we achieved a clean, performant query that segments users by transaction frequency.```


## Question 3: Account Inactivity Alert

**Objective:**  
Flag every active savings or investment plan that has gone **365 days** without any inflow transaction.

---

### Approach

1. **Identify “Last Inflow” Per Plan**  
   - In the CTE `last_txns`, I grouped the `savings_savingsaccount` table by `plan_id` and took the `MAX(verification_transaction_date)`—the timestamp when a deposit was actually verified—to determine each plan’s most recent incoming transaction.

2. **Filter Only Active Entities**  
   - **Customers:**  
     Used `users_customuser.is_active = 1` to restrict to customers who still have an open relationship with the business.  
   - **Plans:**  
     Used `plans_plan.is_deleted = 0` to exclude any plans that a customer has explicitly cancelled or removed.  
   - Together, these two flags ensure we only alert on plans that **both** belong to an active customer **and** remain live in the system.

3. **Detect One-Year Inactivity**  
   - In the main query, I joined each active plan to its `last_transaction_date`.  
   - Then applied:  
     ```sql
     last_transaction_date < DATE_SUB(CURRENT_DATE, INTERVAL 365 DAY)
     ```  
     to select plans whose last verified deposit was more than 365 days ago.

4. **Output Fields**  
   - `plan_id`  
   - `owner_id`  
   - Derived `type` (“Savings” vs. “Investment”)  
   - `last_transaction_date`  
   - `inactivity_days` calculated via `DATEDIFF(CURRENT_DATE, last_transaction_date)`

---

### Challenges & Solutions

- **Why Both `is_active` and `is_deleted`?**  
  - **`is_active` (users_customuser):** Ensures we only consider customers who remain active in the system—no alerts for deactivated users.  
  - **`is_deleted` (plans_plan):** Ensures we only consider plans that haven’t been cancelled or removed by the customer—no alerts for “closed” accounts.  
  - **Combined Filter:** Without both, we risk alerting on plans that are either owned by deactivated customers or have already been deleted, neither of which is actionable for operations.

- **Choosing `verification_transaction_date`**  
  - The inflow’s **verification** timestamp is the definitive indicator of when funds actually posted. In contrast, a generic `transaction_date` can reflect initiation or scheduling. Using the verified date guarantees we measure real account activity.

By combining customer and plan–level activity flags with the one-year cutoff on verified inflows, this query reliably surfaces only those live accounts that need an inactivity check.```




## Question 4: Customer Lifetime Value (CLV) Estimation

**Objective:**
Estimate a basic **Customer Lifetime Value (CLV)** for each user using transaction behavior and account tenure.
The formula used is:

```text
CLV = (total_transactions / tenure_months) * 12 * avg_profit_per_transaction
```

We assume `avg_profit_per_transaction` is **0.1%** of the **average confirmed transaction amount**.

---

### Approach

1. **Join Users to Transactions via Plans**

   * To trace transactions to a customer, we first join:

     * `users_customuser` → `plans_plan` (via `owner_id`)
     * Then `plans_plan` → `savings_savingsaccount` (via `plan_id`)
   * This ensures that only transactions tied to valid user plans are counted.

2. **Calculate Tenure in Months**

   * Used `TIMESTAMPDIFF(MONTH, u.date_joined, CURRENT_DATE)` to compute how long each user has held an account.
   * Wrapped the result in `GREATEST(..., 1)` to avoid division by zero for users who joined less than a month ago.

3. **Count Transactions and Compute Average Value**

   * Used `COUNT(s.id)` for total transactions and `AVG(s.confirmed_amount / 100)` to compute average transaction value (converted from **kobo to naira**).
   * Only `confirmed_amount` values are used to ensure we exclude failed or pending inflows.

4. **Compute Estimated CLV**

   * CLV is estimated using:

     ```sql
     (COUNT(transactions) / tenure_months) * 12 * 0.001 * avg_transaction_value
     ```
   * Multiplied by `12` to annualize the lifetime value.
   * Multiplied by `0.001` to reflect 0.1% assumed profit margin on each transaction.

5. **Output Fields**

   * `customer_id`
   * `name`
   * `tenure_months`
   * `total_transactions`
   * `estimated_clv` (rounded to 2 decimal places)
   * Results are sorted in **descending order** of `estimated_clv`.

---

### Challenges & Solutions

* **Avoiding Division by Zero**

  * Used `GREATEST(..., 1)` to force a minimum of 1 month tenure so users who signed up recently don’t break the calculation.

* **Why Join Through Plans?**

  * Savings transactions aren’t tied directly to users. They link to `plans_plan`, which in turn is linked to `users_customuser`. This two-step join ensures that each transaction can be confidently assigned to a user.

* **Why Use Confirmed Amounts?**

  * `confirmed_amount` ensures only actual credited amounts are included. Using unconfirmed or placeholder values could distort profit or transaction counts.

* **Why Use 0.1% Profit Margin?**

  * In absence of real profit-per-transaction data, we assume a simplified constant profit rate of **0.1%** for estimation purposes.

