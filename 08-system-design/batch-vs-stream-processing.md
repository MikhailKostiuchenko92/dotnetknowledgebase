# Batch vs Stream Processing

**Category:** System Design / Data Pipelines
**Difficulty:** Middle
**Tags:** `batch`, `streaming`, `lambda-architecture`, `kappa-architecture`, `apache-spark`, `kafka-streams`, `azure-stream-analytics`

## Question

> What is the difference between batch and stream processing? When should you choose each? What are Lambda and Kappa architectures? How do you decide between real-time and near-real-time for a given use case?

- What are the trade-offs between latency, throughput, and complexity for each approach?
- How does a .NET team typically handle stream processing on Azure?

## Short Answer

Batch processing runs jobs on accumulated data at scheduled intervals (hourly, nightly) — simple, high throughput, but high latency. Stream processing continuously processes each event as it arrives — low latency, but more complex to implement and operate. Lambda architecture runs both layers in parallel to get the best of both worlds at the cost of maintaining two codebases. Kappa architecture simplifies this by using only a streaming layer that can also replay historical data. For .NET teams on Azure, the typical stack is Azure Stream Analytics (managed streaming with SQL-like syntax) or .NET workers consuming Kafka/Service Bus for custom logic.

## Detailed Explanation

### Batch Processing

Process accumulated data in bulk on a schedule:

```
Source data (24 hours)
       │
       ▼ (midnight)
[Batch Job — Azure Data Factory / SQL Agent / .NET Worker]
       │ (completes after 2 hours)
       ▼
Aggregated results available at 2am
```

**Characteristics:**
- **Latency**: hours (data age = time since last batch run).
- **Throughput**: very high — optimised bulk reads, parallel processing.
- **Failure recovery**: straightforward — rerun the batch from the start.
- **Tools**: Azure Data Factory, SQL Server Agent, .NET `IHostedService` with a CRON timer, Apache Spark.

**Good for**: end-of-day reports, billing, data warehouse loads, ML model training.

### Stream Processing

Process each event as it arrives:

```
Event published by source
       │ (milliseconds later)
       ▼
[Stream Processor — Azure Stream Analytics / Kafka Streams / .NET Worker]
       │ (milliseconds to seconds)
       ▼
Real-time dashboard updated, alert fired, read model updated
```

**Characteristics:**
- **Latency**: milliseconds to seconds.
- **Throughput**: lower than batch per unit time — each event processed individually.
- **Failure recovery**: complex — must track checkpoints (offsets) to avoid reprocessing or skipping.
- **Tools**: Azure Stream Analytics, Kafka Streams, Flink, Apache Spark Structured Streaming.

**Good for**: fraud detection, real-time dashboards, live bidding, IoT sensor alerts, CQRS projections.

### Lambda Architecture

Combines batch and streaming to provide both correctness and low latency:

```
Raw events (all time)
  │
  ├─── Batch layer (reprocesses everything periodically, correct but slow)
  │    └── Batch views: accurate, hours old
  │
  ├─── Speed layer (processes only recent events, fast but approximate)
  │    └── Real-time views: low latency, may have slight inaccuracies
  │
  └─── Serving layer: merges batch + real-time views → single query API
```

**Drawbacks**: two processing pipelines to maintain; logic must be written twice (batch + stream); merging results adds complexity.

### Kappa Architecture (Simplified)

Eliminate the batch layer — use streaming for everything, with the ability to replay historical data:

```
All events stored in Kafka (or Azure Event Hubs) with long retention
       │
       ▼
[Stream Processor] ← processes live stream
       │
       ▼         ← to recompute: replay from offset 0 on a new consumer group
Read models / views
```

Requirements:
1. **Replayable event log**: Kafka with long retention (days/weeks), or Azure Event Hubs with Capture to Blob Storage.
2. **Stateless processing**: the stream processor builds state from events; running it again from the beginning produces the same state.
3. **Dual-run for upgrades**: run new processor version in parallel while old version serves, then atomic cutover.

**Kappa is the preferred modern architecture** for event-sourced systems.

### Windowing in Stream Processing

Stream processors aggregate events over time windows:

| Window type | Description | Example |
|-------------|------------|---------|
| **Tumbling** | Fixed, non-overlapping | Hourly totals (00:00–01:00, 01:00–02:00) |
| **Sliding** | Fixed size, moves with each event | Last 60 minutes at any point |
| **Session** | Variable size, closes after inactivity | User session: ends after 30min of no events |
| **Hopping** | Fixed size, overlapping | Every 15min, report last 60min |

