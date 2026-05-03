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

--  Grant table-level permissions
GRANT SELECT, INSERT, UPDATE ON TABLE public.rental TO rental;
--  Granting sequence permission
GRANT USAGE ON SEQUENCE public.rental_rental_id_seq TO rental;
--  Switch to the user to test
SET ROLE rentaluser;
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (CURRENT_TIMESTAMP, 10, 5, CURRENT_TIMESTAMP + INTERVAL '7 days', 1);
UPDATE rental 
SET return_date = CURRENT_TIMESTAMP 
WHERE rental_id = 1;
-- Switch back to original user
RESET ROLE;

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
-- Identify the customer
SELECT c.customer_id, c.first_name, c.last_name
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(r.rental_id) > 0 AND COUNT(p.payment_id) > 0
LIMIT 1;

--  Create the Role
RESET ROLE;
CREATE ROLE client_mary_smith WITH LOGIN;

-- Grant Required Permissions
GRANT SELECT ON public.customer TO client_mary_smith;
GRANT SELECT ON public.rental TO client_mary_smith;
GRANT SELECT ON public.payment TO client_mary_smith;

--  Demonstration of Access
SET ROLE client_mary_smith;

SELECT * FROM public.customer WHERE first_name = 'MARY' AND last_name = 'SMITH';
SELECT * FROM public.rental;  -- Currently shows ALL rentals until RLS is applied
SELECT * FROM public.payment; -- Currently shows ALL payments until RLS is applied

RESET ROLE;

--Task 3. Implement row-level security
-- We check if the role exists before creating; for policies, we use DROP IF EXISTS
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'client_mary_smith') THEN
        CREATE ROLE client_mary_smith WITH LOGIN;
    END IF;
END $$;

-- Ensure permissions are set
GRANT SELECT ON public.customer, public.rental, public.payment TO client_mary_smith;

--  Enable RLS
ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;

-- Create Dynamic Policies
-- Instead of 'customer_id = 1', we extract the name from the role 'client_mary_smith'
-- and find the matching ID in the customer table.
DROP POLICY IF EXISTS mary_rental_policy ON rental;
CREATE POLICY mary_rental_policy ON rental
    FOR SELECT
    TO client_mary_smith
    USING (
        customer_id = (
            SELECT customer_id FROM public.customer 
            WHERE 'client_' || LOWER(first_name) || '_' || LOWER(last_name) = current_user
        )
    );

DROP POLICY IF EXISTS mary_payment_policy ON payment;
CREATE POLICY mary_payment_policy ON payment
    FOR SELECT
    TO client_mary_smith
    USING (
        customer_id = (
            SELECT customer_id FROM public.customer 
            WHERE 'client_' || LOWER(first_name) || '_' || LOWER(last_name) = current_user
        )
    );

-- Demonstrating Successful Access
SET ROLE client_mary_smith;
SELECT 'Successful Access' AS status, COUNT(*) FROM rental; -- Should show only Mary's rentals

-- Demonstrating Denied Access
-- This query attempts to find data for a different customer (e.g., ID 2).
-- Because of RLS, this must return 0 rows even if customer 2 has data.
SELECT 'Denied Access Test' AS status, * 
FROM rental 
WHERE customer_id = 2; 

RESET ROLE;







