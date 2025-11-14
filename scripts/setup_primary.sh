#!/bin/bash

# Setup Script for Primary Node (Node 1)
# This script sets up the primary PostgreSQL database node

set -e

echo "================================================"
echo "Setting up Primary Node (Node 1)"
echo "================================================"

# Configuration variables
DB_NAME="bookstore_db"
DB_USER="postgres"
PRIMARY_DATA_DIR="/var/lib/postgresql/data"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Step 1: Checking PostgreSQL installation..."
if ! command -v psql &> /dev/null; then
    echo "ERROR: PostgreSQL is not installed. Please install PostgreSQL first."
    exit 1
fi
echo "✓ PostgreSQL is installed"

echo ""
echo "Step 2: Creating database..."
# Create database if it doesn't exist
psql -U $DB_USER -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    psql -U $DB_USER -c "CREATE DATABASE $DB_NAME;"
echo "✓ Database '$DB_NAME' is ready"

echo ""
echo "Step 3: Configuring replication settings..."
echo "Please ensure the following settings are in postgresql.conf:"
echo "  - wal_level = replica"
echo "  - max_wal_senders = 3"
echo "  - max_replication_slots = 3"
echo "  - wal_keep_size = 1024"
echo ""
echo "And add replication authentication to pg_hba.conf:"
echo "  host    replication     replication_user    <replica_ip>/32    md5"
echo ""
read -p "Have you configured these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please configure the settings and run this script again."
    exit 1
fi

echo ""
echo "Step 4: Running primary node setup SQL..."
psql -U $DB_USER -d $DB_NAME -f "$SCRIPT_DIR/../node1_primary/setup_primary.sql"
echo "✓ Primary node setup completed"

echo ""
echo "Step 5: Verifying setup..."
psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as inventory_count FROM inventory;"

echo ""
echo "================================================"
echo "Primary Node Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Note down the primary server IP address"
echo "2. Restart PostgreSQL to apply configuration changes"
echo "3. Set up the replica node using setup_replica.sh"
echo ""
echo "To create a base backup for the replica, run:"
echo "pg_basebackup -h localhost -D /path/to/replica/data -U replication_user -v -P --wal-method=stream"
