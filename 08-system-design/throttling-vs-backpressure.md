# Throttling vs Backpressure

**Category:** System Design / Rate Limiting
**Difficulty:** 🔴 Senior
**Tags:** `throttling`, `backpressure`, `reactive-streams`, `Channel<T>`, `TCP-congestion`, `flow-control`, `System.Threading.Channels`

## Question

> What is the difference between throttling and backpressure? How does backpressure propagate in a system, and how do you implement it in .NET with `System.Threading.Channels`?

## Short Answer

**Throttling** is a **server-side** enforcement mechanism: the server rejects or delays requests that exceed a limit, protecting itself from overload. **Backpressure** is a **cooperative flow control** mechanism: a slow consumer signals upstream producers to slow their emission rate, rather than dropping work. Throttling discards excess; backpressure buffers or slows the producer. TCP's congestion control window is the canonical backpressure example. In .NET, `System.Threading.Channels` with a `BoundedChannel` naturally propagates backpressure: `WriteAsync` blocks (or returns false) when the channel is full, pausing the producer until the consumer drains.

## Detailed Explanation

### Throttling

Throttling is a **defensive mechanism** applied at the service boundary:

```
Client sends 1000 req/s
Service limit: 100 req/s
Throttle: reject 900 req/s with HTTP 429
```

The server protects itself; the client bears the cost (rejected requests). The client must retry with back-off.

**Characteristics**:
- Works across process boundaries (HTTP, broker).
- Discards or delays excess work.
- Client unaware of server capacity until rejection.
- Appropriate when: unknown clients, API monetisation, DDoS protection.

### Backpressure

Backpressure is a **cooperative mechanism** between a known producer and consumer:

```
Producer generates 1000 events/s
Consumer can only process 100/s

With backpressure: Producer automatically slows to 100/s
Without backpressure: Buffer fills → OOM or messages dropped
```

The key insight: **blocking the producer** is preferable to dropping messages or exhausting memory.

**Characteristics**:
- Requires a shared channel or in-process queue.
- Producer is aware of consumer capacity.
- Works between async stages in a pipeline (not across network boundaries).
- Appropriate when: internal pipelines, stream processing, producer/consumer patterns.

### TCP Congestion Control: The Canonical Example

TCP implements backpressure via:
1. **Receive window**: receiver advertises how much buffer space it has.
2. **Congestion window**: sender limits in-flight bytes based on observed ACK timing.

If ACKs are slow (receiver overwhelmed), the congestion window shrinks → sender slows down. This is exactly backpressure: receiver controls producer rate.

### Reactive Streams and IAsyncEnumerable

In .NET, `IAsyncEnumerable<T>` propagates backpressure naturally: the producer only generates the next item when the consumer calls `MoveNextAsync()`. If the consumer is slow, the producer pauses.

```csharp
// Producer yields only when consumer is ready
await foreach (var item in ProduceSlowAsync(cancellationToken))
{
    await ProcessAsync(item);  // if this is slow, producer pauses automatically
}
```

This is in contrast to `IObservable<T>` (Rx), where the producer pushes regardless of consumer speed — requiring explicit backpressure operators (`Buffer`, `Sample`, `OnBackpressureDrop`).

### System.Threading.Channels

`Channel<T>` provides a thread-safe producer/consumer queue with optional bounded capacity:

| Channel type | Behaviour when full | Use when |
|-------------|---------------------|---------|
| `Unbounded` | Never full; grows indefinitely | Producer bursts are OK; OOM risk |
| `Bounded + Wait` | `WriteAsync` blocks until space | Backpressure: slow consumer pauses producer |
| `Bounded + DropOldest` | Oldest item discarded | Latest data matters; losing old data is OK (telemetry) |
| `Bounded + DropNewest` | New item discarded | Existing items are more important (ordered event log) |
| `Bounded + DropWrite` | `TryWrite` returns false; caller decides | Caller controls drop logic |

`BoundedChannelFullMode.Wait` is backpressure: the producer is paused, not punished with a rejection.

### Pipeline with Multiple Stages

```
Stage 1 (Producer) → Channel<RawEvent> (capacity: 100) → Stage 2 (Parser) →
Channel<ParsedEvent> (capacity: 50) → Stage 3 (Persister)
```

If Stage 3 (DB write) is slow, its channel fills → Stage 2 blocks → its channel fills → Stage 1 blocks. Backpressure propagates all the way back to the source. The system slows end-to-end without dropping data.

## Code Example

