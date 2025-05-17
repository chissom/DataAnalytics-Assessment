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
