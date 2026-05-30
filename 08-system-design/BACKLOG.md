# 📋 System Design — Question Backlog

Master list of planned questions for the `08-system-design` section.
Use this file as the single source of truth for what to add next.

## How to use with Claude Code

- **Add one:** _"add a system design question on `rate-limiter` from BACKLOG.md"_
- **Add a group:** _"add all questions from the 'Caching' group in BACKLOG.md"_
- **Continue:** _"pick the next 5 unwritten questions from BACKLOG.md and create them"_
- **Status check:** _"compare BACKLOG.md against existing files in `08-system-design/` and tell me what's missing"_

When a question is created, mark it `[x]` and add a link to the file.

## Conventions

- **Filename:** kebab-case, exactly as listed below.
- **Difficulty:** 🟢 Junior • 🟡 Middle • 🔴 Senior
- **Template:** `_templates/question-template.md`
- **Commit:** `feat(system-design): add question on <topic>`

---

## Progress

**Total:** 114 / 120
**By difficulty:** 🟢 13/24 · 🟡 55/54 · 🔴 46/42

---

## 1. Fundamentals & Core Concepts

- [x] 🟢 [`scalability-vs-performance.md`](./scalability-vs-performance.md) — Horizontal vs vertical scaling, throughput vs latency, when each matters
- [x] 🟢 [`availability-vs-consistency.md`](./availability-vs-consistency.md) — The availability/consistency trade-off, SLAs, "nines" of availability (99.9% etc.)
- [x] 🟡 [`cap-theorem.md`](./cap-theorem.md) — CAP theorem, CP vs AP systems, network partition tolerance, practical examples
- [x] 🟡 [`pacelc-theorem.md`](./pacelc-theorem.md) — Extension of CAP: latency vs consistency trade-off even without partition
- [x] 🟡 [`eventual-consistency.md`](./eventual-consistency.md) — What it means, read-your-writes, monotonic reads, causal consistency
- [x] 🔴 [`strong-vs-eventual-consistency-patterns.md`](./strong-vs-eventual-consistency-patterns.md) — CRDT, vector clocks, last-write-wins, conflict resolution
- [x] 🟡 [`latency-numbers.md`](./latency-numbers.md) — L1/L2 cache, RAM, SSD, network round trips — orders of magnitude every engineer should know
- [x] 🟢 [`single-points-of-failure.md`](./single-points-of-failure.md) — Identifying SPOFs, redundancy strategies, active-active vs active-passive
- [x] 🟡 [`fault-tolerance-vs-high-availability.md`](./fault-tolerance-vs-high-availability.md) — Graceful degradation, bulkhead pattern, circuit breaker
- [x] 🔴 [`distributed-transactions.md`](./distributed-transactions.md) — 2PC, saga pattern (choreography vs orchestration), outbox pattern

## 2. APIs & Communication

- [x] 🟢 [`rest-api-design-principles.md`](./rest-api-design-principles.md) — Resources, HTTP verbs, status codes, idempotency, versioning strategies
- [x] 🟡 [`rest-vs-grpc-vs-graphql.md`](./rest-vs-grpc-vs-graphql.md) — Trade-offs: payload size, contract, streaming, browser support, .NET tooling
- [x] 🟡 [`api-versioning-strategies.md`](./api-versioning-strategies.md) — URL path, header, query param, content negotiation; deprecation lifecycle
- [x] 🟡 [`api-gateway-pattern.md`](./api-gateway-pattern.md) — Routing, auth, rate limiting, aggregation, BFF (Backend-for-Frontend)
- [x] 🟡 [`grpc-in-dotnet.md`](./grpc-in-dotnet.md) — Protobuf, streaming modes (unary/server/client/bidirectional), deadlines, .NET specifics
- [x] 🔴 [`graphql-design-tradeoffs.md`](./graphql-design-tradeoffs.md) — N+1 problem, DataLoader, schema stitching, persisted queries, when NOT to use
- [x] 🟡 [`webhooks-vs-polling-vs-sse.md`](./webhooks-vs-polling-vs-sse.md) — Push vs pull, reliability guarantees, event delivery, retry logic
- [x] 🔴 [`idempotency-in-apis.md`](./idempotency-in-apis.md) — Idempotency keys, at-least-once delivery, deduplication patterns
- [x] 🟡 [`pagination-strategies.md`](./pagination-strategies.md) — Offset vs cursor-based, keyset pagination, pros/cons, large dataset behaviour

