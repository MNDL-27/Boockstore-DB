-- Test Script for Replication
-- This script tests the replication by making changes on the primary
-- and verifying they appear on the replica

-- Run this on the PRIMARY node
\echo 'Testing Replication - Run on PRIMARY Node'
\echo '=========================================='
\echo ''

-- Show current inventory count
\echo 'Current inventory count:'
SELECT COUNT(*) as total_books FROM inventory;

\echo ''
\echo 'Adding a new book to inventory...'
INSERT INTO inventory (isbn, book_title, author, publisher, publication_year, quantity_available, price, node_id)
VALUES ('9780134685991', 'Effective Java', 'Joshua Bloch', 'Addison-Wesley', 2018, 15, 49.99, 1);

\echo ''
\echo 'New inventory count:'
SELECT COUNT(*) as total_books FROM inventory;

\echo ''
\echo 'Updating quantity for an existing book...'
UPDATE inventory SET quantity_available = quantity_available + 10 
WHERE isbn = '9780451524935';

\echo ''
\echo 'Updated book details:'
SELECT book_title, quantity_available, last_updated 
FROM inventory 
WHERE isbn = '9780451524935';

\echo ''
\echo 'Deleting a book from inventory...'
DELETE FROM inventory WHERE isbn = '9780141182605';

\echo ''
\echo 'Final inventory count:'
SELECT COUNT(*) as total_books FROM inventory;

\echo ''
\echo '=========================================='
\echo 'Primary changes complete!'
\echo 'Wait a few seconds, then run verify_replication.sql on the REPLICA'
\echo '=========================================='
