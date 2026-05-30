# Single Points of Failure

**Category:** System Design / Fundamentals
**Difficulty:** 🟢 Junior
**Tags:** `SPOF`, `redundancy`, `high-availability`, `active-active`, `active-passive`, `fault-tolerance`

## Question

> What is a single point of failure (SPOF)? How do you identify SPOFs in a system design, and what strategies exist to eliminate them?

## Short Answer

A Single Point of Failure (SPOF) is any component whose failure causes the entire system to become unavailable. SPOFs are identified by asking: "if this component fails, does the system stop working?" Elimination strategies include redundancy (multiple instances), failover (active-passive), load balancing (active-active), and designing stateless services. Eliminating SPOFs is the foundation of high-availability architecture.

## Detailed Explanation

### What Makes Something a SPOF?

Any component in your system that has **no redundant counterpart** is a SPOF. Common examples:

| Component | Typical SPOF | Solution |
|-----------|-------------|---------|
| Web server | Single VM with no replicas | Load-balanced pool of instances |
| Database | Single primary, no replica | Primary-replica with auto-failover |
| Load balancer | Single LB instance | Redundant LB pair or cloud-managed LB |
| Message broker | Single Kafka broker | Kafka cluster with replication factor ≥ 3 |
| DNS server | Single DNS resolver | Multiple NS records, cloud DNS |
| Power supply | Single PSU in server | Dual PSU + UPS |
| Datacenter | Single AZ | Multi-AZ or multi-region deployment |
| Human | Single on-call engineer | On-call rotation + runbooks |

### Identifying SPOFs: The Failure Mode Analysis

Walk through your architecture diagram and for each component ask:

1. **Can it fail?** (all components can fail eventually)
2. **What fails with it?** (blast radius)
3. **Does anything else handle requests while it's down?** (redundancy check)
4. **How quickly can it be restored?** (RTO — Recovery Time Objective)

If the answer to #3 is "no" → it's a SPOF.

### Active-Passive vs Active-Active

**Active-Passive (Warm/Cold Standby):**
- One instance handles all traffic; a standby instance monitors and waits.
- On failure, the standby is promoted (failover).
- Failover takes seconds to minutes → brief downtime.
- Standby consumes resources but serves no traffic.
- Simpler to implement, especially for stateful systems.

**Active-Active:**
- Multiple instances all handle traffic simultaneously.
- On failure of one, the others absorb its load (degraded capacity, but still available).
- Zero downtime — no "promotion" step needed.
- Requires stateless design or shared state (external DB, distributed cache).
- More complex: must handle request routing, session affinity, data consistency.

| | Active-Passive | Active-Active |
|--|---|---|
| **Downtime during failover** | Seconds to minutes | None |
| **Resource utilisation** | 50% (standby idle) | 100% (all active) |
| **State complexity** | Simpler | Shared external state required |
| **Capacity during failure** | Full (standby takes over) | Reduced (N-1 handling N load) |
| **Example** | SQL Server Always On | Azure Load Balancer + ASP.NET Core pods |

### Redundancy Strategies

1. **N+1 redundancy**: one spare for every N active units. If one fails, headroom absorbs the extra load.
2. **N+2 / 2N**: more headroom; used for critical systems where even degraded capacity is unacceptable.
3. **Geographic redundancy**: multiple availability zones or regions prevent facility-level SPOFs.
4. **Data redundancy**: replication factor ≥ 3 in distributed systems (Kafka, Cassandra, Cosmos DB) means two nodes can fail without data loss.

### Statelessness Is the Key Enabler

Active-active redundancy is easy when services are stateless:
- Any instance can serve any request.
- No session affinity needed.
- Scale horizontally by adding more instances.

Stateful services (database, cache, session) become the pinch point — they require more sophisticated redundancy strategies (replication, sharding).

For ASP.NET Core: store session in Redis, JWTs instead of server-side sessions, sticky sessions only as a last resort. [See: scalability-vs-performance.md](./scalability-vs-performance.md)

### Cloud-Managed Redundancy

Modern cloud platforms eliminate many SPOFs by default:
- **Azure Load Balancer / AWS ALB**: highly available, no customer-managed SPOF.
- **Azure SQL / RDS**: managed primary-replica with automatic failover.
- **Azure Service Bus / SQS**: replicated across availability zones internally.
- **Azure Kubernetes Service**: control plane is managed by Azure (not a customer SPOF).

