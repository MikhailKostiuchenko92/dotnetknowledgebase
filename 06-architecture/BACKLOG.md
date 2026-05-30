# 📋 Architecture — Question Backlog

Master list of planned questions for the `06-architecture` section.
Use this file as the single source of truth for what to add next.

## How to use with Claude Code

- **Add one:** _"add an architecture question on `cqrs-fundamentals` from BACKLOG.md"_
- **Add a group:** _"add all questions from the 'Clean Architecture' group in BACKLOG.md"_
- **Continue:** _"pick the next 5 unwritten questions from BACKLOG.md and create them"_
- **Status check:** _"compare BACKLOG.md against existing files in `06-architecture/` and tell me what's missing"_

When a question is created, mark it `[x]` and add a link to the file.

## Conventions

- **Filename:** kebab-case, exactly as listed below.
- **Difficulty:** 🟢 Junior • 🟡 Middle • 🔴 Senior
- **Template:** `_templates/question-template.md`
- **Commit:** `feat(architecture): add question on <topic>`

---

## Progress

**Total:** 80 / 106
**By difficulty:** 🟢 15/21 · 🟡 37/47 · 🔴 28/38

---

## §1 Clean Architecture & Layering

- [x] 🟢 [`layered-vs-clean-architecture.md`](./layered-vs-clean-architecture.md) — N-tier layers vs Clean Architecture, dependency direction, why "Clean" avoids infrastructure coupling
- [x] 🟢 [`dependency-inversion-in-architecture.md`](./dependency-inversion-in-architecture.md) — DIP at architectural level, policy vs detail, why high-level modules must not depend on low-level
- [x] 🟢 [`ports-and-adapters.md`](./ports-and-adapters.md) — Hexagonal architecture, driving vs driven adapters, application port = interface
- [x] 🟡 [`clean-architecture-in-dotnet.md`](./clean-architecture-in-dotnet.md) — Domain / Application / Infrastructure / Presentation layers, project reference rules, .NET solution layout
- [x] 🟡 [`application-layer-responsibilities.md`](./application-layer-responsibilities.md) — Use cases, orchestration logic, no business rules here, CQRS integration
- [x] 🟡 [`domain-layer-design.md`](./domain-layer-design.md) — Pure domain model, no framework dependencies, rich vs anemic comparison
- [x] 🟡 [`infrastructure-layer-design.md`](./infrastructure-layer-design.md) — Implementing domain interfaces with EF Core, HTTP clients, messaging
- [x] 🟡 [`onion-architecture.md`](./onion-architecture.md) — Concentric rings model, similarities and differences vs Clean Architecture, common misconceptions
- [x] 🟡 [`vertical-slice-architecture.md`](./vertical-slice-architecture.md) — Feature folders, co-locating handler/validator/response, Jimmy Bogard's approach
- [x] 🟡 [`modular-monolith-design.md`](./modular-monolith-design.md) — Bounded context modules, public vs internal APIs, migration path to microservices
- [x] 🔴 [`fitness-functions.md`](./fitness-functions.md) — Architectural fitness functions, NetArchTest / ArchUnit-style rules, enforcing constraints in CI
- [x] 🔴 [`architecture-decision-records.md`](./architecture-decision-records.md) — ADR format, when to document a decision, adr-tools, living documentation
- [x] 🔴 [`anticorruption-layer.md`](./anticorruption-layer.md) — Translating between bounded contexts, preventing model pollution from external systems
- [x] 🔴 [`shared-kernel-vs-separate-ways.md`](./shared-kernel-vs-separate-ways.md) — DDD integration patterns: shared kernel, customer-supplier, conformist, ACL, separate ways

---

## §2 Domain-Driven Design (DDD)

