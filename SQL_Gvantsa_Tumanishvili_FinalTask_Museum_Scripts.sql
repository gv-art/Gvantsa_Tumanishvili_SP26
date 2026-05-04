CREATE SCHEMA IF NOT EXISTS collection_management;
SET search_path TO collection_management;

--Task 3:Create a physical database with a separate database and schema and give it an appropriate domain-related name

CREATE TABLE storage_facilities (
    facility_id SERIAL PRIMARY KEY,
    facility_name VARCHAR(150) NOT NULL,
    physical_address TEXT
);

CREATE TABLE locations(
	location_id SERIAL PRIMARY KEY,
	facility_id INT NOT NULL REFERENCES storage_facilities(facility_id),
	room_number VARCHAR(50) NOT NULL
);

CREATE TABLE items (
    item_id SERIAL PRIMARY KEY,
    item_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    location_id INT REFERENCES locations(location_id)
);

CREATE TABLE artifacts (
    item_id INT PRIMARY KEY REFERENCES items(item_id),
    excavation_site VARCHAR(255),
    culture_origin VARCHAR(100),
    material_composition VARCHAR(150)
);

CREATE TABLE specimens (
    item_id INT PRIMARY KEY REFERENCES items(item_id),
    scientific_name VARCHAR(255) NOT NULL,
    taxon_group VARCHAR(100),
    collection_site TEXT
);

CREATE TABLE historical_objects (
    item_id INT PRIMARY KEY REFERENCES items(item_id),
    associated_person VARCHAR(255),
    associated_event VARCHAR(255),
    date_range VARCHAR(100),
    provenance_summary TEXT
);

CREATE TABLE artworks (
    item_id INT PRIMARY KEY REFERENCES items(item_id),
    artist_name VARCHAR(255),
    dimensions VARCHAR(100),
    style_period VARCHAR(100),
    display_label TEXT GENERATED ALWAYS AS (artist_name || ' (' || style_period || ')') STORED
);

CREATE TABLE people (
    person_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(201) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED
);

CREATE TABLE employees (
    person_id INT PRIMARY KEY REFERENCES people(person_id),
    job_title VARCHAR(100) NOT NULL,
    hire_date DATE DEFAULT CURRENT_DATE,
    salary NUMERIC(12,2)
);

CREATE TABLE visitors (
    person_id INT PRIMARY KEY REFERENCES people(person_id),
    membership_level VARCHAR(50),
    last_visit DATE DEFAULT CURRENT_DATE
);

CREATE TABLE exhibitions (
    exhibition_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    curator_id INT REFERENCES employees(person_id),
    start_date DATE,
    end_date DATE
);

CREATE TABLE exhibition_items (
    exhibition_id INT REFERENCES exhibitions(exhibition_id),
    item_id INT REFERENCES items(item_id),
    PRIMARY KEY (exhibition_id, item_id)
);

-- 1. 
ALTER TABLE exhibitions 
ADD CONSTRAINT CK_exhibition_start_future 
CHECK (start_date > '2026-01-01');

-- 2. 
ALTER TABLE exhibitions 
ADD CONSTRAINT CK_exhibition_date_consistency 
CHECK (end_date >= start_date);

--3. 
ALTER TABLE employees 
ADD CONSTRAINT CK_employee_salary_positive 
CHECK (salary > 0);

--4. 
ALTER TABLE items 
ADD CONSTRAINT CK_item_type_valid 
CHECK (item_type IN ('Artwork', 'Artifact', 'Specimen', 'Historical Object'));

--5. 
ALTER TABLE visitors 
ADD CONSTRAINT CK_visitor_membership_tier
CHECK (membership_level IN ('Standard', 'Silver', 'Gold', 'VIP'));

