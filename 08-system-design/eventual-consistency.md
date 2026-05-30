# Eventual Consistency

**Category:** System Design / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `eventual-consistency`, `consistency-models`, `read-your-writes`, `monotonic-reads`, `causal-consistency`, `distributed-systems`

## Question

> What is eventual consistency? What are the different weak consistency models (read-your-writes, monotonic reads, causal consistency)? When is eventual consistency safe to use, and when is it dangerous?

## Short Answer

Eventual consistency guarantees that, if no new writes occur, all replicas will eventually converge to the same value — but reads during the convergence window may return stale data. It enables high availability and low write latency at the cost of temporary divergence. Stronger weak models like "read-your-writes" and "causal consistency" add specific guarantees on top of eventual consistency without requiring full linearisability.

## Detailed Explanation

### What Eventual Consistency Means

In a distributed system with replicated data:

1. A write lands on one replica (or a subset).
2. The system propagates the write to other replicas asynchronously.
3. During propagation, other replicas still serve the old value.
4. Eventually (milliseconds to seconds later), all replicas converge.

The key word is *eventually* — there is no upper bound specified unless the system provides bounded staleness guarantees (e.g., Cosmos DB Bounded Staleness level).

### Consistency Models Spectrum

From strongest to weakest:

| Model | Guarantee |
|-------|-----------|
| **Linearisability** (strong) | Every operation appears instantaneous; all observers agree on order |
| **Sequential consistency** | All processes see operations in the same order (not necessarily real-time) |
| **Causal consistency** | Causally related operations are seen in order; concurrent ops may differ |
| **Read-your-writes** | You always see your own writes immediately |
| **Monotonic reads** | If you read value V, you never read an older version afterward |
| **Monotonic writes** | Your writes are applied in the order you issued them |
| **Eventual consistency** | No guarantees during convergence; all nodes eventually agree |

Most production systems target something in the middle — not full linearisability, not pure eventual.

### Read-Your-Writes (Session Consistency)

After writing a value, subsequent reads by the **same client** always return that value or a newer one.

**Example**: You update your profile picture. Refreshing your own profile page must show the new picture immediately — you shouldn't see the old one. Other users' feeds may lag.

**Implementation**: Route the client to the primary for reads, or attach a session token that encodes the write's LSN (Log Sequence Number) so a replica won't serve a read until it has caught up past that LSN.

Cosmos DB **Session** consistency level implements read-your-writes via a *session token* passed between requests. [See: cap-theorem.md](./cap-theorem.md)

### Monotonic Reads

If a read returns value V, all subsequent reads by the same client return V or a newer value.

**Without monotonic reads**: Reads routed to different replicas could return: value V3, then V1, then V2 — going backwards in time. This is disorienting to users.

**Example**: A news feed that occasionally shows an article as "deleted" and then shows it again because the CDN edge picked different origin servers.

**Implementation**: Session affinity to a specific replica, or a minimum version requirement per client.

### Causal Consistency

Operations that are causally related (A happens-before B) are seen in that order by all observers. Concurrent operations (neither caused the other) may be seen in different orders by different observers.

**Example**: A comment reply causally depends on the original comment. Causal consistency ensures you never see the reply before the original comment.

**Vector clocks** and **Lamport timestamps** track causal relationships. MongoDB's multi-document transactions and Cosmos DB's Consistent Prefix level provide causal-like guarantees.

### When Eventual Consistency Is Safe

✅ Data where staleness is imperceptible or irrelevant:
- View/like counts on social media posts
- Product recommendation carousels
- Leaderboards and aggregate statistics
- DNS records (propagation delay is well-understood and accepted)
- Shopping cart add (conflict resolution: merge both items)

### When Eventual Consistency Is Dangerous

❌ Data where staleness causes correctness violations:
- **Inventory**: Two buyers both read "1 item left" from different replicas → double-sell
- **Bank balances**: Transfer and balance read on different replicas → negative balance
- **Distributed locks**: Both nodes think they hold the lock → split-brain
- **Authentication tokens**: Revoked token still accepted by replica that hasn't received the revocation
- **Unique constraints**: Two users register the same username on different shards

### Conflict Resolution in AP Systems

When two replicas both accept writes for the same key during a partition, they must resolve conflicts on merge:

| Strategy | How it works | Risk |
|----------|-------------|------|
| **Last-Write-Wins (LWW)** | Highest timestamp wins | Silently discards data |
| **CRDT** (Conflict-Free Replicated Data Type) | Data structure designed to merge safely (e.g., counters, sets) | Limited to specific data types |
| **Application-level merge** | App receives both versions and resolves | Complex, requires app logic |
| **Versioned merge** | Store all versions (siblings), let user/app choose | UX complexity |

