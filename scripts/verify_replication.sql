-- Verify Replication Script
-- This script verifies that changes from the primary have been replicated
-- Run this on the REPLICA node after running test_replication.sql on primary

-- Run this on the REPLICA node
\echo 'Verifying Replication - Run on REPLICA Node'
\echo '============================================'
\echo ''

-- Verify this is a replica
\echo 'Checking node type:'
SELECT 
    CASE 
        WHEN pg_is_in_recovery() THEN 'REPLICA (Read-Only)'
        ELSE 'PRIMARY (Read-Write)'
    END as node_type;

\echo ''
\echo 'Current inventory count:'
SELECT COUNT(*) as total_books FROM inventory;

\echo ''
\echo 'Looking for the newly added book (Effective Java):'
SELECT book_title, author, quantity_available, price, last_updated
FROM inventory 
WHERE isbn = '9780134685991';

\echo ''
\echo 'Checking updated quantity for 1984:'
SELECT book_title, quantity_available, last_updated
FROM inventory 
WHERE isbn = '9780451524935';

\echo ''
\echo 'Verifying deletion (Crime and Punishment should not exist):'
SELECT COUNT(*) as should_be_zero
FROM inventory 
WHERE isbn = '9780141182605';

\echo ''
\echo 'Replication lag information:'
SELECT 
    EXTRACT(EPOCH FROM (NOW() - pg_last_xact_replay_timestamp())) as lag_seconds,
    pg_size_pretty(pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn())) as replay_lag
FROM (SELECT 1) as dummy;

\echo ''
\echo '============================================'
\echo 'Verification complete!'
\echo 'If you see the new book and updated quantities, replication is working correctly.'
\echo '============================================'