/*comments on constraints and data type selection:
storage_facilities
Data Types: SERIAL is used for the PK to automate unique ID generation; VARCHAR(150) ensures facility names have a reasonable length, while TEXT allows for long, detailed addresses.
Constraints: NOT NULL on facility_name ensures every facility is identifiable.

locations
Data Types: INT for facility_id matches the parent table for efficient joining; VARCHAR(50) provides flexibility for room numbers like "A-101" or "Vault 4".
Constraints: NOT NULL on facility_id and room_number maintains referential and structural integrity.

items
Data Types: VARCHAR(50) for item_type and VARCHAR(255) for title offer high-performance storage for critical descriptive data.
Constraints: CK_item_type_valid limits inputs to the four specific museum categories, preventing data entry errors.

artworks
Data Types: VARCHAR(100) for dimensions and period allows for standard descriptive strings; TEXT is used for the display label to accommodate long, concatenated strings.
Constraints: GENERATED ALWAYS AS ... STORED automates the creation of the display_label, ensuring formatting remains consistent without manual input.

artifacts, specimens, & historical_objects
Data Types: VARCHAR and TEXT fields (like scientific_name and provenance_summary) were chosen to support various lengths of professional and scientific data.
Constraints: PRIMARY KEY REFERENCES items(item_id) ensures these tables function as strict 1:1 extensions of the parent items table.

people
Data Types: VARCHAR(255) for email follows standard web length protocols.
Constraints: UNIQUE on email prevents duplicate registrations; GENERATED ALWAYS AS for full_name ensures the museum's contact list is always standardized.

employees
Data Types: NUMERIC(12,2) provides high precision for financial data without rounding errors.
Constraints: DEFAULT CURRENT_DATE automates record-keeping for new hires; CK_employee_salary_positive ensures payroll data is logically sound (must be > 0).

visitors
Data Types: DATE is the most efficient type for tracking visit history.
Constraints: CK_visitor_membership_tier enforces specific membership levels, facilitating standardized marketing and access control.

exhibitions
Data Types: TEXT for description allows curators to write full paragraphs about the exhibition's theme.
Constraints: CK_exhibition_start_future ensures exhibitions are scheduled correctly for the 2026 season; CK_exhibition_date_logic prevents end dates from being scheduled before start dates.

exhibition_items
Data Types: Standard INT types match the PKs of the related tables for maximum join performance.
Constraints: A composite PRIMARY KEY ensures that the same item cannot be double-counted within a single exhibition.
*/


--TASK 4
-- Populate storage_facilities
INSERT INTO storage_facilities (facility_name, physical_address) VALUES
('Main Vault', '123 Museum Way'),
('South Wing Archive', '456 History Lane'),
('Offsite Climate-Control', '789 Secure Rd'),
('Restoration Lab', '101 Art Blvd'),
('Deep Storage A', '202 Cold St'),
('Exhibition Hall C Storage', '303 Display Ave');


-- populate people table:
INSERT INTO people (first_name, last_name, email) VALUES
('Alice', 'Smith', 'alice.smith@museum.org'),
('Bob', 'Jones', 'bob.jones@museum.org'),
('Charlie', 'Brown', 'charlie.b@gmail.com'),
('Diana', 'Prince', 'diana.p@museum.org'),
('Edward', 'Norton', 'ed.norton@yahoo.com'),
('Fiona', 'Gallagher', 'fiona.g@museum.org');

-- Populate locations
INSERT INTO locations (facility_id, room_number) VALUES
((SELECT facility_id FROM storage_facilities WHERE facility_name = 'Main Vault'), 'Room 101'),
((SELECT facility_id FROM storage_facilities WHERE facility_name = 'Main Vault'), 'Room 102'),
((SELECT facility_id FROM storage_facilities WHERE facility_name = 'South Wing Archive'), 'A-12'),
((SELECT facility_id FROM storage_facilities WHERE facility_name = 'South Wing Archive'), 'B-04'),
((SELECT facility_id FROM storage_facilities WHERE facility_name = 'Offsite Climate-Control'), 'Vault-9'),
((SELECT facility_id FROM storage_facilities WHERE facility_name = 'Restoration Lab'), 'Station 4');

-- Populate employees
INSERT INTO employees (person_id, job_title, hire_date, salary) VALUES
((SELECT person_id FROM people WHERE email = 'alice.smith@museum.org'), 'Head Curator', '2026-02-15', 85000),
((SELECT person_id FROM people WHERE email = 'bob.jones@museum.org'), 'Archivist', '2026-03-01', 55000),
((SELECT person_id FROM people WHERE email = 'diana.p@museum.org'), 'Security Lead', DEFAULT, 60000),
((SELECT person_id FROM people WHERE email = 'fiona.g@museum.org'), 'Restoration Tech', '2026-04-10', 52000),
((SELECT person_id FROM people WHERE email = 'charlie.b@gmail.com'), 'Junior Docent', '2026-03-20', 35000),
((SELECT person_id FROM people WHERE email = 'ed.norton@yahoo.com'), 'Night Guard', '2026-02-01', 40000);

