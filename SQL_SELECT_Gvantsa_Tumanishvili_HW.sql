/*setting schema*/
SET search_path = public;
/*Part1, 1st Question,*/

/* I would choose the JOIN Solution for this one in production because of its perofrmance. Also it is optimized and doesn't have unnecessary intermediate steps*/
/* All three approaches work
 */

/*Part1, 1st Question, JOIN Solution*/

/* 
Task conditions:
- Return films in category 'Animation'
- Release year between 2017 and 2019
- Rental rate > 1
- Output: title, release_year, rental_rate
*/
/*
JOIN TYPES USED:
1. INNER JOIN (film - film_category)
   - Keeps only films that have a matching record in film_category
   - If a film is not assigned to any category - it is excluded

2. INNER JOIN (film_category - category)
   - Keeps only categories that match film_category records
   - Ensures we only include films that belong to a valid category

EFFECT ON RESULT SET:
- Only films that:
  - exist in film table
  - are linked to a category
  - AND belong specifically to the 'Animation' category
- Any film without a category or without the 'Animation' category is excluded
*/
SELECT 
    f.title, 
    f.release_year, 
    f.rental_rate
FROM public.film AS f
INNER JOIN public.film_category AS fc ON f.film_id = fc.film_id
INNER JOIN public.category AS c ON fc.category_id = c.category_id
WHERE c.name = 'Animation'
    AND f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
ORDER BY f.title ASC;
/*Advantages: Best performance in most cases, optimized, clear relational logic, No unnecessary intermediate steps 
Disadvantages: Can become hard to read in very complex queries, less modular than CTE, hard to debug*/

/* Part1, 1st Question, Subquery Solution
*/

/*
JOIN TYPES USED INSIDE SUBQUERY:
1. INNER JOIN (film_category - category)
   - Keeps only matching category records
   - Ensures only valid category mappings are included

NOTE:
- The main query does NOT use JOIN directly
- Instead, it filters using an IN condition
*/

/*
EFFECT ON RESULT SET:
- First, a list of film_ids belonging to 'Animation' is created
- Then, the outer query returns films whose film_id is in that list
- This acts like an INNER JOIN logically (but executed differently)
*/


SELECT 
    f.title, 
    f.release_year, 
    f.rental_rate
FROM public.film AS f
WHERE f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
    AND f.film_id IN (
        SELECT fc.film_id 
        FROM public.film_category AS fc
        INNER JOIN public.category AS c ON fc.category_id = c.category_id
        WHERE c.name = 'Animation'
    )
ORDER BY f.title ASC;

/*Advantages: Compact and intuitive, easy to write for filtering logic
Disadvantages: Can be less efficient, less flexible for reuse, harder to read when nested deeply */

/* Part1, 1st Question CTE Solution.*/

/*
JOIN TYPES USED:
1. INNER JOIN (film_category - category)
   - Keeps only matching records between film categories and categories

2. INNER JOIN (film - animation_list CTE)
   - Keeps only films whose film_id exists in the CTE result

EFFECT ON RESULT SET:
- The CTE creates a filtered list of Animation film IDs
- The main query joins films with this list
- Only films that match the Animation category are returned
*/
WITH animation_list AS (
    SELECT fc.film_id
    FROM public.film_category AS fc
    INNER JOIN public.category AS c ON fc.category_id = c.category_id
    WHERE c.name = 'Animation'
)
SELECT 
    f.title, 
    f.release_year, 
    f.rental_rate
FROM public.film AS f
INNER JOIN animation_list AS al ON f.film_id = al.film_id
WHERE f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
ORDER BY f.title ASC;
/* Advantages: Very Readable, Easy to debug, Good for Complex queries
Disadvantages: Can use more momery, slight overhead, not optimized well*/

/*Part 1, 2nd Question, all three approaches are possible but i would choose JOIN because of its advanatages i listed below*/
/* 
Task conditions:
- Calculate total revenue per store
- Include payments from 2017-04-01 onwards
- Output: store location + revenue
*/
/* Part1 2nd Question, JOIN Solution */
/*
JOIN TYPES USED AND THEIR EFFECT:

1. INNER JOIN (store - address)
   - Ensures each store is matched with its address
   - Stores without an address are excluded

2. INNER JOIN (store - inventory)
   - Keeps only stores that have inventory items
   - Stores with no inventory are excluded

3. INNER JOIN (inventory - rental)
   - Keeps only inventory items that have been rented
   - Unsold/unrented inventory is excluded

4. INNER JOIN (rental - payment)
   - Keeps only rentals that have corresponding payments
   - Unpaid rentals are excluded

EFFECT ON RESULT SET:
- The query includes ONLY transactions where:
  store - inventory - rental - payment ALL exist
- Any missing link in this chain removes the record entirely
- This ensures that revenue is calculated only from valid, completed payments
*/

SELECT 
    a.address || ' ' || COALESCE(a.address2, '') AS store_location,
    SUM(p.amount) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a ON s.address_id = a.address_id
INNER JOIN public.inventory AS i ON s.store_id = i.store_id
INNER JOIN public.rental AS r ON i.inventory_id = r.inventory_id
INNER JOIN public.payment AS p ON r.rental_id = p.rental_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY s.store_id, a.address, a.address2 
ORDER BY revenue DESC;
/*Advantages: BEst performance in most databases, no intermediate result sets, fully optimized and efficient for large datasets and aggregations
Disadvantages: Lower readability, harder to separate logic into steps*/


/* Part1 2nd Question, Subquery Solution */
/*
JOIN TYPES AND SELECTION:

1. INNER JOIN (store - address)
   - s.address_id = a.address_id
   - Selected because each store must have a valid location
   - Ensures only stores with addresses are included

2. INNER JOIN (inventory - rental)
   - i.inventory_id = r.inventory_id
   - Selected to include only rented inventory
   - Excludes inventory that was never rented

3. INNER JOIN (rental - payment)
   - r.rental_id = p.rental_id
   - Selected to include only completed transactions (with payments)
   - Ensures revenue is based on actual payments

4. INNER JOIN (store - revenue_metrics subquery)
   - s.store_id = revenue_metrics.store_id
   - Connects each store with its calculated revenue
   - Ensures only stores with revenue are included in the final result

REASON FOR USING INNER JOIN:
- Only records with matching data in all tables are relevant
- Excludes:
  * stores without revenue
  * rentals without payments
  * inventory without rentals
- Ensures accurate revenue calculation

RESULT SET EFFECT:
- Revenue is first calculated in the subquery (store_id → total_revenue)
- Then joined with store and address information
- Stores without valid revenue are excluded from the final output
*/


