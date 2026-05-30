# GraphQL vs REST in .NET

**Category:** Architecture / API Design
**Difficulty:** 🔴 Senior
**Tags:** `GraphQL`, `Hot-Chocolate`, `DataLoader`, `N+1`, `REST`, `schema`, `query-language`, `over-fetching`

## Question

> What are the trade-offs between GraphQL and REST APIs? When is GraphQL worth the complexity, and how do you solve the N+1 problem with DataLoader in Hot Chocolate?

## Short Answer

**GraphQL** lets clients request exactly the fields they need from a single endpoint — solving over-fetching and under-fetching. REST has a fixed response shape per endpoint. GraphQL wins when: client data requirements vary significantly (mobile vs web vs third parties), you have many interconnected entities (social graphs, e-commerce catalogs), or you want to consolidate multiple REST calls into one query. REST wins for: simple CRUD APIs, public APIs requiring HTTP caching, team/tooling familiarity. The N+1 problem (executing one DB query per parent entity when loading children) is solved with **DataLoader** — batch loading with deduplication.

## Detailed Explanation

### Over-Fetching and Under-Fetching

```
REST over-fetching:
  GET /api/orders/42 → returns full OrderDto (50+ fields)
  Client only needed: orderId, status, total → extra bandwidth wasted

REST under-fetching:
  GET /api/orders/42 → need customer name → GET /api/customers/7
  GET /api/customers/7 → need customer tier → need another call
  → Chattiness, multiple round trips

GraphQL single query:
  query {
    order(id: 42) {
      id
      status
      total
      customer {
        name
        tier
      }
    }
  }
  → Exactly what was asked, in one request
```

### Hot Chocolate Setup (.NET)

```bash
dotnet add package HotChocolate.AspNetCore
dotnet add package HotChocolate.Data                # ← LINQ/EF Core integration
dotnet add package HotChocolate.Data.EntityFramework # ← UseDbContext helper
```

```csharp
// Program.cs
builder.Services
    .AddGraphQLServer()
    .AddQueryType<QueryType>()
    .AddMutationType<MutationType>()
    .AddDataLoader<OrderByIdDataLoader>()
    .AddProjections()   // ← translates GraphQL field selection → SQL column selection
    .AddFiltering()     // ← adds where: { status: { eq: "Submitted" } } support
    .AddSorting();      // ← adds order: { total: DESC }

app.MapGraphQL("/graphql"); // ← GraphQL playground at /graphql in development
```

### Query Type

```csharp
[QueryType]
public class QueryType
{
    // IQueryable → Hot Chocolate executes EF Core query with field projections automatically
    [UseProjection, UseFiltering, UseSorting]
    public IQueryable<Order> GetOrders([Service] AppDbContext db)
        => db.Orders.AsNoTracking();

    // Single entity with DataLoader (avoids N+1 when called from nested types)
    public async Task<Order?> GetOrder(int id, OrderByIdDataLoader loader, CancellationToken ct)
        => await loader.LoadAsync(id, ct);
}
```

### The N+1 Problem

```
N+1 scenario:
  Query { orders { id customer { name } } }
  Without DataLoader:
    → SELECT * FROM orders         (1 query)
    → For each order (N=100):
      → SELECT * FROM customers WHERE id = ?  (100 queries)
    → Total: 101 queries!

With DataLoader:
  → SELECT * FROM orders                        (1 query)
  → SELECT * FROM customers WHERE id IN (1..100) (1 batched query)
  → Total: 2 queries
```

### DataLoader Implementation

