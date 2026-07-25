--Regional Performance Analysis


--11. Which regions generate the highest revenue and sales volume?

select region,sum(final_sale_price_usd) as total_revenue,count(transaction_id) as total_sales
from dimregion join factsales
using (region_key)
group by region
order by total_revenue desc,total_sales desc

--12. Which region records the highest average customer satisfaction?

select region,round(avg(customer_satisfaction_score),2) as Avg_customer_satisfaction_score
from dimregion join factsales 
using (region_key)
group by region
order by Avg_customer_satisfaction_score desc

--13. Which region has the highest proportion of repeat customers?
select region,ROUND(
        AVG(is_repeat_customer::int) * 100,
        2
    ) AS repeat_customer_rate
FROM dimregion
JOIN factsales
USING(region_key)
GROUP BY region
ORDER BY repeat_customer_rate DESC;
--14. How has revenue grown year-over-year (YoY) across different regions?
with regionwise_revenue as (
    select
        region,
        year,
        sum(final_sale_price_usd) as total_revenue
    from dimregion
    join factsales using (region_key)
    join dimdate using (date_key)
    group by region, year
)
select
    region,
    year,
    total_revenue,
    lag(total_revenue) over (partition by region order by year) as prev_year_revenue,
    round(
        (total_revenue - lag(total_revenue) over (partition by region order by year)) * 100.0
        / nullif(lag(total_revenue) over (partition by region order by year), 0),
        2
    ) as yoy_growth_pct
from regionwise_revenue
order by region, year;
