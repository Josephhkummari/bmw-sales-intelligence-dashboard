--Product Performance Analysis
--15. Which vehicle segments contribute the most to overall sales volume?
select segment,count(*) as overall_sales
from dimmodel join factsales
using (model_key)
group by segment
order by overall_sales desc
--16. How has the revenue contribution of Electric Vehicles (EVs) changed compared to conventional fuel vehicles between 2024 and 2025?
with fuel_revenue as (
    select 
        dd.year,
        case 
            when dm.fuel_type in ('Electric', 'BEV') or dm.model in ('i4', 'i5', 'i7', 'iX') then 'Electric'
            else 'Conventional'
        end as vehicle_type,
        sum(fs.final_sale_price_usd) as overall_revenue
    from dimmodel dm 
    join factsales fs using (model_key) 
    join dimdate dd using (date_key)
    group by dd.year, 
             case 
                 when dm.fuel_type in ('Electric', 'BEV') or dm.model in ('i4', 'i5', 'i7', 'iX') then 'Electric'
                 else 'Conventional'
             end
)
select 
    year,
    vehicle_type,
    overall_revenue,
    round(overall_revenue * 100.0 / sum(overall_revenue) over (partition by year), 2) as revenue_share_pct
from fuel_revenue
order by year, vehicle_type;


--17. Which BMW models generate the highest average revenue from optional add-ons (options_cost_usd)?
select model,round(avg(options_cost_usd),2) as optional_cost_revenue
from dimmodel join factsales using(model_key)
group by model
order by optional_cost_revenue desc
--18. What are the top three best-selling vehicle models within each region?
with overall_sales as (
select model,region,count(*) as units_sold 
from dimmodel join factsales using (model_key)
join dimregion using (region_key)
group by model,region
),
ranked_regions as (
select region,model,units_sold,rank() over (partition by region order by units_sold desc) as best_sellers
from overall_sales
)

select *
from ranked_regions 
where best_sellers<=3;
