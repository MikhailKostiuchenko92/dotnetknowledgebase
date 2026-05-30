# Single Responsibility Principle (SRP)

**Category:** OOP & Design / SOLID
**Difficulty:** 🟢 Junior
**Tags:** `SRP`, `SOLID`, `cohesion`, `refactoring`

## Question
> What is the Single Responsibility Principle, and how would you refactor a God class in C# to follow it?

## Short Answer
The Single Responsibility Principle says a class should have one reason to change, not just one method. In practice, that means a class should focus on one cohesive responsibility instead of mixing validation, business rules, persistence, logging, and notifications. When a class becomes a God class, the usual fix is to split it into smaller collaborators with clearer roles.

## Detailed Explanation
### What SRP actually means
SRP is the first SOLID principle and the easiest one to state incorrectly. “A class should do only one thing” is too vague; the more accurate interview answer is “a class should have one reason to change.” A reason to change is usually tied to one actor or concern: business rules, persistence, formatting, external communication, and so on. If one class changes whenever finance changes pricing rules, DBAs change storage rules, and product changes email wording, that class has multiple responsibilities.

### Cohesion is the positive signal
SRP is closely related to cohesion. A highly cohesive class has fields and methods that all work toward one purpose. A low-cohesion class has unrelated methods grouped together simply because it was convenient. That low cohesion is what often produces a God class: a large object that knows too much, coordinates too much, and becomes the default place for every new requirement.

| Signal | Healthy SRP | SRP violation |
| --- | --- | --- |
| Reason to change | One main reason | Many unrelated reasons |
| Method grouping | Same business concept | Mixed concerns |
| Dependencies | Few, focused | Database, email, logging, mapping, validation all together |
| Testability | Small unit tests | Large setup, many mocks |

### The God class smell in C#
In C# codebases, a God class often appears as `OrderService`, `UserManager`, or `ReportProcessor` with hundreds of lines. It validates input, talks to EF Core or ADO.NET, sends emails, logs audit events, maybe even formats PDFs. The problem is not only size. The deeper issue is that unrelated policies and details are coupled together. That increases merge conflicts, makes tests brittle, and creates fear around changing anything.

> Warning: SRP does **not** mean “every class must be tiny.” Splitting one understandable class into ten microscopic pass-through classes can make the design worse, not better.

### How refactoring usually works
A common refactoring path is:
1. Identify different reasons the class changes.
2. Group methods and fields by concern.
3. Extract cohesive collaborators such as validators, repositories, calculators, or notifiers.
4. Keep one orchestration class if needed, but let it coordinate instead of doing everything itself.

For example, if `OrderProcessor` validates orders, saves them, and emails the customer, those are at least three responsibilities. A better design is an `OrderValidator`, `OrderRepository`, and `EmailNotifier`, with a thin `OrderService` orchestrating them. That separation makes each unit simpler and lets you change storage or notification logic without touching order validation.

### Why SRP matters and its trade-offs
SRP improves maintainability, testability, and readability. Smaller cohesive classes are easier to name, easier to reuse, and easier to replace. It also reduces ripple effects because changing email text should not force a recompilation of pricing logic.

The trade-off is that strict SRP can increase the number of types. More abstractions can mean more files, more dependency wiring, and a harder time understanding the flow if the design becomes over-factored. The goal is not maximum splitting; the goal is clear boundaries around responsibilities that actually change independently.

### When not to over-apply it
If a class is small, stable, and all of its behavior changes for the same business reason, splitting it may add ceremony without value. SRP is most useful when you already see divergent change, difficult testing, large constructors, or frequent edit collisions. In interviews, a strong answer connects SRP to cohesion and to concrete smells such as a God class rather than treating it as a purely theoretical slogan.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace OopAndDesign.SrpSample;

// Before refactoring, one OrderProcessor often validates, saves, and emails.
// After refactoring, each class owns one cohesive responsibility.

public sealed record Order(int Id, decimal Total, string CustomerEmail);

public sealed class OrderValidator
{
    public void Validate(Order order)
    {
        if (order.Total <= 0)
        {
            throw new ArgumentException("Order total must be greater than zero.");
        }

        if (string.IsNullOrWhiteSpace(order.CustomerEmail))
        {
            throw new ArgumentException("Customer email is required.");
        }
    }
}

public sealed class OrderRepository
{
    private readonly List<Order> _orders = [];

    public void Save(Order order)
    {
        _orders.Add(order); // Persistence concern only.
        Console.WriteLine($"Saved order {order.Id}.");
    }
}

public sealed class EmailNotifier
{
    public void SendConfirmation(Order order)
    {
        Console.WriteLine($"Sent confirmation to {order.CustomerEmail}.");
    }
}

public sealed class OrderService(
    OrderValidator validator,
    OrderRepository repository,
    EmailNotifier notifier)
{
    public void Place(Order order)
    {
        validator.Validate(order);       // Validation responsibility.
        repository.Save(order);          // Persistence responsibility.
        notifier.SendConfirmation(order); // Notification responsibility.
    }
}

public static class Program
{
    public static void Main()
    {
        var service = new OrderService(new OrderValidator(), new OrderRepository(), new EmailNotifier());
        service.Place(new Order(1, 125.50m, "customer@example.com"));
    }
}
```

## Common Follow-up Questions
- How is SRP related to cohesion?
- How do you detect a God class in a real codebase?
- Can a method violate SRP, or is SRP only about classes?
- How would SRP influence unit testing strategy?
- What is the difference between SRP and separation of concerns?

## Common Mistakes / Pitfalls
- Defining SRP as “one method per class” instead of “one reason to change.”
- Splitting classes too aggressively and creating an anemic, over-engineered design.
- Leaving orchestration logic spread across many controllers instead of extracting a focused application service.
- Treating class size alone as the problem when the real issue is low cohesion.
- Moving code into helper classes without creating meaningful responsibility boundaries.

## References
- [Architectural principles for modern web applications with Azure](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Object-oriented programming fundamentals in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)
- [Large Class code smell](https://refactoring.guru/smells/large-class)
- [Divergent Change code smell](https://refactoring.guru/smells/divergent-change)
