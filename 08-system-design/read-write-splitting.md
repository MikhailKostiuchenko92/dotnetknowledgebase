# Read-Write Splitting

**Category:** System Design / Data Storage
**Difficulty:** 🔴 Senior
**Tags:** `read-write-splitting`, `CQRS`, `read-replica`, `replication-lag`, `query-routing`, `EF-Core`, `consistency`

## Question

> How do you design read-write splitting in a distributed system? What are the consistency pitfalls of routing reads to replicas? How does CQRS relate to read-write splitting?

## Short Answer

Read-write splitting routes writes to the primary database and reads to one or more replicas, increasing read throughput without increasing write load on the primary. The core challenge is replication lag — reads from replicas may see stale data, violating read-your-writes and monotonic-read consistency. CQRS (Command Query Responsibility Segregation) formalises this at the architecture level: commands (writes) go to the write model, queries go to a separately optimised read model, which may be a replica, a denormalised projection, or a different database technology entirely.

## Detailed Explanation

### Basic Read-Write Splitting

Traffic is classified at the application level:

```
Writes (INSERT/UPDATE/DELETE) → Primary DB
Reads  (SELECT)                → Read Replica(s)
```

This improves read throughput because:
- Replicas share the read load.
- Replicas can be scaled independently of the primary.
- Read-heavy queries (reporting, search) don't compete with writes on the same I/O paths.

### Consistency Pitfalls

#### 1. Read-Your-Writes Violation
```
User writes profile photo → Primary
User reloads page → reads from replica (still has old photo) → stale!
```

**Solutions:**
- Route reads to primary for 1–2 seconds after a write (time-based).
- Sticky routing: route a user's reads to primary if they have recent writes (session token / LSN comparison).
- Use the Cosmos DB session token pattern. [See: eventual-consistency.md](./eventual-consistency.md)

#### 2. Monotonic Reads Violation
```
User reads row version V3 from replica A
User reloads → routes to replica B which has V1 (more lagged)
→ data appears to go backward in time
```

**Solutions:**
- Pin a user's reads to the same replica for the session (session affinity).
- Read from primary for any row read within the last N seconds.

#### 3. Phantom Reads in Reports
A long-running analytics query on a replica may produce inconsistent results if the replica applies new writes during the query execution.

**Solution:** Use `READ COMMITTED SNAPSHOT ISOLATION (RCSI)` — the replica serves queries from a snapshot taken at query start, so new writes during the query don't affect it.

### Routing Strategies

**Application-level routing** (explicit):
```csharp
// Two DbContext types, two connection strings
services.AddDbContext<WriteDbContext>(o => o.UseSqlServer(primaryCs));
services.AddDbContext<ReadDbContext>(o => o.UseSqlServer(replicaCs + ";ApplicationIntent=ReadOnly"));
```

**Driver-level routing** (transparent):
SQL Server `MultiSubnetFailover=True;ApplicationIntent=ReadOnly` — the driver routes to the readable secondary automatically.

**Proxy-level routing** (infrastructure):
ProxySQL, pgBouncer, AWS RDS Proxy — examine the SQL and route reads/writes at the proxy, no application change required.

### CQRS: Architectural Formalisation

Command Query Responsibility Segregation takes read-write splitting from an infrastructure optimisation to an architectural pattern:

| | Write side (Command) | Read side (Query) |
|--|---|---|
| **Model** | Domain aggregate, enforces invariants | Read-optimised DTO / projection |
| **Storage** | Normalised relational DB | Denormalised, materialised view, or separate DB |
| **Consistency** | Strong (ACID) | Eventual (projections lag behind writes) |
| **Scaling** | Vertical or shard | Horizontal (read replicas, search indexes) |

A **Projection** converts domain events into the read model. When an `OrderPlaced` event is raised, the projection updates a denormalised `OrderSummary` row optimised for the orders list screen — no JOIN required at read time.

CQRS enables:
- Using a different DB technology for the read model (SQL for writes, Elasticsearch for search, Redis for live dashboards).
- Rebuilding the read model by replaying events from the write side.
- Independent scaling of reads and writes.

**Cost**: eventual consistency between write and read sides; increased system complexity; projection rebuild latency on schema change.

[See: cqrs-and-read-models.md](./cqrs-and-read-models.md) for full implementation.

### Lag Monitoring and Alerting

Always monitor replication lag in production:
- SQL Server: `sys.dm_hadr_database_replica_states` → `secondary_lag_seconds`.
- PostgreSQL: `pg_stat_replication` → `replay_lag`.
- Alert when lag > acceptable threshold (e.g., > 5s for user-facing reads; > 60s for analytics).

If lag exceeds threshold, temporarily route reads back to primary to avoid consistency violations.

## Code Example

