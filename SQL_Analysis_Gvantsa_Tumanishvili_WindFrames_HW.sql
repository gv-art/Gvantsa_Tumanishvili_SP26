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
      AND cu.country_region IN ('Americas', 'Asia', 'Europe')
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
    amount_sold AS "AMOUNT_SOLD",
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
        TRIM(TO_CHAR(t.time_id, 'Day')) AS day_name,
        SUM(s.amount_sold) AS sales
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year = 1999
      AND t.calendar_week_number BETWEEN 48 AND 52
    GROUP BY t.calendar_week_number, t.time_id
),
Weekend_Aggregated AS (
    SELECT 
        *,
        CASE 
            WHEN day_name IN ('Saturday', 'Sunday') 
            -- Combine Sat/Sun sales for the average logic
            THEN SUM(sales) OVER (PARTITION BY calendar_week_number, 
                 CASE WHEN day_name IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END)
            ELSE sales 
        END AS avg_basis_sales
    FROM Daily_Sales
),
Calculations AS (
    SELECT 
        calendar_week_number,
        time_id,
        day_name,
        sales,
        -- Standard Cumulative Sum
        SUM(sales) OVER (PARTITION BY calendar_week_number ORDER BY time_id) AS cum_sum,
        -- Custom Centered Moving Average logic to match sample report
        CASE 
            WHEN day_name = 'Monday' THEN 
                (LAG(sales, 1) OVER (ORDER BY time_id) + -- Sunday
                 LAG(sales, 2) OVER (ORDER BY time_id) + -- Saturday
                 sales + 
                 LEAD(sales, 1) OVER (ORDER BY time_id)) / 3 -- Tuesday
            WHEN day_name = 'Friday' THEN 
                (LAG(sales, 1) OVER (ORDER BY time_id) + -- Thursday
                 sales + 
                 LEAD(sales, 1) OVER (ORDER BY time_id) + -- Saturday
                 LEAD(sales, 2) OVER (ORDER BY time_id)) / 3 -- Sunday
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
SELECT 
    time_id,
    amount_sold,
    AVG(amount_sold) OVER (
        ORDER BY time_id 
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS rolling_avg
FROM sh.sales;
/*Reason for choosing ROWS: This mode is strictly based on the physical position of rows. It doesn't care if 
two rows have the same date or if there are gaps in dates; it simply grabs the row immediately before and the 
row immediately after. It is the most common choice for "n-row" smoothing.*/



SELECT 
    time_id,
    amount_sold,
    SUM(amount_sold) OVER (
        ORDER BY time_id 
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sales
FROM sh.sales;
/*Reason for choosing RANGE: Unlike ROWS, RANGE is based on the values in the ORDER BY column. If you have 10 
sales records for the same date, RANGE treats them as "peers." A running total using RANGE will show the same 
accumulated sum for all 10 rows because they share the same logical value (the date), which is often preferred 
for financial reporting to avoid showing arbitrary mid-day totals.*/



SELECT 
    t.calendar_week_number,
    s.amount_sold,
    AVG(s.amount_sold) OVER (
        ORDER BY t.calendar_week_number 
        GROUPS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS three_week_avg
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id -- Joining to get the week column
WHERE t.calendar_year = 1999
LIMIT 100;
/*Reason for choosing GROUPS: This mode (introduced in more recent SQL standards like PostgreSQL 11+) counts 
sets of rows that share the same value. In this case, each "group" is a week. Even if a week has 500 sales rows, 
GROUPS 2 PRECEDING will skip back past the 2 previous distinct weeks (the peer groups) rather than trying to 
count individual rows or logical ranges. It is perfect for "n-period" analysis where each period contains many 
rows.*/







