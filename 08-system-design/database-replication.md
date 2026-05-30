# Database Replication

**Category:** System Design / Data Storage
**Difficulty:** 🟡 Middle
**Tags:** `replication`, `primary-replica`, `read-replica`, `synchronous`, `asynchronous`, `replication-lag`, `SQL-Server`, `failover`

## Question

> How does database replication work? Compare synchronous and asynchronous replication. How do you handle replication lag in an application, and how does read-replica routing work in practice?

## Short Answer

Replication keeps multiple copies of data in sync across nodes. Synchronous replication guarantees that a write is durable on all replicas before acknowledging — zero data loss, higher write latency. Asynchronous replication acknowledges after the primary commits and replicates to replicas in the background — lower write latency, potential data loss on failover. In practice, most production databases use asynchronous replication for read replicas and synchronous for the failover replica. Applications must account for replication lag by routing writes and lag-sensitive reads to the primary.

## Detailed Explanation

### Replication Roles

| Role | Responsibilities |
|------|----------------|
| **Primary (Leader)** | Accepts all writes; replicates the write log to replicas |
| **Replica (Follower)** | Applies the replication log; serves read queries |
| **Synchronous replica** | Primary waits for ACK before returning to client |
| **Asynchronous replica** | Primary returns to client immediately; replica catches up in background |

### Synchronous vs Asynchronous Replication

| | Synchronous | Asynchronous |
|--|------------|-------------|
| **Write latency** | Higher (waits for replica ACK) | Lower (returns after local commit) |
| **Data loss on failover** | Zero (replica has all writes) | Potential loss of last N writes |
| **Availability** | Lower (write fails if replica unavailable) | Higher (primary can accept writes alone) |
| **Typical use** | 1 synchronous replica for failover | Multiple async read replicas |

**SQL Server Always On**: typically one **synchronous** replica for automatic failover (RPO = 0) + one or more **asynchronous** replicas in secondary regions (RPO > 0, lower latency for local writes).

**PostgreSQL streaming replication**: synchronous or asynchronous per replica, configured via `synchronous_commit`. Can set "any 1 of 3 replicas" = semi-synchronous.

### Replication Lag

Asynchronous replicas trail the primary by some amount of lag — typically milliseconds in the same datacenter, seconds to minutes across regions or during high load.

**Lag causes**:
- High write throughput that outpaces replica apply rate.
- Long-running transactions on the primary that block replica apply.
- Network bandwidth constraints.

**Problems caused by lag**:
- Read-your-writes violation: user writes profile, reads from replica → sees old value.
- Monotonic read violation: user reads new value from replica A, then old value from replica B.
- Phantom data: reporting queries on replica miss recent writes.

### Handling Replication Lag in Applications

**Strategy 1: Route sensitive reads to primary**
```
Write → primary
Critical reads (e.g., post-write verification) → primary
Non-critical reads (dashboards, search) → replica
```

**Strategy 2: Session consistency / read-your-writes**
Track the primary's replication log position (LSN) when writing; route subsequent reads by that user to a replica only after it has caught up to that LSN. Cosmos DB does this with session tokens.

**Strategy 3: Stale-read tolerant design**
For analytics, feeds, and counts — design the UX to tolerate slight staleness. Show "updated a few seconds ago" rather than guaranteeing real-time data.

**Strategy 4: Wait for replica to catch up**
After a critical write, poll until the replica's LSN >= the primary's LSN at write time. Expensive and adds latency — only for edge cases.

### Read Replica Routing Patterns

**Application-level routing**:
```csharp
// EF Core: separate connection strings for read/write
services.AddDbContext<WriteDbContext>(o => o.UseSqlServer(primaryConnectionString));
services.AddDbContext<ReadDbContext>(o => o.UseSqlServer(replicaConnectionString));
```

**Driver-level routing**: SQL Server `ApplicationIntent=ReadOnly` connection string property. The driver automatically routes the connection to a readable secondary in an Always On AG without application-level routing logic.

**Proxy-level routing**: PgBouncer, ProxySQL, Azure SQL Hyperscale — route reads to replicas transparently at the connection proxy layer.

### Multi-Primary Replication

Some databases support multi-primary (active-active) replication — all nodes accept writes. Conflicts must be resolved. Used in:
- Cosmos DB (multi-region writes with conflict resolution).
- MySQL Group Replication / Galera Cluster.
- CockroachDB (distributed SQL with Raft consensus).