The SPOFs that remain are **application-level**: misconfigured single replicas, single database primaries without read replicas, external dependencies without circuit breakers.

### Kubernetes / ASP.NET Core Pattern

```yaml
# Deployment with minimum 2 replicas across availability zones
spec:
  replicas: 3
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone   # spread across AZs
      whenUnsatisfiable: DoNotSchedule
```

## Code Example

```csharp
// ASP.NET Core — Polly circuit breaker to handle a SPOF downstream dependency
// If the dependency fails, degrade gracefully rather than cascading failure
// .NET 8 — Microsoft.Extensions.Http.Resilience (Polly v8 / Resilience.Http)

using Microsoft.Extensions.Http.Resilience;
using Polly;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient("PaymentService", client =>
{
    client.BaseAddress = new Uri("https://payment.internal/");
})
.AddResilienceHandler("payment-pipeline", static pipeline =>
{
    // Circuit breaker: if 50% of requests fail in 30s window, open the circuit
    pipeline.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
    {
        FailureRatio = 0.5,
        SamplingDuration = TimeSpan.FromSeconds(30),
        MinimumThroughput = 10,
        BreakDuration = TimeSpan.FromSeconds(15),
        OnOpened = args =>
        {
            // Log, alert, or switch to fallback
            Console.WriteLine("Circuit OPEN — payment service unavailable");
            return default;
        }
    });

    // Retry: 3 attempts with exponential backoff before triggering circuit
    pipeline.AddRetry(new HttpRetryStrategyOptions
    {
        MaxRetryAttempts = 3,
        BackoffType = DelayBackoffType.Exponential,
        UseJitter = true
    });
});

var app = builder.Build();

app.MapPost("/checkout", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("PaymentService");

    try
    {
        var response = await client.PostAsync("/charge", null);
        return response.IsSuccessStatusCode
            ? Results.Ok("Payment accepted")
            : Results.Problem("Payment declined");
    }
    catch (BrokenCircuitException)
    {
        // Graceful degradation: queue the payment for retry later
        // rather than returning a 500 to the user
        return Results.Accepted("/checkout/queued", "Payment queued — service temporarily unavailable");
    }
});

app.Run();
```

## Common Follow-up Questions

- What is the difference between SPOF elimination and fault tolerance?
- How do you calculate the overall availability of a system with multiple components?
- What is the "split-brain" problem, and how do active-active databases avoid it?
- How do Kubernetes pod disruption budgets (PDB) protect against self-inflicted SPOFs during deployments?
- When is active-passive preferable to active-active despite the resource waste?
- What is the MTTR (Mean Time To Recover) and MTBF (Mean Time Between Failures), and how do they relate to availability?

## Common Mistakes / Pitfalls

- **Eliminating the obvious SPOFs while missing hidden ones**: The DNS resolver, the network switch, the deployment pipeline, a single on-call engineer — non-application SPOFs are often overlooked.
- **Thinking "we have a replica" means no SPOF**: a read replica that isn't in the automatic failover path is not a SPOF eliminator — it's just a backup. Test the failover regularly.
- **Active-active with shared mutable state without a consensus protocol**: two active write primaries without conflict resolution creates split-brain and data corruption.
- **Forgetting the load balancer**: adding 5 web replicas while leaving a single self-managed nginx instance as the LB just moves the SPOF one layer up.
- **External dependency as SPOF**: a third-party payment API or OAuth provider is a SPOF if your system has no fallback (circuit breaker, queue, cached tokens).
- **Not testing failover**: redundancy that has never been tested (chaos engineering, planned failovers) often doesn't work when needed.

## References

- [Azure Architecture Center — Design for reliability](https://learn.microsoft.com/azure/architecture/framework/resiliency/principles)
- [Kubernetes — Pod Disruption Budgets](https://learn.microsoft.com/azure/aks/operator-best-practices-scheduler)
- [Microsoft.Extensions.Http.Resilience (Polly v8)](https://learn.microsoft.com/dotnet/core/resilience/)
- [AWS Well-Architected Framework — Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
- [See: fault-tolerance-vs-high-availability.md](./fault-tolerance-vs-high-availability.md) — deeper coverage of graceful degradation patterns
