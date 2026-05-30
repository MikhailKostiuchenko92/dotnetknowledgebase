# Database Connection Pooling

**Category:** System Design / Data Storage
**Difficulty:** 🔴 Senior
**Tags:** `connection-pooling`, `ADO.NET`, `EF-Core`, `pgBouncer`, `pool-sizing`, `connection-leaks`, `async`

## Question

> How does database connection pooling work in .NET? How do you size a connection pool, detect connection leaks, and what role does async/await play? When do you need an external pooler like pgBouncer?

## Short Answer

ADO.NET maintains a pool of open database connections per unique connection string. When `OpenAsync()` is called, a connection is checked out from the pool rather than establishing a new TCP connection; when `Dispose()` is called, it's returned. Pool size should be tuned based on workload: too small causes queuing, too large causes DB-side resource exhaustion. `async`/`await` is critical because it releases the thread while waiting for I/O but holds the connection — shorter connection hold times enable higher throughput. External poolers (pgBouncer) handle server-side connection limits and are essential for high-concurrency microservices targeting PostgreSQL.

## Detailed Explanation

### How ADO.NET Connection Pooling Works

When you call `new SqlConnection(connectionString)` in .NET, ADO.NET maintains a **pool per unique connection string** (including server, database, credentials). On `OpenAsync()`:

1. Check the pool for an idle connection with matching connection string.
2. If found → return it immediately (sub-millisecond).
3. If not found and pool not at `MaxPoolSize` → create a new physical connection (~5–50ms depending on network).
4. If pool is at `MaxPoolSize` → wait up to `Connection Timeout` seconds → throw `InvalidOperationException("Timeout expired... pool")`.

On `Dispose()` / `Close()`: the physical connection is returned to the pool (not actually closed), reset to a clean state, and made available for the next caller.

### Pool Configuration

Connection string parameters (SQL Server):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Min Pool Size` | 0 | Connections kept alive when idle |
| `Max Pool Size` | 100 | Maximum concurrent connections in pool |
| `Connection Timeout` | 15s | Time to wait for a pooled connection |
| `Connection Lifetime` | 0 (unlimited) | Max age before a connection is evicted |

```
"Server=db;Database=App;Min Pool Size=5;Max Pool Size=50;Connection Timeout=10"
```

### Pool Sizing Formula

A common starting point:

```
Max Pool Size ≈ (number of CPU cores on DB server) × 2 + effective spindle count
```

But in practice, for I/O-bound workloads: measure empirically. Too-small pool → requests queue. Too-large pool → DB memory/CPU exhaustion and context-switch overhead.

**Rule of thumb for SQL Server**: start at 50–100 per application instance. For PostgreSQL (no internal pooling architecture), start at 10–20 per app instance and use pgBouncer.

### Connection Leaks

A connection leak occurs when a `SqlConnection` is opened but never closed (e.g., exception thrown before `Dispose()` is called).

```csharp
// ❌ LEAK: exception before dispose returns connection to limbo
var conn = new SqlConnection(cs);
conn.Open();
throw new Exception("oops");  // connection never returned to pool
conn.Dispose();               // unreachable
```

Symptoms:
- Pool exhaustion timeout errors (`"The timeout period elapsed prior to obtaining a connection"`)
- Growing active connection count on the DB server
- Memory growth in the application process

Fix: always use `using` or `await using`:
```csharp
await using var conn = new SqlConnection(cs);
await conn.OpenAsync(ct);
// ... dispose called automatically even if exception thrown
```

EF Core's `DbContext.Dispose()` returns the connection to the pool; in ASP.NET Core, `AddDbContext` registers DbContext as `Scoped` → disposed at request end → no leak.

### Async/Await and Connections

A connection is **held open** for the duration of `conn.OpenAsync()` through to `conn.Dispose()`. With synchronous code, the thread is also blocked during I/O. With async:

- The thread is freed while awaiting I/O (e.g., waiting for a query response).
- But the connection is still checked out from the pool.
- Higher throughput because threads are freed, but pool sizing still matters.

> **Important**: `async`/`await` reduces thread consumption but does NOT reduce connection consumption. A pool of size 10 handles 10 concurrent DB operations regardless of whether they're async or sync.

### pgBouncer: External Pooler for PostgreSQL

PostgreSQL creates one OS process per connection — expensive. A PostgreSQL instance with 100 client connections spawns 100 processes. At 500 connections, memory pressure and context switching degrade performance.

pgBouncer sits between application and DB as a connection multiplexer:

```
App instances (1000 concurrent → 1000 logical connections)
         ↓
     pgBouncer (pool: 50 real connections)
         ↓
PostgreSQL (50 server processes)
```

pgBouncer modes:
- **Session pooling**: 1 real connection per client session (minimal benefit).
- **Transaction pooling**: real connection checked out per transaction, returned immediately after commit/rollback. **(Recommended)** — allows 1000 clients to share 50 connections.
- **Statement pooling**: per statement; incompatible with prepared statements.

> **Note:** Transaction pooling is incompatible with features that span transactions: `SET` session variables, advisory locks, `LISTEN/NOTIFY`, temp tables. Avoid these when using pgBouncer transaction mode.

SQL Server has built-in server-side connection pooling (threads not processes), so pgBouncer-equivalent tooling is less commonly needed — but Azure SQL's per-vCore connection limits can still necessitate an application-level proxy.

## Code Example

```csharp
// .NET 8 — connection pool configuration, leak prevention, pool monitoring

