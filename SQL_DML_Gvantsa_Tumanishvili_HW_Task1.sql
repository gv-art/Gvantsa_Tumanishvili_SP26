/* GENERAL TASK 1 comments:
- WHY SEPARATE TRANSACTIONS?
  Each logical operation is wrapped in its own BEGIN/COMMIT to ensure Atomicity. This means each 
  step (like adding films or updating a customer) is treated as a single "unit of work."
  
- WHAT WOULD HAPPEN IF THE TRANSACTION FAILS?
  If an error occurs (like a constraint violation), the entire transaction block is aborted. 
  The database will not save any partial data from that specific block, keeping the DB clean.
  
- ROLLBACK POSSIBILITY & DATA IMPACT:
  A ROLLBACK is possible at any point before the COMMIT is executed. If triggered, all 
  uncommitted data within that block is discarded, and the database reverts to its exact 
  state prior to that block's BEGIN. No other user data is affected.
  
- REFERENTIAL INTEGRITY:
  Maintained by dynamically fetching Foreign Keys (like language_id, film_id, staff_id) 
  using subqueries and JOINs instead of hardcoding numbers. This ensures all relationships 
  point to existing, valid records.
  
- DUPLICATE PREVENTION:
  The script uses 'WHERE NOT EXISTS' clauses against unique business keys (film titles, 
  actor names, etc.) to ensure the script can be run multiple times without 
  creating duplicate records.
*/

/*Adding my favorite movies: Hamnet, Barbie and Interstellar to the table:*/
/* comments:
- Uniqueness: Ensured via WHERE NOT EXISTS on the film title.
- Relationships: Established by dynamically pulling language_id for 'English' using TRIM() 
  to handle the CHAR(20) padding issue.
- Advantages of INSERT INTO SELECT: Avoids hardcoding IDs, making the script portable across 
  different database environments.
*/
BEGIN;

WITH lang AS (
    SELECT language_id
    FROM public.language
    WHERE TRIM(name) = 'English'
),
films_to_insert AS (
    SELECT *
    FROM (
        VALUES
        (
            'HAMNET',
            'A historical drama reimagining the life of William Shakespeare and his wife Agnes as they struggle with the tragic death of their son, Hamnet, which inspires the creation of the play Hamlet.',
            2025, 7, 4.99, 20.99, 'PG-13'::mpaa_rating
        ),
        (
            'BARBIE',
            'Stereotypical Barbie experiences a full-on existential crisis and embarks on a journey of self-discovery from Barbie Land to the real world.',
            2024, 14, 9.99, 19.99, 'PG-13'::mpaa_rating
        ),
        (
            'INTERSTELLAR',
            'A team of explorers travel through a wormhole in space in an attempt to ensure humanity survival as Earth faces an environmental collapse.',
            2014, 21, 19.99, 24.99, 'PG-13'::mpaa_rating
        )
    ) AS f(title, description, release_year, rental_duration, rental_rate, replacement_cost, rating)
)
INSERT INTO public.film (
    title,
    description,
    release_year,
    language_id,
    rental_duration,
    rental_rate,
    replacement_cost,
    rating,
    last_update
)
SELECT 
    f.title,
    f.description,
    f.release_year,
    l.language_id,
    f.rental_duration,
    f.rental_rate,
    f.replacement_cost,
    f.rating,
    CURRENT_DATE
FROM films_to_insert f
CROSS JOIN lang l
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.film existing 
    WHERE existing.title = f.title
)
RETURNING *;

COMMIT;


/* Adding my actors to the Acotrs table, since none of them have been existed in the table as i checked it*/
/* comments:
- Uniqueness: Ensured by checking for the combination of first_name and last_name 
  using WHERE NOT EXISTS.
- Logic: Prevents duplicating real-world actors that might already exist in the system.
*/
BEGIN;

INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 'JESSIE', 'BUCKLEY', CURRENT_DATE
WHERE NOT EXISTS (SELECT 1 FROM public.actor WHERE first_name = 'JESSIE' AND last_name = 'BUCKLEY')
UNION ALL
SELECT 'PAUL', 'MESCAL', CURRENT_DATE
WHERE NOT EXISTS (SELECT 1 FROM public.actor WHERE first_name = 'PAUL' AND last_name = 'MESCAL')
UNION ALL
SELECT 'MARGOT', 'ROBBIE', CURRENT_DATE
WHERE NOT EXISTS (SELECT 1 FROM public.actor WHERE first_name = 'MARGOT' AND last_name = 'ROBBIE')
UNION ALL
SELECT 'RYAN', 'GOSLING', CURRENT_DATE
WHERE NOT EXISTS (SELECT 1 FROM public.actor WHERE first_name = 'RYAN' AND last_name = 'GOSLING')
UNION ALL
SELECT 'MATTHEW', 'MCCONAUGHEY', CURRENT_DATE
WHERE NOT EXISTS (SELECT 1 FROM public.actor WHERE first_name = 'MATTHEW' AND last_name = 'MCCONAUGHEY')
UNION ALL
SELECT 'ANNE', 'HATHAWAY', CURRENT_DATE
WHERE NOT EXISTS (SELECT 1 FROM public.actor WHERE first_name = 'ANNE' AND last_name = 'HATHAWAY')
RETURNING actor_id, first_name, last_name;

