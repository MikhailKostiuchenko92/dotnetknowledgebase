# Cache Eviction Policies

**Category:** System Design / Caching
**Difficulty:** 🔴 Senior
**Tags:** `cache-eviction`, `LRU`, `LFU`, `FIFO`, `ARC`, `TinyLFU`, `Redis`, `maxmemory-policy`, `IMemoryCache`

## Question

> Explain the main cache eviction policies (LRU, LFU, FIFO, ARC/TinyLFU). When does each one perform best, and what are its failure modes? How do you configure eviction in Redis and `IMemoryCache`?

## Short Answer

**LRU** (Least Recently Used) evicts the entry accessed longest ago — excellent for temporal locality but bad when scan patterns pollute the cache with single-use data. **LFU** (Least Frequently Used) evicts the least-accessed entry — resists scan pollution but doesn't handle temporal shifts well (a popular item from last month remains until it's accessed again). **FIFO** evicts by insertion order regardless of access — simple but worst cache-hit ratio for most workloads. **ARC** and **TinyLFU** are adaptive algorithms that combine recency and frequency tracking to achieve near-optimal hit rates in practice. Redis supports approximate LRU and LFU via `maxmemory-policy`; `IMemoryCache` supports priority-based eviction with a configurable size limit.

## Detailed Explanation

### Why Eviction Matters

A cache has finite memory. When it's full and a new item must be inserted, something must be evicted. The eviction choice directly determines cache hit ratio — and therefore the load on the DB and the tail latency of your service.

### FIFO (First-In, First-Out)

Evicts the oldest-inserted entry, regardless of access pattern.

**Implementation**: circular buffer or queue.
**Time complexity**: O(1) eviction.
**Use case**: task queues, not caches. In a cache, recently inserted popular items are evicted before older infrequently-accessed items — the opposite of what you want.
**Failure mode**: hot data inserted early is evicted when new items arrive, even if it's still being accessed frequently.

### LRU (Least Recently Used)

Evicts the entry that was accessed **least recently** (longest time since last access).

**Classic implementation**: HashMap + doubly-linked list. On access, move the node to the head; evict from the tail.
**Time complexity**: O(1) get/put.
**Redis**: Approximate LRU — Redis samples N random keys and evicts the one with the oldest `lru_clock` timestamp. Approximation avoids the overhead of maintaining the full LRU list (saves ~3 bytes per key at scale).

**Best for**: workloads with **temporal locality** — recently used data is likely to be used again soon. Web sessions, user profile caches.

**Failure modes**:
1. **Full scan (cache pollution)**: a query that scans 1 million keys that are never accessed again fills the cache with cold data, evicting all your hot entries. After the scan, cache hit rate crashes.
2. **Static working set larger than cache**: if you have 10 GB of hot data and a 5 GB cache, LRU performs fine. If you have 4 GB of hot data and 1 MB of frequently accessed data, LRU may evict the 1 MB data when the 4 GB is cycled through.

### LFU (Least Frequently Used)

Evicts the entry with the **lowest access frequency**.

**Implementation**: min-heap or frequency counter + doubly-linked list.
**Redis LFU**: uses a Morris counter (probabilistic approximation) — 8-bit counter per key with logarithmic increment. Counter decays over time (controlled by `lfu-decay-time`).

**Best for**: workloads with **frequency skew** — a small hot set (Zipf distribution) should stay in cache even if accessed hours ago.

**Failure modes**:
1. **New items evicted immediately**: a newly inserted item has frequency = 1 and is immediately evicted if the cache is full of items with frequency ≥ 2. New hot data never gets a chance to warm up. Redis mitigates this by initialising new keys with the global average frequency.
2. **Stale popular data**: an item popular last month still has a high frequency counter and resists eviction even if it's never accessed again. Mitigated by frequency decay.

### ARC (Adaptive Replacement Cache)

