-- Task2
-- 2.Create a new user with the username "rentaluser" and the password "rentalpassword". Give the user the ability to connect to the database but no other permissions.

-- crwating user:
CREATE ROLE rentaluser LOGIN PASSWORD 'rentalpassword';
-- granting permission
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;
-- switching to rentaluser role succesfully:
SET ROLE rentaluser;
-- Trying to read to trigger ERROR message and demonstrate denied access:
SELECT * FROM customer;

-- 2.Grant "rentaluser" permission allows reading data from the "customer" table. check to make sure this permission works correctly: write a SQL query to select all customers.

-- Switching to rentaluser before granting permission to demonstrate denied access to table:
SET ROLE rentaluser;
SELECT * FROM customer;
-- granting rentaluser permission to read data from customer table:
RESET ROLE;
GRANT SELECT ON customer TO rentaluser;
-- Checking to make sure the permission works
SET ROLE rentaluser;
SELECT * FROM customer;
-- trying to read film table to trigger ERROR
SELECT * FROM film;

-- 3.Create a new user group called "rental" and add "rentaluser" to the group.

-- reseting to administrator
RESET ROLE;
--creating new user rental
CREATE ROLE rental;
-- adding rentaluser to the group
GRANT rental TO rentaluser;

-- 4.Grant the "rental" group INSERT and UPDATE permissions for the "rental" table. Insert a new row and update one existing row in the "rental" table under that role.

-- Grant table-level permissions
GRANT SELECT, INSERT, UPDATE ON TABLE public.rental TO rental;

SET ROLE rentaluser;
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (CURRENT_TIMESTAMP, 10, 5, CURRENT_TIMESTAMP + INTERVAL '7 days', 1);

UPDATE rental 
SET return_date = CURRENT_TIMESTAMP 
WHERE rental_id = 1;

-- 5. Revoke the "rental" group's INSERT permission for the "rental" table. Try to insert new rows into the "rental" table make sure this action is denied.
--Switching to Admin to revoke the permission
RESET ROLE;
-- Revoking the INSERT permission from the group
REVOKE INSERT ON TABLE public.rental FROM rental;
SET ROLE rentaluser;
-- TRY TO INSERT: to trigger error and demonstrated revoke was successful
SET ROLE rentaluser;
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (CURRENT_TIMESTAMP, 11, 6, CURRENT_TIMESTAMP + INTERVAL '2 days', 1);
-- Switching back to admin
RESET ROLE;

-- 6.Create a personalized role for any customer already existing in the dvd_rental database. The name of the role name must be client_{first_name}_{last_name} (omit curly brackets). The customer's payment and rental history must not be empty. 
RESET ROLE;
SELECT c.first_name, c.last_name
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(r.rental_id) > 0 AND COUNT(p.payment_id) > 0
LIMIT 1;

-- Runing as Superuser (Admin)
CREATE ROLE client_mary_smith;

-- demonstrating succesful access
-- Grant permission to the new role
GRANT SELECT ON TABLE public.customer TO client_mary_smith;
SET ROLE client_mary_smith;
SELECT first_name, last_name, email 
FROM public.customer 
WHERE first_name = 'MARY' AND last_name = 'SMITH';

-- demonstrating denied access
SELECT * FROM public.payment;

RESET ROLE;

--Task 3. Implement row-level security
-- finding Mary's ID (which was 1):
SELECT customer_id FROM customer WHERE first_name = 'MARY' AND last_name = 'SMITH';

-- Grant the role access to the tables
GRANT SELECT ON rental, payment TO client_mary_smith;

-- enabling row-level security:
ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;

-- creating security pilicies for both tables:
CREATE POLICY mary_rental_policy ON rental
    FOR SELECT
    TO client_mary_smith
    USING (customer_id = 1); -- Assuming Mary's ID is 1
CREATE POLICY mary_payment_policy ON payment
    FOR SELECT
    TO client_mary_smith
    USING (customer_id = 1);

-- demonstrating results:
SET ROLE client_mary_smith;

SELECT * FROM rental;

SELECT * FROM payment;








