-- Task 1
WITH CustomerSales AS (
    SELECT 
        ch.channel_desc,
        c.cust_id,
        c.cust_first_name || ' ' || c.cust_last_name AS customer_name,
        SUM(s.amount_sold) AS total_sales
    FROM sh.sales s
    JOIN sh.customers c ON s.cust_id = c.cust_id
    JOIN sh.channels ch ON s.channel_id = ch.channel_id
    GROUP BY ch.channel_desc, c.cust_id, c.cust_first_name, c.cust_last_name
),
ChannelTotals AS (
    SELECT 
        channel_desc, 
        SUM(total_sales) as channel_grand_total
    FROM CustomerSales
    GROUP BY channel_desc
),
RankedSales AS (
    SELECT 
        cs1.channel_desc,
        cs1.customer_name,
        ROUND(cs1.total_sales, 2) AS total_sales,
        ROUND((cs1.total_sales / ct.channel_grand_total) * 100, 4) AS sales_percentage,
        (SELECT COUNT(DISTINCT cs2.total_sales) + 1 
         FROM CustomerSales cs2 
         WHERE cs2.channel_desc = cs1.channel_desc 
           AND cs2.total_sales > cs1.total_sales) AS rank
    FROM CustomerSales cs1
    JOIN ChannelTotals ct ON cs1.channel_desc = ct.channel_desc
)
SELECT 
    channel_desc,
    customer_name,
    total_sales,
    sales_percentage || '%' AS sales_percentage
FROM RankedSales
WHERE rank <= 5
ORDER BY channel_desc, total_sales DESC;


--Task 2

CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT 
    product_name,
    COALESCE(q1, 0) AS q1,
    COALESCE(q2, 0) AS q2,
    COALESCE(q3, 0) AS q3,
    COALESCE(q4, 0) AS q4,
    ROUND((COALESCE(q1,0) + COALESCE(q2,0) + COALESCE(q3,0) + COALESCE(q4,0)), 2) AS year_sum
FROM crosstab(
    -- Source query: must return Row ID, Category (Column Header), and Value
    $$
    SELECT 
        p.prod_name,
        t.calendar_quarter_number,
        SUM(s.amount_sold)
    FROM sh.sales s
    JOIN sh.products p ON s.prod_id = p.prod_id
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.customers cust ON s.cust_id = cust.cust_id
    JOIN sh.countries count ON cust.country_id = count.country_id
    WHERE p.prod_category = 'Photo'
      AND count.country_region = 'Asia'
      AND t.calendar_year = 2000
    GROUP BY p.prod_name, t.calendar_quarter_number
    ORDER BY 1, 2
    $$,
    -- Category query: specifies the possible values for the columns
    $$ SELECT generate_series(1,4) $$
) AS ct(
    product_name TEXT,
    q1 NUMERIC,
    q2 NUMERIC,
    q3 NUMERIC,
    q4 NUMERIC
)
ORDER BY year_sum DESC;

-- Task 3

WITH Top300Customers AS (
    SELECT 
        s.cust_id
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year IN (1998, 1999, 2001)
    GROUP BY s.cust_id
    ORDER BY SUM(s.amount_sold) DESC
    LIMIT 300
)
SELECT 
    ch.channel_desc,
    c.cust_id,
    c.cust_last_name,
    c.cust_first_name,
    ROUND(SUM(s.amount_sold), 2) AS amount_sold
FROM sh.sales s
JOIN sh.customers c ON s.cust_id = c.cust_id
JOIN sh.channels ch ON s.channel_id = ch.channel_id
JOIN sh.times t ON s.time_id = t.time_id
JOIN Top300Customers top ON c.cust_id = top.cust_id
WHERE t.calendar_year IN (1998, 1999, 2001)
GROUP BY ch.channel_desc, c.cust_id, c.cust_last_name, c.cust_first_name
ORDER BY ch.channel_desc, amount_sold DESC;


-- Task 4
SELECT 
    t.calendar_month_desc,
    p.prod_category,
    TO_CHAR(SUM(CASE WHEN c_reg.country_region = 'Americas' THEN s.amount_sold ELSE 0 END), '999,999,999') AS "Americas SALES",
    TO_CHAR(SUM(CASE WHEN c_reg.country_region = 'Europe' THEN s.amount_sold ELSE 0 END), '999,999,999') AS "Europe SALES"
FROM sh.sales s
JOIN sh.products p ON s.prod_id = p.prod_id
JOIN sh.times t ON s.time_id = t.time_id
JOIN sh.customers c ON s.cust_id = c.cust_id
JOIN sh.countries c_reg ON c.country_id = c_reg.country_id
WHERE t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')
  AND c_reg.country_region IN ('Americas', 'Europe')
GROUP BY t.calendar_month_desc, p.prod_category
ORDER BY t.calendar_month_desc ASC, p.prod_category ASC;

/*commen section for methods selection:
Task 1
For this report, I chose a strategy utilizing Common Table Expressions (CTEs) combined with a correlated subquery for ranking to strictly avoid window frames. While 
ranking is typically handled by window functions, standard functions like DENSE_RANK() automatically apply a default window frame when an ORDER BY clause is present. 
By using a correlated subquery to manually count distinct higher sales values, and a separate CTE to calculate channel-wide totals for the KPI denominator, the solution 
remains 100% frame-free while still delivering the required Top 5 ranking and percentage-of-channel analysis.

Task 2
To solve the quarterly sales pivot, I implemented the crosstab() function from the tablefunc extension. This approach was chosen because it is the most efficient and 
readable method in PostgreSQL for transforming row-based temporal data (quarters) into a columnar format. I utilized COALESCE within the main SELECT statement to ensure 
that any quarters with zero sales are treated as numeric zeros rather than NULLs, allowing for an accurate calculation of the year_sum and a clean, professional report 
layout that matches the required sample.

Task 3
The logic for this task relies on a CTE with a standard ORDER BY and LIMIT 300 clause to identify the top-performing customers across the years 1998, 1999, and 2001. 
I chose this specific method to bypass the use of RANK() or ROW_NUMBER() window functions, which carry inherent window frames. By first isolating the relevant customer
 IDs in a subquery and then joining that result set back to the main sales and channel tables, I ensured that the multi-year performance ranking is accurate and the 
 final breakdown by sales channel remains compliant with a frame-free requirement.

Task 4
For the regional sales comparison, I chose a conditional aggregation strategy using SUM(CASE WHEN...) statements. This technique is ideal for this specific report 
because it allows for the simultaneous calculation of "Americas SALES" and "Europe SALES" columns within a standard GROUP BY structure, removing the need for complex 
pivot functions or windowing. I also applied TO_CHAR with a specific digit template to format the numeric output with commas, ensuring the final result is easy to read
 and aligns perfectly with the formatting seen in the provided sample report.


*/