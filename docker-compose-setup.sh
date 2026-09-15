#!/bin/bash

# Docker Compose Setup Script for Bookstore Replication
# This script helps set up the distributed bookstore database using Docker

set -e

echo "================================================"
echo "Docker-based Bookstore Database Setup"
echo "================================================"
echo ""

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✓ Docker and Docker Compose are installed"
echo ""

# Start the containers
echo "Step 1: Starting containers..."
docker-compose up -d postgres-primary

echo ""
echo "Waiting for primary database to be ready..."
sleep 10

echo ""
echo "Step 2: Setting up replication user on primary..."
docker exec -it bookstore-primary psql -U postgres -d bookstore_db -c "
    CREATE USER replication_user WITH REPLICATION ENCRYPTED PASSWORD 'replication_password';
    GRANT CONNECT ON DATABASE bookstore_db TO replication_user;
    SELECT pg_create_physical_replication_slot('replica_node_1_slot');
"

echo ""
echo "Step 3: Configuring pg_hba.conf for replication..."
docker exec -it bookstore-primary bash -c "
    echo 'host    replication     replication_user    all                md5' >> /var/lib/postgresql/data/pg_hba.conf
    psql -U postgres -c 'SELECT pg_reload_conf();'
"

echo ""
echo "Step 4: Starting replica node..."
# Stop replica if running
docker-compose stop postgres-replica || true
docker-compose rm -f postgres-replica || true

# Remove replica data volume
docker volume rm boockstore-db_replica_data || true

# Start replica with fresh setup
docker-compose up -d postgres-replica

echo ""
echo "Waiting for replica to initialize..."
sleep 5

echo ""
echo "Step 5: Creating base backup for replica..."
docker exec -it bookstore-replica bash -c "
    rm -rf /var/lib/postgresql/data/*
    PGPASSWORD='replication_password' pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replication_user -v -P --wal-method=stream -R
    chown -R postgres:postgres /var/lib/postgresql/data
"

echo ""
echo "Step 6: Restarting replica..."
docker-compose restart postgres-replica

echo ""
echo "Waiting for replica to start..."
sleep 10

echo ""
echo "Step 7: Verifying replication setup..."
echo ""
echo "Primary replication status:"
docker exec bookstore-primary psql -U postgres -d bookstore_db -c "SELECT * FROM pg_stat_replication;"

echo ""
echo "Replica status:"
docker exec bookstore-replica psql -U postgres -d bookstore_db -c "SELECT pg_is_in_recovery();"

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "Services running:"
echo "  - Primary Database: localhost:5432"
echo "  - Replica Database: localhost:5433"
echo "  - PgAdmin (optional): http://localhost:5050"
echo ""
echo "To connect to primary:"
echo "  docker exec -it bookstore-primary psql -U postgres -d bookstore_db"
echo ""
echo "To connect to replica:"
echo "  docker exec -it bookstore-replica psql -U postgres -d bookstore_db"
echo ""
echo "To test replication:"
echo "  docker exec -it bookstore-primary psql -U postgres -d bookstore_db -f /docker-entrypoint-initdb.d/test_replication.sql"
echo ""
echo "To stop all services:"
echo "  docker-compose down"
echo ""
