# Frequently Asked Questions (FAQ)

## General Questions

### What is database replication?

Database replication is the process of copying and maintaining database data across multiple database servers. In this system, changes made to the primary database are automatically synchronized to one or more replica databases.

### Why use replication?

- **High Availability**: If the primary fails, replica can take over
- **Load Distribution**: Read queries can be distributed across replicas
- **Disaster Recovery**: Real-time backup of data
- **Geographic Distribution**: Place replicas closer to users

### What type of replication is used?

This implementation uses **PostgreSQL Streaming Replication**, which is:
- **Physical replication**: Byte-level replication of data files
- **Asynchronous by default**: Can be configured for synchronous
- **Master-Slave**: One primary (read-write), one or more replicas (read-only)

## Setup Questions

### Can I use different PostgreSQL versions?

No. Primary and replica must run the **same major version** of PostgreSQL (e.g., both 15.x). Minor versions can differ (e.g., 15.1 and 15.3).

### Do I need two physical servers?

**For production**: Yes, use separate physical or virtual servers
**For testing**: You can use Docker or two PostgreSQL instances on the same server with different ports

### What are the minimum hardware requirements?

**Minimum (testing)**:
- 2 CPU cores per node
- 4GB RAM per node
- 20GB disk space per node

**Recommended (production)**:
- 4+ CPU cores per node
- 8GB+ RAM per node
- 100GB+ SSD storage per node
- Dedicated network connection

### Can I run this on Windows?

Yes, but with considerations:
- Use WSL2 for Linux-based scripts
- Or use Docker Desktop
- Or adapt scripts for PowerShell
- PostgreSQL for Windows is fully supported

## Replication Questions

### How fast is replication?

Typically **sub-second** with good network:
- Local network: < 100ms
- Same datacenter: < 500ms
- Cross-datacenter: 1-5 seconds (depends on distance)

### What happens if replication fails?

- Primary continues to operate normally
- WAL files accumulate on primary (configured limit)
- Replica catches up when connection restored
- Replication slots prevent data loss

### Can I write to the replica?

**No**, replicas are **read-only** during normal operation. However:
- After promotion to primary, replica becomes read-write
- Logical replication allows some write scenarios
- Conflict resolution required for multi-master

### How much data can be replicated?

No practical limit. PostgreSQL replication has been tested with:
- Databases: Terabytes of data
- Tables: Billions of rows
- Load: Thousands of transactions per second

## Operational Questions

### How do I perform maintenance?

**Primary maintenance**:
1. Ensure replica is up-to-date
2. Perform maintenance on primary
3. Replica continues serving reads
4. Or failover to replica first

**Replica maintenance**:
1. Disconnect replica
2. Perform maintenance
3. Reconnect - it will catch up automatically

### How do I upgrade PostgreSQL?

**Method 1: In-place upgrade**
1. Upgrade primary using pg_upgrade
2. Rebuild replica from new primary

**Method 2: Logical replication**
1. Set up new nodes with new version
2. Use logical replication to sync
3. Switch over when ready

### How do I add more replicas?

1. Create replication slot on primary
2. Take base backup from primary (or existing replica)
3. Configure new replica to connect
4. Start replica

### How do I handle disk space issues?

**On primary**:
- Monitor WAL disk usage
- Adjust `wal_keep_size` or use archive
- Ensure replica is connected

**On replica**:
- Similar storage as primary needed
- Monitor pg_wal directory

## Failover Questions

### When should I perform failover?

- Primary server hardware failure
- Primary datacenter outage
- Planned maintenance requiring downtime
- Network partition isolating primary

### How long does failover take?

**Manual failover**: 1-5 minutes
- Detection: 30 seconds
- Promotion: 10 seconds
- Application update: 1-5 minutes

**Automatic failover** (with tools): 10-60 seconds

### Will I lose data during failover?

**Asynchronous replication** (default):
- May lose recent transactions (< 1 second typically)
- Trade-off for better performance

**Synchronous replication**:
- Zero data loss
- Slower write performance
- Requires wait for replica confirmation

### Can I failback to original primary?

Yes, but requires reconfiguration:
1. Verify old primary is healthy
2. Reconfigure it as replica of new primary
3. Let it catch up
4. Plan another failover when ready

## Performance Questions

### Does replication affect primary performance?