- [x] 🟢 [`ddd-tactical-vs-strategic.md`](./ddd-tactical-vs-strategic.md) — Strategic (bounded context, context map) vs tactical patterns (aggregate, entity, VO)
- [x] 🟢 [`entity-vs-value-object.md`](./entity-vs-value-object.md) — Identity-based equality vs structural equality, immutability, C# record as VO
- [x] 🟢 [`ubiquitous-language.md`](./ubiquitous-language.md) — Why shared language matters, building it with domain experts, impact on code naming
- [x] 🟡 [`aggregate-design.md`](./aggregate-design.md) — Aggregate root, consistency boundary, one transaction per aggregate rule, size guidelines
- [x] 🟡 [`bounded-context.md`](./bounded-context.md) — Context boundaries, same concept different meanings in different contexts, mapping
- [x] 🟡 [`domain-events.md`](./domain-events.md) — Raising domain events inside aggregate, dispatching in application layer, MediatR INotification
- [x] 🟡 [`domain-services.md`](./domain-services.md) — When to extract to domain service vs keep in aggregate, stateless operations, naming
- [x] 🟡 [`repository-pattern.md`](./repository-pattern.md) — Abstract persistence, domain-oriented interface, unit of work, EF Core implementation
- [x] 🟡 [`specification-pattern.md`](./specification-pattern.md) — Encapsulating query criteria, composable specs, ISpecification, EF Core integration
- [x] 🟡 [`anemic-vs-rich-domain-model.md`](./anemic-vs-rich-domain-model.md) — Fowler's anti-pattern critique, when rich model pays off, pragmatic trade-offs
- [x] 🟡 [`context-mapping-patterns.md`](./context-mapping-patterns.md) — Published language, open-host service, customer-supplier, conformist, ACL
- [x] 🟡 [`value-object-implementation.md`](./value-object-implementation.md) — C# record VO pattern, EF Core owned types, Money/Address/Email examples
- [x] 🔴 [`aggregate-invariants.md`](./aggregate-invariants.md) — Always-valid domain model, enforcing invariants in constructors/methods, guard clauses
- [x] 🔴 [`large-aggregate-splitting.md`](./large-aggregate-splitting.md) — Signs of over-sized aggregates, how to decompose, eventual consistency across boundaries
- [x] 🔴 [`domain-model-vs-persistence-model.md`](./domain-model-vs-persistence-model.md) — Separate domain and EF Core models, mapping strategies, cost vs benefit
- [x] 🔴 [`event-storming.md`](./event-storming.md) — Workshop technique, domain events → commands → aggregates → bounded contexts, hotspot discovery
- [x] 🔴 [`ddd-and-microservices.md`](./ddd-and-microservices.md) — One service per bounded context (usually), when to break the rule, context map to service map
- [x] 🔴 [`ddd-anti-patterns.md`](./ddd-anti-patterns.md) — Entity-service naming trap, database-driven design, persistence bleeding into domain

---

## §3 CQRS

- [x] 🟢 [`cqrs-fundamentals.md`](./cqrs-fundamentals.md) — Command/Query Responsibility Segregation, Bertrand Meyer's CQS origin, Greg Young's evolution
- [x] 🟢 [`command-vs-query.md`](./command-vs-query.md) — What makes a command vs a query, void vs return value, side effects contract
- [x] 🟡 [`cqrs-with-mediatr.md`](./cqrs-with-mediatr.md) — IRequest / IRequestHandler, notifications, MediatR DI setup, request pipeline
- [x] 🟡 [`cqrs-read-models.md`](./cqrs-read-models.md) — Denormalized projections, separate read DB strategy, updating read models from events
- [x] 🟡 [`cqrs-write-models.md`](./cqrs-write-models.md) — Command handler loads aggregate, executes, persists, publishes domain events
- [x] 🟡 [`pipeline-behaviors.md`](./pipeline-behaviors.md) — IPipelineBehavior, ordering, validation/logging/caching/transaction use cases
- [x] 🟡 [`cqrs-without-event-sourcing.md`](./cqrs-without-event-sourcing.md) — CQRS on a single relational DB, DB views, EF Core split for read/write
- [x] 🔴 [`cqrs-consistency-challenges.md`](./cqrs-consistency-challenges.md) — Eventual consistency between write model and read projection, stale read handling
- [x] 🔴 [`cqrs-and-ddd.md`](./cqrs-and-ddd.md) — Command → aggregate → domain events → projection, how DDD and CQRS compose in .NET
- [x] 🔴 [`task-based-ui-and-cqrs.md`](./task-based-ui-and-cqrs.md) — Why CRUD UIs fight CQRS, intention-revealing commands, task-based UX design

---

## §4 Event Sourcing

- [x] 🟢 [`event-sourcing-fundamentals.md`](./event-sourcing-fundamentals.md) — Store events not state, replay to rebuild, append-only log, audit built-in
- [x] 🟡 [`event-store-design.md`](./event-store-design.md) — Events table schema, optimistic concurrency with stream version, aggregate streams
- [x] 🟡 [`projections-and-read-models.md`](./projections-and-read-models.md) — Synchronous vs async projections, catch-up subscriptions, projection rebuilds
- [x] 🟡 [`event-sourcing-in-dotnet.md`](./event-sourcing-in-dotnet.md) — EventStoreDB, Marten (PostgreSQL), custom implementation patterns
- [x] 🟡 [`snapshots-in-event-sourcing.md`](./snapshots-in-event-sourcing.md) — When to snapshot, snapshot strategy, loading state with and without snapshot
- [x] 🔴 [`event-sourcing-vs-traditional.md`](./event-sourcing-vs-traditional.md) — Audit log benefit, temporal queries, debugging advantages, operational complexity cost
- [x] 🔴 [`event-schema-evolution.md`](./event-schema-evolution.md) — Upcasting, versioned events, forward/backward compatibility, schema registry
- [x] 🔴 [`event-sourcing-pitfalls.md`](./event-sourcing-pitfalls.md) — Stale projections in UI, long streams, wrong granularity, testing complexity
- [x] 🔴 [`event-sourcing-and-cqrs.md`](./event-sourcing-and-cqrs.md) — Complementary but independent — can use each without the other, when to combine
- [x] 🔴 [`event-driven-projections.md`](./event-driven-projections.md) — Catch-up vs persistent subscriptions, competing consumers, projection reset strategy

