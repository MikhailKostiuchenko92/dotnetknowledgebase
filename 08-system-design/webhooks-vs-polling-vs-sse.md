# Webhooks vs Polling vs Server-Sent Events

**Category:** System Design / APIs
**Difficulty:** 🟡 Middle
**Tags:** `webhooks`, `polling`, `SSE`, `server-sent-events`, `push`, `pull`, `real-time`, `event-delivery`

## Question

> Compare webhooks, polling, and Server-Sent Events (SSE) for delivering real-time updates. What are the reliability guarantees, failure modes, and when would you choose each?

## Short Answer

Polling (client repeatedly asks "any updates?") is simple but wastes bandwidth and adds latency. Webhooks (server pushes to a client URL when something happens) are efficient but require the client to be reachable and handle retries. Server-Sent Events (SSE) give the server a persistent channel to stream events to the browser over HTTP, without WebSocket complexity. Choose webhooks for server-to-server notifications; SSE for browser real-time feeds; polling when simplicity matters more than efficiency.

## Detailed Explanation

### Short Polling

Client sends an HTTP request on a fixed interval, regardless of whether new data exists.

```
Client → GET /events?since=last_id  (every 5 seconds)
Server → 200 [] or 200 [event1, event2]
```

**Pros**: Simplest implementation, works everywhere, stateless server.
**Cons**: Wastes bandwidth (empty responses), minimum latency = poll interval, scales poorly under many clients.

**Use when**: Data freshness within 10–60 seconds is acceptable; client count is small; server can't push.

### Long Polling

Client sends a request; server holds it open until an event arrives or a timeout occurs.

```
Client → GET /events/wait (holds connection)
Server → (waits for event or 30s timeout)
Server → 200 [event1]  (as soon as event arrives)
Client → immediately opens new request
```

**Pros**: Near-real-time; no persistent connection; works through proxies.
**Cons**: Server holds open connections (memory + thread cost if not async); reconnect overhead; ordering/deduplication complex.

**Use when**: SSE/WebSocket not available; moderate client count; latency < 5s needed.

### Webhooks

Server makes an outbound HTTP POST to a client-supplied URL when an event occurs.

```
Event occurs → Server POST /your-endpoint {"event":"order.created",...}
Your server  → 200 OK (or 2xx)  ← must respond within timeout (e.g., 10s)
```

**Reliability challenges**:
- Client endpoint down → delivery fails. Require retry with exponential backoff (typically 3–10 attempts over hours/days).
- Client slow → server times out, retries → duplicate delivery. Client must be **idempotent** (check `event_id`).
- No ordering guarantee on retries.

**Security considerations**:
- Include a **signature** (`X-Signature: sha256=<hmac>`) so the client can verify the payload came from you.
- Clients must validate the signature before processing.

**Pros**: Efficient (push only on change); decoupled; standard HTTP.
**Cons**: Requires client to expose a public HTTPS endpoint; retry/deduplication complexity; hard to test locally without ngrok/tunnels.

**Use when**: server-to-server integrations (GitHub webhooks, Stripe, payment confirmations).

### Server-Sent Events (SSE)

Browser opens a single HTTP GET connection; server streams `text/event-stream` formatted events over it. Built into browsers via `EventSource`.

```
Client → GET /api/events  (Accept: text/event-stream)
Server → 200 Content-Type: text/event-stream
         data: {"type":"order.created","id":"42"}\n\n
         data: {"type":"stock.updated"}\n\n
         (connection stays open)
```

**Browser behaviour**:
- `EventSource` auto-reconnects on disconnect (sends `Last-Event-ID` header).
- SSE is **one-way** (server → client only).
- Limited to 6 simultaneous connections per origin in HTTP/1.1 (removed in HTTP/2 multiplexing).

**Pros**: Native browser support, auto-reconnect, standard protocol, simple server implementation.
**Cons**: Unidirectional; HTTP/1.1 connection limit; not suitable for bidirectional communication (use WebSocket for that).

**Use when**: browser dashboard with live updates (stock ticker, order status, notifications feed).

### Comparison

| | Short Polling | Long Polling | Webhooks | SSE |
|--|---|---|---|---|
| **Direction** | Pull | Pull | Push (server→server) | Push (server→browser) |
| **Latency** | = poll interval | Near real-time | Near real-time | Near real-time |
| **Connections** | Many short | Fewer, held open | Server initiates | One persistent per client |
| **Browser support** | ✅ | ✅ | ❌ (needs server) | ✅ Native `EventSource` |
| **Reconnect** | Client controls | Client controls | Server retries | Auto |
| **Ordering** | By timestamp | By timestamp | Not guaranteed | In-order |
| **Reliability** | At-most-once | At-most-once | At-least-once (with retries) | At-most-once |

### ASP.NET Core SSE Implementation

ASP.NET Core supports SSE natively through `IAsyncEnumerable` + `text/event-stream` response, or via minimal API with `PushStreamContent`.

## Code Example

