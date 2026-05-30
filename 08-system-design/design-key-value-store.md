# Design: Key-Value Store

**Category:** System Design / Classic Design Problems
**Difficulty:** 🟡 Middle
**Tags:** `system-design`, `key-value-store`, `consistent-hashing`, `replication`, `partitioning`, `LSM-tree`, `Dynamo`, `etcd`

## Question

> Design a distributed key-value store supporting GET, PUT, and DELETE. Handle horizontal scaling to 100 nodes, data replication for fault tolerance, and configurable consistency guarantees. Think DynamoDB / Redis Cluster / etcd.

## Short Answer

A distributed key-value store partitions keys across nodes using **consistent hashing** (a ring), replicates each key to N successive nodes for fault tolerance, and uses a quorum-based write/read protocol (W + R > N ensures consistency). Writes typically go to a coordinator that replicates to N nodes; reads can be from any R quorums — with N=3, W=2, R=2 being the common balance. Conflict resolution is via vector clocks (last-write-wins for simple cases) or application-level merge. Persistence uses an **LSM-tree** (write-optimised, compaction-based) like LevelDB or RocksDB.

## Detailed Explanation

### API

```
PUT key value [ttl_seconds]  → OK | ERROR
GET key                      → value | NOT_FOUND
DELETE key                   → OK | NOT_FOUND
```

### Data Partitioning: Consistent Hashing

Without consistent hashing, adding/removing nodes requires rehashing all keys. With consistent hashing:
- Place nodes on a virtual ring by hashing their IDs.
- Each key maps to the first node clockwise on the ring.
- Adding a node: only its immediate predecessor's keys migrate.
- Removing a node: only its keys migrate to the next node.

**Virtual nodes (vnodes)**: each physical node is represented by K virtual nodes on the ring (e.g., K=150). This ensures even distribution even with heterogeneous hardware.

### Replication

Store each key on the N nodes following the key's home node on the ring. Common: N=3.

```
Ring: A → B → C → D → E

Key K → hashes to B
With N=3, replicate to: B (primary), C, D
```

This means any key is always on 3 consecutive nodes.

### Consistency: Quorum Reads/Writes

Configure:
- **N**: replication factor (e.g., 3)
- **W**: write quorum — how many replicas must ACK before write is confirmed
- **R**: read quorum — how many replicas must respond before read is returned

Rules:
- `W + R > N` → strong consistency (reads always see the latest write)
- `W = 1` → fastest writes, risk of data loss
- `R = 1` → fastest reads, may return stale data
- `W = N` → all replicas must write (slowest, most durable)

**Common configurations**:
- N=3, W=2, R=2: balanced availability and consistency
- N=3, W=1, R=1: maximum availability, eventual consistency (Dynamo default)
- N=3, W=3, R=1: maximum durability, reads are fast

### Conflict Resolution

When a key is written to partitioned replicas that later reconcile:
- **Last-Write-Wins (LWW)**: keep the entry with the latest timestamp. Simple but loses concurrent writes.
- **Vector clocks**: each write increments a per-node version counter. On conflict, the version with the highest clock wins or both are kept for application-level merge.
- **CRDTs**: data types designed to merge automatically (counters, sets).

### Persistence: LSM-Tree

Write-optimised storage:
1. All writes go to an in-memory **MemTable** (sorted map).
2. MemTable flushed to disk as an **SSTable** (immutable, sorted file) when full.
3. Background **compaction** merges SSTables, removing obsolete values.

Reads: check MemTable first, then SSTables in order (newest to oldest). **Bloom filter** per SSTable skips files that definitely don't contain the key.

### Architecture Overview

```
Client
  │
  ▼
[Coordinator Node (chosen by hashing client request)]
  │
  ├─ Writes W of N replicas → ACK to client
  ├─ Reads from R of N replicas → return newest value to client
  │
  ▼
[Ring of N Nodes]
  Each node:
    - MemTable (in-memory writes)
    - WAL (crash recovery)
    - SSTables (persisted, immutable)
    - Bloom filter (skip-list per SSTable)
    - Hinted handoff (store writes for down nodes, replay on recovery)

[Gossip Protocol] — nodes exchange ring membership and health
```

### Handling Node Failures: Hinted Handoff

If a target replica is down, the coordinator writes to the next healthy node with a "hint" that the data belongs to the down node. When the down node recovers, the hint is replayed. This maintains W-quorum availability during temporary outages.

## Code Example