```sql
-- Azure Stream Analytics: tumbling window — count orders per minute
SELECT
    System.Timestamp() AS WindowEnd,
    COUNT(*) AS OrderCount,
    SUM(TotalAmount) AS Revenue
FROM orders TIMESTAMP BY EventTime
GROUP BY TumblingWindow(minute, 1)
```

### .NET Stream Processing with Azure Stream Analytics

Azure Stream Analytics (ASA) is the managed Azure streaming service — SQL-like syntax, no infrastructure to manage:

```sql
-- ASA query: detect fraudulent transactions (>3 payments in 60 seconds from same card)
SELECT
    CardNumber,
    COUNT(*) AS TransactionCount,
    SUM(Amount) AS TotalAmount,
    System.Timestamp() AS WindowEnd
INTO [fraud-alerts-output]
FROM [transactions-input] TIMESTAMP BY EventTime
GROUP BY CardNumber, TumblingWindow(second, 60)
HAVING COUNT(*) > 3
```

### .NET Worker for Custom Stream Logic

For logic that can't be expressed in SQL, a .NET worker consuming Kafka/Service Bus:

```csharp
// .NET streaming worker: compute running order totals per customer (stateful)
public sealed class OrderTotalsStreamWorker(
    IKafkaConsumer<OrderEvent> consumer,
    IOrderTotalsRepository totals) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await foreach (var evt in consumer.ConsumeAsync(ct))
        {
            // Update running total for this customer
            await totals.IncrementAsync(
                evt.CustomerId,
                evt.TotalAmount,
                evt.OccurredAt,
                ct);

            // Emit to downstream projection
            await _projections.UpdateCustomerSummaryAsync(evt.CustomerId, ct);
        }
    }
}
```

### Decision Guide

| Requirement | Choose |
|------------|--------|
| End-of-day reports, billing | Batch |
| Data warehouse ETL | Batch |
| Fraud detection | Stream |
| Live dashboards | Stream |
| ML training on historical data | Batch |
| Real-time recommendations | Stream |
| Nightly aggregations only | Batch |
| CQRS read model projection | Stream |
| Need both correct history + low latency | Lambda / Kappa |

> **Warning:** "Real-time" is often a misunderstood requirement. Many use cases that claim to need real-time actually need "near-real-time" (< 5 minutes). Batch jobs running every 5 minutes may be sufficient, far simpler to implement, and much cheaper to operate than a full streaming pipeline.

## Common Follow-up Questions

- What is exactly-once processing in a streaming system and why is it difficult to achieve?
- How do you handle late-arriving events (events with an old timestamp arriving after the window has closed)?
- What is watermarking in stream processing and how does it bound late data?
- How does Apache Flink differ from Spark Structured Streaming?
- How does Azure Event Hubs Capture enable Kappa architecture replays?

## Common Mistakes / Pitfalls

- **Choosing streaming for simplicity reasons**: stream processing is more complex than batch — checkpointing, watermarks, late data, exactly-once. Only choose streaming if the latency requirement justifies the complexity.
- **Ignoring late data in windowed aggregations**: events may arrive out of order (e.g., mobile app offline for 30 minutes); a window that closes at T+60s may miss events that arrive at T+90s. Design watermarks to handle late arrivals.
- **Stateful streaming without state backend**: accumulating state in worker memory is lost on restart; use a state backend (Redis, Azure Table Storage) for fault-tolerant stateful streaming.
- **Processing order dependency in parallel streams**: if stream processing requires event A before event B, you need partitioning + ordering guarantees — simple parallel consumers won't provide this.

## References

- [Lambda Architecture — Nathan Marz](https://lambda-architecture.net/) (verify URL)
- [Kappa Architecture — Jay Kreps](https://www.oreilly.com/radar/questioning-the-lambda-architecture/) (verify URL)
- [Azure Stream Analytics documentation](https://learn.microsoft.com/en-us/azure/stream-analytics/)
- [Azure Event Hubs for Apache Kafka](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-for-kafka-ecosystem-overview)
- [See: kafka-fundamentals.md](./kafka-fundamentals.md)
- [See: idempotent-data-pipeline.md](./idempotent-data-pipeline.md)
