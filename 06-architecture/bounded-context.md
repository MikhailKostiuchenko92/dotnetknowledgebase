# Bounded Context

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `bounded-context`, `context-map`, `ubiquitous-language`, `model-boundary`, `strategic-DDD`

## Question

> What is a Bounded Context in DDD? Why does the same term (e.g., "Customer") mean different things in different contexts, and how do you identify context boundaries in a real system?

## Short Answer

A **Bounded Context** is the boundary within which a particular domain model is internally consistent and the Ubiquitous Language applies without ambiguity. Outside the boundary, the same word can mean something different — "Customer" in the Orders context is a lightweight reference with name and ID, while "Customer" in the CRM context is a full entity with contact history, loyalty tier, and preferences. Identifying boundaries requires recognising when the same word triggers a different conversation with domain experts from different departments — those department boundaries usually correspond to bounded context boundaries.

## Detailed Explanation

### Why the Same Word Means Different Things

In a large company:

| Context | "Customer" means |
|---------|-----------------|
| **CRM** | Full profile: contacts, history, preferences, loyalty tier |
| **Orders** | A buyer reference: ID + name + shipping address for this order |
| **Billing** | A payer: ID + payment method + invoice history |
| **Shipping** | A recipient: ID + delivery address + contact number |

These are all the same real person — but each context only cares about specific attributes and operations. Forcing one universal `Customer` model to satisfy all four contexts creates a bloated object that no single context can evolve independently.

### Bounded Context vs Subdomain

| Concept | What it is |
|---------|-----------|
| **Subdomain** | Part of the problem space (what the business does) |
| **Bounded Context** | Part of the solution space (how software is structured) |

Ideally one subdomain → one bounded context. In practice:
- A legacy system may have multiple subdomains crammed into one context
- One team may manage multiple related contexts
- A generic subdomain (auth) may be served by an external product

### Identifying Context Boundaries

Signals that you've hit a context boundary:
- The same word triggers a different conversation with two different department experts
- Two teams argue about what a field on a shared entity means
- A change in one area consistently requires changes in another (coupling smell)
- A separate database schema, separate deployment, or separate team owns data

### Practical Approach: Event Storming

Event Storming workshops with domain experts surface context boundaries:
1. Write domain events on sticky notes ("Order Placed", "Payment Cleared", "Shipment Dispatched")
2. Group events into sequences
3. Look for **pivot events** — events that one group produces and another group consumes
4. The pivot event boundaries often correspond to context boundaries

### Context Map

Document how contexts integrate:

```
┌──────────────────────────────────────────────────────────────┐
│                        Context Map                            │
│                                                              │
│  ┌──────────────┐  OrderPlaced    ┌─────────────────────┐   │
│  │    Orders    │ ──────────────→ │     Inventory       │   │
│  │   Context    │                 │      Context        │   │
│  └──────────────┘                 └─────────────────────┘   │
│         │ OrderSubmitted                    │ Allocated      │
│         ↓                                   ↓               │
│  ┌──────────────┐                 ┌─────────────────────┐   │
│  │   Payments   │                 │     Shipping        │   │
│  │   Context    │                 │      Context        │   │
│  └──────────────┘                 └─────────────────────┘   │
│                                                              │
│  Integration: Domain Events over message bus                 │
└──────────────────────────────────────────────────────────────┘
```

### Bounded Context in .NET Solution Structure

```
src/
  Orders/
    YourApp.Orders.Domain/     ← Order, OrderLine, CustomerId (lightweight VO)
    YourApp.Orders.Application/
    YourApp.Orders.Infrastructure/
  Crm/
    YourApp.Crm.Domain/        ← Customer (full entity with CRM attributes)
    YourApp.Crm.Application/
    YourApp.Crm.Infrastructure/
  Billing/
    YourApp.Billing.Domain/    ← Payer, Invoice (billing-specific Customer)
    ...
```

Each context has its own database schema or database.

## Code Example

```csharp
// WRONG: One "universal" Customer trying to serve all contexts
public class Customer
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string Email { get; set; } = "";
    // CRM fields
    public string LoyaltyTier { get; set; } = "";
    public List<Interaction> ContactHistory { get; set; } = [];
    // Billing fields
    public string PaymentMethodToken { get; set; } = "";
    public List<Invoice> Invoices { get; set; } = [];
    // Shipping fields
    public string PreferredCarrier { get; set; } = "";
    public List<Address> DeliveryAddresses { get; set; } = [];
    // 30 more fields... each context polluting the others
}

// CORRECT: Each context has its own representation
// Orders context — Customer is a lightweight reference
namespace YourApp.Orders.Domain
{
    public record CustomerId(int Value);
    public record CustomerSnapshot(CustomerId Id, string Name, Address ShippingAddress);

    public class Order
    {
        public CustomerId CustomerId { get; private set; }
        public CustomerSnapshot CustomerAtOrderTime { get; private set; } = null!;
        // Orders context only cares about: ID + name + address at time of order
    }
}

// CRM context — Customer is a full entity
namespace YourApp.Crm.Domain
{
    public class Customer : AggregateRoot
    {
        public CustomerId Id { get; private set; }
        public PersonalInfo PersonalInfo { get; private set; } = null!;
        public LoyaltyTier LoyaltyTier { get; private set; } = LoyaltyTier.Bronze;
        private readonly List<Interaction> _history = [];
        public IReadOnlyList<Interaction> History => _history;

        public void RecordInteraction(Interaction interaction)
        {
            _history.Add(interaction);
            if (_history.Count % 10 == 0) PromoteLoyaltyTier(); // business rule
        }
    }
}
```

## Common Follow-up Questions

- How large should a bounded context be — one microservice, one module, or something else?
- How do you handle a query that needs data from two bounded contexts (e.g., order list showing CRM customer tier)?
- What is the difference between a bounded context and a microservice?
- How do you map an existing monolith's boundaries to find hidden bounded contexts?
- When is it acceptable to have two bounded contexts share a database?

## Common Mistakes / Pitfalls

- **Confusing bounded context with a database table or microservice**: a bounded context is a conceptual boundary — it might be a module in a monolith, a separate service, or even a folder in a single project.
- **The universal model anti-pattern**: building one `Customer` class used across Orders, CRM, Billing, and Shipping means every context's requirements collide. Any change for one context risks breaking another.
- **Context boundaries that don't match team boundaries**: Conway's Law predicts that software systems mirror the communication structure of the teams that build them. Mismatched context-team boundaries create hidden integration complexity.
- **Overfine context boundaries**: one bounded context per aggregate leads to hundreds of tiny services with massive integration overhead. A context should cover a meaningful business capability, not a single database table.

## References

- [Bounded Contexts — Martin Fowler](https://martinfowler.com/bliki/BoundedContext.html) (verify URL)
- [Strategic Domain-Driven Design — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/architect-microservice-container-applications/identify-microservice-domain-model-boundaries)
- [See: ddd-tactical-vs-strategic.md](./ddd-tactical-vs-strategic.md)
- [See: context-mapping-patterns.md](./context-mapping-patterns.md)
- [See: anticorruption-layer.md](./anticorruption-layer.md)
