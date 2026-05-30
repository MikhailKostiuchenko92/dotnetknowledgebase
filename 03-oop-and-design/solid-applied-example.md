# SOLID Applied: Refactoring a Legacy C# Class

**Category:** OOP & Design / SOLID
**Difficulty:** 🟡 Middle
**Tags:** `SOLID`, `refactoring`, `OOP`

## Question
> Can you walk through a real C# refactoring where one legacy class violates all five SOLID principles?

## Short Answer
A legacy “do everything” service often breaks SRP, OCP, DIP, and ISP immediately, and it usually drags LSP problems in through bad inheritance or fake implementations. The refactoring path is to identify responsibilities, extract abstractions around true variation points, replace condition-heavy logic with strategies, and narrow contracts to real client needs. The result is not just prettier code; it is easier testing, safer extension, and fewer change collisions.

## Detailed Explanation
### The legacy shape
Imagine a `LegacyOrderProcessor` that validates an order, calculates discounts with a `switch`, saves directly through SQL code, sends email, exports CSV, and depends on a broad `IOrderInfrastructure` interface. It may also use subclasses like `NoDiscountProcessor` that throw for some scenarios. That single class becomes the place where every change lands.

This design violates all five SOLID principles:

| Principle | Legacy problem |
| --- | --- |
| SRP | One class owns validation, pricing, persistence, and notifications |
| OCP | New discount or channel requires editing the same class |
| LSP | Subclasses or implementations cannot honor the expected behavior |
| ISP | Consumers depend on methods like export/email/save even if they need one |
| DIP | High-level workflow depends on concrete SQL and email details |

### Step 1: fix SRP by separating responsibilities
The first move is usually SRP because it exposes the real seams. Split validation into `IOrderValidator`, persistence into `IOrderRepository`, and notifications into `INotificationSender`. Keep a thin `OrderService` that orchestrates the use case.

This gives you cohesive units and makes the code easier to test. Instead of one giant test covering validation + discount + database + email, you can test each behavior independently.

### Step 2: fix OCP by extracting a variation point
Legacy classes usually hide OCP violations in `if`/`switch` blocks. If discount calculation changes by customer type, that is a variation point. Replace the conditional with `IDiscountStrategy` implementations. The service now works with a collection of strategies and selects the right one at runtime.

That means adding a new discount no longer requires modifying the stable orchestration class.

### Step 3: fix DIP by depending on abstractions
Once responsibilities are separated, the orchestration service should depend on abstractions instead of concrete infrastructure. `OrderService` should not know whether persistence uses EF Core, Dapper, or an API. It should only know it needs to save an order. In ASP.NET Core, the DI container can compose those pieces, but the principle is in the constructor signatures and dependency direction.

### Step 4: fix ISP by narrowing contracts
A broad `IOrderInfrastructure` or `IOrderManager` is a sign that the design is organized around convenience rather than clients. Split those contracts by role: `IOrderRepository`, `INotificationSender`, `IOrderValidator`, maybe `IOrderExporter` if a different use case needs export. That keeps each consumer coupled only to the behavior it actually uses.

### Step 5: fix LSP by making contracts honest
LSP often fails when a subtype exists just to reuse code but cannot truly honor the contract. Maybe `TrialDiscountStrategy` throws on enterprise orders, or a subclassed processor silently skips notifications. The fix is to redesign the abstraction so each implementation can satisfy it. Narrow, capability-based interfaces usually help more than inheritance.

> Warning: do not “fix” SOLID by creating dozens of empty wrapper interfaces. The abstractions should represent real responsibilities and real variation points.

### Trade-offs and when to stop
This refactoring introduces more types and more wiring. That is acceptable when the original class is a frequent change hotspot. But if a workflow is genuinely tiny and stable, the full SOLID treatment can be too much. The goal is not to maximize pattern count; it is to reduce change friction around known axes of variation.

A strong interview answer shows the order of refactoring: split responsibilities, find variation points, invert dependencies, narrow interfaces, and validate contracts. That demonstrates design thinking rather than memorized slogans.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace OopAndDesign.SolidAppliedSample;

