# Producer-Consumer with `Channel<T>`

**Category:** C# / Threading / Concurrency
**Difficulty:** Senior
**Tags:** `Channel<T>`, `producer-consumer`, `bounded`, `unbounded`, `backpressure`, `pipeline`

## Question
> How do you build a producer-consumer pipeline with `System.Threading.Channels.Channel<T>`, and when should you choose bounded or unbounded channels?

Also asked as:
- "Why are channels a good fit for async producer-consumer workloads in .NET?"
- "What do `SingleReader`, `SingleWriter`, and bounded capacity options actually change?"

## Short Answer
`Channel<T>` is an async-friendly producer-consumer primitive with separate writer and reader sides, built-in completion, and optional bounded capacity for back-pressure. Use a bounded channel when producers can outrun consumers and you need to control memory and throughput; use an unbounded channel only when the item volume is naturally limited or buffering growth is acceptable. `SingleReader` and `SingleWriter` are optimization hints that let the implementation use cheaper paths when you know only one reader or writer exists.

## Detailed Explanation

### Why `Channel<T>` exists
Producer-consumer pipelines are everywhere: ingesting messages, background work queues, ETL stages, file processing, API fan-in/fan-out, and hosted services. Traditional choices such as `Queue<T>` plus `lock` or `BlockingCollection<T>` either require manual coordination or block threads. `Channel<T>` was designed for modern async code, so waiting to read or write can suspend without tying up a worker thread.

It gives you:

- a `ChannelWriter<T>` for producers
- a `ChannelReader<T>` for consumers
- async APIs such as `WriteAsync` and `ReadAsync`
- completion semantics via `Complete`
- configuration for bounded capacity and performance hints

### Bounded vs unbounded channels
This is the key design decision.

| Option | Behavior | Strength | Risk |
|---|---|---|---|
| Unbounded | Writers keep enqueueing | Simpler, no producer stalls | Memory can grow without limit |
| Bounded | Capacity limit enforced | Back-pressure, predictable memory | Producers may wait or drop depending on mode |

A bounded channel protects the system when producers are faster than consumers. Instead of buffering forever, the writer eventually waits for space or follows a configured full mode such as drop oldest or drop newest.

In real services, bounded channels are often the safer default because they make overload visible instead of silently turning it into unbounded memory growth.

> **Warning:** an unbounded channel is not "free scalability." It is often just delayed failure through memory pressure.

### `SingleReader` and `SingleWriter`
These options do not change correctness. They are performance hints. If you know there will be exactly one reader or one writer, the channel implementation can avoid some coordination overhead.

Set them only when the guarantee is truly valid. They are promises to the implementation, not aspirations.

### Pipeline pattern
Channels compose nicely into multi-stage pipelines:

1. producer stage reads input and writes work items
2. worker stage reads, transforms, and writes results to another channel
3. sink stage reads final results and persists or publishes them

Each stage can run at its own pace. Bounded channels between stages create natural back-pressure instead of unlimited buffering.

### Completion and shutdown
A producer calls `writer.Complete()` when no more items will arrive. Consumers using `ReadAllAsync` will then finish once the buffer is drained. If completion includes an exception, that failure propagates to readers.

This explicit completion model is one of the biggest advantages over ad-hoc queue designs.

### When channels are a better choice
Use `Channel<T>` when you need:

- async-friendly producer-consumer coordination
- one or many producers and consumers
- bounded buffering and back-pressure
- a background queue inside ASP.NET Core or worker services
- a pipeline that should not block worker threads while waiting

Use [async-streams-vs-channels.md](./async-streams-vs-channels.md) as the companion topic: async streams are pull-based, while channels are better when producers push independently.

### Full modes and overload strategy
For bounded channels, `BoundedChannelFullMode` expresses policy, not just mechanics. `Wait` applies back-pressure by making producers slow down. `DropWrite`, `DropNewest`, or `DropOldest` are appropriate only when the domain can tolerate loss, such as telemetry sampling or best-effort notifications.

That policy decision is important architecture, not a minor implementation detail. A work queue for financial operations should probably wait or reject upstream requests explicitly. A metrics pipeline may reasonably drop some data under pressure.

