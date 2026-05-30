# Performance Profiling Approach

**Category:** System Design / Performance
**Difficulty:** Senior
**Tags:** `profiling`, `dotnet-trace`, `dotnet-counters`, `benchmarkdotnet`, `memory`, `cpu`, `diagnostics`

## Question

> How do you approach diagnosing and fixing a performance problem in a .NET service in production? What tools do you use and in what order? How do you distinguish a CPU-bound from a memory/GC-bound from an I/O-bound bottleneck?

- You see your service's p99 latency is 5× higher than usual. Walk me through your investigation.
- What is the difference between profiling in development vs in production?

## Short Answer

Performance diagnosis starts with **observability before profiling**: check metrics (CPU, memory, GC pause, connection pool, request rate) to form a hypothesis about the bottleneck type — CPU-bound, GC-bound, I/O-bound, or lock contention. Then attach the right tool to confirm: `dotnet-counters` for live runtime counters, `dotnet-trace` for CPU flamegraphs and event streams, PerfView for GC deep-dives, and a memory dump for heap analysis. Fix one thing at a time, measure before and after, and validate with a load test or BenchmarkDotNet to avoid guessing.

## Detailed Explanation

### Step 0: Observe Before Profiling

Looking at profiling output without a hypothesis wastes time. Start with structured observability:

| Signal | What to look at | Tells you |
|--------|----------------|-----------|
| CPU % | Host/container CPU cores | CPU-bound or not |
| GC counters | Gen0/1/2 collection rate, pause time (ms) | GC pressure |
| Threadpool queue | `ThreadPool Queue Length` counter | Thread starvation |
| Request rate + latency | p50/p95/p99, throughput | Severity |
| Error rate | 4xx/5xx, timeouts | Degraded dependency |
| DB connection pool | `Active connections`, `Pool exhausted` | DB bottleneck |
| External call latency | HTTP client duration | Slow downstream |

OpenTelemetry + Prometheus + Grafana should answer most of this without touching the process.

### Step 1: Identify Bottleneck Type

**CPU-bound**: CPU% near 100%, few allocations, thread pool threads busy.
- Causes: inefficient algorithms, tight loops, regex, JSON serialization without `System.Text.Json` pooling.
- Fix: algorithmic improvement, caching, vectorized code (`SIMD`, `Span<T>`).

**GC-bound**: CPU is elevated but the application isn't doing useful work — GC is running. Gen2 collections are frequent. GC pause spikes correlate with p99 latency spikes.
- Causes: excessive allocation on hot paths, large object heap (LOH) fragmentation, improper use of `List<T>` resizing, LINQ allocations in tight loops.
- Fix: pooling (`ArrayPool<T>`, `MemoryPool<T>`), `Span<T>`, `struct`s, `stackalloc`, `IAsyncEnumerable` instead of materializing large lists.

**I/O-bound**: CPU is low, thread pool queue grows. Requests are blocked waiting for DB, external HTTP calls, or disk.
- Causes: missing `async/await`, synchronous blocking on async code (`.Result`, `.Wait()`), missing DB indexes, N+1 queries, slow downstream.
- Fix: async all the way, query optimisation, connection pooling, caching, timeout + circuit breaker.

**Lock contention**: CPU is moderate, threads are blocked. Deadlocks or high-contention `lock` blocks.
- Causes: `lock(this)`, global locks, `Dictionary` without `ConcurrentDictionary`, naive singleton initialization.
- Fix: lock-free data structures (`ConcurrentDictionary`, `Interlocked`), narrower lock scope, `SemaphoreSlim` for async.

### Step 2: .NET Diagnostic Tools

#### `dotnet-counters` — Live Runtime Counters

```bash
# Install globally (one-time)
dotnet tool install -g dotnet-counters

# Attach to running process — shows live GC, threadpool, exceptions
dotnet-counters monitor -p <PID> \
  --counters System.Runtime,Microsoft.AspNetCore.Hosting
```

Key counters to watch:
- `gc-heap-size` / `gen-0-gc-count`, `gen-1-gc-count`, `gen-2-gc-count`
- `threadpool-thread-count`, `threadpool-queue-length`
- `exception-count`
- `alloc-rate` — bytes/s allocated (high = GC pressure)

#### `dotnet-trace` — CPU & Event Tracing

```bash
dotnet tool install -g dotnet-trace

# Collect a 30-second CPU profile (suitable for production if brief)
dotnet-trace collect -p <PID> \
  --profile cpu-sampling \
  --duration 00:00:30 \
  -o trace.nettrace
```

Open `.nettrace` in Visual Studio, PerfView, or speedscope (`https://speedscope.app`).

#### `dotnet-dump` — Memory Heap Analysis

```bash
dotnet tool install -g dotnet-dump

# Capture a memory dump without stopping the process (Linux: createdump)
dotnet-dump collect -p <PID>

# Analyse
dotnet-dump analyze core_20240101_123456

# Inside the REPL:
> gcheapstat       # heap size by generation
> dumpheap -stat   # object type frequency (find the leak)
> dumpheap -type System.String -min 1000  # large string instances
> gcroot <addr>    # why isn't this collected?
```

#### PerfView — Deep GC Analysis

PerfView is the gold standard for .NET GC analysis. On Windows:

