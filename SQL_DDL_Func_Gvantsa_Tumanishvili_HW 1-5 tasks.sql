/*1st task*/
/**
 * LOGIC EXPLANATION:
 * - Current Quarter/Year: Determined dynamically using EXTRACT(QUARTER FROM CURRENT_DATE) 
 * and EXTRACT(YEAR FROM CURRENT_DATE). This ensures the view always targets the 
 * present day without manual updates.
 * - Calculation: SUM(p.amount) aggregates the total revenue for each specific category.
 * - Why only sales appear: The query uses INNER JOINs across Category, Film_Category, 
 * Inventory, Rental, and Payment. If a category has no linked sales, there is no 
 * matching row in the 'payment' table, so the category is not included.
 * - Zero-sales exclusion: The WHERE clause strictly filters for payment_dates within the 
 * current quarter/year. Categories that only have sales in previous quarters are 
 * excluded by this filter.
 *
 * SCENARIO HANDLING:
 * - Missing Data: If a category exists but has no sales for the current quarter, it 
 * simply won't appear in the output.
 * - Incorrect Input: Since this is a VIEW with no parameters, it relies on the system clock. 
 * If the database system time is wrong, the quarter calculation will be wrong.
 *
 * VERIFICATION METHOD:
 * - Because the sample database contains no data for 2026, the view will naturally be empty.
 * - Verification: To verify the logic works, we can temporarily replace "CURRENT_DATE" 
 * with a literal date known to have data (e.g., '2007-02-15') to see the quarter 
 * aggregation trigger. Once verified, it is reverted to CURRENT_DATE for production.
 *
 * DATA THAT SHOULD NOT APPEAR:
 * - Sales from a different year (e.g., revenue from 2005).
 * - Sales from a different quarter (e.g., if we are in Q2, Q1 sales are excluded).
 * - Film categories that exist in the 'category' table but have never been rented.
 */
-- CREATE VIEW
CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category_name,
    SUM(p.amount) AS total_revenue,
    EXTRACT(QUARTER FROM CURRENT_DATE) AS current_quarter,
    EXTRACT(YEAR FROM CURRENT_DATE) AS current_year
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN inventory i ON fc.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
WHERE EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
  AND EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY c.name;

SELECT * FROM sales_revenue_by_category_qtr;
/*2nd task*/

CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(
    p_year INT, 
    p_quarter INT
)
RETURNS TABLE(category_name TEXT, total_revenue NUMERIC) AS $$
/**
 * LOGIC EXPLANATION:
 * - Why parameters are used: To make the logic reusable for any specific point in time, 
 * allowing users to pull historical reports by passing specific year/quarter values.
 * - Calculation: The function joins the category table to payments through the 
 * inventory and rental chain. It sums the 'amount' where the date parts match the inputs.
 * - Result: Returns a table with the category name and the calculated sum.
 */
BEGIN
    -- 1. Handling Incorrect Parameters (Invalid Quarter)
    IF p_quarter < 1 OR p_quarter > 4 THEN
        RAISE EXCEPTION 'Invalid quarter: %. Value must be between 1 and 4.', p_quarter;
    END IF;

    -- 2. Handling Incorrect Parameters (Invalid Year)
    IF p_year < 1900 OR p_year > 2100 THEN
        RAISE EXCEPTION 'Invalid year: %. Please provide a valid year (1900-2100).', p_year;
    END IF;

    RETURN QUERY
    SELECT 
        c.name::TEXT,
        SUM(p.amount)
    FROM category c
    JOIN film_category fc ON c.category_id = fc.category_id
    JOIN inventory i ON fc.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    WHERE EXTRACT(QUARTER FROM p.payment_date) = p_quarter
      AND EXTRACT(YEAR FROM p.payment_date) = p_year
    GROUP BY c.name;

    -- 3. Handling Missing Data
    -- If the SELECT query returns 0 rows, we notify the user.
    IF NOT FOUND THEN
        RAISE NOTICE 'No sales data exists for Year %, Quarter %.', p_year, p_quarter;
    END IF;
