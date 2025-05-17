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
   - Used the `transaction_date` timestamp in `savings_savingsaccount` to extract both `YEAR(transaction_date)` and `MONTH(transaction_date)`.  
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
  **Solution:** I extracted the year and month components from the `transaction_date` timestamp using `YEAR(transaction_date)` and `MONTH(transaction_date)`. This allowed me to accurately bucket transactions into calendar months for each customer.

- **Ensuring Accurate Boundaries**  
  With the derived year–month buckets, it was critical to verify there were no off-by-one errors at the category edges (2→3 and 9→10 transactions). The clear `CASE` logic (with `>=`, `BETWEEN`, and `ELSE`) ensures every average value falls into exactly one category.

By deriving month information from `transaction_date` and carefully structuring the CTEs, we achieved a clean, performant query that segments users by transaction frequency.```

