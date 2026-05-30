# Change Data Capture

**Category:** System Design / Data Pipelines
**Difficulty:** Senior
**Tags:** `cdc`, `debezium`, `sql-server-ct`, `outbox`, `event-streaming`, `replication`

## Question

> What is Change Data Capture (CDC)? How does it work at the database level? What are the use cases and how do you integrate it with a downstream event streaming system like Kafka? How does CDC compare to polling and to the Outbox pattern?

- How does Debezium capture changes from PostgreSQL and SQL Server?
- What are the ordering and latency guarantees of CDC?

## Short Answer

CDC captures row-level changes (INSERT, UPDATE, DELETE) from a database's transaction log, converting them into an ordered stream of change events without modifying the application. It is ideal for feeding changes from operational databases to analytics pipelines, read models, or other services with minimal latency (seconds) and no application coupling. Debezium is the standard open-source CDC tool that reads database WAL/binlog/CT and publishes to Kafka. Compared to polling, CDC is lower latency and doesn't miss deletes; compared to the Outbox pattern, CDC doesn't require application code changes but captures all table changes, not just intentional domain events.

## Detailed Explanation

### How CDC Works

Every transactional database maintains a transaction log for crash recovery:
- **PostgreSQL**: Write-Ahead Log (WAL)
- **SQL Server**: Transaction Log + Change Tracking / Change Data Capture tables
- **MySQL/MariaDB**: Binary Log (binlog)

CDC reads this log and produces a stream of change events:

```
Application writes:
  UPDATE orders SET status = 'Shipped' WHERE id = 'order-123'
  ↓
Database transaction log records:
  LSN 12345: UPDATE orders, pk=order-123, before={status:'Processing'}, after={status:'Shipped'}
  ↓
CDC connector reads WAL:
  Emits: { op: "u", table: "orders", before: {...}, after: {...}, lsn: 12345, ts: ... }
  ↓
Published to Kafka topic: dbserver1.public.orders
```

### Debezium Architecture

```
PostgreSQL (WAL) ──► Debezium PostgreSQL Connector ──► Kafka topic: db.orders
SQL Server (CT)  ──► Debezium SQL Server Connector  ──► Kafka topic: db.orders
                                │
                    Kafka Connect (distributed)
                    (runs as a cluster of workers)
```

Debezium runs inside **Kafka Connect** — a framework for scalable, fault-tolerant connectors. It uses a replication slot (PostgreSQL) or CT tables (SQL Server) to read changes.

**Event envelope format** (Debezium):
```json
{
  "op": "u",            // "c"=create, "u"=update, "d"=delete, "r"=read (snapshot)
  "source": { "table": "orders", "lsn": 12345, "ts_ms": 1700000000000 },
  "before": { "id": "order-123", "status": "Processing", "total": 9900 },
  "after":  { "id": "order-123", "status": "Shipped",    "total": 9900 }
}
```

### PostgreSQL CDC Setup

```sql
-- Postgres: enable logical replication for CDC
-- postgresql.conf:
wal_level = logical
max_replication_slots = 5

-- Create a replication slot (Debezium does this automatically)
SELECT pg_create_logical_replication_slot('debezium_orders', 'pgoutput');

-- Grant replication role to Debezium user
CREATE USER debezium_user WITH REPLICATION PASSWORD '...';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium_user;
```

Debezium connector configuration:
```json
{
  "name": "orders-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres-host",
    "database.port":     "5432",
    "database.user":     "debezium_user",
    "database.password": "${file:/secrets.properties:password}",
    "database.dbname":   "orders",
    "topic.prefix":      "db",
    "table.include.list": "public.orders,public.order_lines",
    "publication.name":  "dbz_publication",
    "slot.name":         "debezium_orders"
  }
}
```

### SQL Server Change Tracking vs CDC

SQL Server offers two mechanisms:

| | Change Tracking (CT) | Change Data Capture (CDC) |
|--|---------------------|--------------------------|
| What it captures | Which rows changed (no before/after) | Full before/after row images |
| Log storage | Minimal (row version only) | More (full row data) |
| Latency | Near-real-time | Near-real-time |
| Use case | Sync detection (pull model) | Stream all changes (push model) |

```sql
-- SQL Server: enable CDC on a table
EXEC sys.sp_cdc_enable_db;

EXEC sys.sp_cdc_enable_table
  @source_schema = 'dbo',
  @source_name   = 'orders',
  @role_name     = NULL,
  @captured_column_list = NULL;   -- all columns

-- CDC creates shadow tables: cdc.dbo_orders_CT
SELECT * FROM cdc.dbo_orders_CT
WHERE __$operation IN (1,2,3,4)  -- 1=delete, 2=insert, 3=before update, 4=after update
  AND __$start_lsn > @lastLsn
ORDER BY __$start_lsn;
```

### .NET: Consuming CDC Events from Kafka

A .NET service consuming Debezium CDC events to update a read model:

