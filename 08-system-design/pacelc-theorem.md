# PACELC Theorem

**Category:** System Design / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `PACELC`, `CAP`, `latency`, `consistency`, `partition-tolerance`, `distributed-systems`

## Question

> What is the PACELC theorem, and how does it extend the CAP theorem? Why is latency an important dimension that CAP ignores?

## Short Answer

PACELC (Partition/Availability/Consistency and Else/Latency/Consistency) extends CAP by recognising that even when no partition exists, distributed systems face a trade-off between **latency** and **consistency**. CAP only covers behaviour during a partition; PACELC covers the common case (no partition) as well. For example, a strongly-consistent system pays a latency penalty even during normal operation because writes must be synchronously replicated to a quorum.

## Detailed Explanation

### Why CAP Is Incomplete

The CAP theorem answers: *"During a network partition, do you choose consistency or availability?"* But partitions are rare events. 99.9% of the time, distributed systems operate without partitions — and yet they still face a fundamental trade-off that CAP ignores: **how long should a write take?**

If every write must be acknowledged by all N replicas before returning, the write latency is bounded by the slowest replica. If writes return after acknowledging just one replica, latency is low but reads on other replicas may return stale data.

### The PACELC Framework

Proposed by Daniel Abadi (2012):

```
If there is a Partition:
  choose between Availability and Consistency
Else (normal operation):
  choose between Latency and Consistency
```

Written as a label: `PA/EL` = "Availability during partition, Latency during normal operation"

| Label | Partition choice | Normal operation choice |
|-------|-----------------|------------------------|
| **PA/EL** | Availability | Low Latency | DynamoDB (default), Cassandra (default) |
| **PC/EC** | Consistency | Consistency | VoltDB, HBase, Google Spanner |
| **PA/EC** | Availability | Consistency | MongoDB (default) |
| **PC/EL** | Consistency | Latency | (rare; usually latency optimised CP systems) |

> **Note:** These labels simplify real systems. Cassandra can be tuned toward PC/EC with `QUORUM` read/write consistency. The label describes the *default* or *typical* configuration.

### Latency vs Consistency in Normal Operation

Consider a 3-node cluster with synchronous replication:

- **Strong/linearisable**: Write must be committed on all 3 nodes before ACK. If node 3 is in a different region (50ms RTT), every write takes ≥50ms. Reads always return the latest data.
- **Eventual**: Write committed on 1 node, replicated asynchronously. Write returns in <1ms. Reads may return data up to 50ms stale.

The choice affects user experience constantly — not just during failures. This is the gap PACELC fills.

### Real Database Examples

| Database | PACELC Label | Notes |
|----------|-------------|-------|
| **DynamoDB** | PA/EL | Default: eventual reads, low latency |
| **Cassandra** | PA/EL | Tunable; default ONE consistency = low latency |
| **MongoDB** | PA/EC | Primary reads are consistent; secondaries are stale |
| **Cosmos DB** | Depends on level | Session = PA/EC-ish; Strong = PC/EC |
| **Google Spanner** | PC/EC | TrueTime gives external consistency at ~10ms write latency |
| **etcd / ZooKeeper** | PC/EC | Raft consensus, CP, consistent and slower |
| **Redis (standalone)** | PA/EL | Single node: no partition; primary-replica: AP |

### Trade-off Illustration

For a global e-commerce site:

- **Product catalog** (read-heavy, stale OK): PA/EL — DynamoDB Eventual Reads, CDN-cached. Low latency globally.
- **Inventory reservation** (correctness critical): PC/EC — strong consistency quorum, accept latency, prevent overselling.
- **User cart** (session-scoped): PA/EC — session consistency (Cosmos DB Session level): your writes always visible to you, low latency.

### .NET Relevance

In ASP.NET Core systems:
- `IMemoryCache` is purely local — no consistency across replicas (PA/EL extreme).
- `IDistributedCache` with Redis: replication lag exists; can read stale data on replica (PA/EL).
- EF Core + SQL Server with synchronous Always On: writes go to primary, reads from primary = PC/EC.
- EF Core + read replicas (async): reads from replica may be stale = PA/EL for reads.

## Code Example

```csharp
// Illustrating PACELC trade-off with DynamoDB vs consistent read
// AWS SDK for .NET (.NET 8) — showing eventual vs strongly consistent read

using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;

var client = new AmazonDynamoDBClient();

// PA/EL: Eventual consistent read — low latency, may return stale data
// Default for DynamoDB — good for product catalog, leaderboards
var eventualRead = await client.GetItemAsync(new GetItemRequest
{
    TableName = "Products",
    Key = new Dictionary<string, AttributeValue>
    {
        ["ProductId"] = new AttributeValue { S = "prod-42" }
    },
    ConsistentRead = false   // PA/EL — reads from any replica
});

// PC/EC: Strongly consistent read — higher latency, always latest value
// Required for inventory or balance checks
var strongRead = await client.GetItemAsync(new GetItemRequest
{
    TableName = "Products",
    Key = new Dictionary<string, AttributeValue>
    {
        ["ProductId"] = new AttributeValue { S = "prod-42" }
    },
    ConsistentRead = true    // PC/EC — routes to primary, ~2× latency, 2× cost
});

Console.WriteLine($"Stock (eventual): {eventualRead.Item["StockCount"].N}");
Console.WriteLine($"Stock (strong):   {strongRead.Item["StockCount"].N}");
```

## Common Follow-up Questions

- How do you decide between PA/EL and PC/EC for a specific data entity in your system?
- What consistency level does Cassandra `QUORUM` map to in PACELC terms?
- How does Google Spanner achieve PC/EC globally while keeping latency reasonable?
- What is "session consistency" and how does it differ from strong consistency?
- How does PACELC apply when choosing between `IMemoryCache` and Redis?
- How do replication lag and read replicas fit into the PACELC model?

## Common Mistakes / Pitfalls

- **Thinking PACELC replaces CAP**: PACELC *extends* CAP — the partition behaviour half (PA or PC) is identical to CAP's CA choice. PACELC adds the "E" (else) dimension for normal operation.
- **Ignoring the E-side trade-off**: Many engineers focus entirely on partition tolerance and forget that the synchronous replication tax is paid on every write in normal operation, not just during failures.
- **Labelling databases statically**: Cassandra with `ConsistencyLevel.ALL` is PC/EC; with `ConsistencyLevel.ONE` it's PA/EL. The PACELC label depends on configuration.
- **Confusing "low latency" with "eventual consistency"**: a write that returns after local commit is low-latency AND could be immediately consistent if only one node exists. The latency penalty comes from *cross-node synchronisation*, not eventual consistency per se.
- **Selecting PC/EC globally when only some entities require it**: applying strong consistency to every read/write when only financial data requires it imposes unnecessary latency cost across the whole system.

## References

- [Abadi, D. (2012) — Consistency Tradeoffs in Modern Distributed Database System Design](https://www.vldb.org/pvldb/vol5/p1970_danabadi_vldb2012.pdf) (verify URL)
- [Martin Kleppmann — PACELC and the perils of over-simplification](https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html)
- [Azure Cosmos DB consistency levels](https://learn.microsoft.com/azure/cosmos-db/consistency-levels)
- [Amazon DynamoDB consistent reads](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html)
- [See: cap-theorem.md](./cap-theorem.md) — foundation for understanding PACELC
