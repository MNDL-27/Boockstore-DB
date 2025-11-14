#!/bin/bash

# Setup Script for Replica Node (Node 2)
# This script sets up the replica PostgreSQL database node

set -e

echo "================================================"
echo "Setting up Replica Node (Node 2)"
echo "================================================"

# Configuration variables
DB_NAME="bookstore_db"
PRIMARY_HOST="<primary_host_ip>"  # Replace with actual primary host IP
REPLICATION_USER="replication_user"
REPLICA_DATA_DIR="/var/lib/postgresql/replica_data"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Step 1: Checking PostgreSQL installation..."
if ! command -v psql &> /dev/null; then
    echo "ERROR: PostgreSQL is not installed. Please install PostgreSQL first."
    exit 1
fi
echo "✓ PostgreSQL is installed"

echo ""
echo "Step 2: Configuration check..."
echo "Primary host: $PRIMARY_HOST"
echo "Replica data directory: $REPLICA_DATA_DIR"
echo ""
read -p "Is this configuration correct? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please edit this script with correct configuration."
    exit 1
fi

echo ""
echo "Step 3: Stopping PostgreSQL (if running)..."
# This command may vary based on your system
sudo systemctl stop postgresql || echo "PostgreSQL was not running"

echo ""
echo "Step 4: Creating base backup from primary..."
echo "This will create a complete copy of the primary database"
echo ""
# Remove existing data directory if it exists
if [ -d "$REPLICA_DATA_DIR" ]; then
    read -p "Data directory exists. Remove it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -rf "$REPLICA_DATA_DIR"
    else
        echo "Cannot proceed with existing data directory."
        exit 1
    fi
fi

# Create base backup
pg_basebackup -h $PRIMARY_HOST -D $REPLICA_DATA_DIR -U $REPLICATION_USER -v -P --wal-method=stream -R

echo "✓ Base backup completed"

echo ""
echo "Step 5: Configuring replica..."
# The -R flag in pg_basebackup creates standby.signal and appropriate configuration
# Additional configuration can be added to postgresql.auto.conf

echo ""
echo "Step 6: Setting up standby mode..."
# For PostgreSQL 12+, standby.signal file indicates standby mode
touch "$REPLICA_DATA_DIR/standby.signal"
echo "✓ Standby signal created"

echo ""
echo "Step 7: Starting replica..."
# This command may vary based on your system
sudo systemctl start postgresql
echo "✓ PostgreSQL started in replica mode"

echo ""
echo "Step 8: Verifying replication..."
sleep 5
psql -h localhost -U postgres -d $DB_NAME -c "SELECT pg_is_in_recovery();"

echo ""
echo "================================================"
echo "Replica Node Setup Complete!"
echo "================================================"
echo ""
echo "The replica is now receiving updates from the primary."
echo ""
echo "To monitor replication status, run:"
echo "  psql -d $DB_NAME -c 'SELECT * FROM replica_status;'"
echo ""
echo "To check replication lag:"
echo "  psql -d $DB_NAME -c 'SELECT * FROM get_replication_lag();'"
