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

### §6 Rate Limiting & Throttling
- [circuit-breaker-pattern.md](./circuit-breaker-pattern.md) — Closed/Open/Half-Open states, Polly v8, Microsoft.Extensions.Resilience
- [distributed-rate-limiting.md](./distributed-rate-limiting.md) — Redis Lua scripts, sliding window counter, multi-region challenges
- [rate-limiting-algorithms.md](./rate-limiting-algorithms.md) — Token bucket, leaky bucket, fixed window, sliding window — trade-offs
- [rate-limiting-concepts.md](./rate-limiting-concepts.md) — Per-user vs global limits, HTTP 429, Retry-After header
- [rate-limiting-in-aspnet-core.md](./rate-limiting-in-aspnet-core.md) — .NET 7+ RateLimiter middleware, policies, custom rejection response
- [throttling-vs-backpressure.md](./throttling-vs-backpressure.md) — Cooperative flow control, System.Threading.Channels, TCP analogy

### §7 Classic System Design Problems
- [design-api-gateway.md](./design-api-gateway.md) — YARP routing, auth middleware, rate limiting, circuit breaking, SSL termination
- [design-chat-system.md](./design-chat-system.md) — WebSocket fan-out, Cassandra message storage, read receipts, presence, group chat
- [design-distributed-cache.md](./design-distributed-cache.md) — Consistent hashing ring, quorum N/W/R, LRU/LFU eviction, Redis cluster
- [design-file-storage-service.md](./design-file-storage-service.md) — Chunking, deduplication, presigned S3 URLs, CDN, delta sync
- [design-job-scheduler.md](./design-job-scheduler.md) — Leader election, SELECT SKIP LOCKED claim, heartbeat, DAG dependencies
- [design-key-value-store.md](./design-key-value-store.md) — Consistent hashing, replication, quorum reads/writes, LSM-tree
- [design-news-feed.md](./design-news-feed.md) — Hybrid fan-out (write + read), celebrity problem, Redis timeline, ranking
- [design-notification-system.md](./design-notification-system.md) — Push/email/SMS fan-out, templates, delivery tracking, priority queues
- [design-payment-system.md](./design-payment-system.md) — Idempotency keys, double-entry ledger, gateway timeout handling, PCI DSS
- [design-rate-limiter.md](./design-rate-limiter.md) — Tier-aware token bucket, Redis Lua, fail-open strategy, response headers
- [design-search-autocomplete.md](./design-search-autocomplete.md) — Trie top-K, Redis sorted sets per prefix, ranking decay, CDN edge caching
- [design-url-shortener.md](./design-url-shortener.md) — Base-62 encoding, 301 vs 302, caching, analytics pipeline

### §8 Microservices & Service Architecture
- [distributed-tracing.md](./distributed-tracing.md) — W3C traceparent, OpenTelemetry spans, sampling strategies, log correlation
- [domain-driven-microservices.md](./domain-driven-microservices.md) — Bounded contexts, anti-corruption layer, shared kernel, context map
- [inter-service-communication.md](./inter-service-communication.md) — REST vs gRPC vs messaging, temporal coupling, Polly resilience
- [monolith-vs-microservices.md](./monolith-vs-microservices.md) — When to split, modular monolith, Conway's Law, distributed monolith anti-pattern
- [service-discovery.md](./service-discovery.md) — Client-side vs server-side, Consul, Kubernetes DNS, crash detection, health probes
- [service-mesh-vs-api-gateway.md](./service-mesh-vs-api-gateway.md) — East-west vs north-south, Istio vs Dapr, when a mesh is overkill
- [sidecar-pattern.md](./sidecar-pattern.md) — Envoy, Dapr building blocks, in-process vs sidecar trade-offs
- [strangler-fig-pattern.md](./strangler-fig-pattern.md) — Incremental migration, dual-write, CDC, canary routing, cutover checklist

### §9 Observability & Reliability
- [chaos-engineering.md](./chaos-engineering.md) — Steady-state hypothesis, blast radius, Chaos Mesh, Azure Chaos Studio
- [graceful-degradation-patterns.md](./graceful-degradation-patterns.md) — Stale cache fallback, Polly fallback pipeline, feature flags, shed load
- [health-checks-in-aspnet-core.md](./health-checks-in-aspnet-core.md) — IHealthCheck, liveness/readiness/startup, Kubernetes probe config
- [metrics-and-alerting.md](./metrics-and-alerting.md) — RED/USE, Prometheus histograms, alert rules, SLO burn rate
- [observability-three-pillars.md](./observability-three-pillars.md) — Logs, metrics, traces, OpenTelemetry unified pipeline
- [slos-slas-error-budgets.md](./slos-slas-error-budgets.md) — SLI/SLO/SLA, error budget, multi-window burn rate alerts
- [structured-logging-patterns.md](./structured-logging-patterns.md) — Serilog, correlation IDs, PII scrubbing, log aggregation

### §10 Performance & Scalability Patterns
- [async-io-and-throughput.md](./async-io-and-throughput.md) — Kestrel async I/O, thread pool, I/O completion ports, Pipelines
- [backpressure-patterns.md](./backpressure-patterns.md) — Bounded Channel<T>, drop/block/error strategies, multi-stage pipeline
- [bulkhead-pattern.md](./bulkhead-pattern.md) — Resource isolation, Polly ConcurrencyLimiter, SemaphoreSlim partitioning
- [connection-pooling-at-scale.md](./connection-pooling-at-scale.md) — SocketsHttpHandler, DB pool sizing formula, PgBouncer
- [cqrs-and-read-models.md](./cqrs-and-read-models.md) — Command/query separation, projections, MediatR, eventual consistency
- [denormalization-for-performance.md](./denormalization-for-performance.md) — Materialised views, inline scalars, EF Core computed columns
- [load-balancing-strategies.md](./load-balancing-strategies.md) — Round-robin, least-connections, consistent hashing, L4 vs L7
- [performance-profiling-approach.md](./performance-profiling-approach.md) — dotnet-trace, dotnet-counters, dotnet-dump, BenchmarkDotNet workflow

### §11 Security at Scale
- [authentication-vs-authorization.md](./authentication-vs-authorization.md) — AuthN vs AuthZ, claims-based identity, ASP.NET Core policies
- [jwt-design-considerations.md](./jwt-design-considerations.md) — RS256/ES256, expiry, refresh tokens, revocation, deny-list
- [oauth2-flows-compared.md](./oauth2-flows-compared.md) — Authorization Code + PKCE, Client Credentials, OIDC, scope design
- [secrets-management-at-scale.md](./secrets-management-at-scale.md) — Azure Key Vault, Managed Identity, CSI driver, zero-downtime rotation
- [zero-trust-architecture.md](./zero-trust-architecture.md) — mTLS, workload identity, SPIFFE, Istio AuthorizationPolicy