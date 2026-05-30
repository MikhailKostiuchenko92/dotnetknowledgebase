# Expression Trees

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🔴 Senior
**Tags:** `expression-trees`, `LINQ`, `IQueryable`, `ORM`

## Question
> What is an expression tree in C#, how is `Expression<Func<T>>` different from `Func<T>`, and why do LINQ providers and ORMs care so much about that difference?

## Short Answer
A `Func<T>` is executable compiled code, while an `Expression<Func<T>>` is a data structure that describes code as an object graph. LINQ providers such as Entity Framework Core inspect that graph, translate it into SQL or another query language, and execute it somewhere else instead of running the delegate locally. Expression trees are essential for dynamic queries and ORMs, but they support only an analyzable subset of C# and add complexity you usually avoid in ordinary business logic.

## Detailed Explanation
### Code to execute vs code to inspect
The core distinction is simple: a `Func<T>` is behavior, but an `Expression<Func<T>>` is a description of behavior. When the compiler sees an expression tree lambda, it produces objects from `System.Linq.Expressions` that represent parameters, constants, property access, method calls, and operators.

| Type | Meaning | Typical consumer |
| --- | --- | --- |
| `Func<T>` | Executable delegate | Your process, in-memory collections |
| `Expression<Func<T>>` | Inspectable syntax tree | LINQ providers, ORMs, rule engines |

That difference becomes visible in LINQ. `IEnumerable<T>.Where` takes a delegate because the items are already in memory. `IQueryable<T>.Where` takes an expression tree because the provider needs to inspect the predicate and translate it before execution.

### Why ORMs and LINQ providers depend on expression trees
Entity Framework Core cannot send arbitrary compiled IL to SQL Server. Instead, it captures a query like `db.Products.Where(p => p.Price > 100)` as an expression tree, walks the tree, and translates it into SQL. The database does the filtering, which avoids loading unnecessary rows into memory.

This is why `Expression<Func<T, bool>>` is such a common type in repositories, specifications, and query-building APIs. It gives infrastructure code something analyzable. A compiled delegate would hide the logic inside executable code, and EF Core would have no safe way to convert that to SQL.

> Warning: “it compiles” does not mean “the provider can translate it.” Many expression trees are valid C#, but some method calls or constructs still fail at runtime because the provider has no translation for them.

### Building and compiling trees
Most developers create expression trees with normal lambda syntax, which is concise and readable. But you can also build them manually with the `Expression` API. That is useful when filters are dynamic, for example when a UI lets users choose property names and thresholds at runtime.

Once you have a tree, you can call `.Compile()` to turn it back into a delegate. That is handy for in-memory execution, but compilation is not free. If you repeatedly build and compile equivalent trees on a hot path, you may pay avoidable overhead.

### Trade-offs and practical guidance
Expression trees enable powerful features: strongly typed dynamic queries, remote translation, reusable specifications, and framework extensibility. The downside is complexity. APIs become more abstract, debugging is less direct, and translation rules leak into application design. You also cannot assume every C# construct is supported. Providers typically handle a useful subset, not the entire language.

In interviews, the strongest answer is that expression trees represent code as data. `Func<T>` is for execution. `Expression<Func<T>>` is for inspection and translation. ORMs care because they must understand your query well enough to execute it outside your process.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        List<Product> products =
        [
            new("Keyboard", 120m, true),
            new("Cable", 10m, true),
            new("Monitor", 300m, false)
        ];

        Expression<Func<Product, bool>> expression = BuildMinimumPriceFilter(100m);
        Console.WriteLine($"Tree: {expression}");

        Func<Product, bool> compiled = expression.Compile(); // Compile only when you need local execution.
        string[] matches = products.Where(compiled).Select(p => p.Name).ToArray();

        Console.WriteLine(string.Join(", ", matches));
    }

    private static Expression<Func<Product, bool>> BuildMinimumPriceFilter(decimal minPrice)
    {
        ParameterExpression parameter = Expression.Parameter(typeof(Product), "p");
        MemberExpression price = Expression.Property(parameter, nameof(Product.Price));
        ConstantExpression threshold = Expression.Constant(minPrice);
        BinaryExpression body = Expression.GreaterThanOrEqual(price, threshold);

        return Expression.Lambda<Func<Product, bool>>(body, parameter);
    }
}

internal sealed record Product(string Name, decimal Price, bool InStock);
```

## Common Follow-up Questions
- Why does `IQueryable<T>` usually use expression trees while `IEnumerable<T>` uses delegates?
- What happens when EF Core cannot translate part of an expression tree?
- When would you build an expression tree manually instead of writing a lambda?
- What is the cost of calling `.Compile()` repeatedly?
- Which kinds of C# constructs are commonly problematic for query translation?

## Common Mistakes / Pitfalls
- Treating `Func<T>` and `Expression<Func<T>>` as interchangeable types.
- Calling local helper methods inside ORM queries without checking whether translation is supported.
- Compiling trees too early, which forces local evaluation instead of remote translation.
- Building complicated trees in application code where a simple in-memory delegate would be enough.
- Assuming provider runtime failures are type-safety problems rather than translation limitations.

## References
- [Expression Trees](https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/expression-trees/)
- [How to build dynamic queries](https://learn.microsoft.com/en-us/dotnet/csharp/linq/how-to-build-dynamic-queries)
- [Expression<TDelegate> Class](https://learn.microsoft.com/en-us/dotnet/api/system.linq.expressions.expression-1)
- [How queries work in Entity Framework Core](https://learn.microsoft.com/en-us/ef/core/querying/how-query-works)
