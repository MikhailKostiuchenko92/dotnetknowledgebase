# Chaos Engineering Basics

**Category:** Architecture / Resilience
**Difficulty:** 🔴 Senior
**Tags:** `chaos-engineering`, `fault-injection`, `Azure-Chaos-Studio`, `Simmy`, `resilience-testing`, `GameDay`

## Question

> What is chaos engineering, and how do you apply it in a .NET microservices environment? Compare fault injection with Simmy (Polly), Azure Chaos Studio, and structured Game Day exercises.

## Short Answer

Chaos engineering is the practice of deliberately injecting failures into a system to uncover resilience weaknesses before they cause real outages. The cycle: form a **hypothesis** ("the system handles InventoryService failures gracefully"), inject a fault (network delay, HTTP error, exception), **observe** the system's behavior, and either confirm the hypothesis or improve the system. In .NET: **Simmy** (Polly chaos addon) injects faults into Polly pipelines for unit/integration tests. **Azure Chaos Studio** injects infrastructure-level faults (VM crashes, network partitions) in staging environments. **Game Day** is a team exercise where engineers intentionally break things in a controlled session.

## Detailed Explanation

### Why Chaos Engineering

```
Traditional approach: add resilience patterns → trust they work → discover gaps in production

Chaos engineering approach:
  1. Define steady state: system is healthy (metrics: latency p99 < 200ms, error rate < 0.1%)
  2. Hypothesize: "If InventoryService fails, orders degrade gracefully (no timeouts, no 500s)"
  3. Inject fault: return 503 from InventoryService
  4. Observe: does error rate stay < 0.1%? Does latency stay < 200ms?
  5. Result A (hypothesis confirmed): resilience works as designed
     Result B (hypothesis rejected): fix the gap → re-test
  6. Run in production (gradually, with blast radius control)

Netflix Chaos Monkey: randomly terminates VMs in production to force teams to build fault-tolerant services
Principle: "Hope is not a strategy" — test your resilience or the first outage will
```

### Simmy: Fault Injection in Polly Pipelines

```csharp
// NuGet: Simmy (Polly.Contrib.Simmy)
// Inject faults into Polly pipelines — great for integration and load tests

using Polly.Simmy;

// Development/test: add chaos to pipeline
var chaosPipeline = new ResiliencePipelineBuilder<HttpResponseMessage>()
    // Real resilience strategies first
    .AddRetry(new RetryStrategyOptions<HttpResponseMessage> { MaxRetryAttempts = 3 })
    .AddCircuitBreaker(new CircuitBreakerStrategyOptions<HttpResponseMessage>())
    // Chaos layer (inject AFTER resilience to test whether resilience handles it)
    .AddChaosLatency(new ChaosLatencyStrategyOptions
    {
        Enabled = true,
        InjectionRate = 0.1,           // ← 10% of calls get extra latency
        Latency = TimeSpan.FromSeconds(3),
        Randomizer = new SystemRandomizer()
    })
    .AddChaosFault(new ChaosFaultStrategyOptions
    {
        InjectionRate = 0.05,          // ← 5% of calls throw exception
        FaultGenerator = args => ValueTask.FromResult<Exception?>(new HttpRequestException("Simmy fault"))
    })
    .Build();

// Enable/disable chaos via configuration (NEVER in production)
builder.Services.AddResiliencePipeline("inventory-with-chaos", (pipeline, ctx) =>
{
    var env = ctx.ServiceProvider.GetRequiredService<IWebHostEnvironment>();
    var config = ctx.ServiceProvider.GetRequiredService<IConfiguration>();

    pipeline.AddRetry(new RetryStrategyOptions { MaxRetryAttempts = 3, UseJitter = true });

    if (!env.IsProduction() && config.GetValue<bool>("ChaosEngineering:Enabled"))
    {
        pipeline.AddChaosLatency(new ChaosLatencyStrategyOptions
        {
            Enabled = true,
            InjectionRate = config.GetValue<double>("ChaosEngineering:LatencyInjectionRate", 0.1),
            Latency = TimeSpan.FromMilliseconds(
                config.GetValue<int>("ChaosEngineering:LatencyMs", 2000))
        });
    }
});
```

### Azure Chaos Studio

