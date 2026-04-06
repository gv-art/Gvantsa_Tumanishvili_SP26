--DATABASE SETUP
-- 1. Creating the schema container
CREATE SCHEMA IF NOT EXISTS recruitment_agency_physical;
-- 2. Setting the search path so all following tables are created inside this schema
SET search_path TO recruitment_agency_physical;

/* DDL EXECUTION ORDER EXPLANATION:
In a relational database, "Parent" tables (Lookups, Participants, Companies) must be 
created before "Child" tables (Jobs, Applications, Interviews). 
It matters because Foreign Keys create a physical link to a Primary Key (PK) in another table. 
If the Parent table does not exist yet, the database cannot verify that the link is 
valid. 
If the sequence is wrong (e.g., creating 'Jobs' before 'Companies'), 
PostgreSQL will throw Error Code 42P01: "relation 'companies' does not exist."
*/

/*Creating Status_lookup table*/
CREATE TABLE Status_lookup (Status_ID SERIAL Primary key NOT NULL, 
							-- I chose SERIAL data type as it is standard for primary keys and automates unique ID generation.
							-- Choosing wrong data type, for example VARCHAR would make ID generation prone to duplicates and slower.
							-- The Primary Key is the most vital constraint; it ensures that every single row in your table is unique and identifiable. If it were not in the place we would not be able to identify each row uniquely.
							-- 
							Status_Name VARCHAR(50) NOT NULL,
							-- I chose VARCHAR(50) data type because It is standard practice for names and efficiently stores variable-length strings.
							-- Choosing wrong data type for example CHAR(50) would waste space. Choosing VARCHAR(5) would make it impossible to record long names.

							Category VARCHAR(50) NOT NULL); 
							-- I chose VARCHAR(50)to ensure usability and storage efficiency, It provides enough space for standard status categories without taking up large space..
							-- Choosing CHAR(50) would waste space on the disk. Choosing TEXT would allow inserting whole paragraphs in the field. 							
/*Constraints: 
Primary key (Status_ID) - is the most vital constraint; it ensures that every single row in your table is unique and identifiable.It prevents two 
different statuses from sharing the same identity. If it were missing we could accidentally insert "Active" multiple times. If an Orders table tried to link to an 
"Active" status, the database wouldn't know which version of "Active" to use, leading to logic errors in your application.
NOT NULL (All three tables) - This constraint forbids a column from being empty. It avoids incomplete data where essential information is missing. In Status_Name we 
could have a record that exists but has no name. A user looking at a status dropdown menu would see a blank line, making the system unusable. For Category we would 
lose the ability to group your data. If we ran a report to see all "Shipping" categories, any record with a NULL value would be skipped, leading to inaccurate business 
insights.*/


/*Creating Locations table*/
CREATE TABLE Locations (Locations_ID SERIAL Primary key NOT NULL, 
						-- I chose SERIAL data type as it is standard for primary keys and automates unique ID generation.
						-- Choosing any other data types(VARCHAR/INT) would not automate the generation process, and would require manual entry, resulting in slowing down process.

							City_name VARCHAR(100) NOT NULL, 
							-- I chose VARCHAR(100) to support long international names while saving disk space;
							-- Using CHAR(100) would waste storage with empty padding, while VARCHAR(10) would cause data truncation for longer names.

							Country VARCHAR(100) NOT NULL);
							-- VARCHAR(100) ensures usability for diverse country names.
							-- choosing TEXT would risk "data pollution" by allowing paragraphs, whereas a smaller limit would trigger "Value too long" errors.

/*Primary Key (Locations_ID) - The Primary Key is the unique fingerprint for every location in the database. It prevents the system from having two same location entries.
without it we could end up with ten different rows for "Paris," each with a different ID, or worse, multiple rows with the same ID. Because of which identification would be difficult.
NOT NULL (City_name and Country) -  prevents rows that exist but contain no actual geographical information. Without it we might have a location record In City_Name that belongs to 
a country but has no city. If a user tries to generate a shipping label, the "City" field would be blank, making the label useless. Without it in Country column we could have a city like 
"Springfield" without a country attached. Since there are dozens of Springfields globally, the data becomes functionally useless for filtering, sorting, and calculations. */

/*Creating Skills table*/
CREATE TABLE Skills (Skill_ID SERIAL Primary key NOT NULL,
					-- I chose SERIAL data type as it is standard for primary keys and automates unique ID generation.
					-- Choosing any other data types(VARCHAR/INT) would not automate the generation process, and would require manual entry, resulting in slowing down process.

							Skill_name VARCHAR(50) NOT NULL UNIQUE,
							-- I chose VARCHAR(50) to allow for diverse skill names while ensuring storage efficiency;
							-- Choosing CHAR(50) would waste disk space by padding shorter skills. Choosing VARCHAR(10) would cause "data truncation" for longer professional skills.

							Category VARCHAR(50));
							-- I chose VARCHAR(50) as it ensures taking up space efficiently. I think 50 characters is logical maximum limit for category variable.
							-- Choosing CHAR would waste space via padding for short categories. Choosing TEXT data type would allow long paragraphs.