## 3. Data Storage & Databases

- [x] 🟢 [`sql-vs-nosql.md`](./sql-vs-nosql.md) — When to choose relational vs document/key-value/graph/columnar, trade-offs
- [x] 🟡 [`database-indexing-strategies.md`](./database-indexing-strategies.md) — B-tree vs hash indexes, composite indexes, covering indexes, selectivity
- [x] 🟡 [`database-sharding.md`](./database-sharding.md) — Horizontal partitioning, shard keys, hotspot problem, consistent hashing
- [x] 🟡 [`database-replication.md`](./database-replication.md) — Primary-replica, synchronous vs asynchronous, read replicas, lag handling
- [x] 🔴 [`read-write-splitting.md`](./read-write-splitting.md) — Routing reads to replicas, replication lag consistency issues, CQRS connection
- [x] 🔴 [`multi-tenancy-strategies.md`](./multi-tenancy-strategies.md) — Schema-per-tenant, row-level isolation, separate databases, EF Core implications
- [x] 🟡 [`time-series-databases.md`](./time-series-databases.md) — When to use (InfluxDB, TimescaleDB, Azure Data Explorer), retention policies
- [x] 🟡 [`polyglot-persistence.md`](./polyglot-persistence.md) — Using the right DB per access pattern, data synchronization challenges
- [x] 🔴 [`database-connection-pooling.md`](./database-connection-pooling.md) — Pool size tuning, connection leaks, async vs sync, pgBouncer, ADO.NET pools
- [x] 🟡 [`optimistic-vs-pessimistic-locking.md`](./optimistic-vs-pessimistic-locking.md) — Use cases, row versioning, deadlock avoidance, EF Core concurrency tokens
- [x] 🔴 [`event-sourcing-vs-crud.md`](./event-sourcing-vs-crud.md) — Append-only log, replaying events, projections, snapshot pattern, trade-offs

## 4. Caching

- [x] 🟢 [`caching-strategies-overview.md`](./caching-strategies-overview.md) — Cache-aside, read-through, write-through, write-behind, when to use each
- [x] 🟡 [`cache-invalidation-problem.md`](./cache-invalidation-problem.md) — Why it's hard, TTL strategy, event-driven invalidation, cache stampede
- [x] 🟡 [`redis-fundamentals.md`](./redis-fundamentals.md) — Data structures (string, hash, sorted set, list), persistence (RDB/AOF), clustering
- [x] 🟡 [`distributed-cache-vs-local-cache.md`](./distributed-cache-vs-local-cache.md) — IMemoryCache vs IDistributedCache, consistency issues, latency
- [x] 🔴 [`cache-eviction-policies.md`](./cache-eviction-policies.md) — LRU, LFU, FIFO, ARC — when each is appropriate, Redis policy configuration
- [x] 🟡 [`cdn-fundamentals.md`](./cdn-fundamentals.md) — Edge caching, cache-control headers, stale-while-revalidate, purging strategies
- [x] 🔴 [`cache-aside-in-aspnet-core.md`](./cache-aside-in-aspnet-core.md) — IDistributedCache implementation, Redis provider, serialization, stampede prevention
- [x] 🔴 [`bloom-filters-for-cache.md`](./bloom-filters-for-cache.md) — Probabilistic membership, false positive rate, use case (avoid DB lookup for non-existent keys)

## 5. Messaging & Event-Driven Architecture

