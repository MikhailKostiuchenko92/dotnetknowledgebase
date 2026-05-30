# Design a Distributed Cache

**Category:** System Design / Classic Problems
**Difficulty:** Senior
**Tags:** `caching`, `distributed-systems`, `consistent-hashing`, `replication`, `redis`

## Question

> Design a distributed in-memory cache (like Redis or Memcached) from scratch. The system should support GET, SET, and DELETE operations with TTL, serve millions of requests per second, and survive node failures without data loss.

- How would you distribute keys across nodes?
- How do you handle replication and failover?
- How does eviction work under memory pressure?

## Short Answer

A distributed cache consists of a cluster of nodes, with keys mapped to nodes via consistent hashing to minimise reshuffling when nodes join or leave. Each key is replicated to *N* nodes (e.g., 3), with quorum writes (W=2) and quorum reads (R=2) ensuring durability and availability. Eviction is LRU or LFU per-node based on `maxmemory-policy`; expired keys are cleaned lazily on access plus a background sweep. Failover uses a sentinel or Raft-elected leader to promote replicas automatically.

## Detailed Explanation

### Functional Requirements

| Operation | Behaviour |
|-----------|-----------|
| `SET key value [EX seconds]` | Store with optional TTL |
| `GET key` | Return value or miss |
| `DELETE key` | Remove immediately |
| `EXISTS key` | Non-destructive probe |

Non-functional: <1 ms p99, 1M+ QPS cluster-wide, 99.99% availability, configurable consistency.

### Data Partitioning — Consistent Hashing

Naïve modular hashing (`hash(key) % N`) requires remapping ~N/old_N keys on node add/remove. Consistent hashing places both nodes and keys on a 128-bit ring (MD5 or xxHash3); each key maps to the first node clockwise from its hash position.

**Virtual nodes** address hot spots: each physical node owns *V* virtual positions (V=150 is typical). When a node is added, it absorbs ~1/N of each existing node's range rather than a single contiguous slice.

```
Ring:   ... [VN-A1] ... [VN-B3] ... [VN-A2] ... [VN-C1] ...
Key K:  hash(K) falls between VN-B3 and VN-A2 → owned by Node A
```

### Replication — N/W/R Quorum

For durability, the coordinator node replicates synchronously to the next *N−1* clockwise nodes (preference list).

- **N = 3**: three physical copies
- **W = 2**: write ACK requires 2/3 nodes to confirm
- **R = 2**: read from 2/3 nodes, return latest version (compare vector clocks)
- **W + R > N** guarantees at least one overlapping node sees the latest write

Async replication to the third replica allows the coordinator to ACK the client quickly; hinted handoff stores the write locally when the target node is down and delivers it on recovery.

### Replication & Failover

**Sentinel mode** (Redis model):
- 3+ sentinel processes monitor the primary
- Quorum vote triggers failover → replica elected as new primary
- Client libraries auto-discover the new primary via sentinel

**Cluster mode** (peer-to-peer):
- Each primary owns a shard of the keyspace (16,384 hash slots in Redis)
- Each primary has 1–2 replicas
- Gossip protocol (PING/PONG) detects failures; any majority of masters can elect a new master for a failed slot range

### Memory Management & Eviction

Each node has a fixed `maxmemory` ceiling. When reached, eviction applies:

| Policy | Behaviour |
|--------|-----------|
| `noeviction` | Return error on writes |
| `allkeys-lru` | Evict least-recently-used from all keys |
| `allkeys-lfu` | Evict least-frequently-used (better for skewed access) |
| `volatile-lru` | LRU among keys with TTL set |
| `volatile-ttl` | Evict soonest-to-expire first |

**Lazy expiry**: check TTL on GET; if expired, delete and return miss.  
**Active sweep**: background thread samples 20 random keys with TTL every 100 ms; if >25% expired, repeat immediately (Redis approach).

### Client Protocol

A custom binary protocol (like RESP3) reduces parsing overhead vs JSON/HTTP:
- Fixed-length header (type byte + length)
- Pipelining: multiple commands in one TCP send, responses batched
- Connection multiplexing: single TCP connection serves many concurrent requests (avoids socket exhaustion)

### Capacity Estimation

