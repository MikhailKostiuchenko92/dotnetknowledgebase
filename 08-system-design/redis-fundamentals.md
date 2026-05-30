# Redis Fundamentals

**Category:** System Design / Caching
**Difficulty:** 🟡 Middle
**Tags:** `redis`, `data-structures`, `persistence`, `RDB`, `AOF`, `clustering`, `pub-sub`, `StackExchange.Redis`

## Question

> What is Redis and what makes it fast? Describe the main data structures Redis provides, its persistence options (RDB vs AOF), and how Redis clustering works.
>
> Follow-up: How do you use Redis in .NET, and what are the trade-offs between `IDistributedCache` and using StackExchange.Redis directly?

## Short Answer

Redis is an in-memory data store that achieves microsecond latency because all data lives in RAM and operations are processed in a single-threaded event loop, eliminating locking overhead. It offers rich data structures (strings, hashes, lists, sets, sorted sets, streams, bitmaps, HyperLogLog, geospatial) beyond simple key-value. Persistence is optional: RDB writes snapshots at intervals, AOF logs every write command, or both. Redis Cluster partitions keyspace across nodes using 16,384 hash slots for horizontal scaling with automatic failover. In .NET, use `IDistributedCache` for the standard caching interface or StackExchange.Redis for full Redis capabilities.

## Detailed Explanation

### Why Redis Is Fast

- **All data in RAM**: no disk I/O on reads or writes.
- **Single-threaded command processing**: no mutex/lock overhead; commands are processed one at a time in an event loop (Redis 6+ added I/O threading for network, but command execution remains single-threaded).
- **Non-blocking I/O (epoll/kqueue)**: thousands of client connections handled without thread-per-client overhead.
- **Optimised data structures**: hand-tuned C implementations (e.g., `listpack` for small sets, `skiplist` for sorted sets).

Typical latency: **< 1 ms** for simple GET/SET; **< 100 µs** on a local network.

### Data Structures

| Structure | Commands | Typical Use Case |
|-----------|----------|-----------------|
| **String** | `GET`, `SET`, `INCR`, `SETEX` | Cache values, counters, session tokens |
| **Hash** | `HGET`, `HSET`, `HMGET` | Object storage (user profile fields) |
| **List** | `LPUSH`, `RPOP`, `LRANGE` | Queues, activity feeds, recent items |
| **Set** | `SADD`, `SISMEMBER`, `SUNION` | Tags, unique visitors, friend lists |
| **Sorted Set (ZSet)** | `ZADD`, `ZRANGE`, `ZRANGEBYSCORE` | Leaderboards, rate limiting (sliding window) |
| **Stream** | `XADD`, `XREAD`, `XGROUP` | Persistent message queue / event log |
| **Bitmap** | `SETBIT`, `GETBIT`, `BITCOUNT` | Daily active user tracking (1 bit per user) |
| **HyperLogLog** | `PFADD`, `PFCOUNT` | Approximate distinct count (0.81% error) |
| **Geospatial** | `GEOADD`, `GEODIST`, `GEORADIUS` | Location-based queries |

### Persistence Options

#### RDB (Redis Database Snapshot)

Redis forks the process and dumps a binary snapshot to disk at configured intervals (e.g., `save 900 1` = save if at least 1 key changed in the last 900 seconds).

- **Pros**: compact file; fast restarts; no performance impact on main process (fork + copy-on-write).
- **Cons**: potential data loss equal to the snapshot interval; `BGSAVE` fork can be slow on large datasets (memory copy-on-write spikes).

#### AOF (Append-Only File)

Every write command is appended to a log file. On restart, Redis replays the log.

- **Pros**: configurable durability (`appendfsync always/everysec/no`); maximum data loss = 1 second with `everysec`.
- **Cons**: AOF files grow large (mitigated by `BGREWRITEAOF` compaction); slightly higher write throughput impact.

#### Hybrid (RDB + AOF) — Recommended for Production