COMMIT;

/* Adding my actors and films in the film_actor conjunction table using corresponsing IDs*/

/* comments:
- Relationships: inventory is linked to films via film_id; film_actor links actors to 
  films using dynamic lookups.
- Inventory: Ensures films exist in a store's stock before they are made available for rental.
*/
BEGIN;

-- Step 1: Insert inventory for the films into stores
WITH films AS (
    SELECT film_id, title
    FROM public.film
    WHERE title IN ('HAMNET', 'BARBIE', 'INTERSTELLAR')
),
stores AS (
    SELECT store_id
    FROM public.store
)
INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, s.store_id, CURRENT_DATE
FROM films f
CROSS JOIN stores s
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.inventory i
    WHERE i.film_id = f.film_id 
      AND i.store_id = s.store_id
)
RETURNING *;


-- Step 2: Insert film_actor relationships
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
JOIN public.film f 
    ON f.title IN ('HAMNET', 'BARBIE', 'INTERSTELLAR')
WHERE (a.first_name, a.last_name, f.title) IN (
    ('JESSIE', 'BUCKLEY', 'HAMNET'),
    ('PAUL', 'MESCAL', 'HAMNET'),
    ('MARGOT', 'ROBBIE', 'BARBIE'),
    ('RYAN', 'GOSLING', 'BARBIE'),
    ('MATTHEW', 'MCCONAUGHEY', 'INTERSTELLAR'),
    ('ANNE', 'HATHAWAY', 'INTERSTELLAR')
)
AND NOT EXISTS (
    SELECT 1 
    FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id 
      AND fa.film_id = f.film_id
)
RETURNING *;

COMMIT;

/*Altering any existing customer in the database with at least 43 rental and 43 payment records and Changing their personal data to mine*/
/* comments:
- Data Integrity: PRE-CHECK SELECT is performed to verify the target customer before update.
- Join Inflation: Count of rentals and payments are calculated independently in subqueries 
  to ensure the "at least 43 records" logic is mathematically accurate and not inflated 
  by a many-to-many join.
- No Hardcoding: address_id is fetched dynamically from the address table.
*/
BEGIN;

-- Step 1: PRE-CHECK
WITH rental_counts AS (
    SELECT customer_id, COUNT(*) AS rental_count
    FROM public.rental
    GROUP BY customer_id
),
payment_counts AS (
    SELECT customer_id, COUNT(*) AS payment_count
    FROM public.payment
    GROUP BY customer_id
),
target_customer AS (
    SELECT c.customer_id
    FROM public.customer c
    JOIN rental_counts r ON c.customer_id = r.customer_id
    JOIN payment_counts p ON c.customer_id = p.customer_id
    WHERE r.rental_count >= 43
      AND p.payment_count >= 43
    LIMIT 1
)
SELECT *
FROM public.customer
WHERE customer_id = (SELECT customer_id FROM target_customer);


-- Step 2: UPDATE (CTE must be redefined!)
WITH rental_counts AS (
    SELECT customer_id, COUNT(*) AS rental_count
    FROM public.rental
    GROUP BY customer_id
),
payment_counts AS (
    SELECT customer_id, COUNT(*) AS payment_count
    FROM public.payment
    GROUP BY customer_id
),
target_customer AS (
    SELECT c.customer_id
    FROM public.customer c
    JOIN rental_counts r ON c.customer_id = r.customer_id
    JOIN payment_counts p ON c.customer_id = p.customer_id
    WHERE r.rental_count >= 43
      AND p.payment_count >= 43
    LIMIT 1
)
UPDATE public.customer
SET 
    store_id = 1,
    first_name = 'GVANTSA',
    last_name = 'TUMANISHVILI',
    email = 'tumanishviligvanca@gmail.com',
    address_id = (
        SELECT address_id 
        FROM public.address 
        ORDER BY address_id 
        LIMIT 1
    ),
    last_update = CURRENT_DATE
WHERE customer_id = (SELECT customer_id FROM target_customer)
RETURNING *;

