# Bloom Filters for Cache

**Category:** System Design / Caching
**Difficulty:** 🔴 Senior
**Tags:** `bloom-filter`, `probabilistic`, `false-positive`, `cache-penetration`, `bit-array`, `hash-functions`

## Question

> What is a Bloom filter, and how does it prevent unnecessary DB lookups for non-existent keys ("cache penetration")? What are the false-positive and false-negative properties, and how do you choose the filter size?

## Short Answer

A Bloom filter is a space-efficient probabilistic data structure that answers "is this element definitely NOT in the set?" with 100% accuracy, or "is this element POSSIBLY in the set?" with a tunable false-positive rate. In a caching system, it sits in front of the cache and DB: if the filter says "definitely not in DB," the request is rejected immediately without a DB query. It prevents **cache penetration attacks** — where millions of requests for non-existent keys bypass the cache and hammer the DB. Bloom filters never produce false negatives (no misses are reported as present), but may have configurable false positives (typically 1–3%).

## Detailed Explanation

### The Cache Penetration Problem

```
Attacker sends: GET /users/9999999999 (never exists)
                GET /users/8888888888
                GET /users/7777777777
                ... 1,000,000 unique non-existent IDs

For each request:
  Cache: MISS (key not cached because it never existed)
  DB:    SELECT * FROM users WHERE id = 9999999999 → empty result
```

Each request hits the DB because the cache only stores data that has been fetched. A Bloom filter says "user 9999999999 has NEVER been inserted into the DB" before even checking the cache.

### How a Bloom Filter Works

1. Allocate a bit array of size `m` (all zeros).
2. Choose `k` independent hash functions, each mapping an element to a position in `[0, m)`.
3. **Insert element `x`**: compute `h1(x), h2(x), ... hk(x)` and set those bits to 1.
4. **Query element `x`**: compute all `k` hash positions. If ANY bit is 0 → element is **definitely not present**. If ALL bits are 1 → element is **probably present** (may be a false positive from other elements setting those bits).

**False negatives: impossible.** If an element was inserted, its bits are permanently 1 (in a standard Bloom filter — deletions are not supported without variants like Counting Bloom Filter).

**False positives: tunable.** With `n` elements, `m` bits, and `k` hash functions:

```
p ≈ (1 - e^(-kn/m))^k
```

Optimal `k = (m/n) * ln(2)`. To achieve 1% false positive rate for `n` elements:
- `m ≈ 9.6 * n` bits (≈ 1.2 bytes per element)
- `k ≈ 7` hash functions

For 10 million user IDs (n=10M): m ≈ 96 MB — vastly smaller than storing all IDs.

### Space Comparison

| Approach | Space for 10M IDs | Notes |
|----------|------------------|-------|
| HashSet<long> | ~80 MB (8 bytes × 10M) | Exact; high memory |
| Sorted array + binary search | ~80 MB | Exact; read-only |
| Redis SET | ~250 MB | Exact; distributed |
| **Bloom filter (1% FPR)** | **~12 MB** | Probabilistic; tiny |
| **Bloom filter (0.1% FPR)** | **~18 MB** | Still much smaller |

### Bloom Filter in a Caching System

```
Request: GET /users/42
  1. Bloom filter: "is 42 POSSIBLY in the DB?" 
     → NO (0 bit found) → return 404 immediately — no cache/DB hit
     → YES (all bits 1)  → check cache → check DB
```

**Key insight**: non-existent keys never reach the cache or DB. This eliminates cache penetration entirely.

### Bloom Filter Variants

| Variant | Supports Deletion? | Notes |
|---------|-------------------|-------|
| Standard Bloom filter | ❌ | Simplest; smallest |
| Counting Bloom filter | ✅ | Increments counters instead of bits; 4–8x larger |
| Cuckoo filter | ✅ | Better space efficiency than counting; supports limited deletions |
| Scalable Bloom filter | N/A | Grows dynamically as elements are added |
| TinyLFU | N/A (frequency) | Used in cache admission, not membership |

### Implementation in .NET

No standard library includes a Bloom filter. Options:
1. Implement from scratch (straightforward for fixed-size cases).
2. **Redis BF** — Redis Stack includes a native Bloom filter type (`BF.ADD`, `BF.EXISTS`).
3. Third-party: `BloomFilter.NetCore` NuGet package.

### Redis Bloom Filter Commands

```
BF.RESERVE users:bloom 0.01 10000000   # 1% FPR, 10M capacity
BF.ADD     users:bloom 42
BF.EXISTS  users:bloom 42               # → 1 (possibly exists)
BF.EXISTS  users:bloom 99999999         # → 0 (definitely does not exist)
```

### When NOT to Use a Bloom Filter

- **When the false-positive rate matters for correctness**: a 1% false-positive rate means 1% of truly missing keys still hit the DB. Acceptable for DDoS protection; unacceptable if "does not exist" must be 100% accurate.
- **When the data set is small**: for < 100K items, a `HashSet<T>` in memory is fine.
- **When items are frequently deleted**: standard Bloom filters don't support deletion. Use a Cuckoo filter or a different approach.
- **When you need to retrieve values**: Bloom filters only answer membership queries — not key-value lookups.