Redis 4.0+ supports a hybrid format: AOF file starts with an RDB snapshot, followed by incremental AOF tail. Combines fast restart (from RDB) with minimal data loss (from AOF).

```
# redis.conf
appendonly yes
appendfsync everysec
aof-use-rdb-preamble yes   # hybrid mode
```

> **No persistence mode**: Redis used purely as a cache. If Redis restarts, all data is lost — acceptable if the cache is always rebuildable from the DB.

### Redis Cluster

Redis Cluster partitions the keyspace across nodes using **16,384 hash slots**:

```
hash_slot = CRC16(key) % 16384
```

Each master node owns a range of slots (e.g., node A: 0–5460, node B: 5461–10922, node C: 10923–16383). Each master has one or more replicas for failover.

**Hash tags** force related keys to the same slot: `{user:42}:profile` and `{user:42}:session` both hash on `user:42`.

**Cluster reads**: by default, clients read from the primary. With `READONLY`, reads can go to replicas (may return stale data).

**Failover**: if a master is unreachable for `cluster-node-timeout` ms, a replica is automatically promoted.

**Multi-key operations**: Lua scripts and `MGET`/`MSET` only work when all keys are in the same slot → use hash tags.

### Redis Sentinel (vs Cluster)

For single-shard high availability without partitioning, Redis Sentinel monitors master/replica and promotes the replica on master failure. Simpler than cluster but no horizontal scaling.

### .NET Integration

#### IDistributedCache (Microsoft abstraction)

```csharp
// Registration
builder.Services.AddStackExchangeRedisCache(o => o.Configuration = "localhost:6379");

// Use
await cache.SetStringAsync("key", "value", new DistributedCacheEntryOptions
{
    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10)
});
var val = await cache.GetStringAsync("key");
```

**Pros**: swappable (Redis → SQL Server → memory for tests); simple string/byte[] interface.
**Cons**: only string/byte[] values; no access to Redis-native structures (sorted sets, pub/sub, Lua).

#### StackExchange.Redis (Full Access)

```csharp
var redis = await ConnectionMultiplexer.ConnectAsync("localhost:6379");
var db = redis.GetDatabase();

// Sorted set for leaderboard
await db.SortedSetAddAsync("leaderboard", "alice", 1500);
await db.SortedSetAddAsync("leaderboard", "bob",   1200);
var top3 = await db.SortedSetRangeByRankWithScoresAsync("leaderboard", 0, 2, Order.Descending);

// Pub/sub
var sub = redis.GetSubscriber();
await sub.PublishAsync("notifications:user:42", "new-message");
await sub.SubscribeAsync("notifications:user:42", (ch, msg) => Console.WriteLine(msg));
```

**Use StackExchange.Redis when**: you need leaderboards, pub/sub, streams, Lua scripts, atomic multi-key operations.

## Code Example

