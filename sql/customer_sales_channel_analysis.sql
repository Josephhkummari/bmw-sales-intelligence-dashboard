--Customer & Sales Channel Analysis

--19. Which sales channel achieves the highest repeat customer rate?
select sales_channel,round(AVG(is_repeat_customer::int) * 100,2) as repeat_customer_rate,SUM(is_repeat_customer::int) AS repeat_customers
from factsales join dimcustomer
using (customer_key)
group by sales_channel
order by repeat_customer_rate desc
--20. How does customer satisfaction vary across different financing options?
select financing_type,round(avg(customer_satisfaction_score),2) as avg_satisfaction_score
from dimcustomer join factsales
using (customer_key)
group by financing_type
order by avg_satisfaction_score desc
--21. Does delivery performance influence customer satisfaction?
select delivery_category,COUNT(*) AS total_orders,round(avg(customer_satisfaction_score),2) as avg_satisfaction_score
from factsales
group by delivery_category
order by total_orders,avg_satisfaction_score desc
--22. Which customer segment (Individual, Fleet, Corporate) contributes the most to total revenue?
select customer_type,sum(final_sale_price_usd) as total_revenue
from dimcustomer join factsales
using (customer_key)
group by customer_type
order by total_revenue desc