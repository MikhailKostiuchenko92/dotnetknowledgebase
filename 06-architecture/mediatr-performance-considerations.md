# MediatR Performance Considerations

**Category:** Architecture / Mediator & Pipeline
**Difficulty:** 🔴 Senior
**Tags:** `MediatR`, `performance`, `reflection`, `overhead`, `source-generators`, `hot-path`, `benchmarks`

## Question

> What is the performance overhead of MediatR? When does its reflection-based dispatch become a bottleneck, and what are the alternatives for high-throughput scenarios?

## Short Answer

MediatR uses reflection-based handler discovery and dispatch — measurable overhead of ~1–10 microseconds per call vs direct invocation. For most web APIs (< 10,000 rps), this overhead is negligible compared to DB/HTTP call latency. At very high throughput (100k+ rps, tight loops, hot paths), the allocation and reflection overhead can matter. Alternatives: direct handler injection (bypass MediatR entirely), custom type-safe dispatch table, or Scrutor decorators. MediatR v12+ improved allocation; the real question is whether your application is actually bottlenecked on dispatch overhead.

## Detailed Explanation

### Overhead Sources

MediatR dispatch involves:
1. **Type resolution**: `GetService(typeof(IRequestHandler<PlaceOrderCommand, int>))` — DI lookup
2. **Open generic wrapping**: creating behavior wrappers for each registered pipeline behavior
3. **Async state machine allocation**: each pipeline step creates an async task allocation
4. **Reflection for handler method**: in older versions (pre-v10), reflection was used; newer versions use compiled delegates

```csharp
// What happens internally when you call sender.Send(cmd, ct):
// 1. Resolve IRequestHandler<PlaceOrderCommand, int> from DI
// 2. Wrap in IPipelineBehavior<> chain (allocation per behavior per request)
// 3. Call Handle() via compiled delegate or reflection
// 4. Unwrap result

// Total overhead: ~1-10 microseconds + N allocations (N = pipeline depth)
```

### Benchmark Context

```
Benchmark results (approximate, .NET 8, BenchmarkDotNet):
  Direct handler call:          ~0.05 µs, 0 alloc
  MediatR v12 (no behaviors):   ~1.5 µs, ~300 bytes alloc
  MediatR v12 (3 behaviors):    ~3.0 µs, ~700 bytes alloc

For a typical request with 100ms DB query:
  MediatR overhead: 3µs / 100,000µs = 0.003% of request time → negligible

For a hot path calling handler 1M times/second:
  3µs × 1,000,000 = 3 seconds of overhead per second → significant
```

### When to Avoid MediatR

```
❌ Avoid MediatR for:
  - Inner loops (processing 10k items per request each calling a handler)
  - Extremely high-throughput APIs with sub-millisecond latency SLAs
  - Background workers processing millions of messages per second

✅ MediatR is fine for:
  - HTTP request handlers (latency dominated by I/O, not dispatch)
  - CQRS commands and queries (DB calls dwarf dispatch overhead)
  - Anything where the bottleneck is I/O, not CPU
```

### Alternative 1: Direct Handler Injection

```csharp
// Bypass MediatR entirely for hot paths
// Controller injects the handler directly
[ApiController]
public class HighThroughputController(PlaceOrderHandler handler) : ControllerBase
{
    [HttpPost("orders")]
    public Task<int> Place(PlaceOrderCommand cmd, CancellationToken ct)
        => handler.Handle(cmd, ct);  // ← no MediatR overhead
}

// Still use MediatR for the rest of the application
// Hybrid: MediatR for complex flows, direct injection for hot paths
```

### Alternative 2: Custom Dispatch Table

