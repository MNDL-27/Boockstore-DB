# Distributed Bookstore Database - Setup Guide

## Prerequisites

- PostgreSQL 12 or higher installed on both servers
- Network connectivity between nodes
- Sufficient disk space on both nodes
- Root or PostgreSQL superuser access

## Quick Start

### 1. Primary Node Setup

```bash
# Navigate to the scripts directory
cd scripts/

# Make scripts executable
chmod +x *.sh

# Run primary setup script
./setup_primary.sh
```

### 2. Configure PostgreSQL Settings

On the **primary node**, edit `postgresql.conf`:

```bash
# Add these settings to postgresql.conf
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3
wal_keep_size = 1024
```

Edit `pg_hba.conf` to allow replication connections:

```bash
# Add this line (replace <replica_ip> with actual IP)
host    replication     replication_user    <replica_ip>/32    md5
```

Restart PostgreSQL:

```bash
sudo systemctl restart postgresql
```

### 3. Replica Node Setup

On the **replica node**, stop PostgreSQL and create base backup:

```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Create base backup from primary
pg_basebackup -h <primary_ip> -D /var/lib/postgresql/data \
  -U replication_user -v -P --wal-method=stream -R

# Start PostgreSQL
sudo systemctl start postgresql
```

### 4. Verify Replication

On the **primary node**:

```bash
psql -d bookstore_db -c "SELECT * FROM pg_stat_replication;"
```

On the **replica node**:

```bash
psql -d bookstore_db -c "SELECT pg_is_in_recovery();"
```

## Detailed Setup Instructions

### Primary Node Configuration

#### Step 1: Install PostgreSQL

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib

# CentOS/RHEL
sudo yum install postgresql-server postgresql-contrib
sudo postgresql-setup initdb
```

#### Step 2: Configure PostgreSQL

Copy configuration files:

```bash
# Copy primary configuration
cp config/postgresql_primary.conf /etc/postgresql/*/main/conf.d/
cp config/pg_hba_primary.conf /etc/postgresql/*/main/pg_hba.conf
```

Or manually add settings to existing files:

```bash
# Edit postgresql.conf
sudo nano /etc/postgresql/*/main/postgresql.conf

# Add replication settings
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3
wal_keep_size = 1024
listen_addresses = '*'
```

#### Step 3: Create Database and Schema

```bash
# Connect to PostgreSQL
sudo -u postgres psql

# Create database
CREATE DATABASE bookstore_db;

# Connect to database
\c bookstore_db

# Run setup script
\i /path/to/node1_primary/setup_primary.sql
```

#### Step 4: Verify Primary Setup

```bash
# Check replication slots
psql -d bookstore_db -c "SELECT * FROM pg_replication_slots;"

# Check inventory table
psql -d bookstore_db -c "SELECT COUNT(*) FROM inventory;"
```

### Replica Node Configuration

#### Step 1: Prepare Replica Server

```bash
# Install PostgreSQL (same version as primary)
sudo apt install postgresql postgresql-contrib

# Stop PostgreSQL
sudo systemctl stop postgresql
```

#### Step 2: Create Base Backup

```bash
# Remove existing data directory
sudo rm -rf /var/lib/postgresql/*/main/*

# Create base backup from primary
pg_basebackup -h <primary_ip> -D /var/lib/postgresql/*/main \
  -U replication_user -v -P --wal-method=stream -R

# Set ownership
sudo chown -R postgres:postgres /var/lib/postgresql/*/main
```

#### Step 3: Configure Replica Settings

The `-R` flag in pg_basebackup creates the necessary configuration automatically. To customize:

```bash
# Edit postgresql.auto.conf or postgresql.conf
sudo nano /var/lib/postgresql/*/main/postgresql.auto.conf

# Add/modify these settings
primary_conninfo = 'host=<primary_ip> port=5432 user=replication_user password=replication_password'
primary_slot_name = 'replica_node_1_slot'
hot_standby = on
```

#### Step 4: Start Replica

```bash
# Start PostgreSQL
sudo systemctl start postgresql

# Verify replica is running
sudo systemctl status postgresql

# Check if in recovery mode
psql -d bookstore_db -c "SELECT pg_is_in_recovery();"
```

## Testing Replication

### Test 1: Basic Replication Test

On **primary**:

```bash
psql -d bookstore_db -f scripts/test_replication.sql
```

Wait a few seconds, then on **replica**:

```bash
psql -d bookstore_db -f scripts/verify_replication.sql
```

### Test 2: Monitor Replication Health

Run the monitoring script:

```bash
./scripts/monitor_replication.sh
```

### Test 3: Measure Replication Lag

On **primary**:

```bash
psql -d bookstore_db -c "
  SELECT 
    client_addr,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) as lag
  FROM pg_stat_replication;"
