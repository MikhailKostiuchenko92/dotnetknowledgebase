# SLOs, SLAs, and Error Budgets

**Category:** System Design / Observability
**Difficulty:** Senior
**Tags:** `slo`, `sla`, `sli`, `error-budget`, `reliability`, `burn-rate`

## Question

> Explain the difference between SLI, SLO, and SLA. What is an error budget and how does it guide engineering decisions? How do you calculate burn rate alerts?

- How do you choose SLI metrics for a service?
- What happens when an error budget is exhausted?

## Short Answer

An **SLI** (Service Level Indicator) is a measured metric (e.g., error rate, p99 latency). An **SLO** (Service Level Objective) is the target for that metric (e.g., "99.9% of requests succeed"). An **SLA** (Service Level Agreement) is a contractual promise to customers — an SLO with financial penalties for breach. An **error budget** is the allowed failure headroom implied by the SLO (99.9% availability = 0.1% budget = 43.8 min downtime/month). When the budget is healthy, teams ship features; when it's exhausted, reliability work takes priority over features. Burn rate alerts fire when you're consuming the budget faster than the SLO allows.

## Detailed Explanation

### SLI → SLO → SLA Hierarchy

```
SLI (measurement):
  "Error rate over last 5 min = 0.3%"
     ↓
SLO (target, internal):
  "Error rate must stay below 0.1% — measured monthly"
     ↓
SLA (contractual, external):
  "We guarantee 99.9% availability per month. If breached, customer receives 10% credit."
```

SLOs are tighter than SLAs. You want to know internally (SLO breach) before the customer does (SLA breach).

### Choosing SLIs

Good SLIs are **user-facing** and **directly measurable**:

| Service Type | SLI Examples |
|-------------|-------------|
| API / web service | Request success rate, p99 latency, error rate |
| Batch pipeline | Job completion rate, data freshness (lag), throughput |
| Storage / DB | Read/write availability, durability (data loss rate) |
| Messaging | Message delivery rate, consumer lag |

**Not good SLIs**: CPU utilisation, memory usage, disk space — these are symptoms (USE metrics), not user experience.

### Error Budget

The error budget is the complement of the SLO target:

| SLO | Allowed errors (monthly) | Allowed downtime (monthly) |
|-----|--------------------------|--------------------------|
| 99% | 1% | 7.2 hours |
| 99.9% | 0.1% | 43.8 minutes |
| 99.95% | 0.05% | 21.9 minutes |
| 99.99% | 0.01% | 4.4 minutes |

**Error budget policy**:
- Budget > 50% remaining → ship features aggressively, accept risk.
- Budget 10–50% remaining → slow down, no high-risk deploys.
- Budget < 10% remaining → freeze feature work, focus on reliability.
- Budget exhausted → feature freeze until budget resets (next month).

This makes reliability trade-offs explicit and data-driven rather than political.

### Error Budget Burn Rate

Burn rate measures how fast you're consuming the budget relative to the allowed rate.

```
Error budget for 30 days at 99.9% = 0.1% × 30 days = 43.8 min

If current error rate = 1%:
  Budget burn rate = 1% / 0.1% = 10×
  At 10× burn rate, budget exhausted in: 30 days / 10 = 3 days
```

A burn rate of 1× means you'll exactly exhaust the budget in 30 days. >1× means you're burning faster than allowed.

### Multi-Window Burn Rate Alerts (Google SRE Approach)

Single-window alerts (just "error rate > threshold for 5 min") are noisy for transient spikes. Multi-window burn rate pairs a **slow burn** (1-hour window) with a **fast spike** (5-minute window) to distinguish:

| Alert | Burn Rate | Detection Window | Sensitivity |
|-------|-----------|-----------------|------------|
| Page (critical) | 14.4× | 1h + 5m | 2% budget in 1h |
| Page (high) | 6× | 6h + 30m | 5% budget in 6h |
| Ticket (warning) | 3× | 24h + 2h | 10% budget in 24h |
| Warning | 1× | 3 days | Budget on track |

```yaml
# Prometheus — multi-window burn rate for 99.9% SLO
groups:
  - name: slo-orders
    rules:
      # SLI: request success rate
      - record: job:orders_success_rate:rate5m
        expr: |
          rate(http_server_request_duration_count{job="orders",http_response_status_code!~"5.."}[5m])
          /
          rate(http_server_request_duration_count{job="orders"}[5m])

      # Page alert: 14.4× burn rate
      - alert: OrdersSLOCriticalBurn
        expr: |
          (1 - job:orders_success_rate:rate5m) > (14.4 * 0.001)
          and
          (1 - rate(http_server_request_duration_count{job="orders",http_response_status_code!~"5.."}[1h])
               / rate(http_server_request_duration_count{job="orders"}[1h]))
            > (14.4 * 0.001)
        for: 2m
        labels:
          severity: page
        annotations:
          summary: "Orders SLO burning at 14.4× rate — error budget exhausted in < 2 hours"

      # Warning: 6× burn rate
      - alert: OrdersSLOHighBurn
        expr: |
          (1 - job:orders_success_rate:rate5m) > (6 * 0.001)
          and
          (1 - rate(http_server_request_duration_count{job="orders",http_response_status_code!~"5.."}[6h])
               / rate(http_server_request_duration_count{job="orders"}[6h]))
            > (6 * 0.001)
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Orders SLO burning at 6× — budget may exhaust in < 5 days"
```

### Toil vs Reliability Work

The error budget framework distinguishes:

| | Toil | Reliability Work |
|--|------|-----------------|
| Definition | Manual, repetitive operational work with no lasting improvement | Eliminates toil, improves SLO, reduces incidents |
| Examples | Manually restarting pods, rotating credentials, applying patches | Automating restart, secret rotation, auto-remediation |
| SRE principle | < 50% of SRE time should be toil | Remainder: engineering to reduce future toil |

### SLA Practicalities

- SLAs are **commercial documents** with specific measurement periods (typically monthly), exclusions (planned maintenance windows), and remedies (service credits).
- Your SLO must be significantly tighter than the SLA to give you time to detect and fix before the SLA is breached.
- Common exclusions: scheduled maintenance, force majeure, customer-caused issues, third-party provider outages.

> **Warning:** Setting SLOs too high (99.99%) on services that don't actually need it forces unnecessary toil and prevents the team from ever deploying (each deployment is a risk to the tiny error budget). The correct SLO is the minimum reliability that keeps users happy — not the maximum technically achievable.

## Code Example

```csharp
// Error budget tracker: calculate remaining budget from Prometheus
// (Illustrative — production uses Grafana dashboards)

namespace Reliability;

public sealed class ErrorBudgetCalculator
{
    private const double SloTarget = 0.999; // 99.9%
    private static readonly TimeSpan Window = TimeSpan.FromDays(30);

    /// <summary>
    /// Returns remaining error budget as a fraction of the total (0–1).
    /// budgetRemaining = 1.0 means no errors consumed; 0.0 means exhausted.
    /// </summary>
    public static double Calculate(long totalRequests, long failedRequests)
    {
        if (totalRequests == 0) return 1.0;

        var allowedFailures      = totalRequests * (1 - SloTarget); // e.g., 1 in 1000
        var remainingAllowance   = allowedFailures - failedRequests;
        return Math.Max(0, remainingAllowance / allowedFailures);
    }

    /// <summary>
    /// Returns current burn rate multiplier.
    /// 1.0 = consuming budget exactly on pace; >1 = burning faster.
    /// </summary>
    public static double BurnRate(double currentErrorRate)
    {
        var allowedErrorRate = 1 - SloTarget;      // 0.001 for 99.9%
        return currentErrorRate / allowedErrorRate;
    }

    /// <summary>
    /// Time until budget exhausted at current burn rate.
    /// </summary>
    public static TimeSpan TimeToExhaustion(double burnRate, double budgetRemaining)
    {
        if (burnRate <= 0) return TimeSpan.MaxValue;
        var fraction = budgetRemaining / burnRate;
        return Window * fraction;
    }
}

// Usage in a background metric publisher
public class BudgetMetricsService(
    IPrometheusRegistry registry,
    ILogger<BudgetMetricsService> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var (total, failed) = await QueryPrometheusAsync(ct);
            var budgetRemaining = ErrorBudgetCalculator.Calculate(total, failed);
            var burnRate        = ErrorBudgetCalculator.BurnRate((double)failed / total);

            registry.GetGauge("slo_error_budget_remaining").Set(budgetRemaining);
            registry.GetGauge("slo_error_budget_burn_rate").Set(burnRate);

            if (budgetRemaining < 0.1)
                log.LogWarning(
                    "Error budget below 10%! Remaining: {Budget:P1}, Burn rate: {Rate:F1}×",
                    budgetRemaining, burnRate);

            await Task.Delay(TimeSpan.FromMinutes(5), ct);
        }
    }

    private Task<(long total, long failed)> QueryPrometheusAsync(CancellationToken ct)
        => Task.FromResult((total: 1_000_000L, failed: 500L)); // placeholder
}
```

## Common Follow-up Questions

- How do you write an SLO for a batch pipeline where "availability" is not the right metric?
- What is a "toil budget" and how does it relate to an error budget?
- Your service depends on a third-party API with its own SLA. How does that affect your own SLO commitments?
- How do you handle a planned maintenance window in the context of your error budget?
- How do you present error budget status to non-engineering stakeholders?

## Common Mistakes / Pitfalls

- **Confusing SLO and SLA**: an SLO is an internal engineering target; an SLA is a customer-facing contractual commitment. Using them interchangeably causes miscommunication.
- **Setting SLOs without measuring baselines first**: set SLOs based on what users actually need and what you can actually achieve — not arbitrary round numbers (99.99% sounds good but may be impossible).
- **Single-window burn rate alerts**: `error_rate > 0.001 for 5m` fires on transient spikes and exhausts on-call attention. Use multi-window paired conditions.
- **Not defining what "success" means for the SLI**: does a 429 response count as an error for the SLO? A timeout? Document it.
- **Ignoring the error budget during sprint planning**: if the team never looks at error budget status, the framework is theatre. Review it at the start of each sprint.
- **100% SLO**: there is no such thing. A 100% SLO requires infinite redundancy, prevents all deployments (each one risks availability), and is typically a sign the team hasn't thought through the trade-offs.

## References

- [Google SRE Book — Service Level Objectives (Chapter 4)](https://sre.google/sre-book/service-level-objectives/)
- [Google SRE Workbook — Alerting on SLOs (Chapter 5)](https://sre.google/workbook/alerting-on-slos/)
- [The Site Reliability Workbook — Google](https://sre.google/workbook/table-of-contents/)
- [SLO generator — Google Cloud](https://github.com/google/slo-generator)
- [See: metrics-and-alerting.md](./metrics-and-alerting.md)
- [See: chaos-engineering.md](./chaos-engineering.md)