```bash
# Collect GC events
PerfView.exe /GCCollectOnly /AcceptEula /NoGui collect

# Or via dotnet-trace on Linux (convert to speedscope)
```

PerfView's GC view shows allocation stacks, pause times per collection, and LOH details.

#### BenchmarkDotNet — Microbenchmarking

For confirming a fix is faster (not just "it feels faster"):

```csharp
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

BenchmarkRunner.Run<SerializationBenchmark>();

[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class SerializationBenchmark
{
    private readonly Order _order = new(Guid.NewGuid(), "ACME", [new("Widget", 99_00)]);

    [Benchmark(Baseline = true)]
    public string NewtonsoftJson() => Newtonsoft.Json.JsonConvert.SerializeObject(_order);

    [Benchmark]
    public string SystemTextJson() =>
        System.Text.Json.JsonSerializer.Serialize(_order);
}
```

`[MemoryDiagnoser]` shows allocations per operation — critical for GC-pressure comparisons.

### Step 3: Production-Safe Profiling

In production, be careful:

- **`dotnet-counters`**: read-only, no side effects, safe at any time.
- **`dotnet-trace`** CPU sampling: low overhead (~1–2% CPU), safe for 30-second bursts.
- **`dotnet-dump`**: pauses the process briefly (seconds); schedule during low traffic.
- **PerfView full collection**: significant overhead; use with traffic diversion or on a replica.

In Kubernetes, you can exec into the pod:

```bash
kubectl exec -it <pod> -- bash
dotnet-counters monitor -p 1  # PID 1 in a container is usually the app
```

### Step 4: Fix and Verify

**The fix cycle:**
1. Hypothesis → tool confirms
2. Write a benchmark or integration test that captures the before state
3. Apply fix
4. Run benchmark — confirm improvement
5. Load test in staging — confirm no regression elsewhere
6. Deploy and watch metrics (A/B or canary)

> **Warning:** Never deploy a "performance fix" without measuring before and after. Micro-optimisations that look faster in isolation often have no measurable effect on end-to-end latency, and sometimes make things worse (e.g., pooling objects that are rarely reused, adding `async` where sync was fine).

## Code Example

```csharp
// Before: allocates string + char[] on every request (hot path)
public string FormatOrderRef(int year, int seq) =>
    $"ORD-{year:D4}-{seq:D8}";   // string interpolation = new string each call

// After: write to a pre-sized Span<char>, no heap allocation
public static string FormatOrderRefSpan(int year, int seq)
{
    // stackalloc for small fixed-size buffers — no GC pressure
    Span<char> buf = stackalloc char[18]; // "ORD-2024-00000001"
    "ORD-".AsSpan().CopyTo(buf);
    year.TryFormat(buf[4..], out _, "D4");
    buf[8] = '-';
    seq.TryFormat(buf[9..], out _, "D8");
    return new string(buf);
}

// Verify with BenchmarkDotNet — shows 0 bytes allocated in Span version
// | Method             | Mean     | Allocated |
// |--------------------|----------|-----------|
// | FormatOrderRef     | 42.1 ns  | 48 B      |
// | FormatOrderRefSpan | 18.3 ns  | 0 B       |
```

```csharp
// Before: sync blocking on async — causes thread starvation
public IActionResult GetReport(int id)
{
    var report = _service.GetReportAsync(id).Result; // BLOCKS thread
    return Ok(report);
}

// After: async all the way — thread returned to pool while I/O completes
public async Task<IActionResult> GetReport(int id)
{
    var report = await _service.GetReportAsync(id);
    return Ok(report);
}
```

## Common Follow-up Questions

- What is LOH (Large Object Heap) and how does it cause fragmentation?
- How do `ArrayPool<T>` and `MemoryPool<T>` reduce GC pressure?
- What is GC server mode vs workstation mode and when should you change it?
- How do you find a memory leak (steadily growing heap) in a long-running service?
- How do OpenTelemetry metrics relate to .NET runtime counters?

## Common Mistakes / Pitfalls

- **Optimising without measuring first**: changing an algorithm because it "looks slower" rather than confirming it's actually the bottleneck.
- **Ignoring GC pauses as a latency source**: a Gen2 collection pausing for 100ms explains a p99 spike without any slow code.
- **Profiling in Debug build**: the JIT doesn't inline or optimise in Debug mode; always profile Release builds with optimisations on.
- **Testing with a single request**: the JIT's tiered compilation means the first 30 calls are unoptimised; BenchmarkDotNet handles warm-up, but manual tests may not.
- **Not checking allocations**: a function that takes 10ns but allocates 500B per call at 50k req/s generates 25MB/s of garbage, causing frequent Gen1 collections.
- **Blocking async code with `.Result` or `.Wait()`**: the single most common cause of thread-pool starvation in ASP.NET Core services.

## References

- [dotnet-trace — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-trace)
- [dotnet-counters — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-counters)
- [dotnet-dump — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-dump)
- [BenchmarkDotNet documentation](https://benchmarkdotnet.org/articles/overview.html)
- [Performance best practices with gRPC / ASP.NET Core — Stephen Toub, David Fowler](https://learn.microsoft.com/en-us/aspnet/core/grpc/performance)
- [See: async-io-and-throughput.md](./async-io-and-throughput.md)