using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

// ── Connection string with explicit pool settings ─────────────────────
var connectionString =
    "Server=sqlserver;Database=AppDb;User Id=app;Password=secret;" +
    "Min Pool Size=5;" +      // keep 5 connections warm at all times
    "Max Pool Size=50;" +     // cap at 50 — tune based on DB server capacity
    "Connection Timeout=10;" + // fail fast if pool is exhausted
    "Connection Lifetime=300"; // evict connections after 5 min (handles failovers)

// ── EF Core: pool is managed transparently ────────────────────────────
builder.Services.AddDbContextPool<AppDbContext>(options =>
    options.UseSqlServer(connectionString),
    poolSize: 128);   // DbContextPool reuses DbContext instances (not the same as connection pool)

// ── Manual connection: always use await using ─────────────────────────
app.MapGet("/count", async (CancellationToken ct) =>
{
    await using var conn = new SqlConnection(connectionString);  // checked out from pool
    await conn.OpenAsync(ct);                                    // fast if pool has idle connections

    await using var cmd = new SqlCommand("SELECT COUNT(*) FROM Orders", conn);
    var count = (int)(await cmd.ExecuteScalarAsync(ct))!;

    return Results.Ok(count);
    // conn.Dispose() called here → returned to pool (NOT physically closed)
});

// ── Pool exhaustion detection ─────────────────────────────────────────
// Monitor via SQL Server DMV: sys.dm_exec_connections
// Or via .NET EventCounters:
using System.Diagnostics.Tracing;

// Subscribe to ADO.NET event counters
var listener = new EventListener();
listener.EventSourceCreated += (s, e) =>
{
    if (e.EventSource?.Name == "Microsoft.Data.SqlClient.EventSource")
        listener.EnableEvents(e.EventSource!, EventLevel.Informational,
            EventKeywords.None, new Dictionary<string, string?> { ["EventCounterIntervalSec"] = "5" });
};
listener.EventWritten += (s, e) =>
{
    if (e.EventName == "EventCounters" && e.Payload is not null)
    {
        // payload contains: active-hard-connections, active-soft-connections, pool-groups, etc.
        Console.WriteLine($"Pool event: {e.EventName}");
    }
};

// ── pgBouncer connection string (looks like a regular PG connection) ──
// Application connects to pgBouncer (port 6432), not directly to PostgreSQL (5432)
var pgBouncer = "Host=pgbouncer-host;Port=6432;Database=AppDb;Username=app;Password=secret;" +
                "Pooling=true;MinPoolSize=2;MaxPoolSize=20";
// Npgsql pool size should be small (20) — pgBouncer multiplexes internally
```

## Common Follow-up Questions

- How do you detect connection pool exhaustion in production, and what do you do when it occurs?
- What is `DbContextPool` in EF Core and how does it differ from the underlying ADO.NET connection pool?
- How does Azure SQL's connection limit per service tier affect pool sizing?
- What is the difference between pgBouncer's session, transaction, and statement pooling modes?
- How do you handle connection pool warm-up on application startup to avoid cold-start latency spikes?
- When would you use `NpgsqlDataSource` (Npgsql 7+) instead of connection string-based pooling?

## Common Mistakes / Pitfalls

- **Not disposing connections**: the most common source of pool exhaustion. Always `await using var conn = new ...` or rely on EF Core's scoped `DbContext`.
- **Opening connections too early and holding them too long**: fetching a connection before a slow validation step (external API call, computation) holds the connection idle. Open as late as possible, close as early as possible.
- **Pool size too large for the DB server**: 100 app instances × 100 connections = 10,000 connections. SQL Server may handle this, but PostgreSQL with 10,000 processes will OOM the server. Use pgBouncer or drastically reduce per-instance pool size.
- **Different connection strings creating separate pools**: `Server=db;User=app` and `Server=DB;user=APP` are different strings → different pools. Use a connection string builder to normalise values.
- **EF Core `DbContextPool` confused with connection pool**: `AddDbContextPool` reuses `DbContext` instances (resetting tracked entities between requests). It's an additional optimisation layer on top of ADO.NET's connection pool, not a replacement.
- **Ignoring `Connection Lifetime`**: in cloud environments, DB IP addresses change during failovers. Without a `Connection Lifetime`, connections created before a failover continue using the old IP and fail silently until the pool is exhausted.

## References

- [SQL Server connection pooling (ADO.NET)](https://learn.microsoft.com/dotnet/framework/data/adonet/sql-server-connection-pooling)
- [Npgsql connection pooling documentation](https://www.npgsql.org/doc/connection-string-parameters.html)
- [pgBouncer documentation](https://www.pgbouncer.org/config.html)
- [EF Core DbContext pooling](https://learn.microsoft.com/ef/core/performance/advanced-performance-topics#dbcontext-pooling)
- [Azure SQL connection limits per service tier](https://learn.microsoft.com/azure/azure-sql/database/resource-limits-logical-server)
