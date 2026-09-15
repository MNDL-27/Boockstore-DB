# Bookstore Database - Distributed Replication System

A simple scenario demonstrating distributed bookstore database replication using PostgreSQL streaming replication across two nodes for high availability.

## Overview

This repository contains a complete implementation of a distributed bookstore database system with inventory table replication across two nodes (Primary and Replica). The system uses PostgreSQL's native streaming replication to ensure high availability and data redundancy.

## Features

- ✅ **PostgreSQL Streaming Replication**: Real-time data synchronization
- ✅ **Two-Node Architecture**: Primary (read-write) and Replica (read-only)
- ✅ **High Availability**: Automatic failover capability
- ✅ **Load Distribution**: Read operations can be distributed to replica
- ✅ **Data Redundancy**: Real-time backup across nodes
- ✅ **Monitoring Tools**: Scripts to monitor replication health
- ✅ **Complete Documentation**: Detailed setup and architecture guides

## Repository Structure

```
Boockstore-DB/
├── schema/
│   └── inventory_table.sql          # Inventory table schema and sample data
├── node1_primary/
│   └── setup_primary.sql            # Primary node setup script
├── node2_replica/
│   └── setup_replica.sql            # Replica node configuration script
├── config/
│   ├── postgresql_primary.conf      # Primary node PostgreSQL settings
│   ├── postgresql_replica.conf      # Replica node PostgreSQL settings
│   ├── pg_hba_primary.conf          # Primary authentication config
│   └── pg_hba_replica.conf          # Replica authentication config
├── scripts/
│   ├── setup_primary.sh             # Automated primary setup
│   ├── setup_replica.sh             # Automated replica setup
│   ├── monitor_replication.sh       # Health monitoring script
│   ├── test_replication.sql         # Replication testing (run on primary)
│   └── verify_replication.sql       # Verify replication (run on replica)
├── docs/
│   ├── ARCHITECTURE.md              # System architecture documentation
│   └── SETUP_GUIDE.md               # Detailed setup instructions
└── README.md                        # This file
```

## Quick Start

### Prerequisites

- PostgreSQL 12 or higher installed on both servers
- Network connectivity between the two nodes
- Sufficient storage space
- Root or PostgreSQL superuser access

### 1. Setup Primary Node

```bash
# Clone the repository
git clone https://github.com/MNDL-27/Boockstore-DB.git
cd Boockstore-DB

# Make scripts executable
chmod +x scripts/*.sh

# Run primary setup
./scripts/setup_primary.sh
```

### 2. Configure Replication Settings

Edit PostgreSQL configuration on the primary node:

```bash
# Add to postgresql.conf
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3

# Add to pg_hba.conf (replace <replica_ip> with actual IP)
host    replication     replication_user    <replica_ip>/32    md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### 3. Setup Replica Node

On the replica server:

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

```bash
# On primary - check replication status
psql -d bookstore_db -c "SELECT * FROM pg_stat_replication;"

# On replica - verify it's in recovery mode
psql -d bookstore_db -c "SELECT pg_is_in_recovery();"

# Run monitoring script
./scripts/monitor_replication.sh
```

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│                                                             │
│  ┌──────────────┐              ┌──────────────┐           │
│  │ Write Client │              │ Read Clients │           │
│  └──────┬───────┘              └──────┬───────┘           │
└─────────┼─────────────────────────────┼────────────────────┘
          │                             │
          │ Writes                      │ Reads
          │                             │
          ▼                             ▼
┌──────────────────┐          ┌──────────────────┐
│   Node 1         │   WAL    │   Node 2         │
│   Primary        │─────────▶│   Replica        │
│   (Read-Write)   │ Stream   │   (Read-Only)    │
│                  │          │                  │
│ ┌──────────────┐ │          │ ┌──────────────┐ │
│ │  Inventory   │ │          │ │  Inventory   │ │
│ │    Table     │ │          │ │    Table     │ │
│ └──────────────┘ │          │ └──────────────┘ │
└──────────────────┘          └──────────────────┘
```

### Replication Type

- **Streaming Replication**: Uses PostgreSQL's Write-Ahead Log (WAL) streaming
- **Physical Replication**: Byte-level replication for guaranteed consistency
- **Asynchronous**: Configurable to synchronous for zero data loss