ARC maintains **four lists** internally:
- **T1**: recently inserted items (FIFO behaviour)
- **T2**: frequently used items (LRU behaviour)
- **B1**: ghost list of T1 evictions (metadata only, no data)
- **B2**: ghost list of T2 evictions (metadata only, no data)

When a hit occurs in B1 (previously evicted from T1), ARC grows T2 (favouring frequency). When a hit occurs in B2, ARC grows T1 (favouring recency). The balance parameter `p` adapts automatically.

**Result**: ARC is self-tuning between LRU and LFU behaviour based on observed access patterns.
**Limitation**: patented by IBM; not used in Redis. Used in ZFS, some database buffer pools.

### TinyLFU / W-TinyLFU

Used in Caffeine (Java) and as the inspiration for modern .NET approaches. Maintains a frequency sketch (Count-Min sketch — probabilistic frequency table) over a window of recent accesses, combined with an LRU-protected "admission window" for new items.

**Key insight**: before evicting a cached item in favour of a new one, **compare their estimated frequencies**. Only admit the new item if it's more popular than what it would evict.

This makes TinyLFU nearly immune to scan pollution and cold-start problems.
.NET: **Microsoft.Extensions.Caching.Hybrid** internally uses a simplified version of this for its local (L1) tier.

### Redis Eviction Policies

Configure via `maxmemory-policy` in `redis.conf`:

| Policy | Algorithm | Scope |
|--------|-----------|-------|
| `noeviction` | Block writes when full | All keys |
| `allkeys-lru` | Approximate LRU | All keys |
| `allkeys-lfu` | Approximate LFU | All keys |
| `allkeys-random` | Random | All keys |
| `volatile-lru` | Approximate LRU | Keys with TTL only |
| `volatile-lfu` | Approximate LFU | Keys with TTL only |
| `volatile-ttl` | Evict soonest-to-expire | Keys with TTL only |
| `volatile-random` | Random | Keys with TTL only |

**Recommendations:**
- **Pure cache** (all data is rebuildable): `allkeys-lru` or `allkeys-lfu`.
- **Mixed (cache + persistent)**: `volatile-lru`/`volatile-lfu` so that keys without TTL (persistent data) are never evicted.
- **Never `noeviction` for a cache role**: writes will fail when Redis is full.

```
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lfu
lfu-log-factor 10        # higher = slower frequency increment (less aggressive)
lfu-decay-time 1         # halve frequency counter every N minutes
maxmemory-samples 10     # keys sampled per eviction decision (higher = more accurate LRU/LFU)
```

### IMemoryCache Eviction

`IMemoryCache` does not evict by count by default. To enable size-based eviction:

```csharp
services.AddMemoryCache(o => o.SizeLimit = 10_000);

cache.Set("key", value, new MemoryCacheEntryOptions
{
    Size     = 1,                                       // relative cost units
    Priority = CacheItemPriority.High,                  // Low/Normal/High/NeverRemove
    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10)
});
```

Eviction is triggered when `SizeLimit` is exceeded. `IMemoryCache` uses a **priority + size** model, not pure LRU, but respects recency within the same priority bucket.

## Code Example

