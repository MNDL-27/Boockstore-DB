# Security Considerations

## Important Security Notes

⚠️ **WARNING**: This implementation contains example passwords and configurations for demonstration purposes. These MUST be changed before deploying to production.

## Default Credentials to Change

### 1. Replication User Password

**Current (Example)**:
```sql
CREATE USER replication_user WITH REPLICATION ENCRYPTED PASSWORD 'replication_password';
```

**Change to**:
```sql
CREATE USER replication_user WITH REPLICATION ENCRYPTED PASSWORD 'your_strong_random_password_here';
```

**Generate a strong password**:
```bash
# Using OpenSSL
openssl rand -base64 32

# Using pwgen
pwgen -s 32 1
```

### 2. PostgreSQL User Passwords

**Change default postgres password**:
```sql
ALTER USER postgres PASSWORD 'your_strong_password';
```

### 3. PgAdmin Credentials (Docker setup)

**Current (Example)**:
- Email: admin@bookstore.com
- Password: admin

**Change in docker-compose.yml**:
```yaml
environment:
  PGADMIN_DEFAULT_EMAIL: your_email@example.com
  PGADMIN_DEFAULT_PASSWORD: your_strong_password
```

## Files Containing Example Passwords

The following files contain example passwords that should be updated:

1. `node1_primary/setup_primary.sql`
   - Line: `CREATE USER replication_user...`
   
2. `config/postgresql_replica.conf`
   - Line: `primary_conninfo = '...'`
   
3. `docker-compose.yml`
   - PostgreSQL passwords
   - PgAdmin credentials
   
4. `docker-compose-setup.sh`
   - Replication user creation
   - pg_basebackup command

## Security Best Practices

### 1. Password Management

✅ **DO**:
- Use strong, randomly generated passwords (32+ characters)
- Store passwords in a secure password manager
- Use different passwords for different services
- Rotate passwords regularly (every 90 days)
- Use environment variables for passwords in scripts

❌ **DON'T**:
- Use default passwords in production
- Hardcode passwords in scripts
- Share passwords via insecure channels
- Use simple or dictionary words
- Reuse passwords across systems

### 2. Network Security

✅ **DO**:
- Use SSL/TLS for all replication connections
- Restrict access by IP address in pg_hba.conf
- Use VPN for cross-datacenter replication
- Configure firewall rules to allow only necessary ports
- Use private networks when possible

❌ **DON'T**:
- Expose PostgreSQL directly to the internet
- Use unencrypted connections for replication
- Allow connections from 0.0.0.0/0 in production
- Forget to configure firewall rules

### 3. Authentication

✅ **DO**:
- Use md5 or scram-sha-256 authentication
- Consider certificate-based authentication for replication
- Limit replication user privileges to only what's needed
- Use separate users for different purposes
- Enable connection logging

**Example pg_hba.conf** (secure):
```conf
# TYPE  DATABASE        USER              ADDRESS         METHOD
local   all             postgres                          peer
host    all             all               127.0.0.1/32   scram-sha-256
host    replication     replication_user  10.0.1.0/24    scram-sha-256
hostssl bookstore_db    app_user          10.0.2.0/24    scram-sha-256
```

❌ **DON'T**:
- Use 'trust' authentication in production
- Give replication user superuser privileges
- Use the same user for applications and replication

### 4. SSL/TLS Configuration

**Enable SSL on primary**:
```conf
# postgresql.conf
ssl = on
ssl_cert_file = '/path/to/server.crt'
ssl_key_file = '/path/to/server.key'
ssl_ca_file = '/path/to/ca.crt'
```

**Require SSL in pg_hba.conf**:
```conf
hostssl replication replication_user 10.0.1.0/24 scram-sha-256
hostssl bookstore_db all 0.0.0.0/0 scram-sha-256
```

**Update replica connection string**:
```conf
primary_conninfo = 'host=primary_ip port=5432 user=replication_user password=*** sslmode=require sslcert=/path/to/client.crt sslkey=/path/to/client.key sslrootcert=/path/to/ca.crt'
```

### 5. Firewall Configuration

**Allow only necessary connections**:
```bash
# UFW (Ubuntu)
sudo ufw allow from 10.0.1.0/24 to any port 5432 proto tcp

# iptables
sudo iptables -A INPUT -p tcp -s 10.0.1.0/24 --dport 5432 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5432 -j DROP

# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.1.0/24" port port="5432" protocol="tcp" accept'
sudo firewall-cmd --reload
```

