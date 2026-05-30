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
- [database-indexing-strategies.md](./database-indexing-strategies.md) — B-tree/hash indexes, composite, covering, selectivity, EF Core Fluent API
- [database-replication.md](./database-replication.md) — Primary-replica, sync vs async replication, lag handling, read routing
- [database-sharding.md](./database-sharding.md) — Horizontal partitioning, shard key selection, consistent hashing, hotspot
- [multi-tenancy-strategies.md](./multi-tenancy-strategies.md) — Per-DB / per-schema / row-level isolation, EF Core global query filters
- [read-write-splitting.md](./read-write-splitting.md) — Replica routing, replication lag pitfalls, CQRS connection
- [sql-vs-nosql.md](./sql-vs-nosql.md) — When to choose relational vs document/key-value/graph, polyglot persistence