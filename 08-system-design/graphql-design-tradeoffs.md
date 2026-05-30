# GraphQL Design Trade-offs

**Category:** System Design / APIs
**Difficulty:** 🔴 Senior
**Tags:** `GraphQL`, `N+1`, `DataLoader`, `schema-stitching`, `persisted-queries`, `security`, `HotChocolate`

## Question

> What are the key design trade-offs when building a GraphQL API? How do you solve the N+1 problem with DataLoader? When would you recommend NOT using GraphQL?

## Short Answer

GraphQL's main strengths — client-driven queries and schema introspection — also introduce its biggest risks: the N+1 query problem from nested resolvers, unbounded query complexity enabling DoS attacks, and the operational overhead of a schema registry. DataLoader solves N+1 by batching resolver calls within a single request. GraphQL is a poor fit when the API surface is simple, when caching at the HTTP layer is critical, or when strong backwards-compatibility guarantees outweigh the flexibility benefit.

## Detailed Explanation

### The N+1 Problem

Consider a query that returns orders with their customer names:

```graphql
query {
  orders {           # 1 SQL: SELECT * FROM Orders → 10 rows
    id
    customer {
      name           # 10 SQLs: SELECT * FROM Customers WHERE id = ?
    }
  }
}
```

Each order resolver independently fetches its customer — 10 orders → 10+1 = 11 queries. This is the **N+1 problem**, and it's the most common GraphQL performance bug.

### DataLoader: Solving N+1

DataLoader batches individual loads within a single request tick into one bulk query:

1. All `customer` field resolvers register a load request for their `customerId`.
2. At the end of the execution tick, DataLoader collects all pending IDs and fires one SQL: `SELECT * FROM Customers WHERE id IN (1, 2, 3, ...)`.
3. Results are distributed back to each resolver.

Additionally, DataLoader caches within the request lifetime — if two orders have the same customer, it's only fetched once.

In HotChocolate (.NET), this is implemented via `IDataLoader<TKey, TValue>` or the `[DataLoader]` source generator.

### Query Complexity and Depth Limiting

Clients control query shape — a malicious client can write:
```graphql
{ users { friends { friends { friends { friends { name } } } } } }
```

Without limits, this exponentially multiplies resolver calls. Mitigation:

- **Depth limiting**: reject queries deeper than N levels.
- **Complexity analysis**: assign a cost to each field; reject queries above a threshold.
- **Query allowlisting (persisted queries)**: only pre-approved query hashes are executed in production.

### Schema Design Trade-offs

**Overly fine-grained types**: creating a type for every entity is natural but leads to deep nesting and complex DataLoader chains. Sometimes a "view" type that flattens data is better.

**Mutations as transactions**: GraphQL mutations are sequential (not parallel like queries), but each mutation is still a separate operation. Multi-step business operations should be a single mutation with all required inputs, not chained calls.

**Schema versioning**: GraphQL has no built-in versioning. The convention is **additive changes only** — add new fields, never remove. Deprecate fields with `@deprecated(reason: "use newField instead")`. Use a schema registry to enforce this.

### Schema Stitching vs Federation

When multiple teams own different parts of the schema:

- **Schema stitching**: combine multiple remote schemas at a gateway. Simpler, but gateway must know about all schemas. Queries fan out to each schema service.
- **Apollo Federation / HotChocolate Fusion**: each service owns its subgraph schema and declares `@key` directives. A gateway plans and routes the query. Decoupled — services evolve independently.

### Caching

REST caches naturally at the HTTP layer (GET requests with `Cache-Control`). GraphQL uses POST for all operations — HTTP caching doesn't work out of the box.

Options:
- **Persisted queries**: client sends a query hash; server returns cached result. Enables CDN caching.
- **Response caching**: HotChocolate + `@cacheControl` directives; cache full query responses in Redis.
- **Field-level caching**: DataLoader caches within the request; add a response cache for across-request caching.

### When NOT to Use GraphQL

| Scenario | Why REST/gRPC is better |
|----------|------------------------|
| Simple CRUD with no over-fetching problem | REST is simpler, easier to cache, better tooled |
| Public API with stable contract | REST versioning is simpler; GraphQL schema evolution requires governance |
| High-frequency, low-latency calls | REST/gRPC are more efficient; GraphQL parsing overhead adds up |
| File upload/download | GraphQL multipart is awkward; REST with presigned URLs is cleaner |
| Strong HTTP caching required | GraphQL POST-by-default breaks CDN caching |
| Team without GraphQL expertise | Operational complexity (schema registry, DataLoader, complexity limits) is high |

