# Ordering in Distributed Systems

**Category:** System Design / Messaging
**Difficulty:** Senior
**Tags:** `ordering`, `lamport-clocks`, `vector-clocks`, `kafka-partitions`, `sequence-numbers`, `causal-consistency`

## Question

> How do you guarantee message ordering in a distributed system? What is the difference between total ordering and causal ordering? How do Lamport clocks and vector clocks work? What does Kafka provide and what are the limits?

- Why is global ordering across partitions expensive and usually not worth it?
- How do you implement per-entity ordering without a global sequence?

## Short Answer

Total ordering (every message has a globally agreed position) requires a single serialisation point — a bottleneck that limits throughput. In practice, systems implement **causal ordering** (if A caused B, A is always seen before B) or **per-partition ordering** (Kafka: ordered within a partition, unordered across partitions). Lamport timestamps assign a logical clock value that increases on each event and message receive; vector clocks extend this to track causality across N processes. For .NET services, per-entity ordering (all events for a given order ID go to the same Kafka partition or Service Bus session) is the pragmatic approach that provides ordering guarantees where needed without a global bottleneck.

## Detailed Explanation

### Why Ordering Is Hard

In a distributed system, messages travel through multiple network hops, queues, and services. Two messages sent "at the same time" by different producers may arrive in any order at any consumer:

```
Producer A: sends msg1 at t=100ms
Producer B: sends msg2 at t=101ms (1ms later)

Consumer sees: msg2, msg1  (out of order due to network jitter)
```

Physical clock synchronisation (NTP) is accurate to ±10–100ms — insufficient for determining true "happened before" in a distributed system.

### Lamport Timestamps

Lamport's algorithm assigns a logical timestamp that respects the "happened before" (→) relationship:

**Rules:**
1. Each process maintains a counter `L`, starting at 0.
2. On every internal event: `L = L + 1`.
3. On send: increment `L`, attach `L` to the message.
4. On receive: `L = max(L, message.L) + 1`.

```csharp
public sealed class LamportClock
{
    private long _time;

    public long Tick()               => Interlocked.Increment(ref _time);
    public long Send()               => Interlocked.Increment(ref _time);  // same as Tick
    public long Receive(long msgTime) =>
        Interlocked.Exchange(ref _time, Math.Max(_time, msgTime) + 1);
    public long Time                 => Interlocked.Read(ref _time);
}
```

**Limitation**: Lamport timestamps provide a total order, but two events with the same timestamp may have no causal relationship (concurrent events). `L(A) < L(B)` does NOT mean A caused B — only that A did not happen *after* B.

### Vector Clocks

Vector clocks track causality precisely: `VC[i]` is the number of events process `i` has seen:

```csharp
public sealed class VectorClock
{
    private readonly int[] _clock;
    private readonly int   _myIndex;

    public VectorClock(int processCount, int myIndex)
    {
        _clock   = new int[processCount];
        _myIndex = myIndex;
    }

    public int[] Tick()
    {
        _clock[_myIndex]++;
        return (int[])_clock.Clone();
    }

    public int[] Receive(int[] received)
    {
        for (int i = 0; i < _clock.Length; i++)
            _clock[i] = Math.Max(_clock[i], received[i]);
        _clock[_myIndex]++;
        return (int[])_clock.Clone();
    }

    // A causally precedes B if all A[i] <= B[i] and at least one A[i] < B[i]
    public static bool HappenedBefore(int[] a, int[] b) =>
        a.Zip(b, (ai, bi) => ai <= bi).All(x => x) &&
        a.Zip(b, (ai, bi) => ai < bi).Any(x => x);

    // Concurrent: neither happened before the other
    public static bool Concurrent(int[] a, int[] b) =>
        !HappenedBefore(a, b) && !HappenedBefore(b, a);
}
```

Vector clocks are used in DynamoDB, Riak, and CRDTs for conflict detection and resolution.

**Cost**: each message carries a vector of size N (number of processes). At 100 services, that's 400 bytes per message — expensive at high throughput.

### Kafka Partition Ordering

Kafka provides ordered delivery within a partition. The standard pattern: map business entities to partitions via a consistent key:

```
Key: orderId
Kafka partition: hash(orderId) % numPartitions

All events for order X → same partition → consumed in order

OrderCreated(orderId=X)   offset 5
PaymentReceived(orderId=X) offset 12
OrderShipped(orderId=X)   offset 19
OrderDelivered(orderId=X) offset 28
```

**Cross-partition ordering is not guaranteed**:
```
Partition 0: OrderCreated(X), PaymentReceived(X), OrderShipped(X)
Partition 1: OrderCreated(Y), PaymentReceived(Y)

Consumer sees: might receive PaymentReceived(Y) before OrderCreated(X) — different partitions
```

If you need causal ordering across entities (e.g., a customer discount applied to all their orders must arrive before any order processing), you must either:
1. Use a single partition for all events that must be causally ordered — limits throughput.
2. Include a "parent event ID" in each message and have consumers wait for the parent before processing.
3. Use a sequence number per entity stored in the DB and reject/requeue out-of-order messages.

### Per-Entity Sequence Numbers

The most practical approach for business systems: each entity (order, customer, account) has a monotonically increasing version number:

```csharp
// Every event carries the entity's version at the time it was generated
public record OrderEvent(Guid OrderId, int Version, string EventType, ...);

// Consumer: process only if version is expected; buffer or reject otherwise
public sealed class OrderEventConsumer(IOrderRepository orders)
{
    private readonly ConcurrentDictionary<Guid, int> _expectedVersions = new();

    public async Task HandleAsync(OrderEvent evt, CancellationToken ct)
    {
        var expectedVersion = _expectedVersions.GetOrAdd(evt.OrderId,
            _ => await orders.GetCurrentVersionAsync(evt.OrderId, ct));

        if (evt.Version < expectedVersion)
        {
            // Duplicate or already processed — skip
            return;
        }

        if (evt.Version > expectedVersion)
        {
            // Out of order — buffer and wait (or dead-letter if gap is too large)
            await _buffer.BufferAsync(evt, ct);
            return;
        }

        // In-order event — process
        await ProcessEventAsync(evt, ct);
        _expectedVersions[evt.OrderId] = expectedVersion + 1;
    }
}
```

### Azure Service Bus Sessions for Ordering

Service Bus sessions provide ordered, FIFO delivery per session key — no Lamport clocks needed:

```csharp
// All messages for the same orderId arrive in FIFO order via session
var message = new ServiceBusMessage(body) { SessionId = orderId.ToString() };

// Consumer accepts a session — processes exactly one session at a time, in order
var session = await client.AcceptNextSessionAsync("orders-queue", ct);
await foreach (var msg in session.ReceiveMessagesAsync(ct))
{
    await ProcessInOrderAsync(msg, ct);  // guaranteed FIFO within this session
    await session.CompleteMessageAsync(msg, ct);
}
```

See [azure-service-bus-patterns.md](./azure-service-bus-patterns.md) for full session details.

### Why Global Ordering Is Expensive

Global total ordering requires a single sequencer — one process that assigns monotonically increasing sequence numbers to all messages:

```
All producers → [Global Sequencer] → [All consumers in order]
```

The sequencer is:
- A **single point of failure** — if it crashes, the system stops.
- A **throughput bottleneck** — all writes serialised through one node.
- A **latency source** — every message must touch the sequencer.

Google Spanner achieves external consistency with TrueTime (GPS+atomic clocks) but is expensive and complex. For most systems, per-entity ordering is sufficient and far more practical.

> **Warning:** Be precise about your ordering requirement. "Messages must arrive in order" usually means "messages for the same entity must arrive in order" — not global order across all entities. Clarifying this requirement almost always leads to a much simpler per-partition or per-session solution.

## Code Example

```csharp
// Practical: Kafka consumer that detects out-of-order events per entity
// and requeues them with a delay
public sealed class OrderedEventConsumer : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var consumer = BuildConsumer();
        consumer.Subscribe("orders.events");

        while (!ct.IsCancellationRequested)
        {
            var result = consumer.Consume(ct);
            var evt    = result.Message.Value;

            var currentVersion = await _db.GetVersionAsync(evt.OrderId, ct);

            if (evt.Version == currentVersion + 1)
            {
                // In order — process immediately
                await ProcessAsync(evt, ct);
                consumer.Commit(result);
            }
            else if (evt.Version <= currentVersion)
            {
                // Already processed or duplicate
                consumer.Commit(result);
                _logger.LogDebug("Skipping duplicate event v{V} for order {OrderId}",
                    evt.Version, evt.OrderId);
            }
            else
            {
                // Out of order — re-queue to retry topic with delay
                _logger.LogWarning("Out-of-order event v{V} (expected v{Expected}) for {OrderId}",
                    evt.Version, currentVersion + 1, evt.OrderId);
                await _retryProducer.ProduceAsync("orders.events.retry", result.Message, ct);
                consumer.Commit(result);
            }
        }
    }
}
```

## Common Follow-up Questions

- How does Google Spanner achieve external consistency without a global lock?
- What is a CRDT and how does it allow concurrent updates without coordination?
- How do you handle the "gap" problem — message 5 arrives but messages 3 and 4 are missing?
- How does Kafka's exactly-once semantics (`enable.idempotence`) relate to message ordering?
- What is the difference between FIFO ordering and causal ordering?

## Common Mistakes / Pitfalls

- **Assuming wall-clock timestamps provide ordering**: NTP synchronisation is only accurate to ±10–100ms; two events 5ms apart can have reversed timestamps across servers.
- **Using a single Kafka partition for all messages**: this limits throughput to the throughput of one consumer and one partition — avoid for high-volume topics.
- **Not handling gaps in sequence numbers**: an out-of-order consumer that buffers indefinitely waiting for a gap-filling message will grow unboundedly if the gap-filler was lost; add a timeout and dead-letter.
- **Conflating "delivered in order" with "processed in order"**: Kafka delivers a partition in order, but if your consumer processes messages in parallel (`MaxConcurrentCalls > 1`), processing may still be out of order.
- **Ignoring duplicate detection**: guaranteed ordering + at-least-once delivery means you may see the same message twice; always combine ordering with idempotency.

## References

- [Lamport timestamps — Leslie Lamport, 1978](https://lamport.azurewebsites.net/pubs/time-clocks.pdf)
- [Kafka ordering guarantees — Confluent](https://www.confluent.io/blog/kafka-exactly-once-semantics/)
- [Azure Service Bus message sessions](https://learn.microsoft.com/en-us/azure/service-bus-messaging/message-sessions)
- [Designing Data-Intensive Applications — Martin Kleppmann (Chapter 9)](https://dataintensive.net/)
- [See: kafka-fundamentals.md](./kafka-fundamentals.md)
- [See: eventual-consistency.md](./eventual-consistency.md)