/*
Before refactoring, a LegacyOrderProcessor often looked like this:
- Validate input inline
- switch(customerType) to calculate discounts
- new SqlConnection(...) and save directly
- send email directly
- maybe implement unrelated export/report methods too
That single class violates SRP, OCP, ISP, and DIP, and usually encourages LSP problems.
*/

public sealed record Order(int Id, decimal Total, string CustomerType, string Email);

public interface IOrderValidator
{
    void Validate(Order order);
}

public interface IDiscountStrategy
{
    string CustomerType { get; }
    decimal Apply(decimal total);
}

public interface IOrderRepository
{
    void Save(Order order, decimal finalTotal);
}

public interface INotificationSender
{
    void Send(string email, string message);
}

public sealed class OrderValidator : IOrderValidator
{
    public void Validate(Order order)
    {
        if (order.Total <= 0)
        {
            throw new ArgumentException("Order total must be positive.");
        }

        if (string.IsNullOrWhiteSpace(order.Email))
        {
            throw new ArgumentException("Email is required.");
        }
    }
}

public sealed class RegularDiscountStrategy : IDiscountStrategy
{
    public string CustomerType => "Regular";
    public decimal Apply(decimal total) => total;
}

public sealed class VipDiscountStrategy : IDiscountStrategy
{
    public string CustomerType => "VIP";
    public decimal Apply(decimal total) => total * 0.90m;
}

public sealed class ConsoleOrderRepository : IOrderRepository
{
    public void Save(Order order, decimal finalTotal)
    {
        Console.WriteLine($"Saved order {order.Id} with final total {finalTotal:C}.");
    }
}

public sealed class ConsoleNotificationSender : INotificationSender
{
    public void Send(string email, string message)
    {
        Console.WriteLine($"To {email}: {message}");
    }
}

public sealed class OrderService(
    IOrderValidator validator,
    IEnumerable<IDiscountStrategy> discountStrategies,
    IOrderRepository repository,
    INotificationSender notificationSender)
{
    private readonly Dictionary<string, IDiscountStrategy> _discounts =
        discountStrategies.ToDictionary(strategy => strategy.CustomerType, StringComparer.OrdinalIgnoreCase);

    public void Process(Order order)
    {
        validator.Validate(order); // SRP

        if (!_discounts.TryGetValue(order.CustomerType, out var strategy))
        {
            throw new InvalidOperationException($"No discount strategy for '{order.CustomerType}'.");
        }

        var finalTotal = strategy.Apply(order.Total); // OCP + LSP via honest strategy contract
        repository.Save(order, finalTotal);           // DIP through abstraction
        notificationSender.Send(order.Email, $"Your final total is {finalTotal:C}.");
    }
}

public static class Program
{
    public static void Main()
    {
        var service = new OrderService(
            new OrderValidator(),
            [new RegularDiscountStrategy(), new VipDiscountStrategy()],
            new ConsoleOrderRepository(),
            new ConsoleNotificationSender());

        service.Process(new Order(1001, 200m, "VIP", "customer@example.com"));
    }
}
```

## Common Follow-up Questions
- In what order would you apply SOLID during a real refactoring?
- How do you know when a `switch` deserves a strategy abstraction?
- Where should the interfaces live in a layered architecture?
- How do you avoid over-engineering during a SOLID refactor?
- What tests would you write before and after this refactoring?
- How does this approach map to ASP.NET Core dependency injection?

## Common Mistakes / Pitfalls
- Refactoring everything at once instead of extracting one responsibility at a time.
- Creating interfaces with technical names and no business meaning.
- Moving code into more files without actually improving cohesion or dependency direction.
- Preserving invalid subtype contracts and claiming LSP is solved because an interface exists.
- Over-abstracting stable code that does not need extension yet.

## References
- [Architectural principles for modern web applications with Azure](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Dependency injection in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection)
- [Interfaces in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)
- [Strategy pattern](https://refactoring.guru/design-patterns/strategy)
- [Shotgun Surgery code smell](https://refactoring.guru/smells/shotgun-surgery)
