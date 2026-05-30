# Backpressure Patterns

**Category:** System Design / Performance
**Difficulty:** Senior
**Tags:** `backpressure`, `channel`, `queue`, `flow-control`, `reactive`, `bounded-queue`

## Question

> What is backpressure in a distributed system? Why does unbounded queuing lead to cascading failures? How do you implement backpressure in .NET using `Channel<T>`?

- What is the difference between dropping, blocking, and buffering under overload?
- How does TCP's receive buffer relate to the concept of backpressure?

## Short Answer

Backpressure is a mechanism that signals a producer to slow down when a consumer cannot keep up. Without it, a fast producer fills an unbounded queue until memory is exhausted, causing latency to grow without bound and eventually crashing the process — long after the system was already degraded. In .NET, `System.Threading.Channels.Channel<T>` with a bounded capacity is the standard backpressure primitive: the producer either blocks, receives an error, or drops items when the channel is full, giving the system a chance to shed load gracefully instead of accepting it silently until collapse.

## Detailed Explanation

### Why Unbounded Queues Fail

The "fast producer, slow consumer" problem:

```
Producer: 10,000 msgs/s
Consumer:  8,000 msgs/s
Queue:    grows at 2,000/s

After 10s:  20,000 items (50MB)
After 60s: 120,000 items (300MB)
After 5min: crash (OOM)
```

Worse: the queue depth adds latency. An item queued 120,000 deep at 8,000/s takes **15 seconds** to process. The user's "fast" enqueue has a 15-second invisible delay. By the time memory pressure kills the process, every queued item has been waiting for minutes.

### Three Responses to Overload

| Strategy | Behaviour | Use when |
|----------|-----------|---------|
| **Drop** | Discard new items when full | Non-critical, lossy-ok (metrics, analytics, logs) |
| **Block** | Producer waits until space available | Critical work that must be processed |
| **Error** | Return error to caller immediately | Request-response; caller handles retry |

### `Channel<T>` in .NET

`System.Threading.Channels` (introduced in .NET Core 2.1) is the standard, high-performance MPSC/MPMC queue with backpressure.

**Bounded channel** — enforces backpressure:

```csharp
// BoundedChannelOptions controls backpressure behaviour
var options = new BoundedChannelOptions(capacity: 1000)
{
    FullMode = BoundedChannelFullMode.Wait,          // Block: producer awaits space
    // FullMode = BoundedChannelFullMode.DropWrite,  // Drop: silently discard new items
    // FullMode = BoundedChannelFullMode.DropOldest, // Evict: discard oldest item
    SingleWriter = false,
    SingleReader = false,
};

var channel = Channel.CreateBounded<WorkItem>(options);
```

**Unbounded channel** — no backpressure (dangerous for production):

```csharp
var channel = Channel.CreateUnbounded<WorkItem>(); // Never fills; can OOM
```

### Pipeline Backpressure with Multiple Stages

```csharp
// Multi-stage pipeline: each stage has its own bounded channel
// Back-pressure propagates upstream: if Stage 3 is slow, Stage 2 blocks, then Stage 1

public sealed class ProcessingPipeline
{
    private readonly Channel<RawEvent>      _stage1 = Channel.CreateBounded<RawEvent>(500);
    private readonly Channel<ParsedEvent>   _stage2 = Channel.CreateBounded<ParsedEvent>(200);
    private readonly Channel<EnrichedEvent> _stage3 = Channel.CreateBounded<EnrichedEvent>(100);

    public async Task RunAsync(CancellationToken ct)
    {
        await Task.WhenAll(
            ProduceAsync(_stage1.Writer, ct),
            ParseAsync(_stage1.Reader, _stage2.Writer, ct),
            EnrichAsync(_stage2.Reader, _stage3.Writer, ct),
            ConsumeAsync(_stage3.Reader, ct));
    }

    private static async Task ParseAsync(
        ChannelReader<RawEvent> input,
        ChannelWriter<ParsedEvent> output,
        CancellationToken ct)
    {
        await foreach (var raw in input.ReadAllAsync(ct))
        {
            var parsed = Parse(raw);
            // This await blocks if Stage 3 channel is full — backpressure propagates up
            await output.WriteAsync(parsed, ct);
        }
        output.Complete();
    }
}
```