/*PRIMARY KEY (Skill_ID) - It prevents the system from losing track of which skill is which when they are referenced by other tables. If we diin't have a Primary Key, 
we might have two rows for "Python." Even if they look the same, the database would treat them as unrelated objects.
UNIQUE (Skill_name) - It prevents the exact same skill name from being entered into the table twice under different IDs. Without UNIQUE, we could have ID 1 as "SQL" and ID 5 also as "SQL."
NOT NULL (Skill_name) - This ensures that every entry actually represents a skill. It prevents the creation of a record that has an ID but no name. without it our application 
might show a list of skills for a user, but it would just look like a series of empty bullet points.*/

/*Creating Services table*/
CREATE TABLE Services (Service_ID SERIAL Primary key NOT NULL,
						-- I chose SERIAL data type as it is standard for primary keys and automates unique ID generation.
						-- Choosing any other data types(VARCHAR/INT) would not automate the generation process, and would require manual entry, resulting in slowing down process.

							Service_name VARCHAR(100) NOT NULL UNIQUE,
							-- I chose VARCHAR(100) because service names can be descriptive and vary significantly in length. 100 characters provides a safe buffer for professional service titles without being excessively large.
							-- Choosing a limit that is too small would lead to "Data Truncation."Choosing CHAR would cause padding of short service names.

							Description TEXT);
							-- I chose the TEXT data type for the Description column because service details can vary greatly in length.
							-- Chossing VARCHAR(n) would impose character limit, while choosing optimal character limit is imposible for such variables, as service description can require 300 or even more characters and veries significantly.
							-- Also choosing CHAR(n) would not be efficient either as it is fixed-length and short descriptions would take as much space as 300 character-length description.

/*PRIMARY KEY (Service_ID) - It prevents the database from having two different service records that look distinct but share the same internal ID. Without it If we have 
multiple services without a Primary Key, other tables wouldn't be able to "point" to a specific service reliably.
UNIQUE (Service_name) - It prevents the creation of two separate IDs for the same service.  "Skills Testing" can't be entered twice with different IDs.
NOT NULL (Service_name) - It avoids incomplete service cataloging. The system tracks evolving processes. If a service record was created with a NULL name, you would have an ID in your "Service Usage" history that points to nothing.*/

/*Creating Companies table*/
CREATE TABLE Companies (Company_ID SERIAL Primary key NOT NULL,
						-- I chose SERIAL data type as it is standard for primary keys and automates unique ID generation.
						-- Choosing any other data types(VARCHAR/INT) would not automate the generation process, and would require manual entry, resulting in slowing down process.

						Company_name VARCHAR(100) NOT NULL UNIQUE,
						-- Selected VARCHAR(100) to accommodate long legal names while maintaining storage efficiency for shorter titles.
						-- Chooding CHAR(100) would result in padding. Choosing VARCHAR(20) imposes unsifficient character limit. Choosing TEXT would allow data pollution.

						Website_URL VARCHAR(255) NOT NULL UNIQUE);
						-- I chose VARCHAR(255) because URLs can be significantly longer than standard names . 255 characters is safe limit for web addresses.
						-- CHoosing shorter limit e.g VARCHAR(50) would lead to Data truncation.Choosing ChAR(255) would cause storage waste. Choosing TEXT would allow any length including massive blocks.

/*PRIMARY KEY (Company_ID) - It preventsidentity confusion during the hiring process. It prevents "Company A" and "Company B" from being mixed up in the database. 
Without a Primary Key, if we had two records for "TechCorp," a candidate's application might link to the wrong one. You could end up sending a candidate's resume to a company they never applied to, damaging your agency's professional reputation.
UNIQUE (Company_name and Website_URL) - It avoids duplicate client profiles. It stops two different recruiters from accidentally onboarding the same client twice. Without it if you have "Google" in the system twice with different IDs, our job postings will be split. 
we might see 5 jobs under one "Google" and 3 under another, making it impossible to see the hiring outcomes for the client as a whole.
As for Website_URL: Companies sometimes change their names (rebranding), but their URLs often stay the same or are unique markers. This prevents us from creating a "new" company profile for an existing client just because they tweaked their name slightly.
NOT NULL (Company_name and Website_URL) - It prevents records that exist but have no identifiable information. Without it we would have a job posting linked to a blank company. A candidate wouldn't know who they are applying to, and your agency wouldn't know who to 
bill for the placement. Also, In a recruitment agency, recruiters need to research the company to brief candidates. If the URL is missing, the recruiter loses a vital 
tool for the hiring process, leading to poorly prepared candidates and failed interviews.*/

