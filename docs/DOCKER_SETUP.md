# Docker Setup Guide

## Quick Start with Docker

This guide explains how to quickly set up the distributed bookstore database using Docker Compose.

### Prerequisites

- Docker Engine 20.10 or higher
- Docker Compose 2.0 or higher
- At least 2GB of free disk space

### 1. Start the System

```bash
# Make the setup script executable
chmod +x docker-compose-setup.sh

# Run the automated setup
./docker-compose-setup.sh
```

Alternatively, manual setup:

```bash
# Start containers
docker-compose up -d

# Wait for containers to be ready
sleep 10

# Configure replication manually (see script for commands)
```

### 2. Access the Databases

**Primary Database:**
```bash
docker exec -it bookstore-primary psql -U postgres -d bookstore_db
```

**Replica Database:**
```bash
docker exec -it bookstore-replica psql -U postgres -d bookstore_db
```

**PgAdmin (Web UI):**
- URL: http://localhost:5050
- Email: admin@bookstore.com
- Password: admin

Add servers in PgAdmin:
- Primary: bookstore-primary:5432
- Replica: bookstore-replica:5432

### 3. Test Replication

```bash
# On primary, add a test record
docker exec -it bookstore-primary psql -U postgres -d bookstore_db -c \
  "INSERT INTO inventory (isbn, book_title, author, publisher, publication_year, quantity_available, price, node_id) 
   VALUES ('9780135957059', 'The Pragmatic Programmer', 'David Thomas', 'Addison-Wesley', 2019, 25, 44.99, 1);"

# Wait a moment, then check on replica
docker exec -it bookstore-replica psql -U postgres -d bookstore_db -c \
  "SELECT * FROM inventory WHERE isbn = '9780135957059';"
```

### 4. Monitor Replication

**Check replication status on primary:**
```bash
docker exec -it bookstore-primary psql -U postgres -d bookstore_db -c \
  "SELECT application_name, state, sync_state FROM pg_stat_replication;"
```

**Check replica status:**
```bash
docker exec -it bookstore-replica psql -U postgres -d bookstore_db -c \
  "SELECT pg_is_in_recovery();"
```

### 5. Stop the System

```bash
# Stop all containers
docker-compose down

# Remove volumes (data will be lost)
docker-compose down -v
```

## Troubleshooting

### Containers Won't Start

```bash
# Check logs
docker-compose logs postgres-primary
docker-compose logs postgres-replica

# Restart services
docker-compose restart
```

### Replication Not Working

```bash
# Check primary configuration
docker exec bookstore-primary cat /var/lib/postgresql/data/pg_hba.conf

# Check replica configuration
docker exec bookstore-replica cat /var/lib/postgresql/data/postgresql.auto.conf

# Restart replica
docker-compose restart postgres-replica
```

### Reset Everything

```bash
# Stop and remove everything
docker-compose down -v

# Start fresh
./docker-compose-setup.sh
```

## Configuration Files

The Docker setup uses:
- `docker-compose.yml` - Service definitions
- `schema/inventory_table.sql` - Loaded automatically on primary
- Configuration from `config/` directory

## Advantages of Docker Setup

✅ Quick setup (< 5 minutes)
✅ No PostgreSQL installation required
✅ Isolated environment
✅ Easy cleanup
✅ Reproducible setup
✅ Good for testing and learning

## Production Considerations

⚠️ This Docker setup is for **development and testing only**

For production:
- Use persistent volumes with backup
- Configure proper networking
- Set strong passwords
- Use secrets management
- Monitor with proper tools
- Configure resource limits
- Set up automatic failover
- Implement backup strategy

## Next Steps

After successful Docker setup:
1. Explore the database schema
2. Test replication with sample data
3. Try the monitoring scripts
4. Understand the architecture
5. Plan your production deployment