```csharp
// Type-safe dispatch without reflection (for extreme performance)
public class HandlerDispatcher(IServiceProvider sp)
{
    private static readonly FrozenDictionary<Type, Type> _handlerMap =
        new Dictionary<Type, Type>
        {
            [typeof(PlaceOrderCommand)] = typeof(PlaceOrderHandler),
            [typeof(GetOrderQuery)]     = typeof(GetOrderHandler)
        }.ToFrozenDictionary();  // ← FrozenDictionary is ~30% faster than Dictionary for lookups

    public Task<TResult> Send<TResult>(IRequest<TResult> request, CancellationToken ct)
    {
        var handlerType = _handlerMap[request.GetType()];
        var handler = (IRequestHandler<IRequest<TResult>, TResult>) sp.GetRequiredService(handlerType);
        return handler.Handle(request, ct);
    }
}
```

### Alternative 3: Minimal API Without MediatR

```csharp
// For maximum performance: inject handler directly in minimal API
app.MapPost("/orders", (PlaceOrderCommand cmd, PlaceOrderHandler handler, CancellationToken ct)
    => handler.Handle(cmd, ct));

// No MediatR, no pipeline — but also no validation/logging behaviors
// Add Polly/resilience and validation as explicit middleware or filter
```

### MediatR v12 Improvements

MediatR v12+ addressed many allocation concerns:
- Reduced allocations via better use of `ValueTask`
- Removed many internal boxing operations
- Improved `Span<T>` usage internally

```csharp
// If performance matters: profile first, then decide
// "Premature optimization is the root of all evil" — Donald Knuth
// Use BenchmarkDotNet to measure your actual hot path before rewriting
```

## Code Example

```csharp
// BenchmarkDotNet: compare MediatR vs direct handler
[MemoryDiagnoser, SimpleJob(RuntimeMoniker.Net80)]
public class MediatRVsDirectBenchmark
{
    private IServiceProvider? _sp;
    private ISender? _sender;
    private PlaceOrderHandler? _handler;

    [GlobalSetup]
    public void Setup()
    {
        var services = new ServiceCollection();
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());
        services.AddScoped<IOrderRepository, InMemoryOrderRepository>();
        _sp = services.BuildServiceProvider();
        _sender = _sp.GetRequiredService<ISender>();
        _handler = _sp.GetRequiredService<PlaceOrderHandler>();
    }

    [Benchmark(Baseline = true)]
    public Task<int> DirectHandler()
        => _handler!.Handle(new PlaceOrderCommand(1, 99.99m), CancellationToken.None);

    [Benchmark]
    public Task<int> MediatRSend()
        => _sender!.Send(new PlaceOrderCommand(1, 99.99m), CancellationToken.None);
}
```

## Common Follow-up Questions

- Does MediatR v12 use source generators to eliminate reflection?
- How do you profile which part of the request pipeline is the actual bottleneck?
- Are there production-ready alternatives to MediatR with better performance?
- How does `Wolverine` (formerly `JasperFx`) compare to MediatR in terms of performance?
- When would you justify removing MediatR from an existing application?

## Common Mistakes / Pitfalls

- **Optimising MediatR dispatch before profiling**: spending days removing MediatR when the actual bottleneck is a missing DB index wastes time. Always measure first.
- **Using MediatR inside tight background loops**: a background service processing 1M messages/second and calling `sender.Send()` for each message suffers real overhead. Inject handlers directly.
- **Confusing memory allocation with latency**: MediatR allocates ~300-700 bytes per call. GC overhead from this is minimal at reasonable throughput; only matters at extreme scale.
- **Rewriting MediatR pipeline with a custom framework**: most teams who do this end up rebuilding MediatR, but worse. Profile first, optimize surgically where the actual bottleneck is measured.

## References

- [MediatR v12 performance improvements](https://github.com/jbogard/MediatR/releases) (verify URL)
- [Wolverine messaging framework](https://wolverinefx.net/) (verify URL)
- [BenchmarkDotNet — .NET benchmarking](https://benchmarkdotnet.org/)
- [See: mediator-pattern.md](./mediator-pattern.md)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