/*creating Participant table*/
CREATE TABLE Participant (Participant_ID SERIAL Primary key NOT NULL,
						-- I chose SERIAL data type as it is standard for primary keys and automates unique ID generation.
						-- Choosing any other data types(VARCHAR/INT) would not automate the generation process, and would require manual entry, resulting in slowing down process.

							Name VARCHAR(50) NOT NULL,
							-- I chose VARCHAR(50) to provide a reasonable upper limit for individual names while maintaining storage efficiency.
							-- The primary risk is data truncation, where a limit that is too small forces the database to cut off or reject long entries. Conversely, using a fixed-length CHAR type causes internal padding, 
							--which wastes disk space by filling shorter names with empty characters.

							Surname VARCHAR(50) NOT NULL,
							-- VARCHAR(50) is the most practical choice because it handles the natural variability of names while preventing storage waste.
							-- Using a limit that is too restrictive, like VARCHAR(10), risks data truncation, where hyphenated or long international surnames are cut off. Conversely, choosing CHAR(50) leads to internal padding, 
							--wasting disk space by filling the remainder of every short name with empty characters.

							Email VARCHAR(255) NOT NULL UNIQUE,
							-- Choosing VARCHAR(255) for an Email column is the standard technical requirement because the official Internet standard (RFC 5321) defines the maximum length of an email address as 254 characters.
							-- Smaller limits reject valid emails; CHAR(255) causes inefficient internal padding.
							Phone_Number VARCHAR(20) UNIQUE);
							-- I chose VARCHAR(20) because it accommodates international formats and symbols (+, -, spaces) while preventing truncation.
							-- INT/BIGINT types lose leading zeros; CHAR(20) wastes space via internal padding.
/*PRIMARY KEY (Participant_ID) - It prevents the system from creating two different records that actually represent the same human being. Without a Primary Key, a candidate might apply for a job as "Gvantsa Tumanishvili" (ID 101) and later be hired as a company 
representative "Gvantsa Tumanishvili" (ID 505)."
UNIQUE (Email and Phone_Number) - It prevents duplicate profiles and "Double-Contacting." It prevents two recruiters from accidentally adding the same person to the database twice.
If two people have the same email, out automated "Interview Scheduled" alerts might go to the wrong person. Also, If UNIQUE is missing, we might have the same candidate listed multiple times.
NOT NULL (Name, Surname, Email)  - These ensure that every participant record is actually usable for a recruitment agency. It avoids Anonymous records. Without it there 
might be cases when It is impossible to contact to succesful candidates because their records are empty/null*/

--Following instructions I have added User_type column and its constraint to participant table*/
-- Adding the column with a DEFAULT value
ALTER TABLE Participant 
ADD COLUMN User_Type VARCHAR(20) NOT NULL DEFAULT 'Candidate';
--Addin the CHECK constraint (The "Specific Value" requirement)
ALTER TABLE Participant 
ADD CONSTRAINT check_user_type 
CHECK (User_Type IN ('Candidate', 'Employer', 'Staff'));

/*Applying GENERATED AS ALWAYS column following instructions given */
ALTER TABLE Participant 
ADD COLUMN Full_Name VARCHAR(101) 
GENERATED ALWAYS AS (Name || ' ' || Surname) STORED;

-- This ensures the 'Full_Name' is always consistent and updated 
-- automatically whenever a Name or Surname changes.

/*creating Jobs table*/
CREATE TABLE Jobs (Job_ID SERIAL PRIMARY KEY,
					-- I chose SERIAL data type as it is standard for primary keys and automates unique ID generation.
					-- Choosing any other data types(VARCHAR/INT) would not automate the generation process, and would require manual entry, resulting in slowing down process.

                    Company_ID INT NOT NULL REFERENCES Companies(Company_ID),
					-- I chose INT to match the primary key of the Companies table, ensuring referential integrity.
    				-- Without the REFERENCES constraint, "Orphaned Records" could occur, where a job exists for a non-existent company.

                    Job_title VARCHAR(100) NOT NULL,
					-- I chose VARCHAR(100) to provide a safe buffer for long, descriptive corporate titles.
    				-- A smaller limit would cause data truncation; CHAR(100) would waste space via internal padding.

                    Salary NUMERIC(12,2) NOT NULL CHECK (Salary >= 0),
					-- I chose NUMERIC for exact decimal precision. 
    				-- FLOAT would cause "Rounding Errors" in financial data; without the CHECK, a typo could result in a negative salary.

                    Status_ID INT NOT NULL REFERENCES Status_lookup(Status_ID));
					-- I chose the INT data type to represent the status as a numeric identifier rather than a text string. This is a standard practice for "Categorical Data" to ensure high performance and data integrity.
    				-- Using a free-text VARCHAR would lead to "Dirty Data," like having both 'Open' and 'Opened' in the system. Also VARCHAR would cause "Data Inconsistency" through typos and increase the storage overhead for every record.
