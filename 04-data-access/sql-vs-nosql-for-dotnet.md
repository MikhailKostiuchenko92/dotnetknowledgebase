# SQL vs NoSQL for .NET Applications

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🟡 Middle
**Tags:** `SQL`, `NoSQL`, `MongoDB`, `Redis`, `Cosmos DB`, `document-db`, `decision-framework`, `CAP-theorem`

## Question

> When would you choose a NoSQL database over SQL Server for a .NET application? What are the trade-offs? Which NoSQL categories exist, and how do document, key-value, column-family, and graph databases differ in their .NET integration?

## Short Answer

Relational databases excel when data has a stable schema, strong consistency is required, and complex queries with JOINs are common. NoSQL databases trade relational integrity and query flexibility for horizontal scalability, flexible schemas, or specialized access patterns. The choice is driven by the **access pattern**, not the popularity of the technology. Document databases (MongoDB, Cosmos DB) suit semi-structured data with hierarchical reads. Key-value stores (Redis) suit caching and ephemeral state. Column-family (Cassandra) suits high-write time-series at scale. Graph databases suit highly connected data. Most enterprise .NET applications use SQL + Redis cache, not a full NoSQL replacement.

## Detailed Explanation

### NoSQL Categories and .NET Libraries

| Category | Examples | .NET Library | Best for |
|----------|----------|-------------|----------|
| **Document** | MongoDB, Cosmos DB, Couchbase | `MongoDB.Driver`, `Microsoft.Azure.Cosmos` | Product catalogs, CMS, event logs |
| **Key-Value** | Redis, Memcached | `StackExchange.Redis`, `IDistributedCache` | Session, caching, rate limiting, pub/sub |
| **Column-family** | Cassandra, ScyllaDB | `CassandraCSharpDriver` | IoT time-series, high-write analytics |
| **Graph** | Neo4j, Azure Cosmos DB (Gremlin) | `Neo4j.Driver`, CosmosDB Gremlin | Social graphs, recommendation engines, fraud detection |
| **Search** | Elasticsearch, Azure AI Search | `NEST`/`Elastic.Clients.Elasticsearch` | Full-text search, faceted filtering |

### When SQL Wins

- Complex queries with JOINs across multiple entities
- Strong ACID transactions across multiple entities
- Schema is well-defined and unlikely to change frequently
- Reporting and analytics requiring GROUP BY, window functions
- Referential integrity (FK constraints) is critical
- Team is already familiar with T-SQL and EF Core

### When NoSQL Wins

| Scenario | Database type | Reason |
|----------|---------------|--------|
| High-speed session storage, cache | Redis (key-value) | Microsecond reads, eviction, TTL support |
| Product catalog with variable attributes | MongoDB / Cosmos DB | Flexible schema per product category |
| User activity event stream at 100k/s | Cassandra | Horizontal write partitioning, no joins needed |
| Recommendation graph | Neo4j | Graph traversal queries are O(hop count), not O(table size) |
| Unstructured content (CMS blocks) | Document DB | Embed all page content in one document — one read = one page |

### CAP Theorem — Simplified

NoSQL systems often relax consistency (C) to gain partition tolerance and availability (AP systems). SQL Server with synchronous replication is CP (consistent + partition tolerant, but may become unavailable during a network split).

> **Important**: "eventual consistency" means reads may return stale data for a period after a write. This is acceptable for caches and analytics feeds but not for financial transactions.

### .NET Integration Example: MongoDB

```csharp
// Program.cs — MongoDB DI registration
builder.Services.AddSingleton<IMongoClient>(
    new MongoClient(builder.Configuration.GetConnectionString("Mongo")));

builder.Services.AddScoped(sp =>
    sp.GetRequiredService<IMongoClient>().GetDatabase("ShopDb"));

// Document model — BSON serialization
[BsonIgnoreExtraElements]  // tolerant of schema evolution
public record ProductDocument(
    [property: BsonId, BsonRepresentation(BsonType.ObjectId)] string Id,
    string Name,
    decimal Price,
    Dictionary<string, object> Attributes  // flexible per-category attributes
);

// Query
var collection = db.GetCollection<ProductDocument>("products");
var products = await collection
    .Find(p => p.Attributes["Color"].Equals("Red"))
    .SortByDescending(p => p.Price)
    .Limit(20)
    .ToListAsync(ct);
```