```csharp
// .NET 8 — Custom LRU cache implementation (interview-level)
// O(1) get/put using Dictionary + LinkedList

public sealed class LruCache<TKey, TValue>(int capacity) where TKey : notnull
{
    private readonly int _capacity = capacity;
    private readonly Dictionary<TKey, LinkedListNode<(TKey Key, TValue Value)>> _map = new();
    private readonly LinkedList<(TKey Key, TValue Value)> _order = new();

    public bool TryGet(TKey key, out TValue? value)
    {
        if (_map.TryGetValue(key, out var node))
        {
            _order.Remove(node);
            _order.AddFirst(node);       // move to most-recently-used head
            value = node.Value.Value;
            return true;
        }
        value = default;
        return false;
    }

    public void Put(TKey key, TValue value)
    {
        if (_map.TryGetValue(key, out var existing))
        {
            _order.Remove(existing);
            _map.Remove(key);
        }
        else if (_map.Count >= _capacity)
        {
            // Evict least-recently-used (tail)
            var lru = _order.Last!;
            _order.RemoveLast();
            _map.Remove(lru.Value.Key);
        }

        var node = new LinkedListNode<(TKey, TValue)>((key, value));
        _order.AddFirst(node);
        _map[key] = node;
    }
}

// ── Usage ─────────────────────────────────────────────────────────────
var cache = new LruCache<string, int>(capacity: 3);
cache.Put("a", 1);
cache.Put("b", 2);
cache.Put("c", 3);

cache.TryGet("a", out _);   // "a" is now MRU

cache.Put("d", 4);          // evicts "b" (LRU), not "a"

// ── Redis eviction configuration via StackExchange.Redis ──────────────
// (programmatic config — usually done in redis.conf or Azure portal)
using StackExchange.Redis;

var redis = await ConnectionMultiplexer.ConnectAsync("localhost:6379");
var server = redis.GetServer("localhost:6379");

// Check current policy
var info = await server.InfoAsync("memory");
// Look for: maxmemory_policy

// ── IMemoryCache with SizeLimit and Priority ──────────────────────────
using Microsoft.Extensions.Caching.Memory;

var memCache = new MemoryCache(new MemoryCacheOptions { SizeLimit = 500 });

// High-priority entry (evicted last)
memCache.Set("config:featureFlags", new { EnableBeta = true },
    new MemoryCacheEntryOptions
    {
        Size     = 1,
        Priority = CacheItemPriority.High,
        AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
    });

// Low-priority entry (evicted first)
memCache.Set("feed:trending", new[] { "item1", "item2" },
    new MemoryCacheEntryOptions
    {
        Size     = 50,
        Priority = CacheItemPriority.Low,
        AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5)
    });
```

## Common Follow-up Questions

- Why does Redis use approximate LRU rather than exact LRU, and what's the accuracy trade-off?
- How does the Caffeine cache (Java) achieve near-optimal hit ratios with W-TinyLFU, and is there a .NET equivalent?
- If a cache is 90% full of hot data and 10% scan data, which eviction policy removes the scan data fastest?
- What is the "frequency decay" mechanism in Redis LFU, and why is it needed?
- How would you benchmark eviction policy effectiveness for your specific access pattern?
- When is `CacheItemPriority.NeverRemove` safe to use in `IMemoryCache`?

## Common Mistakes / Pitfalls

- **Leaving `maxmemory-policy` as `noeviction` on a cache Redis**: when memory fills, all writes fail (COMMAND OOM error). Always set a policy for cache-role Redis instances.
- **Using `volatile-lru` without setting TTL on all keys**: keys without TTL are never evicted under `volatile-*` policies — if all keys lack TTL, the policy degrades to `noeviction`.
- **Not setting `SizeLimit` on `IMemoryCache`**: without it, entries are never evicted by size. If code adds unbounded entries (e.g., one entry per HTTP request), the process runs out of memory.
- **Setting all entries to `CacheItemPriority.High`**: defeats the purpose of priority-based eviction. Only truly critical/expensive-to-rebuild entries deserve high priority.
- **Confusing LRU eviction with TTL expiry**: TTL removes entries after a fixed duration regardless of access. Eviction only occurs under memory pressure. They are complementary — always set both TTL and configure eviction.
- **Choosing LFU without decay for caches with shifting workloads**: yesterday's hot items keep high counters and resist eviction even if access patterns have moved on entirely. Always configure `lfu-decay-time` in Redis.

## References

- [Redis eviction policies — official documentation](https://redis.io/docs/manual/eviction/)
- [Redis LFU implementation notes](https://redis.io/docs/reference/eviction/#the-new-lfu-mode)
- [Caffeine cache — TinyLFU paper](https://dl.acm.org/doi/10.1145/3149360) (verify URL)
- [IMemoryCache eviction in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/memory#use-setsize-size-and-sizelimit-to-limit-cache-size)
- [See: redis-fundamentals.md](./redis-fundamentals.md) — Redis configuration and clustering
