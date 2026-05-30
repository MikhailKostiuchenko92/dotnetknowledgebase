# Distributed Transactions

**Category:** System Design / Fundamentals
**Difficulty:** 🔴 Senior
**Tags:** `distributed-transactions`, `2PC`, `saga`, `choreography`, `orchestration`, `outbox`, `eventual-consistency`

## Question

> How do distributed transactions work? Compare Two-Phase Commit (2PC), the Saga pattern (choreography vs orchestration), and the Outbox pattern. When would you use each, and what are the failure modes?

## Short Answer

Distributed transactions coordinate writes across multiple services or databases. Two-Phase Commit (2PC) provides ACID guarantees but creates a blocking protocol prone to coordinator failures, making it unsuitable for microservices. The Saga pattern decomposes a distributed operation into a sequence of local transactions with compensating actions on failure — choreography uses events while orchestration uses a central coordinator. The Outbox pattern provides reliable at-least-once delivery of events as part of a local database transaction, ensuring the database write and the event publish are atomic.

## Detailed Explanation

### Why Distributed Transactions Are Hard

In a microservices system, a business operation (e.g., "place an order") may require:

1. Deducting inventory from the Inventory service DB
2. Creating an order in the Order service DB
3. Charging the customer in the Payment service DB

Each step is a separate transaction in a separate database. There is no global transaction manager that can atomically commit or roll back across all three. If step 2 succeeds but step 3 fails, the system is in an inconsistent state.

### Two-Phase Commit (2PC)

2PC uses a **coordinator** to coordinate a commit across multiple **participants**:

**Phase 1 — Prepare:**
- Coordinator sends `PREPARE` to all participants.
- Each participant writes to a write-ahead log and votes `YES` (I can commit) or `NO`.

**Phase 2 — Commit or Abort:**
- If all vote YES: coordinator sends `COMMIT`. Participants apply changes.
- If any vote NO: coordinator sends `ABORT`. Participants roll back.

**Failure modes:**

| Scenario | Problem |
|----------|---------|
| Coordinator crashes after PREPARE, before COMMIT | Participants are **blocked** — they've locked resources and can't proceed |
| Participant crashes after voting YES | On recovery, participant must ask coordinator for outcome (potentially unavailable) |
| Network partition during Phase 2 | Some participants commit, others abort — **inconsistency** |

2PC is **blocking**: if the coordinator fails in the window between phases, participants hold locks indefinitely.

> **Warning:** 2PC is rarely used in modern distributed systems. It appears in XA transactions (Java EE, MSDTC), but is largely considered an anti-pattern for internet-scale microservices due to availability impact.

**Use 2PC when:** You control both sides of a transaction, both are on the same network, and the cost of blocking/locking is acceptable (e.g., same datacenter, small batches, database-to-queue coordination via MSDTC).

### Saga Pattern

A Saga decomposes a distributed transaction into a sequence of **local transactions**, each published as an event or command. On failure, **compensating transactions** are executed to undo completed steps.

Sagas trade **isolation** for **availability**: intermediate states are visible to other processes (T1 committed, T2 not yet), but the system never blocks.

#### Choreography-Based Saga

Each service listens for events and publishes new events. No central coordinator.

```
OrderService         InventoryService      PaymentService
──────────           ────────────          ───────────────
OrderPlaced ──────→  Reserve Stock
                     StockReserved ──────→ Charge Customer
                                           PaymentSucceeded ──→ (done)

On failure:
                     StockReserveFailed ─→ OrderService cancels order
                     PaymentFailed ──────→ InventoryService releases stock
```

**Pros:** Loose coupling, no single coordinator SPOF.
**Cons:** Hard to follow the business flow; compensations are implicit; debugging requires distributed tracing.

#### Orchestration-Based Saga

A central **Saga Orchestrator** (e.g., MassTransit StateMachine, Durable Functions) commands each step and handles failures explicitly.

```
SagaOrchestrator ──→ ReserveStock (command)
                 ←── StockReserved (event)
                 ──→ ChargeCustomer (command)
                 ←── PaymentFailed (event)
                 ──→ ReleaseStock (compensating command)
                 ──→ CancelOrder (compensating command)
```

**Pros:** Business flow is in one place; easier to monitor; explicit compensation logic.
**Cons:** Orchestrator is a coordination bottleneck; requires durable state storage.

**In .NET:** MassTransit Sagas + Entity Framework for state persistence; Azure Durable Functions for orchestration.

### Outbox Pattern

The **hardest problem** in event-driven systems: ensuring that a database write and an event publish are **atomic**. Without the outbox:

1. Write to DB ✅ → crash → publish event ❌ → event lost, data inconsistent.
2. Publish event ✅ → crash → write to DB ❌ → event published but DB not updated.

The Outbox pattern solves this by writing the event **to the same database as the domain data** in the same local transaction. A separate process (poller or CDC) reads the outbox and publishes events.

```
Local Transaction:
  INSERT INTO Orders (...)          -- domain write
  INSERT INTO Outbox (event, ...)   -- same transaction

Outbox Relay (separate process):
  SELECT * FROM Outbox WHERE Published = false
  Publish to message broker
  UPDATE Outbox SET Published = true
```

**Guarantees**: At-least-once delivery (the relay may publish the same event twice if it crashes after publish but before updating the outbox). Consumers must be idempotent.

