# Design a Chat System

**Category:** System Design / Classic Problems
**Difficulty:** Senior
**Tags:** `websocket`, `real-time`, `messaging`, `presence`, `group-chat`

## Question

> Design a real-time chat system like WhatsApp or Slack. It should support 1:1 messaging, group chats (up to 1000 members), message delivery receipts, online presence, and message history. Target: 500 million users, 100 billion messages per day.

- How do you push messages to clients in real time?
- Where do you store messages, and how do you model conversations?
- How do you implement delivery and read receipts at scale?

## Short Answer

Clients maintain a persistent WebSocket connection to a stateful chat server. When User A sends a message, the chat server writes it to Cassandra (optimised for append-heavy workloads), then fans it out to recipients — directly via their WebSocket connection if on the same server, or through a Redis pub/sub broadcast if on a different server. For offline recipients, a push notification is enqueued. Delivery receipts (sent/delivered/read) are modelled as status columns updated asynchronously. Presence (online/offline) uses heartbeat TTLs in Redis.

## Detailed Explanation

### Functional Requirements

| Feature | Detail |
|---------|--------|
| 1:1 messaging | Real-time delivery, offline queue |
| Group chat | Up to 1000 members |
| Message status | Sent → Delivered → Read |
| Presence | Online / offline / last seen |
| Media | Images, files (via object storage) |
| History | Scrollback up to 1 year |

### Real-Time Transport: WebSocket vs Alternatives

| Transport | Bidirectional | Server push | Overhead | Best for |
|-----------|:---:|:---:|--------|---------|
| WebSocket | ✅ | ✅ | Low (framing only) | Chat, live updates |
| Long-polling | ✅ | ✅ | High (HTTP headers) | Legacy fallback |
| SSE | ❌ | ✅ | Low | Notifications only |
| gRPC streaming | ✅ | ✅ | Low (HTTP/2) | Internal services |

**WebSocket** is standard for chat. A single Kestrel/SignalR server can hold ~100K concurrent connections (at ~10 KB RAM per connection = 1 GB). With 500M users and 20% concurrently active → 100M connections → 1000 servers (horizontal scale).

### Connection Architecture

```
Client
 │ WebSocket (TLS)
 ▼
Load Balancer (sticky sessions by user_id hash → consistent hashing)
 ▼
Chat Server (stateful — holds connection map: user_id → WebSocket)
 ├── On message receive: write to Cassandra + fan-out
 └── On message send to user X:
      ├── User X on THIS server → send directly via WebSocket
      └── User X on OTHER server → publish to Redis pub/sub channel "user:{X}"
           → subscribed server picks up and delivers
```

### Message Storage — Cassandra

Cassandra is ideal: time-series append workload, no complex joins, horizontal partitioning, tunable consistency.

**Schema:**

```sql
-- Messages partitioned by conversation for efficient history queries
CREATE TABLE messages (
    conversation_id UUID,
    message_id      TIMEUUID,   -- encodes timestamp, enables time ordering
    sender_id       UUID,
    content         TEXT,
    media_url       TEXT,
    status          TINYINT,    -- 0=sent, 1=delivered, 2=read
    PRIMARY KEY (conversation_id, message_id)
) WITH CLUSTERING ORDER BY (message_id DESC);

-- Mailbox: maps user → unread conversations
CREATE TABLE user_mailbox (
    user_id         UUID,
    conversation_id UUID,
    last_message_id TIMEUUID,
    unread_count    INT,
    PRIMARY KEY (user_id, last_message_id)
) WITH CLUSTERING ORDER BY (last_message_id DESC);
```

TIMEUUID guarantees monotonic ordering within a partition even from multiple writers (based on time + MAC address + random).

### Delivery Receipts

1. **Sent (✓)**: server ACKs to sender after writing to Cassandra.
2. **Delivered (✓✓)**: recipient's device ACKs on WebSocket receive OR push notification delivery callback.
3. **Read (✓✓ blue)**: client sends explicit READ event when user opens conversation.

Status updates are written back to the `messages` table (`status` column) and pushed to the sender via their WebSocket connection.

> **Scale concern:** For group chats with 1000 members, "read by all" requires tracking 1000 individual read events. Store per-user receipts in a separate table keyed by `(message_id, user_id)` rather than updating the message row (avoids hotspot on a single Cassandra partition).

### Presence System

Presence uses a Redis TTL-based heartbeat:

```
Client heartbeat (every 30 s): SETEX presence:{user_id} 60 "online"
TTL expires after 60 s of silence → user appears offline
Presence query: GET presence:{user_id} → nil = offline
```

For "last seen" timestamp, write to a persistent store (DynamoDB) on disconnect.

At 500M users × 5% active = 25M presence keys in Redis → ~3.5 GB. Fits on a single medium Redis instance; shard if needed.

### Group Chat Fan-out

1:1 chat → 1 delivery. Group chat (1000 members) → up to 1000 deliveries per message.

**Small groups (<= 100 members)**: fan-out synchronously in the message handler.  
**Large groups (> 100 members)**: enqueue a fan-out job to a Kafka topic; a pool of fan-out workers consumes it and delivers to each member's server.