## Code Example

```csharp
// HotChocolate GraphQL server in ASP.NET Core 8
// Demonstrates: DataLoader, query depth limit, complexity analysis

using HotChocolate;
using HotChocolate.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddGraphQLServer()
    .AddQueryType<Query>()
    .AddDataLoader<CustomerDataLoader>()
    // Security: limit depth and complexity
    .AddMaxExecutionDepthRule(maxAllowedExecutionDepth: 8)
    .SetMaxAllowedComplexity(500)
    .UseField(next => async ctx =>
    {
        ctx.SetLocalValue("complexity", 1);  // each field costs 1
        await next(ctx);
    });

var app = builder.Build();
app.MapGraphQL();
app.Run();

// ── Query type ────────────────────────────────────────────────────────
public class Query
{
    // Resolver: 1 SQL for all orders
    public async Task<IEnumerable<Order>> GetOrders([Service] OrderRepository repo)
        => await repo.GetAllAsync();
}

// ── Types ─────────────────────────────────────────────────────────────
public class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public decimal Total { get; set; }

    // DataLoader: batches N customer fetches into 1 SQL
    public async Task<Customer> GetCustomer(
        [Service] CustomerDataLoader loader) // injected per-request, batched
        => await loader.LoadAsync(CustomerId);
}

public record Customer(int Id, string Name, string Email);

// ── DataLoader ────────────────────────────────────────────────────────
public class CustomerDataLoader(CustomerRepository repo, IBatchScheduler scheduler, DataLoaderOptions options)
    : BatchDataLoader<int, Customer>(scheduler, options)
{
    // Called ONCE per request with ALL requested customer IDs
    protected override async Task<IReadOnlyDictionary<int, Customer>> LoadBatchAsync(
        IReadOnlyList<int> keys,           // all IDs collected this tick
        CancellationToken ct)
    {
        // Single SQL: SELECT * FROM Customers WHERE id IN (...)
        var customers = await repo.GetByIdsAsync(keys, ct);
        return customers.ToDictionary(c => c.Id);
    }
}

// ── Repositories (stubs) ─────────────────────────────────────────────
public class OrderRepository
{
    public Task<IEnumerable<Order>> GetAllAsync()
        => Task.FromResult<IEnumerable<Order>>([new() { Id = 1, CustomerId = 10, Total = 99 }]);
}

public class CustomerRepository
{
    public Task<IEnumerable<Customer>> GetByIdsAsync(IReadOnlyList<int> ids, CancellationToken ct)
        => Task.FromResult<IEnumerable<Customer>>([new(10, "Alice", "alice@example.com")]);
}
```

## Common Follow-up Questions

- How does Apollo Federation / HotChocolate Fusion differ from schema stitching?
- How do you implement subscription resolvers for real-time data in HotChocolate?
- How do you enforce field-level authorisation in a GraphQL schema?
- What is persisted query allowlisting, and how does it improve security and caching?
- How do you test GraphQL resolvers and DataLoader implementations in unit tests?
- How do you handle pagination in GraphQL — cursor-based vs offset, and how does it interact with DataLoader?

## Common Mistakes / Pitfalls

- **Ignoring the N+1 problem**: adding a nested object field without a DataLoader guarantees N+1 queries. Every resolver that loads a related entity needs a DataLoader.
- **No query complexity limits**: without depth or complexity limits, a single malicious query can bring down the server. Add limits before going to production.
- **Treating mutations as idempotent**: GraphQL doesn't enforce idempotency. Retrying a failed mutation (e.g., charge customer) without idempotency keys causes double-processing.
- **Removing schema fields without deprecation period**: clients depend on existing fields. Removing without `@deprecated` and a migration window breaks consumers.
- **Using GraphQL for file uploads**: the `multipart/form-data` GraphQL spec is non-standard and poorly supported. Use presigned URLs (S3 / Azure Blob) instead.
- **Forgetting authentication on introspection**: GraphQL introspection exposes the entire schema structure — disable it in production for public APIs or restrict to authenticated users.

## References

- [HotChocolate .NET GraphQL server — documentation](https://chillicream.com/docs/hotchocolate/v14/)
- [DataLoader — batching and caching for GraphQL](https://github.com/graphql/dataloader)
- [GraphQL best practices — graphql.org](https://graphql.org/learn/best-practices/)
- [Principled GraphQL — Apollo](https://principledgraphql.com/)
- [See: rest-vs-grpc-vs-graphql.md](./rest-vs-grpc-vs-graphql.md) — trade-off comparison with REST and gRPC
