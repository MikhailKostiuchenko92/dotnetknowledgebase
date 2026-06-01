# Performance Testing ASP.NET Core Applications

**Category:** ASP.NET Core / Testing
**Difficulty:** 🔴 Senior
**Tags:** `load-testing`, `k6`, `NBomber`, `BenchmarkDotNet`, `performance`, `throughput`

## Question

> How do you performance-test an ASP.NET Core application? Walk through micro-benchmarking with `BenchmarkDotNet`, load testing with `k6` / `NBomber`, and interpreting results.

## Short Answer

Performance testing has two levels: **micro-benchmarking** (measure the cost of a specific method or code path with `BenchmarkDotNet`) and **load testing** (measure end-to-end throughput, latency, and error rates under simulated traffic with `k6`, `NBomber`, or `Bombardier`). Micro-benchmarks catch algorithmic regressions; load tests reveal infrastructure bottlenecks — connection pools, GC pressure, database timeouts under concurrency.

## Detailed Explanation

### BenchmarkDotNet — micro-benchmarks

```bash
dotnet add package BenchmarkDotNet
```

```csharp
[MemoryDiagnoser]       // Allocations (bytes, Gen0/1/2 collections)
[SimpleJob(RuntimeMoniker.Net80)]
public class JsonSerializationBenchmarks
{
    private static readonly Product _product = new(1, "Widget", 9.99m);
    private static readonly byte[] _jsonBytes =
        JsonSerializer.SerializeToUtf8Bytes(_product);

    [Benchmark(Baseline = true)]
    public byte[] SystemTextJson_Serialize() =>
        JsonSerializer.SerializeToUtf8Bytes(_product);

    [Benchmark]
    public Product SystemTextJson_Deserialize() =>
        JsonSerializer.Deserialize<Product>(_jsonBytes)!;
}

// Run from Program.cs in Release mode
// BenchmarkRunner.Run<JsonSerializationBenchmarks>();
```

> **Critical:** Always run benchmarks in `Release` mode. Debug mode disables JIT optimizations and gives misleading results.

```bash
dotnet run -c Release
```

Sample output:

```
| Method                      | Mean     | Allocated |
|---------------------------- |---------:|----------:|
| SystemTextJson_Serialize    | 245.3 ns |     240 B |
| SystemTextJson_Deserialize  | 312.1 ns |     176 B |
```

### k6 — load testing (JavaScript-based)

```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 20 },  // ramp up to 20 VUs
    { duration: '1m',  target: 20 },  // sustain
    { duration: '10s', target: 0  },  // ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<200'], // 95th percentile < 200ms
    'http_req_failed':   ['rate<0.01'], // < 1% errors
  },
};

export default function () {
  const res = http.get('http://localhost:5000/products');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time ok': (r) => r.timings.duration < 200,
  });
  sleep(1);
}
```

```bash
k6 run load-test.js
```

### NBomber — load testing in C#

```bash
dotnet add package NBomber
dotnet add package NBomber.Http
```

```csharp
var httpClient = new HttpClient();

var scenario = Scenario.Create("get_products", async context =>
{
    var response = await httpClient.GetAsync("http://localhost:5000/products");
    return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
})
.WithWarmUpDuration(TimeSpan.FromSeconds(5))
.WithLoadSimulations(
    Simulation.InjectPerSec(rate: 100, during: TimeSpan.FromMinutes(1)));

NBomberRunner
    .RegisterScenarios(scenario)
    .WithReportFormats(ReportFormat.Html)
    .Run();
```

### Interpreting results

| Metric | What it means | Target |
|---|---|---|
| p50 (median latency) | Typical user experience | < 100ms for APIs |
| p95 / p99 | Worst-case for 95%/99% of requests | < 500ms |
| Throughput (RPS) | Requests per second at target latency | Depends on SLA |
| Error rate | % of failed requests | < 0.1% |
| GC Gen0/1/2 count | Allocation pressure | Low Gen1/Gen2 |

### Performance debugging in ASP.NET Core

```csharp
// Add detailed timing to trace slow requests
app.Use(async (context, next) =>
{
    var sw = Stopwatch.StartNew();
    await next();
    sw.Stop();

    if (sw.ElapsedMilliseconds > 500)
    {
        var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
        logger.LogWarning("Slow request: {Method} {Path} took {Ms}ms",
            context.Request.Method, context.Request.Path, sw.ElapsedMilliseconds);
    }
});
```

### BenchmarkDotNet with ASP.NET Core (overhead isolation)

To benchmark a specific service method directly (not over HTTP):

```csharp
[GlobalSetup]
public void Setup()
{
    var services = new ServiceCollection();
    services.AddDbContext<AppDbContext>(...);
    services.AddScoped<IProductService, ProductService>();
    _provider = services.BuildServiceProvider();
}

[Benchmark]
public async Task GetProducts_100Items()
{
    using var scope = _provider.CreateScope();
    var svc = scope.ServiceProvider.GetRequiredService<IProductService>();
    var products = await svc.GetProductsAsync(CancellationToken.None);
    _ = products.Count;
}
```

## Code Example

```javascript
// k6 spike test — sudden traffic increase
export const options = {
  stages: [
    { duration: '10s', target: 10  },  // baseline
    { duration: '10s', target: 200 },  // spike
    { duration: '3m',  target: 200 },  // sustain spike
    { duration: '10s', target: 10  },  // recover
    { duration: '3m',  target: 10  },  // post-spike baseline
  ],
};
```

```csharp
// BenchmarkDotNet: test multiple serializer options
[Params(1, 10, 100)]
public int ItemCount { get; set; }

[Benchmark]
public string SerializeProducts()
{
    var products = Enumerable.Range(1, ItemCount)
        .Select(i => new Product(i, $"Product {i}", i * 1.99m))
        .ToList();
    return JsonSerializer.Serialize(products);
}
```

## Common Follow-up Questions

- What is the difference between latency and throughput, and how do they trade off under load?
- How do you profile ASP.NET Core applications under load using `dotnet-trace` and `PerfView`?
- What are common causes of `p99` latency spikes in .NET applications (GC pauses, thread pool starvation)?
- How do you interpret memory allocation numbers from BenchmarkDotNet's `[MemoryDiagnoser]`?
- What is `Bombardier` and when would you use it instead of k6?

## Common Mistakes / Pitfalls

- **Running benchmarks in Debug mode** — JIT optimizations are disabled; results are meaningless. Always use `Release` mode.
- **Not warming up the server before measuring** — the first few requests trigger JIT compilation and DI resolution; always include a warm-up phase in load tests.
- **Load testing against localhost** — network overhead is eliminated, masking real latency; test against a staging environment that mirrors production.
- **Ignoring p99 in favor of averages** — averages hide tail latency; a p99 of 5 seconds means 1% of users wait 5 seconds, which is often unacceptable.
- **Not testing with realistic data sizes** — a benchmark with 1 row is not representative of 1 million rows; parameterize with `[Params]` to cover realistic ranges.

## References

- [BenchmarkDotNet documentation](https://benchmarkdotnet.org)
- [k6 documentation](https://k6.io/docs/)
- [NBomber documentation](https://nbomber.com/docs/)
- [Microsoft — .NET performance profiling](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-trace)
- [Andrew Lock — BenchmarkDotNet in .NET](https://andrewlock.net/benchmarking-a-csharp-collection/) (verify URL)
