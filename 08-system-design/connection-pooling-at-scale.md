# Connection Pooling at Scale

**Category:** System Design / Performance
**Difficulty:** Middle
**Tags:** `connection-pooling`, `http`, `grpc`, `database`, `kestrel`, `sockets`

## Question

> How does connection pooling work for HTTP, gRPC, and database connections? What are the correct pool size formulas? What goes wrong when pools are misconfigured at scale?

- How does `SocketsHttpHandler` pool HTTP connections in .NET?
- What is the database pool size formula and why does more connections sometimes hurt?

## Short Answer

Connection pooling reuses established TCP/TLS connections, avoiding the cost of handshake and authentication on every request. `HttpClient` / `SocketsHttpHandler` pools HTTP/1.1 connections per host (keep-alive) and multiplexes hundreds of streams over a single HTTP/2 connection (gRPC). Database pools (ADO.NET / EF Core) maintain a set of open database connections; the optimal pool size is usually `(number of CPU cores × 2) + effective spindle count`, not "as many as possible" — over-provisioned pools saturate the database server. Connection exhaustion is a common high-traffic failure mode: every request blocks waiting for a free connection.

## Detailed Explanation

### HTTP Connection Pooling (`SocketsHttpHandler`)

.NET's `SocketsHttpHandler` (used by `HttpClient` internally since .NET 5) maintains a connection pool per `(scheme, host, port)` tuple.

| Setting | Default | Purpose |
|---------|---------|---------|
| `PooledConnectionLifetime` | ∞ | Max age before connection is recycled (avoids DNS staleness) |
| `PooledConnectionIdleTimeout` | 1 min | Remove idle connections from pool |
| `MaxConnectionsPerServer` | ∞ | Cap concurrent connections per host |
| `ConnectTimeout` | OS default | How long to wait to establish a TCP connection |

**Critical rule**: a single `HttpClient` instance (or `IHttpClientFactory` named client) should be reused for the lifetime of the application. Each `new HttpClient()` creates a new socket pool and exhausts ephemeral ports.

```csharp
// Correct: singleton SocketsHttpHandler with explicit settings
builder.Services.AddHttpClient("payment-api", client =>
    client.BaseAddress = new Uri("https://payments.internal"))
    .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
    {
        PooledConnectionLifetime = TimeSpan.FromMinutes(2), // recycle DNS staleness
        PooledConnectionIdleTimeout = TimeSpan.FromMinutes(1),
        MaxConnectionsPerServer = 100,          // cap per destination
        EnableMultipleHttp2Connections = true,  // multiple H2 connections for gRPC
    });
```

### HTTP/2 and gRPC Multiplexing

HTTP/2 multiplexes multiple streams over one TCP connection. A single connection handles up to 100 concurrent gRPC streams (default `MaxConcurrentStreams = 100` per connection). Under very high load, enable multiple HTTP/2 connections:

```csharp
.ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
{
    EnableMultipleHttp2Connections = true, // allows >1 H2 conn per host
})
```

This is essential when a single gRPC channel's 100-stream limit becomes a bottleneck.

### Database Connection Pooling (ADO.NET / EF Core)

ADO.NET pools connections by connection string. When `Open()` is called, a connection is drawn from the pool (or created if below `Max Pool Size`). `Close()` returns it to the pool, not to the database server.

**Key connection string params**:
- `Min Pool Size` (default: 0): warm connections kept alive
- `Max Pool Size` (default: 100): hard cap; requests block when full
- `Connection Timeout` (default: 15 s): how long to wait for a free pool slot

```
Connection string: "...;Min Pool Size=5;Max Pool Size=50;Connection Timeout=30"
```

### Database Pool Sizing Formula

The famous formula from pgBouncer / Postgres documentation:

```
Optimal pool size = (number of effective cores × 2) + number of storage spindles
```

For a 4-core SSD database server: `(4 × 2) + 1 = 9`. Start at 10, benchmark, and adjust.

**Why not 1000 connections?**

Each Postgres connection spawns a backend process (~5–10 MB RAM). At 1000 connections:
- 5–10 GB RAM consumed by connection processes
- OS context-switch overhead on every query
- Lock contention increases with more concurrent transactions