## Code Example

```csharp
// .NET 8 — Bloom filter implementation from scratch
// Demonstrates the algorithm; use Redis BF or a library in production

using System.Security.Cryptography;

/// <summary>
/// Fixed-size Bloom filter. Thread-safe for concurrent reads; 
/// not thread-safe for concurrent Add+Query without external synchronization.
/// </summary>
public sealed class BloomFilter(int capacity, double falsePositiveRate = 0.01)
{
    private readonly int    _bitCount    = OptimalBitCount(capacity, falsePositiveRate);
    private readonly int    _hashCount   = OptimalHashCount(capacity, OptimalBitCount(capacity, falsePositiveRate));
    private readonly byte[] _bits;

    public BloomFilter(int capacity, double falsePositiveRate = 0.01) : this(capacity, falsePositiveRate)
    {
        _bits = new byte[(_bitCount + 7) / 8];
    }

    public void Add(string item)
    {
        foreach (var position in GetBitPositions(item))
            _bits[position / 8] |= (byte)(1 << (position % 8));
    }

    /// <returns>
    /// false = item is DEFINITELY NOT in the set (no false negatives).
    /// true  = item is POSSIBLY in the set (false positives possible).
    /// </returns>
    public bool MightContain(string item)
    {
        foreach (var position in GetBitPositions(item))
            if ((_bits[position / 8] & (byte)(1 << (position % 8))) == 0)
                return false;   // a 0 bit → definitely absent

        return true;
    }

    private IEnumerable<int> GetBitPositions(string item)
    {
        // Use two independent hashes to simulate k hash functions (Kirsch-Mitzenmacher)
        var bytes = System.Text.Encoding.UTF8.GetBytes(item);
        var hash1 = (int)(BinaryPrimitives(bytes, seed: 0) % _bitCount);
        var hash2 = (int)(BinaryPrimitives(bytes, seed: 1) % _bitCount);

        for (int i = 0; i < _hashCount; i++)
            yield return Math.Abs((hash1 + i * hash2) % _bitCount);
    }

    private static uint BinaryPrimitives(byte[] data, uint seed)
    {
        // MurmurHash3-inspired mixing (simplified)
        uint h = seed ^ (uint)data.Length;
        foreach (byte b in data) { h ^= b; h = System.Numerics.BitOperations.RotateLeft(h, 5); h *= 0x9e3779b1u; }
        return h;
    }

    // Optimal bit count: m = -n * ln(p) / (ln(2)^2)
    private static int OptimalBitCount(int n, double p) =>
        (int)Math.Ceiling(-n * Math.Log(p) / (Math.Log(2) * Math.Log(2)));

    // Optimal hash count: k = (m/n) * ln(2)
    private static int OptimalHashCount(int n, int m) =>
        (int)Math.Round((double)m / n * Math.Log(2));
}

// ── Integration: cache penetration guard in ASP.NET Core ─────────────
using Microsoft.Extensions.Caching.Distributed;
using StackExchange.Redis;

public sealed class UserRepository(IDatabase redis, IDistributedCache cache, ILogger<UserRepository> log)
{
    // Pre-populated Bloom filter (loaded from DB on startup)
    private static readonly BloomFilter _existingUsers = new(10_000_000, falsePositiveRate: 0.01);

    // Call during startup: load all user IDs into the filter
    public static async Task WarmFilterAsync(IEnumerable<long> allUserIds)
    {
        foreach (var id in allUserIds)
            _existingUsers.Add(id.ToString());
    }

    public async Task<User?> GetUserAsync(long id, CancellationToken ct)
    {
        // 1. Bloom filter check — O(k) time, no I/O
        if (!_existingUsers.MightContain(id.ToString()))
        {
            log.LogDebug("Bloom filter: user {Id} definitely does not exist", id);
            return null;   // ← DB query avoided entirely
        }

        // 2. Normal cache-aside from here
        var key    = $"v1:user:{id}";
        var cached = await cache.GetStringAsync(key, ct);
        if (cached is not null)
            return System.Text.Json.JsonSerializer.Deserialize<User>(cached);

        // 3. DB query (only reached if Bloom filter says "possibly exists")
        var user = await FetchFromDbAsync(id, ct);
        if (user is not null)
        {
            await cache.SetStringAsync(key,
                System.Text.Json.JsonSerializer.Serialize(user),
                new DistributedCacheEntryOptions
                    { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(15) }, ct);
        }
        return user;
    }

    private static Task<User?> FetchFromDbAsync(long id, CancellationToken _) =>
        Task.FromResult<User?>(id < 1000 ? new User(id, $"User {id}") : null);
}

// ── Redis Stack Bloom filter (production recommended) ────────────────
// var bloomKey = "users:bloom";
// await redisDb.ExecuteAsync("BF.RESERVE", bloomKey, "0.01", "10000000");
// await redisDb.ExecuteAsync("BF.ADD", bloomKey, userId.ToString());
// var exists = (int)await redisDb.ExecuteAsync("BF.EXISTS", bloomKey, userId.ToString());
// if (exists == 0) return null;  // definitely not in DB

record User(long Id, string Name);

// Suppress unused import warning
using System.Buffers.Binary;