END;
$$ LANGUAGE plpgsql;

--test A
-- Using 2007 Q1 because the database actually has data for this period
SELECT * FROM get_sales_revenue_by_category_qtr(2007, 1);

-- test B
-- Testing an impossible quarter to see the RAISE EXCEPTION in action
SELECT * FROM get_sales_revenue_by_category_qtr(2026, 5);

-- 3rd task
- 3rd task
CREATE OR REPLACE FUNCTION most_popular_films_by_countries(p_countries TEXT[])
RETURNS TABLE (
    country TEXT,
    film TEXT,
    rating mpaa_rating, -- Standard type in DVD Rental DB
    language_name CHAR(20),
    length SMALLINT,
    release_year YEAR
) AS $$
/**
 * LOGIC EXPLANATION:
 * - Popularity Definition: Defined by the total count of rentals (rental_count).
 * - Calculation: We join Country -> City -> Address -> Customer -> Rental -> Inventory -> Film -> Language.
 * - Why this logic: Using a Common Table Expression (CTE) with RANK() allows us to 
 * identify the top film(s) for each country efficiently.
 * - Ties: Handled by RANK(). If multiple films have the same maximum rental count, 
 * all tied films are returned for that country.
 * - No Data: Countries with no rentals/data are excluded via INNER JOINs.
 */
BEGIN
    -- Check for incorrect parameters
    IF p_countries IS NULL OR array_length(p_countries, 1) IS NULL THEN
        RAISE EXCEPTION 'Input country array cannot be empty or NULL.';
    END IF;

    RETURN QUERY
    WITH film_popularity AS (
        SELECT 
            co.country AS c_name,
            f.title AS f_title,
            f.rating AS f_rating,
            l.name AS f_lang,
            f.length AS f_len,
            f.release_year AS f_year,
            COUNT(r.rental_id) AS rental_count,
            -- Rank films by popularity per country. Ties receive the same rank.
            RANK() OVER (
                PARTITION BY co.country 
                ORDER BY COUNT(r.rental_id) DESC
            ) as rank_pos
        FROM country co
        JOIN city ci ON co.country_id = ci.country_id
        JOIN address a ON ci.city_id = a.city_id
        JOIN customer cu ON a.address_id = cu.address_id
        JOIN rental r ON cu.customer_id = r.customer_id
        JOIN inventory i ON r.inventory_id = i.inventory_id
        JOIN film f ON i.film_id = f.film_id
        JOIN language l ON f.language_id = l.language_id
        WHERE co.country = ANY(p_countries)
        GROUP BY co.country, f.film_id, f.title, f.rating, l.name, f.length, f.release_year
    )
    SELECT 
        c_name,
        f_title,
        f_rating,
        f_lang,
        f_len,
        f_year
    FROM film_popularity
    WHERE rank_pos = 1;

    -- If the array contains names but no data is found in tables
    IF NOT FOUND THEN
        RAISE NOTICE 'No film data found for the specified countries.';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Test queries
SELECT * FROM most_popular_films_by_countries(ARRAY['Afghanistan', 'Brazil']);
SELECT * FROM most_popular_films_by_countries(NULL);
/*
LOGIC SUMMARY:
- Popularity is calculated by the total rental count (COUNT(r.rental_id)). This is a direct measure of volume, 
providing a standard popularity metric for the rental business model.
- Ties are handled by RANK(). Unlike ROW_NUMBER(), which forces a single result, RANK() ensures that if 
multiple films share the exact same maximum rental count, all tied films are returned. This prevents 
the silent dropping of equally popular data.
- If the input array is NULL or empty, the function triggers a validation check and raises an exception.
- If a country exists in the database but has no rental records, it is excluded via the INNER JOIN chain. 
If no data is found for the entire request, a RAISE NOTICE is issued.
- The result set includes:
    * Country: The name of the country.
    * Film: The title of the top-performing film(s).
    * Rating: MPAA rating (e.g., 'PG-13').
    * Language: The spoken language of the film.
    * Length: The duration of the film in minutes.
    * Release Year: The year the film was released.
*/

