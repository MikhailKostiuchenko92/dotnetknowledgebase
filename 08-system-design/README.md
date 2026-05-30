# System Design

> High-level design problems (rate limiter, URL shortener, cache, queue).

## Questions

Interview-ready deep-dives into distributed systems design, architecture patterns, and scalability principles.

## Index

### §1 Fundamentals & Core Concepts
- [availability-vs-consistency.md](./availability-vs-consistency.md) — Availability/consistency trade-off, SLAs, and "nines" of uptime
- [cap-theorem.md](./cap-theorem.md) — CAP theorem, CP vs AP systems, partition tolerance
- [distributed-transactions.md](./distributed-transactions.md) — 2PC, Saga (choreography/orchestration), Outbox pattern
- [eventual-consistency.md](./eventual-consistency.md) — Eventual consistency, read-your-writes, monotonic reads, causal consistency
- [fault-tolerance-vs-high-availability.md](./fault-tolerance-vs-high-availability.md) — Graceful degradation, bulkhead, circuit breaker
- [latency-numbers.md](./latency-numbers.md) — Orders-of-magnitude latency reference every engineer should know
- [pacelc-theorem.md](./pacelc-theorem.md) — PACELC: latency vs consistency even without a partition
- [scalability-vs-performance.md](./scalability-vs-performance.md) — Horizontal vs vertical scaling, throughput vs latency
- [single-points-of-failure.md](./single-points-of-failure.md) — Identifying SPOFs, active-active vs active-passive redundancy
- [strong-vs-eventual-consistency-patterns.md](./strong-vs-eventual-consistency-patterns.md) — CRDTs, vector clocks, LWW conflict resolution

### §2 APIs & Communication
- [api-gateway-pattern.md](./api-gateway-pattern.md) — Routing, auth, rate limiting, aggregation, BFF pattern, YARP
- [api-versioning-strategies.md](./api-versioning-strategies.md) — URL/header/query/content-negotiation versioning, deprecation lifecycle
- [graphql-design-tradeoffs.md](./graphql-design-tradeoffs.md) — N+1 problem, DataLoader, schema complexity limits, when NOT to use GraphQL
- [grpc-in-dotnet.md](./grpc-in-dotnet.md) — Protobuf, four streaming modes, deadlines, .NET specifics
- [idempotency-in-apis.md](./idempotency-in-apis.md) — Idempotency keys, at-least-once deduplication, Redis-based middleware
- [pagination-strategies.md](./pagination-strategies.md) — Offset vs cursor/keyset pagination, EF Core implementation
- [rest-api-design-principles.md](./rest-api-design-principles.md) — HTTP verbs, status codes, idempotency, resource-oriented design
- [rest-vs-grpc-vs-graphql.md](./rest-vs-grpc-vs-graphql.md) — Trade-offs: payload, contract, streaming, browser support, .NET tooling
- [webhooks-vs-polling-vs-sse.md](./webhooks-vs-polling-vs-sse.md) — Push vs pull, HMAC signing, SSE with ASP.NET Core

### §3 Data Storage & Databases
- [database-connection-pooling.md](./database-connection-pooling.md) — ADO.NET pool internals, pgBouncer, pool exhaustion, async patterns
- [database-indexing-strategies.md](./database-indexing-strategies.md) — B-tree/hash indexes, composite, covering, selectivity, EF Core Fluent API
- [database-replication.md](./database-replication.md) — Primary-replica, sync vs async replication, lag handling, read routing
- [database-sharding.md](./database-sharding.md) — Horizontal partitioning, shard key selection, consistent hashing, hotspot
- [event-sourcing-vs-crud.md](./event-sourcing-vs-crud.md) — Append-only event log, projections, snapshots, Marten library
- [multi-tenancy-strategies.md](./multi-tenancy-strategies.md) — Per-DB / per-schema / row-level isolation, EF Core global query filters
- [optimistic-vs-pessimistic-locking.md](./optimistic-vs-pessimistic-locking.md) — Row versioning, deadlock avoidance, EF Core concurrency tokens
- [polyglot-persistence.md](./polyglot-persistence.md) — Right DB per access pattern, sync challenges, Outbox + CDC
- [read-write-splitting.md](./read-write-splitting.md) — Replica routing, replication lag pitfalls, CQRS connection
- [sql-vs-nosql.md](./sql-vs-nosql.md) — When to choose relational vs document/key-value/graph, polyglot persistence
- [time-series-databases.md](./time-series-databases.md) — InfluxDB, TimescaleDB, Azure Data Explorer, retention policies

### §4 Caching
- [bloom-filters-for-cache.md](./bloom-filters-for-cache.md) — Probabilistic membership, false-positive rate, cache penetration prevention
- [cache-aside-in-aspnet-core.md](./cache-aside-in-aspnet-core.md) — Production-grade cache-aside: key versioning, stampede lock, HybridCache (.NET 9)
- [cache-eviction-policies.md](./cache-eviction-policies.md) — LRU, LFU, FIFO, ARC/TinyLFU; Redis maxmemory-policy configuration
- [cache-invalidation-problem.md](./cache-invalidation-problem.md) — Why it's hard, TTL jitter, event-driven invalidation, cache stampede
- [caching-strategies-overview.md](./caching-strategies-overview.md) — Cache-aside, read-through, write-through, write-behind in ASP.NET Core
- [cdn-fundamentals.md](./cdn-fundamentals.md) — Edge caching, Cache-Control headers, stale-while-revalidate, purging
- [distributed-cache-vs-local-cache.md](./distributed-cache-vs-local-cache.md) — IMemoryCache vs IDistributedCache, HybridCache (.NET 9)
- [redis-fundamentals.md](./redis-fundamentals.md) — Data structures, RDB/AOF persistence, Cluster, StackExchange.Redis

### §5 Messaging & Event-Driven Architecture
- [at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md) — Delivery guarantees, idempotent consumers, deduplication table pattern
- [dead-letter-queues.md](./dead-letter-queues.md) — Poison messages, retry strategies, DLQ monitoring, replay patterns
- [event-driven-architecture.md](./event-driven-architecture.md) — Domain vs integration events, choreography vs orchestration, MassTransit Saga
- [kafka-vs-rabbitmq.md](./kafka-vs-rabbitmq.md) — Log model vs smart broker, partitions, consumer groups, when to use each
- [message-broker-overview.md](./message-broker-overview.md) — Queues, pub/sub, ACK, DLQ fundamentals; RabbitMQ, Kafka, Azure Service Bus
- [outbox-pattern.md](./outbox-pattern.md) — Transactional outbox, polling vs CDC relay, EF Core + MassTransit implementation
- [pub-sub-vs-message-queue.md](./pub-sub-vs-message-queue.md) — Point-to-point vs fan-out, RabbitMQ exchange types, Azure Service Bus topics