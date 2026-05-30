# Architecture

> Clean Architecture, CQRS, Mediator, microservices, messaging.

## Questions

_Questions are organized by sub-topic. See [BACKLOG.md](./BACKLOG.md) for the full planned list._

## Index

### §1 Clean Architecture & Layering
- [application-layer-responsibilities.md](./application-layer-responsibilities.md) — Use cases, orchestration logic, no business rules here, CQRS integration
- [clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md) — Domain/Application/Infrastructure/Presentation layers, project reference rules, .NET solution layout
- [dependency-inversion-in-architecture.md](./dependency-inversion-in-architecture.md) — DIP at architectural level, policy vs detail, high-level must not depend on low-level
- [domain-layer-design.md](./domain-layer-design.md) — Pure domain model, no framework dependencies, rich vs anemic comparison
- [infrastructure-layer-design.md](./infrastructure-layer-design.md) — Implementing domain interfaces with EF Core, HTTP clients, messaging
- [layered-vs-clean-architecture.md](./layered-vs-clean-architecture.md) — N-tier layers vs Clean Architecture, dependency direction, infrastructure coupling
- [modular-monolith-design.md](./modular-monolith-design.md) — Bounded context modules, public vs internal APIs, migration path to microservices
- [onion-architecture.md](./onion-architecture.md) — Concentric rings model, similarities/differences vs Clean Architecture
- [ports-and-adapters.md](./ports-and-adapters.md) — Hexagonal architecture, driving vs driven adapters, application port = interface
- [vertical-slice-architecture.md](./vertical-slice-architecture.md) — Feature folders, co-locating handler/validator/response, Jimmy Bogard's approach