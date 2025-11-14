# SSH Log Analysis with ELK Stack

This project sets up an ELK (Elasticsearch, Logstash, Kibana) stack to monitor and analyze SSH authentication logs from `/var/log/auth.log`. It's designed to help detect brute-force attacks, failed login attempts, and suspicious SSH activity.

## Features

- **Real-time log ingestion** from auth.log
- **Advanced log parsing** with Grok patterns
- **GeoIP enrichment** for source IP addresses
- **Kibana dashboards** for visualization
- **Automated monitoring** scripts
- **Fake attack generator** for testing

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- Ports 5601 (Kibana), 9200 (Elasticsearch), 9600 (Logstash) available

## Quick Start

1. **Start the ELK stack:**
   ```bash
   docker compose up -d
   ```

2. **Wait for services to be ready** (about 30-60 seconds):
   ```bash
   ./scripts/health_check.sh
   ```

3. **Access Kibana:**
   - Open http://localhost:5601
   - Go to Discover → Create data view
   - Index pattern: `authlogs*`
   - Time field: `@timestamp`

4. **Generate test data** (optional):
   ```bash
   ./gen_fake_ssh_attacks.sh 100
   ```

## Project Structure

```
csdf-project/
├── docker-compose.yml      # ELK stack configuration
├── logstash.conf           # Logstash pipeline configuration
├── auth.log                # SSH log file (mounted to container)
├── gen_fake_ssh_attacks.sh # Script to generate test SSH attacks
├── scripts/                # Utility scripts
│   ├── health_check.sh     # Check all services health
│   ├── view_logs.sh        # View logs from all services
│   └── reset_stack.sh      # Reset and restart the stack
├── kibana/                 # Kibana dashboard exports
│   └── dashboard.json     # Pre-configured dashboard
└── README.md               # This file
```

## Services

### Elasticsearch
- **Port:** 9200
- **Status:** http://localhost:9200/_cluster/health?pretty
- **Data:** Stored in Docker volume `esdata`

### Kibana
- **Port:** 5601
- **URL:** http://localhost:5601
- **Security:** Disabled for development

### Logstash
- **Port:** 9600 (API)
- **Config:** `/usr/share/logstash/pipeline/logstash.conf`
- **Input:** `/var/log/auth.log`

## Common Operations

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f logstash
docker compose logs -f elasticsearch
docker compose logs -f kibana
```

### Check Service Health

```bash
# Quick health check
./scripts/health_check.sh

# Elasticsearch cluster status
curl http://localhost:9200/_cluster/health?pretty

# Document count
curl http://localhost:9200/authlogs/_count?pretty
```

### Add Test Data

```bash
# Generate 100 fake SSH attack attempts
./gen_fake_ssh_attacks.sh 100

# Or manually add a line
echo "Oct 31 12:55:01 arch sshd[3333]: Failed password for invalid user root from 10.0.0.7 port 22 ssh2" \
  | sudo tee -a auth.log
```

### Reset Everything

```bash
# Stop and remove all containers and data
docker compose down -v

# Restart fresh
docker compose up -d
```

## Logstash Configuration

The Logstash pipeline:
1. Reads from `/var/log/auth.log`
2. Parses SSH log entries with Grok patterns
3. Extracts: timestamp, host, PID, status, user, source IP, port
4. Enriches with GeoIP data (if available)
5. Outputs to Elasticsearch index `authlogs`

### Parsed Fields

- `@timestamp` - Event timestamp
- `host` - Hostname
- `pid` - Process ID
- `status` - "Failed" or "Accepted"
- `user` - Username attempted
- `src_ip` - Source IP address
- `port` - Source port
- `geoip.*` - GeoIP data (if enabled)

## Kibana Dashboards

After creating the data view, you can:
1. **Explore data** in Discover
2. **Create visualizations:**
   - Failed login attempts over time
   - Top attacking IPs
   - Most targeted usernames
   - Geographic distribution (if GeoIP enabled)
3. **Import pre-built dashboard** from `kibana/dashboard.json`

## Troubleshooting

### Kibana shows "not ready"
- Wait 30-60 seconds for Elasticsearch to fully start
- Check: `curl http://localhost:9200/_cluster/health?pretty`
- Status should be "green" or "yellow"

### No data in Kibana
- Verify Logstash is running: `docker compose ps`
- Check Logstash logs: `docker compose logs logstash`
- Add test data: `./gen_fake_ssh_attacks.sh 10`
- Verify index exists: `curl http://localhost:9200/_cat/indices?v`

### Permission denied errors
- Logstash runs as root (user: "0:0") to read auth.log
- If issues persist, check file permissions

### Elasticsearch shard issues
- Disk space might be low (watermarks adjusted in docker-compose.yml)
- Check: `curl http://localhost:9200/_cat/shards/authlogs?v`
- Fix yellow status: `curl -X PUT 'http://localhost:9200/authlogs/_settings' -H 'Content-Type: application/json' -d '{"index":{"number_of_replicas":"0"}}'`

## Advanced Configuration

### GeoIP Enrichment & Maps

- GeoIP lookups are **enabled by default** for public source IPs (`src_ip` field).  
  Private/reserved ranges (10.x, 172.16/12, 192.168.x, 127.x, etc.) are skipped automatically.
- Logstash enriches each event with the `geoip.*` fields (latitude, longitude, country, city, ASN, etc.).
- Kibana can use `geoip.location` to plot events on a map.

#### Updating the GeoIP database (optional)
The Logstash GeoIP plugin ships with a bundled database. To use the latest MaxMind GeoLite2 data:
1. Create a `geoip/` folder in this project.
2. Download `GeoLite2-City.mmdb` from MaxMind (requires a free account) into `geoip/`.
3. Update `docker-compose.yml` to mount that directory: `./geoip:/usr/share/logstash/geoip:ro`.
4. Set `database => "/usr/share/logstash/geoip/GeoLite2-City.mmdb"` inside the Logstash `geoip` filter (if you need the custom path).

#### Build a Kibana map (geo heatmap)
1. Open **Kibana → Maps** → “Create map”.
2. Add a **Documents** layer using the `authlogs*` data view.
3. Set the **geospatial field** to `geoip.location`.
4. Style by:
   - Size or color using `failed_login` tag (failed vs. accepted).
   - Time filter (e.g., last 24h) to watch attack bursts.
5. Save the map or embed it into your dashboard for quick situational awareness.

### Adjust Logstash Parsing

Edit `logstash.conf` to:
- Add more Grok patterns for different log formats
- Add additional field extractions
- Filter out specific events
- Add custom tags

### Scale Elasticsearch

For production, consider:
- Multiple Elasticsearch nodes
- Separate master/data nodes
- Proper security configuration
- Index lifecycle management

## Security Notes

⚠️ **This setup is for development/testing only!**

- Security is disabled (`xpack.security.enabled=false`)
- No authentication required
- Not suitable for production use

For production:
- Enable X-Pack security
- Use TLS/SSL
- Set up proper authentication
- Configure firewall rules
- Use secrets management

## License

This project is provided as-is for educational and development purposes.

## Contributing

Feel free to enhance this project with:
- Additional log parsers
- More Kibana visualizations
- Alerting rules
- Better documentation
- Performance optimizations

