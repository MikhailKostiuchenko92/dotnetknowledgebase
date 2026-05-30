# Polyglot Persistence

**Category:** System Design / Data Storage
**Difficulty:** 🟡 Middle
**Tags:** `polyglot-persistence`, `data-synchronisation`, `CDC`, `outbox`, `multi-database`, `architectural-patterns`

## Question

> What is polyglot persistence? When should you use different database technologies for different parts of a system, and how do you handle data synchronisation across them?

## Short Answer

Polyglot persistence means using multiple database technologies in one system, each chosen for the access pattern it serves best — a relational DB for transactions, Redis for caching, Elasticsearch for full-text search, and a TSDB for metrics. The benefit is that each store is optimised for its workload. The challenge is keeping data in sync across stores when the same logical entity is represented in multiple places, typically solved via the Outbox pattern, Change Data Capture (CDC), or event-driven projections.

## Detailed Explanation

### The Core Idea

Different data has different access patterns:

| Data | Primary access pattern | Best store |
|------|----------------------|-----------|
| Orders, users, transactions | Complex queries, ACID | PostgreSQL / SQL Server |
| User sessions, rate counters | Key-value, sub-ms | Redis |
| Product search | Full-text, facets, ranking | Elasticsearch |
| IoT / metrics / traces | Time range, aggregations | InfluxDB / TimescaleDB / ADX |
| Social graph (friends) | Graph traversal | Neo4j / Cosmos DB Gremlin |
| Product catalogue | Flexible schema, document | Cosmos DB / MongoDB |

No single database is optimal for all these patterns. Using a SQL database for full-text search, time-series, and graph traversal is possible but inefficient — you're fighting the database's design.

### When Polyglot Persistence Makes Sense

✅ Use when:
- The read access pattern for a feature is fundamentally different from the write pattern.
- Full-text search is needed (Elasticsearch shines; SQL `LIKE '%query%'` is terrible).
- High-throughput caching layer is needed (Redis, Memcached).
- Time-series or analytics queries require a specialised engine.
- The team has clear ownership of each data store.

❌ Avoid when:
- The system is small — operational complexity outweighs any benefit.
- The team lacks expertise to operate multiple database systems.
- The data is highly relational and cross-store consistency is required frequently.
- Eventual consistency between stores is unacceptable for the use case.

### The Synchronisation Problem

When an `Order` is written to SQL Server, it must eventually appear in Elasticsearch for search and in Redis for fast lookups. How do you keep them in sync?

**Option 1: Dual-write (anti-pattern)**
```
Write to SQL Server → write to Elasticsearch → write to Redis
```
If any step fails, stores are inconsistent. No atomic guarantee. **Don't do this.**

**Option 2: Outbox Pattern**
Write to SQL Server + outbox table in one transaction. A relay publishes events. Each subscriber (Elasticsearch indexer, Redis updater) processes the event independently. At-least-once delivery; idempotent consumers handle duplicates. [See: outbox-pattern.md](./outbox-pattern.md)

**Option 3: Change Data Capture (CDC)**
A CDC agent (Debezium, SQL Server CT/CDC, Azure Event Hubs Capture) reads the database's write-ahead log and publishes change events without modifying the application. No application code changes; subscriptions are added at the infrastructure layer. [See: change-data-capture.md](./change-data-capture.md)

**Option 4: Event-Driven Projections**
The system is event-sourced — all writes are events appended to an event store. Read models (SQL, Elasticsearch, Redis) are projections built by replaying events. Rebuild any projection at any time without data loss. [See: event-sourcing-vs-crud.md](./event-sourcing-vs-crud.md)

### Consistency Model

In a polyglot system, the primary store (SQL) is the **source of truth**. Secondary stores (Elasticsearch, Redis) are **derived projections**:

- Primary store: strong consistency, ACID.
- Secondary stores: eventually consistent; may lag by milliseconds to seconds.

Design the UX to tolerate this: after creating an order, the confirmation page shows data from the primary store (instant), not the search index (may lag 1–2s).

### Operational Complexity

Each additional database type requires:
- Separate connection pooling and monitoring.
- Separate backup, restore, and DR strategy.
- Schema migrations or index mappings to maintain.
- Expertise to diagnose issues (Elasticsearch GC, Redis memory pressure, etc.).

Start with a single database and add specialised stores only when a concrete bottleneck justifies the cost.

## Code Example