/*Constraints:
PRIMARY KEY (Job_ID)- It avoids overlapping job postings. It ensures every unique role has one specific identity. Without a PK, we couldn't distinguish between two different "Software Engineer" roles at the same company.
FOREIGN KEY / REFERENCES (Company_ID & Status_ID) - It prevents a job from being created for a company that doesn't exist, or having a status that isn't defined in the 
lookup table. Without it A recruiter could accidentally assign a Job to Company_ID 999. If that company doesn't exist, the job posting is nothing, candidates apply to it, but there is no client to interview them or pay the agency's placement fee.
CHECK (Salary >= 0) - It avoids Logical impossibilities and typos. Without this, a simple typing error could result in a salary of -50,000. This would break the financial reporting and look highly unprofessional on a public-facing job board.
NOT NULL (All Columns) - It avoids Incomplete job advertisements. Without it A candidate sees a job with a salary and a company name, but doesn't know if they are applying to be the CEO or a Janitor. Also The system wouldn't know if the job 
is "Active" or "Filled," meaning old jobs might stay on the website forever, wasting recruiters' time.
*/


/*Creating candidates table*/
CREATE TABLE Candidates(Participant_ID INT PRIMARY KEY REFERENCES Participant(Participant_ID),
						-- I chose INT to maintain a 1:1 relationship with the Participant table.
    					-- RChoosing SERIAL would cause redundancy; lacking REFERENCES creates orphaned records.
						Resume_URL VARCHAR(255) NOT NULL);
						-- Chose VARCHAR(255) because it is Industry standard for long cloud-storage links.
    					-- choosing VARCHAR(50) causes truncation; CHAR(255) causes inefficient padding.

/*PRIMARY KEY (Participant_ID)  -By making the ID of a participant the Primary Key of the candidate table, we are enforcing a 1:1 relationship. It avoids Multiple candidate profiles for the same person.
Without this, you could have one Participant_ID linked to three different rows in the Candidates table, each with a different resume.
REFERENCES / FOREIGN KEY (Participant(Participant_ID)) - It prevents us from adding a resume for someone who isn't already registered in your main Participant table.
Without it we might have a resume, but you have no idea who it belongs to or how to contact them.
NOT NULL (Resume_URL) - This prevents Empty applications. It ensures that no one is classified as a candidate if they haven't actually provided their credentials.
Without it a recruiter might find a promising candidate profile in the system, but when they go to submit them for a job, the Resume_URL is blank.*/


/*Creating Service_Candidates (Service Usage) conjunction table*/
CREATE TABLE Service_Candidates (
    Usage_ID SERIAL PRIMARY KEY,
	-- I chose SERIAL data type as it is standard for primary keys and automates unique ID generation.
	-- Choosing any other data types(VARCHAR/INT) would not automate the generation process, and would require manual entry, resulting in slowing down process.

    Participant_ID INT NOT NULL REFERENCES Participant(Participant_ID),
	-- I chose INT to match the Parent table and ensure "Referential Integrity."
	-- RChoosing SERIAL would cause redundancy; lacking REFERENCES creates orphaned records.

    Service_ID INT NOT NULL REFERENCES Services(Service_ID),
	-- I chose INT for Foreign Keys to ensure every record points to a valid Participant and Service.
    -- Without REFERENCES, we risk "Orphaned Records" that link to non-existent data.

    Service_date TIMESTAMPTZ NOT NULL,
	-- I chose TIMESTAMPTZ to ensure "Time Zone Awareness" and prevent errors during daylight savings.
    -- A simple DATE lacks the necessary "Temporal Granularity" to track the exact time of service.

    Status_ID INT NOT NULL REFERENCES Status_lookup(Status_ID));
	-- I chose INT to enforce "Data Normalization" and prevent typos through a lookup table.
    -- VARCHAR leads to "Dirty Data" and inconsistent reporting (e.g., 'Active' vs 'active').

/*PRIMARY KEY (Usage_ID) - IT prevents record collision and loss of specific history. It ensures every single instance of a service being provided is a unique event.
Without a unique Usage_ID, we couldn't distinguish between a candidate receiving "Resume Advice" on Monday versus receiving it again on Friday.
FOREIGN KEYS / REFERENCES (Participant, Services, Status_lookup) - These constraints ensure that every log entry points to a real person, a real service, and a valid status.
Without it we'd be tracking a service provided to "nobody," which makes the service usage analytics inaccurate and the billing records impossible to verify.
NOT NULL (All Columns) -  it prevents half-finished logs where we know who got a service, but not what or when. Without it, we know a candidate was helped on Tuesday, but we don't know 
if they got "Coaching" or "Skills Testing." Also we would lose the ability to track the evolving process.
TIMESTAMPTZ (Service_date) - It prevents chronological confusion. If our agency has offices in different cities (like London and New York), using a standard timestamp without a zone could make 
it look like an interview happened before the prep coaching session simply because of the time difference.*/

/*Creating Company_Representatives table*/
CREATE TABLE Company_Representatives (Participant_ID INT REFERENCES Participant(Participant_ID),
										-- I chose INT to match the Parent table and ensure "Referential Integrity."
										-- RChoosing SERIAL would cause redundancy; lacking REFERENCES creates orphaned records.

										Company_ID INT REFERENCES Companies(Company_ID),
										-- I chose INT for both keys to ensure "Referential Integrity" with the parent tables.
    									-- Mismatched data types would prevent the tables from "Joining" correctly in queries.

										Role_title VARCHAR(100) NOT NULL,
										-- I chose VARCHAR(100) to allow for long professional titles without wasting space.
    									-- VARCHAR(20) is too restrictive; CHAR(100) causes unnecessary "Internal Padding."

										PRIMARY KEY (Participant_ID, Company_ID));

