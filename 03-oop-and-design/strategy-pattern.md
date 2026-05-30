# Strategy Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟢 Junior
**Tags:** `strategy`, `behavioral`, `func`, `algorithm`

## Question
> What is the Strategy pattern, and when would you use it instead of a big `if`/`switch` block?

## Short Answer
The Strategy pattern encapsulates a family of algorithms behind a common contract so the caller can swap them without changing its own code. It is useful when the behavior varies, but the workflow around that behavior stays the same. In C#, a full interface-based strategy is common, but for very small variations a `Func<T>` or `Comparison<T>` can act as a lightweight strategy.

## Detailed Explanation
### What it is
Strategy is a behavioral pattern that turns interchangeable behavior into separate objects. Instead of one class containing branching logic for every variation, you define a common abstraction and move each algorithm into its own implementation. The calling class depends on the abstraction, not on concrete branches.

A classic example is sorting. You may want to sort products by price, name, popularity, or some custom score. The calling code should not need to know the details of each algorithm; it should only ask for sorting to happen.

### How it works internally
There are usually three parts:

1. **Context** – the class that uses the algorithm.
2. **Strategy contract** – an interface or delegate describing the behavior.
3. **Concrete strategies** – the actual algorithms.

At runtime, the context receives one strategy and delegates the varying work to it. That makes the object graph more composable and easier to test because you can inject a fake or alternate strategy.

In C#, you do not always need a whole class hierarchy. If the variation is a single operation, a delegate can be enough.

| Approach | Best for | Trade-off |
| --- | --- | --- |
| Interface-based strategy | Rich behavior, dependencies, testability | More types and ceremony |
| `Func<T>` / delegate | Small one-off variations | Less self-documenting, harder to extend |
| `if` / `switch` | Tiny, stable logic | Grows into rigid branching quickly |

### Why it matters
The real value is not “fewer `if` statements.” It is **separating what changes from what stays stable**. The surrounding workflow can remain simple while the algorithm changes independently. That improves maintainability, supports Open/Closed Principle, and makes unit tests smaller because each strategy can be tested in isolation.

It also helps when behavior comes from configuration, user choice, feature flags, or dependency injection. You can register different strategies and select one at runtime without rewriting the caller.

> Strategy is about interchangeable behavior. If the “algorithm choices” are unlikely to change or only differ by one line, a full pattern may be unnecessary.

### Trade-offs and when not to use it
Strategy introduces extra types and indirection. For a tiny application, that can feel heavier than a local `switch`. It can also become over-engineered if every minor variation gets a class.

Use Strategy when:
- you have multiple valid ways to perform the same task;
- callers should not know the details of the chosen algorithm;
- you want to unit test the behavior independently.

Avoid it when:
- there is only one stable algorithm;
- the variation is trivial and unlikely to grow;
- inheritance or polymorphism would add more complexity than value.

A good interview answer also mentions that modern C# gives you two levels of Strategy: **objects for richer policies** and **delegates for lightweight policies**.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace OopAndDesign.StrategyPattern;

public sealed record Product(string Name, decimal Price);

public interface IProductOrderingStrategy
{
    IEnumerable<Product> Order(IEnumerable<Product> products);
}

public sealed class SortByPriceAscending : IProductOrderingStrategy
{
    public IEnumerable<Product> Order(IEnumerable<Product> products) =>
        products.OrderBy(product => product.Price);
}

public sealed class SortByName : IProductOrderingStrategy
{
    public IEnumerable<Product> Order(IEnumerable<Product> products) =>
        products.OrderBy(product => product.Name);
}

public sealed class ProductSorter
{
    public IEnumerable<Product> Sort(IEnumerable<Product> products, IProductOrderingStrategy strategy) =>
        strategy.Order(products);

    public IEnumerable<Product> Sort(
        IEnumerable<Product> products,
        Func<IEnumerable<Product>, IEnumerable<Product>> strategy) =>
        strategy(products); // Lightweight strategy via delegate.
}

public static class Program
{
    public static void Main()
    {
        var products = new[]
        {
            new Product("Keyboard", 120m),
            new Product("Mouse", 40m),
            new Product("Monitor", 300m)
        };

        var sorter = new ProductSorter();

        var byPrice = sorter.Sort(products, new SortByPriceAscending());
        Console.WriteLine("Interface-based strategy:");
        foreach (var product in byPrice)
        {
            Console.WriteLine($"{product.Name}: {product.Price}");
        }

        var byNameDescending = sorter.Sort(
            products,
            items => items.OrderByDescending(product => product.Name));

        Console.WriteLine();
        Console.WriteLine("Delegate-based strategy:");
        foreach (var product in byNameDescending)
        {
            Console.WriteLine($"{product.Name}: {product.Price}");
        }
    }
}
```

## Common Follow-up Questions
- How is Strategy different from Template Method?
- When is a delegate enough instead of a strategy class?
- How would you choose a strategy with dependency injection?
- Is Strategy still useful if there are only two algorithms?
- How do you test a class that depends on a strategy?

## Common Mistakes / Pitfalls
- Creating a strategy class for every tiny variation and over-engineering the design.
- Letting the context know too much about specific strategies, which defeats the abstraction.
- Using Strategy when the algorithm is effectively fixed and will never vary.
- Hiding important business rules inside anonymous delegates that become hard to discover.

## References
- [Strategy pattern - Refactoring.Guru](https://refactoring.guru/design-patterns/strategy)
- [Delegates - C# Programming Guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/delegates/)
- [Lambda expressions - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/lambda-expressions)
- [Comparison<T> Delegate](https://learn.microsoft.com/dotnet/api/system.comparison-1)
