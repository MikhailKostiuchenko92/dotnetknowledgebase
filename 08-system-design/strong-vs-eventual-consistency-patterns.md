# Strong vs Eventual Consistency Patterns

**Category:** System Design / Fundamentals
**Difficulty:** 🔴 Senior
**Tags:** `CRDT`, `vector-clocks`, `last-write-wins`, `conflict-resolution`, `consistency`, `distributed-systems`

## Question

> What patterns exist for resolving conflicts in eventually-consistent distributed systems? Compare CRDTs, vector clocks, and last-write-wins. When would you design a system to use strong consistency vs an eventual model with merge logic?

## Short Answer

In eventually-consistent systems, concurrent writes to the same data on different replicas create conflicts that must be resolved. The main strategies are: **Last-Write-Wins (LWW)** — simplest but silently discards data; **vector clocks / version vectors** — track causality to detect concurrent writes and surface them for resolution; and **CRDTs (Conflict-Free Replicated Data Types)** — data structures that always merge safely without coordination. Choose strong consistency when correctness violations from stale data are unacceptable; choose eventual consistency with explicit merge logic when availability and partition tolerance outweigh the complexity cost.

## Detailed Explanation

### The Conflict Problem

In an AP distributed system, two clients can write to the same key on two different replicas during a partition. When the partition heals, the replicas must decide which value "wins" — or merge both. This is the conflict resolution problem.

### Last-Write-Wins (LWW)

Each write is stamped with a timestamp. On merge, the highest timestamp wins; the other write is silently discarded.

**Used by**: Cassandra (default), DynamoDB (with TTL), Redis (no conflict — single primary).

**Pros**: Simple, O(1) metadata, no coordination.

**Cons**:
- Silently discards data — the losing write is gone with no error.
- Wall-clock drift between nodes means the "last" write is non-deterministic. Node A may have a clock 100ms ahead, so its writes always win even if they arrived first.
- Unsuitable for counters, sets, or any data where both writes carry information.

> **Warning:** LWW is deceptively dangerous. In Cassandra, a `DELETE` with a slightly earlier timestamp than a concurrent `INSERT` can result in the deleted row re-appearing after the partition heals — this is the "zombie row" problem.

### Vector Clocks / Version Vectors

A vector clock is a map of `{ nodeId → logicalCounter }`. Each write increments the local counter. On merge, if neither vector clock *dominates* the other (neither is ≥ in all components), the writes are **concurrent** — both values are preserved as "siblings" for application-level resolution.

**Used by**: Amazon Dynamo (original design), Riak, CouchDB.

