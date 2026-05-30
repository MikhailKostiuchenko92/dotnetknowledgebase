# Design: Notification System

**Category:** System Design / Classic Design Problems
**Difficulty:** 🟡 Middle
**Tags:** `system-design`, `notifications`, `push`, `email`, `SMS`, `fan-out`, `priority-queue`, `templates`, `delivery-tracking`

## Question

> Design a notification system that supports push notifications (mobile/web), email, and SMS. Handle 10M notifications/day, personalised templates, delivery tracking, user preferences, and retry on failure.

## Short Answer

A notification system decouples **notification creation** from **delivery** via a message queue. An orchestrator service reads notification requests, applies templates and user preferences, and fans out to channel-specific workers (email, SMS, push). Each worker calls the appropriate provider (SendGrid, Twilio, FCM/APNs) and records delivery status. Key design challenges: handling high fan-out for broadcast messages (10M users × 1 provider call each), user opt-out preferences, provider rate limits and failures, and template personalisation at scale.

## Detailed Explanation

### System Components

| Component | Responsibility |
|-----------|---------------|
| **Notification API** | Accepts notification requests; validates; enqueues |
| **Orchestrator** | Dequeues, resolves template, checks preferences, fans out per channel |
| **Channel Workers** | Email worker, Push worker, SMS worker — call external providers |
| **Template Service** | Stores/renders Handlebars/Liquid templates with user data |
| **Preference Store** | User opt-ins/opt-outs per channel and notification type |
| **Delivery Tracker** | Stores send/delivered/failed/opened status per notification |
| **Dead-Letter Handler** | Retries failed deliveries; escalates after N attempts |

### Message Flow

```
Caller → POST /notifications → [Validation] → [Notification Queue]
                                                       │
                                            [Orchestrator Workers]
                                            ├─ Check user preferences
                                            ├─ Render template
                                            └─ Fan out to channel queues
                                                   │        │       │
                                             [Email Q] [Push Q] [SMS Q]
                                                   │        │       │
                                              SendGrid    FCM    Twilio
                                                   │        │       │
                                              [Delivery Tracker DB]
```

### Fan-Out at Scale

For a broadcast notification to 10M users:
- **Write-time fan-out**: create 10M individual queue messages at send time. Pros: simple workers. Cons: 10M writes per broadcast.
- **Read-time fan-out**: store one notification + recipient list; workers pull and expand. Pros: storage efficient. Cons: workers must maintain pagination state.

**Hybrid approach**: for small audiences (< 10K), write-time fan-out. For large broadcasts, read-time fan-out with worker-side pagination. This is the approach used by Facebook, Twitter for notifications.

### Priority Queues

Different notification types have different urgency:
- **Critical**: OTP/2FA, account security alerts → P0 queue, no batching.
- **Transactional**: order confirmation, password reset → P1 queue, single delivery.
- **Marketing**: newsletter, promotional → P2 queue, batched, respect send-time optimisation.

Use separate queues per priority. P2 is processed during off-peak hours or with rate limiting.

### User Preferences

Store per-user, per-channel, per-type opt-in state:

```sql
CREATE TABLE notification_preferences (
    user_id   BIGINT,
    channel   VARCHAR(20),   -- 'email', 'push', 'sms'
    type      VARCHAR(50),   -- 'marketing', 'security', 'order_update'
    enabled   BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (user_id, channel, type)
);
```

Check preferences in the orchestrator before creating channel-specific messages. Respect unsubscribe requests immediately (update preference + process bounces from providers).

### Delivery Tracking

Record each delivery attempt:

```sql
CREATE TABLE delivery_log (
    id           UUID PRIMARY KEY,
    notification_id UUID,
    user_id      BIGINT,
    channel      VARCHAR(20),
    status       VARCHAR(20),   -- queued|sent|delivered|failed|bounced|opened
    provider_id  VARCHAR(100),  -- external message ID (SendGrid/Twilio ID)
    attempted_at TIMESTAMP,
    updated_at   TIMESTAMP
);
```

