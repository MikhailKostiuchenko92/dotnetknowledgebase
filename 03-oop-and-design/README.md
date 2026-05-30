# OOP & Design

> OOP principles, SOLID, GoF design patterns, DDD basics.

**86 questions** · 🟢 20 Junior · 🟡 40 Middle · 🔴 26 Senior

## Index

### §1 OOP Fundamentals

| File | Difficulty | Topic |
|---|---|---|
| [oop-four-pillars.md](oop-four-pillars.md) | 🟢 | Encapsulation, inheritance, polymorphism, abstraction |
| [encapsulation.md](encapsulation.md) | 🟢 | Access modifiers, information hiding, property vs field |
| [overloading-vs-overriding.md](overloading-vs-overriding.md) | 🟢 | Method overloading vs overriding, `new` vs `override` |
| [abstract-class-vs-interface.md](abstract-class-vs-interface.md) | 🟢 | When to use each, default interface methods (C# 8+) |
| [sealed-classes-and-methods.md](sealed-classes-and-methods.md) | 🟢 | `sealed` keyword, devirtualization, design intent |
| [inheritance-vs-composition.md](inheritance-vs-composition.md) | 🟡 | Favour composition, fragile base class problem |
| [polymorphism-types.md](polymorphism-types.md) | 🟡 | Compile-time vs runtime polymorphism, vtable |
| [object-equality-and-identity.md](object-equality-and-identity.md) | 🟡 | `==` vs `Equals` vs `ReferenceEquals`, `IEquatable<T>` |
| [covariance-and-contravariance.md](covariance-and-contravariance.md) | 🔴 | `out`/`in` generic variance, array covariance gotcha |
| [virtual-dispatch-internals.md](virtual-dispatch-internals.md) | 🔴 | Method table (vtable), CLR dispatch, JIT devirtualization |
| [interface-default-members.md](interface-default-members.md) | 🔴 | Default interface methods (C# 8+), diamond problem |

### §2 SOLID Principles

| File | Difficulty | Topic |
|---|---|---|
| [single-responsibility-principle.md](single-responsibility-principle.md) | 🟢 | SRP, cohesion, god class smell |
| [dependency-inversion-principle.md](dependency-inversion-principle.md) | 🟢 | DIP, high vs low-level modules, abstractions |
| [open-closed-principle.md](open-closed-principle.md) | 🟡 | OCP via strategy/composition, extending without modifying |
| [liskov-substitution-principle.md](liskov-substitution-principle.md) | 🟡 | Behavioural substitutability, pre/postcondition rules |
| [interface-segregation-principle.md](interface-segregation-principle.md) | 🟡 | Fat interface smell, role interfaces |
| [solid-applied-example.md](solid-applied-example.md) | 🟡 | Refactoring a class that violates all 5 principles |
| [cohesion-and-coupling.md](cohesion-and-coupling.md) | 🔴 | Cohesion types, afferent vs efferent coupling metrics |
| [solid-violations-and-smells.md](solid-violations-and-smells.md) | 🔴 | Recognising violations: shotgun surgery, interface bloat |
| [open-closed-vs-yagni.md](open-closed-vs-yagni.md) | 🔴 | Tension between OCP and YAGNI, when to abstract |

### §3 GoF Creational Patterns

| File | Difficulty | Topic |
|---|---|---|
| [singleton-pattern.md](singleton-pattern.md) | 🟢 | Classic vs `Lazy<T>`, thread safety, DI replacement |
| [factory-method-pattern.md](factory-method-pattern.md) | 🟢 | Virtual constructor, factory method vs `new` |
| [abstract-factory-pattern.md](abstract-factory-pattern.md) | 🟡 | Product families, switching families at runtime |
| [builder-pattern.md](builder-pattern.md) | 🟡 | Fluent builder, immutable result, telescoping constructors |
| [prototype-pattern.md](prototype-pattern.md) | 🟡 | `ICloneable`, deep vs shallow copy, record `with` |
| [object-pool-pattern.md](object-pool-pattern.md) | 🟡 | `ObjectPool<T>`, `ArrayPool<T>`, when pooling pays off |
| [di-as-creational-pattern.md](di-as-creational-pattern.md) | 🔴 | DI as abstract factory, `Func<T>`, keyed services (.NET 8) |

### §4 GoF Structural Patterns

| File | Difficulty | Topic |
|---|---|---|
| [adapter-pattern.md](adapter-pattern.md) | 🟢 | Class vs object adapter, legacy code wrapping |
| [decorator-pattern.md](decorator-pattern.md) | 🟡 | Decorator vs inheritance, Scrutor, ASP.NET Core pipeline |
| [facade-pattern.md](facade-pattern.md) | 🟡 | Simplifying subsystems, application service as facade |
| [proxy-pattern.md](proxy-pattern.md) | 🟡 | Virtual/protection/logging proxy, `DispatchProxy` |
| [composite-pattern.md](composite-pattern.md) | 🟡 | Tree structures, Component/Leaf/Composite |
| [bridge-pattern.md](bridge-pattern.md) | 🔴 | Abstraction/Implementor decoupling, vs strategy |
| [flyweight-pattern.md](flyweight-pattern.md) | 🔴 | Shared intrinsic state, string interning, struct optimization |
| [decorator-in-di.md](decorator-in-di.md) | 🔴 | Decorating interfaces in DI, Scrutor, open-generic pitfalls |

### §5 GoF Behavioral Patterns

| File | Difficulty | Topic |
|---|---|---|
| [strategy-pattern.md](strategy-pattern.md) | 🟢 | Algorithm family, `Func<T>` as lightweight strategy |
| [null-object-pattern.md](null-object-pattern.md) | 🟢 | Replacing null checks, `NullLogger<T>` |
| [observer-pattern.md](observer-pattern.md) | 🟡 | `IObservable<T>`, events, vs Rx, weak event pattern |
| [command-pattern.md](command-pattern.md) | 🟡 | Command object, undo/redo, MediatR `IRequest` |
| [template-method-pattern.md](template-method-pattern.md) | 🟡 | Abstract base with hooks, Hollywood Principle, vs strategy |
| [iterator-pattern.md](iterator-pattern.md) | 🟡 | `IEnumerable<T>`, `yield return`, lazy evaluation |
| [chain-of-responsibility-pattern.md](chain-of-responsibility-pattern.md) | 🟡 | Handler chain, ASP.NET Core middleware analogy |
| [mediator-pattern.md](mediator-pattern.md) | 🟡 | Mediator vs event bus, MediatR, coupling reduction |
| [memento-pattern.md](memento-pattern.md) | 🟡 | Snapshot for undo/redo, record/clone as modern memento |
| [visitor-pattern.md](visitor-pattern.md) | 🔴 | Double dispatch, sealed hierarchy, vs pattern matching |
| [state-pattern.md](state-pattern.md) | 🔴 | State machine, transitions, vs enum+switch, Stateless |
| [specification-pattern.md](specification-pattern.md) | 🔴 | `ISpecification<T>`, composite specs, EF Core integration |

### §6 Domain-Driven Design Basics

| File | Difficulty | Topic |
|---|---|---|
| [ddd-core-concepts.md](ddd-core-concepts.md) | 🟢 | Ubiquitous language, bounded context, strategic vs tactical |
| [entity-vs-value-object.md](entity-vs-value-object.md) | 🟢 | Identity-based vs structural equality, record as VO |
| [repository-pattern.md](repository-pattern.md) | 🟡 | Repository interface, hiding persistence, generic vs typed |
| [domain-service.md](domain-service.md) | 🟡 | When logic doesn't belong to entity/VO, stateless services |
| [ubiquitous-language-in-code.md](ubiquitous-language-in-code.md) | 🟡 | Naming after domain terms, anti-corruption layer |
| [ddd-layers-and-clean-arch.md](ddd-layers-and-clean-arch.md) | 🟡 | DDD layers mapped to Clean Architecture |
| [value-object-implementation.md](value-object-implementation.md) | 🟡 | `IEquatable<T>`, records, collection wrapping, validation |
| [aggregate-pattern.md](aggregate-pattern.md) | 🔴 | Aggregate root, consistency boundary, invariant enforcement |
| [domain-events.md](domain-events.md) | 🔴 | Domain vs integration events, raising, dispatching, MediatR |
| [aggregate-design-guidelines.md](aggregate-design-guidelines.md) | 🔴 | Small aggregates, eventual consistency, compensation |
| [bounded-context-integration.md](bounded-context-integration.md) | 🔴 | Context map: shared kernel, ACL, open host, published language |
| [cqrs-and-ddd.md](cqrs-and-ddd.md) | 🔴 | CQRS from DDD, read vs write model, eventual consistency |

### §7 Functional Patterns in C#

| File | Difficulty | Topic |
|---|---|---|
| [pure-functions-and-side-effects.md](pure-functions-and-side-effects.md) | 🟢 | Pure functions, referential transparency, testability |
| [extension-methods.md](extension-methods.md) | 🟢 | Extension method mechanics, OCP tool, LINQ pattern |
| [immutability-in-csharp.md](immutability-in-csharp.md) | 🟢 | `readonly`, `init`, records, `ImmutableList<T>` |
| [result-pattern.md](result-pattern.md) | 🟡 | `Result<T>`, railway-oriented programming, vs exceptions |
| [option-type.md](option-type.md) | 🟡 | `Option<T>`/`Maybe<T>`, nullable reference types, null safety |
| [pattern-matching-oop.md](pattern-matching-oop.md) | 🟡 | Switch expressions, type/property/list patterns (C# 8–12) |
| [functional-composition.md](functional-composition.md) | 🟡 | Method chaining, LINQ pipeline, monad-like patterns |
| [expression-trees.md](expression-trees.md) | 🔴 | `Expression<Func<T>>` vs `Func<T>`, LINQ providers, ORM |
| [discriminated-unions-csharp.md](discriminated-unions-csharp.md) | 🔴 | DU via class hierarchy, OneOf library, future union types |
| [higher-order-functions-csharp.md](higher-order-functions-csharp.md) | 🔴 | Currying, partial application, `Func` composition |

### §8 Generics & Type-Level Patterns

| File | Difficulty | Topic |
|---|---|---|
| [generics-fundamentals.md](generics-fundamentals.md) | 🟢 | Type parameters, inference, open vs closed generics, reification |
| [generic-constraints.md](generic-constraints.md) | 🟡 | `where T : new()`, `struct`, `class`, `unmanaged`, interface |
| [generic-patterns.md](generic-patterns.md) | 🟡 | Generic repository, result, open-generic DI, CRTP |
| [options-pattern.md](options-pattern.md) | 🟡 | `IOptions<T>`, `IOptionsSnapshot`, `IOptionsMonitor`, validation |
| [pipeline-pattern.md](pipeline-pattern.md) | 🟡 | Middleware pipeline, `IMiddleware`, generic pipeline behavior |
| [source-generators-in-design.md](source-generators-in-design.md) | 🔴 | Source generators as code-gen alternative to reflection |
| [open-generic-registration.md](open-generic-registration.md) | 🔴 | Open-generic DI registration, decorator chaining |
| [type-safe-builder-pattern.md](type-safe-builder-pattern.md) | 🔴 | Phantom types, type-state builder, compile-time enforcement |

### §9 Anti-Patterns & Code Smells

| File | Difficulty | Topic |
|---|---|---|
| [god-class-anti-pattern.md](god-class-anti-pattern.md) | 🟢 | God object, low cohesion, extract class refactoring |
| [spaghetti-and-big-ball-of-mud.md](spaghetti-and-big-ball-of-mud.md) | 🟢 | Unstructured codebase, accidental complexity, strangler fig |
| [anemic-domain-model.md](anemic-domain-model.md) | 🟡 | Anemic vs rich domain model, service bloat, DDD view |
| [primitive-obsession.md](primitive-obsession.md) | 🟡 | Primitives for domain concepts, value object refactoring |
| [law-of-demeter.md](law-of-demeter.md) | 🟡 | Tell Don't Ask, method chaining vs LoD, coupling impact |
| [shotgun-surgery.md](shotgun-surgery.md) | 🟡 | Scattered change smell, SRP violation, fix |
| [service-locator-anti-pattern.md](service-locator-anti-pattern.md) | 🟡 | Service locator vs DI, hidden dependencies, testability |
| [over-engineering-and-yagni.md](over-engineering-and-yagni.md) | 🔴 | YAGNI, premature abstraction, when simplicity wins |
| [refactoring-to-patterns.md](refactoring-to-patterns.md) | 🔴 | When GoF pattern solves a smell, incremental refactoring |