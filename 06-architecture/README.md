# Architecture

> Clean Architecture, CQRS, Mediator, microservices, messaging.

## Questions

_Questions are organized by sub-topic. See [BACKLOG.md](./BACKLOG.md) for the full planned list._

## Index

### §1 Clean Architecture & Layering
- [anticorruption-layer.md](./anticorruption-layer.md) — Translating between bounded contexts, preventing model pollution from external systems
- [application-layer-responsibilities.md](./application-layer-responsibilities.md) — Use cases, orchestration logic, no business rules here, CQRS integration
- [architecture-decision-records.md](./architecture-decision-records.md) — ADR format, when to document a decision, adr-tools, living documentation
- [clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md) — Domain/Application/Infrastructure/Presentation layers, project reference rules, .NET solution layout
- [dependency-inversion-in-architecture.md](./dependency-inversion-in-architecture.md) — DIP at architectural level, policy vs detail, high-level must not depend on low-level
- [domain-layer-design.md](./domain-layer-design.md) — Pure domain model, no framework dependencies, rich vs anemic comparison
- [fitness-functions.md](./fitness-functions.md) — NetArchTest architectural tests, dependency enforcement, CI architecture gates
- [infrastructure-layer-design.md](./infrastructure-layer-design.md) — Implementing domain interfaces with EF Core, HTTP clients, messaging
- [layered-vs-clean-architecture.md](./layered-vs-clean-architecture.md) — N-tier layers vs Clean Architecture, dependency direction, infrastructure coupling
- [modular-monolith-design.md](./modular-monolith-design.md) — Bounded context modules, public vs internal APIs, migration path to microservices
- [onion-architecture.md](./onion-architecture.md) — Concentric rings model, similarities/differences vs Clean Architecture
- [ports-and-adapters.md](./ports-and-adapters.md) — Hexagonal architecture, driving vs driven adapters, application port = interface
- [shared-kernel-vs-separate-ways.md](./shared-kernel-vs-separate-ways.md) — DDD context mapping patterns: Shared Kernel, Customer-Supplier, Conformist, ACL, Separate Ways
- [vertical-slice-architecture.md](./vertical-slice-architecture.md) — Feature folders, co-locating handler/validator/response, Jimmy Bogard's approach

### §2 Domain-Driven Design (DDD)
- [aggregate-design.md](./aggregate-design.md) — Aggregate root, consistency boundary, one transaction per aggregate, size rules
- [aggregate-invariants.md](./aggregate-invariants.md) — Always-valid model, factory methods, guard clauses, state machine transitions
- [anemic-vs-rich-domain-model.md](./anemic-vs-rich-domain-model.md) — Fowler's anti-pattern, rich model trade-offs, EF Core with private setters
- [bounded-context.md](./bounded-context.md) — Context boundaries, same concept different meanings, identifying boundaries
- [context-mapping-patterns.md](./context-mapping-patterns.md) — Published Language, Open Host Service, partnership, full pattern catalog
- [ddd-and-microservices.md](./ddd-and-microservices.md) — Bounded context to service mapping, Conway's Law, when to break the rule
- [ddd-anti-patterns.md](./ddd-anti-patterns.md) — Entity-service trap, database-driven design, persistence bleeding
- [ddd-tactical-vs-strategic.md](./ddd-tactical-vs-strategic.md) — Strategic (bounded context, context map) vs tactical patterns (aggregate, entity, VO)
- [domain-events.md](./domain-events.md) — Raising events in aggregates, SaveChanges dispatch, domain vs integration events
- [domain-model-vs-persistence-model.md](./domain-model-vs-persistence-model.md) — Separate models, EF Core mapping, when to split
- [domain-services.md](./domain-services.md) — Stateless cross-entity operations, vs application services, naming
- [entity-vs-value-object.md](./entity-vs-value-object.md) — Identity-based vs structural equality, immutability, C# record as VO
- [event-storming.md](./event-storming.md) — Workshop technique, Big Picture/Process/Design levels, discovering bounded contexts
- [large-aggregate-splitting.md](./large-aggregate-splitting.md) — Signs of oversized aggregates, decomposition, eventual consistency
- [repository-pattern.md](./repository-pattern.md) — Domain-oriented interface, aggregate root per repo, EF Core implementation
- [specification-pattern.md](./specification-pattern.md) — ISpecification, composable queries, Ardalis.Specification, EF Core
- [ubiquitous-language.md](./ubiquitous-language.md) — Shared vocabulary with domain experts, impact on code naming
- [value-object-implementation.md](./value-object-implementation.md) — C# record VOs, EF Core ComplexType vs OwnsOne, Money/Address/Email

### §3 CQRS
- [command-vs-query.md](./command-vs-query.md) — Command vs query contracts, idempotency, caching, API design impact
- [cqrs-and-ddd.md](./cqrs-and-ddd.md) — Command → aggregate → domain event → projection, full DDD+CQRS composition
- [cqrs-consistency-challenges.md](./cqrs-consistency-challenges.md) — Eventual consistency, stale reads, read-after-write strategies
- [cqrs-fundamentals.md](./cqrs-fundamentals.md) — CQS origin, Greg Young CQRS, read/write model separation, spectrum
- [cqrs-read-models.md](./cqrs-read-models.md) — Denormalized projections, DB views, async read model updates
- [cqrs-with-mediatr.md](./cqrs-with-mediatr.md) — IRequest/IRequestHandler, notifications, ISender vs IMediator
- [cqrs-without-event-sourcing.md](./cqrs-without-event-sourcing.md) — Single-database CQRS, EF Core AsNoTracking + Dapper split
- [cqrs-write-models.md](./cqrs-write-models.md) — Command handler → aggregate → persist → domain events
- [pipeline-behaviors.md](./pipeline-behaviors.md) — IPipelineBehavior, registration order, validation/logging/caching/transaction
- [task-based-ui-and-cqrs.md](./task-based-ui-and-cqrs.md) — Intention-revealing commands, CRUD vs task-based UX, REST sub-resources

### §4 Event Sourcing
- [event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md) — Append-only event log, state reconstruction, audit trail, replay benefits