**Minimal impact**:
- WAL generation: Happens anyway for durability
- Network: Asynchronous streaming
- CPU: < 5% overhead typically

**Synchronous replication**: More impact
- Writes wait for replica confirmation
- Network latency affects write speed

### Can replicas handle write load?

No, replicas are read-only. For write scaling:
- Use connection pooling on primary
- Partition data (sharding)
- Consider multi-master solutions
- Upgrade primary hardware

### How many replicas can I have?

**PostgreSQL supports**:
- Theoretical: Unlimited
- Practical: 5-10 replicas commonly
- Limited by: `max_wal_senders` setting

**Considerations**:
- Each replica adds network load to primary
- Use cascading replication for many replicas

## Monitoring Questions

### What should I monitor?

**Critical metrics**:
1. Replication lag (bytes/seconds)
2. Replica connection status
3. WAL disk usage
4. Replica query conflicts

**Performance metrics**:
1. Transaction rate
2. Query response time
3. Connection count
4. Disk I/O

### How do I detect replication lag?

```sql
-- On primary
SELECT pg_wal_lsn_diff(sent_lsn, replay_lsn) as lag_bytes
FROM pg_stat_replication;

-- On replica
SELECT NOW() - pg_last_xact_replay_timestamp() as lag_time;
```

**Alerts**:
- Warning: > 10 seconds lag
- Critical: > 60 seconds lag

### What tools can I use for monitoring?

**Open source**:
- pgAdmin
- pg_top / pg_activity
- check_postgres Nagios plugin
- Prometheus + postgres_exporter
- Grafana dashboards

**Commercial**:
- Datadog
- New Relic
- AppDynamics

## Security Questions

### Is replication traffic encrypted?

By default, no. To enable:
1. Configure SSL in postgresql.conf
2. Update pg_hba.conf to require SSL
3. Use `hostssl` instead of `host`

### How do I secure the replication user?

1. Use strong random password
2. Limit access in pg_hba.conf by IP
3. Consider certificate-based auth
4. Regular password rotation
5. Use dedicated replication user (don't reuse postgres)

### Can someone intercept replication data?

**Without SSL**: Yes, replication traffic is unencrypted
**With SSL**: Traffic is encrypted
**Best practice**: 
- Always use SSL for production
- Use VPN for cross-datacenter replication

## Troubleshooting

### Replica can't connect to primary

**Check**:
1. Network connectivity: `ping`, `telnet`
2. PostgreSQL running on primary
3. pg_hba.conf allows replication connection
4. Replication user password correct
5. Firewall rules allow port 5432

### High replication lag

**Causes**:
1. Network bandwidth limitation
2. Slow disk I/O on replica
3. Heavy write load on primary
4. Long-running queries on replica

**Solutions**:
1. Upgrade network connection
2. Use SSD storage
3. Tune checkpoint settings
4. Cancel blocking queries on replica

### "requested WAL segment has already been removed"

**Cause**: Primary deleted WAL before replica received it

**Solutions**:
1. Increase `wal_keep_size` on primary
2. Use replication slots (recommended)
3. Set up WAL archiving
4. Rebuild replica from new base backup

## Best Practices

### Pre-Production Checklist

- [ ] Test failover procedure
- [ ] Document connection strings
- [ ] Set up monitoring and alerts
- [ ] Configure backups
- [ ] Test restore procedure
- [ ] Create runbook for common issues
- [ ] Train team on failover process
- [ ] Schedule regular failover drills

### Production Checklist

- [ ] Use replication slots
- [ ] Enable SSL/TLS
- [ ] Set up monitoring
- [ ] Configure automatic failover (optional)
- [ ] Document disaster recovery plan
- [ ] Regular backup testing
- [ ] Performance baseline established
- [ ] Capacity planning completed

## Getting Help

### Something not working?

1. Check PostgreSQL logs
2. Review this FAQ
3. Read SETUP_GUIDE.md
4. Check PostgreSQL documentation
5. Open an issue on GitHub

### Where to learn more?

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [PostgreSQL Wiki](https://wiki.postgresql.org/)
- [PostgreSQL Mailing Lists](https://www.postgresql.org/list/)
- Community forums and Stack Overflow

### Contributing

Found an issue or have a suggestion?
- Open an issue on GitHub
- Submit a pull request
- Share your experience
