# SQL vs NoSQL

**Category:** System Design / Data Storage
**Difficulty:** 🟢 Junior
**Tags:** `SQL`, `NoSQL`, `relational`, `document`, `key-value`, `columnar`, `graph`, `trade-offs`

## Question

> When would you choose a relational database over a NoSQL database, and vice versa? What are the main NoSQL categories and their use cases?

## Short Answer

Relational databases (SQL) provide ACID guarantees, a flexible query language, and strong consistency — they're the right choice when data is structured, relationships are important, and correctness is non-negotiable. NoSQL databases trade some of those guarantees for specialised access patterns, horizontal scalability, or flexible schemas. There is no universal "better" — choose based on the access pattern, consistency requirements, and scale of your data.

## Detailed Explanation

### Relational Databases (SQL)

Organise data into tables with rows and columns. Use SQL for queries. ACID transactions span multiple tables.

**Strengths:**
- Flexible queries: `JOIN`, aggregates, `WHERE` on any column with an index.
- ACID transactions prevent partial updates.
- Schema enforcement catches data quality issues at write time.
- Decades of tooling, operational knowledge, and ORM support (EF Core, Dapper).
- Normalisation prevents data duplication and inconsistency.

**Weaknesses:**
- Horizontal sharding is complex (requires application-level shard routing or tools like Vitess/Citus).
- Schema migrations are costly for large tables.
- Object-relational impedance mismatch (mapping graphs/documents to rows).
- Write throughput capped by single-primary limits.

**Best for:** financial systems, e-commerce orders, user management, any domain with complex relationships and reporting needs.

### NoSQL Categories

#### 1. Document Databases
*Examples: MongoDB, Cosmos DB (Core API), CouchDB*

Store JSON/BSON documents. Schema is flexible — documents in the same collection can have different shapes. Efficient when you always read/write a document as a unit.

| Use | Don't use |
|-----|----------|
| Product catalogue (varied attributes) | Complex cross-document joins |
| User profiles | Accounting (multi-document ACID) |
| CMS content | Reporting across many documents |

**In .NET**: Cosmos DB SDK, MongoDB.Driver.

#### 2. Key-Value Stores
*Examples: Redis, DynamoDB, Azure Table Storage*

Pure `get(key) → value` and `set(key, value)`. No query by value — only by exact key.

| Use | Don't use |
|-----|----------|
| Session storage, caching | Anything requiring filtering by attributes |
| Shopping cart (key = user ID) | Relational data |
| Rate limit counters | Full-text search |
| Distributed locks | |

**In .NET**: `IDistributedCache` (Redis provider), `StackExchange.Redis`.

#### 3. Wide-Column Stores
*Examples: Cassandra, HBase, Azure Data Explorer (partial)*

Store rows with dynamic columns; optimised for writes and time-series-like access patterns. Data is partitioned by a partition key; rows within a partition are sorted by a clustering key.

| Use | Don't use |
|-----|----------|
| Time-series data (IoT, metrics, logs) | Ad-hoc queries without partition key |
| High write throughput (millions/s) | Strong consistency requirements |
| Geographically distributed writes | Complex joins |

#### 4. Graph Databases
*Examples: Neo4j, Amazon Neptune, Azure Cosmos DB (Gremlin API)*

Optimised for traversing relationships. Graph queries that would require many JOINs in SQL run in O(edge) time in a graph DB.

| Use | Don't use |
|-----|----------|
| Social networks (friends-of-friends) | Bulk data with simple access patterns |
| Fraud detection (connected entities) | Most standard CRUD applications |
| Recommendation engines | |

#### 5. Search Engines
*Examples: Elasticsearch, Azure Cognitive Search, Meilisearch*

Full-text search, faceted filtering, relevance ranking. Not a primary store — typically sync'd from a primary DB.

| Use | Don't use |
|-----|----------|
| Product search, log search | Primary data store |
| Faceted filtering | ACID transactions |
| Autocomplete | |

### Decision Matrix

| Factor | Lean SQL | Lean NoSQL |
|--------|----------|-----------|
| Data model | Structured, relational | Flexible, document-like |
| Query patterns | Ad-hoc, complex JOINs | Predefined access patterns |
| Consistency | Strong ACID required | Eventual OK |
| Scale | Vertical / moderate horizontal | Massive horizontal |
| Team knowledge | Strong SQL | NoSQL expertise available |
| Writes | Moderate | Very high throughput needed |

### Polyglot Persistence

