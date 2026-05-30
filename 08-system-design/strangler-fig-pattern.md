# Strangler Fig Pattern

**Category:** System Design / Microservices
**Difficulty:** Middle
**Tags:** `migration`, `strangler-fig`, `monolith`, `dual-write`, `feature-flags`, `incremental`

## Question

> How would you incrementally migrate a legacy monolith to microservices without a big-bang rewrite? Explain the Strangler Fig pattern and the techniques you'd use to make migration safe and reversible.

- How does dual-write work during data migration?
- How do you know when a bounded context is ready to be fully extracted?

## Short Answer

The Strangler Fig pattern wraps the legacy monolith behind a routing facade (reverse proxy or API gateway), then incrementally redirects individual routes to new microservices — one bounded context at a time. The monolith continues handling all other requests. Dual-write keeps both the old and new data stores in sync during the transition; traffic is shifted gradually using feature flags or canary routing. The monolith is "strangled" over months or years until all routes are redirected and it can be retired — no big-bang cutover required.

## Detailed Explanation

### Why Not a Big-Bang Rewrite?

The "big bang" approach — freeze the monolith, rewrite everything in parallel, deploy the new system — historically fails because:
- The parallel codebase accumulates bugs the original never had.
- New features added to the monolith during the rewrite must be re-implemented.
- Integration is deferred until the end; risks are discovered late.
- Business value is delayed for months or years.

The Strangler Fig (named after the tropical plant that slowly envelops its host tree) delivers incremental business value while managing risk.

### Step-by-Step Migration

#### Phase 1: Install the Facade

Place a reverse proxy (NGINX, YARP, Azure API Management) in front of the monolith. All traffic passes through it unchanged initially.

```
Client → Facade (proxy) → Monolith (100% traffic)
```

This is a zero-risk step — the facade is transparent. Invest time here to add observability (distributed tracing, structured logging) if the monolith lacks it.

#### Phase 2: Extract a Bounded Context

Identify the first context to extract using these criteria:
- **Well-defined API boundary** (few dependencies on other monolith modules)
- **Independent data** (no foreign keys crossing context boundaries)
- **Business value** (scalability need, team ownership)

Build the new microservice alongside the monolith (separate repo, separate DB).

#### Phase 3: Dual-Write (Data Synchronisation)

During transition, both systems are live. Data must stay consistent:

```
Option A — App-level dual-write:
Facade or new service writes to both old DB and new DB
→ easy to implement; risk of partial failures

Option B — CDC (Change Data Capture):
Debezium captures monolith DB change log → Kafka → new service consumes
→ more robust; eventual consistency; decouples teams

Option C — DB-level replication:
Postgres logical replication from monolith DB to new service DB
→ lowest code change; schema must be compatible
```

CDC (Debezium + Kafka) is the most reliable for large tables because it handles backfill, ordering, and exactly-once delivery.

#### Phase 4: Shadow Traffic / Dark Launch

Route a copy of traffic to the new service without affecting live responses:

```
Facade → Monolith (authoritative response to client)
       → New service (async/shadow — compare response; never returned to client)
```

Discrepancies in responses are logged and investigated. When parity is confirmed, proceed to canary.

#### Phase 5: Canary Routing

Gradually shift a percentage of production traffic to the new service:

```
Feature flag: new_orders_service_rollout = 5%
→ 5% of /orders requests → New Orders Service
→ 95% → Monolith

Roll forward: 5% → 25% → 50% → 100%
Roll back: set flag to 0% — no deployment needed
```

#### Phase 6: Cut Over & Retire

At 100% traffic, monitor for 1–2 weeks. Then:
1. Remove the route from the monolith.
2. Disable dual-write / CDC sync.
3. Decommission old tables.
4. Update the facade routing table.

Repeat for the next bounded context.

### Readiness Checklist (Before Cutting Over)

- [ ] New service passes all existing integration tests for this context
- [ ] Shadow traffic comparison shows <0.1% response discrepancy
- [ ] Canary at 100% for 72 h with no SLO breach
- [ ] Old data fully migrated and verified (row counts, checksums)
- [ ] Rollback procedure documented and tested
- [ ] Runbook updated; on-call team briefed