COMMIT;

/*Deleting my records from Rental and Payment tables*/
/* comments:
- Safety: PRE-CHECK SELECTs are run for both payment and rental tables to confirm target rows.
- Data Loss Prevention: Deleting from the child table (payment) before the parent table (rental) 
  honors foreign key constraints and prevents unintended errors.
- Scope: Only records linked to the specific 'GVANTSA' customer_id are targeted.
*/
BEGIN;

-- Step 1: PRE-CHECK customer (optional but recommended)
SELECT *
FROM public.customer
WHERE first_name = 'GVANTSA' 
  AND last_name = 'TUMANISHVILI';

-- Step 2: PRE-CHECK payments (REQUIRED)
SELECT *
FROM public.payment
WHERE customer_id = (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'GVANTSA' 
      AND last_name = 'TUMANISHVILI'
    LIMIT 1
);

-- Step 3: PRE-CHECK rentals (REQUIRED)
SELECT *
FROM public.rental
WHERE customer_id = (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'GVANTSA' 
      AND last_name = 'TUMANISHVILI'
    LIMIT 1
);

-- Step 4: DELETE payments (child table first)
DELETE FROM public.payment 
WHERE customer_id = (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'GVANTSA' 
      AND last_name = 'TUMANISHVILI'
    LIMIT 1
)
RETURNING *;

-- Step 5: DELETE rentals
DELETE FROM public.rental 
WHERE customer_id = (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'GVANTSA' 
      AND last_name = 'TUMANISHVILI'
    LIMIT 1
)
RETURNING *;

COMMIT;

/*Renting my favorite movies from the store they are in and paying for them:*/
/* comments:
- Relationships: staff_id is dynamically selected based on the store_id of the inventory item.
- Business Logic: A CASE expression handles the rental amount, comparing return_date 
  to the film's rental_duration to calculate potential late fees.
- Integrity: Ensures that the rental transaction and the corresponding payment are 
  recorded simultaneously within the same transaction.
*/

/* Subtask: Rent & Pay
*/

BEGIN;

-- 1. FIRST: Ensure the movies are in the Inventory (Choosing Store 1)
INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, 1, CURRENT_DATE
FROM public.film f
WHERE f.title IN ('HAMNET', 'BARBIE', 'INTERSTELLAR')
AND NOT EXISTS (
    SELECT 1 FROM public.inventory i WHERE i.film_id = f.film_id AND i.store_id = 1
)
RETURNING inventory_id;


-- 2. SECOND: Create Rental records
INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id, return_date, last_update)
SELECT 
    '2017-05-15 10:00:00'::timestamp, 
    i.inventory_id, 
    c.customer_id, 
    s.staff_id, 
    '2017-05-22 10:00:00'::timestamp, -- Returning it 7 days later
    CURRENT_DATE
FROM public.inventory i
JOIN public.film f ON i.film_id = f.film_id
JOIN public.store st ON i.store_id = st.store_id
JOIN public.staff s ON st.manager_staff_id = s.staff_id -- Dynamically getting staff from that store
CROSS JOIN public.customer c
WHERE f.title IN ('HAMNET', 'BARBIE', 'INTERSTELLAR')
  AND c.first_name = 'GVANTSA'
  AND NOT EXISTS (
      SELECT 1 FROM public.rental r 
      WHERE r.inventory_id = i.inventory_id 
      AND r.customer_id = c.customer_id 
      AND r.rental_date = '2017-05-15 10:00:00'
  )
RETURNING rental_id, inventory_id, staff_id;


-- 3. THIRD: Create Payment records with late fee logic
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 
    r.customer_id, 
    r.staff_id, 
    r.rental_id, 
    CASE 
        WHEN (EXTRACT(DAY FROM (r.return_date - r.rental_date)) > f.rental_duration) 
        -- Base rate + $2.00 per day late fee (example logic)
        THEN f.rental_rate + ((EXTRACT(DAY FROM (r.return_date - r.rental_date)) - f.rental_duration) * 2.00)
        ELSE f.rental_rate 
    END as total_amount,
    '2017-05-15 10:05:00'::timestamp
FROM public.rental r
JOIN public.inventory i ON r.inventory_id = i.inventory_id
JOIN public.film f ON i.film_id = f.film_id
WHERE r.customer_id = (SELECT customer_id FROM public.customer WHERE first_name = 'GVANTSA' LIMIT 1)
  AND r.rental_date = '2017-05-15 10:00:00'
  AND NOT EXISTS (
      SELECT 1 FROM public.payment p WHERE p.rental_id = r.rental_id
  )
RETURNING *;

COMMIT;








