```csharp
// DataLoader: batch + deduplicate IDs collected during a single request
public class OrderByIdDataLoader(IBatchScheduler scheduler, DataLoaderOptions options)
    : BatchDataLoader<int, Order>(scheduler, options)
{
    [Service]
    private IDbContextFactory<AppDbContext>? DbContextFactory { get; init; }

    protected override async Task<IReadOnlyDictionary<int, Order>> LoadBatchAsync(
        IReadOnlyList<int> keys,  // ← all IDs accumulated during this request
        CancellationToken ct)
    {
        await using var db = await DbContextFactory!.CreateDbContextAsync(ct);

        return await db.Orders
            .Where(o => keys.Contains(o.Id))
            .ToDictionaryAsync(o => o.Id, ct);
        // ↑ Single query: SELECT * FROM orders WHERE id IN (@p0, @p1, ..., @pN)
    }
}

// CustomerByIdDataLoader — same pattern for nested customer loading
public class CustomerByIdDataLoader(IBatchScheduler scheduler, DataLoaderOptions options)
    : BatchDataLoader<int, Customer>(scheduler, options)
{
    protected override async Task<IReadOnlyDictionary<int, Customer>> LoadBatchAsync(
        IReadOnlyList<int> keys, CancellationToken ct)
    {
        await using var db = await _dbContextFactory.CreateDbContextAsync(ct);
        return await db.Customers.Where(c => keys.Contains(c.Id))
            .ToDictionaryAsync(c => c.Id, ct);
    }
}

// Order type: use DataLoader to load nested customer
[ObjectType<Order>]
public static class OrderType
{
    public static async Task<Customer?> GetCustomer(
        [Parent] Order order,
        CustomerByIdDataLoader loader,
        CancellationToken ct)
        => await loader.LoadAsync(order.CustomerId, ct);
}
```

### GraphQL vs REST Comparison

| | REST | GraphQL |
|--|------|---------|
| **Endpoint** | One per resource | One (`/graphql`) |
| **Response shape** | Fixed (server-defined) | Client-defined |
| **HTTP caching** | ✅ Native (GET + URL-based) | ❌ Hard (all POST) |
| **Versioning** | Via URL/header | Schema evolution (additive is safe) |
| **N+1** | Handled by design | Requires DataLoader |
| **Tooling** | Universal | Growing (Banana Cake Pop, Apollo) |
| **Learning curve** | Low | High (schema, resolvers, DataLoader) |

## Code Example

```csharp
// Minimal GraphQL server with Hot Chocolate
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContextFactory<AppDbContext>(opts =>
    opts.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services
    .AddGraphQLServer()
    .AddQueryType(q => q.Name("Query"))
    .AddTypeExtension<OrderQueries>()
    .AddDataLoader<CustomerByIdDataLoader>()
    .AddProjections()
    .AddFiltering()
    .AddSorting();

var app = builder.Build();
app.MapGraphQL();
app.Run();
```

## Common Follow-up Questions

- How do you handle authentication and authorization at the field level in GraphQL?
- What is GraphQL persisted queries, and how does it improve performance and security?
- How do you test GraphQL resolvers — unit vs integration?
- How do you handle pagination in GraphQL (Relay cursor-based vs offset-based)?
- What is the Apollo Federation pattern for composing multiple GraphQL services?

## Common Mistakes / Pitfalls

- **Not using DataLoader for relationships**: loading related entities in resolver methods without DataLoader causes N+1 queries in production. Any resolver that loads data for `[Parent]` objects must use a DataLoader.
- **Exposing internal domain model directly as GraphQL types**: mapping EF Core entities directly to GraphQL types exposes internals and creates tight coupling. Use dedicated GraphQL types + projections.
- **Ignoring query depth/complexity limits**: malicious clients can send deeply nested queries that exhaust DB/CPU. Configure `MaxExecutionDepth` and `MaxAllowedComplexity`.
- **Using GraphQL for simple CRUD APIs**: the overhead of schema definition, resolvers, DataLoaders, and client tooling is unjustified for simple CRUD with few clients. Use REST.

## References

- [Hot Chocolate Documentation](https://chillicream.com/docs/hotchocolate)
- [GraphQL specification](https://spec.graphql.org/)
- [DataLoader pattern — Facebook origin](https://github.com/graphql/dataloader)
- [See: rest-vs-grpc.md](./rest-vs-grpc.md)