-- Populate visitors 
INSERT INTO visitors (person_id, membership_level, last_visit) VALUES
((SELECT person_id FROM people WHERE email = 'charlie.b@gmail.com'), 'Gold', '2026-03-25'),
((SELECT person_id FROM people WHERE email = 'ed.norton@yahoo.com'), 'Standard', DEFAULT),
((SELECT person_id FROM people WHERE email = 'alice.smith@museum.org'), 'VIP', '2026-04-01'),
((SELECT person_id FROM people WHERE email = 'bob.jones@museum.org'), 'Silver', '2026-02-28'),
((SELECT person_id FROM people WHERE email = 'diana.p@museum.org'), 'Gold', '2026-04-15'),
((SELECT person_id FROM people WHERE email = 'fiona.g@museum.org'), 'Standard', '2026-03-12');

-- Populate items
-- Populate the parent 'items' table first
INSERT INTO items (item_type, title, location_id) VALUES
('Artwork', 'The Starry Night Replica', (SELECT location_id FROM locations WHERE room_number = 'Room 101')),
('Artifact', 'Ancient Roman Coin', (SELECT location_id FROM locations WHERE room_number = 'A-12')),
('Specimen', 'Prehistoric Fern Fossil', (SELECT location_id FROM locations WHERE room_number = 'Vault-9')),
('Historical Object', 'Napoleon’s Letter', (SELECT location_id FROM locations WHERE room_number = 'Room 102')),
('Artwork', 'Modern Sculpture #4', (SELECT location_id FROM locations WHERE room_number = 'Station 4')),
('Artifact', 'Egyptian Amulet', (SELECT location_id FROM locations WHERE room_number = 'B-04')),
('Artwork', 'Guernica Study', (SELECT location_id FROM locations WHERE room_number = 'Room 101')),
('Artwork', 'The Thinker (Small Cast)', (SELECT location_id FROM locations WHERE room_number = 'Station 4')),
('Artwork', 'Sunflowers Replica', (SELECT location_id FROM locations WHERE room_number = 'Room 101')),
('Artwork', 'Abstract Blue', (SELECT location_id FROM locations WHERE room_number = 'Station 4')),
('Artifact', 'Mayan Jade Mask', (SELECT location_id FROM locations WHERE room_number = 'A-12')),
('Artifact', 'Greek Amphora', (SELECT location_id FROM locations WHERE room_number = 'B-04')),
('Artifact', 'Viking Brooch', (SELECT location_id FROM locations WHERE room_number = 'A-12')),
('Artifact', 'Ming Dynasty Vase', (SELECT location_id FROM locations WHERE room_number = 'B-04')),
('Specimen', 'Ammonite Shell', (SELECT location_id FROM locations WHERE room_number = 'Vault-9')),
('Specimen', 'Trilobite Fossil', (SELECT location_id FROM locations WHERE room_number = 'Vault-9')),
('Specimen', 'Desert Rose Crystal', (SELECT location_id FROM locations WHERE room_number = 'Vault-9')),
('Specimen', 'Meteorite Fragment', (SELECT location_id FROM locations WHERE room_number = 'Vault-9')),
('Specimen', 'Obsidian Blade', (SELECT location_id FROM locations WHERE room_number = 'Vault-9')),
('Historical Object', 'WWII Enigma Machine', (SELECT location_id FROM locations WHERE room_number = 'Room 102')),
('Historical Object', 'Suffragette Banner', (SELECT location_id FROM locations WHERE room_number = 'Room 102')),
('Historical Object', 'Apollo 11 Flight Suit', (SELECT location_id FROM locations WHERE room_number = 'Room 102')),
('Historical Object', 'Lincoln’s Top Hat', (SELECT location_id FROM locations WHERE room_number = 'Room 102')),
('Historical Object', 'Victorian Medical Kit', (SELECT location_id FROM locations WHERE room_number = 'Room 102'));

