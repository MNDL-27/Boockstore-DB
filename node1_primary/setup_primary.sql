-- Primary Node (Node 1) Setup Script
-- This script configures the primary database node for the bookstore system

-- Create the bookstore database
-- Note: This command should be run as a superuser before connecting to the database
-- CREATE DATABASE bookstore_db;

-- Connect to the bookstore database
-- \c bookstore_db

-- Enable replication settings
-- These settings are typically configured in postgresql.conf, but shown here for reference
-- wal_level = replica
-- max_wal_senders = 3
-- max_replication_slots = 3
-- hot_standby = on

-- Create replication user (should be run by a superuser)
-- This user will be used by the replica node to connect and receive WAL data
CREATE USER replication_user WITH REPLICATION ENCRYPTED PASSWORD 'replication_password';

-- Grant necessary privileges
GRANT CONNECT ON DATABASE bookstore_db TO replication_user;

-- Create replication slot for the replica node
-- Replication slots ensure that the primary node retains WAL files
-- until they have been received by all replicas
SELECT * FROM pg_create_physical_replication_slot('replica_node_1_slot');

-- Load the inventory table schema
\i ../schema/inventory_table.sql

-- Create a view to show replication status (for monitoring)
CREATE OR REPLACE VIEW replication_status AS
SELECT 
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replication_lag_bytes
FROM pg_stat_replication;

-- Grant access to monitoring views
GRANT SELECT ON replication_status TO replication_user;

-- Display setup completion message
DO $$
BEGIN
    RAISE NOTICE 'Primary node setup completed successfully!';
    RAISE NOTICE 'Node ID: 1 (Primary)';
    RAISE NOTICE 'Replication user: replication_user';
    RAISE NOTICE 'Replication slot: replica_node_1_slot';
END $$;