### .NET Integration Example: Redis (IDistributedCache)

```csharp
// Registering Redis as IDistributedCache
builder.Services.AddStackExchangeRedisCache(options =>
    options.Configuration = builder.Configuration.GetConnectionString("Redis"));

// Usage in a service
public async Task<ProductDto?> GetCachedProductAsync(int id, CancellationToken ct)
{
    string key = $"product:{id}";
    var cached = await _cache.GetStringAsync(key, ct);
    if (cached is not null)
        return JsonSerializer.Deserialize<ProductDto>(cached);

    var product = await _db.Products.FindAsync([id], ct);
    if (product is null) return null;

    var dto = new ProductDto(product.Id, product.Name, product.Price);
    await _cache.SetStringAsync(key, JsonSerializer.Serialize(dto),
        new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5) },
        ct);
    return dto;
}
```

## Code Example

```csharp
// Polyglot persistence in one service:
// - SQL Server (EF Core) for orders and customers (ACID required)
// - Redis for product cache (read-heavy, can tolerate staleness)
// - MongoDB for flexible product attributes

public class ProductService(AppDbContext db, IDistributedCache cache, IMongoDatabase mongo)
{
    public async Task<ProductDetailDto?> GetAsync(int id, CancellationToken ct)
    {
        // 1. Redis cache hit (fastest path)
        var cached = await cache.GetStringAsync($"product:{id}", ct);
        if (cached is not null)
            return JsonSerializer.Deserialize<ProductDetailDto>(cached);

        // 2. Relational data from SQL Server
        var product = await db.Products
            .AsNoTracking()
            .Where(p => p.Id == id)
            .Select(p => new { p.Id, p.Name, p.Price, p.CategoryId })
            .FirstOrDefaultAsync(ct);

        if (product is null) return null;

        // 3. Flexible attributes from MongoDB
        var attrs = await mongo.GetCollection<ProductAttributeDoc>("product_attrs")
            .Find(a => a.ProductId == id)
            .FirstOrDefaultAsync(ct);

        var dto = new ProductDetailDto(product.Id, product.Name, product.Price,
                                       attrs?.Attributes ?? []);

        // 4. Cache for 5 minutes
        await cache.SetStringAsync($"product:{id}", JsonSerializer.Serialize(dto),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5) },
            ct);

        return dto;
    }
}
```

## Common Follow-up Questions

- How do you handle distributed transactions across a SQL database and a NoSQL store?
- What is the impedance mismatch between relational and document models, and how does Cosmos DB address it?
- When does using Cosmos DB with the SQL API (formerly Document DB) make more sense than SQL Server?
- How do you implement the Outbox pattern across polyglot persistence?
- What are the licensing and operational cost differences between SQL Server and managed NoSQL services on Azure?

## Common Mistakes / Pitfalls

- **Using NoSQL to avoid schema design**: a schema-less document database does not mean schema-free — it just shifts schema enforcement to the application layer. You lose database-level validation.
- **Assuming NoSQL = always faster**: a well-indexed SQL Server query on 10M rows is often faster than a document DB query that reads entire documents to filter on a nested field.
- **Replacing EF Core + SQL Server with MongoDB "for simplicity"**: EF Core migrations, LINQ queries, and change tracking are well-understood. MongoDB's aggregation pipeline is complex and harder to test.
- **Ignoring consistency requirements**: using Redis cache for user account balances or order totals introduces stale-read risk. Reserve eventual consistency for truly tolerance-safe data (product descriptions, session tokens).

## References

- [Choose a data store — Azure Architecture Center — Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/data-store-overview)
- [Azure Cosmos DB for NoSQL with .NET — Microsoft Learn](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/sdk-dotnet-v3)
- [StackExchange.Redis documentation](https://stackexchange.github.io/StackExchange.Redis/)
- [MongoDB .NET Driver documentation](https://www.mongodb.com/docs/drivers/csharp/current/)
- [See: distributed-transactions.md](./distributed-transactions.md)