```csharp
using Confluent.Kafka;
using System.Text.Json;

// Deserialise Debezium envelope
public sealed record DebeziumEnvelope<T>(
    string Op,    // "c", "u", "d", "r"
    T? Before,
    T? After,
    DebeziumSource Source);

public sealed record DebeziumSource(string Table, long TsMs, long Lsn);

// Consumer updating a read model projection
public sealed class OrdersCdcConsumer(IOrderReadModelRepository readModel) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
        {
            BootstrapServers = "kafka:9092",
            GroupId          = "orders-cdc-projector",
            AutoOffsetReset  = AutoOffsetReset.Earliest,
            EnableAutoCommit = false,
        }).Build();

        consumer.Subscribe("db.public.orders");

        while (!ct.IsCancellationRequested)
        {
            var result = consumer.Consume(ct);
            var envelope = JsonSerializer.Deserialize<DebeziumEnvelope<OrderRow>>(result.Message.Value)!;

            switch (envelope.Op)
            {
                case "c" or "r":
                    await readModel.UpsertAsync(envelope.After!, ct);
                    break;
                case "u":
                    await readModel.UpsertAsync(envelope.After!, ct);
                    break;
                case "d":
                    await readModel.DeleteAsync(envelope.Before!.Id, ct);
                    break;
            }

            consumer.Commit(result);
        }
    }
}
```

### CDC vs Polling vs Outbox

| | Polling | Outbox Pattern | CDC |
|--|---------|---------------|-----|
| Captures deletes | No (unless soft-delete) | App must write delete event | Yes |
| Application code changes | Yes (write `updated_at`) | Yes (write to outbox table) | **No** |
| Latency | Seconds–minutes | Seconds | Seconds |
| Misses events | Possible (race conditions) | No (transactional) | No |
| Domain event semantics | No (raw table diff) | Yes (intentional events) | **No** (raw table diff) |
| Event ordering | Not guaranteed | Guaranteed (per row) | Guaranteed (per table, by LSN) |

**Choose CDC when**: you need to feed changes from an existing database to downstream consumers without modifying the application, or you need to capture all row-level changes (including from legacy apps, batch jobs, migrations).

**Choose Outbox when**: you need clean domain events with business semantics and control over what gets published.

> **Warning:** CDC replication slots (PostgreSQL) accumulate WAL segments if the consumer falls behind. A stalled Debezium connector will cause the PostgreSQL WAL to grow unboundedly until the disk fills. Monitor replication slot lag with `pg_replication_slots` and alert if `pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) > 1GB`.

## Code Example

```sql
-- Monitor CDC replication slot health in PostgreSQL
SELECT
    slot_name,
    active,
    pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag_pretty
FROM pg_replication_slots
WHERE slot_type = 'logical';
-- Alert if lag_bytes > 500MB — Debezium may be falling behind
```

```csharp
// Register CDC health check in ASP.NET Core
builder.Services.AddHealthChecks()
    .AddCheck("cdc-lag", async (ct) =>
    {
        var lag = await _db.Database
            .SqlQueryRaw<long>("""
                SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)
                FROM pg_replication_slots WHERE slot_name = 'debezium_orders'
                """)
            .FirstOrDefaultAsync(ct);

        return lag < 100_000_000  // 100 MB
            ? HealthCheckResult.Healthy($"CDC lag: {lag:N0} bytes")
            : HealthCheckResult.Degraded($"CDC lag high: {lag:N0} bytes");
    }, tags: ["ready"]);
```

## Common Follow-up Questions

- How do you handle schema evolution in CDC — what happens when a column is added or renamed?
- How does the initial snapshot (full table read) work when first setting up Debezium?
- What is Kafka Connect's exactly-once delivery mode and when is it needed for CDC?
- How do you implement CDC for a sharded database where data is split across multiple instances?
- How does CDC interact with soft-delete patterns (rows marked `deleted_at` vs physically deleted)?

## Common Mistakes / Pitfalls

- **Not monitoring replication slot lag**: an unmonitored stalled CDC consumer causes WAL to grow until disk is full — a P0 production incident.
- **Treating CDC events as domain events**: CDC events are table-level diffs — they contain raw column values, not business intent. Build a translation layer to convert them to meaningful domain events if needed downstream.
- **Publishing all tables**: CDC can easily overwhelm Kafka with high-volume tables (clickstream, audit log); be selective about which tables to capture.
- **Ignoring the initial snapshot**: the first run of Debezium reads the entire table as "read" (op = "r") events; ensure your consumer handles this without creating duplicate records.
- **Missing schema registry**: CDC event schemas evolve with the database schema; use Confluent Schema Registry with Avro or JSON Schema to manage schema compatibility.

## References

- [Debezium documentation](https://debezium.io/documentation/)
- [PostgreSQL logical replication — Debezium](https://debezium.io/documentation/reference/stable/connectors/postgresql.html)
- [SQL Server CDC — Debezium](https://debezium.io/documentation/reference/stable/connectors/sqlserver.html)
- [Outbox pattern with Debezium (log mining)](https://debezium.io/documentation/reference/stable/transformations/outbox-event-router.html)
- [See: outbox-pattern.md](./outbox-pattern.md)
- [See: kafka-fundamentals.md](./kafka-fundamentals.md)
