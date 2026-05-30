# 📋 OOP & Design — Question Backlog

Master list of planned questions for the `03-oop-and-design` section.
Use this file as the single source of truth for what to add next.

## How to use with Claude Code

- **Add one:** _"add an oop-and-design question on `strategy-pattern` from BACKLOG.md"_
- **Add a group:** _"add all questions from the 'SOLID Principles' group in BACKLOG.md"_
- **Continue:** _"pick the next 5 unwritten questions from BACKLOG.md and create them"_
- **Status check:** _"compare BACKLOG.md against existing files in `03-oop-and-design/` and tell me what's missing"_

When a question is created, mark it `[x]` and add a link to the file.

## Conventions

- **Filename:** kebab-case, exactly as listed below.
- **Difficulty:** 🟢 Junior • 🟡 Middle • 🔴 Senior
- **Template:** `_templates/question-template.md`
- **Commit:** `feat(oop-design): add question on <topic>`

---

## Progress

**Total:** 0 / 86
**By difficulty:** 🟢 0/20 · 🟡 0/40 · 🔴 0/26

---

## §1 OOP Fundamentals (11 questions)

- [ ] 🟢 `oop-four-pillars.md` — Encapsulation, inheritance, polymorphism, abstraction — definitions and C# examples
- [ ] 🟢 `encapsulation.md` — Access modifiers, information hiding, exposing behaviour not state, property vs field
- [ ] 🟢 `overloading-vs-overriding.md` — Method overloading vs overriding, new vs override keywords, hiding vs polymorphism
- [ ] 🟢 `abstract-class-vs-interface.md` — When to use each, default interface methods (C# 8+), multiple-interface inheritance
- [ ] 🟢 `sealed-classes-and-methods.md` — sealed keyword, devirtualization optimisation, security and design intent
- [ ] 🟡 `inheritance-vs-composition.md` — "Favour composition over inheritance" rule, fragile base class problem, when inheritance is fine
- [ ] 🟡 `polymorphism-types.md` — Compile-time (overload) vs runtime (override) polymorphism, virtual dispatch table, interfaces
- [ ] 🟡 `object-equality-and-identity.md` — == vs Equals vs ReferenceEquals, IEquatable\<T\>, GetHashCode contract, records
- [ ] 🔴 `covariance-and-contravariance.md` — out/in generic variance, IEnumerable\<T\> covariance, Action\<T\> contravariance, array covariance gotcha
- [ ] 🔴 `virtual-dispatch-internals.md` — Method table (vtable), virtual/interface dispatch under the CLR, devirtualisation by JIT
- [ ] 🔴 `interface-default-members.md` — Default interface methods (C# 8+), diamond problem handling, trait/mixin pattern, limitations

---

## §2 SOLID Principles (9 questions)

- [ ] 🟢 `single-responsibility-principle.md` — SRP definition, cohesion, god class smell, real C# refactoring example
- [ ] 🟢 `dependency-inversion-principle.md` — DIP, high vs low-level modules, abstractions, how it differs from DI container
- [ ] 🟡 `open-closed-principle.md` — OCP via inheritance, composition, and strategy, extending without modifying, C# examples
- [ ] 🟡 `liskov-substitution-principle.md` — LSP, behavioural substitutability, precondition/postcondition rules, LSP violations
- [ ] 🟡 `interface-segregation-principle.md` — ISP, fat interface smell, role interfaces, segregating by client need
- [ ] 🔴 `cohesion-and-coupling.md` — Types of cohesion (functional/temporal/sequential), coupling metrics, afferent vs efferent
- [ ] 🟡 `solid-applied-example.md` — Refactoring a real C# class that violates all 5 SOLID principles, step by step
- [ ] 🔴 `solid-violations-and-smells.md` — Recognising violations in a codebase: shotgun surgery, fragile base class, interface bloat
- [ ] 🔴 `open-closed-vs-yagni.md` — Tension between OCP (plan for extension) and YAGNI (don't over-abstract), when to apply OCP

---

## §3 GoF Creational Patterns (7 questions)

- [ ] 🟢 `singleton-pattern.md` — Classic vs Lazy\<T\> singleton, thread-safety variants, when DI container replaces it
- [ ] 🟢 `factory-method-pattern.md` — Factory method, virtual constructor, vs new, C# abstract + concrete factory example
- [ ] 🟡 `abstract-factory-pattern.md` — Abstract factory, product families, switching families at runtime, vs factory method
- [ ] 🟡 `builder-pattern.md` — Builder for complex objects, fluent API, immutable result, vs telescoping constructors
- [ ] 🟡 `prototype-pattern.md` — ICloneable, deep vs shallow copy, MemberwiseClone pitfalls, record with-expression as modern prototype
- [ ] 🟡 `object-pool-pattern.md` — ObjectPool\<T\> (Microsoft.Extensions.ObjectPool), ArrayPool\<T\>, MemoryPool\<T\>, when pooling pays off
- [ ] 🔴 `di-as-creational-pattern.md` — DI container as configurable abstract factory, factory delegates (Func\<T\>), keyed services (.NET 8)

---

## §4 GoF Structural Patterns (8 questions)

- [ ] 🟢 `adapter-pattern.md` — Class adapter vs object adapter, legacy code wrapping, IAdapter\<T\> in C# example
- [ ] 🟡 `decorator-pattern.md` — Decorator vs inheritance, open/closed, Scrutor library, pipeline decoration in ASP.NET Core
- [ ] 🟡 `facade-pattern.md` — Simplifying subsystem access, anti-corruption layer connection, application service as facade
- [ ] 🟡 `proxy-pattern.md` — Virtual proxy (lazy load), protection proxy, logging proxy, DispatchProxy and Castle DynamicProxy
- [ ] 🟡 `composite-pattern.md` — Tree structures, Component/Leaf/Composite, IEnumerable recursive traversal example
- [ ] 🔴 `bridge-pattern.md` — Abstraction/Implementor decoupling, vs strategy pattern, cross-platform code example
- [ ] 🔴 `flyweight-pattern.md` — Shared intrinsic state, extrinsic state per use, string interning analogy, struct optimisation
- [ ] 🔴 `decorator-in-di.md` — Decorating interfaces in a DI container, Scrutor's Decorate, open-generic decoration pitfalls

---

## §5 GoF Behavioral Patterns (12 questions)

- [ ] 🟢 `strategy-pattern.md` — Algorithm family, interchangeability, Func\<T\> as lightweight strategy, sorting example
- [ ] 🟢 `null-object-pattern.md` — Null object vs null-conditional, replacing null checks, NullLogger\<T\> as canonical example
- [ ] 🟡 `observer-pattern.md` — IObservable\<T\>/IObserver\<T\>, event-based alternative, vs Rx, pub-sub, weak event pattern
- [ ] 🟡 `command-pattern.md` — Command object, undo/redo support, MediatR IRequest connection, command queue
- [ ] 🟡 `template-method-pattern.md` — Abstract base with hooks, Hollywood Principle, vs strategy, when each is better
- [ ] 🟡 `iterator-pattern.md` — IEnumerable\<T\>/IEnumerator\<T\>, yield return mechanics, custom iterators, lazy evaluation
- [ ] 🟡 `chain-of-responsibility-pattern.md` — Handler chain, middleware pipeline analogy, ASP.NET Core pipeline connection
- [ ] 🟡 `mediator-pattern.md` — Mediator vs event bus, MediatR as mediator, coupling reduction, request/notification split
- [ ] 🟡 `memento-pattern.md` — Snapshot for undo/redo, encapsulation of state, record/clone as modern memento
- [ ] 🔴 `visitor-pattern.md` — Double dispatch, adding operations to a sealed hierarchy, expression tree analogy, vs pattern matching
- [ ] 🔴 `state-pattern.md` — State machine with state objects, transitions, vs enum+switch, Stateless library example
- [ ] 🔴 `specification-pattern.md` — ISpecification\<T\>, composite specifications, EF Core integration, Ardalis.Specification library

---

## §6 Domain-Driven Design Basics (12 questions)

- [ ] 🟢 `ddd-core-concepts.md` — Ubiquitous language, bounded context, domain model, strategic vs tactical DDD
- [ ] 🟢 `entity-vs-value-object.md` — Identity-based equality (entity) vs structural equality (value object), C# record as VO
- [ ] 🔴 `aggregate-pattern.md` — Aggregate root, consistency boundary, invariant enforcement, reference by ID between aggregates
- [ ] 🔴 `domain-events.md` — Domain events vs integration events, raising in domain, dispatching in application layer, MediatR
- [ ] 🟡 `repository-pattern.md` — Repository interface, hiding persistence, vs direct DbContext, generic vs typed repositories
- [ ] 🟡 `domain-service.md` — When logic doesn't belong to entity or VO, stateless, examples: pricing, transfer, tax calculation
- [ ] 🟡 `ubiquitous-language-in-code.md` — Naming types/methods after domain terms, anti-corruption layer from model rot
- [ ] 🟡 `ddd-layers-and-clean-arch.md` — DDD layers (Domain/Application/Infrastructure/UI) mapped to Clean Architecture
- [ ] 🟡 `value-object-implementation.md` — IEquatable\<T\>, operator overloading, C# record as VO, collection wrapping, validation
- [ ] 🔴 `aggregate-design-guidelines.md` — Small aggregates rule, eventual consistency between aggregates, domain event compensation
- [ ] 🔴 `bounded-context-integration.md` — Context map patterns: shared kernel, ACL, open host service, published language
- [ ] 🔴 `cqrs-and-ddd.md` — CQRS as natural consequence of DDD, read model vs write model, eventual consistency handling

---

## §7 Functional Patterns in C# (10 questions)

- [ ] 🟢 `pure-functions-and-side-effects.md` — Pure function definition, referential transparency, testability, when purity isn't practical
- [ ] 🟢 `extension-methods.md` — Extension method mechanics, OCP tool, LINQ as extension pattern, pitfalls (visibility, overloading)
- [ ] 🟢 `immutability-in-csharp.md` — readonly fields, init-only properties, records, ImmutableList\<T\>, why immutability helps concurrency
- [ ] 🟡 `result-pattern.md` — Result\<T\>/Either\<L,R\>, railway-oriented programming, vs throwing exceptions, FluentResults library
- [ ] 🟡 `option-type.md` — Option\<T\>/Maybe\<T\>, nullable reference types vs option type, eliminating null checks, C# 8+ NRT
- [ ] 🟡 `pattern-matching-oop.md` — Switch expressions, type/relational/property/list patterns (C# 8–12), replacing visitor pattern
- [ ] 🟡 `functional-composition.md` — Method chaining, LINQ as functional pipeline, compose/pipe helpers, monad-like patterns in C#
- [ ] 🔴 `expression-trees.md` — Expression\<Func\<T\>\> vs Func\<T\>, LINQ providers, building/compiling expressions, ORM usage
- [ ] 🔴 `discriminated-unions-csharp.md` — Discriminated unions via class hierarchy, OneOf library, records for cases, future C# union types
- [ ] 🔴 `higher-order-functions-csharp.md` — Funcs as first-class, currying, partial application, Func composition, strategy via delegates

---

## §8 Generics & Type-Level Patterns (8 questions)

- [ ] 🟢 `generics-fundamentals.md` — Generic type parameters, type inference, open vs closed generic types, reification (not erasure)
- [ ] 🟡 `generic-constraints.md` — where T : new(), struct, class, unmanaged, interface, base class — when each is needed
- [ ] 🟡 `generic-patterns.md` — Generic repository, generic result, open-generic DI registration, self-referential (CRTP) pattern
- [ ] 🟡 `options-pattern.md` — IOptions\<T\>/IOptionsSnapshot\<T\>/IOptionsMonitor\<T\>, named options, validation, DI integration
- [ ] 🟡 `pipeline-pattern.md` — Middleware pipeline (chain of responsibility with next()), IMiddleware, generic pipeline behavior
- [ ] 🔴 `source-generators-in-design.md` — Source generators as code-gen alternative to reflection, avoiding magic, design patterns enabled
- [ ] 🔴 `open-generic-registration.md` — Open-generic DI registration, typeof(IRepository\<\>), decorator chaining on open generics
- [ ] 🔴 `type-safe-builder-pattern.md` — Phantom types / type-state builder, compile-time mandatory-step enforcement, C# example

---

## §9 Anti-Patterns & Code Smells (9 questions)

- [ ] 🟢 `god-class-anti-pattern.md` — God object, low cohesion, extract class refactoring, feature envy connection
- [ ] 🟢 `spaghetti-and-big-ball-of-mud.md` — Unstructured codebase, accidental complexity, strangler-fig refactoring entry point
- [ ] 🟡 `anemic-domain-model.md` — Anemic vs rich domain model, behaviour vs data, service bloat, DDD perspective
- [ ] 🟡 `primitive-obsession.md` — Using primitives for domain concepts, value object refactoring, type safety improvement
- [ ] 🟡 `law-of-demeter.md` — Tell Don't Ask, method chaining vs LoD, fluent API as intentional exception, coupling impact
- [ ] 🟡 `shotgun-surgery.md` — Scattered change smell, SRP violation, example across layers and fix
- [ ] 🟡 `service-locator-anti-pattern.md` — Service locator vs DI, hidden dependencies, testability, when static access is a smell
- [ ] 🔴 `over-engineering-and-yagni.md` — YAGNI, premature abstraction, pattern obsession, recognising when simplicity wins
- [ ] 🔴 `refactoring-to-patterns.md` — Recognising when a GoF pattern solves a smell, incremental refactoring approach, strangler fig
