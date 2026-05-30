# Describe a time you introduced observability or monitoring that later caught a real issue.

**Category:** Problem Solving & Technical Decisions
**Difficulty:** 🔴 Senior
**Tags:** `observability`, `monitoring`, `opentelemetry`, `alerting`, `sre`, `production`

## Question
> Describe a time you introduced observability or monitoring that later caught a real issue.

## Short Answer
I instrumented a payment processing service with structured logging, distributed traces, and a custom metric for payment settlement latency. Three weeks later, that metric triggered an alert for an upstream payment gateway's latency degradation — 4 hours before it escalated into a full gateway outage. Our team was able to notify stakeholders and implement graceful degradation before customers were impacted.

## What the Interviewer Is Looking For

This question tests your understanding that **observability is a proactive discipline, not a reactive cleanup task**. Interviewers want to see:

- You think about what could go wrong when you build something, and instrument for it.
- You understand the three pillars of observability: metrics, traces, logs.
- You've had the experience of instrumentation saving the day — this demonstrates real operational maturity.
- You know the difference between monitoring (watching known-bad states) and observability (being able to ask novel questions about system state).

### Three Pillars of Observability

| Pillar | What It Answers | Tools (.NET) |
|--------|----------------|--------------|
| Metrics | "How is the system performing right now?" | `System.Diagnostics.Metrics`, Prometheus, Azure Monitor |
| Traces | "What happened for this specific request?" | OpenTelemetry, Application Insights |
| Logs | "What events occurred and in what context?" | Serilog, `ILogger`, structured JSON logs |

> **⚠ Tip:** The best observability stories involve a custom metric or alert, not just "we added logging." Custom business-level metrics (payment latency, order completion rate, checkout funnel drop-off) show production engineering maturity.

## Example STAR Answer

**Situation:**
I joined a payment team where all three payment processing services had been running for 2 years with minimal telemetry: application-level exception logs and basic HTTP status code monitoring. There was no end-to-end trace, no business-level metric, and no alert for degraded (but non-failing) payment gateway responses.

**Task:**
I led a 2-sprint observability improvement initiative: instrument the critical payment path with distributed tracing, structured logging, and business-level metrics.

**Action:**

*Sprint 1 — Foundations:*
Added OpenTelemetry instrumentation across all 3 services:
- Distributed traces for every payment initiation-to-settlement flow, including gateway calls.
- Structured logging with correlation IDs propagated across service boundaries.
- Standard runtime metrics via `dotnet-counters` exported to Azure Monitor.

*Sprint 2 — Business-level metrics and alerts:*
Added custom metrics using `System.Diagnostics.Metrics`:

```csharp
private static readonly Histogram<double> PaymentSettlementLatency =
    Meter.CreateHistogram<double>("payment.settlement.latency_ms");

// In the settlement path:
PaymentSettlementLatency.Record(elapsed.TotalMilliseconds, 
    new TagList { { "gateway", gatewayName }, { "status", result.Status } });
```

I configured two alerts:
1. **P99 settlement latency > 3,000 ms** for any 5-minute window → PagerDuty alert.
2. **Settlement success rate < 98%** for any 10-minute window → Slack warning.

*The payoff — 3 weeks later:*
At 2:15 AM, alert 1 fired: P99 settlement latency had risen from 900 ms to 4,200 ms for our primary payment gateway. Our services were technically functioning. The distributed trace showed all the latency was inside the external gateway call.

I was on call. I escalated to the payments gateway's status page — nothing posted yet. I called their on-call line. They confirmed an internal issue and had begun investigation. I notified our ops team and enabled our fallback gateway (secondary payment processor, pre-configured but dormant).

4 hours later, the primary gateway posted an incident report. Our customers saw zero failed payments. Our internal monitoring had caught the issue 4 hours before their own public status page acknowledged it.

**Result:**
Zero customer-facing payment failures during the incident. Engineering leadership cited this as an example of proactive SRE practice. The custom metrics and alert setup became the team's standard for all new integrations.

## Reflection / What I'd Do Differently
I would implement a **synthetic transaction monitor** — a recurring test payment against each gateway using a test account — in addition to live traffic metrics. This would catch gateway issues even during low-traffic periods (nights, weekends) where live metric volume might be too low to trigger statistical alerts.

## Common Follow-up Questions
- What's the difference between observability and monitoring?
- What are the three pillars of observability and when do you prioritise one over another?
- How do you instrument a service with OpenTelemetry in .NET?
- What is a Service Level Objective (SLO) and how do you set one?
- How do you avoid alert fatigue when instrumenting a system?
- What metrics would you add to a new API service on day one?

## Common Mistakes / Pitfalls
- **Only logging exceptions** — exceptions are lagging indicators; business-level metrics are leading indicators.
- **No correlation IDs** — distributed traces are only useful if requests can be correlated across service boundaries.
- **Alert on every anomaly** — over-alerting creates alert fatigue and causes real alerts to be ignored.
- **Instrumenting after incidents** — observability added reactively only catches the same class of incident. Proactive instrumentation catches novel failures.
- **Only monitoring infrastructure** — CPU, memory, and network metrics tell you the machine is sick, not that the business is failing. Add application-level and business-level metrics.
- **Not testing alerts** — if an alert has never fired in a controlled test, you don't know if it works.

## References
- [OpenTelemetry for .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel)
- [System.Diagnostics.Metrics — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/metrics)
- [Structured Logging with Serilog](https://serilog.net/)
- [Google SRE Book — Chapter on Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Azure Monitor Alerts — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)

[See also: Managed Multiple High-Priority Incidents](managed-multiple-high-priority-incidents.md)