- [x] 🟢 [`message-broker-overview.md`](./message-broker-overview.md) — Broker concepts: queues, pub/sub, ACK, DLQ, MassTransit, RabbitMQ, Azure Service Bus
- [x] 🟡 [`pub-sub-vs-message-queue.md`](./pub-sub-vs-message-queue.md) — Point-to-point vs fan-out, competing consumers, Azure Service Bus vs Event Grid
- [x] 🟡 [`at-least-once-vs-exactly-once.md`](./at-least-once-vs-exactly-once.md) — Delivery guarantees, idempotent consumers, de-duplication
- [x] 🟡 [`kafka-vs-rabbitmq.md`](./kafka-vs-rabbitmq.md) — Kafka log model vs RabbitMQ exchanges; partitions, consumer groups, when to use each
- [x] 🟡 [`kafka-fundamentals.md`](./kafka-fundamentals.md) — Partitions, consumer groups, offsets, retention, log compaction, ordering guarantees
- [x] 🟡 [`azure-service-bus-patterns.md`](./azure-service-bus-patterns.md) — Queues vs topics, sessions, dead-letter queue, message lock, scheduled messages
- [x] 🔴 [`outbox-pattern.md`](./outbox-pattern.md) — Transactional outbox, polling vs CDC, at-least-once delivery guarantee, EF Core implementation
- [x] 🔴 [`saga-pattern.md`](./saga-pattern.md) — Choreography vs orchestration, compensating transactions, failure handling, MassTransit/.NET
- [x] 🔴 [`event-driven-architecture.md`](./event-driven-architecture.md) — Domain vs integration events, choreography vs orchestration, when EDA hurts
- [x] 🔴 [`ordering-in-distributed-systems.md`](./ordering-in-distributed-systems.md) — Sequence numbers, Lamport clocks, Kafka partition ordering, why global order is expensive
- [x] 🟡 [`dead-letter-queues.md`](./dead-letter-queues.md) — Poison messages, retry strategies, monitoring, alerting, requeue patterns

## 6. Rate Limiting & Throttling

- [x] 🟢 [`rate-limiting-concepts.md`](./rate-limiting-concepts.md) — Why rate limiting, per-user vs global, response codes (429), headers (`Retry-After`)
- [x] 🟡 [`rate-limiting-algorithms.md`](./rate-limiting-algorithms.md) — Token bucket, leaky bucket, fixed window, sliding window — trade-offs
- [x] 🟡 [`rate-limiting-in-aspnet-core.md`](./rate-limiting-in-aspnet-core.md) — .NET 7+ `RateLimiter` middleware, `FixedWindowLimiter`, `SlidingWindowLimiter`, `TokenBucketLimiter`
- [x] 🔴 [`distributed-rate-limiting.md`](./distributed-rate-limiting.md) — Redis-backed counters, Lua scripts for atomicity, key design, multi-region challenges
- [x] 🟡 [`circuit-breaker-pattern.md`](./circuit-breaker-pattern.md) — States (closed/open/half-open), Polly implementation, integration with rate limiting
- [x] 🔴 [`throttling-vs-backpressure.md`](./throttling-vs-backpressure.md) — Client-side vs server-side control, reactive streams, TCP congestion analogy

## 7. Classic System Design Problems

- [x] 🟡 [`design-url-shortener.md`](./design-url-shortener.md) — Hash generation, collision handling, redirects, analytics, expiry
- [x] 🟡 [`design-rate-limiter.md`](./design-rate-limiter.md) — Full end-to-end design: storage, algorithm, distributed counters, API design
- [x] 🟡 [`design-notification-system.md`](./design-notification-system.md) — Push/email/SMS fanout, template management, delivery tracking, scale
- [x] 🟡 [`design-key-value-store.md`](./design-key-value-store.md) — In-memory + persistence, consistent hashing, replication, GET/PUT/DELETE
- [x] 🔴 [`design-distributed-cache.md`](./design-distributed-cache.md) — Cache cluster, consistent hashing ring, replication factor, eviction, client library
- [x] 🔴 [`design-search-autocomplete.md`](./design-search-autocomplete.md) — Trie vs inverted index, prefix matching, ranking, caching top queries
- [x] 🔴 [`design-news-feed.md`](./design-news-feed.md) — Fan-out on write vs read, celebrity problem, timeline storage, ranking
- [x] 🔴 [`design-chat-system.md`](./design-chat-system.md) — WebSocket vs long-polling, message storage, read receipts, group chats, presence
- [x] 🔴 [`design-payment-system.md`](./design-payment-system.md) — Idempotency, exactly-once semantics, ledger, reconciliation, PCI DSS implications
- [x] 🔴 [`design-job-scheduler.md`](./design-job-scheduler.md) — Cron triggers, distributed locking (leader election), retry, DAG dependencies
- [x] 🟡 [`design-api-gateway.md`](./design-api-gateway.md) — Routing table, auth middleware, rate limiting, circuit breaking, SSL termination
- [x] 🔴 [`design-file-storage-service.md`](./design-file-storage-service.md) — Chunking, deduplication, metadata store, CDN integration, presigned URLs

