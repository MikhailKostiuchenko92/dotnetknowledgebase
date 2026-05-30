# Chaos Engineering

**Category:** System Design / Observability
**Difficulty:** Senior
**Tags:** `chaos-engineering`, `resilience`, `blast-radius`, `steady-state`, `fault-injection`, `azure-chaos-studio`

## Question

> What is chaos engineering? How does it differ from traditional testing? Walk me through designing a chaos experiment for a microservices system. What tools are available in the Azure/.NET ecosystem?

- What is the "steady-state hypothesis" and why is it central to chaos experiments?
- How do you limit the blast radius of an experiment?

## Short Answer

Chaos engineering is the practice of deliberately injecting failures into a production (or production-like) system to discover weaknesses before they cause incidents. Unlike unit/integration tests that verify known failure modes, chaos engineering uncovers **unknown unknowns** — failure modes no one predicted. Every experiment starts with a **steady-state hypothesis** (what "normal" looks like in metrics), injects a failure (network partition, pod kill, latency spike), and verifies the system returns to steady state. Blast radius is controlled by starting experiments on a small percentage of traffic or non-critical environments, then expanding confidence.

## Detailed Explanation

### Chaos vs Traditional Testing

| | Unit/Integration Tests | Chaos Engineering |
|--|------------------------|------------------|
| Failure mode | Known, coded by developer | Unknown, discovered empirically |
| Environment | Isolated test environment | Production or production-like |
| Goal | Verify correctness | Discover systemic weaknesses |
| Output | Pass/fail | Observations + hypotheses |
| Frequency | Every CI run | Scheduled experiments, game days |

### Core Principles (Netflix Chaos Engineering Principles)

1. **Build a hypothesis around steady-state behaviour** — define measurable normality first.
2. **Vary real-world events** — inject real failure types (network partition, instance kill, CPU saturation).
3. **Run experiments in production** — staging rarely reproduces production failure modes accurately.
4. **Automate experiments** — manual experiments are too slow; automate and run continuously.
5. **Minimise blast radius** — start small, expand gradually.

### Experiment Design Template

#### Step 1: Define Steady State

Identify the metrics that describe "normal":
- Request success rate > 99.5%
- p99 latency < 800 ms
- Active orders processed per minute > 1,000

#### Step 2: Hypothesis

"If we terminate one of three Orders API pods, the remaining pods will absorb traffic within 10 seconds, and success rate will not drop below 99% for more than 30 seconds."

#### Step 3: Inject Failure

Choose a failure type matching a realistic production risk:

| Failure Type | Tool | Scenario |
|-------------|------|---------|
| Pod kill | k8s `kubectl delete pod` / Chaos Mesh | Unplanned restart |
| CPU saturation | stress-ng / Azure Chaos Studio | Noisy neighbour |
| Network latency | tc netem / Chaos Mesh | Slow downstream |
| Network partition | iptables / Chaos Mesh | Service unreachable |
| Disk I/O saturation | fio / Azure Chaos Studio | Slow storage |
| Memory pressure | memhog / Azure Chaos Studio | OOM risk |
| DNS failure | CoreDNS fault injection | Service discovery failure |

#### Step 4: Measure & Observe

Monitor the metrics defined in Step 1 during the experiment.

#### Step 5: Abort Condition

Define an automatic halt: if success rate drops below 95%, abort experiment and restore normal state.

#### Step 6: Learn & Fix

Document weaknesses found. File reliability work tickets. Re-run experiment to verify fix.

### Blast Radius Control

| Technique | Description |
|-----------|-------------|
| **Start in staging** | Run experiments in a production-mirror environment first |
| **Target a single pod/instance** | Kill one of five, not all five |
| **Limit to a traffic percentage** | Use feature flags to route only 5% of users to the chaos target |
| **Time-box experiments** | Auto-restore after 5 minutes regardless of outcome |
| **Abort conditions** | Halt if SLO breach exceeds threshold (e.g., error rate > 5%) |
| **Off-peak timing** | Run during low-traffic windows initially |

> **Warning:** Never run chaos experiments on databases without a tested restore procedure. A pod kill is reversible; accidental data corruption is not.

### Azure Chaos Studio

Azure Chaos Studio is the managed chaos platform for Azure workloads. It supports agent-based experiments (inside the VM/container) and service-based experiments (Azure platform faults):

| Fault | Target |
|-------|--------|
| VM shutdown | Azure VM |
| AKS pod chaos | Kubernetes pod |
| Cosmos DB failover | Cosmos DB (trigger regional failover) |
| Service Bus: message hold | Azure Service Bus |
| CPU pressure | VM agent (stress-ng under the hood) |
| Network latency | VM / AKS pod |

### Chaos Mesh (Kubernetes-native)

Chaos Mesh runs in Kubernetes and injects failures via CRDs:

```yaml
# Kill a random Orders API pod every 10 minutes during business hours
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: orders-pod-kill
  namespace: production
spec:
  action: pod-kill
  mode: one                         # kill one pod at a time
  selector:
    namespaces: [production]
    labelSelectors:
      app: orders-api
  scheduler:
    cron: "*/10 9-17 * * 1-5"      # business hours weekdays
```

```yaml
# Inject 200ms network latency on outbound calls from Inventory service
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: inventory-latency
spec:
  action: delay
  mode: all
  selector:
    labelSelectors:
      app: inventory-api
  delay:
    latency: "200ms"
    correlation: "25"
    jitter: "50ms"
  duration: "5m"
```

### Game Day

A "game day" is a scheduled chaos exercise involving engineers, operations, and sometimes product owners:
1. Brief: review hypothesis, abort conditions, communication channels.
2. Execute: run planned experiments; observe metrics together.
3. Improvise: senior engineer introduces unannounced failures (realistic simulation).
4. Retrospective: document findings, assign reliability tickets.

Game days build shared understanding of the system's failure modes across the team.

## Code Example

```csharp
// Resiliency verification test — complements chaos experiments
// Uses Polly to assert that the system degrades gracefully under failure

using Polly;
using Polly.CircuitBreaker;

namespace ChaosTests;

// Test: circuit breaker opens when downstream fails 50%
public class CircuitBreakerChaosTest
{
    [Fact]
    public async Task CircuitOpens_WhenHalfOfCallsFail()
    {
        var failureCount = 0;

        // Simulate an unreliable downstream
        var handler = new MockHttpMessageHandler(req =>
        {
            Interlocked.Increment(ref failureCount);
            // Fail every other request
            return failureCount % 2 == 0
                ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                : new HttpResponseMessage(HttpStatusCode.OK);
        });

        var client = new HttpClient(handler) { BaseAddress = new Uri("http://test") };

        var pipeline = new ResiliencePipelineBuilder<HttpResponseMessage>()
            .AddCircuitBreaker(new CircuitBreakerStrategyOptions<HttpResponseMessage>
            {
                FailureRatio      = 0.5,
                SamplingDuration  = TimeSpan.FromSeconds(10),
                MinimumThroughput = 10,
                BreakDuration     = TimeSpan.FromSeconds(30),
            })
            .Build();

        // Send 20 requests — circuit should open after ~10 with 50% failure rate
        var results = new List<(bool success, bool circuitOpen)>();
        for (var i = 0; i < 20; i++)
        {
            try
            {
                var response = await pipeline.ExecuteAsync(
                    async ct => await client.GetAsync("/api/test", ct));
                results.Add((response.IsSuccessStatusCode, false));
            }
            catch (BrokenCircuitException)
            {
                results.Add((false, true));  // circuit open — fast-fail, no network call
            }
        }

        // Assert: circuit eventually opened (fast-fails occurred)
        Assert.Contains(results, r => r.circuitOpen);
        // Assert: service was not hammered while circuit was open
        Assert.True(failureCount < 20, "Should stop calling downstream after circuit opens");
    }
}
```

## Common Follow-up Questions

- How do you run chaos experiments on a database without risking data loss?
- A chaos experiment reveals that your circuit breaker is configured incorrectly and opens too slowly. How do you fix this without redeploying?
- How do you automate chaos experiments in a CI/CD pipeline (run on every deployment)?
- What is the difference between fault injection (known failure) and chaos (unknown failure)?
- How do you measure the ROI of chaos engineering to justify it to management?

## Common Mistakes / Pitfalls

- **No steady-state definition before the experiment**: without a baseline, you can't tell whether the experiment revealed a problem or the system was already degraded.
- **Skipping the abort condition**: an experiment that runs unchecked when the system is already stressed can cause a real outage.
- **Running chaos in staging only**: production has traffic patterns, data volumes, and third-party integrations that staging never replicates; staging experiments provide false confidence.
- **Chaos without on-call engineer monitoring**: never run experiments unattended; have the on-call engineer watching metrics and ready to abort.
- **Treating chaos as a one-off exercise**: chaos engineering is a continuous practice, not a quarterly event; automate it.
- **Chaos before basic resiliency patterns exist**: if the service has no retry logic, circuit breakers, or health checks, chaos experiments will just find obvious failures. Implement baseline resilience first.

## References

- [Principles of Chaos Engineering — principlesofchaos.org](https://principlesofchaos.org/)
- [Chaos Monkey — Netflix](https://netflix.github.io/chaosmonkey/)
- [Azure Chaos Studio — Microsoft Learn](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview)
- [Chaos Mesh — chaos-mesh.org](https://chaos-mesh.org/)
- [See: slos-slas-error-budgets.md](./slos-slas-error-budgets.md)
- [See: circuit-breaker-pattern.md](./circuit-breaker-pattern.md)