/*4th task*/


CREATE OR REPLACE FUNCTION films_in_stock_by_title(p_title_pattern TEXT)
RETURNS TABLE (
    row_num INT,
    film_title TEXT,
    language TEXT,
    customer_name TEXT,
    rental_date TIMESTAMPTZ 
) AS $$
/**
 * LOGIC EXPLANATION:
 * - Pattern Matching: Uses the ILIKE operator with '%' wildcards. The '%' represents 
 * zero or more characters, allowing for case-insensitive partial title matches anywhere in the string.
 * - Row Numbering: Generated via ROW_NUMBER() starting from 1 and incrementing by 1 
 * for every row returned, as per requirements.
 * - Performance: We use a CTE to filter the 'film' table first. Pattern matching (ILIKE) 
 * on large strings can trigger sequential scans; by filtering the film IDs first, 
 * we avoid performing expensive joins on the entire rental/inventory history.
 * - Case Sensitivity: 'ILIKE' is used to ensure that searches are case-insensitive.
 * - Design Decision (Ties/History): For items currently in stock, this function returns 
 * the details of the LAST person who rented that specific copy. If an item is in 
 * stock but has never been rented, the customer and date fields will be NULL.
 * - Multiple Matches: If multiple copies of a film are in stock, each unique inventory_id 
 * appears as a separate row.
 * - No Matches: If no films match or no matching films are in stock, the function 
 * raises a NOTICE and returns an empty set.
 */
BEGIN
    -- Handle incorrect parameters
    IF p_title_pattern IS NULL OR p_title_pattern = '' THEN
        RAISE EXCEPTION 'Search pattern cannot be empty or NULL.';
    END IF;

    RETURN QUERY
    WITH available_inventory AS (
        -- Get inventory items that are NOT currently checked out
        SELECT 
            i.inventory_id,
            f.title,
            l.name AS lang_name
        FROM film f
        JOIN language l ON f.language_id = l.language_id
        JOIN inventory i ON f.film_id = i.film_id
        WHERE f.title ILIKE p_title_pattern
        AND i.inventory_id NOT IN (
            SELECT r.inventory_id 
            FROM rental r 
            WHERE r.return_date IS NULL
        )
    ),
    latest_rentals AS (
        -- Get the most recent rental for each inventory item to provide context
        SELECT DISTINCT ON (r.inventory_id)
            r.inventory_id,
            c.first_name || ' ' || c.last_name AS full_name,
            r.rental_date
        FROM rental r
        JOIN customer c ON r.customer_id = c.customer_id
        ORDER BY r.inventory_id, r.rental_date DESC
    )
    SELECT 
        (ROW_NUMBER() OVER (ORDER BY ai.title, lr.rental_date DESC))::INT AS row_num,
        ai.title::TEXT,
        ai.lang_name::TEXT,
        lr.full_name::TEXT,
        lr.rental_date
    FROM available_inventory ai
    LEFT JOIN latest_rentals lr ON ai.inventory_id = lr.inventory_id;

    -- Handle no matches found
    IF NOT FOUND THEN
        RAISE NOTICE 'No movies matching "%" were found in stock.', p_title_pattern;
    END IF;
END;
$$ LANGUAGE plpgsql;

/*Test queries*/ 
SELECT * FROM films_in_stock_by_title('%love%');
SELECT * FROM films_in_stock_by_title(NULL);