SELECT 
    a.address || ' ' || COALESCE(a.address2, '') AS store_location,
    revenue_metrics.total_revenue AS revenue
FROM public.store AS s
INNER JOIN public.address AS a ON s.address_id = a.address_id
INNER JOIN (
    SELECT 
        i.store_id, 
        SUM(p.amount) AS total_revenue
    FROM public.inventory AS i
    INNER JOIN public.rental AS r ON i.inventory_id = r.inventory_id
    INNER JOIN public.payment AS p ON r.rental_id = p.rental_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY i.store_id
) AS revenue_metrics ON s.store_id = revenue_metrics.store_id
ORDER BY revenue DESC;
/*advantages: compact and self-contained, works well for aggregation-first logic and is easier to embed inside larger queries
disadvantages: can reduce readability when nested, harder to debug then CTE and may have performance issues with large datasets*/ 

/* Part1 2nd Question, CTE Solution */
/*
JOIN TYPES AND SELECTION:

1. INNER JOIN (inventory - rental)
   - i.inventory_id = r.inventory_id
   - Selected to include only rented inventory
   - Excludes inventory that was never rented

2. INNER JOIN (rental - payment)
   - r.rental_id = p.rental_id
   - Selected to include only rentals with payments
   - Ensures revenue is based on completed transactions

3. INNER JOIN (store - address)
   - s.address_id = a.address_id
   - Connects each store with its location
   - Ensures only stores with valid addresses are included

4. INNER JOIN (store - CTE)
   - s.store_id = src.store_id
   - Links each store to its precomputed revenue
   - Ensures only stores with revenue are included

CONDITIONS AND THEIR EFFECT:

- WHERE p.payment_date >= '2017-04-01'
  - Filters data before aggregation
  - Ensures only relevant payments are included in revenue calculation

RESULT SET EFFECT:

- The CTE first computes total revenue per store
- Only stores with valid payments are included in this step
- The main query then joins this aggregated result with store and address data
- Stores without revenue are excluded from the final output
*/

WITH store_revenue_cte AS (
    SELECT 
        i.store_id, 
        SUM(p.amount) AS total_revenue
    FROM public.inventory AS i
    INNER JOIN public.rental AS r ON i.inventory_id = r.inventory_id
    INNER JOIN public.payment AS p ON r.rental_id = p.rental_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY i.store_id
)
SELECT 
    a.address || ' ' || COALESCE(a.address2, '') AS store_location,
    src.total_revenue AS revenue
FROM public.store AS s
INNER JOIN public.address AS a ON s.address_id = a.address_id
INNER JOIN store_revenue_cte AS src ON s.store_id = src.store_id
ORDER BY revenue DESC;
/*Advantages:Very clear logical structure, easier to debug and extend, good for multi-step transformations, improves readability in complex reports
Disadvantages: MAy use extra memory, slower than other approaches and not always optimized efficiently*/

/* Part1, 3th Question*/

/* This task can be done in all three approaches, I would choose JOIN solution because it ensures balance between performance and simplicity. Its has fiwers lines 
of codes while offering the most direct path for the database engine*/
/*
Task Conditions:
- Identify actors/actresses who participated in movies
- Consider only movies released since 2015 (inclusive)
- Count the number of movies each actor/actress took part in
- Return:
  - first_name
  - last_name
  - number_of_movies
- Show only the top 5 actors/actresses with the highest number of movies
- Sort the result by number_of_movies in descending order
*/

/* Part1 3rd Question, Join Solution */

/*
JOIN TYPES AND SELECTION:

1. INNER JOIN (actor - film_actor)
   - a.actor_id = fa.actor_id
   - Selected to connect actors with the films they participated in
   - Ensures only actors with at least one film are included

2. INNER JOIN (film_actor - film)
   - fa.film_id = f.film_id
   - Selected to access film details such as release_year
   - Ensures only valid film records are included

REASON FOR USING INNER JOIN:
- Only actors who have participated in films are relevant
- Only films that exist in the dataset and match records are included
- This excludes:
  * actors with no films
  * invalid or unmatched film records*/

SELECT 
    a.first_name, 
    a.last_name, 
    COUNT(fa.film_id) AS number_of_movies
FROM public.actor AS a
INNER JOIN public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN public.film AS f ON fa.film_id = f.film_id
WHERE f.release_year >= 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC
LIMIT 5;
/* Advantaes: Best performance, optimized, no intermediate results
Disadvantages: Lower readability and harder to maintain when logic grows */

/* Part1 3rd Question, Subquery Solution */

/*1. INNER JOIN (film_actor - film)
   - fa.film_id = f.film_id
   - Used to access film information (release_year)
   - Ensures only valid film records are included

REASON FOR USING INNER JOIN:
- Only films that exist and match in both tables are considered
- Excludes:
  * invalid film records
  * records without matching film information

CONDITIONS AND THEIR EFFECT:

- WHERE f.release_year >= 2015
  - Filters films before aggregation
  - Ensures only films released since 2015 are counted

RESULT SET EFFECT (INNER QUERY):

- The subquery first creates an aggregated dataset:
  actor_id - number_of_movies
- Only actors with films in the specified period are included
- This dataset is then used in the outer query

OUTER QUERY JOIN:

- INNER JOIN (actor - subquery result)
  - a.actor_id = top_counts.actor_id
  - Used to attach actor names to the aggregated results
  - Ensures only actors with counted movies are included in the final result

FINAL RESULT EFFECT:

- Aggregation happens first in the subquery
- Then actor details are added in the outer query
- Only actors with movies since 2015 are shown
- Top 5 actors are returned based on number_of_movies
*/

SELECT 
    a.first_name, 
    a.last_name, 
    top_counts.number_of_movies
FROM public.actor AS a
INNER JOIN (
    SELECT 
        fa.actor_id, 
        COUNT(fa.film_id) AS number_of_movies
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY fa.actor_id
) AS top_counts ON a.actor_id = top_counts.actor_id
ORDER BY top_counts.number_of_movies DESC
LIMIT 5;
/*advantages: Clean way to compute counts first, then join actor info, Keeps aggregation isolated 
Disadvantages: Adds extra nesting without real benefit, Slightly worse readability than CTE Potentially less efficient than direct JOIN (depending on optimizer)*/


