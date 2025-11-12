# Changelog

## [Enhanced] - 2025-10-31

### Added

#### Documentation
- **README.md** - Comprehensive documentation with:
  - Quick start guide
  - Project structure
  - Common operations
  - Troubleshooting guide
  - Security notes

#### Scripts (`scripts/` directory)
- **health_check.sh** - Comprehensive health check for all ELK services
- **view_logs.sh** - View logs from specific or all services
- **reset_stack.sh** - Reset and restart the entire stack
- **monitor.sh** - Real-time monitoring dashboard
- **query_elasticsearch.sh** - Query Elasticsearch with useful pre-built queries

#### Enhanced Logstash Configuration
- Improved Grok patterns for better parsing
- Support for multiple SSH event types:
  - Failed/Accepted password attempts
  - Connection events
  - Disconnection events
  - Invalid user attempts
- Added severity tagging (warning/info)
- Added tags for failed logins and potential brute force
- Better timestamp parsing with timezone support
- Enhanced field extraction

#### Kibana Resources
- **dashboard-guide.md** - Step-by-step guide to create visualizations:
  - Failed login attempts over time
  - Top attacking IPs
  - Most targeted usernames
  - Login status distribution
  - Attacks by hour
- KQL query examples
- Dashboard creation instructions

#### Index Template
- **templates/authlogs-template.json** - Elasticsearch index template with:
  - Proper field mappings (IP, keyword, text, date)
  - Optimized settings
  - Better search performance

#### Docker Compose Updates
- Added templates volume mount for Logstash
- Better organization and comments

### Improved
- Better error handling in scripts
- More informative health checks
- Enhanced log parsing accuracy
- Better field extraction from SSH logs

### Files Modified
- `docker-compose.yml` - Added templates volume
- `logstash.conf` - Enhanced parsing and field extraction
- `imp_cmds.txt` - Updated with new commands

### Files Added
- `README.md`
- `CHANGELOG.md`
- `scripts/health_check.sh`
- `scripts/view_logs.sh`
- `scripts/reset_stack.sh`
- `scripts/monitor.sh`
- `scripts/query_elasticsearch.sh`
- `kibana/dashboard-guide.md`
- `templates/authlogs-template.json`

## [Initial] - 2025-10-31

### Added
- Basic ELK stack setup
- Simple Logstash configuration
- Fake SSH attack generator script
- Basic commands file

