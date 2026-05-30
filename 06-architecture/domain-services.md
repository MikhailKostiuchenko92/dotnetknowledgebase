# Domain Services

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `domain-service`, `aggregate`, `application-service`, `stateless`, `business-logic`

## Question

> What is a Domain Service in DDD? When should logic live in a Domain Service rather than in an aggregate entity? How do you distinguish between a Domain Service and an Application Service?

## Short Answer

A **Domain Service** is a stateless operation that belongs in the domain layer but doesn't naturally fit on a single entity or value object. It expresses a business operation in the Ubiquitous Language and typically coordinates multiple domain objects. It does **not** access infrastructure (no DB calls, no HTTP). An **Application Service** (or handler) orchestrates use cases across domain objects and infrastructure — it calls repositories, dispatches events, sends emails. The distinction: if removing the class would lose a business concept, it's a Domain Service; if it just wires things together, it's an Application Service.

## Detailed Explanation

### Why Domain Services Exist

Some business operations don't belong on a single entity:
- **Span multiple aggregates**: comparing prices across multiple `Product` objects
- **Require external domain knowledge that no entity owns**: calculating shipping cost based on `Order` + destination + carrier rules
- **Would make an entity depend on another**: `Order.ReserveInventory(inventory)` would give `Order` a reference to `Inventory`, coupling two aggregates

The domain service encapsulates this cross-entity logic while keeping it in the domain layer.

### Domain Service Characteristics

| Characteristic | Value |
|----------------|-------|
| Location | Domain layer |
| State | Stateless |
| Dependencies | Other domain objects, domain interfaces (no infrastructure) |
| Naming | Expresses domain concept: `PricingService`, `ShippingCostCalculator`, `TransferService` |
| Output | Domain objects, value objects, or domain events |
| What it's NOT | A service that calls EF Core, sends HTTP requests, or handles app workflow |

### Domain Service vs Application Service vs Infrastructure Service

```
Layer          | Class example                  | What it does
──────────────────────────────────────────────────────────────────
Domain         | PricingService                 | Calculates price from domain rules (pure logic)
Application    | PlaceOrderHandler              | Orchestrates: load → domain → save → notify
Infrastructure | SendGridEmailSender             | Sends email via SendGrid API
```

**Rule of thumb**: If it needs `IOrderRepository` (infrastructure), it's Application. If it only needs other domain objects, it's a Domain Service.

### When to Use a Domain Service

```csharp
// ❌ BAD: Logic on aggregate that shouldn't be there
// Order shouldn't know about Inventory — coupling two aggregates
public class Order
{
    public void CalculateShipping(Inventory inventory, ShippingRates rates)
    {
        // Order now depends on both Inventory and ShippingRates concepts
    }
}

// ✅ GOOD: Stateless Domain Service encapsulating cross-entity logic
// Named using UL: ShippingCostCalculator
public class ShippingCostCalculator
{
    public Money Calculate(Order order, ShippingAddress destination, IEnumerable<CarrierRate> rates)
    {
        var weight = order.Lines.Sum(l => l.Product.WeightKg * l.Quantity);
        var baseRate = destination.IsRemote ? rates.Max(r => r.RatePerKg) 
                                            : rates.Min(r => r.RatePerKg);
        return new Money(weight * baseRate, "USD");
    }
}
```

### Classic DDD Example: Transfer Service

The canonical example from Evans — transferring money between two `Account` aggregates. Neither account should do the transfer because the operation involves both:

```csharp
// Domain Service: MoneyTransferService
public class MoneyTransferService
{
    public void Transfer(Account source, Account destination, Money amount)
    {
        // Business invariant: source must have sufficient funds
        if (source.Balance < amount)
            throw new InsufficientFundsException(source.Id, amount);

        source.Debit(amount);
        destination.Credit(amount);

        // Domain events are raised inside Debit/Credit
    }
}

// Application handler: orchestrates repos + domain service
public class TransferFundsHandler(
    IAccountRepository accounts,
    MoneyTransferService transferService) : IRequestHandler<TransferFundsCommand>
{
    public async Task Handle(TransferFundsCommand cmd, CancellationToken ct)
    {
        var source = await accounts.GetByIdAsync(cmd.SourceAccountId, ct) ?? throw new NotFoundException();
        var destination = await accounts.GetByIdAsync(cmd.DestinationAccountId, ct) ?? throw new NotFoundException();

        transferService.Transfer(source, destination, cmd.Amount); // domain logic

        await accounts.SaveAsync(source, ct);       // infrastructure
        await accounts.SaveAsync(destination, ct);  // infrastructure
    }
}
```

### Naming Domain Services

Good domain service names come from the Ubiquitous Language:
- `PricingEngine` — not `PriceCalculator` or `PriceService`
- `TaxCalculator` — not `TaxService`
- `RiskAssessor` — not `RiskService`
- `FulfillmentCoordinator` — not `FulfillmentService`

Avoid the word "Service" when a more expressive name exists.

## Code Example

```csharp
// Domain layer: discount eligibility — logic spans Customer + Order concepts
public class DiscountEligibilityChecker
{
    public DiscountOffer CalculateDiscount(Customer customer, Order order)
    {
        // Rule 1: Loyal customers get 10% off orders over $500
        if (customer.LoyaltyTier == LoyaltyTier.Gold && order.Total > new Money(500))
            return DiscountOffer.Percentage(10);

        // Rule 2: First order for any customer is free shipping
        if (customer.OrderCount == 0)
            return DiscountOffer.FreeShipping;

        // Rule 3: Bulk orders (>10 lines) get 5% discount
        if (order.Lines.Count > 10)
            return DiscountOffer.Percentage(5);

        return DiscountOffer.None;
    }
}

// Application handler uses the domain service
public class PlaceOrderHandler(
    IOrderRepository orders,
    ICustomerRepository customers,
    DiscountEligibilityChecker discountChecker) : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var customer = await customers.GetByIdAsync(cmd.CustomerId, ct) ?? throw new NotFoundException();
        var order = Order.Draft(cmd.CustomerId, cmd.Lines);

        // Domain service: pure logic, no infrastructure calls
        var discount = discountChecker.CalculateDiscount(customer, order);
        order.ApplyDiscount(discount);

        await orders.AddAsync(order, ct);
        return order.Id.Value;
    }
}
```

## Common Follow-up Questions

- Can a Domain Service be injected into an aggregate? (Generally no — why?)
- How do you test a Domain Service in isolation?
- When does a Domain Service become an Application Service (and how do you detect the drift)?
- Is a Factory considered a Domain Service in DDD?
- How do you handle a Domain Service that needs a value from a repository to calculate (e.g., current tax rate)?

## Common Mistakes / Pitfalls

- **Anemic service that's just a wrapper**: a `CustomerService` with `GetById`, `Save`, `Update`, `Delete` is an Application Service pattern — it's not a Domain Service expressing a business operation.
- **Domain Service with infrastructure injection**: if your `PricingService` takes `IProductRepository` in its constructor to load prices, it belongs in the Application layer, not the Domain layer.
- **Fat domain service**: a `OrderProcessingDomainService` with 15 methods covering all order operations is just an anemic model with extra steps. Push behavior back onto the aggregates.
- **Overusing domain services for single-entity operations**: if the logic only touches one entity (`order.Cancel()`), it belongs on the entity. Domain Services are for operations that span multiple domain objects.

## References

- [Domain Services — Microsoft Architecture Microservices Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Domain Services vs Application Services — Nick Tune (DDD Crew)](https://nick-tune.me/posts/domain-service-vs-application-service/) (verify URL)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: application-layer-responsibilities.md](./application-layer-responsibilities.md)
- [See: domain-layer-design.md](./domain-layer-design.md)
