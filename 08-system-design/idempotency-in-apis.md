# Idempotency in APIs

**Category:** System Design / APIs
**Difficulty:** 🔴 Senior
**Tags:** `idempotency`, `idempotency-key`, `at-least-once`, `deduplication`, `distributed-systems`, `payments`

## Question

> What is idempotency in the context of APIs? How do idempotency keys work? How do you implement deduplication for at-least-once delivery in a distributed system?

## Short Answer

An operation is idempotent if executing it multiple times produces the same result as executing it once. In APIs, idempotency keys allow clients to safely retry requests without duplicating side effects — the server stores the result of the first execution keyed by the client-provided UUID, and returns the same result on retries without re-executing. This is essential for payment processing, order creation, and any `POST` operation in an at-least-once delivery system.

## Detailed Explanation

### The Problem: Retry-Induced Duplication

In distributed systems, any request may fail for network reasons — the client can't tell whether the server received and processed the request or not. The safe response is to retry. But retrying a non-idempotent operation (e.g., "charge $100") causes duplicates:

```
Client → POST /payments { amount: 100 }
Network error (client never gets response)
Client → POST /payments { amount: 100 }  ← retry
Server charges $100 twice ← BUG
```

### HTTP Verb Idempotency Review

| Verb | Inherently idempotent? | Reason |
|------|----------------------|--------|
| `GET` | ✅ | Read-only, no side effects |
| `DELETE` | ✅ | Deleting an already-deleted resource → same end state |
| `PUT` | ✅ | Replaces the whole resource with the same value → same result |
| `POST` | ❌ | Creates new resources; each call is a new operation |
| `PATCH` | ❌ (usually) | Depends on semantics; "increment by 1" is not idempotent |

### Idempotency Keys

The standard pattern (used by Stripe, Braintree, Adyen):

1. **Client generates a UUID** before the first attempt: `Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000`
2. **Client includes the header** with every attempt (including retries).
3. **Server stores** the request key + response in a durable store (DB/Redis) on first execution.
4. **Server checks** on every subsequent call: if key exists, return stored response without re-executing.

```
First call:
  Client → POST /payments { Idempotency-Key: "key-abc", amount: 100 }
  Server → (key-abc not seen) → charge $100 → store (key-abc → 201 { payment_id: "pay_1" }) → return 201

Retry:
  Client → POST /payments { Idempotency-Key: "key-abc", amount: 100 }
  Server → (key-abc exists) → return stored 201 { payment_id: "pay_1" } ← no charge
```

### Key Design Decisions

#### Key Scope and TTL
- Keys should expire after a reasonable window (e.g., 24h for payments, 7 days for order creation).
- Expired keys are not found → treated as new requests.
- Key scope: per user + operation, or global. Per-user prevents one user's key from colliding with another's.

#### Response Storage
- Store the full HTTP status + response body keyed by idempotency key.
- On conflict (same key, different request body): return `422 Unprocessable Entity` — the key is being reused with different parameters, which is a client bug.

#### Concurrent Duplicate Requests
- Two requests with the same key can arrive simultaneously (double-click).
- Use a database unique constraint or Redis `SET NX` (set-if-not-exists) to handle the race:
  - First writer wins; second gets the stored result.
  - Intermediate state: second caller may need to poll/wait until first completes.

#### Exactly-Once vs At-Least-Once
Idempotency keys achieve **effectively-once** semantics (at-least-once delivery + idempotent consumer = no observable duplicates). True exactly-once is theoretically impossible in distributed systems without a single coordination point.

### Deduplication at the Consumer Layer

For message queues (Service Bus, Kafka, RabbitMQ), the approach mirrors API idempotency:

1. Producer includes a `MessageId` / `CorrelationId` on every message.
2. Consumer stores processed `MessageId`s in a deduplication store (DB, Redis).
3. Before processing: check if `MessageId` already processed → skip if yes.
4. After processing: mark `MessageId` as processed.

> **Warning:** Steps 3–4 must be atomic with the business operation or use the Outbox pattern. If the check and the processing are not in the same transaction, a crash between them causes either a duplicate or a missed message.

[See: outbox-pattern.md](./outbox-pattern.md)

### Natural vs Key-Based Idempotency

Sometimes you can use natural keys instead of client-supplied UUIDs:
- Order number: `INSERT INTO Orders (order_number, ...) ON CONFLICT (order_number) DO NOTHING`
- User registration: `INSERT INTO Users (email, ...) ON CONFLICT (email) DO NOTHING RETURNING id`

Natural key idempotency is simpler when a unique business identifier exists. Idempotency keys are needed when no natural identifier exists before the operation (e.g., payment with no pre-existing ID).

## Code Example