-- Populate artworks
INSERT INTO artworks (item_id, artist_name, dimensions, style_period) VALUES
((SELECT item_id FROM items WHERE title = 'The Starry Night Replica' AND item_type = 'Artwork' LIMIT 1), 'Vincent van Gogh', '73 x 92 cm', 'Post-Impressionism'),
((SELECT item_id FROM items WHERE title = 'Modern Sculpture #4' AND item_type = 'Artwork' LIMIT 1), 'Jane Doe', '2m x 1m', 'Contemporary'),
((SELECT item_id FROM items WHERE title = 'Guernica Study' AND item_type = 'Artwork' LIMIT 1), 'Pablo Picasso', '27 x 60 cm', 'Cubism'),
((SELECT item_id FROM items WHERE title = 'The Thinker (Small Cast)' AND item_type = 'Artwork' LIMIT 1), 'Auguste Rodin', '70 cm height', 'Impressionist Sculpture'),
((SELECT item_id FROM items WHERE title = 'Sunflowers Replica' AND item_type = 'Artwork' LIMIT 1), 'Vincent van Gogh', '95 x 73 cm', 'Post-Impressionism'),
((SELECT item_id FROM items WHERE title = 'Abstract Blue' AND item_type = 'Artwork' LIMIT 1), 'Mark Rothko', '150 x 120 cm', 'Color Field');

-- populate artifacts
INSERT INTO artifacts (item_id, excavation_site, culture_origin, material_composition) VALUES
((SELECT item_id FROM items WHERE title = 'Ancient Roman Coin' AND item_type = 'Artifact' LIMIT 1), 'Rome, Italy', 'Roman Empire', 'Bronze'),
((SELECT item_id FROM items WHERE title = 'Egyptian Amulet' AND item_type = 'Artifact' LIMIT 1), 'Giza Plateau', 'Old Kingdom Egypt', 'Lapis Lazuli'),
((SELECT item_id FROM items WHERE title = 'Mayan Jade Mask' AND item_type = 'Artifact' LIMIT 1), 'Chichen Itza', 'Mayan', 'Jadeite'),
((SELECT item_id FROM items WHERE title = 'Greek Amphora' AND item_type = 'Artifact' LIMIT 1), 'Athens', 'Classical Greek', 'Ceramic'),
((SELECT item_id FROM items WHERE title = 'Viking Brooch' AND item_type = 'Artifact' LIMIT 1), 'Birka, Sweden', 'Norse', 'Silver'),
((SELECT item_id FROM items WHERE title = 'Ming Dynasty Vase' AND item_type = 'Artifact' LIMIT 1), 'Jingdezhen', 'Ming Dynasty', 'Porcelain');

-- populate specimens
INSERT INTO specimens (item_id, scientific_name, taxon_group, collection_site) VALUES
((SELECT item_id FROM items WHERE title = 'Prehistoric Fern Fossil' AND item_type = 'Specimen' LIMIT 1), 'Pecopteris arborescens', 'Plantae', 'Coal Measures, UK'),
((SELECT item_id FROM items WHERE title = 'Ammonite Shell' AND item_type = 'Specimen' LIMIT 1), 'Asteroceras obtusum', 'Cephalopoda', 'Lyme Regis, Dorset'),
((SELECT item_id FROM items WHERE title = 'Trilobite Fossil' AND item_type = 'Specimen' LIMIT 1), 'Elrathia kingii', 'Arthropoda', 'Wheeler Shale, Utah'),
((SELECT item_id FROM items WHERE title = 'Desert Rose Crystal' AND item_type = 'Specimen' LIMIT 1), 'Gypsum selenite', 'Mineral', 'Sahara Desert, Morocco'),
((SELECT item_id FROM items WHERE title = 'Meteorite Fragment' AND item_type = 'Specimen' LIMIT 1), 'Iron-nickel meteorite', 'Celestial', 'Barringer Crater, Arizona'),
((SELECT item_id FROM items WHERE title = 'Obsidian Blade' AND item_type = 'Specimen' LIMIT 1), 'Volcanic Glass', 'Mineraloid', 'Yellowstone Region, USA');