/*Constraints:
COMPOSITE PRIMARY KEY (Participant_ID, Company_ID) - It prevents the same person from being assigned as a representative for the same company more than once. This ensures that the link between a participant and a company is a unique,
FOREIGN KEYS / REFERENCES (Participant_ID & Company_ID) - It ensures we cannot link a representative to a person who doesn't exist in the Participant table, or to a company that doesn't exist in the Companies table.
Without these, our system would fill with "Orphaned Records" we'd have a representative role but no way to know who the person is or who they work for.
NOT NULL (Role_title) - It prevents having a participant linked to a company without knowing what they do.
Without it during a successful application, the agency needs to know which representative to contact to finalize the placement.*/


/*Creating Candidates_Jobs_Application table*/
CREATE TABLE Candidates_Jobs_Application(Participant_ID INT NOT NULL REFERENCES Participant(Participant_ID),
										-- I chose INT to match the Parent table and ensure "Referential Integrity."
										-- RChoosing SERIAL would cause redundancy; lacking REFERENCES creates orphaned records.

											Job_ID INT NOT NULL REFERENCES Jobs(Job_ID),
											-- I chose INT to maintain "Referential Integrity" with the Jobs table.
											-- SERIAL would create a "New ID" instead of linking to an existing job; VARCHAR would slow down "Join Operations" and reporting.
											Application_ID SERIAL NOT NULL PRIMARY KEY,
											--I chose SERIAL to automate tracking numbers for every application.
    										-- Manual entry leads to duplicate IDs; lack of a unique ID makes tracking specific submissions difficult.

											Applied_at TIMESTAMPTZ CHECK (Applied_at > '2000-01-01') NOT NULL,
											-- I chose TIMESTAMPTZ for "Time Zone Awareness" and precision.
    										-- DATE lacks granularity; TIMESTAMP (no zone) leads to "Time Ambiguity" in global systems.

											Status_ID INT NOT NULL REFERENCES Status_lookup(Status_ID));
											-- I chose INT to enforce "Data Normalization" for stages like 'Applied' or 'Interviewing'.
    										-- VARCHAR causes "Inconsistent Data" and slows down status-based filtering.

/*PRIMARY KEY (Application_ID) - It prevents the system from confusing two separate applications. Without a unique ID, we wouldn't have a reliable way to link interviews or feedback to a specific submission.
FOREIGN KEYS / REFERENCES (Participant, Jobs, Status_lookup) - These ensure that an application cannot exist unless it is tied to a real person, a real job posting, and a valid workflow status.
Without these a candidate could "apply" to Job_ID 999. If that job doesn't exist, their application is lost in digital limbo or we could have an application with no candidate attached.
NOT NULL (All Columns) - It avoids incomplete Submissions. Without it we lose the ability to sort by Newest Applications. Also, without it in status_ID the application would be in an "unknown" state.
I have added CHECK (Applied_at > '2000-01-01') to Applied_at column following instructions.*/



/*Creating Skills_Candidates Conjunction table*/
CREATE TABLE Skills_Candidates (Skill_ID INT NOT NULL REFERENCES Skills(Skill_ID),
								--I chose the INT data type for these columns to maintain "Data Type Compatibility" with the Primary Keys of the Skills and Participant tables.
								-- Using VARCHAR (e.g., storing the word 'Python') would lead to "Data Redundancy" and massive storage waste.
								
    							Participant_ID INT NOT NULL REFERENCES Participant(Participant_ID),
								-- I chose INT to ensure "Referential Integrity" and high-performance joins.
    							-- SERIAL would create "Data Mismatch"; lacking REFERENCES creates "Orphaned Data."

    							Acquired_At TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
								-- I chose TIMESTAMPTZ to automate record-keeping with "Global Time Accuracy."
    							-- DATE lacks the necessary "Precision" to track exact update times.

    							PRIMARY KEY (Skill_ID, Participant_ID));
								-- I chose a Composite Primary Key to prevent "Duplicate Skill Assignments."
    							-- A standalone SERIAL ID would allow "Redundant Rows" for the same skill/person pair.