Providers send webhook callbacks on delivery/open/bounce events — update `delivery_log` accordingly.

### Template Rendering

Store templates in DB with versioning:

```
Subject: "Your {{orderType}} order #{{orderId}} has shipped"
Body: "Hi {{firstName}}, your {{item_count}} items will arrive by {{eta}}."
```

Use a library like `Scriban` or `Fluid` for Liquid templates in .NET.

Cache rendered templates (same template + same data should not be re-rendered for every user). For bulk sends with the same template, render once and personalise only the dynamic fields.

## Code Example

```csharp
// ASP.NET Core 8 — Notification system core components

using MassTransit;
using System.Text.Json;

// ── Request contract ──────────────────────────────────────────────────
public record SendNotificationRequest(
    Guid   CorrelationId,
    long[] RecipientUserIds,
    string TemplateId,
    Dictionary<string, string> TemplateData,
    string[] Channels,          // ["email", "push", "sms"]
    string Priority = "normal"  // "critical" | "normal" | "marketing"
);

// ── Orchestrator consumer ─────────────────────────────────────────────
public sealed class NotificationOrchestratorConsumer(
    IPreferenceStore preferences,
    ITemplateService templates,
    IPublishEndpoint bus,
    ILogger<NotificationOrchestratorConsumer> log)
    : IConsumer<SendNotificationRequest>
{
    public async Task Consume(ConsumeContext<SendNotificationRequest> ctx)
    {
        var req = ctx.Message;

        // Fan out per recipient × channel
        foreach (var userId in req.RecipientUserIds)
        {
            foreach (var channel in req.Channels)
            {
                // Check user preference
                if (!await preferences.IsEnabledAsync(userId, channel, req.TemplateId))
                {
                    log.LogDebug("User {UserId} opted out of {Channel}", userId, channel);
                    continue;
                }

                // Render template for this user
                var userData     = await GetUserDataAsync(userId);
                var mergedData   = new Dictionary<string, string>(req.TemplateData);
                mergedData["firstName"] = userData.FirstName;
                mergedData["email"]     = userData.Email;

                var rendered = await templates.RenderAsync(req.TemplateId, mergedData, channel);

                // Route to the appropriate channel queue
                var channelMsg = channel switch
                {
                    "email" => (object)new SendEmail(userId, userData.Email, rendered.Subject, rendered.Body),
                    "push"  => new SendPush(userId, rendered.Subject, rendered.Body),
                    "sms"   => new SendSms(userId, userData.PhoneNumber, rendered.Body),
                    _       => null
                };

                if (channelMsg is not null)
                    await bus.Publish(channelMsg, ctx.CancellationToken);
            }
        }
    }

    private static Task<UserData> GetUserDataAsync(long userId) =>
        Task.FromResult(new UserData($"User{userId}", $"user{userId}@example.com", "+15551234567"));
}

// ── Email channel worker ──────────────────────────────────────────────
public sealed class EmailWorker(
    IEmailProvider provider,
    IDeliveryTracker tracker,
    ILogger<EmailWorker> log) : IConsumer<SendEmail>
{
    public async Task Consume(ConsumeContext<SendEmail> ctx)
    {
        var msg = ctx.Message;
        try
        {
            var providerId = await provider.SendAsync(msg.ToEmail, msg.Subject, msg.Body);
            await tracker.RecordAsync(new DeliveryRecord(
                ctx.MessageId.ToString()!, msg.UserId, "email", "sent", providerId));
        }
        catch (ProviderRateLimitException ex)
        {
            // Re-throw so MassTransit retries after back-off
            log.LogWarning("SendGrid rate limit hit; will retry. {Msg}", ex.Message);
            throw;
        }
        catch (PermanentDeliveryException ex)
        {
            // Bad address etc — record as failed, don't retry
            log.LogError("Permanent delivery failure for {UserId}: {Msg}", msg.UserId, ex.Message);
            await tracker.RecordAsync(new DeliveryRecord(
                ctx.MessageId.ToString()!, msg.UserId, "email", "failed", null));
        }
    }
}

// ── Delivery webhook endpoint (SendGrid, Twilio callbacks) ────────────
var app = WebApplication.Create(args);

app.MapPost("/webhooks/sendgrid", async (
    SendGridWebhookPayload[] events,
    IDeliveryTracker tracker,
    CancellationToken ct) =>
{
    foreach (var evt in events)
    {
        await tracker.UpdateAsync(evt.MessageId, evt.Event switch
        {
            "delivered" => "delivered",
            "bounce"    => "bounced",
            "open"      => "opened",
            _           => "sent"
        }, ct);
    }
    return Results.Ok();
});

app.Run();

// ── Contracts ─────────────────────────────────────────────────────────
record SendEmail(long UserId, string ToEmail, string Subject, string Body);
record SendPush(long UserId, string Title, string Body);
record SendSms(long UserId, string PhoneNumber, string Body);
record DeliveryRecord(string MessageId, long UserId, string Channel, string Status, string? ProviderId);
record UserData(string FirstName, string Email, string PhoneNumber);
record RenderedTemplate(string Subject, string Body);
record SendGridWebhookPayload(string MessageId, string Event);

interface IPreferenceStore
{
    Task<bool> IsEnabledAsync(long userId, string channel, string templateId);
}
interface ITemplateService
{
    Task<RenderedTemplate> RenderAsync(string templateId, Dictionary<string, string> data, string channel);
}
interface IEmailProvider
{
    Task<string> SendAsync(string to, string subject, string body);
}
interface IDeliveryTracker
{
    Task RecordAsync(DeliveryRecord record);
    Task UpdateAsync(string messageId, string status, CancellationToken ct = default);
}
class ProviderRateLimitException(string msg) : Exception(msg);
class PermanentDeliveryException(string msg) : Exception(msg);
```

