# ADO.NET Connection Pooling

**Category:** Data Access / ADO.NET
**Difficulty:** 🟡 Middle
**Tags:** `ADO.NET`, `connection-pooling`, `SqlConnection`, `pool-exhaustion`, `Max-Pool-Size`, `Azure-SQL`, `connection-string`

## Question

> How does ADO.NET's connection pool work? What causes pool exhaustion, how do you diagnose it, and what are the key connection string settings to tune for production and Azure SQL workloads?

## Short Answer

ADO.NET maintains a per-connection-string pool of reusable physical TCP connections to the database. When you call `conn.Open()`, ADO.NET either returns an idle connection from the pool or creates a new one (up to `Max Pool Size`). When you `conn.Dispose()`, the connection is returned to the pool — not physically closed. Pool exhaustion occurs when all connections are in use and no new ones can be created (pool size limit hit) — callers block until a connection is freed or timeout. Key settings: `Max Pool Size` (default 100), `Min Pool Size` (pre-allocated connections), `Connect Timeout`, and `Connection Lifetime`.

## Detailed Explanation

### How the Pool Works

```
First request:
  conn.Open() → pool empty → create new TCP connection to SQL Server (expensive: ~5–50ms)

Subsequent requests:
  conn.Open() → pool has idle connection → return it (cheap: < 1ms)

conn.Dispose() → don't close TCP → mark as idle, return to pool

Pool limit hit:
  conn.Open() → all 100 connections in use → block for Connect Timeout seconds
  If no connection freed in time → SqlException: "Timeout expired. The timeout period elapsed
  prior to obtaining a connection from the pool."
```

### Pool Key — Connection String Exact Match

The pool is keyed by the exact connection string (including whitespace and case). Two slightly different strings create two separate pools:

```csharp
// ❌ Creates TWO separate pools — both pool up to 100 connections
new SqlConnection("Server=.;Database=MyDb;Integrated Security=True");
new SqlConnection("Server=.;Database=MyDb;Integrated Security=true");  // lowercase 'true'
// Normalize connection strings to avoid unintentional pool fragmentation
```

### Connection String Settings

```
Server=myserver;Database=MyDb;User Id=user;Password=pass;
  Min Pool Size=5;         -- pre-warm N connections at startup
  Max Pool Size=100;       -- maximum pool size (default: 100)
  Connect Timeout=30;      -- seconds to wait for a connection (default: 15 for SQL auth)
  Connection Lifetime=0;   -- seconds before a connection is retired (0 = never)
  Pooling=true;            -- enable pooling (default: true)
  Encrypt=True;            -- required for Azure SQL
  TrustServerCertificate=False;  -- for production; True for local dev only
```

### Azure SQL Specifics

Azure SQL has its own connection limits based on the service tier:

| Service Tier | Max Connections |
|-------------|----------------|
| Basic (5 DTU) | 30 |
| Standard S0 | 60 |
| Standard S2 | 120 |
| General Purpose 2 vCores | ~300 |
| Business Critical 4 vCores | ~2000 |

> **Recommendation for Azure SQL:** Set `Max Pool Size` to no more than ~80% of the Azure tier's connection limit to leave headroom for Azure's own internal connections. Also set `Connection Lifetime=300` to recycle connections after 5 minutes — Azure SQL occasionally closes idle connections unilaterally.

### Pool Exhaustion — Diagnosis

**Symptoms:** `SqlException: Timeout expired. The timeout period elapsed prior to obtaining a connection from the pool.`

**Diagnosis:**

```csharp
// Add performance counter logging (Windows only)
// Or use Application Insights / OpenTelemetry with DbConnection events

// Quick check in code: get current pool stats
var connString = new SqlConnectionStringBuilder(_connStr)
{
    Pooling = true
}.ConnectionString;

// More practically: look for SqlException with "pool" in message
catch (SqlException ex) when (ex.Message.Contains("pool"))
{
    logger.LogCritical("Connection pool exhausted: {Message}", ex.Message);
}
```