## 8. Microservices & Service Architecture

- [x] 🟢 [`monolith-vs-microservices.md`](./monolith-vs-microservices.md) — When to split, operational overhead, data isolation, team topology
- [x] 🟡 [`service-discovery.md`](./service-discovery.md) — Client-side vs server-side discovery, Consul, Kubernetes DNS, health checks
- [x] 🟡 [`sidecar-pattern.md`](./sidecar-pattern.md) — Service mesh (Istio/Dapr/Linkerd), sidecar vs in-process, observability injection
- [x] 🟡 [`strangler-fig-pattern.md`](./strangler-fig-pattern.md) — Gradual monolith migration, facade routing, feature flags, dual-write
- [x] 🔴 [`domain-driven-microservices.md`](./domain-driven-microservices.md) — Bounded contexts as service boundaries, anti-corruption layer, shared kernel
- [x] 🟡 [`inter-service-communication.md`](./inter-service-communication.md) — Synchronous (gRPC/REST) vs asynchronous (messaging), coupling analysis
- [x] 🔴 [`distributed-tracing.md`](./distributed-tracing.md) — Correlation IDs, OpenTelemetry, sampling strategies, trace context propagation in .NET
- [x] 🔴 [`service-mesh-vs-api-gateway.md`](./service-mesh-vs-api-gateway.md) — East-west vs north-south traffic, Dapr in .NET, when a mesh is overkill

## 9. Observability & Reliability

- [x] 🟢 [`observability-three-pillars.md`](./observability-three-pillars.md) — Logs, metrics, traces — what each answers, OpenTelemetry as the standard
- [x] 🟡 [`structured-logging-patterns.md`](./structured-logging-patterns.md) — Serilog/NLog, log levels, correlation IDs, PII scrubbing, log aggregation
- [x] 🟡 [`metrics-and-alerting.md`](./metrics-and-alerting.md) — RED (Rate/Errors/Duration), USE (Utilization/Saturation/Errors), Prometheus/Grafana
- [x] 🟡 [`health-checks-in-aspnet-core.md`](./health-checks-in-aspnet-core.md) — `IHealthCheck`, liveness vs readiness vs startup probes, Kubernetes integration
- [x] 🔴 [`slos-slas-error-budgets.md`](./slos-slas-error-budgets.md) — SLI/SLO/SLA definitions, error budget burn rate, toil vs reliability work
- [x] 🔴 [`chaos-engineering.md`](./chaos-engineering.md) — Principles, blast radius, steady-state hypothesis, tools (Chaos Monkey, Azure Chaos Studio)
- [x] 🟡 [`graceful-degradation-patterns.md`](./graceful-degradation-patterns.md) — Fallbacks, stale data serving, feature flags, dependency timeouts

## 10. Performance & Scalability Patterns

- [x] 🟢 [`load-balancing-strategies.md`](./load-balancing-strategies.md) — Round-robin, least-connections, IP-hash, weighted, health-based
- [x] 🟡 [`connection-pooling-at-scale.md`](./connection-pooling-at-scale.md) — HTTP keep-alive, gRPC connection management, database pool sizing formula
- [x] 🟡 [`async-io-and-throughput.md`](./async-io-and-throughput.md) — Why async matters for web servers, Kestrel thread model, I/O completion ports
- [x] 🔴 [`backpressure-patterns.md`](./backpressure-patterns.md) — Bounded queues, `Channel<T>` back-pressure, TCP receive buffer, drop vs block
- [x] 🔴 [`cqrs-and-read-models.md`](./cqrs-and-read-models.md) — Command/query separation, separate read DB, eventual consistency, projection rebuild
- [x] 🟡 [`bulkhead-pattern.md`](./bulkhead-pattern.md) — Isolating failures, thread pool partitioning, Polly `Bulkhead`, resource limits
- [x] 🔴 [`performance-profiling-approach.md`](./performance-profiling-approach.md) — Benchmark-first, PerfView, dotnet-trace, ETW, memory dumps — process for production investigation
- [x] 🟡 [`denormalization-for-performance.md`](./denormalization-for-performance.md) — When to break 3NF deliberately, read-optimised schemas, materialized views

## 11. Security at Scale