/*COMPOSITE PRIMARY KEY (Skill_ID, Participant_ID) - this prevents duplicate skill tagging. Without this, we could have redundant rows for the same skill.
FOREIGN KEYS / REFERENCES (Skills & Participant) - It prevents a candidate from being linked to a skill that hasn't been defined, or a skill from being assigned to a participant who doesn't exist.
Without it a recruiter might try to tag a candidate with Skill_ID 99. If that ID doesn't exist, the candidate is effectively linked to a "mystery skill." When we run a report on "Candidates with Java Skills," 
this candidate would be invisible because the link is broken, leading to missed placement opportunities.
NOT NULL (Skill_ID, Participant_ID, Acquired_At) - This avoids Ghost competencies. If Skill_ID were NULL, we would know a participant learned something, but not what. 
This makes the record useless for matching candidates to job postings. If Acquired_At were missing, we couldn't track the evolving process or verify how recently 
a candidate updated their profile.
DEFAULT CURRENT_TIMESTAMP (Acquired_At) - this ensures the "history" is recorded even if the recruiter forgets to type in a date. In a fast-paced agency, users often 
skip non-mandatory fields. Without this default, we would have many skills with no "start date," making it impossible to see if a candidate's expertise is fresh or 
several years old.*/

/*Creating Application_status_history table*/
CREATE TABLE Application_Status_History (History_ID SERIAL PRIMARY KEY,
							-- I chose SERIAL to uniquely identify every event in the audit trail.
    						-- Risk: Manual INT entry would cause "Sequence Gaps" and duplicate ID errors.

    						Application_ID INT NOT NULL REFERENCES Candidates_Jobs_Application(Application_ID),
							--I chose the INT data type for Application_ID to maintain a direct relationship with the Candidates_Jobs_Application table.
							-- Using SERIAL here would incorrectly generate a "New ID" for the history event itself.

    						Status_ID INT NOT NULL REFERENCES Status_lookup(Status_ID),
							-- I chose INT for Foreign Keys to ensure "Data Type Compatibility" during joins.
    						-- Risk: SERIAL would incorrectly generate new IDs; lacking REFERENCES creates "Unverifiable History."

    						Changed_At TIMESTAMPTZ NOT NULL DEFAULT NOW());
							-- I chose TIMESTAMPTZ to automate "Time-Stamping" with global accuracy.
    						-- DATE lacks the necessary "Resolution" to order events occurring on the same day.

/*PRIMARY KEY (History_ID) - It prevents the system from confusing two different status changes that might happen in quick succession. Without a unique History_ID, 
we couldn't easily reference a specific moment in time
FOREIGN KEYS / REFERENCES (Application_ID & Status_ID) - It prevents logging a status change for an application that doesn't exist or assigning a status that isn't in your official Status_lookup.
Withoutu it if you log a status change for Application_ID 999 (which doesn't exist), we have "orphaned" history. we know something happened, but wedon't know who 
it happened to, making the audit trail useless for the agency. Also, If a bug allows a Status_ID that isn't in the lookup table, our "History Report" would show an 
empty space or an error instead of "Interview Scheduled."
NOT NULL (All Columns) - "it iavoids Broken Links in the timeline. If Changed_At or Status_ID were allowed to be NULL, the "evolving process" would have gaps. 
we might see that a candidate was "Hired," but we wouldn't know when it happened or what their previous stage was. This makes it impossible to calculate 
"Time-to-Hire" metrics, which are essential for recruitment agency performance.
DEFAULT NOW() (Changed_At) - This avoids human error and chronological gaps. If this weren't automated, the system would rely on the application code to send a 
timestamp. If the server clock is off or the code has a bug, we might have history logs appearing out of order. By using DEFAULT NOW(), the database itself guarantees 
that the moment a change is saved, the exact time is captured.*/

/*Creating Candidate_Preferred_Location table*/
CREATE TABLE Candidate_Preferred_Location (Participant_ID INT NOT NULL REFERENCES Participant(Participant_ID),
										--I chose the INT data type for these Foreign Keys to maintain "Referential Integrity" with the Participant and Locations tables.
										-- Using VARCHAR to store the city name (e.g., 'London') directly would lead to "Data Redundancy" and "Storage Inefficiency."

    									Locations_ID INT NOT NULL REFERENCES Locations(Locations_ID),
										--I chose INT to ensure "Data Type Compatibility" and high-speed table joins.
    									-- SERIAL would cause "Identity Mismatch"; lacking REFERENCES creates "Unverifiable Data."
										
    									Date_Added TIMESTAMPTZ NOT NULL DEFAULT NOW(),
										-- I chose TIMESTAMPTZ to automate "Audit Logging" with global time accuracy.
    									-- DATE lacks the precision needed to track real-time profile updates.

   				 						PRIMARY KEY (Participant_ID, Locations_ID));
										-- I chose a Composite Primary Key to prevent "Redundant Preference Records."
    									-- A standalone SERIAL ID would allow the same location to be saved twice for one user.

/*COMPOSITE PRIMARY KEY (Participant_ID, Locations_ID) - It prevents the database from storing "Gvantsa Tumanishvili wants to work in London" three different times.
Without this, our search results would be "noisy." If a recruiter searches for candidates in London, Gvantsa Tumanishvili would appear multiple times in the list.
FOREIGN KEYS / REFERENCES (Participant & Locations) - It prevents a candidate from being linked to a location ID that doesn't exist, or a preference being assigned to 
a participant who isn't in our records. Without this a recruiter might try to tag a candidate with Locations_ID 500. If that ID doesn't exist in your Locations table, that candidate is effectively "lost" to the system.*/
/*Creating Candidate_experience table
NOT NULL (All Columns) - It prevents incomplete profiles. Without this If Locations_ID were NULL, we would know a candidate has a location preference, but we wouldn't 
know where.
DEFAULT NOW() (Date_Added) - It automates the history of the candidate's profile. Without this, recruiters would have to manually enter the date they talked to the candidate about relocation.*/