Modern systems commonly use multiple database types:
- SQL (Postgres/SQL Server) for transactional data
- Redis for caching and sessions
- Elasticsearch for search
- Cosmos DB or Cassandra for global write distribution

Each system uses the right tool for its access pattern. The challenge becomes data synchronisation across stores — typically via the Outbox pattern or CDC. [See: polyglot-persistence.md](./polyglot-persistence.md)

## Code Example

```csharp
// Choosing storage tier in ASP.NET Core 8 based on access pattern

// ── SQL (EF Core) — order with line items, JOIN needed ───────────────
using Microsoft.EntityFrameworkCore;

app.MapGet("/orders/{id}", async (int id, OrderDbContext db) =>
{
    var order = await db.Orders
        .Include(o => o.LineItems)                // JOIN — natural for relational
        .Include(o => o.Customer)
        .FirstOrDefaultAsync(o => o.Id == id);

    return order is null ? Results.NotFound() : Results.Ok(order);
});

// ── Redis (key-value) — session cart, fast read by userId ────────────
using StackExchange.Redis;

app.MapGet("/cart/{userId}", async (string userId, IConnectionMultiplexer redis) =>
{
    var db = redis.GetDatabase();
    var cartJson = await db.StringGetAsync($"cart:{userId}"); // O(1) key lookup
    return cartJson.HasValue ? Results.Ok(cartJson.ToString()) : Results.NotFound();
});

app.MapPut("/cart/{userId}", async (string userId, CartDto cart, IConnectionMultiplexer redis) =>
{
    var db = redis.GetDatabase();
    var json = System.Text.Json.JsonSerializer.Serialize(cart);
    await db.StringSetAsync($"cart:{userId}", json, expiry: TimeSpan.FromDays(7));
    return Results.NoContent();
});

// ── Cosmos DB (document) — product catalogue, flexible schema ─────────
using Microsoft.Azure.Cosmos;

app.MapGet("/products/{id}", async (string id, CosmosClient cosmos) =>
{
    var container = cosmos.GetContainer("ShopDb", "Products");
    try
    {
        // Document store: read full document by partition key + id — O(1)
        var response = await container.ReadItemAsync<Product>(id, new PartitionKey(id));
        return Results.Ok(response.Resource);
    }
    catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
    {
        return Results.NotFound();
    }
});

record CartDto(string UserId, List<CartItem> Items);
record CartItem(string ProductId, int Quantity, decimal Price);
record Product(string Id, string Name, Dictionary<string, object> Attributes); // flexible schema
```

## Common Follow-up Questions

- What is the CAP theorem and how does it apply to NoSQL databases? [See: cap-theorem.md](./cap-theorem.md)
- When would you use Cosmos DB over MongoDB, or vice versa?
- What is eventual consistency in a document database, and when is it acceptable?
- How do you handle schema migrations in a schemaless document database?
- What is the "impedance mismatch" problem in ORM and how does it relate to the SQL vs NoSQL choice?
- How do you synchronise data between a primary relational DB and an Elasticsearch index?

## Common Mistakes / Pitfalls

- **Using NoSQL just for scalability before it's needed**: most applications comfortably scale with a well-tuned relational database + read replicas. Premature NoSQL adds operational complexity without benefit.
- **Using a document DB to model relational data**: embedding foreign key relationships in documents and doing application-level joins defeats the purpose of a document store and is slower than SQL.
- **Assuming NoSQL = schema-less = no schema planning needed**: documents in production inevitably evolve; without a schema migration strategy, you end up with inconsistent documents that break queries.
- **Not understanding the partition key in DynamoDB/Cosmos DB**: choosing a bad partition key (low cardinality) causes hot partitions — all writes go to one shard, negating horizontal scalability.
- **Using key-value for multi-field queries**: filtering by multiple attributes (e.g., "users in city X with age > 30") requires a full scan in a key-value store. Use a document DB or SQL for this pattern.
- **Forgetting that "flexible schema" complicates reads**: when different documents have different fields, every read must handle missing fields defensively — this complexity is moved from the DB to application code.

## References

- [Azure SQL vs Azure Cosmos DB — guidance](https://learn.microsoft.com/azure/cosmos-db/relational-nosql)
- [MongoDB use cases](https://www.mongodb.com/use-cases)
- [Choosing between relational and non-relational (Azure Architecture Center)](https://learn.microsoft.com/azure/architecture/data-guide/relational-data/index)
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 2 — Data Models and Query Languages
- [See: polyglot-persistence.md](./polyglot-persistence.md) — using multiple database types in one system
