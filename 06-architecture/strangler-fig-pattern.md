# Strangler Fig Pattern

**Category:** Architecture / Microservices
**Difficulty:** 🟡 Middle
**Tags:** `strangler-fig`, `migration`, `incremental`, `proxy`, `YARP`, `monolith-migration`

## Question

> How does the Strangler Fig pattern work for incrementally migrating a monolith to microservices? What is the role of the routing proxy, and how do you handle data migration during service extraction?

## Short Answer

The **Strangler Fig** pattern replaces a monolith feature-by-feature, with a proxy sitting in front of both the old monolith and the new services. The proxy routes each request to either the monolith (legacy) or the new service (strangler). Over time, more routes point to new services until the monolith is fully replaced. The key advantage: no big-bang rewrite — the system stays operational throughout the migration. Data migration is the hard part: each extracted service needs its own database, requiring a data synchronization period while both the monolith and new service share or replicate data.

## Detailed Explanation

### Migration Phases

```
Phase 1: Proxy added, all traffic still to monolith
  Client → Proxy → Monolith (all routes)

Phase 2: First service extracted (e.g., Product Catalog)
  Client → Proxy → ProductService (/api/products/*)
                 → Monolith       (all other routes)

Phase 3: Second service extracted (e.g., Orders)
  Client → Proxy → ProductService (/api/products/*)
                 → OrderService   (/api/orders/*)
                 → Monolith       (remaining routes)

Phase N: Monolith decommissioned
  Client → Proxy → [all new services]
                 → (Monolith gone)
```

### Choosing What to Extract First

```
Best candidates for first extraction:
  ✓ Leaf services (few or no dependencies on other parts of the monolith)
  ✓ Services with clear API boundaries already in the monolith
  ✓ Parts with separate teams or high change frequency
  ✓ Reporting/read-only services (lower risk, no write transactions)

Worst candidates for first extraction:
  ✗ Core transactional logic (orders, payments) — complex, high risk
  ✗ Anything with many cross-cutting dependencies
  ✗ Parts with shared domain models used everywhere
```

### Proxy Implementation with YARP

```csharp
// Feature flag controlled routing: toggle between monolith and new service per route
builder.Services.AddReverseProxy()
    .LoadFromMemory(GetRoutes(), GetClusters());

List<RouteConfig> GetRoutes() =>
[
    new RouteConfig
    {
        RouteId = "products-new",
        ClusterId = "products-service",
        Match = new RouteMatch { Path = "/api/products/{**catch-all}" },
        // Metadata can be used to enable/disable this route via feature flags
        Metadata = new Dictionary<string, string> { ["FeatureFlag"] = "NewProductService" }
    },
    new RouteConfig
    {
        RouteId = "legacy-catchall",
        ClusterId = "monolith",
        Match = new RouteMatch { Path = "/{**catch-all}" },
        Order = 100 // ← lowest priority — catches everything not matched above
    }
];
```

### Data Migration: The Hardest Part

When extracting a service, its data must be separated from the monolith's DB:

```
Phase A: Read from monolith DB, write to both monolith DB + new service DB (dual write)
  Risk: write failures to one DB create inconsistency
  Mitigation: CDC (Change Data Capture) replicates monolith writes to new service DB

Phase B: New service is authoritative, monolith reads from new service via API
  Monolith code: IProductRepository → HttpProductRepository (calls new service)
  No direct DB access from monolith to new service's DB

Phase C: Monolith DB data migrated, monolith no longer touches product data
```

```csharp
// Facade in the monolith: swap DB access for HTTP call
// (Interface doesn't change — monolith code unaware of extraction)
public class HttpProductRepository(HttpClient http) : IProductRepository
{
    public async Task<Product?> GetByIdAsync(int id, CancellationToken ct)
        => await http.GetFromJsonAsync<Product>($"/api/products/{id}", ct);
}

// Register in monolith DI: no other code changes needed
services.AddHttpClient<IProductRepository, HttpProductRepository>(c =>
    c.BaseAddress = new Uri("http://product-service/"));
```

### Synchronization During Dual Write Period

```csharp
// Dual write adapter: write to both DBs; new service DB is eventually authoritative
public class DualWriteProductRepository(
    LegacyProductRepository legacy,
    ProductServiceHttpClient newService) : IProductRepository
{
    public async Task SaveAsync(Product product, CancellationToken ct)
    {
        await legacy.SaveAsync(product, ct);          // ← write to old DB (source of truth now)
        try
        {
            await newService.UpsertAsync(product, ct); // ← replicate to new service DB
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Dual write failed for product {Id}", product.Id);
            // Don't fail the request — sync can catch up via reconciliation job
        }
    }
}
```

## Code Example

```csharp
// Reconciliation job: verifies data consistency between old and new service
// Run periodically to catch any dual-write gaps
public class DataReconciliationJob(LegacyDbContext legacy, ProductServiceHttpClient newService)
{
    public async Task ReconcileAsync(DateTime since, CancellationToken ct)
    {
        var changedProducts = await legacy.Products
            .Where(p => p.UpdatedAt >= since)
            .ToListAsync(ct);

        foreach (var product in changedProducts)
        {
            var serviceVersion = await newService.GetByIdAsync(product.Id, ct);
            if (serviceVersion is null || serviceVersion.UpdatedAt < product.UpdatedAt)
            {
                await newService.UpsertAsync(product, ct);
                _metrics.IncrementCounter("reconciliation.products.synced");
            }
        }
    }
}
```

## Common Follow-up Questions

- How do you handle transactions that span the monolith and an extracted service?
- What is the Branch by Abstraction pattern, and how does it differ from Strangler Fig?
- How do you roll back a service extraction if the new service has too many bugs?
- How do you measure the success of a service extraction — what metrics matter?
- How long should the dual-write period last?

## Common Mistakes / Pitfalls

- **Extracting services without cleaning up the monolith first**: if the monolith's internal code for a feature is a tangled mess, extracting it produces a tangled microservice. Refactor in the monolith first, then extract.
- **No feature flag for routing**: if the new service has a critical bug, you need to be able to instantly route traffic back to the monolith without a deployment.
- **Dual write without reconciliation**: gaps in dual write are nearly inevitable. A periodic reconciliation job catches and heals inconsistencies.
- **Data migration in one big batch**: migrating millions of rows in a single batch blocks both the old and new DB. Migrate in chunks, validate each chunk, cut over incrementally.

## References

- [Strangler Fig — Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html) (verify URL)
- [Monolith to Microservices — Sam Newman](https://samnewman.io/books/monolith-to-microservices/) (verify URL)
- [YARP .NET reverse proxy](https://microsoft.github.io/reverse-proxy/)
- [See: microservices-vs-monolith.md](./microservices-vs-monolith.md)
- [See: service-decomposition-strategies.md](./service-decomposition-strategies.md)