---

## §5 Microservices Patterns

- [x] 🟢 [`microservices-vs-monolith.md`](./microservices-vs-monolith.md) — Trade-offs, Conway's law, when monolith is the right choice, common fallacies
- [x] 🟢 [`service-decomposition-strategies.md`](./service-decomposition-strategies.md) — Decompose by business capability vs subdomain, strangler fig, start small
- [x] 🟢 [`inter-service-communication.md`](./inter-service-communication.md) — Sync (REST / gRPC) vs async (messaging), latency, coupling, failure modes
- [x] 🟡 [`api-gateway-pattern.md`](./api-gateway-pattern.md) — BFF (Backend for Frontend), aggregation, auth offloading, YARP, Azure API Management
- [x] 🟡 [`service-discovery.md`](./service-discovery.md) — Client-side vs server-side, Consul, Kubernetes DNS, health checks integration
- [x] 🟡 [`distributed-transaction-patterns.md`](./distributed-transaction-patterns.md) — Why 2PC fails in microservices, saga, outbox, compensating transactions
- [x] 🟡 [`strangler-fig-pattern.md`](./strangler-fig-pattern.md) — Incrementally replacing a monolith, proxy routing, per-feature migration
- [x] 🟡 [`sidecar-and-ambassador-patterns.md`](./sidecar-and-ambassador-patterns.md) — Cross-cutting sidecar, proxy ambassador, Dapr, Envoy use cases
- [x] 🟡 [`service-mesh-basics.md`](./service-mesh-basics.md) — Istio/Linkerd concepts, mTLS, traffic management, mesh observability
- [x] 🟡 [`health-checks-in-microservices.md`](./health-checks-in-microservices.md) — Readiness vs liveness vs startup probes, ASP.NET Core health checks
- [x] 🔴 [`data-ownership-in-microservices.md`](./data-ownership-in-microservices.md) — Each service owns its DB, no shared schema, integration via events/APIs
- [x] 🔴 [`microservices-testing-strategies.md`](./microservices-testing-strategies.md) — Consumer-driven contracts, Pact, test pyramid for distributed systems
- [x] 🔴 [`bulkhead-and-isolation.md`](./bulkhead-and-isolation.md) — Resource isolation between services, Polly Isolation, thread-pool bulkhead
- [x] 🔴 [`choreography-vs-orchestration.md`](./choreography-vs-orchestration.md) — Event choreography benefits/risks, orchestration clarity vs coupling trade-off
- [x] 🔴 [`microservices-security-patterns.md`](./microservices-security-patterns.md) — Service-to-service auth, JWT propagation, mTLS, zero-trust in microservices
- [x] 🔴 [`distributed-tracing-patterns.md`](./distributed-tracing-patterns.md) — W3C trace context, correlation IDs, OpenTelemetry in microservices, Jaeger

---

## §6 Mediator & Pipeline Patterns

- [x] 🟢 [`mediator-pattern.md`](./mediator-pattern.md) — GoF mediator, decoupling sender from receiver, MediatR as mediator, when to use
- [ ] 🟡 `mediatr-setup-and-usage.md` — DI registration, IRequest/IRequestHandler, INotification, assembly scanning
- [ ] 🟡 `cross-cutting-via-pipeline.md` — Validation, logging, caching, transaction behaviors in MediatR pipeline
- [ ] 🟡 `notification-vs-request.md` — INotification fan-out vs IRequest single handler, publish vs send semantics
- [ ] 🔴 `mediatr-performance-considerations.md` — Reflection overhead, micro-benchmark results, when to avoid MediatR
- [ ] 🔴 `command-validation-pipeline.md` — FluentValidation + IPipelineBehavior, ValidationException, Result pattern alternatives

---

## §7 API Design & Versioning