CREATE TABLE Candidate_Experience (Experience_ID SERIAL PRIMARY KEY,
						-- I chose SERIAL to uniquely track each individual job entry for a candidate.
    					-- Manual INT entry leads to duplicate ID errors and "Data Entry Overhead."

    					Participant_ID INT NOT NULL REFERENCES Participant(Participant_ID),
						-- I chose INT to ensure "Referential Integrity" with the candidate's profile.
    					-- Using SERIAL would break the link to the original Participant; 
    					-- lacking REFERENCES creates "Orphaned Data."

    					Job_title VARCHAR(100) NOT NULL,
						-- I chose VARCHAR(100) for "Storage Efficiency" with long titles.
    					-- VARCHAR(20) is too restrictive; CHAR(100) causes "Internal Padding" (wasted space).
						
    					Start_date DATE NOT NULL,
						-- I chose the DATE data type because professional experience is almost always measured in days, months, and years.
						-- Choosing wrong data type would result in Data pollution(VARCHAR / TEXT), Over-engineering(TIMESTAMPTZ) or data loss(INT (Year Only).
    					End_date DATE);
						-- I chose DATE because work history only requires "Day-Level Precision."
    					-- TIMESTAMPTZ is "Over-Engineering" and increases "Storage Overhead" unnecessarily.

/*PRIMARY KEY (Experience_ID) - It prevents the database from confusing a candidate's current role with their previous one. Without a unique Experience_ID, we couldn't distinguish between two separate stints at the same company
FOREIGN KEY / REFERENCES (Participant_ID) - It prevents entering job history for a participant who doesn't exist in our Participant table.we might have a brilliant 
"Senior Developer" experience entry in the database, but if the Participant_ID points to nothing, we have no name, no email, and no way to contact the person who has that experience.
NOT NULL (Job_title and Start_date) - This prevents incomplete profiles. Without this a recruiter sees that a candidate worked at "Google" for 5 years, but the title is blank.
we lose the ability to calculate Years of Experience.
DATE (Start_date and End_date) - It prevents the database from trying to track the exact second someone started a job 10 years ago. By using DATE instead of TIMESTAMPTZ,
 we avoid "Time Zone Ambiguity." If a candidate started a job on January 1st in Tokyo, it shouldn't show up as December 31st just because a recruiter is viewing it in New York.*/


 /*Inserting example values in tables*/
 /*Status_lookup table*/
 INSERT INTO Status_lookup (Status_ID, Status_Name, Category) VALUES
(1, 'Submitted', 'Application'),
(2, 'Reviewing', 'Application'), -- Added to support your sample data logic
(3, 'Interviewing', 'Application'),
(4, 'Open', 'Job'),
(5, 'Closed', 'Job'),
(6, 'Scheduled', 'Interview'),
(7, 'Completed', 'Interview')
ON CONFLICT (Status_ID) DO NOTHING;

/*Locations table*/
INSERT INTO Locations (Locations_ID, City_name, Country) VALUES
(1, 'Tbilisi', 'Georgia'),
(2, 'Kutaisi', 'Georgia'),
(3, 'Batumi', 'Georgia')
ON CONFLICT (Locations_ID) DO NOTHING;

/*Skills table*/
INSERT INTO Skills (Skill_ID, Skill_name, Category) VALUES
(1, 'Python', 'Technical'),
(2, 'SQL', 'Technical'),
(3, 'Project Management', 'Soft Skill')
ON CONFLICT (Skill_ID) DO NOTHING;

/*Services table*/
INSERT INTO Services (Service_ID, Service_name, Description) VALUES
(10, 'Resume Advice', 'Professional review and tailoring of a candidate''s CV.'),
(12, 'Career Coaching', '1-on-1 sessions focusing on interview techniques.'),
(15, 'Skills Testing', 'Standardized technical or soft-skill assessments.')
ON CONFLICT (Service_ID) DO NOTHING;

/*Companies table*/
INSERT INTO Companies (Company_ID, Company_name, Website_URL) VALUES
(500, 'TechNova Solutions', 'https://technova.io'),
(501, 'Global Logistics Co.', 'https://globallogistics.com'),
(502, 'GreenTree Finance', 'https://greentree.ge')
ON CONFLICT (Company_ID) DO NOTHING;

/*Participant table*/
INSERT INTO Participant (Participant_ID, Name, Surname, Email, Phone_Number) VALUES
(101, 'Nino', 'Moseshvili', 'Nino.Mose@gmail.com', '+995555111222'),
(102, 'Mariami', 'Khachidze', 'Mariam@gmail.com', '+995555333444'),
(103, 'Giorgi', 'Zhordania', 'Giorgi.Zhordania@gmail.com', '+995555555666'),
(104, 'Lasha', 'Representative', 'lasha.rep@technova.io', '+995555777888'),
(105, 'Anano', 'Lead', 'anano.lead@technova.io', '+995555999000')
ON CONFLICT (Participant_ID) DO NOTHING;

/*Candidates table*/
INSERT INTO Candidates (Participant_ID, Resume_URL) VALUES
(101, 'https://storage.agency/resumes/nino_m.pdf'),
(102, 'https://storage.agency/resumes/mariami_k.pdf'),
(103, 'https://storage.agency/resumes/giorgi_z.pdf')
ON CONFLICT (Participant_ID) DO NOTHING;

/*Company_Representatives table*/
INSERT INTO Company_Representatives (Participant_ID, Company_ID, Role_title) VALUES
(104, 500, 'HR Manager'),
(105, 500, 'Senior Technical Lead'),
(104, 501, 'External Consultant')
ON CONFLICT (Participant_ID, Company_ID) DO NOTHING;

/*Jobs table*/
INSERT INTO Jobs (Job_ID, Company_ID, Job_title, Salary, Status_ID) VALUES
(700, 500, 'Senior Python Developer', 8500, 4),
(701, 501, 'Logistics Coordinator', 43880, 4),
(702, 500, 'UI/UX Designer', 54900, 5)
ON CONFLICT (Job_ID) DO NOTHING;

/*Service_candidates table*/
INSERT INTO Service_Candidates (Usage_ID, Participant_ID, Service_ID, Service_date, Status_ID) VALUES
(1, 101, 10, '2026-03-01 10:00:00', 5),
(2, 102, 12, '2026-03-05 15:30:00', 5),
(3, 101, 15, '2026-03-10 09:15:00', 6)
ON CONFLICT (Usage_ID) DO NOTHING;

/*Candidates_Jobs_Application table*/
INSERT INTO Candidates_Jobs_Application (Application_ID, Participant_ID, Job_ID, Applied_at, Status_ID) VALUES
(1001, 101, 700, '2026-03-20 10:00:00', 1),
(1002, 102, 700, '2026-03-21 14:30:00', 2),
(1003, 101, 702, '2026-03-22 09:00:00', 1)
ON CONFLICT (Application_ID) DO NOTHING;

/*Application_Status_History table*/
INSERT INTO Application_Status_History (History_ID, Application_ID, Status_ID, Changed_At) VALUES
(1, 1001, 1, '2026-03-01 09:00:00'),
(2, 1001, 3, '2026-03-05 14:20:00'),
(3, 1003, 1, '2026-03-06 10:15:00')
ON CONFLICT (History_ID) DO NOTHING;

/*Interview table*/
INSERT INTO Interview (Interview_ID, Application_ID, Participant_ID, Scheduled_date, Feedback_Notes, Status_ID) VALUES
(201, 1001, 104, '2026-04-01 10:00:00', 'Great technical skills, culture fit.', 6),
(202, 1001, 105, '2026-04-03 14:00:00', 'Needs to improve SQL knowledge.', 7),
(203, 1002, 104, '2026-04-05 11:30:00', NULL, 6)
ON CONFLICT (Interview_ID) DO NOTHING;

/*skills_Candidates table*/
INSERT INTO Skills_Candidates (Skill_ID, Participant_ID, Acquired_At) VALUES
(1, 101, '2026-01-15 09:00:00'),
(2, 101, '2026-01-15 09:00:00'),
(3, 102, '2026-02-10 14:30:00')
ON CONFLICT (Skill_ID, Participant_ID) DO NOTHING;

/*Candidate_Preferred_Location table*/
INSERT INTO Candidate_Preferred_Location (Participant_ID, Locations_ID, Date_Added) VALUES
(101, 1, '2026-03-20 11:00:00'),
(101, 3, '2026-03-21 09:30:00'),
(102, 1, '2026-03-22 14:15:00')
ON CONFLICT (Participant_ID, Locations_ID) DO NOTHING;

/*Candidate_Experience table*/
INSERT INTO Candidate_Experience (Experience_ID, Participant_ID, Job_title, Start_date, End_date) VALUES
(1, 101, 'Junior Developer', '2022-01-01', '2023-12-31'),
(2, 101, 'Mid-Level Developer', '2024-01-01', NULL),
(3, 102, 'Marketing Intern', '2023-06-15', '2023-09-15')
ON CONFLICT (Experience_ID) DO NOTHING;


-- Adding a NOT NULL 'record_ts' field to each table using ALTER TABLE following instructions.
ALTER TABLE Status_lookup ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Locations ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Skills ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Services ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Companies ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Participant ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Jobs ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Candidates ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Service_Candidates ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Company_Representatives ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Candidates_Jobs_Application ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Skills_Candidates ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Candidate_Preferred_Location ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Application_Status_History ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Interview ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE Candidate_Experience ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;


