```csharp
// Polyglot write pipeline: SQL Server (source of truth) → Elasticsearch (search)
// Using Outbox pattern to ensure sync without dual-write
// .NET 8 — Elastic.Clients.Elasticsearch + EF Core

using Microsoft.EntityFrameworkCore;
using Elastic.Clients.Elasticsearch;
using System.Text.Json;

// ── Write: primary store + outbox (one transaction) ──────────────────
app.MapPost("/products", async (CreateProductRequest req, AppDbContext db) =>
{
    var product = new Product(Guid.NewGuid(), req.Name, req.Description, req.Price, req.Category);

    // 1. Write to SQL Server (source of truth)
    db.Products.Add(product);

    // 2. Write outbox event in SAME transaction — atomic with the product write
    db.OutboxMessages.Add(new OutboxMessage(
        Id: Guid.NewGuid(),
        EventType: "ProductCreated",
        Payload: JsonSerializer.Serialize(product),
        Published: false,
        CreatedAt: DateTime.UtcNow));

    await db.SaveChangesAsync();   // single transaction: both succeed or both fail
    return Results.Created($"/products/{product.Id}", product);
});

// ── Read: Elasticsearch (optimised for search) ───────────────────────
app.MapGet("/products/search", async (string q, string? category, ElasticsearchClient es) =>
{
    var response = await es.SearchAsync<ProductDocument>(s => s
        .Index("products")
        .Query(query => query
            .Bool(b => b
                .Must(m => m.MultiMatch(mm => mm
                    .Fields(["name^3", "description"])     // name weighted 3×
                    .Query(q)
                    .Fuzziness(new Fuzziness("AUTO"))))
                .Filter(f => category != null
                    ? f.Term(t => t.Field(p => p.Category).Value(category))
                    : f.MatchAll()))));

    return Results.Ok(response.Documents);
});

// ── Outbox relay: publishes events to Elasticsearch ───────────────────
class ProductIndexerService(AppDbContext db, ElasticsearchClient es) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var pending = await db.OutboxMessages
                .Where(m => !m.Published && m.EventType == "ProductCreated")
                .Take(50)
                .ToListAsync(ct);

            foreach (var msg in pending)
            {
                var product = JsonSerializer.Deserialize<Product>(msg.Payload)!;

                // Index into Elasticsearch (idempotent: same id = upsert)
                await es.IndexAsync(new ProductDocument(
                    product.Id.ToString(), product.Name, product.Description,
                    product.Price, product.Category),
                    idx => idx.Index("products").Id(product.Id.ToString()),
                    ct);

                msg.Published = true;
            }

            if (pending.Count > 0)
                await db.SaveChangesAsync(ct);

            await Task.Delay(500, ct);
        }
    }
}

record Product(Guid Id, string Name, string Description, decimal Price, string Category);
record ProductDocument(string Id, string Name, string Description, decimal Price, string Category);
record CreateProductRequest(string Name, string Description, decimal Price, string Category);
```

## Common Follow-up Questions

- How do you handle an Elasticsearch index rebuild after a schema mapping change?
- What is the latency window between a SQL write and Elasticsearch being searchable, and how do you make the UX tolerate it?
- When does CDC (Change Data Capture) offer advantages over the Outbox pattern for sync?
- How do you test polyglot data consistency in integration tests with multiple real databases?
- What is the "strangler fig" pattern for migrating from a monolithic DB to polyglot persistence?
- How do you monitor data drift between the primary store and derived stores?

## Common Mistakes / Pitfalls

- **Dual-write without a transactional boundary**: writing to two databases sequentially with no compensating rollback means any failure between the two writes leaves the stores inconsistent permanently.
- **Treating Elasticsearch as the source of truth**: Elasticsearch is eventually consistent and does not provide ACID guarantees. Always derive its content from a primary store; never write to ES first.
- **Adding polyglot stores prematurely**: a relational DB with proper indexing handles millions of rows. Adding Elasticsearch for search when `LIKE` queries on 50,000 rows are fast enough adds operational complexity with no benefit.
- **Not designing for eventual consistency in the UI**: showing search results immediately after a write can confuse users if the search index hasn't caught up. Add a delay or show the new item from the primary store in the current user's context.
- **Neglecting Redis memory limits**: Redis stores everything in memory. Without `maxmemory` and an eviction policy, Redis runs out of memory and crashes. Always configure a memory limit and eviction policy. [See: cache-eviction-policies.md](./cache-eviction-policies.md)
- **Schema changes breaking downstream consumers**: changing a field in the SQL model breaks the Elasticsearch mapping and the CDC consumer. Always use schema registries and versioned event schemas for polyglot sync pipelines.

## References

- [Polyglot Persistence — Martin Fowler](https://martinfowler.com/bliki/PolyglotPersistence.html)
- [Elastic.Clients.Elasticsearch — .NET client](https://www.elastic.co/guide/en/elasticsearch/client/net-api/current/index.html)
- [See: outbox-pattern.md](./outbox-pattern.md) — transactional event publishing
- [See: change-data-capture.md](./change-data-capture.md) — CDC as an alternative sync strategy
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 10 — Batch Processing / Derived Data