-- populate historical_objects
INSERT INTO historical_objects (item_id, associated_person, associated_event, date_range, provenance_summary) VALUES
((SELECT item_id FROM items WHERE title = 'Napoleon’s Letter' AND item_type = 'Historical Object' LIMIT 1), 'Napoleon Bonaparte', 'Napoleonic Wars', '1804-1815', 'Gift from France.'),
((SELECT item_id FROM items WHERE title = 'WWII Enigma Machine' AND item_type = 'Historical Object' LIMIT 1), 'Alan Turing', 'World War II', '1939-1945', 'Recovered from naval vessel.'),
((SELECT item_id FROM items WHERE title = 'Suffragette Banner' AND item_type = 'Historical Object' LIMIT 1), 'Emmeline Pankhurst', 'Suffrage Movement', '1910-1918', 'Donated by Estate.'),
((SELECT item_id FROM items WHERE title = 'Apollo 11 Flight Suit' AND item_type = 'Historical Object' LIMIT 1), 'Neil Armstrong', 'Moon Landing', '1969', 'On loan from NASA.'),
((SELECT item_id FROM items WHERE title = 'Lincoln’s Top Hat' AND item_type = 'Historical Object' LIMIT 1), 'Abraham Lincoln', 'Civil War Era', '1860-1865', 'Purchased at auction.'),
((SELECT item_id FROM items WHERE title = 'Victorian Medical Kit' AND item_type = 'Historical Object' LIMIT 1), 'Joseph Lister', 'Antiseptic Revolution', '1870-1890', 'From London Hospital.');

-- populate exhibitions:
INSERT INTO exhibitions (title, description, curator_id, start_date, end_date) VALUES
('Renaissance Masterpieces', 'A collection of 15th-century Italian art.', (SELECT person_id FROM people WHERE email = 'alice.smith@museum.org'), '2026-02-15', '2026-05-15'),
('The Digital Era', 'Exploring the intersection of technology and sculpture.', (SELECT person_id FROM people WHERE email = 'alice.smith@museum.org'), '2026-04-01', '2026-07-01'),
('Currency of Empires', 'How coins shaped ancient trade.', (SELECT person_id FROM people WHERE email = 'bob.jones@museum.org'), '2026-02-10', '2026-05-10'),
('The Fossil Record', 'Dinosaurs and prehistoric flora.', (SELECT person_id FROM people WHERE email = 'fiona.g@museum.org'), '2026-03-10', '2026-06-10'),
('Echoes of War', 'Artifacts and letters from major conflicts.', (SELECT person_id FROM people WHERE email = 'bob.jones@museum.org'), '2026-03-20', '2026-04-30'),
('Modern Minimalism', 'Focusing on form and color.', (SELECT person_id FROM people WHERE email = 'alice.smith@museum.org'), '2026-04-25', '2026-08-25');

-- populate exhibition_items:
INSERT INTO exhibition_items (exhibition_id, item_id) VALUES
((SELECT exhibition_id FROM exhibitions WHERE title = 'Renaissance Masterpieces' LIMIT 1), 
 (SELECT item_id FROM items WHERE title = 'The Starry Night Replica' LIMIT 1)),
((SELECT exhibition_id FROM exhibitions WHERE title = 'Currency of Empires' LIMIT 1), 
 (SELECT item_id FROM items WHERE title = 'Ancient Roman Coin' LIMIT 1)),
((SELECT exhibition_id FROM exhibitions WHERE title = 'The Fossil Record' LIMIT 1), 
 (SELECT item_id FROM items WHERE title = 'Prehistoric Fern Fossil' LIMIT 1)),
((SELECT exhibition_id FROM exhibitions WHERE title = 'Echoes of War' LIMIT 1), 
 (SELECT item_id FROM items WHERE title = 'Napoleon’s Letter' LIMIT 1)),
((SELECT exhibition_id FROM exhibitions WHERE title = 'The Digital Era' LIMIT 1), 
 (SELECT item_id FROM items WHERE title = 'Modern Sculpture #4' LIMIT 1)),
((SELECT exhibition_id FROM exhibitions WHERE title = 'Renaissance Masterpieces' LIMIT 1), 
 (SELECT item_id FROM items WHERE title = 'Guernica Study' LIMIT 1)),
((SELECT exhibition_id FROM exhibitions WHERE title = 'Currency of Empires' LIMIT 1), 
 (SELECT item_id FROM items WHERE title = 'Egyptian Amulet' LIMIT 1));


