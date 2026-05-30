# Time-Series Databases

**Category:** System Design / Data Storage
**Difficulty:** 🟡 Middle
**Tags:** `time-series`, `InfluxDB`, `TimescaleDB`, `Azure-Data-Explorer`, `IoT`, `metrics`, `retention`

## Question

> When should you use a time-series database instead of a relational or document database? What are the key characteristics of time-series data, and what do retention policies do?

## Short Answer

A time-series database (TSDB) is optimised for data that is always associated with a timestamp and written in append-only, chronological order — such as IoT sensor readings, application metrics, and financial tick data. TSDBs provide columnar compression, automatic downsampling, and retention policies that automatically delete or summarise old data to control storage costs. Use a TSDB when your primary query pattern is "give me all values for metric X over time window [T1, T2]" and write throughput exceeds what a relational database can handle efficiently.

## Detailed Explanation

### Characteristics of Time-Series Data

| Characteristic | Implication |
|---------------|-------------|
| **Always has a timestamp** | Timestamp is always part of the primary key |
| **Write-heavy, append-only** | Data is never updated — only new measurements written |
| **Time-ordered reads** | Queries always include a time range filter |
| **High cardinality** | Millions of unique metric/tag combinations |
| **Volume decays in value** | Recent data queried frequently; old data rarely; can be summarised |
| **Regular intervals** | Sensor readings every 5 seconds — predictable write pattern |

### Why Not a Relational Database?

| Problem | Relational limitation | TSDB solution |
|---------|----------------------|--------------|
| Write throughput | Row-per-insert overhead; index maintenance | Batch ingest, columnar append |
| Storage size | Full row stored per data point | Delta encoding, compression (10–100× smaller) |
| Time range queries | Full index scan or partition scan | Time-partitioned chunks; hot tier in memory |
| Aggregation (rollup) | `GROUP BY` re-reads all rows | Pre-computed rollups; continuous aggregates |
| Automatic data expiry | Manual `DELETE` jobs | Retention policies automatically drop old partitions |

A relational table with 10 billion IoT readings is possible, but a TSDB holds the same data in 10–100× less space and answers range queries 10–100× faster due to columnar storage and time-aware indexing.

### Time-Series Database Options

| Product | Type | Strengths | .NET support |
|---------|------|-----------|-------------|
| **InfluxDB 3** | Purpose-built TSDB | Apache Arrow, SQL query support, cloud | `InfluxDB3.Client` |
| **TimescaleDB** | PostgreSQL extension | SQL-compatible, `JOIN` with relational data | `Npgsql` (standard PG driver) |
| **Azure Data Explorer (ADX)** | OLAP + time-series | KQL query language, massive scale, Azure native | `Microsoft.Azure.Kusto.Data` |
| **Prometheus** | Pull-based metrics TSDB | Kubernetes native, PromQL | Via Pushgateway or `prometheus-net` |
| **VictoriaMetrics** | Prometheus-compatible | Better compression, higher cardinality | Via Prometheus-compatible endpoints |
| **QuestDB** | High-performance TSDB | SQL compatible, low latency | JDBC driver |

### TimescaleDB: SQL-Compatible TSDB

TimescaleDB extends PostgreSQL with **hypertables** — tables that are automatically partitioned into **chunks** based on time intervals. Each chunk covers a time window (e.g., 1 week). Queries that filter by time only read relevant chunks, not the entire table.

```sql
-- Create hypertable with 1-week chunks
SELECT create_hypertable('sensor_readings', 'time', chunk_time_interval => INTERVAL '1 week');

-- Continuous aggregate: pre-computed hourly averages (automatically refreshed)
CREATE MATERIALIZED VIEW hourly_avg
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket, sensor_id, AVG(temperature)
FROM sensor_readings
GROUP BY bucket, sensor_id;
```

### Retention Policies

Data from 2 years ago is rarely queried at full resolution. Retention policies automate:

1. **Raw data retention**: keep full-resolution data for 7 days → drop or archive.
2. **Downsampling**: aggregate 1-second readings into 1-minute averages → keep 1 year.
3. **Tiering**: recent data in hot storage (SSD); archived data in cold storage (blob).

**In InfluxDB:**
```
CREATE RETENTION POLICY "raw_7d" ON "iot_db" DURATION 7d REPLICATION 1 DEFAULT
CREATE RETENTION POLICY "hourly_1y" ON "iot_db" DURATION 365d REPLICATION 1
```

**In ADX (Kusto):** `.alter table SensorReadings policy retention softdelete = 90d`

### .NET Application Metrics Use Case

For ASP.NET Core applications, emitting metrics to a TSDB is standard:
- `System.Diagnostics.Metrics` (built-in .NET metrics API) → OpenTelemetry → Prometheus/ADX.
- `prometheus-net.AspNetCore` → expose `/metrics` endpoint → Prometheus scrapes every 15s.
- Azure Monitor Application Insights uses ADX under the hood.

## Code Example

