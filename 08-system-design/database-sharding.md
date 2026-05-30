# Database Sharding

**Category:** System Design / Data Storage
**Difficulty:** 🟡 Middle
**Tags:** `sharding`, `horizontal-partitioning`, `shard-key`, `consistent-hashing`, `hotspot`, `SQL-Server`

## Question

> What is database sharding? How do you choose a shard key, what is the hotspot problem, and how does consistent hashing help with shard rebalancing?

## Short Answer

Sharding is horizontal partitioning — splitting rows across multiple database nodes based on a shard key, so each node owns a subset of the data. A good shard key distributes writes evenly and aligns with query patterns (avoid cross-shard joins). A bad shard key creates hotspots where one shard receives all writes. Consistent hashing minimises data movement when nodes are added or removed, making rebalancing cheaper than naive modulo sharding.

## Detailed Explanation

### Why Sharding?

A single relational database node eventually hits throughput limits (write throughput, storage). Read replicas solve read scaling but not write scaling. Sharding splits the write load across multiple independent nodes (shards), each owning a slice of the data.

### Shard Key Selection

The shard key is the column (or columns) used to determine which shard owns a row. Everything else follows.

**Requirements of a good shard key:**

| Requirement | Why |
|------------|-----|
| High cardinality | Low cardinality → many rows map to the same shard → hotspot |
| Even distribution | Uneven distribution → one shard becomes a bottleneck |
| Aligned with queries | Queries that filter by shard key go to one shard; cross-shard queries are expensive |
| Immutable | Changing the shard key value of a row requires moving it to another shard |

**Common choices:**

| Key | Distribution | Cross-shard risk |
|-----|-------------|-----------------|
| User ID | ✅ Good | ✅ User data collocated |
| Tenant ID | ✅ Good for multi-tenant | ✅ Tenant queries single shard |
| Created timestamp | ❌ Hot shard (all new writes → latest shard) | ✅ Time range queries |
| Random UUID | ✅ Perfect distribution | ❌ Every query is cross-shard unless key is provided |
| Geolocation | ✅ For geo-local reads | ❌ Cross-region events require cross-shard |

### The Hotspot Problem

If the shard key has low cardinality or sequential values, writes concentrate on one shard:

- `created_at` shard key → all new writes go to the "current" shard; older shards are cold.
- Celebrity user in a social network → a single user's writes all hit one shard.
- Sequential order IDs → all new orders land on the last shard.

**Mitigations:**
- Use a hash of the shard key rather than the raw value (distributes sequential keys).
- Add a random prefix/suffix to the key (but complicates reads).
- Use composite shard keys (`tenant_id + randomised suffix`).
- Reserve hot rows in a separate "overflow" shard.

### Sharding Strategies

**Range-based sharding**: shard 1 = IDs 1–1M, shard 2 = 1M–2M.
- Simple to reason about; efficient range scans within a shard.
- Sequential IDs create hotspots.

**Hash-based sharding**: `shard = hash(key) % N`.
- Even distribution; no hotspot.
- Range queries → cross-shard fan-out (all shards must be queried).
- Adding/removing a shard requires rehashing all data (mitigated by consistent hashing).

**Directory-based sharding**: a lookup table maps each key → shard.
- Maximum flexibility; can move individual rows.
- Lookup table is a SPOF and bottleneck.

### Consistent Hashing

Standard hash sharding (`hash(key) % N`) means adding one shard requires redistributing `N/(N+1)` of all data — O(total data) movement.

Consistent hashing places shards on a ring. Each key hashes to a point on the ring and is owned by the next shard clockwise. Adding a new shard only affects its immediate predecessor's range — O(data/N) movement, which is the minimum possible.

**Virtual nodes (vnodes)**: each physical shard owns multiple non-contiguous arcs on the ring, improving distribution when shard sizes are uneven or when a shard is added.

Used by: Cassandra, DynamoDB, Redis Cluster.

### Cross-Shard Queries

A query like `SELECT * FROM orders WHERE product_id = 42` with `user_id` as the shard key must fan out to all shards and merge results — expensive.

Mitigations:
- **Denormalise**: store the product information with each order (write-time overhead, eliminates cross-shard read).
- **Secondary index on a separate service**: maintain a product→user lookup in a key-value store.
- **Scatter-gather**: query all shards in parallel, merge in the application layer (acceptable latency if shards are few).
- **Global tables**: small reference data replicated to all shards (product catalogue, currency codes).

### .NET / SQL Server Context

SQL Server's **elastic pools** and **elastic database tools** provide managed sharding for Azure SQL. Shard maps (range or list) are maintained in a shard map manager.

For EF Core with manual sharding: select the `DbContext` connection string at the service level based on the shard key:

## Code Example

```csharp
// Simple shard routing in .NET 8 — hash-based sharding for orders
// Demonstrates shard selection and the hotspot problem

public class ShardRouter(IEnumerable<string> connectionStrings)
{
    private readonly string[] _shards = connectionStrings.ToArray();

    // Hash-based: even distribution, no range queries
    public string GetShardConnectionString(string shardKey)
    {
        // FNV-1a hash for better distribution than GetHashCode
        int hash = FnvHash(shardKey);
        int shardIndex = Math.Abs(hash) % _shards.Length;
        return _shards[shardIndex];
    }

    // Range-based: easy range scans, but sequential IDs cause hotspot
    public string GetShardByRange(int orderId)
    {
        return orderId switch
        {
            < 1_000_000   => _shards[0],
            < 2_000_000   => _shards[1],
            < 3_000_000   => _shards[2],
            _             => _shards[^1]   // latest shard gets ALL new writes — HOTSPOT
        };
    }

    private static int FnvHash(string key)
    {
        uint hash = 2166136261;
        foreach (char c in key)
        {
            hash ^= c;
            hash *= 16777619;
        }
        return (int)hash;
    }
}

// DbContext factory — creates context pointed at the correct shard
public class ShardedOrderDbContextFactory(ShardRouter router)
{
    public OrderDbContext CreateForUser(string userId)
    {
        var connectionString = router.GetShardConnectionString(userId);
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseSqlServer(connectionString)
            .Options;
        return new OrderDbContext(options);
    }
}

// Usage in API endpoint
app.MapGet("/users/{userId}/orders", async (string userId, ShardedOrderDbContextFactory factory) =>
{
    await using var db = factory.CreateForUser(userId);
    // This query only touches ONE shard — userId is the shard key
    var orders = await db.Orders
        .Where(o => o.UserId == userId)
        .ToListAsync();

    return Results.Ok(orders);
});

// Cross-shard query — fan-out (expensive, avoid if possible)
app.MapGet("/orders/by-product/{productId}", async (int productId, ShardRouter router, IConfiguration cfg) =>
{
    var connectionStrings = cfg.GetSection("Shards").Get<string[]>()!;
    var allOrders = new List<Order>();

    // Scatter-gather: query all shards in parallel
    var tasks = connectionStrings.Select(async cs =>
    {
        var options = new DbContextOptionsBuilder<OrderDbContext>().UseSqlServer(cs).Options;
        await using var db = new OrderDbContext(options);
        return await db.Orders.Where(o => o.ProductId == productId).ToListAsync();
    });

    var results = await Task.WhenAll(tasks);
    allOrders.AddRange(results.SelectMany(r => r));

    return Results.Ok(allOrders);
});
```

## Common Follow-up Questions

- How do you handle cross-shard transactions (e.g., transfer money between users on different shards)?
- What is a re-sharding operation, and how do you do it with zero downtime?
- How does Cosmos DB's partition key strategy relate to sharding concepts?
- What is the difference between sharding and table partitioning in SQL Server?
- How do you design a schema for a multi-tenant SaaS application using sharding?
- What is a global secondary index (GSI) in DynamoDB and how does it solve cross-shard queries?

## Common Mistakes / Pitfalls

- **Choosing a low-cardinality shard key**: a `status` column with 3 values only allows 3 shards maximum, and writes concentrate on `status = 'active'`.
- **Using a monotonically increasing key (e.g., auto-increment ID) as shard key with range sharding**: all inserts go to the latest range shard — 100% hotspot. Use a hash or UUID.
- **Forgetting that changing a row's shard key requires cross-shard migration**: if a user changes tenant, all their rows must move to the new tenant's shard. Design shard keys to be immutable.
- **Not co-locating related data on the same shard**: storing orders and users on different shards by different keys means every order fetch needs a cross-shard user lookup. Co-locate entities that are frequently joined.
- **Treating sharding as the first scaling solution**: sharding is complex and irreversible (difficult to un-shard). Exhaust read replicas, caching, and vertical scaling before sharding.
- **No scatter-gather timeout**: a cross-shard query that fans out to 50 shards is now 50 dependent operations — one slow shard blocks the response. Set per-shard timeouts and implement partial result handling.

## References

- [Azure SQL elastic database tools — sharding](https://learn.microsoft.com/azure/azure-sql/database/elastic-scale-introduction)
- [Cosmos DB — partition key strategies](https://learn.microsoft.com/azure/cosmos-db/partitioning-overview)
- [Consistent hashing explained — Tom White](https://tom-e-white.com/2007/11/consistent-hashing.html) (verify URL)
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 6 — Partitioning
- [See: database-replication.md](./database-replication.md) — replication within each shard
