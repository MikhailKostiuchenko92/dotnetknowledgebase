# Facade Pattern

**Category:** OOP & Design / Structural Patterns
**Difficulty:** 🟡 Middle
**Tags:** `facade`, `structural`, `ACL`, `simplification`

## Question
> What is the Facade pattern, and how would you use it in a .NET application to simplify access to a complex subsystem or legacy integration?

## Short Answer
The Facade pattern provides a simple entry point to a more complex subsystem. Instead of exposing many low-level classes, the facade offers a coarse-grained API tailored to a use case. In .NET, facades often appear as application services, orchestration services, or anti-corruption layers that shield the rest of the system from legacy or infrastructure complexity.

## Detailed Explanation
### What Facade solves
Facade is a structural pattern that hides subsystem complexity behind a simpler API. The subsystem still exists, but clients do not need to know all of its moving parts, ordering rules, or error-handling details. They call one higher-level method and let the facade coordinate the rest.

This is common when a workflow touches several services: inventory, payment, shipping, notifications, auditing, and so on. Without a facade, controllers or UI code start coordinating all those pieces directly, which increases coupling and makes the calling code harder to test.

### How it works internally
A facade typically composes multiple collaborators and exposes one or more use-case-oriented methods. Internally, it decides which subsystem calls to make, in what order, and how to translate low-level responses into something the caller understands.

| Aspect | Without Facade | With Facade |
| --- | --- | --- |
| Client knowledge | Must know many subsystem types | Knows one coarse-grained API |
| Workflow orchestration | Scattered across callers | Centralized in one place |
| Change impact | Many callers break when subsystem changes | Mostly isolated behind the facade |
| Testability | Harder because callers mock many dependencies | Easier because callers mock one dependency |

A facade does not have to own business rules. Often it coordinates existing domain or infrastructure services while keeping the entry point simpler.

### Facade and anti-corruption layers
Facade is often part of an anti-corruption layer. In that context, the facade shields a clean domain model from the awkward contracts of a legacy system or third-party platform. It may combine Adapter and Facade behavior: adapt low-level DTOs and provide a simpler API at the same time.

For example, an `OrderSyncFacade` might call three old SOAP endpoints, normalize weird status codes, and return a clean application model. The rest of the codebase does not need to understand the legacy API shape.

### Application service as facade
In many .NET applications, an application service acts like a facade over domain services, repositories, and external integrations. A controller can call `CheckoutService.PlaceOrderAsync(...)` instead of orchestrating five dependencies directly. That keeps the controller thin and the use case explicit.

> Warning: a facade should simplify usage, not become a “god service.” If it absorbs business rules, persistence details, and integration logic all at once, split responsibilities.

### Trade-offs and when not to use it
Facade improves readability and protects clients from change, but it can also hide too much if designed poorly. If the facade becomes overly generic, callers may still need to know subsystem details, which defeats the point. If it becomes too broad, it turns into a dumping ground.

Do not use Facade just to wrap a single dependency with no real simplification. Also, if clients genuinely need fine-grained control over subsystem steps, a facade may be too restrictive.

Facade is different from Adapter: facade simplifies, adapter translates. In practice, one class may do a little of both, but the design intent matters.

## Code Example
```csharp
namespace OopDesignSamples;

public sealed class InventoryService
{
    public bool IsInStock(string sku) => sku == "laptop";
}

public sealed class PaymentGateway
{
    public bool Charge(string customerId, decimal amount) => amount > 0;
}

public sealed class ShippingService
{
    public string CreateShipment(string sku) => $"SHIP-{sku.ToUpperInvariant()}";
}

public sealed record CheckoutResult(bool Success, string Message);

public sealed class CheckoutFacade(
    InventoryService inventory,
    PaymentGateway payment,
    ShippingService shipping)
{
    public CheckoutResult PlaceOrder(string customerId, string sku, decimal amount)
    {
        if (!inventory.IsInStock(sku))
        {
            return new CheckoutResult(false, "Item is out of stock.");
        }

        if (!payment.Charge(customerId, amount))
        {
            return new CheckoutResult(false, "Payment failed.");
        }

        var shipmentId = shipping.CreateShipment(sku); // One simple call hides subsystem coordination.
        return new CheckoutResult(true, $"Order placed. Shipment: {shipmentId}");
    }
}

public static class Program
{
    public static void Main()
    {
        var facade = new CheckoutFacade(new InventoryService(), new PaymentGateway(), new ShippingService());
        var result = facade.PlaceOrder("cust-42", "laptop", 1499m);

        Console.WriteLine(result.Message);
    }
}
```

## Common Follow-up Questions
- How is Facade different from Adapter, Mediator, and Application Service?
- Can a facade also be part of an anti-corruption layer?
- Where should business rules live if the facade only orchestrates?
- When does a facade become a god object?
- Should controllers call the facade directly or go through another layer?

## Common Mistakes / Pitfalls
- Turning the facade into a giant service that knows too much about every subsystem.
- Hiding failures so aggressively that callers lose meaningful error information.
- Putting unrelated use cases into one facade just because they touch the same subsystem.
- Assuming Facade means “one class for the whole application.”
- Confusing simplification with translation and accidentally mixing Facade and Adapter without intent.

## References
- [Facade](https://refactoring.guru/design-patterns/facade)
- [Anti-Corruption Layer pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer)
- [Architectural principles](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
