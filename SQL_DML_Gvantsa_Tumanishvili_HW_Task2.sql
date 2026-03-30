/*task1. Creating table*/
CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;

/*task2: Checking the "Before" size of the table.*/
SELECT *, pg_size_pretty(total_bytes) AS total,
          pg_size_pretty(index_bytes) AS INDEX,
          pg_size_pretty(toast_bytes) AS toast,
          pg_size_pretty(table_bytes) AS TABLE
FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
       FROM (SELECT c.oid,nspname AS table_schema,
                      relname AS TABLE_NAME,
                     c.reltuples AS row_estimate,
                     pg_total_relation_size(c.oid) AS total_bytes,
                     pg_indexes_size(c.oid) AS index_bytes,
                     pg_total_relation_size(reltoastrelid) AS toast_bytes
             FROM pg_class c
             LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE relkind = 'r'
             ) a
     ) a
WHERE table_name LIKE '%table_to_delete%';

/*task3: running the DELETE operation code*/
DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;
/*task3 a) Query complete 00:00:18.325*/
/*running the following size check code again*/
SELECT *, pg_size_pretty(total_bytes) AS total,
          pg_size_pretty(index_bytes) AS INDEX,
          pg_size_pretty(toast_bytes) AS toast,
          pg_size_pretty(table_bytes) AS TABLE
FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
       FROM (SELECT c.oid,nspname AS table_schema,
                      relname AS TABLE_NAME,
                     c.reltuples AS row_estimate,
                     pg_total_relation_size(c.oid) AS total_bytes,
                     pg_indexes_size(c.oid) AS index_bytes,
                     pg_total_relation_size(reltoastrelid) AS toast_bytes
             FROM pg_class c
             LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE relkind = 'r'
             ) a
     ) a
WHERE table_name LIKE '%table_to_delete%';
/*task3 b) result is that table consumes 575MB both before and after DELETE*/
/*task3 c) running the following command:*/
VACUUM FULL VERBOSE table_to_delete;
/*task3 d) size check: result: It takes 383MB now after that command*/
/*task3 e) recreating 'table_to_delete' table*/
DROP TABLE IF EXISTS table_to_delete;

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;

/*task4. Issue the following TRUNCATE operation:*/ 
TRUNCATE table_to_delete;
/*task4 a) It takes 744 msec to perform this TRUNCALE*/
/*task4 b) time comparison
DELETE: Took 18.325 seconds to remove 1/3 of the data.
TRUNCATE: Took only 744 msec (0.74 seconds) to remove all 10 million rows.
Conclusion: TRUNCATE is significantly faster because it is a DDL (Data Definition Language) command. It doesn't scan individual rows or log each deletion; 
it simply deallocates the data pages.*/
/*task4 c)Checking space consumption: result shows that space consumption of the table after TRUNCALE is 0 bytes.
The TRUNCATE operation instantly reduced the table size to 0 bytes of data, whereas the DELETE operation left it at 575 MB. This is because TRUNCATE is a DDL
command that deallocates all storage pages at once, while DELETE only marks individual rows as "dead". Consequently, TRUNCATE is thousands of 
times faster and reclaims disk space immediately without requiring a VACUUM FULL command.*/

/*task5 a)Space consumption before and after operation table:
Operation	        Total Table Size
Initial Table	    575 MB
After DELETE	    575 MB
After VACUUM FULL	383 MB
After TRUNCATE	    0 bytes     */

/*task5 b) comparing DELETE and TRUNCALE
Execution Time (DELETE): Slow. It scans every row one by one to check if it matches your WHERE clause. For 10M rows, this takes seconds.
Execution Time (TRUNCALE): Instant. It doesn't look at the data at all; it just tells the file system to empty the table's storage container.
Disk Space Usage (DELETE): High. It leaves "dead tuples" (holes) in the table. The file size on your hard drive stays the same until a VACUUM is run.
Disk Space Usage (TRUNCALE): Zero. It deallocates all data pages immediately. The file size drops to 8 KB (the minimum) right away.
Transaction Behavior (DELETE): DML (Data Manipulation). It generates individual log entries for every single row deleted, which is why it's resource-heavy.
Transaction Behavior (TRUNCALE): DDL (Data Definition). It is a structural change. It locks the entire table so no one else can use it while it's resetting.
Rollback Possibility (DELETE): Easy. Because it logs every row, you can undo a DELETE if you are inside a transaction (ROLLBACK).
Rollback Possibility (TRUNCALE): Difficult/No. In many databases, it is permanent. In Postgres, it can be rolled back if in a transaction, but it's much riskier.*/

/*task5 c) Explanations:
Initially, the table occupied 575 MB. After a DELETE operation, the size remained 575 MB because PostgreSQL uses MVCC, marking rows as "dead" (bloat) rather than 
erasing them to allow concurrent access. Running VACUUM FULL reclaimed this space by physically rewriting the table, shrinking it to 383 MB. In contrast, the 
TRUNCATE operation was nearly instantaneous (milliseconds vs. seconds) and immediately reduced the table size to 0 bytes (8 KB). This is because TRUNCATE is a DDL 
command that deallocates all data pages at once without the row-by-row logging overhead of DELETE. While DELETE is a DML operation that supports precise filtering 
and easy rollbacks, it causes fragmentation; TRUNCATE is the superior choice for performance and storage when a total table reset is required.*/