/* Part1 3rd Question, CTE Solution */
/*
JOIN TYPES AND SELECTION (INSIDE CTE):

1. INNER JOIN (film_actor - film)
   - fa.film_id = f.film_id
   - Used to access film details (release_year)
   - Ensures only valid film records are included

REASON FOR USING INNER JOIN:
- Only matching records between tables are relevant
- Excludes:
  * invalid film references
  * films without matching records


RESULT SET EFFECT (CTE):

- The CTE first computes:
  actor_id - number_of_movies
- Only actors with qualifying films are included in this step
- The main query then joins this aggregated result with actor data

OUTER JOIN:

- INNER JOIN (actor - CTE)
  - a.actor_id = afc.actor_id
  - Attaches actor names to aggregated results
  - Ensures only actors with movie counts are included

FINAL RESULT EFFECT:

- Aggregation happens inside the CTE
- Then actor details are joined in the outer query
- Only actors with movies since 2015 are returned
- Results are sorted and limited to top 5
*/

WITH actor_film_counts AS (
    SELECT 
        fa.actor_id, 
        COUNT(fa.film_id) AS movie_count
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY fa.actor_id
)
SELECT 
    a.first_name, 
    a.last_name, 
    afc.movie_count AS number_of_movies
FROM public.actor AS a
INNER JOIN actor_film_counts AS afc ON a.actor_id = afc.actor_id
ORDER BY number_of_movies DESC
LIMIT 5;
/* Advantages: Improves readability by separating aggregation (count movies) from final selection Makes it easier to verify correctness of movie count per actor
Useful if marketing later wants more metrics (e.g., revenue, ratings)
Disadvantages: For this task, logic is simple, so CTE is unnecessary overhead, May slightly increase execution cost (extra step), No real benefit since we only have 
one aggregation layer*/

/* Part1, 4th Question: 
All the approaches are possible and work, but Join is the best solution and i would use one in production, because it performs aggregation in 
a single pass and avoids redundant computations.*/
/*
Task Conditions:
- Analyze films by genre over time
- Consider only the following genres:
  - Drama
  - Travel
  - Documentary
- Count the number of films per genre for each release year
- Include columns:
  - release_year
  - number_of_drama_movies
  - number_of_travel_movies
  - number_of_documentary_movies
- Sort results by release_year in descending order
- Handle NULL values where necessary (e.g., missing counts should be treated as 0)
*/

/* Part1 4th Question, JOIN Solution */
/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. INNER JOIN film_category (fc)
   - Why: Connects each film to its category
   - Result set effect: 
     - Expands rows so each film appears once per category it belongs to
     - Enables mapping films to genres

2. INNER JOIN category (c)
   - Why: Retrieves the category name (Drama, Travel, Documentary)
   - Result set effect:
     - Adds genre labels to each row
     - Allows filtering and aggregation by genre

3. WHERE c.name IN ('Drama', 'Travel', 'Documentary')
   - Why: Keeps only the required genres
   - Result set effect:
     - Filters out all other categories before aggregation
     - Reduces dataset size and improves performance

4. INNER JOIN TYPE
   - Why: Only include matching records between tables
   - Result set effect:
     - Excludes films without matching categories
     - Ensures clean and relevant grouped results
*/

SELECT 
    f.release_year,
    COUNT(*) FILTER (WHERE UPPER(c.name) = 'DRAMA') AS number_of_drama_movies,
    COUNT(*) FILTER (WHERE UPPER(c.name) = 'TRAVEL') AS number_of_travel_movies,
    COUNT(*) FILTER (WHERE UPPER(c.name) = 'DOCUMENTARY') AS number_of_documentary_movies