### 6. Audit Logging

**Enable logging in postgresql.conf**:
```conf
# Logging
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB

# What to log
log_connections = on
log_disconnections = on
log_duration = off
log_line_prefix = '%m [%p] %u@%d '
log_statement = 'ddl'
log_min_duration_statement = 1000  # Log queries taking > 1 second
```

### 7. Data Encryption

**Encrypt data at rest**:
- Use encrypted file systems (LUKS, BitLocker)
- Use cloud provider encryption (AWS EBS encryption, Azure Disk Encryption)
- Consider PostgreSQL-level encryption extensions

**Encrypt backups**:
```bash
# Encrypt pg_dump output
pg_dump bookstore_db | gpg --encrypt --recipient your@email.com > backup.sql.gpg

# Encrypt pg_basebackup
tar -cf - /backup/path | gpg --encrypt --recipient your@email.com > backup.tar.gpg
```

### 8. Privilege Management

**Create limited application user**:
```sql
-- Create application user
CREATE USER app_user WITH PASSWORD 'strong_password';

-- Grant only necessary privileges
GRANT CONNECT ON DATABASE bookstore_db TO app_user;
GRANT SELECT, INSERT, UPDATE ON inventory TO app_user;
GRANT USAGE ON SEQUENCE inventory_inventory_id_seq TO app_user;

-- Don't grant:
-- - SUPERUSER
-- - CREATEDB
-- - CREATEROLE
-- - REPLICATION (unless specifically needed)
```

### 9. Regular Security Tasks

**Weekly**:
- Review authentication logs
- Check for failed login attempts
- Monitor replication lag

**Monthly**:
- Review and update firewall rules
- Check for PostgreSQL security updates
- Audit user accounts and privileges

**Quarterly**:
- Rotate passwords
- Review and update SSL certificates
- Test backup restoration
- Conduct security audit

### 10. Security Monitoring

**Set up alerts for**:
- Failed authentication attempts
- Unusual connection patterns
- Replication failures
- Disk space issues
- Long-running queries

**Example monitoring query**:
```sql
-- Check for failed login attempts (requires log_connections = on)
-- Review PostgreSQL logs for lines containing "FATAL: password authentication failed"

-- Check current connections
SELECT 
    datname, 
    usename, 
    client_addr, 
    state, 
    query_start
FROM pg_stat_activity
WHERE datname = 'bookstore_db';
```

## Production Deployment Checklist

Before deploying to production:

- [ ] Change all default passwords
- [ ] Configure SSL/TLS for all connections
- [ ] Set up firewall rules
- [ ] Configure pg_hba.conf with proper restrictions
- [ ] Enable audit logging
- [ ] Set up monitoring and alerting
- [ ] Configure automatic backups
- [ ] Test backup restoration
- [ ] Document all passwords in secure password manager
- [ ] Review and apply PostgreSQL security patches
- [ ] Set up intrusion detection (optional)
- [ ] Configure data encryption at rest
- [ ] Create limited-privilege application users
- [ ] Disable or remove unnecessary users
- [ ] Set connection limits
- [ ] Configure statement timeout
- [ ] Review and minimize SUPERUSER accounts

## Security Incident Response

If you suspect a security breach:

1. **Immediate Actions**:
   - Disconnect affected systems from network
   - Change all passwords
   - Review logs for suspicious activity
   - Notify security team

2. **Investigation**:
   - Analyze PostgreSQL logs
   - Check for unauthorized access
   - Identify affected data
   - Document findings

3. **Recovery**:
   - Restore from clean backup if necessary
   - Apply security patches
   - Update security configurations
   - Monitor for continued issues

4. **Prevention**:
   - Update security procedures
   - Implement additional monitoring
   - Conduct security training
   - Document lessons learned

## Resources

- [PostgreSQL Security Documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)
- [PostgreSQL Security Checklist](https://www.postgresql.org/docs/current/sql-security.html)
- [OWASP Database Security Guide](https://owasp.org/www-community/vulnerabilities/Insecure_Database_Connection)
- [CIS PostgreSQL Benchmark](https://www.cisecurity.org/benchmark/postgresql)

## Support

For security-related questions or to report vulnerabilities:
- Do not post security issues in public GitHub issues
- Contact repository maintainers directly
- Follow responsible disclosure practices
