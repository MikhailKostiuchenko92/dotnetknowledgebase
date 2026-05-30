# Multi-Region Architecture

**Category:** System Design / Cloud-Native
**Difficulty:** Senior
**Tags:** `multi-region`, `active-active`, `active-passive`, `data-residency`, `global-load-balancing`, `conflict-resolution`, `geo-replication`

## Question

> How do you design a system that runs across multiple geographic regions? What is the difference between active-active and active-passive multi-region architectures? How do you handle data consistency, data residency requirements, and conflict resolution?

- What is the difference between RTO and RPO and how do they drive architecture choices?
- How do you handle a split-brain scenario in an active-active database?

## Short Answer

Multi-region architectures run services in multiple geographic locations for lower latency, higher availability, and compliance with data residency laws. Active-passive keeps one region live and fails over to the secondary if the primary fails (simpler, higher RPO). Active-active runs all regions simultaneously accepting writes (complex, lower RPO/RTO). The hardest problem is data consistency: writes to region A and region B may conflict — solved by conflict resolution policies (last-write-wins, vector clocks, application-level merge) or by routing each user's writes to a single home region. Data residency requirements (GDPR, data sovereignty) may prohibit certain data from leaving specific regions entirely.

## Detailed Explanation

### RTO and RPO

| Metric | Definition | Example |
|--------|-----------|---------|
| **RTO** (Recovery Time Objective) | Maximum acceptable downtime | RTO = 4h: system back online within 4 hours of failure |
| **RPO** (Recovery Point Objective) | Maximum acceptable data loss | RPO = 1h: at most 1 hour of transactions may be lost |

RTO/RPO drive architecture costs:

| Architecture | RTO | RPO | Cost |
|-------------|-----|-----|------|
| Single region, backups | Hours | Hours | Low |
| Active-passive (warm standby) | Minutes | Seconds–minutes | Medium |
| Active-active | Seconds | Near-zero | High |

### Active-Passive

```
[Users]
   │
   ▼
[Global Load Balancer]
   │
   ├── Primary (West Europe) ← 100% traffic
   │   └── Database (primary, read/write)
   │           │ async replication
   └── Secondary (North Europe) ← 0% traffic (warm standby)
       └── Database (replica, read-only)

On primary failure:
→ Global LB promotes secondary → failover takes 1–5 minutes
→ Data loss = lag of async replication (RPO = seconds to minutes)
```

Azure Traffic Manager or Azure Front Door handle DNS-based failover.

```json
// Azure Traffic Manager — priority routing
{
  "trafficRoutingMethod": "Priority",
  "endpoints": [
    { "name": "primary",   "priority": 1, "target": "orders-westeurope.azurewebsites.net" },
    { "name": "secondary", "priority": 2, "target": "orders-northeurope.azurewebsites.net" }
  ],
  "healthChecks": { "path": "/healthz/ready", "intervalInSeconds": 30 }
}
```

### Active-Active

Both regions accept writes simultaneously:

```
[Users]
   │
   ▼
[Azure Front Door] ← routes by latency (nearest region)
   │
   ├── West Europe API  ← writes to West Europe DB
   │   └── Cosmos DB (multi-master write) ──────────────────────┐
   │                                                             │ replication
   └── North Europe API ← writes to North Europe DB             │
       └── Cosmos DB (multi-master write) ←────────────────────-┘
```

**Consistency challenge**: user Alice in Paris creates order #1 in West Europe. User Bob in Amsterdam (closest to North Europe) reads order list 100ms later — the write may not have replicated yet. This is **active-active eventual consistency**.

### Conflict Resolution

When two regions simultaneously accept writes to the same item, conflicts arise:

**1. Last-Write-Wins (LWW)**
The write with the later timestamp wins. Simple but lossy — one update is silently discarded.

```csharp
// Cosmos DB LWW (default conflict resolution)
var containerProperties = new ContainerProperties("orders", "/userId")
{
    ConflictResolutionPolicy = new ConflictResolutionPolicy
    {
        Mode = ConflictResolutionMode.LastWriterWins,
        ResolutionPath = "/_ts",   // use Cosmos timestamp as tie-breaker
    }
};
```

**2. Custom Conflict Resolution (Stored Procedure)**
Application logic merges conflicting versions:

```javascript
// Cosmos DB custom merge stored procedure (JavaScript)
function mergeProcedure(incomingItem, existingItem, isTombstone) {
    // Merge shopping cart items from both regions
    if (incomingItem.type === "cart") {
        const merged = { ...existingItem };
        for (const item of incomingItem.items) {
            const existing = merged.items.find(i => i.sku === item.sku);
            if (!existing) merged.items.push(item);
            else existing.quantity = Math.max(existing.quantity, item.quantity);
        }
        return merged;
    }
    return incomingItem._ts > existingItem._ts ? incomingItem : existingItem;
}
```

**3. Routing Writes to Home Region (Partition by User)**
Eliminate conflicts by ensuring all writes for a given entity go to the same region:

```csharp
// Route user's writes to their "home" region based on user ID or location
public string GetHomeRegion(Guid userId)
{
    // Consistent hash → deterministic home region per user
    var hash = Fnv1aHash.ComputeHash(userId.ToByteArray());
    return hash % 2 == 0 ? "westeurope" : "northeurope";
}

// API returns redirect to home region if request arrives at wrong region
public IActionResult CreateOrder([FromBody] CreateOrderRequest request)
{
    var homeRegion = _regionRouter.GetHomeRegion(User.GetUserId());
    if (homeRegion != _currentRegion)
        return RedirectPermanent($"https://orders-{homeRegion}.example.com{Request.Path}");
    // ... handle locally
}
```

### Data Residency and Compliance

GDPR requires that EU citizens' personal data is processed and stored within the EU. Other regulations (China's PIPL, Russia's data localisation law) have similar requirements.

Design pattern: **data residency partitioning**

```
EU users → EU region cluster (databases stay in EU)
           └── EU Cosmos DB account (never replicates outside EU)
           └── EU Storage Accounts

US users → US region cluster
           └── US Cosmos DB account

Metadata (non-PII) → global replication OK
PII → region-locked, strict access controls
```

```csharp
// Routing to correct regional data store
public sealed class RegionalDbResolver(IRegionDetector detector)
{
    public AppDbContext ResolveForUser(Guid userId)
    {
        var region = detector.GetUserRegion(userId); // "eu" | "us" | "apac"
        return region switch
        {
            "eu"   => new AppDbContext(_euConnectionString),
            "us"   => new AppDbContext(_usConnectionString),
            "apac" => new AppDbContext(_apacConnectionString),
            _      => throw new InvalidOperationException($"Unknown region: {region}")
        };
    }
}
```

### Global Load Balancing: Azure Front Door

Azure Front Door routes traffic to the nearest healthy region with sub-second failover:

```bicep
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'orders-afd'
  sku: { name: 'Premium_AzureFrontDoor' }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  name: 'orders-backends'
  properties: {
    loadBalancingSettings: { sampleSize: 4, successfulSamplesRequired: 3 }
    healthProbeSettings: { probePath: '/healthz/ready', probeIntervalInSeconds: 30 }
  }
}
```

> **Warning:** Active-active architecture is significantly more complex and expensive. Quantify your availability requirement: is 99.9% (8.7 hours/year downtime) acceptable? Single-region with good availability practices often achieves 99.9%. Active-active is needed for 99.99%+ (52 minutes/year). Don't build active-active without a clear business requirement justifying the cost.

## Code Example

```csharp
// Health check that includes replication lag monitoring
builder.Services.AddHealthChecks()
    .AddCheck("replication-lag", async (ct) =>
    {
        // Check if this replica is lagging more than 30 seconds behind primary
        var lag = await _db.Database
            .SqlQueryRaw<TimeSpan>("SELECT now() - pg_last_xact_replay_timestamp()")
            .FirstOrDefaultAsync(ct);

        return lag.TotalSeconds < 30
            ? HealthCheckResult.Healthy($"Replication lag: {lag.TotalSeconds:F1}s")
            : HealthCheckResult.Degraded($"Replication lag too high: {lag.TotalSeconds:F1}s");
    }, tags: ["ready"]);
```

## Common Follow-up Questions

- What is the PACELC theorem and how does it extend CAP for multi-region latency trade-offs?
- How do you implement a "follow-the-sun" multi-region database with Postgres and pglogical?
- What is Azure Cosmos DB's five consistency levels and which is appropriate for active-active?
- How do you implement cross-region distributed tracing so you can follow a request across regions?
- How does geo-replication differ between Azure SQL, Cosmos DB, and Azure Blob Storage?

## Common Mistakes / Pitfalls

- **Underestimating data consistency complexity**: teams build active-active for availability and then discover conflict resolution breaks core business invariants (e.g., inventory decrement).
- **Forgetting cross-region latency in synchronous calls**: a synchronous call from West Europe to North Europe adds ~10–30ms per hop; multi-region architecture requires all synchronous cross-region calls to be eliminated.
- **Not testing failover**: the failover runbook exists but has never been executed; Game Days or chaos experiments must exercise regional failovers regularly.
- **Single global database**: deploying services to two regions but keeping one global database is not multi-region — the database is still a single point of failure and a latency source.
- **Neglecting data residency auditing**: data residency requirements often change as regulations evolve; build auditing to detect if data crosses region boundaries accidentally.

## References

- [Azure reliability documentation](https://learn.microsoft.com/en-us/azure/reliability/overview)
- [Azure Cosmos DB global distribution](https://learn.microsoft.com/en-us/azure/cosmos-db/distribute-data-globally)
- [Azure Front Door — global load balancing](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview)
- [PACELC theorem — See PACELC entry](./pacelc-theorem.md)
- [See: cap-theorem.md](./cap-theorem.md)
- [See: eventual-consistency.md](./eventual-consistency.md)
