# Distributed Bookstore Database - Replication Architecture

## Overview

This document describes the replication architecture for the distributed bookstore database system. The system uses **PostgreSQL streaming replication** to replicate the inventory table across two nodes for high availability and load distribution.

## Architecture Components

### Node 1: Primary Node (Read-Write)
- **Role**: Master database server
- **Capabilities**: 
  - Accepts all write operations (INSERT, UPDATE, DELETE)
  - Handles read operations
  - Streams Write-Ahead Log (WAL) to replica
- **Location**: Can be on-premises or cloud-hosted
- **IP**: Configurable (e.g., 192.168.1.10)

### Node 2: Replica Node (Read-Only)
- **Role**: Standby/Replica database server
- **Capabilities**:
  - Read-only operations
  - Automatic failover candidate
  - Real-time data synchronization from primary
- **Location**: Separate physical/virtual server (different availability zone recommended)
- **IP**: Configurable (e.g., 192.168.1.20)

## Replication Type: Streaming Replication

### How It Works

1. **Write-Ahead Log (WAL) Streaming**
   - Primary node generates WAL records for all database changes
   - WAL records are streamed continuously to replica node
   - Replica applies WAL records to maintain an up-to-date copy

2. **Physical Replication**
   - Byte-level replication of data files
   - Entire database cluster is replicated (not just specific tables)
   - Guaranteed consistency across nodes

3. **Replication Slots**
   - Ensures primary retains WAL files until received by replica
   - Prevents data loss if replica is temporarily disconnected

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                       │
│                                                             │
│  ┌──────────────┐              ┌──────────────┐           │
│  │ Write Client │              │ Read Clients │           │
│  └──────┬───────┘              └──────┬───────┘           │
│         │                             │                    │
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

## Benefits

### 1. High Availability
- Automatic failover capability
- Minimal downtime during maintenance
- Data redundancy across nodes

### 2. Load Distribution
- Read queries can be distributed to replica
- Primary handles all writes
- Improved overall system performance

### 3. Data Protection
- Real-time backup of data
- Point-in-time recovery options
- Geographic redundancy (if nodes in different locations)

### 4. Scalability
- Easy to add more read replicas
- Horizontal scaling for read-heavy workloads
- No application changes required

## Failover Strategy

### Automatic Failover (with tools like Patroni, repmgr, or pg_auto_failover)

1. **Detection**: Monitor detects primary node failure
2. **Promotion**: Replica is promoted to primary
3. **Redirection**: Applications redirected to new primary
4. **Recovery**: Failed node rejoins as new replica when restored

### Manual Failover

1. Verify primary is truly down
2. Promote replica: `pg_ctl promote -D /path/to/data`
3. Update application connection strings
4. Reconfigure old primary as new replica when restored

## Performance Considerations

### Replication Lag
- **Typical**: < 1 second
- **Monitoring**: Use `pg_stat_replication` view
- **Impact**: Replica may be slightly behind primary

### Network Bandwidth
- **Requirements**: Depends on write volume
- **Compression**: Can be enabled for WAN connections
- **Optimization**: Use dedicated replication network

### Storage
- **Both nodes**: Equal storage capacity recommended
- **WAL retention**: Configure based on replication lag tolerance
- **Backup storage**: Additional space for WAL archives

## Security Considerations

1. **Network Security**
   - Use dedicated replication user
   - Restrict access via pg_hba.conf
   - Consider VPN for cross-datacenter replication

2. **Authentication**
   - Use strong passwords for replication user
   - Consider certificate-based authentication
   - Regular password rotation

3. **Encryption**
   - Enable SSL/TLS for replication connections
   - Encrypt data at rest
   - Secure WAL archive storage

## Monitoring and Maintenance

### Key Metrics to Monitor

1. **Replication Lag**: Time/bytes behind primary
2. **WAL Sender Status**: Connection state
3. **Disk Usage**: WAL and data directory space
4. **Network Throughput**: Replication bandwidth
5. **Replica Status**: Recovery mode, last replay time

### Regular Maintenance Tasks

1. **Vacuum**: Regular vacuuming on primary
2. **Analyze**: Update statistics for query optimization
3. **WAL Cleanup**: Monitor WAL retention
4. **Backup Testing**: Regular restore tests
5. **Failover Drills**: Practice failover procedures

## Limitations

1. **Read-Only Replica**: Cannot write to replica during normal operation
2. **Replication Lag**: Replica may be slightly behind primary
3. **All-or-Nothing**: Entire cluster is replicated, not selective tables
4. **Version Match**: Primary and replica must run same PostgreSQL major version

## Future Enhancements

1. **Multi-Master Replication**: Using logical replication or BDR
2. **Cross-Region Replication**: Geographic distribution
3. **Automatic Failover**: Integration with Patroni or similar tools
4. **Read Replica Pool**: Multiple read replicas for load balancing
5. **Monitoring Dashboard**: Grafana + Prometheus integration