Multi-primary is complex and usually only warranted for global systems needing writes in multiple regions.

## Code Example

```csharp
// EF Core 8 — read/write separation using ApplicationIntent + separate contexts

using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Primary: all writes
builder.Services.AddDbContext<WriteDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Primary")));

// Replica: reads via ApplicationIntent=ReadOnly
// SQL Server Always On will route this to a readable secondary
builder.Services.AddDbContext<ReadDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("ReadOnlyReplica")
        // Connection string should contain:
        // "ApplicationIntent=ReadOnly;MultiSubnetFailover=True"
        ));

var app = builder.Build();

// Write endpoint — uses primary
app.MapPost("/orders", async (CreateOrderRequest req, WriteDbContext db) =>
{
    var order = new Order { CustomerId = req.CustomerId, Total = req.Total, CreatedAt = DateTime.UtcNow };
    db.Orders.Add(order);
    await db.SaveChangesAsync();
    return Results.Created($"/orders/{order.Id}", order);
});

// Read endpoint — uses replica (may be slightly stale)
app.MapGet("/orders", async (ReadDbContext db) =>
{
    var orders = await db.Orders
        .AsNoTracking()         // never track on replica reads
        .OrderByDescending(o => o.CreatedAt)
        .Take(100)
        .ToListAsync();
    return Results.Ok(orders);
});

// Read-your-writes: after creating an order, read back from PRIMARY to confirm
app.MapGet("/orders/{id}/confirm", async (int id, WriteDbContext db) =>
{
    // Routes to primary — guaranteed to see the just-written row
    var order = await db.Orders.FindAsync(id);
    return order is null ? Results.NotFound() : Results.Ok(order);
});

app.Run();

// Separate DbContext classes map to different connection strings
public class WriteDbContext(DbContextOptions<WriteDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
}

public class ReadDbContext(DbContextOptions<ReadDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
}

public class Order { public int Id { get; set; } public string CustomerId { get; set; } = ""; public decimal Total { get; set; } public DateTime CreatedAt { get; set; } }
record CreateOrderRequest(string CustomerId, decimal Total);
```

## Common Follow-up Questions

- What is the RPO (Recovery Point Objective) and RTO (Recovery Time Objective) for synchronous vs asynchronous replication?
- How does SQL Server Always On Availability Groups differ from log shipping?
- How do you measure replication lag in a production system?
- What is "read-your-writes consistency" and how do you achieve it with read replicas?
- How does Cosmos DB's multi-region write replication handle conflicts?
- What is the difference between replication and sharding, and when do you use both together?

## Common Mistakes / Pitfalls

- **Routing all reads to replica without considering replication lag**: reading order status from a replica immediately after creating the order returns `NotFound` — the write hasn't replicated yet. Critical reads must go to the primary.
- **Using `ApplicationIntent=ReadOnly` but connecting to a standalone instance**: if there's no Always On AG and no read replica, the `ReadOnly` hint is silently ignored — still hits the primary. Verify the connection is actually routed to a replica.
- **Not monitoring replication lag**: lag can spike under high load. Without alerting on lag > 30s, the application silently serves stale data for extended periods.
- **Forgetting `AsNoTracking()` on replica reads**: tracking entities loaded from a read-only connection and then trying to save them throws exceptions. Always use `AsNoTracking()` for reads that will never be written back.
- **Enabling writes on a read replica**: `ApplicationIntent=ReadOnly` prevents writes at the driver level in Always On, but direct connections to the secondary allow reads only — attempting writes throws an error. Make this explicit in code, not just in infrastructure.
- **Synchronous replication across high-latency links**: synchronous replication to a replica in another region (e.g., 75ms RTT) adds 75ms+ to every write. Use asynchronous for cross-region replicas; accept RPO > 0.

## References

- [SQL Server Always On Availability Groups](https://learn.microsoft.com/sql/database-engine/availability-groups/windows/overview-of-always-on-availability-groups-sql-server)
- [ApplicationIntent connection string property](https://learn.microsoft.com/sql/relational-databases/native-client/features/sql-server-native-client-support-for-high-availability-disaster-recovery)
- [PostgreSQL streaming replication](https://www.postgresql.org/docs/current/warm-standby.html)
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 5 — Replication
- [See: read-write-splitting.md](./read-write-splitting.md) — advanced routing patterns and CQRS connection