### TCP Backpressure Analogy

TCP's receive buffer is the original backpressure mechanism:
- Receiver advertises its **receive window** (how many bytes it can buffer).
- Sender limits its send rate to the window size.
- When the receiver's buffer fills up (slow application reading), the window shrinks to 0 → sender stops.

The same principle in a message queue: the channel capacity is the "receive window". When full, the producer stops.

### Backpressure in ASP.NET Core

Kestrel applies backpressure on the HTTP connection: if your application is slow to read the request body, Kestrel's `PipeReader` stops ACKing TCP segments, causing the sender to slow down at the OS level. You inherit this for free with `async` controllers — you just need to avoid blocking threads.

For explicit producer/consumer scenarios (background workers, Kafka consumers):

```csharp
// Kafka consumer with bounded channel backpressure
public sealed class KafkaConsumerService(IConsumer<string, string> consumer) : BackgroundService
{
    private readonly Channel<Message<string,string>> _work =
        Channel.CreateBounded<Message<string,string>>(new BoundedChannelOptions(500)
        {
            FullMode = BoundedChannelFullMode.Wait // block consumer poll if workers are full
        });

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var workerTask = Task.WhenAll(Enumerable.Range(0, 8)
            .Select(_ => WorkerLoopAsync(_work.Reader, ct)));

        while (!ct.IsCancellationRequested)
        {
            var msg = consumer.Consume(ct);
            // Blocks here if channel is full — consumer lag increases, Kafka retains msgs
            await _work.Writer.WriteAsync(msg, ct);
        }

        _work.Writer.Complete();
        await workerTask;
    }

    private static async Task WorkerLoopAsync(
        ChannelReader<Message<string,string>> reader, CancellationToken ct)
    {
        await foreach (var msg in reader.ReadAllAsync(ct))
        {
            await ProcessAsync(msg, ct);
        }
    }
}
```

### Metrics to Monitor

- **Channel occupancy** (current depth / capacity): expose as a Gauge.
- **Drop rate**: counter incremented when `FullMode = DropWrite` discards.
- **Producer wait time**: histogram of how long `WriteAsync` blocks.

> **Warning:** `BoundedChannelFullMode.Wait` backpressure propagates all the way to the HTTP request handler if you're not careful. A slow consumer → full channel → blocked producer thread → Kestrel thread pool exhausted → no new requests handled. Always measure and set realistic capacities.

## Common Follow-up Questions

- What is reactive streams and how does it standardise backpressure across languages?
- How does Kafka handle backpressure — what happens to the consumer if it can't keep up?
- How do you implement a "load shedder" that drops requests above a threshold without blocking the thread pool?
- What is the difference between bounded parallelism (`SemaphoreSlim`) and backpressure (`Channel<T>`)?
- How do you expose channel depth as a Prometheus metric for alerting?

## Common Mistakes / Pitfalls

- **Unbounded channels in production**: `Channel.CreateUnbounded<T>()` is appropriate only for tests or when you know the producer is strictly rate-limited.
- **`DropWrite` without metrics**: silently dropping items without a counter means you'll never know the system is overloaded until something downstream notices missing data.
- **Blocking the Kestrel thread pool**: if the channel Write blocks and you call it inside an HTTP controller without `async`, you waste a thread per blocked request.
- **Single-reader assumption with multiple readers**: if `SingleReader = true` but you add a second reader, you get data races; set `SingleReader = false` for MPMC.
- **No cancellation propagation**: `WriteAsync` and `ReadAllAsync` must receive the service `CancellationToken` so they stop cleanly on shutdown.

## References

- [System.Threading.Channels — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/channels)
- [An Introduction to System.Threading.Channels — Stephen Toub](https://devblogs.microsoft.com/dotnet/an-introduction-to-system-threading-channels/)
- [Reactive Streams Specification](https://www.reactive-streams.org/)
- [See: throttling-vs-backpressure.md](./throttling-vs-backpressure.md)
- [See: async-io-and-throughput.md](./async-io-and-throughput.md)
