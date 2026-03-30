/*Adding my favorite movies: Hamnet, Barbie and Interstellar to the table:*/
BEGIN;

INSERT INTO public.film (title, description, release_year, language_id, rental_duration, rental_rate, replacement_cost, rating, last_update)
SELECT 'HAMNET', 'A historical drama reimagining the life of William 
Shakespeare and his wife Agnes as they struggle with the tragic death of their son, Hamnet, 
which inspires the creation of the play Hamlet.', 2025, language_id, 7, 4.99, 20.99, 'PG-13'::mpaa_rating, CURRENT_DATE
FROM public.language WHERE name = 'English'
AND NOT EXISTS (SELECT 1 FROM public.film WHERE title = 'HAMNET')

UNION ALL

SELECT 'BARBIE', 'Stereotypical Barbie experiences a full-on existential crisis and embarks on a 
journey of self-discovery from Barbie Land to the real world.', 2024, language_id, 14, 9.99, 19.99, 'PG-13'::mpaa_rating, CURRENT_DATE
FROM public.language WHERE name = 'English'
AND NOT EXISTS (SELECT 1 FROM public.film WHERE title = 'BARBIE')

UNION ALL

SELECT 'INTERSTELLAR', 'A team of explorers travel through a wormhole in space in an attempt to 
ensure humanity survival as Earth faces an environmental collapse.', 2014, language_id, 21, 19.99, 24.99, 'PG-13'::mpaa_rating, CURRENT_DATE
FROM public.language WHERE name = 'English'
AND NOT EXISTS (SELECT 1 FROM public.film WHERE title = 'INTERSTELLAR')

RETURNING *;

COMMIT;


/* Adding my actors to the Acotrs table, since none of them have been existed in the table as i checked it*/
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
BEGIN;

INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM public.actor a
CROSS JOIN public.film f
WHERE (a.first_name, a.last_name, f.title) IN (
    ('JESSIE', 'BUCKLEY', 'HAMNET'),
    ('PAUL', 'MESCAL', 'HAMNET'),
    ('MARGOT', 'ROBBIE', 'BARBIE'),
    ('RYAN', 'GOSLING', 'BARBIE'),
    ('MATTHEW', 'MCCONAUGHEY', 'INTERSTELLAR'),
    ('ANNE', 'HATHAWAY', 'INTERSTELLAR')
)
AND NOT EXISTS (
    SELECT 1 FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING *;

COMMIT;

/*Altering any existing customer in the database with at least 43 rental and 43 payment records and Changing their personal data to mine*/
BEGIN;

UPDATE public.customer
SET 
    store_id = 1,
    first_name = 'GVANTSA',
    last_name = 'TUMANISHVILI',
    email = 'tumanishviligvanca@gmail.com',
    address_id = 5,
    last_update = CURRENT_DATE
WHERE customer_id = (
    SELECT c.customer_id
    FROM public.customer c
    JOIN public.rental r ON c.customer_id = r.customer_id
    JOIN public.payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id
    HAVING COUNT(DISTINCT r.rental_id) >= 43 
       AND COUNT(DISTINCT p.payment_id) >= 43
    LIMIT 1 -- Ensures only one customer is altered
)
RETURNING *;

COMMIT;

/*Deleting my records from Rental and Payment tables*/
BEGIN;

DELETE FROM public.payment 
WHERE customer_id = (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'GVANTSA' AND last_name = 'TUMANISHVILI'
    LIMIT 1
)
RETURNING *;

DELETE FROM public.rental 
WHERE customer_id = (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'GVANTSA' AND last_name = 'TUMANISHVILI'
    LIMIT 1
)
RETURNING *;

COMMIT;

/*Renting my favorite movies from the store they are in and paying for them:*/

BEGIN;

-- 1. Create the Rental records
INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id, last_update)
SELECT '2017-05-15 10:00:00', i.inventory_id, c.customer_id, 1, CURRENT_DATE
FROM public.inventory i
JOIN public.film f ON i.film_id = f.film_id
CROSS JOIN public.customer c
WHERE f.title IN ('HAMNET', 'BARBIE', 'INTERSTELLAR')
  AND c.first_name = 'GVANTSA'
  AND NOT EXISTS (
      SELECT 1 FROM public.rental r 
      WHERE r.inventory_id = i.inventory_id 
      AND r.customer_id = c.customer_id 
      AND r.rental_date = '2017-05-15 10:00:00'
  )
RETURNING rental_id;
-- 2. Create the Payment records
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT r.customer_id, r.staff_id, r.rental_id, f.rental_rate, '2017-05-15 10:05:00'
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








































