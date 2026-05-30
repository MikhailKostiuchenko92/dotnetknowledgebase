# Latency Numbers Every Engineer Should Know

**Category:** System Design / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `latency`, `performance`, `memory`, `network`, `disk`, `orders-of-magnitude`, `benchmarking`

## Question

> What are the approximate latency numbers every backend engineer should know? Why does the order of magnitude matter when designing a system?

## Short Answer

Every system design decision has a latency budget. L1 cache access is ~1 ns; L2 ~4 ns; RAM ~100 ns; SSD random read ~100 µs; network round-trip within a datacenter ~0.5 ms; cross-region ~30–150 ms. Knowing these orders of magnitude tells you whether an operation fits inside a tight loop, a single request, or requires async deferral. Picking the wrong storage tier — e.g., hitting a remote DB instead of a local cache — can make a sub-millisecond operation 1,000× slower.

## Detailed Explanation

### The Numbers (2024 approximations)

These numbers are from Jeff Dean's original "Numbers Every Engineer Should Know" (circa 2012), updated for modern hardware:

| Operation | Latency | Notes |
|-----------|---------|-------|
| L1 cache hit | ~1 ns | ~3 CPU cycles |
| L2 cache hit | ~4 ns | ~12 cycles |
| L3 cache hit | ~10–30 ns | Shared across cores |
| Branch misprediction penalty | ~5 ns | |
| Mutex lock/unlock (uncontended) | ~25 ns | |
| RAM access (main memory) | ~100 ns | 100× L1 |
| Compress 1KB with Snappy | ~3 µs | |
| Send 1KB over 1 Gbps network | ~10 µs | |
| Read 4KB randomly from SSD | ~100 µs | 1,000× RAM |
| Read 1MB sequentially from SSD | ~1 ms | |
| Round-trip in same datacenter | ~0.5 ms | |
| Round-trip to EU from US | ~75 ms | |
| Round-trip to AU from US | ~150 ms | |
| Read 1MB sequentially from disk (HDD) | ~20 ms | 200× SSD |
| Seek on HDD | ~10 ms | |
| Send packet CA → Netherlands → CA | ~150 ms | |

> **Rule of thumb scaling**: 1 ns → 1 µs → 1 ms is a 1,000× jump each time. If something takes 100 ns in memory, the equivalent disk operation takes 100 µs, and a cross-datacenter call takes 100 ms.

### Why This Matters in Design

#### 1. Choosing a Storage Tier

If a lookup costs 1 µs from memory but 100 µs from SSD:
- At 10,000 RPS, in-memory = 10ms total compute vs 1,000ms from SSD = **100× throughput difference**.

#### 2. N+1 Query Problem

An ORM that issues 100 DB queries per request instead of 1 bulk query multiplies 0.5 ms × 100 = 50 ms of pure network/DB overhead per request. Batching is critical. [See: ef-core-performance.md](../04-data-access/ef-core-performance.md)

#### 3. Serialisation Cost

JSON serialisation of a large object may take 500 µs on the server. A cross-datacenter call costs 75 ms. If you're calling the same service 5 times per request: `5 × 75 ms = 375 ms` — the serialisation cost is negligible; the network is the bottleneck.

#### 4. Cache Miss Cost

Cache hit (RAM): 100 ns. Cache miss → DB query: 500 µs. A 99% hit rate means 1% of requests pay 5,000× more. Under high load, cache misses cause thundering herd + latency spikes disproportionate to miss rate.

#### 5. Thread Context Switch

~1–10 µs per context switch. Spawning a `Task` per request is cheap. But spinning up 10,000 tasks simultaneously (thread pool starvation) and forcing context switches at scale degrades throughput significantly.

### Implications for .NET System Design

| Scenario | Guideline based on latency numbers |
|----------|-----------------------------------|
| Tight inner loop (LINQ, parsing) | Keep data in L1/L2 cache; prefer `Span<T>`, avoid heap allocations |
| HTTP API handler | Budget ~50ms total; DB calls should be <10ms; cache what you can |
| gRPC vs REST | gRPC Protobuf serialisation ~5× faster than JSON for large payloads |
| Redis vs in-process cache | Redis: ~0.5ms (local datacenter); IMemoryCache: ~100ns — 5,000× difference |
| Async I/O | A 1ms DB call with sync blocking wastes a thread; async frees it for 1ms of other work |
| Database connection pool | Pool connection checkout: <1µs vs establishing new connection: ~5ms |