-- Task 5.1
CREATE OR REPLACE FUNCTION update_item_data(
    p_item_id INT, 
    p_column_name TEXT, 
    p_new_value TEXT
) 
RETURNS TEXT AS $$
BEGIN
    EXECUTE format(
        'UPDATE collection_management.items SET %I = %L WHERE item_id = %s', 
        p_column_name, p_new_value, p_item_id
    );

    RETURN 'Item ' || p_item_id || ' updated successfully: ' || p_column_name || ' set to ' || p_new_value;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error updating item: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Task 5.2
CREATE OR REPLACE FUNCTION add_exhibition_item_transaction(
    p_exhibition_title TEXT,
    p_item_title TEXT
) 
RETURNS TEXT AS $$
DECLARE
    v_ex_id INT;
    v_it_id INT;
BEGIN
    -- 1. Look up the Exhibition ID using the Natural Key (Title)
    SELECT exhibition_id INTO v_ex_id 
    FROM collection_management.exhibitions 
    WHERE title = p_exhibition_title;

    -- 2. Look up the Item ID using the Natural Key (Title)
    SELECT item_id INTO v_it_id 
    FROM collection_management.items 
    WHERE title = p_item_title;

    -- 3. Validation: Ensure both entities exist
    IF v_ex_id IS NULL THEN
        RAISE EXCEPTION 'Exhibition "%" not found.', p_exhibition_title;
    END IF;
    
    IF v_it_id IS NULL THEN
        RAISE EXCEPTION 'Item "%" not found.', p_item_title;
    END IF;

    -- 4. Perform the "Transaction" (Insertion)
    INSERT INTO collection_management.exhibition_items (exhibition_id, item_id)
    VALUES (v_ex_id, v_it_id);

    -- 5. Confirm success
    RETURN 'Transaction Successful: "' || p_item_title || '" has been added to the "' || p_exhibition_title || '" exhibition.';

EXCEPTION
    WHEN unique_violation THEN
        RETURN 'Error: This item is already assigned to this exhibition.';
    WHEN OTHERS THEN
        RETURN 'Error processing transaction: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Task 6:
CREATE OR REPLACE VIEW recent_quarter_analytics AS
SELECT DISTINCT
    i.item_type,
    i.title AS item_name,
    sf.facility_name,
    l.room_number,
    -- Combining sub-type details into a single descriptive column
    COALESCE(a.artist_name, s.scientific_name, h.associated_person, 'Unknown') AS contributor_or_source,
    -- Fetching specific context based on the item type
    COALESCE(a.style_period, s.taxon_group, h.associated_event, 'N/A') AS contextual_category
FROM collection_management.items i
LEFT JOIN collection_management.locations l ON i.location_id = l.location_id
LEFT JOIN collection_management.storage_facilities sf ON l.facility_id = sf.facility_id
LEFT JOIN collection_management.artworks a ON i.item_id = a.item_id
LEFT JOIN collection_management.specimens s ON i.item_id = s.item_id
LEFT JOIN collection_management.historical_objects h ON i.item_id = h.item_id
WHERE 
    i.item_id IN (
        SELECT item_id FROM collection_management.items 
    )
ORDER BY i.item_type, i.title;

--Task 7:
-- 1. Create the role with login capabilities
-- In a real environment, use a strong password and a secure vault
CREATE ROLE museum_manager WITH LOGIN PASSWORD 'SecureManagerPass2026!';

-- 2. Grant usage on the schema
-- The manager needs USAGE permission just to see the schema exists
GRANT USAGE ON SCHEMA collection_management TO museum_manager;

-- 3. Grant SELECT on all existing tables
-- This fulfills the read-only requirement for current data
GRANT SELECT ON ALL TABLES IN SCHEMA collection_management TO museum_manager;

-- 4. Grant SELECT on future tables
-- Best practice: ensures that new items/exhibitions added later are also visible
ALTER DEFAULT PRIVILEGES IN SCHEMA collection_management 
GRANT SELECT ON TABLES TO museum_manager;

-- 5. Grant SELECT on views
-- Necessary so the manager can actually see the Analytics View I created earlier
GRANT SELECT ON ALL SEQUENCES IN SCHEMA collection_management TO museum_manager;




