The database becomes slower as connections increase beyond the optimal point. Use a **connection pooler** (PgBouncer, pgpool-II, SQL Server's built-in pool) in front of the database to fan out many application connections to a small number of actual database connections.

```
Application pods (500 instances × 50 pool = 25,000 potential connections)
         ↓
    PgBouncer (transaction-mode pooling)
         ↓
    PostgreSQL (actual connections: 50–100)
```

### Kestrel Connection Limits

ASP.NET Core Kestrel limits inbound connections:

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxConcurrentConnections        = 10_000; // total open connections
    options.Limits.MaxConcurrentUpgradedConnections = 1_000; // WebSocket/HTTP upgrade
    options.Limits.MaxRequestBodySize              = 10 * 1024 * 1024; // 10 MB
    options.Limits.RequestHeadersTimeout           = TimeSpan.FromSeconds(30);
    options.Limits.KeepAliveTimeout                = TimeSpan.FromSeconds(120);
});
```

### Diagnosing Connection Pool Exhaustion

Signs: `ConnectionPool was exhausted after waiting 30 seconds` errors; request latency spikes in bursts with no CPU increase.

```csharp
// Monitor pool health — .NET 8 built-in metrics
// SqlClient emits: db.client.connections.usage (active), db.client.connections.idle
// Monitor via OpenTelemetry + Prometheus

// Or diagnostic listener for ADO.NET
DiagnosticListener.AllListeners.Subscribe(new SqlClientDiagnosticObserver());
```

Quick checks:
1. Are pool sizes appropriate for your QPS? (QPS × avg_latency_s = connections needed)
2. Is a long-running transaction holding a connection? Check `sys.dm_exec_sessions` / `pg_stat_activity`.
3. Are connections being returned? Check for missing `using` / `await using` on `DbConnection`.

> **Warning:** `await using var conn = await dataSource.OpenConnectionAsync()` must always be in a `using` block. A single leaked connection (exception before `Dispose()`) counts against the pool until the GC finalises it — potentially hours later under low memory pressure.

## Code Example

```csharp
// EF Core + Npgsql with explicit pool tuning
using Npgsql;

var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
dataSourceBuilder.UseLoggerFactory(loggerFactory);

// Npgsql connection pool settings
var dataSource = dataSourceBuilder.Build();

builder.Services.AddDbContextPool<AppDbContext>(options =>
{
    options.UseNpgsql(dataSource, npgsql =>
    {
        npgsql.CommandTimeout(30);
        npgsql.EnableRetryOnFailure(3, TimeSpan.FromSeconds(1), null);
    });
    // DbContextPool size should match your expected concurrency, not pool size
}, poolSize: 256); // max DbContext instances in the pool — tune to concurrency, not DB pool

// Separately, configure Npgsql connection pool in connection string:
// "Host=db;Database=app;Username=app;Password=secret;
//  Minimum Pool Size=5;Maximum Pool Size=50;Connection Idle Lifetime=300"

// For high-traffic APIs: health check on pool saturation
builder.Services.AddHealthChecks()
    .AddNpgSql(connectionString,
        name: "postgres",
        tags: ["ready"],
        timeout: TimeSpan.FromSeconds(3));
```

## Common Follow-up Questions

- What is `DbContextPool` and how does it differ from the ADO.NET connection pool?
- How do you correctly configure connection pooling when running 100 Docker containers each with their own EF Core pool?
- What is the difference between PgBouncer's transaction-mode and session-mode pooling?
- How do you detect a connection leak in production without restarting the service?
- How does HTTP/2's `MaxConcurrentStreams` interact with gRPC load balancing when one connection fills up?

## Common Mistakes / Pitfalls

- **Creating a new `HttpClient` per request**: creates a new socket pool per request; exhausts ephemeral ports (TIME_WAIT state) under load. Always use `IHttpClientFactory` or a singleton.
- **Setting `Max Pool Size = 1000`**: over-provisioning hammers the database; follow the CPU × 2 formula and use PgBouncer if you need many application connections.
- **Forgetting `PooledConnectionLifetime` on `SocketsHttpHandler`**: connections older than the DNS TTL serve stale IPs after a blue-green deployment or pod restart.
- **Connection pool timeouts swallowed as generic exceptions**: catch `InvalidOperationException` with message "Timeout expired" separately — it signals pool exhaustion, not a query error.
- **Not disposing `DbConnection` objects**: every leaked connection counts against the pool. Use `await using` for all `DbConnection`, `DbCommand`, and `DbDataReader` objects.

## References

- [SocketsHttpHandler — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.net.http.socketshttphandler)
- [IHttpClientFactory best practices — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/httpclient-factory)
- [Npgsql Connection String Parameters](https://www.npgsql.org/doc/connection-string-parameters.html)
- [PgBouncer Documentation](https://www.pgbouncer.org/usage.html)
- [See: async-io-and-throughput.md](./async-io-and-throughput.md)
- [See: database-connection-pooling.md](./database-connection-pooling.md)