```

On **replica**:

```bash
psql -d bookstore_db -c "
  SELECT 
    EXTRACT(EPOCH FROM (NOW() - pg_last_xact_replay_timestamp())) as lag_seconds;"
```

## Troubleshooting

### Replication Not Starting

**Problem**: Replica doesn't connect to primary

**Solutions**:
1. Check network connectivity: `ping <primary_ip>`
2. Verify pg_hba.conf allows replication connections
3. Check replication user password
4. Review PostgreSQL logs: `tail -f /var/log/postgresql/postgresql-*.log`

### High Replication Lag

**Problem**: Replica is far behind primary

**Solutions**:
1. Check network bandwidth
2. Increase `wal_keep_size` on primary
3. Monitor disk I/O on replica
4. Consider hardware upgrade

### Connection Refused

**Problem**: Cannot connect to database

**Solutions**:
1. Verify PostgreSQL is running: `sudo systemctl status postgresql`
2. Check listen_addresses in postgresql.conf
3. Verify firewall rules: `sudo ufw status`
4. Check pg_hba.conf authentication settings

### Replication Slot Full

**Problem**: WAL files accumulating on primary

**Solutions**:
1. Check if replica is running and connected
2. Drop and recreate replication slot if necessary:
   ```sql
   SELECT pg_drop_replication_slot('replica_node_1_slot');
   SELECT pg_create_physical_replication_slot('replica_node_1_slot');
   ```

## Maintenance Tasks

### Regular Backups

```bash
# Create backup of primary
pg_basebackup -h localhost -D /backup/primary_backup \
  -U postgres -v -P --wal-method=stream

# Or use pg_dump for logical backup
pg_dump -U postgres bookstore_db > bookstore_backup.sql
```

### Monitoring Replication

Set up a cron job to run monitoring script:

```bash
# Add to crontab
*/5 * * * * /path/to/scripts/monitor_replication.sh >> /var/log/replication_monitor.log 2>&1
```

### Vacuum and Analyze

Regular maintenance on primary:

```bash
# Run vacuum analyze
psql -d bookstore_db -c "VACUUM ANALYZE inventory;"

# Or enable autovacuum in postgresql.conf
autovacuum = on
```

## Failover Procedure

### Manual Failover

When primary fails:

1. **Verify primary is down**
   ```bash
   pg_isready -h <primary_ip>
   ```

2. **Promote replica to primary**
   ```bash
   # On replica server
   pg_ctl promote -D /var/lib/postgresql/*/main
   ```

3. **Update application connection strings** to point to new primary

4. **Verify promotion**
   ```bash
   psql -d bookstore_db -c "SELECT pg_is_in_recovery();"
   # Should return 'f' (false)
   ```

5. **Reconfigure old primary as new replica** when restored

## Performance Tuning

### Primary Node

```bash
# Adjust these in postgresql.conf based on your hardware
shared_buffers = 256MB              # 25% of RAM
effective_cache_size = 1GB          # 50-75% of RAM
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1             # For SSD
effective_io_concurrency = 200      # For SSD
work_mem = 4MB
```

### Replica Node

```bash
# Similar settings as primary
# Additionally:
hot_standby_feedback = on
max_standby_streaming_delay = 30s
```

## Security Hardening

1. **Use SSL for replication**
   ```bash
   # In postgresql.conf
   ssl = on
   ssl_cert_file = '/path/to/server.crt'
   ssl_key_file = '/path/to/server.key'
   
   # In pg_hba.conf
   hostssl replication replication_user <replica_ip>/32 md5
   ```

2. **Strong password policy**
   ```sql
   ALTER USER replication_user PASSWORD 'strong_random_password_here';
   ```

3. **Firewall rules**
   ```bash
   # Allow only necessary connections
   sudo ufw allow from <replica_ip> to any port 5432
   ```

## Additional Resources

- [PostgreSQL Replication Documentation](https://www.postgresql.org/docs/current/runtime-config-replication.html)
- [High Availability Guide](https://www.postgresql.org/docs/current/high-availability.html)
- Monitoring tools: pgAdmin, pg_stat_statements, pg_top