**Common causes:**
1. Not disposing connections (`using` block missing).
2. Long-running queries holding connections for seconds/minutes.
3. `Max Pool Size` too low for concurrent load.
4. DbContext not scoped properly (singleton DbContext in web app).
5. Background jobs that open many connections without pooling.

### Pool Reset on Return

When a connection is returned to the pool, ADO.NET **resets** it:
- Clears any active transaction (rolls back uncommitted transactions).
- Resets SET options (isolation level, NOCOUNT, etc.) to connection defaults.
- Clears any temp tables created in `#TempTable` scope.

This reset is done via `sp_reset_connection` — a lightweight SQL Server command.

## Code Example

```csharp
// Correct pattern — guaranteed return to pool even on exception
public async Task<int> GetOrderCountAsync(CancellationToken ct)
{
    await using var conn = new SqlConnection(_connStr);  // ← await using ensures disposal
    await conn.OpenAsync(ct);
    await using var cmd = conn.CreateCommand();
    cmd.CommandText = "SELECT COUNT(*) FROM Orders WHERE Status = 'Pending'";
    return Convert.ToInt32(await cmd.ExecuteScalarAsync(ct));
}
// conn.DisposeAsync() called here → returns to pool

// Pool exhaustion prevention: check for leaked connections in integration tests
public static class SqlConnectionDiagnostics
{
    public static void LogPoolStats(string connStr)
    {
        // Using System.Data.SqlClient performance counters (Windows)
        // Or: measure via OpenTelemetry DbConnection instrumentation
        using var conn = new SqlConnection(connStr);
        // conn.StatisticsEnabled = true (available in Microsoft.Data.SqlClient)
        // ... open, execute, close
        // var stats = conn.RetrieveStatistics();
        // logger.Log stats["ConnectionPoolMisses"], stats["ConnectionPoolHits"]
    }
}

// appsettings: Azure SQL production connection string with tuned pool settings
// "Default": "Server=tcp:myserver.database.windows.net,1433;Database=MyDb;
//   Authentication=Active Directory Default;Encrypt=True;
//   Min Pool Size=5;Max Pool Size=80;Connect Timeout=30;Connection Lifetime=300;"
```

## Common Follow-up Questions

- How do you disable connection pooling for a specific scenario (e.g., integration tests)?
- What is the difference between `Connection Lifetime` and `Connection Timeout`?
- How does `MultipleActiveResultSets=True` (MARS) affect connection pooling?
- What happens to a transaction if a connection times out mid-operation and is returned to the pool?
- How does Azure SQL's connection throttling (error 40613) interact with connection pooling?

## Common Mistakes / Pitfalls

- **Not disposing `SqlConnection`**: Connections not returned to the pool accumulate. After `Max Pool Size` connections are leaked, all new requests block until timeout. Always use `await using var conn = new SqlConnection(...)`.
- **Using `SqlConnection` as a singleton or static field**: A single connection can't handle concurrent requests (not thread-safe). Always create a new connection per operation and let the pool manage reuse.
- **Setting `Max Pool Size` too high**: On Azure SQL or shared databases, setting `Max Pool Size=1000` when the tier allows only 120 connections causes the pool to hit the server limit, not the pool limit — resulting in `SqlException` from the server instead of a pool timeout.
- **Different connection strings for same database**: Any difference (user, port, Encrypt value) creates a separate pool. Review all registered connection strings across services to ensure they match.
- **`Pooling=False` in production**: Disabling pooling means every `conn.Open()` creates a new TCP connection (~50ms) and `conn.Dispose()` physically closes it. Under moderate load this adds seconds of overhead per request.

## References

- [SQL Server connection pooling — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql-server-connection-pooling)
- [SqlConnectionStringBuilder — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.data.sqlclient.sqlconnectionstringbuilder)
- [Azure SQL connection limits — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-logical-server)
- [See: adonet-overview.md](./adonet-overview.md)
- [See: dbcontext-pooling.md](./dbcontext-pooling.md)
