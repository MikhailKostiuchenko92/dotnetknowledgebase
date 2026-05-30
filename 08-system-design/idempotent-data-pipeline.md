# Idempotent Data Pipeline

**Category:** System Design / Data Pipelines
**Difficulty:** Middle
**Tags:** `idempotency`, `exactly-once`, `checkpointing`, `watermarks`, `replayability`, `at-least-once`

## Question

> What does "exactly-once processing" mean in a data pipeline and why is it an illusion without careful design? How do you make a pipeline idempotent so it can be safely re-run? What are checkpoints and watermarks?

- What is the difference between at-least-once and exactly-once delivery?
- How do you safely replay a failed batch job without double-processing?

## Short Answer

True exactly-once processing requires all components — message broker, compute, and sink — to participate in a transaction simultaneously, which is rarely achievable end-to-end. In practice, pipelines are built for **at-least-once delivery with idempotent sinks**: the pipeline may deliver a message more than once, but the output is the same as if it were delivered exactly once. Idempotency is achieved by using upserts (INSERT … ON CONFLICT UPDATE) or deduplication keys at the sink, checkpoints to record processed position, and watermarks to handle late-arriving data without reprocessing.

## Detailed Explanation

### Why Exactly-Once Is an Illusion

A pipeline step:
1. Read message from Kafka.
2. Transform data.
3. Write to database.
4. Commit Kafka offset.

Failure between steps 3 and 4:
- Database write succeeded.
- Offset not committed.
- On restart: message re-read and processed again.
- Database write happens twice.

To prevent the duplicate: make step 3 idempotent (INSERT … ON CONFLICT DO NOTHING with a deduplication key).

Kafka transactions (`enable.idempotence=true`, `transactional.id`) provide exactly-once within Kafka (read from topic A → write to topic B atomically). But the database write is outside Kafka's transaction scope — you still need an idempotent sink.

**The real goal**: at-least-once delivery + idempotent operations = exactly-once *effect*.

### Idempotent Sinks

**UPSERT (INSERT … ON CONFLICT):**

```sql
-- Idempotent upsert: safe to run multiple times with same event_id
INSERT INTO order_projections (order_id, status, total_cents, updated_at)
VALUES (@OrderId, @Status, @TotalCents, @UpdatedAt)
ON CONFLICT (order_id)
DO UPDATE SET
    status      = EXCLUDED.status,
    total_cents = EXCLUDED.total_cents,
    updated_at  = EXCLUDED.updated_at
WHERE EXCLUDED.updated_at > order_projections.updated_at;  -- only update if newer
```

```csharp
// EF Core idempotent write
await context.OrderProjections
    .Upsert(new OrderProjection { OrderId = evt.OrderId, Status = evt.Status, ... })
    .On(p => p.OrderId)
    .WhenMatched((existing, incoming) => new OrderProjection
    {
        Status    = incoming.Status,
        UpdatedAt = incoming.UpdatedAt,
    })
    .RunAsync(ct);
```

**Deduplication table:**

```sql
-- Track processed message IDs; skip if already seen
CREATE TABLE processed_messages (
    message_id TEXT PRIMARY KEY,
    processed_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX ON processed_messages (processed_at);  -- for cleanup

-- Before processing:
INSERT INTO processed_messages (message_id) VALUES (@MessageId)
ON CONFLICT DO NOTHING;  -- returns 0 rows if duplicate → skip processing
```

### Checkpointing

A checkpoint records the pipeline's last successfully processed position so it can resume from there after a failure:

```csharp
// Checkpoint: save last processed Kafka offset to durable store
public sealed class CheckpointedKafkaConsumer(ICheckpointStore checkpoints)
{
    public async Task RunAsync(CancellationToken ct)
    {
        // Restore last checkpoint (or start from beginning)
        var lastCheckpoint = await checkpoints.LoadAsync("orders-pipeline", ct);
        var startOffset = lastCheckpoint?.Offset ?? 0;

        var consumer = BuildConsumer(startOffset);

        long processedCount = 0;
        await foreach (var message in consumer.ConsumeAsync(ct))
        {
            await ProcessAsync(message, ct);
            processedCount++;

            // Checkpoint every 1000 messages (balance between frequency and overhead)
            if (processedCount % 1000 == 0)
                await checkpoints.SaveAsync("orders-pipeline", message.Offset, ct);
        }
    }
}

// Simple checkpoint using Redis
public sealed class RedisCheckpointStore(IDistributedCache cache) : ICheckpointStore
{
    public async Task SaveAsync(string pipelineId, long offset, CancellationToken ct) =>
        await cache.SetStringAsync($"checkpoint:{pipelineId}", offset.ToString(),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = null }, ct);

    public async Task<Checkpoint?> LoadAsync(string pipelineId, CancellationToken ct)
    {
        var value = await cache.GetStringAsync($"checkpoint:{pipelineId}", ct);
        return value is null ? null : new Checkpoint(long.Parse(value));
    }
}
```

### Batch Job Idempotency

For nightly batch jobs, idempotency means the job can be re-run for the same date without producing duplicate results:

```csharp
// Idempotent batch: DELETE + INSERT for the target date window
public async Task RunDailyAggregationAsync(DateOnly date, CancellationToken ct)
{
    await using var tx = await _db.Database.BeginTransactionAsync(ct);

    // Delete existing results for this date (safe to re-run)
    await _db.DailySalesAggregates
        .Where(a => a.Date == date)
        .ExecuteDeleteAsync(ct);

    // Re-compute and insert
    var aggregates = await _db.Sales
        .Where(s => DateOnly.FromDateTime(s.CreatedAt) == date)
        .GroupBy(s => new { s.ProductId, s.RegionId })
        .Select(g => new DailySalesAggregate
        {
            Date      = date,
            ProductId = g.Key.ProductId,
            RegionId  = g.Key.RegionId,
            Revenue   = g.Sum(s => s.TotalAmount),
            OrderCount = g.Count(),
        })
        .ToListAsync(ct);

    _db.DailySalesAggregates.AddRange(aggregates);
    await _db.SaveChangesAsync(ct);
    await tx.CommitAsync(ct);
}
```

Alternative: use **idempotency keys** and a `processed_batches` table:

```sql
CREATE TABLE processed_batches (
    batch_id    TEXT PRIMARY KEY,           -- e.g., "daily-sales-2024-01-15"
    started_at  TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    row_count   INT
);

-- Before running: check if already completed
SELECT completed_at FROM processed_batches WHERE batch_id = @BatchId;
-- If completed_at IS NOT NULL → skip (already processed)
-- If completed_at IS NULL → was started but crashed → re-run (idempotent)
```

### Watermarks in Streaming Pipelines

A watermark declares "all events with timestamp < T have arrived" — the system can safely close windows and compute final results for that time period:

```
Event stream (out of order):
  t=100: order-A
  t=102: order-B
  t=98:  order-C  ← late (timestamp 98, arrived after t=102)
  t=105: order-D

Watermark: t_max - 5 seconds (allow 5-second late arrivals)
  When latest event is t=102 → watermark = 97 → window [90,100) still open
  When latest event is t=105 → watermark = 100 → window [90,100) can close
```

```csharp
// Azure Stream Analytics: watermark via late arrival tolerance
// In ASA, configure "out of order tolerance" in job settings
// Or with custom delay using TIMESTAMP BY + WITH (EVENTHUBPARTITIONID)

// In Spark Structured Streaming:
var streamWithWatermark = spark
    .ReadStream()
    .Format("kafka")
    .Load()
    .WithWatermark("eventTime", "5 minutes")  // allow 5-minute late arrivals
    .GroupBy(
        Functions.Window(Functions.Col("eventTime"), "1 hour"),
        Functions.Col("customerId"))
    .Agg(Functions.Sum("totalAmount").As("revenue"));
```

### Replayability: Design for Replay

A replayable pipeline can reproduce any past output by re-running from raw inputs. Requirements:

1. **Immutable raw data**: never modify or delete source events (use append-only log — Kafka with long retention, or ADLS Gen2 Bronze layer).
2. **Deterministic transformations**: given the same inputs, produce the same outputs (avoid `DateTime.Now` in transforms — use event timestamps).
3. **Idempotent sinks**: re-running produces same result as first run.
4. **Versioned logic**: store the transformation code version alongside the output.