```
GroupMessage →  Kafka topic: group_fanout
             ← FanOutWorker: for each member in group, publish to "user:{memberId}" Redis channel
```

### Media Messages

1. Client uploads file to presigned S3 URL directly (bypasses chat server).
2. Client sends a message with `media_url` (CDN URL, not S3 direct).
3. CDN serves media to recipients — chat server never proxies binary data.
4. NSFW scanning runs async via Lambda on S3 event; if flagged, message status set to "removed".

### Push Notifications (Offline Users)

If recipient has no active WebSocket connection:
1. Chat server checks Redis presence TTL → nil (offline).
2. Enqueue to notification Kafka topic.
3. Push notification service (APNs / FCM / WNS) sends push.
4. On next app open, client fetches missed messages via REST pull (for reliability, don't rely solely on push).

## Code Example

```csharp
// SignalR hub — real-time chat (production uses WebSocket directly, but SignalR shown for .NET familiarity)
using Microsoft.AspNetCore.SignalR;
using StackExchange.Redis;

namespace Chat;

public sealed class ChatHub(
    IMessageRepository messages,
    IPresenceService presence,
    IDatabase redis) : Hub
{
    // Unique group name for direct messages to a single user
    private static string UserGroup(Guid userId) => $"user_{userId}";

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        // Join personal group so messages can be pushed to this connection
        await Groups.AddToGroupAsync(Context.ConnectionId, UserGroup(userId));
        await presence.SetOnlineAsync(userId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? ex)
    {
        var userId = GetUserId();
        await presence.SetOfflineAsync(userId);
        await base.OnDisconnectedAsync(ex);
    }

    public async Task SendMessage(Guid conversationId, string content)
    {
        var senderId = GetUserId();
        var message = new Message
        {
            Id             = Guid.NewGuid(),
            ConversationId = conversationId,
            SenderId       = senderId,
            Content        = content,
            SentAt         = DateTimeOffset.UtcNow,
            Status         = MessageStatus.Sent,
        };

        // Persist first — never deliver without durability guarantee
        await messages.SaveAsync(message);

        // Notify sender: ACK with server-assigned message ID + timestamp
        await Clients.Caller.SendAsync("MessageAck", message.Id, message.SentAt);

        // Fan-out to all conversation participants
        var participantIds = await messages.GetParticipantsAsync(conversationId);
        foreach (var recipientId in participantIds.Where(id => id != senderId))
        {
            await Clients.Group(UserGroup(recipientId))
                .SendAsync("NewMessage", message);

            // If offline, push notification handled by background service
        }
    }

    public async Task MarkRead(Guid conversationId, Guid messageId)
    {
        var userId = GetUserId();
        await messages.MarkReadAsync(conversationId, messageId, userId);

        // Notify sender of read receipt
        var msg = await messages.GetAsync(messageId);
        await Clients.Group(UserGroup(msg.SenderId))
            .SendAsync("ReadReceipt", messageId, userId);
    }

    private Guid GetUserId() =>
        Guid.Parse(Context.User!.FindFirst("sub")!.Value);
}
```

## Common Follow-up Questions

- How do you guarantee message ordering in a group chat when messages can arrive from multiple servers simultaneously?
- A user switches from WiFi to mobile data mid-conversation. How do you re-establish the WebSocket and recover missed messages?
- How would you implement end-to-end encryption so the server never sees plaintext message content?
- Your Cassandra cluster starts falling behind on writes at peak load. What levers do you pull?
- How do you handle a group chat where a user is removed — should they still see old messages?

## Common Mistakes / Pitfalls

- **Routing messages through the database**: writing to DB then polling for new messages adds latency and load; use in-memory pub/sub (Redis) for real-time delivery.
- **Fan-out on a single thread for large groups**: a 1000-member group message on a synchronous loop blocks the chat server; use a Kafka-backed async fan-out.
- **Using `message_id` as an auto-increment integer**: integer IDs collide under multi-server writes; use TIMEUUID or Snowflake IDs.
- **Storing media in Cassandra BLOBs**: media writes destroy Cassandra compaction performance; always use S3 + CDN.
- **Relying solely on push notifications for delivery**: APNs/FCM are best-effort; clients must pull missed messages on reconnect.
- **Not limiting group size**: unbounded groups (100K members) turn fan-out into a DDoS on your own infrastructure; enforce a hard cap.

## References

- [WhatsApp Architecture Blog — High Scalability](http://highscalability.com/blog/2014/2/26/the-whatsapp-architecture-facebook-bought-for-19-billion.html) (verify URL)
- [SignalR — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/signalr/introduction)
- [Cassandra Data Modelling for Time-Series](https://cassandra.apache.org/doc/latest/cassandra/data_modeling/data_modeling_rdbms.html) (verify URL)
- [System Design Interview Vol 2, Ch 12 — Alex Xu](https://www.bytebytego.com)
- [See: pub-sub-vs-message-queue.md](./pub-sub-vs-message-queue.md)
- [See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md)
