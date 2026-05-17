-- Task 1 
WITH Yearly_Sales AS (
    SELECT 
        cu.country_region,
        t.calendar_year,
        ch.channel_desc,
        SUM(s.amount_sold) AS amount_sold
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.channels ch ON s.channel_id = ch.channel_id
    JOIN sh.customers cust ON s.cust_id = cust.cust_id
    JOIN sh.countries cu ON cust.country_id = cu.country_id
    WHERE t.calendar_year BETWEEN 1999 AND 2001
      AND UPPER(cu.country_region) IN ('AMERICAS', 'ASIA', 'EUROPE')
    GROUP BY cu.country_region, t.calendar_year, ch.channel_desc
),
Calculated_Shares AS (
    SELECT 
        country_region,
        calendar_year,
        channel_desc,
        amount_sold,
        (amount_sold / SUM(amount_sold) OVER (PARTITION BY country_region, calendar_year)) * 100 AS pct_by_channels
    FROM Yearly_Sales
)
SELECT 
    country_region,
    calendar_year,
    channel_desc,
    TO_CHAR(amount_sold, '$99,999,999.99') AS "AMOUNT_SOLD",
    ROUND(pct_by_channels::numeric, 2) AS "% BY CHANNELS",
    ROUND(LAG(pct_by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year)::numeric, 2) AS "% PREVIOUS PERIOD",
    ROUND((pct_by_channels - LAG(pct_by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year))::numeric, 2) AS "% DIFF"
FROM Calculated_Shares
ORDER BY country_region, calendar_year, channel_desc;



-- Task 2
WITH Daily_Sales AS (
    SELECT 
        t.calendar_week_number,
        t.time_id,
        t.day_name,
        SUM(s.amount_sold) AS sales
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year = 1999
      AND t.calendar_week_number BETWEEN 48 AND 52
    GROUP BY t.calendar_week_number, t.time_id, t.day_name
),
Calculations AS (
    SELECT 
        calendar_week_number,
        time_id,
        day_name,
        sales,
        -- Standard Cumulative Sum
        SUM(sales) OVER (PARTITION BY calendar_week_number ORDER BY time_id) AS cum_sum,
        
        CASE 
            -- Monday needs its value, Tuesday, and BOTH Saturday/Sunday from the previous weekend
            WHEN day_name = 'Monday' THEN 
                AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING)
                
            -- Friday needs its value, Thursday, and BOTH Saturday/Sunday from the upcoming weekend
            WHEN day_name = 'Friday' THEN 
                AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING)
                
            -- Saturday and Sunday handle their respective adjacent weekend day + 1 weekday smoothly
            ELSE 
                AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING)
        END AS centered_3_day_avg
    FROM Daily_Sales
)
SELECT 
    calendar_week_number,
    time_id,
    day_name,
    ROUND(sales, 2) AS sales,
    ROUND(cum_sum, 2) AS cum_sum,
    ROUND(centered_3_day_avg, 2) AS centered_3_day_avg
FROM Calculations
WHERE calendar_week_number BETWEEN 49 AND 51
ORDER BY time_id;


--Task 3
WITH Daily_Totals AS (
    SELECT 
        time_id,
        SUM(amount_sold) AS daily_sales
    FROM sh.sales
    GROUP BY time_id
)
SELECT 
    time_id,
    daily_sales,
    AVG(daily_sales) OVER (
        ORDER BY time_id 
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS rolling_avg
FROM Daily_Totals
ORDER BY time_id;

/*
Reason for choosing ROWS: This mode is strictly based on the physical position 
of rows. By grouping transactions into daily totals first, ROWS now cleanly 
grabs exactly the day before and the day after to create a true 3-day 
moving average, completely unaffected by the volume of individual transactions.
*/


WITH Daily_Totals AS (
    SELECT 
        time_id,
        SUM(amount_sold) AS daily_sales
    FROM sh.sales
    GROUP BY time_id
)
SELECT 
    time_id,
    daily_sales,
    SUM(daily_sales) OVER (
        ORDER BY time_id 
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sales
FROM Daily_Totals
ORDER BY time_id;

/*
Reason for choosing RANGE: Unlike ROWS, RANGE operates on the actual values 
in the ORDER BY column. When used on daily aggregated totals, if there are gaps 
in dates or duplicate timestamp elements, RANGE treats identical logical values 
as peers, making it the mathematically bulletproof choice for standard 
financial running totals.
*/



WITH Weekly_Totals AS (
    SELECT 
        t.calendar_week_number,
        SUM(s.amount_sold) AS weekly_sales
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year = 1999
    GROUP BY t.calendar_week_number
)
SELECT 
    calendar_week_number,
    weekly_sales,
    AVG(weekly_sales) OVER (
        ORDER BY calendar_week_number 
        GROUPS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS three_week_avg
FROM Weekly_Totals
ORDER BY calendar_week_number;

/*
Reason for choosing GROUPS: GROUPS counts sets of rows that share duplicate 
values. By aggregating our sales by week first and providing a fully deterministic 
outer ORDER BY (without an arbitrary LIMIT), GROUPS looks back precisely at the 
2 previous distinct week units. This provides a clean, repeatable 3-week 
window evaluation.
*/







