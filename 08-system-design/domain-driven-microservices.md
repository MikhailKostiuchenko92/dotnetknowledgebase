# Domain-Driven Microservices

**Category:** System Design / Microservices
**Difficulty:** Senior
**Tags:** `ddd`, `bounded-context`, `microservices`, `anti-corruption-layer`, `shared-kernel`, `ubiquitous-language`

## Question

> How does Domain-Driven Design guide microservice boundaries? What is a bounded context, and why does it matter for service decomposition? When would you use an anti-corruption layer (ACL)?

- How do you handle the "shared kernel" problem when two services need the same concept?
- What is the difference between strategic and tactical DDD, and which is more important for microservices?

## Short Answer

**Strategic DDD** defines microservice boundaries: each microservice owns exactly one **bounded context** — a cohesive domain model with its own ubiquitous language, data, and team. Bounded contexts avoid the "big ball of mud" where a single `Customer` entity means different things to billing, shipping, and marketing. When one service must talk to a legacy system or a foreign bounded context with an incompatible model, an **anti-corruption layer (ACL)** translates between models, protecting the local domain from external pollution. Tactical patterns (aggregates, repositories, domain events) help implement the model cleanly but are secondary to getting the boundaries right.

## Detailed Explanation

### Strategic vs Tactical DDD

| | Strategic DDD | Tactical DDD |
|--|---------------|-------------|
| **Focus** | Boundaries, relationships between contexts | Implementation patterns within a context |
| **Artefacts** | Context map, bounded contexts, subdomains | Aggregates, entities, value objects, domain events |
| **Importance for microservices** | Critical — wrong boundaries are expensive | Secondary — can evolve internally |
| **Tools** | Event Storming, context mapping workshops | Code patterns (Repository, Factory, Domain Service) |

> Getting boundaries wrong is an architectural mistake that requires team coordination and data migration to fix. Get the model wrong tactically and you refactor your C# classes. The stakes are very different.

### Bounded Context

A bounded context is a linguistic boundary within which a domain model applies consistently. The same real-world concept can have different meanings across contexts:

| Context | "Customer" Means |
|---------|-----------------|
| CRM | A prospect or lead with contact info and sales stage |
| Billing | An entity with payment methods and outstanding invoices |
| Shipping | A delivery address and notification preferences |
| Support | A ticket history and SLA tier |

Each bounded context has its own:
- **Ubiquitous language**: terms defined precisely for that context
- **Data model**: its own database, not shared with other contexts
- **API boundary**: communicates with other contexts via explicit contracts (REST, events)
- **Team ownership**: one team owns one or two contexts end-to-end

### Context Map Relationships

When bounded contexts must interact, their relationship is defined in a **context map**:

| Relationship | Description | .NET Pattern |
|-------------|-------------|-------------|
| **Shared Kernel** | Two contexts share a small common model (both teams agree to co-own) | Shared NuGet package / common types library |
| **Customer/Supplier** | Upstream (supplier) publishes; downstream (customer) adapts to its model | OpenAPI contract; customer writes adapter |
| **Conformist** | Downstream conforms exactly to upstream model (no negotiation) | Use upstream DTOs directly |
| **Anti-Corruption Layer** | Downstream translates upstream model into its own | ACL interface + mapper |
| **Open Host Service** | Upstream publishes a stable, versioned API for many consumers | Well-documented REST/gRPC API |
| **Published Language** | Upstream defines a formal shared language (e.g., CloudEvents schema) | JSON Schema / Protobuf |

### Anti-Corruption Layer (ACL)

An ACL is a translation layer that prevents an external model's concepts and terminology from "leaking" into your bounded context.

**When to use**:
- Integrating with a legacy system that has a poor or different domain model
- Consuming a third-party API (payment gateway, ERP, CRM)
- A downstream team whose model is in flux and you don't want to be affected by every change

```
External Payment Gateway (uses "Transaction", "Merchant", "Acquirer")
           ↓
   [Anti-Corruption Layer]  ← translates to your domain language
           ↓
 Internal Billing Context (uses "Payment", "Seller", "PaymentProvider")
```

The ACL is typically an interface in your domain with an infrastructure-layer implementation:

```csharp
// Domain interface (your language)
namespace Billing.Domain.Ports;

public interface IPaymentGateway
{
    Task<PaymentResult> ChargeAsync(Payment payment, CancellationToken ct);
}

// ACL implementation (translates to external system's language)
namespace Billing.Infrastructure.Adapters;

public sealed class StripePaymentGateway(StripeClient stripe) : IPaymentGateway
{
    public async Task<PaymentResult> ChargeAsync(Payment payment, CancellationToken ct)
    {
        // Translate: your "Payment" → Stripe's "PaymentIntent"
        var intent = await stripe.PaymentIntents.CreateAsync(new PaymentIntentCreateOptions
        {
            Amount   = payment.Amount.Cents,
            Currency = payment.Amount.Currency.ToLowerInvariant(),
            Metadata = new Dictionary<string, string> { ["orderId"] = payment.OrderId.ToString() },
        }, cancellationToken: ct);

        // Translate back: Stripe's result → your "PaymentResult"
        return intent.Status == "succeeded"
            ? PaymentResult.Success(intent.Id)
            : PaymentResult.Failure(intent.LastPaymentError?.Message ?? "Unknown");
    }
}
```