/*Uses ILIKE so that users don't have to worry about capitalization. The % characters allow the term to be found at the start, middle, or end of a title.
Pattern matching on strings can be slow on large datasets because it often bypasses standard indexes. We minimize this by filtering the film table first in a CTE before 
joining the high-volume rental and customer tables.
If a specific inventory copy has been rented multiple times in the past, only the most recent rental record will be shown for that copy to provide the latest historical context.
If a film title matches but there are no inventory records for it, the INNER JOIN ensures it is excluded (since it's not "in stock").*/

/*5th Task*/

CREATE OR REPLACE FUNCTION new_movie(
    p_title TEXT,
    p_release_year YEAR DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::YEAR,
    p_language_name TEXT DEFAULT 'Klingon'
)
RETURNS TEXT AS $$

DECLARE
    v_film_id INT;
    v_lang_id INT;
BEGIN
    -- 1. Check for incorrect parameters
    IF p_title IS NULL OR p_title = '' THEN
        RAISE EXCEPTION 'Movie title cannot be empty.';
    END IF;

    -- 2. Ensure no duplicates (Check if movie already exists)
    IF EXISTS (SELECT 1 FROM film WHERE title = UPPER(p_title)) THEN
        RAISE EXCEPTION 'Movie title "%" already exists in the database.', p_title;
    END IF;

    -- 3. Validate language existence using NOT FOUND
    SELECT language_id INTO v_lang_id 
    FROM language 
    WHERE TRIM(name) = p_language_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Language "%" not found. Please add the language to the language table first.', p_language_name;
    END IF;

    -- 4. Generate unique ID
    v_film_id := nextval('film_film_id_seq');

    -- 5. Perform Insertion
    INSERT INTO film (
        film_id, 
        title, 
        release_year, 
        language_id, 
        rental_duration, 
        rental_rate, 
        replacement_cost
    )
    VALUES (
        v_film_id, 
        UPPER(p_title), 
        p_release_year, 
        v_lang_id, 
        3, 
        4.99, 
        19.99
    );

    RETURN 'Success: Movie "' || p_title || '" inserted with ID ' || v_film_id;

EXCEPTION
    WHEN OTHERS THEN
        -- Preserving consistency: if insertion fails, re-raise the error
        RAISE EXCEPTION 'Insertion failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

/*Prerequisite for Testing*/
INSERT INTO language (name) 
SELECT 'Klingon' 
WHERE NOT EXISTS (SELECT 1 FROM language WHERE name = 'Klingon');

-- Test queries
-- (Note: Running these twice will trigger the 'already exists' exception on the second run)
SELECT new_movie('Interstellar', 2014, 'English');
SELECT new_movie('Star Trek');
/*
LOGIC & SCENARIO EXPLANATIONS:

- ID Generation: The function uses nextval('film_film_id_seq'). This calls the internal 
  PostgreSQL sequence associated with the film_id column, ensuring the ID is unique 
  and incremented correctly without manual hardcoding.

- Duplicate Prevention: Before the INSERT command, an IF EXISTS query checks the 
  film table for the provided title. Titles are converted to UPPER() to ensure 
  case-insensitive matches (e.g., 'INTERSTELLAR' and 'interstellar' are treated as duplicates).

- What happens if movie exists: If a duplicate is found, the function immediately 
  halts and raises a custom exception: "Movie title ... already exists". This prevents 
  the INSERT from ever firing, maintaining data integrity.

- Language Validation: The function selects the language_id into a variable and 
  immediately checks the internal 'FOUND' variable. This is the idiomatic PL/pgSQL 
  method to verify if the row actually exists in the language table.

- What happens if insertion fails: The insertion is wrapped in the function's logic 
  body. If a database-level error occurs, the EXCEPTION block captures it and 
  re-raises the error, ensuring the transaction is rolled back and no "partial" 
  data is left behind.

- Incorrect Parameters / Missing Data: 
    * If the required 'p_title' is missing (NULL or empty), the initial IF check 
      raises an exception.
    * If optional parameters like Year or Language are missing, the function 
      automatically applies the DEFAULT values defined in the function signature 
      (Current Year and 'Klingon').
*/




















	