| Parameter | Value |
|-----------|-------|
| Read QPS | 1M/s |
| Write QPS | 100K/s |
| Avg value size | 1 KB |
| Cache size | 1 TB total |
| Nodes (32 GB RAM each) | ~40 nodes |
| Network (1 KB × 1M QPS) | ~8 Gbps → 10 GbE NICs |

### .NET Client Architecture

StackExchange.Redis is the standard .NET client. It maintains a single multiplexed connection per endpoint, uses pipelining automatically, and supports cluster topology discovery.

> **Warning:** Use `IDistributedCache` (abstraction) in application code, not `IDatabase` directly. This allows swapping Redis for in-memory cache in tests.

## Code Example

```csharp
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.StackExchangeRedis;
using StackExchange.Redis;
using System.Text.Json;

// Startup — cluster-aware connection
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddStackExchangeRedisCache(options =>
{
    options.ConfigurationOptions = new ConfigurationOptions
    {
        EndPoints = { "cache-node1:6379", "cache-node2:6379", "cache-node3:6379" },
        ConnectTimeout = 1000,
        SyncTimeout = 500,
        AbortOnConnectFail = false,    // survive transient failures
        ReconnectRetryPolicy = new ExponentialRetry(5000),
    };
});

// Cache service with stampede protection
public sealed class CacheService(IDistributedCache cache)
{
    private static readonly SemaphoreSlim _lock = new(1, 1);

    public async Task<T?> GetOrSetAsync<T>(
        string key,
        Func<CancellationToken, Task<T>> factory,
        TimeSpan ttl,
        CancellationToken ct = default)
    {
        var bytes = await cache.GetAsync(key, ct);
        if (bytes is not null)
            return JsonSerializer.Deserialize<T>(bytes);

        // Double-checked locking prevents thundering herd
        await _lock.WaitAsync(ct);
        try
        {
            bytes = await cache.GetAsync(key, ct);
            if (bytes is not null)
                return JsonSerializer.Deserialize<T>(bytes);

            var value = await factory(ct);
            if (value is null) return default;

            var serialised = JsonSerializer.SerializeToUtf8Bytes(value);
            await cache.SetAsync(key, serialised,
                new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = ttl
                    // Jitter: ttl + TimeSpan.FromSeconds(Random.Shared.Next(-30, 30))
                }, ct);

            return value;
        }
        finally { _lock.Release(); }
    }
}
```

## Common Follow-up Questions

- How do you handle cache invalidation across replicas when a write reaches the primary but not all replicas?
- What is the "thundering herd" problem and how does probabilistic early expiration (PER) solve it?
- How would you implement multi-tenancy (namespace isolation) in a shared cache cluster?
- Your read QPS doubles. Walk me through scaling the cache without downtime.
- How do you prevent hot keys from overloading a single node?
- What changes when the cache needs to span multiple geographic regions?

## Common Mistakes / Pitfalls

- **Ignoring TTL jitter**: setting identical TTLs on millions of keys causes a mass simultaneous expiry ("thundering herd"). Always add ±10–20% random jitter.
- **Using `IDatabase` directly**: bypasses the abstraction; makes testing painful and couples code to Redis.
- **Not sizing the connection pool**: StackExchange.Redis multiplexes, but `maxmemory` violations without a policy set cause silent write failures (`noeviction`).
- **Treating cache misses as errors**: a miss should trigger a database read, not an alarm. Differentiate cache miss from cache error (connection failure).
- **Replication lag in reads**: reading from a replica without awareness of replication lag can return stale data. Use `R=2` quorum or always read from primary for consistency-sensitive paths.
- **No fallback on cache down**: failing open (serve from DB on cache failure) is almost always correct; failing closed (return 500) cascades into a full outage.

## References

- [Redis Cluster Specification](https://redis.io/docs/reference/cluster-spec/)
- [StackExchange.Redis Configuration](https://stackexchange.github.io/StackExchange.Redis/Configuration)
- [IDistributedCache — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/performance/caching/distributed)
- [Consistent Hashing Explained — Ably Blog](https://ably.com/blog/implementing-smart-rebalancing-with-consistent-hashing) (verify URL)
- [See: cache-eviction-policies.md](./cache-eviction-policies.md)
- [See: distributed-cache-vs-local-cache.md](./distributed-cache-vs-local-cache.md)
