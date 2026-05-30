# What Is NBomber and How Does It Differ From BenchmarkDotNet?

**Category:** Testing / Performance & Load Testing
**Difficulty:** 🟡 Middle
**Tags:** `NBomber`, `load-testing`, `performance`, `BenchmarkDotNet`, `HTTP`, `.NET`

## Question
> What is NBomber and how does it differ from BenchmarkDotNet?

## Short Answer
**BenchmarkDotNet** measures the performance of individual in-process code paths (micro-benchmarks). **NBomber** is a load testing framework that simulates multiple concurrent users hitting an external service (HTTP API, gRPC, database, message queue). They answer different questions: BenchmarkDotNet asks "how fast is this method?"; NBomber asks "how does the service behave under N concurrent users?"

## Detailed Explanation

### Comparison Table

| Aspect | BenchmarkDotNet | NBomber |
|---|---|---|
| Scope | In-process code | External service / API |
| What it simulates | Single-thread micro-measurement | Concurrent virtual users |
| Use case | Micro-optimisation, algorithm comparison | Load testing, capacity planning |
| Metrics | Mean, median, p95, allocations | RPS, latency p50/p95/p99, error rate |
| Execution | Thousands of iterations, single thread | Configurable concurrent users |
| Report | Console table + HTML | HTML dashboard with graphs |

### When to Use Each

| Question | Tool |
|---|---|
| Is `Span<T>` faster than `string` for this parsing? | BenchmarkDotNet |
| Can our API handle 500 concurrent users? | NBomber |
| Does my LINQ query allocate too much? | BenchmarkDotNet |
| What is the p99 latency of `/checkout` under load? | NBomber |
| Which serializer is faster? | BenchmarkDotNet |
| When does our DB connection pool get exhausted? | NBomber |

### NBomber Basic Setup
```shell
dotnet add package NBomber
dotnet add package NBomber.Http
```

```csharp
using NBomber.CSharp;
using NBomber.Http.CSharp;

var httpClient = new HttpClient();

var scenario = Scenario.Create("checkout_scenario", async context =>
{
    var response = await httpClient.GetAsync("https://localhost:5001/api/orders");
    return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
})
.WithWarmUpDuration(TimeSpan.FromSeconds(5))
.WithLoadSimulations(
    Simulation.Inject(rate: 50, interval: TimeSpan.FromSeconds(1),
                      during: TimeSpan.FromSeconds(30))
);

NBomberRunner
    .RegisterScenarios(scenario)
    .Run();
```

### Load Simulation Profiles

| Simulation | Meaning |
|---|---|
| `Inject(rate, interval, during)` | Inject N requests per interval (open model) |
| `InjectPerSec(rate, during)` | Inject N per second |
| `KeepConstant(copies, during)` | Keep N virtual users alive |
| `RampingInject(rate, during)` | Gradually increase rate |

### Reading the Report
```
Stats:
  Scenario: checkout_scenario
  Duration: 30s
  OK count: 1482
  Fail count: 18
  RPS: 49.4

Latency (ms):
  p50: 18  | p75: 23 | p95: 45 | p99: 112
```

## Code Example
```csharp
using NBomber.CSharp;
using NBomber.Http.CSharp;

var http = new HttpClient { BaseAddress = new Uri("http://localhost:5001") };

var getProducts = Scenario.Create("GET /products", async ctx =>
{
    var response = await http.GetAsync($"/api/products?page={ctx.ScenarioInfo.ThreadNumber % 10}");
    return response.IsSuccessStatusCode
        ? Response.Ok(statusCode: (int)response.StatusCode)
        : Response.Fail(statusCode: (int)response.StatusCode);
})
.WithLoadSimulations(
    Simulation.RampingInject(rate: 100, interval: TimeSpan.FromSeconds(1),
                              during: TimeSpan.FromSeconds(10)),
    Simulation.Inject(rate: 100, interval: TimeSpan.FromSeconds(1),
                      during: TimeSpan.FromSeconds(30))
);

NBomberRunner
    .RegisterScenarios(getProducts)
    .WithReportFolder("load-report")
    .WithReportFormats(ReportFormat.Html)
    .Run();
```

## Common Follow-up Questions
- What is the difference between open and closed load models in NBomber?
- How do you model think time between user actions in NBomber?
- How does NBomber compare to k6 or Gatling?
- How do you run NBomber tests in CI without hitting production?
- How do you parameterize NBomber scenarios with test data?

## Common Mistakes / Pitfalls
- **Running load tests against production** — always use a dedicated test environment.
- **Not warming up** — cold starts skew early latency; always configure `WithWarmUpDuration`.
- **Ignoring error rates** — high RPS with 30% failures is not a passing load test.
- **Using `KeepConstant` when `Inject` is more realistic** — real traffic patterns are open (arriving) not closed (think-time-bounded).

## References
- [NBomber official site](https://nbomber.com/)
- [NBomber GitHub](https://github.com/PragmaticFlow/NBomber)
- [NBomber documentation](https://nbomber.com/docs/getting-started/overview)