```csharp
// Idempotency key middleware for ASP.NET Core 8
// Stores first response in Redis; returns cached response on retries

using Microsoft.AspNetCore.Http.Extensions;
using StackExchange.Redis;
using System.Text;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<IConnectionMultiplexer>(
    ConnectionMultiplexer.Connect("localhost:6379"));

var app = builder.Build();

// ── Idempotency middleware ─────────────────────────────────────────────
app.Use(async (ctx, next) =>
{
    // Only apply to state-changing methods
    if (ctx.Request.Method is not ("POST" or "PATCH"))
    {
        await next(ctx);
        return;
    }

    if (!ctx.Request.Headers.TryGetValue("Idempotency-Key", out var keyValues))
    {
        await next(ctx);
        return;
    }

    var idempotencyKey = keyValues.ToString();
    if (idempotencyKey.Length > 128)
    {
        ctx.Response.StatusCode = 400;
        await ctx.Response.WriteAsync("Idempotency-Key too long");
        return;
    }

    var redis = ctx.RequestServices.GetRequiredService<IConnectionMultiplexer>().GetDatabase();
    var cacheKey = $"idem:{ctx.Request.Path}:{idempotencyKey}";

    // Check for existing result
    var cached = await redis.StringGetAsync(cacheKey);
    if (cached.HasValue)
    {
        var stored = JsonSerializer.Deserialize<StoredResponse>(cached!);
        ctx.Response.StatusCode = stored!.StatusCode;
        ctx.Response.ContentType = "application/json";
        await ctx.Response.WriteAsync(stored.Body);
        return;   // return cached response — no business logic executed
    }

    // Intercept the response to capture it
    var originalBody = ctx.Response.Body;
    using var buffer = new MemoryStream();
    ctx.Response.Body = buffer;

    await next(ctx);   // execute the actual handler

    // Capture and store the response
    buffer.Seek(0, SeekOrigin.Begin);
    var responseBody = await new StreamReader(buffer).ReadToEndAsync();

    var toStore = new StoredResponse(ctx.Response.StatusCode, responseBody);
    await redis.StringSetAsync(
        cacheKey,
        JsonSerializer.Serialize(toStore),
        expiry: TimeSpan.FromHours(24));   // TTL: keys expire after 24h

    // Write response to original stream
    buffer.Seek(0, SeekOrigin.Begin);
    await buffer.CopyToAsync(originalBody);
    ctx.Response.Body = originalBody;
});

// ── Payment endpoint ──────────────────────────────────────────────────
app.MapPost("/payments", async (PaymentRequest req) =>
{
    // This runs only ONCE per idempotency key — never twice
    var paymentId = Guid.NewGuid().ToString();
    // ... charge the card via payment gateway ...
    return Results.Created($"/payments/{paymentId}", new { PaymentId = paymentId, req.Amount });
});

app.Run();

record PaymentRequest(string CustomerId, decimal Amount, string Currency);
record StoredResponse(int StatusCode, string Body);
```

## Common Follow-up Questions

- How do you handle the case where two concurrent requests arrive with the same idempotency key and the first is still being processed?
- What happens when the idempotency key TTL expires but the client retries beyond that window?
- How do you implement idempotency in an event-driven system using a message queue?
- What is the difference between idempotency and at-most-once semantics?
- How would Stripe's API return a different error if you reuse an idempotency key with a different request body?
- How does the Outbox pattern relate to idempotency at the database level?

## Common Mistakes / Pitfalls

- **Storing idempotency results only in memory**: a server restart clears the cache, allowing retries to re-execute. Use Redis or a database with a TTL.
- **Not covering the response in the idempotency check**: returning a fresh `payment_id` on each call (even from cache logic) rather than the stored original response means the client sees a different ID on retry, breaking client-side reconciliation.
- **Key collision between users**: if idempotency keys are scoped globally (not per user), one user's key could collide with another's, returning the wrong response. Always scope keys by user/client ID.
- **Treating idempotency as exactly-once**: at-least-once + idempotent consumer = *effectively* once, not mathematically exactly-once. Edge cases (concurrent duplicate delivery before the first is stored) can still cause double-processing without additional locking.
- **Long-running operations returning 202 Accepted**: if the handler is async and returns `202` before completing, the idempotency store captures `202` — retries get `202` even after the operation eventually completes. Use polling or webhooks to communicate final status.
- **Not validating the key is UUID-shaped**: clients may accidentally send the same non-unique key (e.g., `"retry"`) across different operations. Validate key format and scope it to the user.

## References

- [Stripe — Idempotent requests](https://stripe.com/docs/api/idempotent_requests)
- [Idempotency patterns — Microsoft Azure Architecture Center](https://learn.microsoft.com/azure/architecture/patterns/idempotency-token) (verify URL)
- [Redis SET NX — atomic set-if-not-exists](https://redis.io/docs/latest/commands/set/)
- [See: outbox-pattern.md](./outbox-pattern.md) — atomic event publishing tied to idempotent processing
- [See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md) — delivery guarantees in message queues