## Common Follow-up Questions

- How do you handle unsubscribe links in emails that must work even after the user account is deleted?
- How do you implement send-time optimisation — delivering marketing emails at the time each user is most likely to open them?
- What does "at-least-once delivery" mean for notifications, and how do you prevent duplicate delivery (user receives 2 order confirmations)?
- How do you handle provider outages — e.g., SendGrid is down for 30 minutes?
- How do you implement notification batching — combining multiple events into a digest rather than sending one email per event?
- How would you add real-time in-app notifications (browser notifications without push) to this system?

## Common Mistakes / Pitfalls

- **Synchronous fan-out in the request handler**: writing 10M queue messages synchronously while the caller waits will time out. Enqueue one "broadcast notification" message; let the orchestrator fan out asynchronously.
- **Not checking user preferences before delivery**: sending marketing emails to users who unsubscribed violates GDPR/CAN-SPAM and leads to provider blacklisting. Always check preferences in the orchestrator.
- **Retrying permanent failures (bounced email addresses)**: retrying a hard-bounced address causes provider blacklisting. Distinguish transient (connection error) from permanent (bad address) failures and dead-letter permanent ones without retry.
- **Storing full rendered email bodies in the delivery log**: for 10M notifications/day, storing 50 KB of HTML per message = 500 GB/day. Store only metadata (template ID, delivery status) in the delivery log; store rendered bodies in blob storage if at all.
- **No idempotency on the delivery endpoint**: if the orchestrator crashes after publishing to the email queue but before ACKing the original message, it will republish and the user receives two emails. Make the channel worker idempotent (check `MessageId` in delivery log before sending).
- **Single queue for all notification types**: marketing bulk sends (10M messages) starve critical security alerts if they share a queue. Use priority queues or separate queues per notification type.

## References

- [Firebase Cloud Messaging (FCM) — Google](https://firebase.google.com/docs/cloud-messaging)
- [SendGrid API — Twilio](https://docs.sendgrid.com/api-reference/)
- [MassTransit — consumers and retry](https://masstransit.io/documentation/concepts/consumers)
- [See: pub-sub-vs-message-queue.md](./pub-sub-vs-message-queue.md) — fan-out patterns
- [See: dead-letter-queues.md](./dead-letter-queues.md) — handling permanent failures