For detailed architecture information, see [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Database Schema

### Inventory Table

```sql
CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    isbn VARCHAR(13) UNIQUE NOT NULL,
    book_title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    publisher VARCHAR(255),
    publication_year INTEGER,
    quantity_available INTEGER NOT NULL DEFAULT 0,
    price DECIMAL(10, 2) NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    node_id INTEGER NOT NULL
);
```

Includes:
- Automatic timestamp updates
- Indexes on ISBN, title, author, and node_id
- Sample data with 10 popular books

## Testing Replication

### Run Test Suite

1. **On Primary Node**: Insert, update, and delete operations
   ```bash
   psql -d bookstore_db -f scripts/test_replication.sql
   ```

2. **Wait a few seconds** for replication to propagate

3. **On Replica Node**: Verify changes were replicated
   ```bash
   psql -d bookstore_db -f scripts/verify_replication.sql
   ```

### Monitor Replication Health

```bash
# Run monitoring script
./scripts/monitor_replication.sh
```

This displays:
- Node type (Primary/Replica)
- Replication status and lag
- Inventory statistics
- Recent changes

## Use Cases

### High Availability
- **Scenario**: Primary server fails
- **Solution**: Promote replica to primary, minimal downtime

### Load Distribution
- **Scenario**: Heavy read traffic
- **Solution**: Direct read queries to replica node

### Disaster Recovery
- **Scenario**: Data corruption or loss
- **Solution**: Replica serves as real-time backup

### Geographic Distribution
- **Scenario**: Users in different locations
- **Solution**: Place replica closer to users for faster reads

## Monitoring

### Key Metrics

1. **Replication Lag**: Time/bytes behind primary
   ```sql
   SELECT pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) 
   FROM pg_stat_replication;
   ```

2. **Replica Status**: Check if replica is catching up
   ```sql
   SELECT pg_is_in_recovery();
   ```

3. **Connection Status**: Verify replication connection
   ```sql
   SELECT * FROM pg_stat_replication;
   ```

## Failover

### Manual Failover Process

1. **Verify primary is down**
2. **Promote replica**: `pg_ctl promote -D /var/lib/postgresql/data`
3. **Update application connection strings**
4. **Reconfigure old primary as new replica** when restored

For automated failover, consider tools like:
- [Patroni](https://github.com/zalando/patroni)
- [repmgr](https://repmgr.org/)
- [pg_auto_failover](https://github.com/citusdata/pg_auto_failover)

## Troubleshooting

### Common Issues

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Replication not starting | Network/firewall | Check connectivity and pg_hba.conf |
| High replication lag | Network/disk I/O | Monitor bandwidth and disk performance |
| Connection refused | PostgreSQL not running | Check service status and logs |
| Slot full | Replica disconnected | Check replica status, recreate slot |

For detailed troubleshooting, see [SETUP_GUIDE.md](docs/SETUP_GUIDE.md).

## Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Detailed system architecture
- [SETUP_GUIDE.md](docs/SETUP_GUIDE.md) - Complete setup instructions
- [PostgreSQL Replication Docs](https://www.postgresql.org/docs/current/runtime-config-replication.html)

## Performance Tuning

### Primary Node
```conf
shared_buffers = 256MB
effective_cache_size = 1GB
wal_buffers = 16MB
checkpoint_completion_target = 0.9
```

### Replica Node
```conf
hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 30s
```

## Security Best Practices

1. **Use SSL/TLS** for replication connections
2. **Strong passwords** for replication user
3. **Firewall rules** to restrict access
4. **Regular security updates** for PostgreSQL
5. **Encrypted storage** for sensitive data

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Future Enhancements

- [ ] Multi-master replication using logical replication
- [ ] Automatic failover with Patroni integration
- [ ] Monitoring dashboard with Grafana
- [ ] Load balancer configuration (pgpool-II)
- [ ] Backup automation scripts
- [ ] Docker containerization
- [ ] Kubernetes deployment manifests

## Support

For questions or issues:
- Open an [issue](https://github.com/MNDL-27/Boockstore-DB/issues)
- Check the [documentation](docs/)
- Review PostgreSQL [official documentation](https://www.postgresql.org/docs/)

## Acknowledgments

- PostgreSQL Community for excellent documentation
- Contributors and testers
- Open source community

---

**Built with ❤️ for distributed database learning and high availability**