```csharp
// ASP.NET Core 8 — CQRS with separate read/write contexts + lag detection
// Demonstrates read-your-writes guard via timestamp comparison

using Microsoft.EntityFrameworkCore;

// ── Write side: normalised domain model ──────────────────────────────
app.MapPost("/orders", async (CreateOrderRequest req, WriteDbContext db, IReplicationMonitor lag) =>
{
    var order = new Order { CustomerId = req.CustomerId, Total = req.Total, CreatedAt = DateTime.UtcNow };
    db.Orders.Add(order);
    await db.SaveChangesAsync();

    // Tell the replica monitor about this write time — used for read routing
    lag.RecordWrite(req.CustomerId, DateTime.UtcNow);

    return Results.Created($"/orders/{order.Id}", new { order.Id });
});

// ── Read side: denormalised projection, routes to replica ─────────────
app.MapGet("/orders/summary", async (
    string customerId,
    ReadDbContext readDb,
    WriteDbContext writeDb,
    IReplicationMonitor lag) =>
{
    // Read-your-writes guard: if user wrote within last 2s, go to primary
    var lastWrite = lag.GetLastWriteTime(customerId);
    bool useReplica = lastWrite is null || DateTime.UtcNow - lastWrite > TimeSpan.FromSeconds(2);

    if (useReplica)
    {
        // Denormalised read model: no JOINs required, optimised for this screen
        var summary = await readDb.OrderSummaries
            .AsNoTracking()
            .Where(s => s.CustomerId == customerId)
            .OrderByDescending(s => s.CreatedAt)
            .Take(20)
            .ToListAsync();

        return Results.Ok(summary);
    }
    else
    {
        // Fallback to primary for read-your-writes consistency
        var orders = await writeDb.Orders
            .AsNoTracking()
            .Where(o => o.CustomerId == customerId)
            .OrderByDescending(o => o.CreatedAt)
            .Take(20)
            .ToListAsync();

        return Results.Ok(orders.Select(o => new { o.Id, o.Total, o.CreatedAt }));
    }
});

app.Run();

// ── Replication lag monitor (simplified) ─────────────────────────────
public interface IReplicationMonitor
{
    void RecordWrite(string userId, DateTime writeTime);
    DateTime? GetLastWriteTime(string userId);
}

public class InMemoryReplicationMonitor : IReplicationMonitor
{
    private readonly Dictionary<string, DateTime> _writes = new();

    public void RecordWrite(string userId, DateTime writeTime)
        => _writes[userId] = writeTime;

    public DateTime? GetLastWriteTime(string userId)
        => _writes.TryGetValue(userId, out var t) ? t : null;
}

// ── Data models ───────────────────────────────────────────────────────
public class WriteDbContext(DbContextOptions<WriteDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
}

public class ReadDbContext(DbContextOptions<ReadDbContext> options) : DbContext(options)
{
    // Separate read model — could be a different DB or materialized view
    public DbSet<OrderSummary> OrderSummaries => Set<OrderSummary>();
}

public class Order { public int Id { get; set; } public string CustomerId { get; set; } = ""; public decimal Total { get; set; } public DateTime CreatedAt { get; set; } }
public class OrderSummary { public int Id { get; set; } public string CustomerId { get; set; } = ""; public decimal Total { get; set; } public DateTime CreatedAt { get; set; } }
record CreateOrderRequest(string CustomerId, decimal Total);
```

## Common Follow-up Questions

- How do you rebuild a CQRS read model without downtime when the schema changes?
- What is Event Sourcing, and how does it complement CQRS? [See: event-sourcing-vs-crud.md](./event-sourcing-vs-crud.md)
- How do you handle the consistency window between a write and the corresponding projection update?
- What is the difference between CQRS and simple read-write splitting at the infrastructure level?
- How do you test the consistency properties of your read-write split system?
- When does adding a separate read model make a system harder to maintain rather than easier?

## Common Mistakes / Pitfalls

- **Treating CQRS as mandatory for read-write splitting**: simple infrastructure-level read replicas (via `ApplicationIntent=ReadOnly`) provide most of the benefit without CQRS complexity. Use CQRS only when the read model truly needs a different shape.
- **Forgetting read-your-writes on the same request**: a POST that creates an order and then immediately GETs it to return the created entity will get a 404 from the replica. Route the follow-up read to the primary or return the entity from the write response.
- **No lag monitoring**: without alerting on replication lag > threshold, the application silently serves stale data during high-load periods without anyone noticing.
- **Projection out-of-sync after failure**: if the projection update fails after the command succeeds, the read model is stale indefinitely. Use the Outbox pattern or transactional event publishing to ensure projections are eventually updated.
- **CQRS applied everywhere**: most CRUD screens don't benefit from CQRS. Applying it to user registration, settings pages, and simple lookups creates complexity with no gain. Apply selectively to high-read, differently-shaped access patterns.
- **Joining write and read models in the same transaction**: read models should be updated asynchronously. Coupling them in the same transaction defeats the purpose of the pattern and creates tight coupling.

## References

- [Martin Fowler — CQRS](https://martinfowler.com/bliki/CQRS.html)
- [CQRS pattern — Azure Architecture Center](https://learn.microsoft.com/azure/architecture/patterns/cqrs)
- [SQL Server Always On readable secondaries](https://learn.microsoft.com/sql/database-engine/availability-groups/windows/active-secondaries-readable-secondary-replicas-always-on-availability-groups)
- [See: database-replication.md](./database-replication.md) — replication mechanics and lag
- [See: event-sourcing-vs-crud.md](./event-sourcing-vs-crud.md) — event sourcing as a foundation for CQRS read models