### Visualising Magnitude (Scaled to 1 second = 1 ns)

If 1 ns = 1 second of "human time":
- L1 cache: 1 second
- RAM: 3 minutes
- SSD read: 1.7 days
- Cross-continent network: 4.8 years

This framing illustrates why in-memory computation is so much cheaper than any I/O.

## Code Example

```csharp
// Measuring operation latencies in .NET 8 — using Stopwatch and BenchmarkDotNet-style approach

using System.Diagnostics;
using System.Text.Json;

// Quick wall-clock micro-benchmark (for illustration — use BenchmarkDotNet for real measurements)
static long MeasureNs(Action action, int iterations = 100_000)
{
    var sw = Stopwatch.StartNew();
    for (int i = 0; i < iterations; i++) action();
    sw.Stop();
    return sw.ElapsedTicks * 1_000_000_000L / (Stopwatch.Frequency * iterations);
}

// L1/L2 cache access simulation — tight array access
int[] array = new int[1024];
long arrayNs = MeasureNs(() => _ = array[42]);
Console.WriteLine($"Array[42] access: ~{arrayNs} ns");  // typically < 5 ns

// Dictionary lookup (heap, possible cache miss)
var dict = Enumerable.Range(0, 1000).ToDictionary(i => i, i => i * 2);
long dictNs = MeasureNs(() => _ = dict[42]);
Console.WriteLine($"Dictionary lookup: ~{dictNs} ns"); // typically 20-80 ns

// JSON serialisation of a moderate object
var obj = new { Id = 1, Name = "Alice", Roles = new[] { "admin", "user" }, Score = 9.5 };
long jsonNs = MeasureNs(() => JsonSerializer.Serialize(obj), iterations: 10_000);
Console.WriteLine($"JSON serialise (small obj): ~{jsonNs / 1000} µs"); // typically 2-10 µs

// Demonstrating that Redis (0.5ms) >> IMemoryCache (sub-µs) for hot paths
// Don't call Redis inside a tight loop — batch or cache locally:
using Microsoft.Extensions.Caching.Memory;
var cache = new MemoryCache(new MemoryCacheOptions());
cache.Set("key", "value");

long memNs = MeasureNs(() => cache.TryGetValue("key", out _));
Console.WriteLine($"IMemoryCache get: ~{memNs} ns");   // typically < 200 ns
// Redis equivalent: ~500,000 ns (0.5 ms) — 2,500× slower
```

## Common Follow-up Questions

- How would you design a caching strategy to keep p99 latency under 10ms for an API that queries a relational database?
- A single Redis call costs 0.5ms. Your API makes 20 Redis calls per request — what do you do?
- Why is sequential disk access sometimes comparable to random SSD access?
- How do latency numbers change the trade-off between in-process caching and distributed caching?
- What is the relationship between Amdahl's Law and these latency numbers?
- How does NUMA (Non-Uniform Memory Access) affect these numbers on modern multi-socket servers?

## Common Mistakes / Pitfalls

- **Ignoring latency numbers during code review**: calling a remote API inside a LINQ `Select()` or a DB query inside a loop is a common bug that's obvious only if you internalise these numbers.
- **Assuming local network is "free"**: a 0.5ms datacenter round-trip × 100 calls = 50ms overhead — easily the dominant cost in a single request.
- **Treating JSON serialisation as negligible**: at high RPS (10k+), serialisation CPU cost adds up. Use `System.Text.Json` source generators, MessagePack, or Protobuf for hot paths.
- **Confusing throughput and latency**: a system can have high throughput (many requests/second) and high latency (each request takes a long time). Adding concurrency improves throughput; optimising the critical path reduces latency.
- **Benchmarking on development hardware**: SSD latency on a developer laptop is not representative of cloud VM block storage (which may be network-attached and much slower).
- **Not accounting for GC pauses in latency budgets**: a .NET GC Gen2 collection can pause for 50–200ms. If your SLA is p99 < 100ms, GC pauses can blow the budget unpredictably.

## References

- [Jeff Dean — Latency Numbers Every Programmer Should Know (original)](https://gist.github.com/jboner/2841832)
- [Latency Numbers (interactive, updated for modern hardware)](https://colin-scott.github.io/personal_website/research/interactive_latency.html)
- [.NET performance best practices — Microsoft Learn](https://learn.microsoft.com/dotnet/core/performance/)
- [BenchmarkDotNet — accurate .NET micro-benchmarking](https://benchmarkdotnet.org/)
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 1 — Latency percentiles and tail latency
