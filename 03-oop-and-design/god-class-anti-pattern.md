# God Class Anti-Pattern

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟢 Junior
**Tags:** `god-class`, `anti-pattern`, `cohesion`, `refactoring`

## Question
> What is a God class, why is it a problem, and how would you refactor one safely?

## Short Answer
A God class is a class that knows too much and does too much, so unrelated behavior accumulates in one place. That creates low cohesion, too many reasons to change, and code that is difficult to test because every feature touches the same type. The usual fix is incremental refactoring: identify responsibility clusters, extract focused collaborators, and move behavior closer to the data it actually uses.

## Detailed Explanation
### What a God class really is
A God class, sometimes called a God object, is the opposite of a focused abstraction. It handles validation, business rules, persistence, logging, notifications, mapping, and reporting all from one central type. In many codebases the smell is visible from the class name itself: `Manager`, `Helper`, `Processor`, or `Service` with dozens of methods and dependencies.

| Symptom | What it suggests |
| --- | --- |
| Huge file with many unrelated methods | Responsibilities are accumulating |
| Many constructor dependencies | The class coordinates too much |
| Frequent merge conflicts | Multiple features change the same type |
| Vague name | The abstraction is not real |

The root problem is usually low cohesion. Cohesion means the members of a class naturally belong together. In a God class, they do not. The class becomes a dumping ground because adding “just one more method” feels cheaper than designing a better boundary.

### Why it happens
God classes almost never appear by design. They grow gradually under delivery pressure. Teams keep adding logic to the existing “central” class because it already has access to the needed data and dependencies. The local change is faster, but the long-term result is a hotspot that every developer fears touching.

A related smell is **feature envy**. If a method spends most of its time reading another object’s data and making decisions on that object’s behalf, the behavior probably belongs on that other object or in a more focused collaborator. Feature envy often points directly to an extractable responsibility.

> Warning: renaming `OrderManager` to `OrderService` does not fix a God class. The problem is responsibility concentration, not terminology.

### Why it hurts maintainability
The biggest cost is change amplification. A small requirement can force retesting of pricing, persistence, notification, and formatting because all of that logic lives in one type. Testing also becomes harder because the class depends on too many things at once, so unit tests are full of brittle mocks.

This smell also damages design communication. When one class becomes the place where “everything happens,” the object model stops reflecting the domain. New developers learn to search for the big class instead of understanding the system structure.

### How to refactor it safely
The goal is not to explode one large class into twenty arbitrary tiny classes. The goal is to restore meaningful boundaries. A good sequence is:
1. Add tests around the risky behavior.
2. Find behavior clusters that change together.
3. Apply **Extract Class** and **Move Method**.
4. Move domain rules near domain data, and infrastructure work to infrastructure collaborators.

Keep orchestration thin. It is fine to have an application service that coordinates pricing, persistence, and messaging, as long as it does not also own all of those rules internally.

In interviews, the best answer connects the smell to low cohesion and too many reasons to change, then explains that the fix is incremental extraction rather than a heroic rewrite.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        Order order = new("ORD-1001", [new("Keyboard", 2, 50m), new("Mouse", 1, 25m)]);

        var bad = new BadOrderManager();
        Console.WriteLine($"Bad total: {bad.Process(order):C}");

        var good = new OrderApplicationService(new OrderPricingService(), new OrderRepository(), new ReceiptSender());
        Console.WriteLine($"Refactored total: {good.Process(order):C}");
    }
}

internal sealed record Order(string Id, IReadOnlyList<OrderLine> Lines);
internal sealed record OrderLine(string Product, int Quantity, decimal UnitPrice);

internal sealed class BadOrderManager
{
    public decimal Process(Order order)
    {
        // Bad: validation, pricing, persistence, and notification are all mixed.
        if (order.Lines.Count == 0)
        {
            throw new InvalidOperationException("Order must contain at least one line.");
        }

        decimal total = order.Lines.Sum(line => line.Quantity * line.UnitPrice);
        Console.WriteLine($"Saving {order.Id}...");
        Console.WriteLine($"Sending receipt for {order.Id}...");
        return total;
    }
}

internal sealed class OrderApplicationService(OrderPricingService pricing, OrderRepository repository, ReceiptSender sender)
{
    public decimal Process(Order order)
    {
        decimal total = pricing.Calculate(order); // Business rule in a focused collaborator.
        repository.Save(order);                   // Infrastructure concern isolated.
        sender.Send(order.Id, total);
        return total;
    }
}

internal sealed class OrderPricingService
{
    public decimal Calculate(Order order)
    {
        if (order.Lines.Count == 0)
        {
            throw new InvalidOperationException("Order must contain at least one line.");
        }

        return order.Lines.Sum(line => line.Quantity * line.UnitPrice);
    }
}

internal sealed class OrderRepository
{
    public void Save(Order order) => Console.WriteLine($"Saving {order.Id}...");
}

internal sealed class ReceiptSender
{
    public void Send(string orderId, decimal total) => Console.WriteLine($"Sending receipt for {orderId}: {total:C}");
}
```

## Common Follow-up Questions
- How is a God class related to low cohesion and high coupling?
- What is the difference between a large class and a God class?
- Which refactorings would you apply first if the class is risky to change?
- How does feature envy help you decide where behavior should move?
- Can an application service depend on many collaborators without being a God class?

## Common Mistakes / Pitfalls
- Calling every large class a God class without checking whether its responsibilities are actually cohesive.
- Splitting one God class into many tiny wrappers while leaving the behavior in the wrong place.
- Refactoring aggressively without tests and breaking hidden behavior.
- Confusing orchestration code with domain logic and putting both into the same service.
- Renaming the type but keeping all the same responsibilities.

## References
- [Large Class](https://refactoring.guru/smells/large-class)
- [Feature Envy](https://refactoring.guru/smells/feature-envy)
- [Extract Class](https://refactoring.guru/extract-class)
- [Common Web Application Architectures](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