```csharp
// .NET 8 — Consistent hashing ring (core algorithm)

using System.Security.Cryptography;
using System.Text;

/// <summary>
/// Consistent hashing ring with virtual nodes.
/// Each physical node is represented by K virtual nodes for even distribution.
/// </summary>
public sealed class ConsistentHashRing<TNode>(int virtualNodesPerNode = 150)
    where TNode : notnull
{
    private readonly SortedDictionary<uint, TNode> _ring = new();
    private readonly int _vnodes = virtualNodesPerNode;

    public void AddNode(TNode node)
    {
        for (int i = 0; i < _vnodes; i++)
        {
            var hash = Hash($"{node}:{i}");
            _ring.TryAdd(hash, node);
        }
    }

    public void RemoveNode(TNode node)
    {
        for (int i = 0; i < _vnodes; i++)
            _ring.Remove(Hash($"{node}:{i}"));
    }

    /// <summary>Get the N nodes responsible for a key (replication).</summary>
    public IReadOnlyList<TNode> GetNodes(string key, int replicationFactor = 3)
    {
        if (_ring.Count == 0) return [];

        var hash   = Hash(key);
        var result = new List<TNode>();
        var seen   = new HashSet<TNode>();

        // Walk ring clockwise from the key's position
        foreach (var kvp in _ring.Where(kv => kv.Key >= hash).Concat(_ring))
        {
            if (seen.Add(kvp.Value))
                result.Add(kvp.Value);
            if (result.Count == Math.Min(replicationFactor, seen.Count))
                break;
        }
        return result;
    }

    private static uint Hash(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return BitConverter.ToUInt32(bytes, 0);
    }
}

// ── In-memory key-value store with TTL (single node) ────────────────
public sealed class KeyValueStore
{
    private record Entry(string Value, DateTimeOffset? Expiry);
    private readonly System.Collections.Concurrent.ConcurrentDictionary<string, Entry> _data = new();

    public void Put(string key, string value, TimeSpan? ttl = null)
    {
        var expiry = ttl.HasValue ? DateTimeOffset.UtcNow + ttl.Value : (DateTimeOffset?)null;
        _data[key] = new Entry(value, expiry);
    }

    public (bool Found, string? Value) Get(string key)
    {
        if (!_data.TryGetValue(key, out var entry)) return (false, null);
        if (entry.Expiry.HasValue && DateTimeOffset.UtcNow > entry.Expiry)
        {
            _data.TryRemove(key, out _);
            return (false, null);
        }
        return (true, entry.Value);
    }

    public bool Delete(string key) => _data.TryRemove(key, out _);
}

// ── Usage example ─────────────────────────────────────────────────────
var ring = new ConsistentHashRing<string>();
ring.AddNode("node-1");
ring.AddNode("node-2");
ring.AddNode("node-3");
ring.AddNode("node-4");
ring.AddNode("node-5");

// Key "user:42" → hash → 3 successive nodes
var nodes = ring.GetNodes("user:42", replicationFactor: 3);
Console.WriteLine($"Key 'user:42' replicated to: {string.Join(", ", nodes)}");

// When node-2 is removed, only its keys migrate to node-3
ring.RemoveNode("node-2");
var afterRemoval = ring.GetNodes("user:42", replicationFactor: 3);
Console.WriteLine($"After removing node-2: {string.Join(", ", afterRemoval)}");

// ── ASP.NET Core minimal API ──────────────────────────────────────────
var storeApp = WebApplication.Create(args);
var store    = new KeyValueStore();

storeApp.MapGet("/kv/{key}", (string key) =>
{
    var (found, value) = store.Get(key);
    return found ? Results.Ok(new { key, value }) : Results.NotFound();
});

storeApp.MapPut("/kv/{key}", (string key, KvPutRequest req) =>
{
    store.Put(key, req.Value, req.TtlSeconds.HasValue
        ? TimeSpan.FromSeconds(req.TtlSeconds.Value) : null);
    return Results.Ok(new { key });
});

storeApp.MapDelete("/kv/{key}", (string key) =>
    store.Delete(key) ? Results.NoContent() : Results.NotFound());

storeApp.Run();
record KvPutRequest(string Value, int? TtlSeconds);
```

## Common Follow-up Questions

- How does consistent hashing prevent "hot partition" problems when key access is skewed (Zipf distribution)?
- How does DynamoDB's partition key + sort key model differ from a simple key-value store?
- What is the difference between strong consistency and linearisability?
- How do vector clocks become impractical at scale (vector clock explosion), and how does DynamoDB solve this?
- How does Redis Cluster's slot-based partitioning differ from consistent hashing?
- How would you implement a key-value store that supports range queries (e.g., "all keys between A and B")?

## Common Mistakes / Pitfalls

- **No virtual nodes in the ring**: without virtual nodes (or with too few), adding one node shifts ~1/N of keys in a big contiguous block. With 150 vnodes per physical node, key migration is spread evenly and the load is balanced across the ring.
- **W + R = N (not > N)**: this does NOT guarantee strong consistency. With N=3, W=1, R=2: a write can go to replica A; if you read from replicas B and C (quorum of 2, but not A), you miss the latest write. You need W + R > N, i.e., at least one overlap.
- **LWW without synchronised clocks**: last-write-wins requires accurate timestamps. In a distributed system, clocks drift. Without NTP + bounded clock skew, a write from a node with a slow clock "loses" to an older value. Use hybrid logical clocks or vector clocks for accurate ordering.
- **No bloom filter on SSTables**: without bloom filters, every GET that misses the MemTable must scan all SSTables on disk — O(n) I/O for each miss. Bloom filters reduce this to near O(1) for most misses.
- **Unbounded TTL cleanup**: entries with TTL need active expiry scanning. Without it, stale entries accumulate indefinitely. Use a background job or lazy expiry (check on GET) + compaction to reclaim space.
- **Not handling coordinator failure during a write**: if the coordinator crashes after writing to W-1 nodes, the write is neither confirmed nor fully failed. Clients must retry; nodes must handle duplicate writes (idempotent PUT using version vectors).

## References

- [Amazon DynamoDB architecture paper (Dynamo)](https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf)
- [Redis Cluster specification](https://redis.io/docs/management/scaling/)
- [LevelDB/RocksDB LSM-tree overview](https://github.com/facebook/rocksdb/wiki/RocksDB-Overview) (verify URL)
- [Consistent hashing — Wikipedia](https://en.wikipedia.org/wiki/Consistent_hashing)
- [See: database-sharding.md](./database-sharding.md) — horizontal partitioning strategies