**In .NET with EF Core:** NServiceBus, MassTransit Transactional Outbox, or a custom `SaveChangesInterceptor` that writes to an outbox table.

[See: outbox-pattern.md](./outbox-pattern.md) for full implementation.

### Comparison

| | 2PC | Saga (Choreography) | Saga (Orchestration) | Outbox |
|--|-----|---------------------|---------------------|--------|
| **Consistency** | ACID (strong) | Eventual | Eventual | Local ACID + at-least-once |
| **Availability** | Low (blocking) | High | High | High |
| **Complexity** | Low logic, high infra | Medium | Medium-high | Medium |
| **Compensations** | Automatic (rollback) | Manual events | Explicit in orchestrator | N/A |
| **Failure isolation** | Poor (blocking) | Good | Good | N/A (local only) |
| **Use for** | Same-datacenter, same DB vendor | Loosely coupled microservices | Complex multi-step workflows | Reliable event publishing |

## Code Example

```csharp
// Outbox pattern with EF Core — writing domain + outbox in one transaction
// .NET 8, Microsoft.EntityFrameworkCore

using Microsoft.EntityFrameworkCore;
using System.Text.Json;

// ── Domain ────────────────────────────────────────────────────────────
record Order(Guid Id, string CustomerId, decimal Total, string Status);

record OutboxMessage(Guid Id, string EventType, string Payload, bool Published, DateTime CreatedAt);

class OrderDbContext(DbContextOptions<OrderDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OutboxMessage> Outbox => Set<OutboxMessage>();
}

// ── Application service ───────────────────────────────────────────────
class OrderService(OrderDbContext db)
{
    public async Task<Guid> PlaceOrderAsync(string customerId, decimal total)
    {
        var orderId = Guid.NewGuid();
        var order = new Order(orderId, customerId, total, "Pending");

        var outboxEvent = new OutboxMessage(
            Id: Guid.NewGuid(),
            EventType: "OrderPlaced",
            Payload: JsonSerializer.Serialize(new { OrderId = orderId, CustomerId = customerId, Total = total }),
            Published: false,
            CreatedAt: DateTime.UtcNow);

        db.Orders.Add(order);
        db.Outbox.Add(outboxEvent);

        // Single local transaction: both writes succeed or both fail
        // No risk of event published without order saved, or vice versa
        await db.SaveChangesAsync();

        return orderId;
    }
}

// ── Outbox relay (background service) ────────────────────────────────
class OutboxRelayService(OrderDbContext db, IMessageBus bus) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var pending = await db.Outbox
                .Where(m => !m.Published)
                .OrderBy(m => m.CreatedAt)
                .Take(100)
                .ToListAsync(ct);

            foreach (var msg in pending)
            {
                await bus.PublishAsync(msg.EventType, msg.Payload, ct);  // idempotent consumer assumed
                msg = msg with { Published = true };
                db.Outbox.Update(msg);
            }

            if (pending.Count > 0)
                await db.SaveChangesAsync(ct);

            await Task.Delay(TimeSpan.FromSeconds(1), ct);
        }
    }
}

interface IMessageBus
{
    Task PublishAsync(string eventType, string payload, CancellationToken ct);
}
```

## Common Follow-up Questions

- How do you ensure idempotency on the consumer side of an outbox-published event?
- What is Change Data Capture (CDC), and how does it improve on polling-based outbox relay?
- How does MassTransit implement the Saga state machine in .NET?
- What is the "dual-write problem," and how does the outbox pattern solve it?
- How do you handle a compensating transaction that itself fails?
- What is "saga isolation anomaly," and how do you mitigate it without adding blocking?

## Common Mistakes / Pitfalls

- **Using HTTP for saga steps without a message broker**: if the orchestrator calls service B via HTTP and the call times out, the orchestrator doesn't know if B committed or not — use durable messaging.
- **Not making saga consumers idempotent**: the outbox guarantees at-least-once delivery; if the consumer isn't idempotent, duplicate event processing causes double-charges, double-inserts, etc.
- **Forgetting compensation transactions for all steps**: sagas require a compensating action for *every* committed step in the forward path. Partial compensation leaves data inconsistent.
- **Using 2PC across microservices**: 2PC requires a shared transaction coordinator (MSDTC/XA) — this creates coupling and is rarely supported across heterogeneous services/databases.
- **Polling outbox on the hot path**: the outbox relay should run as a background process, not inline with the web request. Polling adds latency to the message relay but should not block the API response.
- **Treating saga orchestrator as an application server**: the orchestrator state must be persisted durably (database, Durable Functions storage). An in-memory saga that crashes mid-flight leaves orphaned state.

## References

- [Microservices Patterns — Chris Richardson (Saga chapter)](https://microservices.io/patterns/data/saga.html)
- [The Outbox Pattern — Kamil Grzybek](https://www.kamilgrzybek.com/design/the-outbox-pattern/)
- [MassTransit Saga State Machine](https://masstransit.io/documentation/patterns/saga/state-machine)
- [Azure Durable Functions — Orchestration patterns](https://learn.microsoft.com/azure/azure-functions/durable/durable-functions-orchestrations)
- [Designing Data-Intensive Applications — Chapter 9: Consistency and Consensus](https://dataintensive.net/)