**Example**:
- Node A writes → clock `{A:1}`, value `"red"`
- Node B writes (without seeing A's write) → clock `{B:1}`, value `"blue"`
- Merge: `{A:1}` and `{B:1}` are concurrent (neither dominates) → both values stored; application must choose

**Pros**: Detects causal relationships accurately; never silently discards data.

**Cons**: Vector clock grows with the number of nodes/clients. "Version explosion" if clients (not just nodes) are tracked — Amazon Dynamo moved away from client-side vector clocks for this reason.

### CRDTs (Conflict-Free Replicated Data Types)

CRDTs are data structures mathematically designed so that any two replicas can always be merged in a deterministic, commutative, associative way — without coordination, without conflict.

**Types**:

| CRDT | Use case | Behaviour |
|------|----------|-----------|
| **G-Counter** | Incrementing counter | Each node owns a slot; total = sum of all slots |
| **PN-Counter** | Increment/decrement counter | Two G-counters: positive + negative |
| **G-Set** | Add-only set | Union is always safe |
| **2P-Set** | Add and remove set | Add-set ∪ minus remove-set |
| **OR-Set** (Observed-Remove) | Add/remove with concurrent safety | Tags each add; remove only removes tagged items |
| **LWW-Register** | Last-write-wins with CRDT framing | Safe when LWW semantics are intended |
| **RGA / Logoot** | Collaborative text editing | Assigns unique positions to characters |

**Used by**: Redis (CRDT module in Redis Enterprise), Riak DT, Azure Cosmos DB (some internal), Figma (collaborative canvas), Google Docs (OT/CRDT hybrid).

**Pros**: Guaranteed convergence, no merge conflicts, operations are always safe.

**Cons**: Limited to CRDT-compatible data shapes; complex to implement custom types; not a drop-in replacement for arbitrary mutable state.

### Choosing Strong vs Eventual + Merge

| Criterion | Choose Strong Consistency | Choose Eventual + Merge |
|-----------|--------------------------|------------------------|
| **Correctness** | Violations are catastrophic (financial, inventory) | Temporary divergence is acceptable |
| **Conflict semantics** | Conflicts must not occur | Conflicts can be merged safely |
| **Write latency** | Acceptable | Must be low |
| **Availability** | Can sacrifice during partition | Must stay up |
| **Data type** | Arbitrary (balances, IDs) | CRDT-compatible (counters, sets, text) |

### .NET Patterns

In .NET, the **Outbox Pattern** with a relational DB gives you strong consistency for the write + at-least-once delivery to downstream services without distributed transactions. [See: outbox-pattern.md](./outbox-pattern.md)

For CRDT-style patterns in C# application logic, model a shopping cart as a `HashSet<CartItem>` with merge-on-conflict:

## Code Example

```csharp
// CRDT-inspired OR-Set for a shopping cart
// Items added on disconnected replicas are merged (union); removes are tagged
// .NET 8 top-level statements

var replicaA = new OrSet<string>();
var replicaB = new OrSet<string>();

// Both replicas add items independently (simulating network partition)
replicaA.Add("apple");
replicaA.Add("banana");
replicaB.Add("banana");   // concurrent add — same item, different unique tag
replicaB.Add("cherry");

// User removes "banana" from replica A
replicaA.Remove("banana");

// Partition heals — merge replica B into A
replicaA.Merge(replicaB);

// "banana" is STILL in the set because replica B added it concurrently
// after A's remove — OR-Set tracks this via unique tags
Console.WriteLine(string.Join(", ", replicaA.Values));  // apple, banana, cherry

// -----------------------------------------------------------------------
// Simple OR-Set implementation (demonstration only — not production grade)
public class OrSet<T> where T : notnull
{
    private readonly Dictionary<T, HashSet<Guid>> _adds = [];
    private readonly Dictionary<T, HashSet<Guid>> _removes = [];

    public void Add(T item)
    {
        if (!_adds.ContainsKey(item)) _adds[item] = [];
        _adds[item].Add(Guid.NewGuid());          // unique tag per add
    }

    public void Remove(T item)
    {
        if (_adds.TryGetValue(item, out var tags))
        {
            if (!_removes.ContainsKey(item)) _removes[item] = [];
            // Only remove the tags we know about NOW — not future adds
            foreach (var tag in tags) _removes[item].Add(tag);
        }
    }

    public void Merge(OrSet<T> other)
    {
        foreach (var (item, tags) in other._adds)
        {
            if (!_adds.ContainsKey(item)) _adds[item] = [];
            foreach (var tag in tags) _adds[item].Add(tag);   // union
        }
        foreach (var (item, tags) in other._removes)
        {
            if (!_removes.ContainsKey(item)) _removes[item] = [];
            foreach (var tag in tags) _removes[item].Add(tag);
        }
    }

    public IEnumerable<T> Values =>
        _adds.Where(kv => kv.Value.Except(_removes.GetValueOrDefault(kv.Key, [])).Any())
             .Select(kv => kv.Key);
}
```

## Common Follow-up Questions

- How does Amazon Dynamo's original design use vector clocks, and why did they later move away from client-side clocks?
- What is the "zombie row" problem in Cassandra, and how do you prevent it?
- How do Google Docs and Figma use CRDTs (or OT) for collaborative editing?
- What are the memory/storage trade-offs of vector clocks vs LWW at scale (millions of keys)?
- How would you implement an idempotent counter in Cassandra that handles concurrent increments correctly?
- When would you choose the Saga pattern over distributed 2PC for strong consistency needs?

## Common Mistakes / Pitfalls

- **Trusting LWW for counters**: incrementing a counter on two replicas and using LWW means one increment is silently lost. Use a CRDT G-Counter or serialise writes through a single node.
- **Unbounded vector clock growth**: tracking one clock entry per *client* (not per *node*) causes vector clocks to grow without bound in consumer-facing systems. Use per-node clocks or bounded version vectors.
- **Assuming CRDTs solve all consistency problems**: CRDTs require operations to be commutative and associative. Arbitrary business logic (e.g., "max 5 items per cart") cannot be expressed as a CRDT without additional coordination.
- **Conflating causal consistency with strong consistency**: causal consistency ensures ordered delivery of causally-related writes, but two independent writes can still be seen in different orders by different observers.
- **Not modelling conflict resolution in domain design**: adding eventual consistency to a system without explicitly designing how conflicts are resolved leads to ad-hoc LWW bugs discovered in production.
- **Ignoring clock skew**: relying on `DateTime.UtcNow` for LWW timestamps assumes clocks are synchronised. Cloud VMs can drift by hundreds of milliseconds. Use logical clocks or hybrid logical clocks (HLC) instead.

## References

- [Martin Kleppmann — Designing Data-Intensive Applications, Chapter 5 (Replication) & Chapter 9](https://dataintensive.net/)
- [A Comprehensive Study of Convergent and Commutative Replicated Data Types (Shapiro et al.)](https://hal.inria.fr/inria-00555588/document)
- [Amazon Dynamo paper — eventual consistency and vector clocks](https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf)
- [CRDT.tech — interactive CRDT explorer](https://crdt.tech/)
- [See: eventual-consistency.md](./eventual-consistency.md) — foundational model this builds on
