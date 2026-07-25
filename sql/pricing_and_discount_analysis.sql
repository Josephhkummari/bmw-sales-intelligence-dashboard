--Pricing & Discount Analysis

--6. Which vehicle models receive the highest average discounts, and how do they compare across the product portfolio?
select dm.model,round(avg(fs.discount_percent),2) as avg_discount_percent
from dimmodel dm join factsales fs
using (model_key)
group by dm.model
order by avg_discount_percent desc
--7. Which models are sold closest to their MSRP, and which require the largest price reductions to complete a sale?
with model_pricing as (
    select
        dm.model,
        round(avg(fs.msrp_usd), 2) as avg_msrp_price,
        round(avg(fs.final_sale_price_usd), 2) as avg_final_price,
        round(avg(fs.discount_amount_usd), 2) as avg_price_reduction
    from dimmodel dm
    join factsales fs using (model_key)
    group by dm.model
),
ranked_pricing as (
    select
        *,
        row_number() over (order by avg_price_reduction asc) as closest_to_msrp_rank,
        row_number() over (order by avg_price_reduction desc) as largest_reduction_rank
    from model_pricing

),
closest_to_msrp as (
    select
        'Closest to MSRP' as pricing_group,
        model,
        avg_msrp_price,
        avg_final_price,
        avg_price_reduction,
        closest_to_msrp_rank as sort_rank
    from ranked_pricing
    where closest_to_msrp_rank <= 5

),
largest_reduction as (
    select
        'Largest Reduction' as pricing_group,
        model,
        avg_msrp_price,
        avg_final_price,
        avg_price_reduction,
        largest_reduction_rank as sort_rank
    from ranked_pricing
    where largest_reduction_rank <= 5
)
select pricing_group, model, avg_msrp_price, avg_final_price, avg_price_reduction
from closest_to_msrp
union all
select pricing_group, model, avg_msrp_price, avg_final_price, avg_price_reduction
from largest_reduction
order by pricing_group;
--8. Do higher discount levels lead to increased vehicle sales?
select
    fs.discount_bucket,
    count(*) as units_sold,
    round(avg(fs.discount_percent), 2) as avg_discount_percent,
    round(count(*) * 100.0 / sum(count(*)) over (), 2) as sales_share_pct
from factsales fs
group by fs.discount_bucket
order by case fs.discount_bucket
    when 'Low' then 1
    when 'Medium' then 2
    when 'High' then 3
    when 'Very High' then 4
    else 5
end;

--9. How does the average profit_proxy vary across different regions?
select dr.region,
       round(avg(fs.final_sale_price_usd - fs.msrp_usd + fs.discount_amount_usd), 2) as avg_profit_proxy
from dimregion dr 
join factsales fs using (region_key)
group by dr.region
order by avg_profit_proxy desc;

--10. Discount % trend by month — is discounting increasing over time?
with monthly_discount as (
    select
        dd.year,
        dd.month,
        round(avg(fs.discount_percent), 2) as avg_discount_percent
    from factsales fs
    join dimdate dd using (date_key)
    group by dd.year, dd.month
)
select
    year,
    month,
    avg_discount_percent,
    lag(avg_discount_percent) over (order by year, month) as prev_month_discount,
    round(avg_discount_percent - lag(avg_discount_percent) over (order by year, month), 2) as discount_change_pct
from monthly_discount
order by year, month;
