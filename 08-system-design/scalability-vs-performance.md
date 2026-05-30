# Scalability vs Performance

**Category:** System Design / Fundamentals
**Difficulty:** 🟢 Junior
**Tags:** `scalability`, `performance`, `throughput`, `latency`, `horizontal-scaling`, `vertical-scaling`

## Question

> What is the difference between scalability and performance? How do horizontal and vertical scaling differ, and when would you choose one over the other?

## Short Answer

Performance measures how fast a single request is handled (latency, throughput); scalability measures how well the system maintains that performance as load increases. Vertical scaling adds more resources to one machine (bigger CPU/RAM); horizontal scaling adds more machines. Horizontal scaling is preferred for large distributed systems because vertical scaling has physical limits and creates a single point of failure.

## Detailed Explanation

### Performance

Performance describes how efficiently a system handles an individual unit of work, typically characterised by two metrics:

| Metric | Definition | Unit |
|--------|------------|------|
| **Latency** | Time from request start to response received | milliseconds (p50, p95, p99) |
| **Throughput** | Number of requests processed per unit of time | requests/second (RPS), messages/second |

Low latency and high throughput are often in tension. Batching increases throughput but adds latency. Caching reduces latency but requires memory. A system can perform well for one user (low latency) but fail to scale to thousands (low throughput under load).

### Scalability

Scalability measures how gracefully a system's performance degrades — or ideally doesn't degrade — as load grows. A system is:

- **Linearly scalable** if doubling resources doubles throughput (ideal).
- **Sub-linearly scalable** if coordination overhead (locks, consensus) erodes gains.
- **Unscalable** if a bottleneck (single DB writer, single thread) caps throughput regardless of resources added.

### Vertical Scaling (Scale Up)

Add more CPU cores, RAM, or faster disks to a single machine.

| Pros | Cons |
|------|------|
| No code changes needed | Hard upper limit (biggest VM available) |
| Low network overhead | Single point of failure |
| Simpler operations | Downtime during upgrade |
| Good for stateful workloads | Expensive at high tiers |

**Use when:** the bottleneck is CPU-bound computation (e.g., video encoding, ML inference) that doesn't benefit from distribution, or when refactoring to distributed architecture is too risky short-term.

### Horizontal Scaling (Scale Out)

Add more instances (nodes, containers, pods) to share the load.

| Pros | Cons |
|------|------|
| Near-unlimited ceiling | Requires stateless or externally-stored state |
| Fault tolerant (N-1 nodes survive) | Network calls between nodes add latency |
| Cost-efficient (commodity hardware) | Distributed coordination complexity |
| Zero-downtime deployments | Load balancer required |

**Use when:** the workload is stateless or state can be externalised (session in Redis, data in DB), and the bottleneck is I/O-bound (web servers, APIs).

### The Scalability Bottleneck Law

Amdahl's Law shows that a fraction `p` of a workload that can be parallelised limits the maximum speedup to `1 / (1 - p)`. If 20% of your code is serial (database writes, single queue consumer), no amount of horizontal scaling eliminates that bottleneck.

### .NET / ASP.NET Core Angle

- **Kestrel** is multi-threaded and stateless by design — ASP.NET Core apps scale horizontally out-of-the-box as long as session state is externalised.
- **`IDistributedCache`** (backed by Redis) allows sticky-session-free horizontal scaling.
- **KEDA** lets Kubernetes horizontally scale .NET worker services based on queue depth, CPU, or custom metrics.
- Vertical scaling gains in .NET come from reduced GC pressure (Server GC, `Span<T>`, pooling) before adding hardware.

### Typical Interview Framing

Interviewers often ask: *"Your API handles 100 RPS now but needs to handle 10,000 RPS next year — what do you do?"*

Walk through this approach:
1. **Profile first** — find the actual bottleneck (CPU? DB? network?).
2. **Optimise before scaling** — a 10× perf improvement is cheaper than 10× machines.
3. **Horizontal for stateless tiers** — API servers, workers.
4. **Vertical for stateful tiers** — until read replicas / sharding becomes necessary.
5. **Cache aggressively** — reduce downstream load.

## Code Example

```csharp
// Horizontal scaling: stateless ASP.NET Core API + external session state
// Program.cs — .NET 8

using Microsoft.Extensions.Caching.StackExchangeRedis;

var builder = WebApplication.CreateBuilder(args);

// Externalise session state so any replica can serve any request
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration["Redis:ConnectionString"];
    // All replicas share the same Redis — no sticky sessions needed
});

builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
});

var app = builder.Build();
app.UseSession();

app.MapGet("/orders/{id}", async (int id, IDistributedCache cache) =>
{
    // Check shared cache first — reduces DB load as we scale out
    var cached = await cache.GetStringAsync($"order:{id}");
    if (cached is not null)
        return Results.Ok(cached);

    // Fetch from DB, write to cache
    var order = $"Order {id} data";           // real: query EF Core
    await cache.SetStringAsync($"order:{id}", order,
        new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5) });

    return Results.Ok(order);
});

app.Run();
```

## Common Follow-up Questions

- How does Amdahl's Law affect your horizontal scaling plan?
- What changes would you need to make to an ASP.NET Core app to make it horizontally scalable?
- How do you measure whether a scaling decision actually improved capacity?
- What is the difference between elasticity and scalability?
- When would you use auto-scaling, and what metric would you trigger it on?
- How does the CAP theorem constrain your scaling options?

## Common Mistakes / Pitfalls

- **Conflating latency and throughput**: optimising for one often harms the other; always specify which matters more for the use case.
- **Scaling before profiling**: adding machines to a serialised bottleneck (e.g., a single-writer queue) achieves nothing and wastes money.
- **Stateful services assumed stateless**: in-memory session or `static` caches break when requests route to different replicas.
- **Ignoring the database tier**: API servers scale horizontally easily, but a single-primary RDS instance becomes the bottleneck that invalidates the rest of the scaling work.
- **Treating vertical scaling as a long-term strategy**: it delays architectural work while racking up cloud costs and SPOF risk.

## References

- [Azure Architecture Center — Scaling up vs scaling out](https://learn.microsoft.com/azure/architecture/best-practices/auto-scaling) (verify URL)
- [ASP.NET Core Performance Best Practices](https://learn.microsoft.com/aspnet/core/performance/performance-best-practices)
- [KEDA — Kubernetes Event-Driven Autoscaling for .NET](https://keda.sh/docs/latest/scalers/)
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 1 — Reliability, Scalability, Maintainability
- [IDistributedCache in ASP.NET Core](https://learn.microsoft.com/aspnet/core/performance/caching/distributed)