```
Azure Chaos Studio injects infrastructure-level faults — cannot be done in code:
  - VM shutdown / restart
  - Container group restart
  - Network partition (block traffic between services)
  - CPU pressure
  - Memory pressure
  - AKS pod failure

Workflow:
  1. Define "target" (Azure resource: VM, AKS cluster, App Service)
  2. Enable chaos on the target (resource provider registration)
  3. Create Experiment: steps → branches → faults
  4. Run experiment → observe metrics in Azure Monitor / Application Insights
  5. Confirm hypothesis or fix and rerun

YAML experiment (network partition):
  - name: Block InventoryService outbound traffic
    actions:
      - type: delay
        duration: PT5M
      - type: network-fault
        target: inventory-vm
        parameters:
          networkInterfaceName: eth0
          destinationFilters:
            - address: 10.0.0.5
```

### Game Day Exercise

```
Game Day structure:
  1. Pre-work (1 week before):
     - Document target system's steady state metrics
     - List top 5 failure scenarios with hypotheses
     - Prepare rollback plan per scenario
     - Schedule during low-traffic window

  2. Game Day (2–4 hours):
     - Assign roles: facilitator, chaos injector, observers (monitoring), scribe
     - Run scenarios one at a time:
       a. Baseline check (system is healthy)
       b. Inject fault
       c. Observe and document behavior
       d. Restore (stop fault injection)
       e. Document findings

  3. Post-work (1 week after):
     - Remediation tickets for confirmed gaps
     - Update runbooks and alerting
     - Schedule follow-up Game Day to verify fixes
```

## Code Example

```csharp
// Integration test: use Simmy to verify circuit breaker opens correctly
[Fact]
public async Task CircuitBreaker_OpensAfter_SustainedFailures()
{
    var openCount = 0;
    var pipeline = new ResiliencePipelineBuilder<HttpResponseMessage>()
        .AddCircuitBreaker(new CircuitBreakerStrategyOptions<HttpResponseMessage>
        {
            FailureRatio = 0.5,
            MinimumThroughput = 4,
            SamplingDuration = TimeSpan.FromSeconds(10),
            BreakDuration = TimeSpan.FromSeconds(5),
            OnOpened = _ => { openCount++; return ValueTask.CompletedTask; }
        })
        // Inject 100% failure rate to force circuit open
        .AddChaosFault(new ChaosFaultStrategyOptions
        {
            InjectionRate = 1.0,
            FaultGenerator = _ => ValueTask.FromResult<Exception?>(
                new HttpRequestException("Chaos fault"))
        })
        .Build();

    // Make 5 calls — circuit should open after MinimumThroughput (4) failures
    for (int i = 0; i < 5; i++)
        await pipeline.ExecuteAsync(_ => ValueTask.FromResult(new HttpResponseMessage()), ct)
            .ContinueWith(_ => { }, ct); // ignore exceptions

    Assert.Equal(1, openCount); // circuit should have opened exactly once
}
```

## Common Follow-up Questions

- What is the difference between fault injection testing and load testing?
- How do you define "steady state" quantitatively for a chaos experiment?
- How do you limit the blast radius of a chaos experiment in production?
- When is it safe to run chaos experiments in production vs staging only?
- How does Netflix's Chaos Monkey relate to modern chaos engineering tools?

## Common Mistakes / Pitfalls

- **Chaos without a hypothesis**: randomly breaking things without a specific testable hypothesis produces noise, not insight. Always define: "We believe X will happen when Y fails — confirm or deny."
- **Chaos in production without a rollback plan**: injecting faults in production without prepared rollback procedures can escalate into real incidents. Always define how to stop the experiment and restore service.
- **Using Simmy in production code**: Simmy/chaos injection must be gated behind environment checks and configuration flags. NEVER ship chaos injection to production as a permanent feature.
- **Testing only in staging**: staging environments often have different scale, traffic patterns, and dependencies than production. Eventual goal is to run constrained experiments in production with blast-radius limits.

## References

- [Azure Chaos Studio documentation](https://learn.microsoft.com/en-us/azure/chaos-studio/)
- [Simmy — Polly chaos addon](https://github.com/Polly-Contrib/Simmy)
- [Chaos Engineering principles](https://principlesofchaos.org/)
- [See: resilience-patterns-overview.md](./resilience-patterns-overview.md)
- [See: designing-for-partial-failure.md](./designing-for-partial-failure.md)
