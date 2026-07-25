-- 1. How has BMW's total revenue and vehicle sales performed across different years and quarters?

select dd.year,dd.quarter,sum(final_sale_price_usd) as total_revenue,count(*) as vehicle_sales
from factsales as fs join dimdate as dd
on fs.date_key=dd.date_key
group by dd.year,dd.quarter
order by year,quarter asc

-- 2. What is the month-over-month (MoM) growth in revenue, and are there any periods of significant increase or decline?

with monthly_sales as 
(
select year,sum(final_sale_price_usd) as revenue,extract(month from sale_date) as month
from factsales as fs join dimdate as dd
on fs.date_key=dd.date_key
group by extract(month from sale_date),extract(year from sale_date),dd.year
order by dd.year,month asc
)

select year,month,revenue,lag(revenue) over (order by year,month) as prev_month_revenue,
revenue - lag(revenue) over (order by year,month) as revenue_change,ROUND(
    (
        revenue - LAG(revenue) OVER (ORDER BY year, month)
    ) * 100.0
    /
    LAG(revenue) OVER (ORDER BY year, month),
    2
) AS mom_growth_pct
from monthly_sales

-- 3. Which BMW models generate the highest revenue, and what are the top five best-performing models?

select dm.model,sum(fs.final_sale_price_usd) as revenue
from dimmodel dm join factsales fs
on dm.model_key=fs.model_key
group by dm.model
order by revenue desc
limit 5

-- 4.How much does each region contribute to the company's total revenue?

select region,sum(fs.final_sale_price_usd) as revenue
from dimregion dr join factsales fs
on dr.region_key = fs.region_key
group by region
order by revenue desc

--5. How has cumulative revenue grown throughout the reporting period?

with monthly_sales as 
(
select year,sum(final_sale_price_usd) as revenue,extract(month from sale_date) as month
from factsales as fs join dimdate as dd
on fs.date_key=dd.date_key
group by extract(month from sale_date),extract(year from sale_date),dd.year
order by dd.year,month asc
)

select year,month,sum(revenue) over (order by year,month rows between unbounded preceding and current row) as running_total
from monthly_sales