```csharp
// ── Webhooks: secure outbound delivery ───────────────────────────────
// .NET 8 — sending a signed webhook, handling retries with Polly

using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Http.Resilience;
using Polly;

builder.Services.AddHttpClient("WebhookSender")
    .AddResilienceHandler("webhook-retry", pipeline =>
    {
        pipeline.AddRetry(new HttpRetryStrategyOptions
        {
            MaxRetryAttempts = 5,
            BackoffType = DelayBackoffType.Exponential,
            Delay = TimeSpan.FromSeconds(2),
            ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
                .Handle<HttpRequestException>()
                .HandleResult(r => (int)r.StatusCode >= 500)   // retry on 5xx only
        });
    });

async Task SendWebhookAsync(string targetUrl, string secret, object payload)
{
    var json      = JsonSerializer.Serialize(payload);
    var signature = ComputeHmac(json, secret);

    using var request = new HttpRequestMessage(HttpMethod.Post, targetUrl)
    {
        Content = new StringContent(json, Encoding.UTF8, "application/json")
    };
    request.Headers.Add("X-Signature-256", $"sha256={signature}");
    request.Headers.Add("X-Event-Id", Guid.NewGuid().ToString());  // idempotency key

    await httpClient.SendAsync(request);
}

static string ComputeHmac(string data, string secret)
{
    var key = Encoding.UTF8.GetBytes(secret);
    var msg = Encoding.UTF8.GetBytes(data);
    return Convert.ToHexString(HMACSHA256.HashData(key, msg)).ToLower();
}

// ── Webhook receiver: validate signature ─────────────────────────────
app.MapPost("/webhooks/stripe", async (HttpRequest req) =>
{
    var body = await new StreamReader(req.Body).ReadToEndAsync();
    var signature = req.Headers["X-Signature-256"].ToString()
        .Replace("sha256=", "");

    if (!VerifySignature(body, signature, webhookSecret))
        return Results.Unauthorized();

    var eventId = req.Headers["X-Event-Id"].ToString();
    if (await dedup.AlreadyProcessedAsync(eventId))
        return Results.Ok("duplicate — already processed");    // idempotent

    // Process event...
    return Results.Ok();
});

// ── SSE: real-time order status stream ────────────────────────────────
app.MapGet("/api/orders/{id}/stream", async (int id, CancellationToken ct) =>
{
    // Returns IAsyncEnumerable — ASP.NET Core 8 streams it as text/event-stream
    return Results.Extensions.EventStream(StreamOrderUpdates(id, ct));
});

static async IAsyncEnumerable<string> StreamOrderUpdates(
    int orderId,
    [EnumeratorCancellation] CancellationToken ct)
{
    var statuses = new[] { "Pending", "Processing", "Shipped", "Delivered" };
    foreach (var status in statuses)
    {
        ct.ThrowIfCancellationRequested();
        yield return JsonSerializer.Serialize(new { orderId, status, ts = DateTime.UtcNow });
        await Task.Delay(TimeSpan.FromSeconds(2), ct);
    }
}
```

## Common Follow-up Questions

- How do you handle webhook delivery failures and ensure at-least-once delivery without duplicates?
- How does WebSocket compare to SSE for bidirectional real-time communication?
- How would you implement a webhook delivery system that can handle 1 million events per day?
- What are the security implications of webhook signature verification, and how do you prevent replay attacks?
- How do you test webhook endpoints locally without deploying to a public URL?
- How does HTTP/2 multiplexing change the SSE connection-limit problem?

## Common Mistakes / Pitfalls

- **Synchronous webhook processing**: running business logic inside the webhook handler synchronously makes the endpoint slow → timeout → retry storm. Receive, validate signature, enqueue to a message queue, return `200` immediately.
- **No signature verification**: accepting webhooks without verifying HMAC signatures lets anyone POST fake events to your endpoint.
- **Not handling duplicate webhook deliveries**: all major webhook providers retry on non-2xx or timeout. Without idempotency checking on `event_id`, you'll process the same event multiple times.
- **SSE with HTTP/1.1 connection limits**: browsers allow only 6 connections per origin over HTTP/1.1. Opening SSE streams from multiple tabs saturates the limit. Require HTTP/2 (which multiplexes) or use a shared SharedWorker with one SSE connection.
- **Polling without exponential backoff**: a client that polls every 100ms under load contributes to the very overload that causes errors, creating a positive feedback loop. Back off on error.
- **Long polling without async server**: holding connections open with synchronous blocking threads (not async) exhausts the thread pool under moderate load. Always use `async`/`await` for long-polling endpoints.

## References

- [Server-Sent Events — MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)
- [Webhooks — Stripe guide to webhooks best practices](https://stripe.com/docs/webhooks/best-practices)
- [ASP.NET Core response streaming](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/request-response)
- [See: idempotency-in-apis.md](./idempotency-in-apis.md) — idempotency keys for webhook deduplication
- [See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md) — delivery guarantee patterns
