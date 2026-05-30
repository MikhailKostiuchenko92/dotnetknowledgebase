# Describe a time you had to diagnose a hard-to-reproduce performance issue in production.

**Category:** Problem Solving & Technical Decisions
**Difficulty:** 🔴 Senior
**Tags:** `performance`, `profiling`, `production`, `debugging`, `distributed-tracing`, `memory`

## Question
> Describe a time you had to diagnose a hard-to-reproduce performance issue in production.

## Short Answer
Our API's P99 latency spiked by 300 ms every 2 minutes, always for a brief burst of requests, never reproducible in staging. Using Application Insights metrics correlated with runtime counters, I traced the spike to Gen 2 garbage collections triggered by large object allocations inside a request pipeline — an `XmlSerializer` instance being recreated on every request, silently migrating large byte arrays to the LOH.

## What the Interviewer Is Looking For

This is a deep **diagnostic engineering** question. Interviewers want to see:

- You can investigate production issues without a debugger attached.
- You know which runtime counters and profiling tools are relevant (GC, CPU, memory, thread pool).
- You can work from symptoms to hypotheses to evidence, not from guesses.
- You understand .NET-specific performance patterns: GC pauses, LOH, thread pool starvation.

### Performance Investigation Toolkit (.NET)

| Tool | Use Case |
|------|----------|
| Application Insights / Azure Monitor | Distributed traces, P95/P99 latency, exception rates |
| `dotnet-counters` | Live GC gen counts, thread pool queue depth, exception rates |
| `dotnet-trace` | CPU profiling, thread contention, async wait analysis |
| `dotnet-dump` | Memory heap analysis, large object heap inspection |
| `BenchmarkDotNet` | Microbenchmark validation once root cause is known |
| Event Pipes / DiagnosticSource | In-process high-frequency instrumentation |

## Example STAR Answer

**Situation:**
Our ASP.NET Core 7 Web API showed a distinctive latency pattern in production: P99 latency spiked from a baseline of 80 ms to 380 ms in bursts every 90–120 seconds. The spike affected all concurrent requests, not a specific endpoint. No errors. No obvious CPU spike. Staging was clean.

**Task:**
Root-cause the latency spike pattern and fix it without deploying experimental code to production.

**Action:**

*Phase 1 — Characterise the pattern with existing telemetry:*
In Application Insights, I overlaid the P99 latency chart against custom metrics. The burst pattern matched the garbage collection interval — specifically Gen 2 GC events. I confirmed using `dotnet-counters monitor`:

```
dotnet-counters monitor --process-id <pid> --counters System.Runtime
```

Gen 2 GC rate: 1 collection every 90–100 seconds. Stop-the-world pause duration: ~280 ms. That matched the latency spike almost exactly.

*Phase 2 — Find the LOH allocator:*
Large Gen 2 GC collections typically indicate LOH pressure (objects > 85 KB bypassing Gen 0/1). I captured a memory dump using `dotnet-dump collect` during a staging load test at production-like concurrency. Analysis with `dotnet-dump analyze`:

```
dumpheap -stat
```

The LOH showed repeated allocations of `byte[]` objects at ~92 KB — consistently during request handling.

*Phase 3 — Trace back to source:*
I searched the codebase for `XmlSerializer` usage (a known LOH offender due to its internal byte buffer allocation). Found a `ToXmlString()` helper method called in an HTTP response serialization path that was instantiating `new XmlSerializer(typeof(T))` on every call — including creating new internal buffers.

Fix: cache the `XmlSerializer` instance in a static `ConcurrentDictionary<Type, XmlSerializer>`, which is the recommended pattern. This reduced LOH allocations to near zero.

**Result:**
After the fix, Gen 2 GC rate dropped from 1/90 sec to 1/18 min. P99 latency stabilised at 85 ms. The incident became a team reference case for static cache of serialisation infrastructure.

## Reflection / What I'd Do Differently
I would add `System.Runtime` counter dashboards to our default Application Insights dashboard setup for all services — GC gen counts, thread pool queue depth, and heap size as standard. This issue took 2 days to root-cause; with those counters prebuilt it would have been 2 hours.

## Common Follow-up Questions
- What's the difference between Gen 0, Gen 1, and Gen 2 garbage collections in .NET?
- How do you approach thread pool starvation vs. memory pressure vs. CPU contention as root causes?
- How does the Large Object Heap differ from the standard heap in .NET?
- What is `dotnet-trace` and when would you reach for it over Application Insights?
- How do you set up baseline performance benchmarks so you can detect regressions earlier?
- When would you use `ArrayPool<T>` or `MemoryPool<T>` to reduce GC pressure?

## Common Mistakes / Pitfalls
- **Guessing the cause without data** — "it's probably a database query" before looking at runtime counters wastes hours.
- **Only checking CPU** — .NET performance issues are frequently GC or thread pool related, not CPU bound.
- **Not having counters in production** — `dotnet-counters` and `dotnet-trace` are safe to run on production without redeployment.
- **Ignoring the LOH** — most developers know about Gen 0/1/2 but miss that objects > 85 KB go straight to LOH and are only collected in Gen 2.
- **Recreating serializers** — `XmlSerializer`, `JsonSerializerOptions` (with custom options), and similar types are expensive to construct; they should always be cached.
- **Fixing symptoms, not causes** — tuning GC settings (`GCConserveMemory`, `GCHeapHardLimit`) without fixing the allocation root cause is a band-aid.

## References
- [Garbage Collection in .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/fundamentals)
- [Large Object Heap — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/large-object-heap)
- [dotnet-counters — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-counters)
- [dotnet-trace — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-trace)
- [Performance Best Practices in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/performance/performance-best-practices)

[See also: Most Complex Technical Problem Solved](most-complex-technical-problem-solved.md)
