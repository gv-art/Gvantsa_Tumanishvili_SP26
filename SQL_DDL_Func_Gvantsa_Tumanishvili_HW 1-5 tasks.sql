/*1st task*/

CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
/**
 * LOGIC EXPLANATION:
 * - Current Quarter/Year: Determined using EXTRACT(QUARTER/YEAR FROM CURRENT_DATE). 
 * This updates automatically as the system clock advances.
 * - Calculation: SUM(p.amount) aggregates revenue per category name.
 * - Why only sales appear: INNER JOINs require a match across all tables. 
 * If a category has no inventory or no payments, it is dropped from the result.
 * - Zero-sales exclusion: The WHERE clause filters specific payment dates. 
 * Categories without payments in that range result in an empty set for that group.
 */
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

CREATE OR REPLACE FUNCTION get_sales_by_category(target_year INT, target_qtr INT)
RETURNS TABLE(cat_name TEXT, revenue DECIMAL) AS $$
BEGIN
    -- Checking for incorrect parameters
    IF target_year < 1900 OR target_year > 2100 THEN
        RAISE EXCEPTION 'Invalid year: %. Please provide a realistic year.', target_year;
    END IF;

    IF target_qtr < 1 OR target_qtr > 4 THEN
        RAISE EXCEPTION 'Invalid quarter: %. Must be between 1 and 4.', target_qtr;
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
    WHERE EXTRACT(QUARTER FROM p.payment_date) = target_qtr
      AND EXTRACT(YEAR FROM p.payment_date) = target_year
    GROUP BY c.name;

    -- Checking if data is missing (No results found)
    IF NOT FOUND THEN
        RAISE NOTICE 'No sales data found for Year %, Quarter %.', target_year, target_qtr;
    END IF;
END;
$$ LANGUAGE plpgsql;

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
 * identify the top film for each country efficiently.
 * - Ties: Handled by RANK(). If multiple films have the same rental count, 
 * this function returns the first one based on alphabetical order of the title.
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
            -- Rank films by popularity per country
            ROW_NUMBER() OVER (
                PARTITION BY co.country 
                ORDER BY COUNT(r.rental_id) DESC, f.title ASC
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
/*Popularity is calculated by the total rental count (COUNT(r.rental_id)). This is usually the most accurate measure of "popularity" in a rental business model compared 
to revenue, which might be skewed by varying rental rates.
We use ROW_NUMBER() with an ORDER BY rental_count DESC, f.title ASC. If two films have the exact same number of rentals, the film that comes first alphabetically will 
be selected as the "most popular." This ensures the function is deterministic (it returns the same result every time).
If the array is NULL, the function hits our safety check and raises an exception. If the array is empty, it does the same.
If a country exists in the country table but has no customers or rentals (e.g., no data), it is filtered out by the INNER JOIN chain.
The function will simply not return a row for that country. If the entire result set is empty, a RAISE NOTICE informs the user.
Country: Returns the name (e.g., 'Brazil').
Film: Returns the title (e.g., 'Film A').
Rating: Returns PG, PG-13, etc.
Language: Returns the film language.
Length: Returns duration in minutes.
Release Year: Returns the year of release.*/

/*4th task*/

CREATE OR REPLACE FUNCTION films_in_stock_by_title(p_title_pattern TEXT)
RETURNS TABLE (
    row_num INT,
    film_title TEXT,
    language TEXT,
    customer_name TEXT,
    rental_date TIMESTAMPTZ -- Matches the actual DB type
) AS $$
/**
 * LOGIC EXPLANATION:
 * - Pattern Matching: Uses the ILIKE operator with '%' wildcards for case-insensitive 
 * partial title matches.
 * - Row Numbering: Generated via ROW_NUMBER() window function to provide 
 * an incrementing counter (1, 2, 3...) for the results.
 * - Performance: We filter films in a CTE first. Pattern matching with '%' can 
 * be slow (sequential scan), so narrowing the film list before joining 
 * larger tables like 'rental' and 'customer' saves processing time.
 * - Case Sensitivity: Handled by 'ILIKE' so 'LOVE' and 'love' both match.
 */
BEGIN
    -- Handle incorrect parameters
    IF p_title_pattern IS NULL OR p_title_pattern = '' THEN
        RAISE EXCEPTION 'Search pattern cannot be empty or NULL.';
    END IF;

    RETURN QUERY
    WITH matching_films AS (
        SELECT 
            f.film_id,
            f.title,
            l.name AS lang_name
        FROM film f
        JOIN language l ON f.language_id = l.language_id
        WHERE f.title ILIKE p_title_pattern
    )
    SELECT 
        (ROW_NUMBER() OVER (ORDER BY mf.title, r.rental_date DESC))::INT,
        mf.title::TEXT,
        mf.lang_name::TEXT,
        (c.first_name || ' ' || c.last_name)::TEXT,
        r.rental_date
    FROM matching_films mf
    JOIN inventory i ON mf.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN customer c ON r.customer_id = c.customer_id;

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
If a movie has been rented 5 times, it will appear 5 times with different rental dates and unique row_num values.
If a film title matches but there are no inventory records for it, the INNER JOIN ensures it is excluded (since it's not "in stock").*/

/*5th Task*/

CREATE OR REPLACE FUNCTION new_movie(
    p_title TEXT,
    p_release_year YEAR DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::YEAR,
    p_language_name TEXT DEFAULT 'Klingon'
)
RETURNS TEXT AS $$
/**
 * LOGIC EXPLANATION:
 * - Unique ID Generation: We fetch the next value from the film_film_id_seq sequence.
 * - No Duplicates: We use an IF EXISTS check on the title before inserting.
 * - Language Validation: We look up the language_id based on the name provided.
 * - Consistency: By checking all conditions (duplicates and language) before 
 * performing the INSERT, we ensure the database remains in a valid state.
 * - Result: Returns a success message with the new Film ID.
 */
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

    -- 3. Validate language existence
    SELECT language_id INTO v_lang_id 
    FROM language 
    WHERE TRIM(name) = p_language_name;

    IF v_lang_id IS NULL THEN
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

-- Test queris
SELECT new_movie('Interstellar', 2014, 'English');
SELECT new_movie('Interstellar');
/*Logic & Scenario Explanations
The function uses nextval('film_film_id_seq'). This calls the internal PostgreSQL sequence associated with the film_id column, ensuring the ID is unique and 
incremented correctly without manual hardcoding.
Before the INSERT command, an IF EXISTS query checks the film table for the provided title. Titles are converted to UPPER() to ensure "Interstellar" and "interstellar" 
are treated as the same movie.
The function immediately halts and raises a custom exception: "Movie title ... already exists". This prevents the INSERT from ever firing, maintaining data integrity.
The function attempts to select the language_id into a variable (v_lang_id). If the result is NULL, it means the language doesn't exist in the language table, and the 
function raises an exception.
The insertion is wrapped in a PL/pgSQL block. If a database-level error occurs (e.g., a constraint violation), the EXCEPTION block captures it and rolls back the logic,
 ensuring no "partial" data is left behind. By validating the title and language before the insert, we minimize the chance of mid-process failures.
 If optional parameters (Year/Language) are missing, the function uses the DEFAULT values defined in the signature (EXTRACT(YEAR...) and 'Klingon'). If the required 
 title is missing, the IF check at the start catches it.
*/



















	




