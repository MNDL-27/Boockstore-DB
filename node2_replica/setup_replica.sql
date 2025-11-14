-- Replica Node (Node 2) Setup Script
-- This script is used after the initial base backup from the primary node

-- The replica node is created using pg_basebackup, which creates an exact copy
-- of the primary node. After the base backup, this script can be used for
-- additional configuration.

-- Connect to the bookstore database on the replica
-- \c bookstore_db

-- Create a view to show replica status (for monitoring)
CREATE OR REPLACE VIEW replica_status AS
SELECT 
    NOW() AS current_time,
    pg_last_wal_receive_lsn() AS receive_lsn,
    pg_last_wal_replay_lsn() AS replay_lsn,
    pg_last_xact_replay_timestamp() AS last_replay_time,
    pg_is_in_recovery() AS is_in_recovery,
    pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()) AS replay_lag_bytes;

-- Create a function to check replication lag
CREATE OR REPLACE FUNCTION get_replication_lag()
RETURNS TABLE (
    lag_seconds NUMERIC,
    lag_bytes NUMERIC,
    is_replica BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(EPOCH FROM (NOW() - pg_last_xact_replay_timestamp()))::NUMERIC AS lag_seconds,
        pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn())::NUMERIC AS lag_bytes,
        pg_is_in_recovery() AS is_replica;
END;
$$ LANGUAGE plpgsql;

-- Display setup completion message
DO $$
BEGIN
    RAISE NOTICE 'Replica node configuration completed successfully!';
    RAISE NOTICE 'Node ID: 2 (Replica)';
    RAISE NOTICE 'Replica is in recovery mode and receiving updates from primary';
    RAISE NOTICE 'Use SELECT * FROM replica_status; to monitor replication health';
END $$;
