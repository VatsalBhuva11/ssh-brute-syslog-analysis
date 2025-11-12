# Kibana Dashboard Setup Guide

This guide helps you create useful visualizations for SSH log analysis.

## Important: Using .keyword Fields

For aggregations and filters in Kibana, use the `.keyword` suffix for text fields:
- `src_ip.keyword` (not `src_ip`)
- `status.keyword` (not `status`)
- `user.keyword` (not `user`)
- `port.keyword` (not `port`)

This is because Elasticsearch stores text fields with a keyword sub-field for exact matching and aggregations.

## Step 1: Create Data View

1. Go to **Discover** (left sidebar)
2. Click **Create data view**
3. Set:
   - **Name:** `authlogs`
   - **Index pattern:** `authlogs*`
   - **Time field:** `@timestamp`
4. Click **Create data view**

## Step 2: Create Visualizations

### Failed Login Attempts Over Time

1. Go to **Visualize Library** → **Create visualization**
2. Choose **Line** chart
3. Select `authlogs` data view
4. Configure:
   - **Y-axis:** Count
   - **X-axis:** Date Histogram on `@timestamp`
   - **Filter:** `status: Failed`
5. Save as: "Failed Login Attempts Over Time"

### Top Attacking IPs

1. Create **Vertical Bar** chart
2. Select `authlogs` data view
3. Configure:
   - **Y-axis:** Count
   - **X-axis:** Terms on `src_ip.keyword` (use .keyword suffix!)
   - **Filter:** `status.keyword: Failed`
   - **Size:** Top 10
4. Save as: "Top Attacking IPs"

### Most Targeted Usernames

1. Create **Pie** chart
2. Select `authlogs` data view
3. Configure:
   - **Slice by:** Terms on `user.keyword` (use .keyword suffix!)
   - **Filter:** `status.keyword: Failed`
   - **Size:** Top 10
4. Save as: "Most Targeted Usernames"

### Failed vs Successful Logins

1. Create **Donut** chart
2. Select `authlogs` data view
3. Configure:
   - **Slice by:** Terms on `status.keyword` (use .keyword suffix!)
4. Save as: "Login Status Distribution"

### Attacks by Hour

1. Create **Area** chart
2. Select `authlogs` data view
3. Configure:
   - **Y-axis:** Count
   - **X-axis:** Date Histogram on `@timestamp` (interval: 1 hour)
   - **Filter:** `status.keyword: Failed`
4. Save as: "Attacks by Hour"

## Step 3: Create Dashboard

1. Go to **Dashboard** → **Create dashboard**
2. Click **Add** → **Add panels**
3. Add all visualizations created above
4. Arrange and resize panels as needed
5. Save as: "SSH Security Dashboard"

## Step 4: Useful Filters

Create saved searches with filters:

- **Brute Force Attempts:** `status.keyword: Failed AND tags: potential_brute_force`
- **Invalid Users:** `tags: invalid_user`
- **Successful Logins:** `status.keyword: Accepted`
- **Specific IP:** `src_ip.keyword: "192.168.1.100"`

## KQL Query Examples

Use these in Discover or visualizations:

```
# All failed logins (KQL works with both, but .keyword is better for aggregations)
status.keyword: Failed

# Failed logins for specific user
status.keyword: Failed AND user.keyword: root

# Attacks from specific IP
src_ip.keyword: "10.0.0.7"

# Multiple failed attempts (use in aggregations)
status.keyword: Failed

# Time range queries
@timestamp >= now()-1h AND status.keyword: Failed
```

**Note:** In KQL (Kibana Query Language), you can use either `status: Failed` or `status.keyword: Failed`, but for aggregations and exact matches, always use `.keyword`.

## Advanced: Machine Learning (if available)

1. Go to **Machine Learning** → **Anomaly Detection**
2. Create job on `authlogs` index
3. Detect:
   - Unusual spikes in failed logins
   - Unusual source IPs
   - Unusual usernames

## Tips

- Use **Refresh** to update data in real-time
- Set **Auto-refresh** to 30 seconds for live monitoring
- Export dashboards as JSON for backup
- Use **Saved Objects** to share dashboards

