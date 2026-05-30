# CAP Theorem

**Category:** System Design / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `CAP`, `consistency`, `availability`, `partition-tolerance`, `distributed-systems`, `CP`, `AP`

## Question

> Explain the CAP theorem. What does it mean for a distributed system to be CP vs AP? Can you give real-world examples of each? What are the practical limitations of the theorem?

## Short Answer

The CAP theorem states that a distributed system can guarantee at most two of three properties: **Consistency** (every read sees the latest write), **Availability** (every request receives a response), and **Partition Tolerance** (the system continues operating despite network partitions). Since network partitions are unavoidable in practice, the real choice is between CP (sacrifice availability during a partition) and AP (sacrifice consistency during a partition). Most modern databases are not purely one or the other — they offer tunable trade-offs.

## Detailed Explanation

### The Three Properties

| Property | Definition |
|----------|------------|
| **Consistency (C)** | Every read returns the most recent write or an error — no stale reads |
| **Availability (A)** | Every request receives a non-error response (not necessarily the latest data) |
| **Partition Tolerance (P)** | The system continues to operate when network messages between nodes are lost or delayed |

### Why P Is Not Optional

A network partition (two nodes can't communicate) is not a hypothetical — it happens in every large deployment due to:
- Network switch failures
- Cloud availability zone outages
- NIC flaps, packet drops
- Datacenter-to-datacenter link degradation

Since partitions will occur, the design choice is: **when a partition happens, do we sacrifice C or A?**

> **Clarification:** The "CA" quadrant (consistency + availability, no partition tolerance) describes a single-node system. The moment you have two nodes connected over a network, you must tolerate partitions — you are a distributed system.

### CP Systems

During a partition, a CP system **refuses to serve requests** (or serves errors) rather than risk returning stale data.

**Examples:**
- **HBase, Zookeeper, etcd, Consul**: consensus-based; writes require quorum, reads can return errors if quorum unavailable.
- **SQL Server Always On (synchronous replicas)**: a secondary won't serve reads if it's behind the primary.
- **Google Spanner** (technically CP with external consistency through TrueTime).

**When to choose CP**: financial systems, inventory management, distributed locking, configuration stores — anywhere a stale read causes a correctness violation.

### AP Systems

During a partition, an AP system **continues to serve requests** on each side of the partition, accepting that different nodes may diverge.

**Examples:**
- **Cassandra, DynamoDB, CouchDB**: writes always succeed on a reachable node; conflicts resolved on merge.
- **DNS**: serves cached entries even if authoritative server is unreachable.
- **Redis Cluster** (with `cluster-allow-reads-when-down yes`).

**When to choose AP**: social feeds, view counters, shopping cart state, recommendation engines — where availability matters more than absolute accuracy.

### Limitations of the CAP Theorem

The original theorem (Brewer 2000, proven by Gilbert & Lynch 2002) is a useful mental model but oversimplified for real systems:

1. **Binary thinking**: Real systems offer a **spectrum** — Cosmos DB has 5 tunable consistency levels from Strong to Eventual.
2. **Ignores latency**: The PACELC theorem extends CAP by noting that even *without* a partition, there's a latency/consistency trade-off. [See: pacelc-theorem.md](./pacelc-theorem.md)
3. **Consistency definition is strict**: CAP "consistency" = linearisability, the strongest model. Most systems don't need linearisability; they need weaker guarantees like session consistency or monotonic reads. [See: eventual-consistency.md](./eventual-consistency.md)
4. **Availability definition is strict**: CAP "availability" = every request answered, every time. In practice, "five nines" is sufficient. [See: availability-vs-consistency.md](./availability-vs-consistency.md)

### Quorum and Tunable Consistency

Most modern distributed databases implement **quorum reads/writes** to allow tuning the CP/AP trade-off dynamically:

Given `N` replicas, `W` write acknowledgements required, `R` read acknowledgements required:

- Strong consistency: `R + W > N` (e.g., N=3, W=2, R=2)
- High availability: `W=1, R=1` (writes/reads to any one replica)

Cassandra and DynamoDB expose W and R per operation. Cosmos DB exposes named consistency levels that map to quorum settings internally.

## Code Example

```csharp
// Demonstrating CP vs AP trade-off using Azure Cosmos DB consistency levels
// The same physical data, different consistency guarantees per request
// .NET 8 — Microsoft.Azure.Cosmos

using Microsoft.Azure.Cosmos;

CosmosClient client = new(
    accountEndpoint: Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")!,
    authKeyOrResourceToken: Environment.GetEnvironmentVariable("COSMOS_KEY")!);

Container container = client.GetContainer("ShopDb", "Inventory");

// CP approach: Strong consistency — linearisable, never stale
// Use for: inventory reservation, payment processing
async Task<int> GetStockStrong(string productId)
{
    var response = await container.ReadItemAsync<Product>(
        id: productId,
        partitionKey: new PartitionKey(productId),
        requestOptions: new ItemRequestOptions
        {
            // Reads from quorum — will fail if quorum unavailable (CP behaviour)
            ConsistencyLevel = ConsistencyLevel.Strong
        });

    return response.Resource.StockCount;
}

// AP approach: Eventual consistency — may return stale data but always responds
// Use for: product listing page, "in stock" indicator (non-binding)
async Task<int> GetStockEventual(string productId)
{
    var response = await container.ReadItemAsync<Product>(
        id: productId,
        partitionKey: new PartitionKey(productId),
        requestOptions: new ItemRequestOptions
        {
            // Reads from nearest replica — always responds, potentially stale (AP behaviour)
            ConsistencyLevel = ConsistencyLevel.Eventual
        });

    return response.Resource.StockCount;
}

record Product(string Id, string Name, int StockCount);
```

## Common Follow-up Questions

- How does PACELC extend the CAP theorem? [See: pacelc-theorem.md](./pacelc-theorem.md)
- What consistency model does Cosmos DB / DynamoDB / Cassandra default to?
- How do you choose a consistency level when designing a checkout system?
- What is linearisability, and why is it stronger than serializability?
- How does quorum work in distributed databases? What is `R + W > N`?
- How does the CAP theorem apply to microservices that communicate over HTTP?

## Common Mistakes / Pitfalls

- **"CA is a valid option"**: In a distributed system, network partitions will happen — CA means single-node or ignoring partitions, which is not a real choice.
- **Treating CAP as a static label**: Good systems (Cassandra, Cosmos DB) are neither purely CP nor AP — they let you tune per operation. Saying "Cassandra is AP" is an oversimplification.
- **Confusing CAP consistency with ACID consistency**: CAP "C" = linearisability (every read sees the latest write across all nodes). ACID "C" = transaction maintains application-level invariants. They are orthogonal.
- **Ignoring the latency dimension**: A system can be CP with a 50ms write penalty or a 5000ms write penalty during normal operation — CAP says nothing about this. PACELC does.
- **Assuming strong consistency is always safer**: Strong consistency requires quorum; if a quorum can't be reached, the system rejects requests — lower availability, not "safer" in all scenarios.
- **Not testing partition behaviour**: systems should be tested with simulated partitions (chaos engineering) to verify they behave as designed during a real partition.

## References

- [CAP Theorem — Brewer's conjecture and the feasibility of consistent, available, partition-tolerant web services (Gilbert & Lynch)](https://dl.acm.org/doi/10.1145/564585.564601)
- [Azure Cosmos DB consistency levels explained](https://learn.microsoft.com/azure/cosmos-db/consistency-levels)
- [Cassandra tunable consistency documentation](https://cassandra.apache.org/doc/latest/cassandra/architecture/dynamo.html) (verify URL)
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 9
- [Please stop calling databases CP or AP (Kyle Kingsbury)](https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html)