```csharp
// .NET 8 — Backpressure with System.Threading.Channels
// Three-stage pipeline: Ingest → Parse → Persist

using System.Threading.Channels;

// ── Channel configuration ─────────────────────────────────────────────
var rawChannel    = Channel.CreateBounded<RawEvent>(new BoundedChannelOptions(capacity: 200)
{
    FullMode      = BoundedChannelFullMode.Wait,       // backpressure: block producer
    SingleWriter  = true,
    SingleReader  = false
});

var parsedChannel = Channel.CreateBounded<ParsedEvent>(new BoundedChannelOptions(capacity: 50)
{
    FullMode      = BoundedChannelFullMode.Wait,       // backpressure propagates up
    SingleWriter  = false,
    SingleReader  = false
});

using var cts = new CancellationTokenSource();

// ── Stage 1: Producer (ingest events from Kafka/HTTP/file) ────────────
var producerTask = Task.Run(async () =>
{
    try
    {
        for (int i = 0; i < 10_000; i++)
        {
            var evt = new RawEvent(i, $"payload-{i}");

            // WriteAsync blocks if rawChannel is full (100 unprocessed items)
            // This is backpressure: producer slows to consumer's pace
            await rawChannel.Writer.WriteAsync(evt, cts.Token);

            Console.WriteLine($"Produced: {i} (channel count: ~{rawChannel.Reader.Count})");
        }
    }
    finally
    {
        rawChannel.Writer.Complete();
    }
});

// ── Stage 2: Parser (N parallel workers, CPU-bound) ───────────────────
int parserWorkers = Environment.ProcessorCount;
var parserTasks   = Enumerable.Range(0, parserWorkers).Select(_ => Task.Run(async () =>
{
    await foreach (var raw in rawChannel.Reader.ReadAllAsync(cts.Token))
    {
        // Simulate CPU-bound parsing
        var parsed = new ParsedEvent(raw.Id, raw.Payload.ToUpperInvariant(), DateTime.UtcNow);

        // Will block if parsedChannel is full (consumer DB write is the bottleneck)
        await parsedChannel.Writer.WriteAsync(parsed, cts.Token);
    }
})).ToArray();

// Complete parsedChannel when all parsers finish
_ = Task.WhenAll(parserTasks).ContinueWith(_ => parsedChannel.Writer.Complete());

// ── Stage 3: Persister (IO-bound, writes to DB) ───────────────────────
var persisterTask = Task.Run(async () =>
{
    var batch = new List<ParsedEvent>(100);

    await foreach (var evt in parsedChannel.Reader.ReadAllAsync(cts.Token))
    {
        batch.Add(evt);

        if (batch.Count >= 100)
        {
            await PersistBatchAsync(batch, cts.Token);  // slow DB write
            Console.WriteLine($"Persisted batch of {batch.Count}");
            batch.Clear();
        }
    }

    // Flush remaining
    if (batch.Count > 0)
        await PersistBatchAsync(batch, cts.Token);
});

await Task.WhenAll(producerTask, persisterTask);
Console.WriteLine("Pipeline complete");

// ── Simulate DB write ─────────────────────────────────────────────────
async Task PersistBatchAsync(IEnumerable<ParsedEvent> events, CancellationToken ct)
{
    await Task.Delay(50, ct);   // simulate 50ms DB round-trip per batch
}

// ── Throttling example: reject when at capacity (no backpressure) ─────
var throttledChannel = Channel.CreateBounded<RawEvent>(new BoundedChannelOptions(100)
{
    FullMode = BoundedChannelFullMode.DropWrite  // ← reject, not block
});

bool accepted = throttledChannel.Writer.TryWrite(new RawEvent(99, "payload"));
if (!accepted)
    Console.WriteLine("Throttled: channel full, request dropped");

// ── Records ───────────────────────────────────────────────────────────
record RawEvent(int Id, string Payload);
record ParsedEvent(int Id, string Data, DateTime Timestamp);
```

## Common Follow-up Questions

- How does `System.Threading.Channels` compare to `BlockingCollection<T>` for producer/consumer scenarios?
- What are the trade-offs between `BoundedChannelFullMode.Wait` (backpressure) vs `DropOldest` (lossy) for telemetry pipelines?
- How does Rx.NET (IObservable) handle backpressure compared to `IAsyncEnumerable`?
- How would you implement backpressure across a network boundary (e.g., gRPC client streaming)?
- What happens to a `Channel<T>` backpressure pipeline when the consumer has an exception — does the producer block forever?
- How does ASP.NET Core's Kestrel use backpressure internally for HTTP request reading?

## Common Mistakes / Pitfalls

- **Using `Unbounded` channels for long-running ingestion**: an `UnboundedChannel` will consume all available heap memory if the producer is faster than the consumer. Always use `BoundedChannel` with an explicit capacity for sustained pipelines.
- **Blocking the thread pool with `Write` instead of `WriteAsync`**: `channel.Writer.Write()` (synchronous) blocks a thread while waiting for capacity. Use `WriteAsync` with `await` to release the thread to the pool while waiting.
- **Not completing the channel**: if the producer never calls `writer.Complete()`, consumers waiting in `ReadAllAsync` block forever even after all items have been processed. Always complete the writer in a `finally` block.
- **Single-reader/single-writer misconconfig**: declaring `SingleWriter = false` on a channel with multiple writers enables more efficient internal implementation. Setting `SingleWriter = true` with multiple concurrent writers causes data races. Match the flag to actual usage.
- **Confusing throttling with backpressure for network services**: backpressure requires a cooperative, in-process (or at least same-network) relationship. You cannot backpressure an external HTTP client — you can only throttle it (reject with 429). Use the correct tool for each context.
- **Ignoring `CancellationToken` propagation in pipeline stages**: if `cts.Cancel()` is called, stages reading from channels need the token to exit their `await foreach` loop. Without the token, they block indefinitely on `ReadAllAsync` even after cancellation.

## References

- [System.Threading.Channels — Microsoft Learn](https://learn.microsoft.com/dotnet/core/extensions/channels)
- [An Introduction to System.Threading.Channels — Stephen Toub](https://devblogs.microsoft.com/dotnet/an-introduction-to-system-threading-channels/)
- [Reactive Extensions (Rx.NET) — GitHub](https://github.com/dotnet/reactive)
- [IAsyncEnumerable and async streams — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/generate-consume-asynchronous-stream)
- [See: rate-limiting-concepts.md](./rate-limiting-concepts.md) — throttling fundamentals