### Domain Events as Context Integration

Bounded contexts should communicate asynchronously via **domain events** rather than synchronous API calls where possible. This decouples their deployment lifecycles and prevents cascading failures.

```
Orders Context:          OrderPlaced event → Kafka topic: orders
                                                 ↓
Inventory Context:                    consumes OrderPlaced → ReserveInventory command
                                                 ↓
Shipping Context:                     consumes InventoryReserved → CreateShipment command
```

Each context translates the incoming event into its own language (conformist or ACL depending on model alignment).

### Subdomains: Core, Supporting, Generic

Not all bounded contexts deserve equal engineering investment:

| Subdomain | Description | Strategy |
|-----------|-------------|----------|
| **Core** | What makes the business unique; competitive advantage | Custom-built, DDD patterns, best engineers |
| **Supporting** | Needed but not differentiating (reporting, notifications) | Build simply or extract from core |
| **Generic** | Commodity (auth, billing, email) | Buy (SaaS) or use open-source |

**Principle**: spend DDD investment where it counts — the core domain. Use a CRUD service for supporting domains; buy SaaS for generic ones.

## Code Example

```csharp
// Bounded context: Orders — its own "Customer" concept
// Note: no dependency on Billing.Customer or CRM.Customer

namespace Orders.Domain;

// Value object: only what Orders cares about
public sealed record OrderCustomer(
    Guid Id,
    string DisplayName,    // "John D." — enough for order confirmation
    string Email);         // for receipt

public sealed class Order
{
    public Guid Id            { get; private set; }
    public OrderCustomer Customer { get; private set; }
    public IReadOnlyList<OrderLine> Lines { get; private set; } = [];
    public OrderStatus Status { get; private set; }

    // Domain event — published when order is placed
    private readonly List<IDomainEvent> _events = new();
    public IReadOnlyList<IDomainEvent> DomainEvents => _events;

    public static Order Place(OrderCustomer customer, IList<OrderLine> lines)
    {
        if (lines.Count == 0)
            throw new DomainException("An order must have at least one line.");

        var order = new Order
        {
            Id       = Guid.NewGuid(),
            Customer = customer,
            Lines    = lines.ToList(),
            Status   = OrderStatus.Pending,
        };

        order._events.Add(new OrderPlacedEvent(order.Id, customer.Id,
            lines.Sum(l => l.TotalCents)));
        return order;
    }

    public void Confirm()
    {
        if (Status != OrderStatus.Pending)
            throw new DomainException("Only pending orders can be confirmed.");
        Status = OrderStatus.Confirmed;
        _events.Add(new OrderConfirmedEvent(Id));
    }
}

// ACL: map CRM Customer → Orders OrderCustomer
public sealed class CrmCustomerAdapter(ICrmService crm) : ICustomerPort
{
    public async Task<OrderCustomer> GetAsync(Guid customerId, CancellationToken ct)
    {
        var crmCustomer = await crm.GetContactAsync(customerId, ct); // CRM model
        return new OrderCustomer(
            crmCustomer.ContactId,           // CRM: ContactId → Orders: Id
            crmCustomer.FullName.Split(' ')[0] + " " + crmCustomer.FullName.Split(' ')[^1][..1] + ".",
            crmCustomer.PrimaryEmail);       // CRM: PrimaryEmail → Orders: Email
    }
}
```

## Common Follow-up Questions

- How do you handle a query that needs to join data from two bounded contexts (e.g., order with customer billing address)?
- What is Event Storming and how does it help discover bounded context boundaries?
- Two teams disagree on where a bounded context boundary should be. How do you resolve this?
- How does the Aggregate pattern enforce invariants within a bounded context?
- When should a bounded context be a separate microservice vs a module within a modular monolith?

## Common Mistakes / Pitfalls

- **One entity = one service** (`CustomerService`, `OrderService`, `ProductService`): these are table-per-service, not bounded contexts. True contexts span multiple related entities.
- **Sharing domain objects across contexts**: putting `Customer` in a `Common.dll` shared by all services creates an implicit coupling that defeats the purpose of bounded contexts.
- **Skipping strategic DDD and jumping to tactical patterns**: building perfect aggregates in a monolith with wrong boundaries doesn't help; boundaries matter more than patterns.
- **Synchronous cross-context calls for core flows**: `OrderService` calling `InventoryService` synchronously couples their availability; prefer domain events for cross-context coordination.
- **ACL in the wrong layer**: the ACL is an infrastructure concern; domain interfaces should be in the domain layer, ACL implementations in the infrastructure layer.
- **Mixing languages across teams without a context map**: two teams using "product" to mean different things leads to silent integration bugs; make the context map explicit.

## References

- [Domain-Driven Design — Eric Evans (book)](https://www.dddcommunity.org/book/evans_2003/)
- [Implementing Domain-Driven Design — Vaughn Vernon (book)](https://vaughnvernon.co/?page_id=168) (verify URL)
- [.NET Microservices Architecture — DDD Chapter](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/)
- [Event Storming — Alberto Brandolini](https://www.eventstorming.com/)
- [See: monolith-vs-microservices.md](./monolith-vs-microservices.md)
- [See: event-driven-architecture.md](./event-driven-architecture.md)