### Anti-Patterns to Avoid

| Anti-Pattern | Problem |
|-------------|---------|
| Shared database during extraction | Creates implicit coupling; defeats purpose |
| Synchronous dual-write without idempotency | Partial failure leaves DBs inconsistent |
| Extracting too many contexts in parallel | Too many in-flight migrations increases risk surface |
| No feature flags | Rollback requires a deployment (slow, risky) |
| Skipping shadow traffic phase | First real traffic exposes regressions in production |

> **Warning:** The most dangerous moment is cutting over data ownership. Ensure the new service can reconstruct its full historical data from the monolith's database before switching writes — never delete from the old DB until the new service is fully authoritative.

## Code Example

```csharp
// YARP-based facade with feature-flag-controlled canary routing

using Yarp.ReverseProxy.Configuration;
using Microsoft.FeatureManagement;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

builder.Services.AddFeatureManagement();

var app = builder.Build();

// Middleware: inspect feature flag and inject custom routing header
// YARP routing rules can use request headers to select cluster
app.Use(async (ctx, next) =>
{
    var featureManager = ctx.RequestServices.GetRequiredService<IFeatureManager>();

    if (ctx.Request.Path.StartsWithSegments("/api/orders"))
    {
        // Canary: percentage-based feature flag (e.g., LaunchDarkly / Azure App Config)
        bool useNewService = await featureManager
            .IsEnabledAsync("new-orders-service");

        // Inject header — YARP routing rule matches on this header
        ctx.Request.Headers["X-Route-Target"] = useNewService ? "orders-v2" : "monolith";
    }

    await next(ctx);
});

app.MapReverseProxy();
app.Run();
```

```json
// appsettings.json — YARP routing (header-based canary)
{
  "ReverseProxy": {
    "Routes": {
      "orders-new": {
        "ClusterId": "orders-service",
        "Match": {
          "Path": "/api/orders/{**catch-all}",
          "Headers": [{ "Name": "X-Route-Target", "Values": ["orders-v2"] }]
        }
      },
      "orders-legacy": {
        "ClusterId": "monolith",
        "Match": { "Path": "/api/orders/{**catch-all}" }
      }
    },
    "Clusters": {
      "orders-service": { "Destinations": { "d1": { "Address": "http://orders-svc" } } },
      "monolith":        { "Destinations": { "d1": { "Address": "http://monolith" } } }
    }
  }
}
```

## Common Follow-up Questions

- How do you handle cross-context queries that previously were a single SQL JOIN — e.g., "get order with customer details"?
- What happens to database transactions that span the boundary of the extracted context during dual-write?
- How do you decide which bounded context to extract first?
- How do you manage schema evolution in the new service's DB while CDC is still running from the monolith?
- What organisational changes (team structure, on-call, CI/CD) need to happen before a context can be extracted?

## Common Mistakes / Pitfalls

- **Sharing the database "temporarily"**: the temporary solution becomes permanent; the two services become coupled at the data layer.
- **No shadow traffic phase**: the first signal from production traffic revealing a regression is a customer-facing bug.
- **Migrating data and switching traffic in the same deployment**: decouple data migration (background job) from traffic switch (feature flag); they move at different speeds.
- **Extracting the most complex context first**: start with a peripheral, well-bounded context (e.g., notifications) to build team confidence before tackling the core domain.
- **Forgetting the facade is now a single point of failure**: the proxy must be highly available (multi-replica, health checks) from day one.
- **No cutover deadline**: without a target date, dual-write infrastructure runs indefinitely, accumulating operational debt.

## References

- [Strangler Fig Application — Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Microservices Patterns — Sam Newman (book)](https://samnewman.io/books/building_microservices/)
- [Debezium CDC](https://debezium.io/documentation/reference/stable/architecture.html)
- [YARP Reverse Proxy](https://microsoft.github.io/reverse-proxy/)
- [See: monolith-vs-microservices.md](./monolith-vs-microservices.md)
- [See: api-gateway-pattern.md](./api-gateway-pattern.md)