DynamoDB and Cassandra default to LWW. CouchDB stores all conflicting versions as siblings. [See: strong-vs-eventual-consistency-patterns.md](./strong-vs-eventual-consistency-patterns.md)

### .NET / ASP.NET Core Context

In a typical ASP.NET Core + Redis setup:
- Writes go to the Redis primary.
- Reads may be served by replicas with replication lag.
- Using `IDistributedCache.SetAsync` then `GetAsync` from a different node can return null or stale data.

For session-level consistency with Redis, pin reads for a user to the same replica using consistent hashing on the user ID, or always read from primary for critical paths.

## Code Example

```csharp
// Demonstrating read-your-writes pattern with Cosmos DB session tokens
// .NET 8 — Microsoft.Azure.Cosmos

using Microsoft.Azure.Cosmos;

CosmosClient client = new(
    accountEndpoint: Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")!,
    authKeyOrResourceToken: Environment.GetEnvironmentVariable("COSMOS_KEY")!,
    new CosmosClientOptions { ConsistencyLevel = ConsistencyLevel.Session });

Container container = client.GetContainer("SocialDb", "Posts");

// 1. Write a post — capture the session token from the response
var post = new Post("post-1", "user-42", "My new post!", DateTimeOffset.UtcNow);
ItemResponse<Post> writeResponse = await container.UpsertItemAsync(
    post,
    partitionKey: new PartitionKey(post.UserId));

string sessionToken = writeResponse.Headers.Session;  // e.g., "0:1234#5678"
Console.WriteLine($"Write session token: {sessionToken}");

// 2. Pass the session token on subsequent reads — guarantees read-your-writes
// Even if routed to a different replica, it won't respond until it catches up
ItemResponse<Post> readResponse = await container.ReadItemAsync<Post>(
    id: "post-1",
    partitionKey: new PartitionKey("user-42"),
    requestOptions: new ItemRequestOptions
    {
        // This token ensures the read reflects at least the write above
        SessionToken = sessionToken
    });

Console.WriteLine($"Read post: {readResponse.Resource.Content}");  // always shows new post

// 3. Eventual read (no session token) — may return stale data from another replica
ItemResponse<Post> eventualRead = await container.ReadItemAsync<Post>(
    id: "post-1",
    partitionKey: new PartitionKey("user-42"),
    requestOptions: new ItemRequestOptions
    {
        ConsistencyLevel = ConsistencyLevel.Eventual   // fastest, no session guarantee
    });

record Post(string Id, string UserId, string Content, DateTimeOffset CreatedAt);
```

## Common Follow-up Questions

- How does Cosmos DB implement session consistency under the hood using session tokens?
- What is the difference between causal consistency and sequential consistency?
- How would you design a "like count" feature that uses eventual consistency safely?
- What happens in a shopping cart when two conflicting writes arrive during a partition? How would you resolve it?
- How do CRDTs work, and what kinds of data are they suited for?
- How does monotonic reads differ from read-your-writes?

## Common Mistakes / Pitfalls

- **Treating "eventual consistency" as a single model**: There is a rich spectrum between linearisability and eventual consistency. Choosing "eventual" without specifying *which* weaker model means missing important guarantees like read-your-writes.
- **Using eventual consistency for uniqueness checks**: Checking "is this username taken?" on an eventually consistent store can return false on two replicas simultaneously, creating duplicates.
- **Ignoring the convergence window**: "Eventually" in DynamoDB default reads is typically <1 second in normal operation, but can be seconds or longer during region failover. Systems must handle the worst case.
- **Assuming session consistency equals strong consistency**: Session consistency only guarantees read-your-writes for the *same client session*. A second session (different tab, different user) may still read stale data.
- **Last-Write-Wins silently discarding data**: In LWW conflict resolution, the losing write is dropped with no error or notification. In financial or audit contexts, this is a data loss bug, not a merge.
- **Not testing eventual consistency behaviour in integration tests**: Most tests run against a single in-process or local database instance where replication lag doesn't exist — the eventual consistency bugs only appear in production.

## References

- [Azure Cosmos DB consistency levels — Session consistency](https://learn.microsoft.com/azure/cosmos-db/consistency-levels#session-consistency)
- [Werner Vogels — Eventually Consistent (ACM Queue, 2008)](https://dl.acm.org/doi/10.1145/1435417.1435432)
- [Martin Kleppmann — Designing Data-Intensive Applications, Chapter 9](https://dataintensive.net/)
- [CRDTs explained — Conflict-Free Replicated Data Types](https://crdt.tech/)
- [See: cap-theorem.md](./cap-theorem.md) — the foundation for understanding why eventual consistency exists