- [ ] 🟢 `rest-maturity-model.md` — Richardson maturity levels 0–3, HATEOAS in theory vs practice, pragmatic REST
- [ ] 🟢 `rest-vs-grpc.md` — HTTP/1.1+JSON vs HTTP/2+Protobuf, streaming, browser compatibility, when gRPC wins
- [ ] 🟢 `api-versioning-strategies.md` — URL path, query string, header, content negotiation — trade-offs of each
- [ ] 🟡 `api-versioning-in-aspnet-core.md` — Asp.Versioning package, version sets, MapToApiVersion, deprecation workflow
- [ ] 🟡 `openapi-and-swagger.md` — Swashbuckle vs NSwag, OpenAPI spec, API client codegen, versioned docs
- [ ] 🟡 `problem-details-rfc7807.md` — ProblemDetails, ValidationProblemDetails, IExceptionHandler (.NET 8), type URIs
- [ ] 🟡 `backward-compatible-api-changes.md` — Safe additive changes, breaking changes, deprecation strategy, sunset header
- [ ] 🔴 `api-contract-testing.md` — Consumer-driven contracts, Pact .NET, verifying provider without integration tests
- [ ] 🔴 `graphql-vs-rest-in-dotnet.md` — Hot Chocolate, DataLoader, n+1 problem, when GraphQL complexity is justified
- [ ] 🔴 `hypermedia-and-hateoas.md` — Level 3 REST, self-descriptive messages, Siren/HAL formats, practical ROI

---

## §8 Resilience Architecture

- [ ] 🟢 `resilience-patterns-overview.md` — Retry, circuit breaker, timeout, bulkhead, fallback — the landscape of resilience
- [ ] 🟢 `retry-pattern-design.md` — Exponential backoff, jitter, idempotency requirement, Polly v8 retry pipeline
- [ ] 🟡 `circuit-breaker-design.md` — Closed/Open/Half-Open states, threshold tuning, Polly ResiliencePipeline
- [ ] 🟡 `timeout-and-cancellation.md` — CancellationToken propagation, timeout policy, cascading timeout risks
- [ ] 🟡 `fallback-and-graceful-degradation.md` — Static fallback, stale cache, degraded mode, feature flags for resilience
- [ ] 🔴 `resilience-in-dotnet-aspnet-core.md` — Microsoft.Extensions.Resilience, IHttpClientFactory + resilience handler
- [ ] 🔴 `chaos-engineering-basics.md` — Chaos Monkey approach, fault injection, Azure Chaos Studio, resilience testing in CI
- [ ] 🔴 `designing-for-partial-failure.md` — Assume everything fails, idempotent retries, compensating actions, partial success API

---

## §9 Modular Monolith

- [ ] 🟢 `monolith-types.md` — Big ball of mud vs well-structured vs modular monolith, when monolith beats microservices
- [ ] 🟡 `modular-monolith-structure.md` — Module boundaries, internal vs exported API, enforcing isolation per module
- [ ] 🟡 `modular-monolith-communication.md` — In-process events vs direct method calls, loose coupling within a process
- [ ] 🟡 `strangler-fig-vs-modular-monolith.md` — Start modular, extract services incrementally, reversibility advantage
- [ ] 🔴 `module-isolation-enforcement.md` — NetArchTest rules, package visibility, ArchUnit-style dependency constraints in CI
- [ ] 🔴 `shared-infrastructure-in-modular-monolith.md` — Shared DB with separate schemas, shared outbox, shared auth, trade-offs

---

## §10 Cross-Cutting Concerns

- [ ] 🟢 `cross-cutting-concerns-overview.md` — What makes a concern "cross-cutting", common examples, strategies to handle
- [ ] 🟢 `global-error-handling.md` — Middleware exception handling, IExceptionHandler (.NET 8), ProblemDetails factory, RFC 9457
- [ ] 🟡 `validation-strategies.md` — FluentValidation vs DataAnnotations, where validation belongs (application vs domain)
- [ ] 🟡 `audit-logging-architecture.md` — EF Core interceptors for audit trail, domain events as audit log, structured logging
- [ ] 🟡 `authorization-patterns.md` — Resource-based auth, policy-based auth, IAuthorizationHandler, claims transformation
- [ ] 🟡 `feature-flags-architecture.md` — Microsoft.FeatureManagement, trunk-based development, kill switch pattern, LaunchDarkly
- [ ] 🔴 `aspect-oriented-programming.md` — AOP in .NET, Castle DynamicProxy, Decorator as AOP alternative, when each fits
- [ ] 🔴 `outbox-pattern-architecture.md` — Why direct side effects are unreliable, transactional outbox, polling vs CDC relay