FROM public.film AS f
INNER JOIN public.film_category AS fc ON f.film_id = fc.film_id
INNER JOIN public.category AS c ON fc.category_id = c.category_id
WHERE UPPER(c.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY')
GROUP BY f.release_year
ORDER BY f.release_year DESC;
/*Advantages:Extremely clean and readable due to FILTER, Performs all aggregations in one scan, Very efficient (no repeated scans), Best suited for pivot-style reporting
Disadvantages: Uses FILTER, Slightly less flexible if categories become dynamic */

/* Part1 4th Question Subquery Solution */
/*1. INNER JOIN film_category (fc2 / fc3 / fc4)
   - Why: To link films with their categories for each subquery
   - Result set effect:
     - Creates a filtered set of film-category relationships for each genre separately
     - Each subquery processes its own dataset independently

2. INNER JOIN category (c2 / c3 / c4)
   - Why: To identify the genre name (Drama, Travel, Documentary)
   - Result set effect:
     - Allows filtering inside each subquery for a specific genre
     - Ensures only relevant category records are counted

3. INNER JOIN film (f2 / f3 / f4)
   - Why: To access release_year for filtering
   - Result set effect:
     - Enables matching films to the outer query's release_year
     - Links subquery results with the main query

4. CORRELATED CONDITION (f2.release_year = f.release_year)
   - Why: To calculate counts per year from the outer query
   - Result set effect:
     - Subqueries run once per outer row
     - Produces year-wise aggregation dynamically

5. DISTINCT f.release_year (in outer query)
   - Why: To avoid duplicate years in the result
   - Result set effect:
     - Ensures one row per release year
     - Prevents repetition caused by joins/subqueries
*/

SELECT 
    DISTINCT f.release_year,
    (SELECT COUNT(*) 
     FROM public.film_category fc2 
     INNER JOIN public.category c2 ON fc2.category_id = c2.category_id 
     INNER JOIN public.film f2 ON fc2.film_id = f2.film_id
     WHERE UPPER(c2.name) = 'DRAMA' AND f2.release_year = f.release_year) AS number_of_drama_movies,
    (SELECT COUNT(*) 
     FROM public.film_category fc3 
     INNER JOIN public.category c3 ON fc3.category_id = c3.category_id 
     INNER JOIN public.film f3 ON fc3.film_id = f3.film_id
     WHERE UPPER(c3.name) = 'TRAVEL' AND f3.release_year = f.release_year) AS number_of_travel_movies,
    (SELECT COUNT(*) 
     FROM public.film_category fc4 
     INNER JOIN public.category c4 ON fc4.category_id = c4.category_id 
     INNER JOIN public.film f4 ON fc4.film_id = f4.film_id
     WHERE UPPER(c4.name) = 'DOCUMENTARY' AND f4.release_year = f.release_year) AS number_of_documentary_movies
FROM public.film AS f
ORDER BY f.release_year DESC;
/* Advantages: Conceptually easy to understand, Clearly separates each genre calculation
Disadvantages: poor performance, not scalable for large datasets and harder to maintain*/

/* Part1 4th Question CTE Solution */
/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. INNER JOIN film_category (fc)
   - Why: Links each film to its category
   - Result set effect:
     - Expands rows so each film appears once per category it belongs to
     - Enables mapping films to genres before aggregation

2. INNER JOIN category (c)
   - Why: Retrieves the category name (Drama, Travel, Documentary)
   - Result set effect:
     - Adds genre labels to each row
     - Allows filtering in the CTE for only required genres

3. WHERE c.name IN ('Drama', 'Travel', 'Documentary')
   - Why: Restricts data to the required genres
   - Result set effect:
     - Reduces dataset size
     - Ensures only relevant genres are processed in the CTE

4. CTE (genre_counts)
   - Why: Separates data preparation (joining + filtering) from aggregation
   - Result set effect:
     - Produces an intermediate table with (release_year, genre_name)
     - Simplifies the final aggregation step

5. CASE WHEN in aggregation
   - Why: Converts genre values into counts
   - Result set effect:
     - Each row contributes 1 to the corresponding genre count
     - Aggregates data into a pivot-style output per year
*/

WITH genre_counts AS (
    SELECT 
        f.release_year,
        UPPER(c.name) AS genre_name
    FROM public.film AS f
    INNER JOIN public.film_category AS fc ON f.film_id = fc.film_id
    INNER JOIN public.category AS c ON fc.category_id = c.category_id
    WHERE UPPER(c.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY')
)
SELECT 
    release_year,
    SUM(CASE WHEN genre_name = 'DRAMA' THEN 1 ELSE 0 END) AS number_of_drama_movies,
    SUM(CASE WHEN genre_name = 'TRAVEL' THEN 1 ELSE 0 END) AS number_of_travel_movies,
    SUM(CASE WHEN genre_name = 'DOCUMENTARY' THEN 1 ELSE 0 END) AS number_of_documentary_movies
FROM genre_counts
GROUP BY release_year
ORDER BY release_year DESC;
/*Advantages: Clear step-by-step logic, Easy to debug, Uses standard SQL 
Disadvantages: Slight extra processing step, Not needed for such a simple aggregation, May use more memory*/

/*Part2, 1st Question
All three approaches are possible. JOIN solution is best one, because it performs aggregation directly on the payment table and avoids intermediate steps.*/

/* Part2, 1st Question, Join Solution */
/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. INNER JOIN payment (p)
   - Why: Main source of revenue data (amount)
   - Result set effect:
     - Creates one row per payment transaction
     - Enables aggregation (SUM) of revenue per staff

2. INNER JOIN staff (s)
   - Why: To identify which employee processed each payment
   - Result set effect:
     - Attaches employee details (first_name, last_name) to each payment
     - Allows grouping revenue by staff member

3. INNER JOIN store (st)
   - Why: To identify the store associated with each staff member
   - Result set effect:
     - Links each staff member to their store
     - Ensures we can report revenue per employee per store

4. INNER JOIN address (a)
   - Why: To display the store location
   - Result set effect:
     - Adds human-readable store address to the result
     - Enhances reporting clarity

5. WHERE payment_date BETWEEN '2017-01-01' AND '2017-12-31'
   - Why: Restrict analysis to the year 2017
   - Result set effect:
     - Filters dataset to only relevant time period
     - Reduces data size and improves performance

6. GROUP BY staff_id (and related fields)
   - Why: Aggregate revenue per employee
   - Result set effect:
     - Collapses multiple payment rows into one row per staff member
     - Enables calculation of total revenue per employee
*/

WITH StaffLastStore AS (
    -- Step 1: Identify the last store each staff member worked at in 2017
    SELECT DISTINCT ON (p.staff_id)
        p.staff_id,
        st.store_id,
        a.address,
        a.address2
    FROM public.payment AS p
    INNER JOIN public.rental AS r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
    INNER JOIN public.store AS st ON i.store_id = st.store_id
    INNER JOIN public.address AS a ON st.address_id = a.address_id
    WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
    ORDER BY p.staff_id, p.payment_date DESC
)
SELECT 
    s.first_name, 
    s.last_name, 
    sls.address || ' ' || COALESCE(sls.address2, '') AS last_store_location,
    SUM(p.amount) AS total_revenue
FROM public.staff AS s
INNER JOIN public.payment AS p ON s.staff_id = p.staff_id
INNER JOIN StaffLastStore AS sls ON s.staff_id = sls.staff_id
WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
GROUP BY s.staff_id, s.first_name, s.last_name, sls.address, sls.address2
ORDER BY total_revenue DESC
LIMIT 3;
/*Advantages, Single-pass aggregation therefore efficient, Direct use of payment table thus correct business logic, No intermediate steps, Best for large financial datasets
Disadvantages: Harder to isolate logic (aggregation + joins together), Slightly less readable, Handling 'last store'  precisely would make it more complex*/

/* Part2, 1st Question, Subquery Solution. */

/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. Subquery (revenue_totals)
   - Why: To first calculate total revenue per staff member
   - Result set effect:
     - Produces a reduced dataset with one row per staff_id
     - Aggregates all payments before joining with staff data

2. INNER JOIN staff (s) WITH subquery
   - Why: To attach employee details to the precomputed revenue
   - Result set effect:
     - Expands each aggregated row with staff information
     - Ensures only staff with recorded payments are included

3. INNER JOIN store (st)
   - Why: To identify the store associated with each staff member
   - Result set effect:
     - Adds store-level information to the result
     - Maintains relationship between staff and their store

4. INNER JOIN address (a)
   - Why: To display the stores physical location
   - Result set effect:
      Adds readable location data to the output
      Improves reporting clarity

5. WHERE condition inside subquery (payment_date filter)
   - Why: Limit revenue calculation to the year 2017
   - Result set effect:
     - Reduces the number of rows before aggregation
     - Improves performance and ensures correct time-based analysis

6. ORDER BY + LIMIT
   - Why: To retrieve top 3 highest revenue-generating staff
   - Result set effect:
     - Sorts aggregated results in descending order
     - Restricts output to only the top performers
*/
WITH StaffStoreHistory AS (
    -- Trace payment to store and rank by date to find the "latest"
    SELECT 
        p.staff_id,
        st.address_id,
        ROW_NUMBER() OVER (PARTITION BY p.staff_id ORDER BY p.payment_date DESC) as latest_rank
    FROM public.payment AS p
    INNER JOIN public.rental AS r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
    INNER JOIN public.store AS st ON i.store_id = st.store_id
    WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
),
LatestStore AS (
    -- Filter for only the most recent store record per staff
    SELECT staff_id, address_id
    FROM StaffStoreHistory
    WHERE latest_rank = 1
)
SELECT 
    s.first_name, 
    s.last_name, 
    a.address || ' ' || COALESCE(a.address2, '') AS last_store_location,
    revenue_totals.annual_revenue AS revenue
FROM public.staff AS s
INNER JOIN (
    -- Revenue calculation with corrected date boundaries
    SELECT p.staff_id, SUM(p.amount) AS annual_revenue
    FROM public.payment AS p
    WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
    GROUP BY p.staff_id
) AS revenue_totals ON s.staff_id = revenue_totals.staff_id
INNER JOIN LatestStore AS ls ON s.staff_id = ls.staff_id
INNER JOIN public.address AS a ON ls.address_id = a.address_id
ORDER BY revenue DESC
LIMIT 3;
/*Advantages: Separates revenue calculation from staff info, Cleaner than JOIN logically, Easy to reuse revenue subquery
Disadvantgaes: Still relies on staff.store_id thus same logical flaw originally, Additional join step so slightly more overhead, Not as efficient as JOIN*/


/* Part2, 1st Question, CTE Solution */

/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. CTE (staff_performance)
   - Why: To first calculate total revenue per staff member
   - Result set effect:
     - Creates a temporary dataset with one row per staff_id
     - Aggregates payment data before joining with other tables

2. INNER JOIN staff (s) WITH CTE
   - Why: To attach employee details to their computed revenue
   - Result set effect:
     - Combines aggregated revenue with staff personal information
     - Keeps only staff who have payment records

3. INNER JOIN store (st)
   - Why: To identify which store each staff member belongs to
   - Result set effect:
     - Adds store-level context to each staff member
     - Maintains staff-to-store relationship

4. INNER JOIN address (a)
   - Why: To display readable store location
   - Result set effect:
     - Adds full address information to the result
     - Improves interpretability of the output

5. WHERE condition inside CTE (payment_date filter)
   - Why: Restrict analysis to 2017 revenue only
   - Result set effect:
     - Filters data before aggregation
     - Reduces dataset size and improves accuracy

6. ORDER BY + LIMIT
   - Why: To identify top 3 highest revenue-generating staff
   - Result set effect:
     - Sorts results in descending order of revenue
     - Returns only the top 3 rows
*/

SELECT 
    s.first_name, 
    s.last_name, 
    a.address || ' ' || COALESCE(a.address2, '') AS last_store_address,
    sr.total_earned AS revenue
FROM public.staff AS s
INNER JOIN (
    SELECT p.staff_id, SUM(p.amount) AS total_earned
    FROM public.payment AS p
    WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
    GROUP BY p.staff_id
) AS sr ON s.staff_id = sr.staff_id
INNER JOIN (
    SELECT p1.staff_id, MAX(st.address_id) AS address_id
    FROM public.payment AS p1
    INNER JOIN public.rental AS r ON p1.rental_id = r.rental_id
    INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
    INNER JOIN public.store AS st ON i.store_id = st.store_id
    WHERE p1.payment_date = (
        SELECT MAX(p2.payment_date)
        FROM public.payment AS p2
        WHERE p2.staff_id = p1.staff_id
          AND p2.payment_date >= '2017-01-01' 
          AND p2.payment_date < '2018-01-01'
    )
    GROUP BY p1.staff_id -- This line prevents the "Hanna Carry" duplicates
) AS lpl ON s.staff_id = lpl.staff_id
INNER JOIN public.address AS a ON lpl.address_id = a.address_id
ORDER BY revenue DESC
LIMIT 3;

/*Advantages: Best readability, Clearly separates:, revenue calculation, final output, Easy to extend (e.g., bonuses, rankings)
advantages: Extra step thus possible memory overhead, Not necessary for simple aggregation, Same issue if store logic not corrected*/

/*Part2, 2nd Question, 
all three approaches are possible but I would choose JOIN for production because it calculates rental counts in a single step without intermediate results.*/

/* Part2, 2nd Question, JOIN Solution */

/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. INNER JOIN inventory (i)
   - Why: To link each film to its inventory items (copies available for rent)
   - Result set effect:
     - Expands each film into multiple rows (one per inventory item)
     - Enables tracking how often each film could be rented

2. INNER JOIN rental (r)
   - Why: To capture actual rental transactions
   - Result set effect:
     - Further expands rows so each represents a rental event
     - Allows counting how many times each film was rented

3. INNER JOIN TYPE
   - Why: Only films that have inventory and rental records are relevant
   - Result set effect:
     - Excludes films that were never rented
     - Ensures accurate popularity measurement based on real rentals

4. GROUP BY (film_id, title, rating)
   - Why: To aggregate rental counts per film
   - Result set effect:
     - Collapses multiple rental rows into one row per film
     - Produces total number_of_rentals for each film

5. CASE (rating - expected_audience_age)
   - Why: To map MPA ratings to audience age groups
   - Result set effect:
     - Adds derived, business-friendly information for marketing analysis

6. ORDER BY + LIMIT
   - Why: To find top 5 most rented films
   - Result set effect:
     - Sorts films by popularity (descending)
     - Returns only the top-performing movies
*/
SELECT 
    f.title, 
    f.rating AS mpa_rating,
    CASE 
        WHEN f.rating = 'G' THEN 'All Ages'
        WHEN f.rating = 'PG' THEN '8+'
        WHEN f.rating = 'PG-13' THEN '13+'
        WHEN f.rating = 'R' THEN '17+'
        WHEN f.rating = 'NC-17' THEN '18+'
        ELSE 'Not Rated'
    END AS expected_audience_age,
    COUNT(r.rental_id) AS number_of_rentals
FROM public.film AS f
INNER JOIN public.inventory AS i ON f.film_id = i.film_id
INNER JOIN public.rental AS r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY number_of_rentals DESC
LIMIT 5;
/**Advantages: Most natural representation of problem, Single-pass aggregation thus best performance, No intermediate tables, Clean and efficient for top-N queries
Disadvantages: Slightly less modular, Harder to extend if logic becomes complex*/

/* Part2, 2nd Question, Subquery Solution */

/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. Subquery (pop)
   - Why: To calculate rental counts per film first
   - Result set effect:
     - Produces a reduced dataset: film_id - rental_count
     - Aggregates rental data before joining with film details

2. INNER JOIN inventory (i) - inside subquery
   - Why: To link films to their inventory items
   - Result set effect:
     - Expands each film into multiple inventory rows
     - Prepares data for rental counting

3. INNER JOIN rental (r) - inside subquery
   - Why: To capture actual rental transactions
   - Result set effect:
     - Expands rows to represent individual rental events
     - Enables counting rentals per film

4. INNER JOIN film (f) with subquery
   - Why: To attach film details (title, rating) to aggregated rental counts
   - Result set effect:
     - Combines descriptive film data with computed popularity metrics
     - Ensures only films with rentals are included

5. INNER JOIN TYPE
   - Why: Only films with rental activity are relevant for popularity analysis
   - Result set effect:
     - Excludes films with no rentals
     - Keeps dataset focused on active/popular films

6. ORDER BY + LIMIT
   - Why: To identify top 5 most rented films
   - Result set effect:
     - Sorts films by rental_count (descending)
     - Returns only top-performing movies
*/

SELECT 
    f.title, 
    f.rating,
    CASE 
        WHEN f.rating = 'G' THEN 'General Audience'
        WHEN f.rating = 'PG' THEN 'Parental Guidance'
        WHEN f.rating = 'PG-13' THEN 'Teens 13+'
        WHEN f.rating = 'R' THEN 'Adults 17+'
        WHEN f.rating = 'NC-17' THEN 'Adults Only 18+'
    END AS audience_group,
    pop.rental_count
FROM public.film AS f
INNER JOIN (
    SELECT i.film_id, COUNT(r.rental_id) AS rental_count
    FROM public.inventory AS i
    INNER JOIN public.rental AS r 
        ON i.inventory_id = r.inventory_id
    GROUP BY i.film_id
) AS pop 
    ON f.film_id = pop.film_id
ORDER BY pop.rental_count DESC
LIMIT 5;
/*Advantages: Separates aggregation logic from presentation, Easier to reuse rental counts, Cleaner structure than JOIN for some readers
Disadvantages:Extra computation step, Slightly less efficient than JOIN, More verbose*/

/* Part2, 2nd Question, CET Solution */

/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. CTE (movie_popularity)
   - Why: To calculate total rentals per film before joining with film details
   - Result set effect:
     - Creates a temporary dataset: film_id - total_rentals
     - Reduces data size by aggregating rental events early

2. INNER JOIN inventory (i) - inside CTE
   - Why: To connect films to their inventory items
   - Result set effect:
     - Expands each film into multiple inventory rows
     - Prepares data for rental aggregation

3. INNER JOIN rental (r) - inside CTE
   - Why: To capture actual rental transactions
   - Result set effect:
     - Expands rows to represent individual rentals
     - Enables counting rentals per film

4. INNER JOIN film (f) with CTE
   - Why: To attach film details (title, rating) to aggregated rental data
   - Result set effect:
     - Combines descriptive attributes with computed popularity metrics
     - Keeps only films that have rental activity

5. INNER JOIN TYPE
   - Why: Only films with rental records are relevant for popularity ranking
   - Result set effect:
      Excludes films that were never rented
      Focuses analysis on active/popular films

6. ORDER BY + LIMIT
   - Why: To retrieve top 5 most rented films
   - Result set effect:
      Sorts films by total_rentals (descending)
     - Returns only the highest-performing movies
*/
WITH movie_popularity AS (
    SELECT 
        i.film_id, 
        COUNT(r.rental_id) AS total_rentals
    FROM public.inventory AS i
    INNER JOIN public.rental AS r 
        ON i.inventory_id = r.inventory_id
    GROUP BY i.film_id
)
SELECT 
    f.title, 
    f.rating,
    CASE 
        WHEN f.rating = 'G' THEN 'All Ages'
        WHEN f.rating = 'PG' THEN '8+'
        WHEN f.rating = 'PG-13' THEN '13+'
        WHEN f.rating = 'R' THEN '17+'
        WHEN f.rating = 'NC-17' THEN '18+'
        ELSE 'Not Rated'
    END AS target_age,
    mp.total_rentals
FROM public.film AS f
INNER JOIN movie_popularity AS mp 
    ON f.film_id = mp.film_id
ORDER BY mp.total_rentals DESC
LIMIT 5;
/* Advantages: Best readability, Easy to debug (you can inspect movie_popularity), Very useful if adding more metrics later
Disadvantages: Extra step so possible memory overhead, Not necessary for simple aggregation, Slightly slower than JOIN*/


/*Part3, V1, All three approaches are possible, In production, I would use JOIN for simple aggregations like this because it is usually more performant and directly 
optimized by the database engine. However, for more complex analytical queries, I would prefer a CTE due to better readability and maintainability.*/

/* Part3, V1, Join Solution */
/*/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. INNER JOIN film_actor (fa)
   - Why: To connect actors with the films they participated in
   - Result set effect:
     - Expands each actor into multiple rows (one per film)
     - Enables linking actors to their film history

2. INNER JOIN film (f)
   - Why: To access film attributes, specifically release_year
   - Result set effect:
     - Adds release_year to each actor-film combination
     - Provides the data needed to calculate inactivity

3. INNER JOIN TYPE
   - Why: Only actors with at least one film are relevant for this analysis
   - Result set effect:
     - Excludes actors with no film records
     - Ensures all rows have valid release_year values

4. GROUP BY (actor_id, first_name, last_name)
   - Why: To aggregate films per actor
   - Result set effect:
     - Collapses multiple film rows into one row per actor
      Enables calculation of MAX(release_year)

5. MAX(release_year)
   - Why: To find the most recent film per actor
   - Result set effect:
     - Identifies the last active year for each actor
     - Used to compute inactivity period

6. ORDER BY
   - Why: To rank actors by longest inactivity
   - Result set effect:
     - Actors with the largest gap appear first
*/*/
SELECT 
    a.first_name, 
    a.last_name, 
    (EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year)) AS years_since_last_film
FROM public.actor AS a
INNER JOIN public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN public.film AS f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY years_since_last_film DESC;
/*Advantages:
Very efficient
Direct and simple for the database optimizer
Good for performance-critical queries
Easy to understand for experienced SQL users
Disadvantages:
Slightly harder to read when logic becomes complex
Logic is 'spread out' (harder to reuse)*/

/* Part3, V1, Subquery Solution */
/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. Subquery (latest_films)
   - Why: To calculate the latest film year (MAX release_year) per actor first
   - Result set effect:
     - Produces a reduced dataset: actor_id - max_year
     - Aggregates all film records before joining with actor data

2. INNER JOIN film_actor (fa) - inside subquery
   - Why: To connect actors with their films
   - Result set effect:
     - Expands each actor into multiple film rows
     - Enables aggregation of release years

3. INNER JOIN film (f) - inside subquery
   - Why: To access release_year for each film
   - Result set effect:
     - Adds release_year to each actor-film pair
     - Provides data for MAX calculation

4. INNER JOIN actor (a) with subquery
   - Why: To attach actor details to aggregated results
   - Result set effect:
     - Combines actor names with their latest film year
     - Keeps only actors who have film records

5. INNER JOIN TYPE
   - Why: Only actors with at least one film are relevant
   - Result set effect:
     - Excludes actors with no film history
     - Ensures valid inactivity calculation

6. ORDER BY
   - Why: To rank actors by longest inactivity period
   - Result set effect:
     - Sorts actors by years_since_last_film (descending)
*/
SELECT 
    a.first_name, 
    a.last_name, 
    (EXTRACT(YEAR FROM CURRENT_DATE) - latest_films.max_year) AS years_since_last_film
FROM public.actor AS a
INNER JOIN (
    SELECT fa.actor_id, MAX(f.release_year) AS max_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
    GROUP BY fa.actor_id
) AS latest_films ON a.actor_id = latest_films.actor_id
ORDER BY years_since_last_film DESC;
/*Advantages
Clear separation of logic:
inner query - aggregation
outer query - presentation
Good for modular thinking
Easier to debug than JOIN in some cases
Disadvantages:
Can be less efficient if subquery is not optimized well
Can become nested and harder to read with complexity
Sometimes harder for beginners*/

/* Part3, V1, CET Solution */
/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. CTE (actor_max_year)
   - Why: To calculate the latest film year per actor in a separate step
   - Result set effect:
     - Creates an intermediate dataset: actor_id - last_year
     - Aggregates film data before joining with actor table

2. INNER JOIN film_actor (fa) - inside CTE
   - Why: To connect actors with their films
   - Result set effect:
     - Expands each actor into multiple rows (one per film)
     - Enables aggregation of release years

3. INNER JOIN film (f) - inside CTE
   - Why: To access release_year for each film
   - Result set effect:
     - Adds release_year to each actor-film pair
     - Provides data for MAX(release_year)

4. INNER JOIN actor (a) with CTE
   - Why: To attach actor details to aggregated results
   - Result set effect:
     - Combines actor names with their latest film year
     - Keeps only actors who have film records

5. INNER JOIN TYPE
   - Why: Only actors with at least one film are relevant
   - Result set effect:
     - Excludes actors with no film history
     - Ensures valid inactivity calculation

6. ORDER BY
   - Why: To rank actors by longest inactivity period
   - Result set effect:
     - Sorts actors by years_since_last_film (descending)
*/
WITH actor_max_year AS (
    -- Grouping the logic for the most recent film per actor
    SELECT fa.actor_id, MAX(f.release_year) AS last_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
    GROUP BY fa.actor_id
)
SELECT 
    a.first_name, 
    a.last_name, 
    (EXTRACT(YEAR FROM CURRENT_DATE) - amy.last_year) AS years_since_last_film
FROM public.actor AS a
INNER JOIN actor_max_year AS amy ON a.actor_id = amy.actor_id
ORDER BY years_since_last_film DESC;
/*Advantages
Best readability
Easy to break complex logic into steps
Reusable inside the query
Very clean and maintainable
Disadvantages:
In some PostgreSQL versions, CTEs can act as a 'optimization fence'
- meaning performance can be slightly worse in some cases
Slight overhead compared to simple JOINs*/

/*Part3, V2:
All the approaches are possible but i would choose CTE in production because it's most readable and maintainable and has best performance, also avoids self-joins*/
/* Part3, V2, JOIN Solution */
/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. INNER JOIN film_actor (fa1)
   - Why: To link actors with their films (first instance - starting film)
   - Result set effect:
     - Creates rows for each actor-film combination (f1 = starting film)
     - Establishes the base year for gap calculation

2. INNER JOIN film (f1)
   - Why: To access release_year of the starting film
   - Result set effect:
     - Adds film_year (start point of gap)
     - Prepares first part of comparison

3. INNER JOIN film_actor (fa2)
   - Why: To link the same actor to all their films again (second instance - future films)
   - Result set effect:
     - Creates combinations of (current film  all future films)
     - Causes row explosion (many combinations per actor)

4. INNER JOIN film (f2)
   - Why: To access release_year of the potential "next" film
   - Result set effect:
     - Adds candidate next_film_year values
     - Enables comparison between current and future films

5. WHERE f2.release_year > f1.release_year
   - Why: To ensure only future films are considered
   - Result set effect:
     - Filters out same-year or past films
     - Keeps only valid forward-looking pairs

6. GROUP BY (actor_id, film_year)
   - Why: To collapse multiple future film matches into one "next film"
   - Result set effect:
     - Aggregates many rows into one per actor + film_year
     - Enables MIN(f2.release_year) to find the closest next film

7. MIN(f2.release_year)
   - Why: To find the immediate next film year
   - Result set effect:
     - Selects the smallest future year
     - Simulates "next film" logic

8. HAVING (gap > 1)
   - Why: To filter only meaningful inactivity gaps
   - Result set effect:
     - Removes consecutive-year films (gap - 1)
     - Keeps only notable inactivity periods

9. INNER JOIN TYPE (overall)
   - Why: Only actors with at least two films are relevant for gap analysis
   - Result set effect:
     - Excludes actors with only one film (no gap possible)
     - Ensures valid comparisons

10. ORDER BY
   - Why: To rank largest inactivity gaps first
   - Result set effect:
     - Sorts results by gap_size in descending order
*/
SELECT 
    a.first_name, 
    a.last_name, 
    f1.release_year AS film_year,
    MIN(f2.release_year) AS next_film_year,
    (MIN(f2.release_year) - f1.release_year) AS gap_size
FROM public.actor AS a
INNER JOIN public.film_actor AS fa1 ON a.actor_id = fa1.actor_id
INNER JOIN public.film AS f1 ON fa1.film_id = f1.film_id
INNER JOIN public.film_actor AS fa2 ON a.actor_id = fa2.actor_id
INNER JOIN public.film AS f2 ON fa2.film_id = f2.film_id
WHERE f2.release_year > f1.release_year
GROUP BY a.actor_id, a.first_name, a.last_name, f1.release_year
ORDER BY gap_size DESC, a.last_name;
/*Advantages
Explicit logic of relationships: clearly shows how each film is connected to the 'next' one.
SQL basics only: works without advanced features (useful if environment is limited).
Flexible filtering: easy to add conditions like minimum gap, specific years, genres, etc.
Transparent grouping: you can directly see how gaps are calculated per film.
Disadvantages
Complex self-join structure: difficult to understand and debug, especially with multiple joins (film_actor + film twice).
Row explosion risk: each film is matched with many future films - requires aggregation to fix.
Hard to guarantee true sequential order: relies on filtering (f2.release_year > f1.release_year), which may miss nuances.
Performance cost: large join operations + aggregation can be expensive on big actor datasets.
Less intuitive for 'next film' logic: you're manually simulating sequencing.*/


/* Part3, V2, Subquery Solution */

/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. INNER JOIN film_actor (fa1)
   - Why: To link actors with their films (starting film)
   - Result set effect:
     - Creates rows for each actor-film combination
     - Provides base (f1.release_year) for gap calculation

2. INNER JOIN film (f1)
   - Why: To access release_year of the current film
   - Result set effect:
     - Adds starting year for each gap calculation
     - Defines the reference point for "next film"

3. Correlated Subquery (SELECT MIN(f2.release_year) ...)
   - Why: To find the next film year for the SAME actor
   - Result set effect:
     - Executes once per outer row (actor + film)
     - Returns the closest future release_year (next film)
     - If no future film exists - returns NULL

4. INNER JOIN film_actor (fa2) - inside subquery
   - Why: To restrict search to films of the same actor
   - Result set effect:
     - Ensures only relevant films are considered
     - Links actor to their future films

5. INNER JOIN film (f2) - inside subquery
   - Why: To access release_year of candidate future films
   - Result set effect:
     - Provides values for MIN() calculation
     - Enables identification of the next film year

6. WHERE f2.release_year > f1.release_year (inside subquery)
   - Why: To consider only future films
   - Result set effect:
     - Filters out current and past films
     - Ensures valid forward-looking comparison

7. WHERE (subquery result - f1.release_year) > 1
   - Why: To keep only meaningful inactivity gaps
   - Result set effect:
     - Filters out consecutive films (gap less then 1)
     - Removes rows where subquery returns NULL

8. INNER JOIN TYPE (overall)
   - Why: Only actors with film records are relevant
   - Result set effect:
     - Excludes actors with no films
     - Keeps only valid actor-film combinations

9. ORDER BY
   - Why: To rank gaps by size
   - Result set effect:
     - Sorts results by gap in descending order
*/
SELECT 
    a.first_name, 
    a.last_name, 
    f1.release_year AS current_film_year,
    (
        SELECT MIN(f2.release_year) 
        FROM public.film f2 
        INNER JOIN public.film_actor fa2 ON f2.film_id = fa2.film_id 
        WHERE fa2.actor_id = a.actor_id 
          AND f2.release_year > f1.release_year
    ) - f1.release_year AS gap
FROM public.actor AS a
INNER JOIN public.film_actor AS fa1 ON a.actor_id = fa1.actor_id
INNER JOIN public.film AS f1 ON fa1.film_id = f1.film_id
WHERE (
    SELECT MIN(f2.release_year) 
    FROM public.film f2 
    INNER JOIN public.film_actor fa2 ON f2.film_id = fa2.film_id 
    WHERE fa2.actor_id = a.actor_id 
      AND f2.release_year > f1.release_year
) IS NOT NULL
ORDER BY gap DESC, a.last_name;
/*Advantages
Very intuitive logic:
'For each film, find the next film of the same actor' - easy to understand.
Direct mapping to the problem: clearly expresses the idea of finding the next film year.
No need for complex joins: reduces structural complexity.
Good for small datasets: works fine when data volume is limited.
Disadvantages 
Repeated computation: the same subquery runs multiple times - very inefficient.
Poor scalability: performance degrades significantly as the number of films increases.
Hard to read when repeated: especially since your query uses the subquery twice.
Redundant logic: same calculation duplicated in SELECT and WHERE.
Hard to optimize by the database: correlated subqueries are often slower than joins/window functions.*/

/* Part3, V2, CET Solution */

/* JOIN SELECTION AND WHY + RESULT SET EFFECT:

1. CTE (actor_film_years)
   - INNER JOIN film_actor (fa) with film (f)
   - Why: To extract actor_id and release_year pairs
   - Result set effect:
     - Produces dataset of (actor_id, release_year)
     - DISTINCT removes duplicates (same actor multiple films in same year)

2. CTE (gaps_calc)
   - INNER JOIN actor_film_years y1 with y2
   - Why: To compare each film year with future film years for the same actor
   - Result set effect:
     - Creates combinations of (start_year - future years) per actor
      Enables calculation of next film via MIN(y2.release_year)

3. JOIN CONDITION (y2.release_year > y1.release_year)
   - Why: To ensure only future films are considered
   - Result set effect:
     - Filters out same-year and past films
     - Keeps only forward-looking comparisons

4. GROUP BY (actor_id, start_year)
   - Why: To collapse multiple future matches into one next film
   - Result set effect:
     - Aggregates multiple rows into one per actor + start_year
     - Enables MIN() to simulate "next film"

5. MIN(y2.release_year)
   - Why: To find the closest next film year
   - Result set effect:
     - Identifies immediate next film for each starting year

6. INNER JOIN actor (a) with gaps_calc
   - Why: To attach actor names to calculated gaps
   - Result set effect:
     - Adds descriptive actor information
     - Keeps only actors with valid gap calculations

7. WHERE gap_duration > 1
   - Why: To filter only meaningful inactivity periods
   - Result set effect:
     - Removes consecutive-year films
     - Keeps only significant gaps

8. INNER JOIN TYPE (overall)
   - Why: Only actors with multiple films (at least 2 years) are relevant
   - Result set effect:
     - Excludes actors without gaps
     - Ensures valid sequential comparison

9. ORDER BY
   - Why: To rank largest inactivity gaps first
   - Result set effect:
     - Sorts output by gap_duration in descending order
*/
WITH actor_film_years AS (
    SELECT DISTINCT fa.actor_id, f.release_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
),
gaps_calc AS (
    SELECT 
        y1.actor_id, 
        y1.release_year AS start_year, 
        MIN(y2.release_year) AS end_year
    FROM actor_film_years y1
    INNER JOIN actor_film_years y2 
        ON y1.actor_id = y2.actor_id 
        AND y2.release_year > y1.release_year
    GROUP BY y1.actor_id, y1.release_year
)
SELECT 
    a.first_name, 
    a.last_name, 
    gc.start_year, 
    gc.end_year, 
    (gc.end_year - gc.start_year) AS gap_duration
FROM public.actor AS a
INNER JOIN gaps_calc AS gc ON a.actor_id = gc.actor_id
ORDER BY gap_duration DESC, a.last_name, gc.start_year;
/*Advantages:
Most natural solution for sequential gaps
- LEAD() directly represents 'next film'
Highly readable and clean
No self-joins needed - avoids row explosion
Efficient for large datasets - only one pass over data
Easily extendable:
can compute multiple gaps
can rank actors by inactivity
can find max gap per actor
Cleaner separation of steps (CTE structure improves clarity)
Disadvantages:
Requires advanced SQL knowledge (window functions)
Not supported in very old database systems
CTE overhead (in some DBs):
may be materialized (depending on DB engine)
Slight learning curve compared to joins/subqueries*/
















