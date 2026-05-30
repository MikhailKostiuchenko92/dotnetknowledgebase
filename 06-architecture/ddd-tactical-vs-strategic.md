# DDD Tactical vs Strategic Patterns

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟢 Junior
**Tags:** `DDD`, `tactical-patterns`, `strategic-patterns`, `bounded-context`, `aggregate`, `context-map`

## Question

> What is the difference between DDD strategic patterns and DDD tactical patterns? Give examples of each and explain how they relate to each other.

## Short Answer

**Strategic DDD** operates at the macro level: identifying bounded contexts (where a model is consistent), drawing context maps (how contexts relate and integrate), and establishing a ubiquitous language per context. **Tactical DDD** operates at the micro level inside a bounded context: aggregates, entities, value objects, domain events, repositories, domain services. Strategic patterns tell you *where* to draw boundaries; tactical patterns tell you *how* to model the domain inside those boundaries. Strategic comes first — tactical patterns applied inside the wrong boundaries produce the wrong model.

## Detailed Explanation

### Strategic DDD

Strategic patterns address the overall architecture of your domain:

| Pattern | Description |
|---------|-------------|
| **Bounded Context** | A boundary within which a domain model is internally consistent; same word can mean different things in different contexts |
| **Ubiquitous Language** | A shared vocabulary between developers and domain experts, expressed in code naming |
| **Context Map** | A diagram showing how bounded contexts integrate (Shared Kernel, ACL, Conformist, etc.) |
| **Subdomains** | Core domain (competitive advantage), Supporting subdomain, Generic subdomain (off-the-shelf) |

Strategic DDD is primarily about **organization and communication** — both of teams and of systems.

```
┌─────────────────────────┐    ACL    ┌─────────────────────────┐
│  Orders Bounded Context  │ ←──────→ │ Inventory Bounded Context│
│  (owns Order, Customer) │           │ (owns Product, Stock)    │
└─────────────────────────┘           └─────────────────────────┘
          ↕ events
┌─────────────────────────┐
│ Payments Bounded Context │
│ (owns Invoice, Payment)  │
└─────────────────────────┘
```

### Tactical DDD

Tactical patterns implement the domain model *inside* a bounded context:

| Pattern | Description |
|---------|-------------|
| **Entity** | Object with a unique identity; `Order`, `Customer` |
| **Value Object** | Structural equality, immutable; `Money`, `Address`, `Email` |
| **Aggregate** | A cluster of entities/VOs with one root; transactional consistency boundary |
| **Aggregate Root** | The sole entry point for the aggregate; `Order` is the root of `{Order, OrderLine}` |
| **Domain Event** | Something meaningful that happened; `OrderPlaced`, `PaymentFailed` |
| **Repository** | Abstracts persistence for an aggregate root |
| **Domain Service** | Stateless operation that doesn't belong on any single entity |
| **Factory** | Complex construction logic for aggregates |

### The Relationship Between Strategic and Tactical

Strategic patterns determine context boundaries; tactical patterns implement the model within:

```
STRATEGIC: "We have an Orders context and an Inventory context"
    ↓
TACTICAL (inside Orders context):
    Order (aggregate root)
      └── OrderLine (entity)
    Customer (entity — lightweight reference, not the full Customer from a CRM context)
    OrderPlaced (domain event)
    IOrderRepository (repository)
    Money (value object)
```

Notice: `Customer` in the **Orders context** might only hold `CustomerId` + `Name` — it's a different object than the full `Customer` in a **CRM context**. This is correct DDD — the same real-world concept has different representations in different bounded contexts.

> **Warning**: Applying tactical patterns without strategic clarity leads to "DDD spaghetti" — aggregates, repos, and value objects for a model with no clear boundaries. Strategic first, tactical second.

### Subdomain Types

Understanding subdomains helps prioritize tactical investment:

| Subdomain type | Investment | Examples |
|----------------|-----------|---------|
| **Core** | Rich domain model, DDD all the way | Order management, pricing engine, risk scoring |
| **Supporting** | Moderate — functional but not differentiating | User management, notifications, reporting |
| **Generic** | Buy off-the-shelf or use minimal code | Authentication, email delivery, PDF generation |

Don't apply heavy tactical DDD to generic subdomains — use a third-party service or a thin CRUD layer.

## Code Example

```csharp
// STRATEGIC: Separate Bounded Context models for the same "Customer" concept

// Orders Bounded Context — Customer is just a reference with name
namespace YourApp.Orders.Domain
{
    // Lightweight Customer within Orders context — not the full CRM customer
    public record CustomerId(int Value);
    public record CustomerName(string Value);

    public class Order
    {
        public OrderId Id { get; private set; }
        public CustomerId CustomerId { get; private set; }   // just an ID reference
        public CustomerName CustomerName { get; private set; } // denormalized for display
        // ... order lines, total, status
    }
}

// CRM Bounded Context — Customer is fully modelled here
namespace YourApp.Crm.Domain
{
    public class Customer
    {
        public CustomerId Id { get; private set; }
        public string FirstName { get; private set; } = string.Empty;
        public string LastName { get; private set; } = string.Empty;
        public Email Email { get; private set; } = null!;
        public Address BillingAddress { get; private set; } = null!;
        public CustomerStatus Status { get; private set; }
        // Full customer lifecycle — loyalty tiers, contact history, etc.
    }
}

// TACTICAL (inside Orders context): Aggregate + Value Object
namespace YourApp.Orders.Domain
{
    // Value Object — structural equality, immutable
    public record Money(decimal Amount, string Currency = "USD")
    {
        public static Money Zero => new(0);
        public static Money operator +(Money a, Money b) =>
            a.Currency == b.Currency ? new(a.Amount + b.Amount, a.Currency)
            : throw new InvalidOperationException("Currency mismatch");
    }

    // Aggregate root — enforces consistency boundary
    public class Order
    {
        public OrderId Id { get; private set; }
        private readonly List<OrderLine> _lines = [];
        public IReadOnlyList<OrderLine> Lines => _lines;
        public Money Total { get; private set; } = Money.Zero;

        public void AddLine(ProductId productId, int qty, Money unitPrice)
        {
            if (qty <= 0) throw new ArgumentOutOfRangeException(nameof(qty));
            _lines.Add(new OrderLine(productId, qty, unitPrice));
            Total += unitPrice * qty; // Money value object addition
        }
    }
}
```

## Common Follow-up Questions

- How do you identify bounded context boundaries in an existing legacy codebase?
- Can a single .NET project contain multiple bounded contexts?
- When should you apply tactical DDD patterns vs simple CRUD?
- How do you handle cross-context queries (e.g., showing customer name on an order list)?
- What is an Event Storming workshop, and how does it help discover bounded contexts?

## Common Mistakes / Pitfalls

- **Applying tactical DDD to generic subdomains**: spending weeks designing a rich domain model for email delivery or PDF generation that could be replaced with a library in an afternoon.
- **One aggregate per entity**: not everything needs an aggregate. `Product` in a simple catalog is just an entity with CRUD — it doesn't need aggregate root treatment unless complex invariants exist.
- **Ignoring strategic DDD**: tactical patterns applied in a monolithic model without context boundaries produce complex, tangled domain objects that try to serve multiple contexts simultaneously.
- **Confusing DDD entities with EF Core entities**: an EF Core entity is a persistence concern. A DDD entity is a domain concept with identity. They often look the same in simple apps but are fundamentally different things.

## References

- [Domain-Driven Design Reference — Eric Evans](https://www.domainlanguage.com/ddd/reference/) (verify URL)
- [Strategic DDD in practice — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/architect-microservice-container-applications/identify-microservice-domain-model-boundaries)
- [See: bounded-context.md](./bounded-context.md)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: entity-vs-value-object.md](./entity-vs-value-object.md)