- [x] 🟢 [`authentication-vs-authorization.md`](./authentication-vs-authorization.md) — Identity (who) vs permission (what), OAuth2 / OIDC overview, JWT structure
- [x] 🟡 [`jwt-design-considerations.md`](./jwt-design-considerations.md) — Stateless vs stateful (opaque tokens), expiry strategy, rotation, revocation
- [x] 🟡 [`oauth2-flows-compared.md`](./oauth2-flows-compared.md) — Authorization code + PKCE, client credentials, device flow — when to use each
- [x] 🔴 [`secrets-management-at-scale.md`](./secrets-management-at-scale.md) — Azure Key Vault, secret rotation, dynamic credentials (Vault), .NET integration
- [x] 🟡 [`zero-trust-architecture.md`](./zero-trust-architecture.md) — Never trust/always verify, mTLS between services, workload identity, BeyondCorp
- [x] 🔴 [`ddos-mitigation.md`](./ddos-mitigation.md) — Layer 3/4 vs Layer 7 attacks, Anycast, WAF rules, connection rate limiting, Azure DDoS Protection
- [x] 🟡 [`pii-and-data-privacy-design.md`](./pii-and-data-privacy-design.md) — GDPR right to erasure, data minimisation, pseudonymisation, audit log design

## 12. Cloud-Native & Infrastructure Patterns

- [x] 🟢 [`containers-and-orchestration.md`](./containers-and-orchestration.md) — Docker fundamentals, Kubernetes resources (Pod/Deployment/Service), why orchestration
- [x] 🟡 [`kubernetes-for-dotnet-devs.md`](./kubernetes-for-dotnet-devs.md) — ConfigMaps, Secrets, resource limits, liveness/readiness probes, rolling update
- [x] 🟡 [`12-factor-app.md`](./12-factor-app.md) — The 12 factors, how .NET apps comply, environment-based config, stateless processes
- [x] 🔴 [`infrastructure-as-code.md`](./infrastructure-as-code.md) — Terraform vs Bicep vs Pulumi, idempotency, state management, drift detection
- [x] 🟡 [`blue-green-and-canary-deployments.md`](./blue-green-and-canary-deployments.md) — Zero-downtime strategies, feature flags vs traffic splitting, rollback
- [x] 🔴 [`multi-region-architecture.md`](./multi-region-architecture.md) — Active-active vs active-passive, data residency, global load balancing, conflict resolution
- [x] 🟡 [`event-driven-autoscaling.md`](./event-driven-autoscaling.md) — KEDA (.NET), scale-to-zero, queue-length-based scaling, cold start mitigation
- [x] 🔴 [`serverless-design-patterns.md`](./serverless-design-patterns.md) — Azure Functions, cold start, durable orchestrations, when serverless hurts

## 13. Data Pipeline & Analytics

- [x] 🟡 [`batch-vs-stream-processing.md`](./batch-vs-stream-processing.md) — Lambda vs Kappa architecture, when real-time is needed, trade-offs
- [x] 🟡 [`data-warehouse-vs-data-lake.md`](./data-warehouse-vs-data-lake.md) — Structured vs raw, ELT vs ETL, Azure Synapse / Databricks, schema-on-read
- [x] 🔴 [`change-data-capture.md`](./change-data-capture.md) — CDC with Debezium/SQL Server CT, feeding downstream systems, latency and ordering
- [x] 🔴 [`designing-for-analytics-at-scale.md`](./designing-for-analytics-at-scale.md) — Star schema, columnar storage, partitioning, query push-down, approximate queries
- [x] 🟡 [`idempotent-data-pipeline.md`](./idempotent-data-pipeline.md) — Exactly-once processing illusion, checkpointing, watermarks, replayability

---

## Suggested study order

If preparing for a Senior/Lead .NET interview:

1. **Fundamentals first** → §1 Core Concepts + §3 Data Storage
2. **Design problems** → §7 Classic Problems (practice end-to-end)
3. **Distributed systems** → §5 Messaging + §2 APIs
4. **Reliability** → §6 Rate Limiting + §9 Observability
5. **Architecture** → §8 Microservices + §10 Performance
6. **Cloud/Infra** → §12 Cloud-Native + §11 Security
7. **Data** → §4 Caching + §13 Data Pipelines
