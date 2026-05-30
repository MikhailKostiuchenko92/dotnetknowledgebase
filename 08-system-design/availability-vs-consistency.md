# Availability vs Consistency

**Category:** System Design / Fundamentals
**Difficulty:** 🟢 Junior
**Tags:** `availability`, `consistency`, `SLA`, `nines`, `trade-offs`, `distributed-systems`

## Question

> What is the trade-off between availability and consistency in distributed systems? What does "five nines" of availability mean, and how do SLAs translate into allowed downtime?

## Short Answer

In distributed systems, availability (every request gets a response) and consistency (every read sees the most recent write) are in tension — improving one often requires relaxing the other. SLAs express availability as a percentage of uptime: "five nines" (99.999%) allows only ~5 minutes of downtime per year. Designing for high availability typically means accepting eventual consistency, while strong consistency requires coordination that reduces availability.

## Detailed Explanation

### What is Availability?

A system is **available** if it responds to every request, even in the presence of partial failures. High availability is expressed as a percentage of time the system is operational over a period (usually a year or month).

### "Nines" of Availability

| SLA | Annual Downtime | Monthly Downtime |
|-----|-----------------|------------------|
| 99% (two nines) | ~87.6 hours | ~7.3 hours |
| 99.9% (three nines) | ~8.76 hours | ~43.8 minutes |
| 99.99% (four nines) | ~52.6 minutes | ~4.4 minutes |
| 99.999% (five nines) | ~5.26 minutes | ~26 seconds |
| 99.9999% (six nines) | ~31.5 seconds | ~2.6 seconds |

> **Gotcha:** Cloud SLAs are often per-service and composite. If your system depends on 3 independent services each at 99.9%, your system's availability is `0.999³ ≈ 99.7%` — over 26 hours downtime per year. Always calculate composite SLAs.

### What is Consistency?

Consistency in the distributed systems context (distinct from ACID "C") means:

- **Strong consistency**: every read reflects the most recent write, globally. All nodes agree on the current state.
- **Eventual consistency**: after writes stop, all nodes will *eventually* converge to the same value — but reads during the window may return stale data.

### The Trade-off

Achieving strong consistency in a distributed system requires coordination (e.g., consensus via Raft or Paxos). Coordination has costs:

1. **Latency**: A write must be acknowledged by a quorum before returning.
2. **Availability**: If a majority quorum can't be reached (network partition), the system must reject writes or reads — sacrificing availability to preserve consistency.

Choosing eventual consistency allows the system to accept writes on any available node and resolve conflicts later, maintaining higher availability.

### SLIs and SLOs

Real SLA frameworks decompose availability into:

| Term | Definition |
|------|------------|
| **SLI** (Service Level Indicator) | The actual measured metric (e.g., success rate) |
| **SLO** (Service Level Objective) | Internal target: 99.9% success rate over 30 days |
| **SLA** (Service Level Agreement) | Contractual commitment to customers, with penalties |
| **Error Budget** | `1 - SLO` — how much failure is allowed (`0.1%` of requests) |

[See: slos-slas-error-budgets.md](./slos-slas-error-budgets.md) for deeper coverage.

### ASP.NET Core / Azure Angle

- Azure Cosmos DB exposes a **consistency level knob** per request: `Strong`, `BoundedStaleness`, `Session`, `ConsistentPrefix`, `Eventual`. Choosing `Strong` halves read throughput and doubles latency because it requires reads from quorum.
- SQL Server Always On **synchronous replicas** provide strong consistency with a latency penalty; **asynchronous replicas** provide higher throughput at the cost of potential data loss.
- For ASP.NET Core APIs, availability is increased with: health checks + readiness probes, graceful shutdown (`IHostApplicationLifetime`), retries with Polly, and circuit breakers to avoid cascading failures.

### Design Guidance

Choose **strong consistency** when:
- Financial transactions (bank balances, inventory counts).
- User-visible data that would cause confusion if stale (e.g., "item already sold").

Choose **eventual consistency** when:
- Social media likes/view counts — a few seconds lag is imperceptible.
- Search indexes, recommendation feeds.
- Audit/event logs — append-only, no conflict.

## Code Example

```csharp
// Composite SLA calculation — availability budget
// Run as a top-level statement in a .NET 9 console app

double[] serviceSlas = [0.999, 0.9999, 0.999]; // three upstream dependencies

double compositeSla = serviceSlas.Aggregate(1.0, (acc, sla) => acc * sla);
double annualDowntimeHours = (1.0 - compositeSla) * 365 * 24;

Console.WriteLine($"Composite SLA:              {compositeSla:P4}");  // ~99.7%
Console.WriteLine($"Annual downtime (hours):    {annualDowntimeHours:F2}");  // ~26.3h

// -----------------------------------------------------------------------
// Cosmos DB: choosing consistency level per request
// Azure.Cosmos SDK — .NET 8
using Microsoft.Azure.Cosmos;

CosmosClient client = new(
    accountEndpoint: "https://my-account.documents.azure.com:443/",
    authKeyOrResourceToken: "...",
    new CosmosClientOptions
    {
        // Account-level default — can be overridden per request
        ConsistencyLevel = ConsistencyLevel.Session
    });

Container container = client.GetContainer("MyDb", "Orders");

// Override to Strong for a financial read — higher latency, guaranteed freshness
ItemResponse<Order> response = await container.ReadItemAsync<Order>(
    id: "order-42",
    partitionKey: new PartitionKey("customer-1"),
    requestOptions: new ItemRequestOptions
    {
        ConsistencyLevel = ConsistencyLevel.Strong   // overrides session default
    });

Console.WriteLine($"Order total: {response.Resource.Total}");

record Order(string Id, string CustomerId, decimal Total);
```

## Common Follow-up Questions

- How does the CAP theorem relate to availability and consistency? [See: cap-theorem.md](./cap-theorem.md)
- What are the different consistency levels in Cosmos DB and when would you choose each?
- How do you design a checkout system that needs both high availability and inventory accuracy?
- What is an error budget and how does it guide reliability work?
- How would you measure your system's actual availability in production?
- What's the difference between read-your-writes consistency and strong consistency?

## Common Mistakes / Pitfalls

- **Conflating ACID consistency with distributed consistency**: ACID "C" is about invariants within a transaction; distributed consistency is about replication across nodes — they are different concepts.
- **Quoting an SLA without calculating composite SLA**: a system with three 99.9% dependencies is not 99.9% available — it's ~99.7%.
- **Treating "five nines" as a universal target**: five nines costs significantly more to achieve than three nines and is only justified for life-critical or high-revenue systems.
- **Ignoring planned maintenance in downtime calculations**: SLAs often exclude "scheduled maintenance windows" — verify the SLA terms carefully.
- **Assuming eventual consistency is "good enough" for financial data**: stale reads of account balances can cause overdrafts or double-spends; strong or session consistency is required there.

## References

- [Azure Cosmos DB consistency levels](https://learn.microsoft.com/azure/cosmos-db/consistency-levels)
- [Azure SLA for Cosmos DB](https://azure.microsoft.com/support/legal/sla/cosmos-db/) (verify URL)
- [ASP.NET Core health checks](https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks)
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 9 — Consistency and Consensus
- [Site Reliability Engineering — Google SRE Book, Chapter 4 (SLOs)](https://sre.google/sre-book/service-level-objectives/)