### Channels in hosted services and pipelines
Channels are especially common in ASP.NET Core background services because they let request-handling code enqueue work quickly while a separate worker drains it asynchronously. The same pattern scales to multi-stage pipelines: one channel between ingestion and parsing, another between parsing and persistence, each with its own capacity. That makes bottlenecks visible and local instead of turning the whole process into one giant unbounded buffer.

### Cancellation and completion together
Cancellation and completion solve different problems. Cancellation says "stop waiting or stop producing now." Completion says "no more items will arrive, but finish draining what is already buffered." Good channel-based designs usually use both deliberately: cancellation for shutdown or timeout, completion for graceful end-of-stream.

### Fairness and work distribution
Channels do not promise business-level fairness between all producers or consumers; they provide a coordination mechanism. If one stage is much slower, it naturally becomes the bottleneck, and bounded capacity forces that bottleneck to show up sooner. That is usually good because it keeps the system honest. You can then scale the consumer stage, increase capacity deliberately, or change the overload policy based on data instead of guesswork.

> **Tip:** if your pipeline has no natural bound, add one anyway and decide explicitly how overload should be handled.

## Code Example
```csharp
using System;
using System.Linq;
using System.Threading.Channels;
using System.Threading.Tasks;

var input = Channel.CreateBounded<int>(new BoundedChannelOptions(capacity: 5)
{
    SingleWriter = true,
    SingleReader = false,
    FullMode = BoundedChannelFullMode.Wait // Back-pressure: producers wait when full.
});

var results = Channel.CreateBounded<string>(new BoundedChannelOptions(capacity: 5)
{
    SingleWriter = false,
    SingleReader = true,
    FullMode = BoundedChannelFullMode.Wait
});

// Producer stage.
Task producer = Task.Run(async () =>
{
    for (int i = 1; i <= 12; i++)
    {
        await input.Writer.WriteAsync(i);
        Console.WriteLine($"Enqueued {i}");
    }

    input.Writer.Complete(); // Signal no more items.
});

// Two worker consumers reading from the same input channel.
Task[] workers = Enumerable.Range(1, 2).Select(workerId => Task.Run(async () =>
{
    await foreach (int item in input.Reader.ReadAllAsync())
    {
        await Task.Delay(100); // Simulate async I/O or processing.
        string transformed = $"worker-{workerId} processed {item * item}";
        await results.Writer.WriteAsync(transformed);
    }
})).ToArray();

// Complete the results channel after all workers finish.
Task closer = Task.Run(async () =>
{
    await Task.WhenAll(workers);
    results.Writer.Complete();
});

// Sink stage.
Task sink = Task.Run(async () =>
{
    await foreach (string line in results.Reader.ReadAllAsync())
    {
        Console.WriteLine(line);
    }
});

await Task.WhenAll(producer, closer, sink);
```

## Common Follow-up Questions
- How does `Channel<T>` differ from `BlockingCollection<T>` in async code?
- When should you choose `BoundedChannelFullMode.DropOldest` or `DropWrite` instead of waiting?
- How do you propagate cancellation through a channel pipeline cleanly?
- When is a channel more appropriate than [async-streams-vs-channels.md](./async-streams-vs-channels.md)?
- What do `SingleReader` and `SingleWriter` change internally?
- How would you implement a background task queue in ASP.NET Core with channels?

## Common Mistakes / Pitfalls
- Using an unbounded channel for a workload where producers can outrun consumers indefinitely.
- Forgetting to call `Complete`, which leaves consumers waiting forever.
- Setting `SingleReader` or `SingleWriter` to true when the code does not actually guarantee it.
- Treating channels as a substitute for full application-level retry, cancellation, or failure policy.
- Holding expensive synchronous work in consumers without considering throughput and capacity limits.

## References
- [System.Threading.Channels — Microsoft Learn](https://learn.microsoft.com/dotnet/core/extensions/channels)
- [Channel<T> overview — Microsoft Learn](https://learn.microsoft.com/dotnet/core/extensions/channels)
- [An Introduction to System.Threading.Channels — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/dotnet/an-introduction-to-system-threading-channels/)
- [See: async-streams-vs-channels.md](./async-streams-vs-channels.md)
- [See: concurrent-collections.md](./concurrent-collections.md)
- [See: cancellation-tokens.md](./cancellation-tokens.md)
