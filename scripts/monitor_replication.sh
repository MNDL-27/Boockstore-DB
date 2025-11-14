#!/bin/bash

# Monitoring Script for Replication Health
# This script checks the health of the replication setup

set -e

DB_NAME="bookstore_db"
DB_USER="postgres"

echo "================================================"
echo "Replication Health Monitor"
echo "================================================"
echo ""

# Check if we're on primary or replica
IS_PRIMARY=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT NOT pg_is_in_recovery();" | tr -d ' ')

if [ "$IS_PRIMARY" = "t" ]; then
    echo "Node Type: PRIMARY"
    echo ""
    echo "Replication Status:"
    echo "-------------------"
    psql -U $DB_USER -d $DB_NAME -c "
        SELECT 
            application_name,
            client_addr,
            state,
            sync_state,
            pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) as replication_lag
        FROM pg_stat_replication;
    "
    
    echo ""
    echo "Replication Slots:"
    echo "------------------"
    psql -U $DB_USER -d $DB_NAME -c "
        SELECT 
            slot_name,
            slot_type,
            active,
            pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) as retained_wal
        FROM pg_replication_slots;
    "
else
    echo "Node Type: REPLICA"
    echo ""
    echo "Replication Status:"
    echo "-------------------"
    psql -U $DB_USER -d $DB_NAME -c "
        SELECT 
            pg_is_in_recovery() as is_replica,
            pg_last_wal_receive_lsn() as receive_lsn,
            pg_last_wal_replay_lsn() as replay_lsn,
            pg_size_pretty(pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn())) as replay_lag,
            pg_last_xact_replay_timestamp() as last_replay_time,
            NOW() - pg_last_xact_replay_timestamp() as replication_delay;
    "
fi

echo ""
echo "Inventory Statistics:"
echo "---------------------"
psql -U $DB_USER -d $DB_NAME -c "
    SELECT 
        COUNT(*) as total_books,
        SUM(quantity_available) as total_quantity,
        ROUND(AVG(price), 2) as avg_price,
        MAX(last_updated) as last_update
    FROM inventory;
"

echo ""
echo "Recent Inventory Changes (Last 5):"
echo "-----------------------------------"
psql -U $DB_USER -d $DB_NAME -c "
    SELECT 
        book_title,
        author,
        quantity_available,
        last_updated
    FROM inventory
    ORDER BY last_updated DESC
    LIMIT 5;
"

echo ""
echo "================================================"
echo "Health Check Complete"
echo "================================================"