```csharp
// .NET 8 — Redis common patterns with StackExchange.Redis

using StackExchange.Redis;
using System.Text.Json;

var conn  = await ConnectionMultiplexer.ConnectAsync("localhost:6379");
var db    = conn.GetDatabase();
var sub   = conn.GetSubscriber();

// ── 1. String — simple cache with TTL ────────────────────────────────
await db.StringSetAsync("session:abc123", "user:42", TimeSpan.FromMinutes(30));
string? session = await db.StringGetAsync("session:abc123");

// ── 2. Hash — store object fields without serialising entire object ───
await db.HashSetAsync("user:42", [
    new HashEntry("name",  "Alice"),
    new HashEntry("email", "alice@example.com"),
    new HashEntry("role",  "admin")
]);
var name = await db.HashGetAsync("user:42", "name");     // "Alice"
var user = await db.HashGetAllAsync("user:42");          // all fields

// ── 3. Sorted Set — leaderboard ───────────────────────────────────────
await db.SortedSetAddAsync("scores:2025", [
    new SortedSetEntry("alice", 1500),
    new SortedSetEntry("bob",   1200),
    new SortedSetEntry("carol", 1800),
]);
var top3 = await db.SortedSetRangeByRankWithScoresAsync(
    "scores:2025", 0, 2, Order.Descending);   // carol, alice, bob

// ── 4. Atomic counter (INCR is single-threaded — no lost updates) ─────
long views = await db.StringIncrementAsync("page:home:views");

// ── 5. Distributed lock (SET NX + PX) — prevents stampede ────────────
bool locked = await db.StringSetAsync("lock:job:1", "worker-1",
    TimeSpan.FromSeconds(30), When.NotExists);

// ── 6. Pub/Sub — event notification ──────────────────────────────────
await sub.SubscribeAsync(RedisChannel.Literal("orders:new"), (_, msg) =>
    Console.WriteLine($"New order: {msg}"));

await sub.PublishAsync(RedisChannel.Literal("orders:new"),
    JsonSerializer.Serialize(new { OrderId = 99, Amount = 149.99 }));

// ── 7. Rate limiting with sorted set (sliding window) ─────────────────
// Store request timestamps; count those within the window
async Task<bool> IsAllowedAsync(string userId, int limit, TimeSpan window)
{
    var now  = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    var key  = $"rl:{userId}";
    var pipe = db.CreateBatch();

    var remove  = pipe.SortedSetRemoveRangeByScoreAsync(key, 0, now - (long)window.TotalMilliseconds);
    var count   = pipe.SortedSetLengthAsync(key);
    var add     = pipe.SortedSetAddAsync(key, now.ToString(), now);
    var expire  = pipe.KeyExpireAsync(key, window);
    pipe.Execute();

    await Task.WhenAll(remove, count, add, expire);
    return await count < limit;
}

await conn.DisposeAsync();
```

## Common Follow-up Questions

- How does Redis handle concurrent writes if it's single-threaded? Can two clients race on the same key?
- When should you use Redis Sentinel vs Redis Cluster?
- What happens to in-flight data during a Redis Cluster node failover?
- How do you implement distributed locking correctly with Redis (Redlock algorithm)?
- What is the Redis `WAIT` command and when do you use it?
- How do Redis Streams differ from pub/sub, and when should you prefer them?

## Common Mistakes / Pitfalls

- **`ConnectionMultiplexer` created per-request**: `ConnectionMultiplexer` is designed to be long-lived and shared across the application. Creating one per request is extremely expensive (TCP + auth handshake). Register as a singleton.
- **Assuming pub/sub is durable**: Redis pub/sub is fire-and-forget. Messages delivered to zero subscribers are lost. For durable event delivery, use Redis Streams (`XADD`/`XREADGROUP`) instead.
- **Multi-key operations across cluster slots**: `MGET key1 key2` fails in cluster mode if keys are in different slots. Use hash tags (`{user:42}:profile`, `{user:42}:session`) to co-locate keys.
- **Treating AOF as a transaction log**: AOF records commands, not row-level changes. Replaying AOF after a crash uses the commands as originally issued — INCR 5 times = state correct, but if commands involved external logic they may not be idempotent.
- **No maxmemory policy configured**: without a `maxmemory-policy`, Redis blocks new writes when memory is full (in Redis ≥ 7: `noeviction` is default). Always configure `maxmemory` and an appropriate eviction policy (`allkeys-lru` for pure cache). [See: cache-eviction-policies.md](./cache-eviction-policies.md)
- **Storing large blobs (> 1 MB) in Redis**: Redis is optimised for many small values. Storing large JSON/binary blobs wastes memory, increases serialisation cost, and can block the event loop during serialization.

## References

- [Redis documentation — data types](https://redis.io/docs/data-types/)
- [Redis persistence (RDB and AOF)](https://redis.io/docs/management/persistence/)
- [Redis Cluster specification](https://redis.io/docs/management/scaling/)
- [StackExchange.Redis — GitHub](https://github.com/StackExchange/StackExchange.Redis)
- [Azure Cache for Redis — .NET quickstart](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-dotnet-core-quickstart)