```csharp
// ❌ Non-replayable: uses current time — re-run produces different output
public DailySummary Process(IEnumerable<Order> orders) =>
    new DailySummary { ProcessedAt = DateTime.UtcNow, ... };  // ← non-deterministic

// ✅ Replayable: uses event time — re-run produces identical output
public DailySummary Process(IEnumerable<Order> orders, DateOnly forDate) =>
    new DailySummary { ForDate = forDate, ... };  // ← deterministic
```

> **Warning:** Replayability requires that all external API calls in your pipeline are either idempotent or cached. A pipeline step that calls a non-idempotent external API (e.g., sends an email, charges a card) must be separated from the replayable transformation step and guarded with a deduplication check.

## Code Example

```csharp
// Full idempotent pipeline step with checkpoint and deduplication
public sealed class OrderProjectionPipeline(
    IKafkaConsumer<string> consumer,
    AppDbContext db,
    ICheckpointStore checkpoints,
    ILogger<OrderProjectionPipeline> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var checkpoint = await checkpoints.LoadAsync("order-projection", ct);
        consumer.SeekTo(checkpoint?.Offset ?? Offset.Beginning);

        while (!ct.IsCancellationRequested)
        {
            var message = consumer.Consume(TimeSpan.FromSeconds(5), ct);
            if (message is null) continue;

            var evt = JsonSerializer.Deserialize<OrderEvent>(message.Value)!;

            // Idempotent: ON CONFLICT UPDATE handles re-delivery
            await db.Database.ExecuteSqlRawAsync("""
                INSERT INTO order_projections
                    (order_id, status, total_cents, version, updated_at)
                VALUES
                    ({0}, {1}, {2}, {3}, {4})
                ON CONFLICT (order_id)
                DO UPDATE SET
                    status     = EXCLUDED.status,
                    total_cents = EXCLUDED.total_cents,
                    updated_at = EXCLUDED.updated_at
                WHERE EXCLUDED.version > order_projections.version
                """,
                evt.OrderId, evt.Status, evt.TotalCents, evt.Version, evt.OccurredAt);

            // Checkpoint every 500 events
            if (message.Offset % 500 == 0)
                await checkpoints.SaveAsync("order-projection", message.Offset, ct);
        }
    }
}
```

## Common Follow-up Questions

- What is the difference between a checkpoint and a savepoint in Apache Flink?
- How does Kafka's transactional API enable exactly-once within Kafka topic-to-topic processing?
- How do you handle watermarks when events can arrive days late (e.g., mobile app offline for 48 hours)?
- What is the two-generals problem and why does it apply to distributed commit protocols?
- How do you test a data pipeline for idempotency — what does a good test look like?

## Common Mistakes / Pitfalls

- **Assuming at-most-once delivery from a durable queue**: all durable message brokers (Kafka, Service Bus) provide at-least-once; design sinks to be idempotent, not to rely on exactly-once delivery.
- **Checkpointing too frequently**: checkpointing after every message adds I/O overhead; checkpoint every N messages or every T seconds.
- **Checkpointing too infrequently**: a crash between checkpoints means reprocessing N messages; idempotent sinks make this safe, but N should be bounded.
- **Non-deterministic transforms**: using `DateTime.UtcNow`, random IDs, or external API state inside a transform makes the pipeline non-replayable.
- **No retention on raw data**: deleting raw event data means you can never replay from scratch; retain raw data for at least the maximum recovery window (weeks to years for compliance).

## References

- [Exactly-once semantics in Kafka — Confluent](https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/)
- [Apache Flink checkpointing](https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/fault-tolerance/checkpointing/)
- [Azure Stream Analytics — out of order handling](https://learn.microsoft.com/en-us/azure/stream-analytics/stream-analytics-out-of-order-and-late-events)
- [See: batch-vs-stream-processing.md](./batch-vs-stream-processing.md)
- [See: outbox-pattern.md](./outbox-pattern.md)
- [See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md)