```csharp
// .NET 8: writing sensor data to TimescaleDB (via Npgsql + Dapper)
// and querying with a time range + continuous aggregate

using Npgsql;
using Dapper;

var connectionString = "Host=localhost;Database=iot_db;Username=postgres;Password=secret";

await using var conn = new NpgsqlConnection(connectionString);
await conn.OpenAsync();

// Batch insert sensor readings (TimescaleDB handles time-partitioning automatically)
var readings = Enumerable.Range(0, 1000).Select(i => new SensorReading(
    Time: DateTime.UtcNow.AddSeconds(-i),
    SensorId: $"sensor-{i % 50}",
    Temperature: 20.0 + Random.Shared.NextDouble() * 10,
    Humidity: 50.0 + Random.Shared.NextDouble() * 20));

// Batch upsert — Npgsql binary import is fastest for bulk writes
await using var writer = await conn.BeginBinaryImportAsync(
    "COPY sensor_readings (time, sensor_id, temperature, humidity) FROM STDIN BINARY");

foreach (var r in readings)
{
    await writer.StartRowAsync();
    await writer.WriteAsync(r.Time,        NpgsqlTypes.NpgsqlDbType.TimestampTz);
    await writer.WriteAsync(r.SensorId,   NpgsqlTypes.NpgsqlDbType.Text);
    await writer.WriteAsync(r.Temperature, NpgsqlTypes.NpgsqlDbType.Double);
    await writer.WriteAsync(r.Humidity,   NpgsqlTypes.NpgsqlDbType.Double);
}
await writer.CompleteAsync();

// Time range query — only reads chunks within the window
var results = await conn.QueryAsync<SensorAgg>("""
    SELECT time_bucket('15 minutes', time) AS bucket,
           sensor_id,
           AVG(temperature) AS avg_temp,
           MAX(temperature) AS max_temp
    FROM sensor_readings
    WHERE time > NOW() - INTERVAL '1 hour'
      AND sensor_id = 'sensor-1'
    GROUP BY bucket, sensor_id
    ORDER BY bucket DESC
    """);

foreach (var r in results)
    Console.WriteLine($"{r.Bucket:HH:mm} | avg={r.AvgTemp:F1}°C max={r.MaxTemp:F1}°C");

// .NET 8 metrics → OpenTelemetry → can be pushed to any TSDB
using System.Diagnostics.Metrics;
using OpenTelemetry;
using OpenTelemetry.Metrics;

var meter = new Meter("MyApp.Api", "1.0");
var requestDuration = meter.CreateHistogram<double>("http.request.duration", "ms");

// Record metrics — OpenTelemetry pipeline exports to Prometheus/ADX
requestDuration.Record(42.5, new TagList { { "route", "/orders" }, { "method", "GET" } });

record SensorReading(DateTime Time, string SensorId, double Temperature, double Humidity);
record SensorAgg(DateTime Bucket, string SensorId, double AvgTemp, double MaxTemp);
```

## Common Follow-up Questions

- How does TimescaleDB's chunk architecture improve query performance compared to a plain PostgreSQL table?
- How do you implement continuous aggregates and retention policies together for a tiered storage approach?
- What is the difference between InfluxDB's line protocol and SQL-based TSDBs?
- How would you design the schema (tags vs fields in InfluxDB, or columns in TimescaleDB) to avoid high-cardinality explosion?
- How does Azure Data Explorer's KQL differ from SQL for time-series analysis?
- When would you use Application Insights vs a custom TimescaleDB for ASP.NET Core telemetry?

## Common Mistakes / Pitfalls

- **Storing time-series data in a relational table with no partitioning**: a 10-billion-row `sensor_readings` table without time-based partitioning requires full table scans for time range queries — catastrophically slow.
- **High-cardinality tags in InfluxDB**: each unique combination of tag values creates a new series. A `user_id` tag with 10 million users creates 10 million series — exceeding InfluxDB's cardinality limits and causing memory pressure.
- **Not setting retention policies**: without retention policies, a metrics database grows indefinitely. A single ASP.NET Core app emitting metrics every 15 seconds can produce gigabytes per day.
- **Querying without a time filter**: `SELECT * FROM sensor_readings WHERE sensor_id = 'x'` without a time filter scans all partitions/chunks — always include a time range in TSDB queries.
- **Using a TSDB for relational lookups**: TSDBs are append-only and not designed for JOIN operations or lookups by non-time keys. Store metadata (device names, owners) in a relational DB and join at the application layer.
- **Assuming OpenTelemetry metrics = TimescaleDB**: OpenTelemetry is the emission standard; you still need a backend (Prometheus, ADX, InfluxDB) to store and query the data.

## References

- [TimescaleDB documentation — hypertables and continuous aggregates](https://docs.timescale.com/use-timescale/latest/hypertables/)
- [Azure Data Explorer documentation](https://learn.microsoft.com/azure/data-explorer/data-explorer-overview)
- [InfluxDB 3 .NET client](https://github.com/InfluxCommunity/influxdb3-csharp)
- [OpenTelemetry .NET metrics](https://learn.microsoft.com/dotnet/core/diagnostics/distributed-tracing-instrumentation-walkthroughs)
- [prometheus-net for ASP.NET Core](https://github.com/prometheus-net/prometheus-net)
