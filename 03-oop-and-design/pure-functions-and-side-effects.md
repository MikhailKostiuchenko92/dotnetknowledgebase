# Pure Functions and Side Effects

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🟢 Junior
**Tags:** `functional`, `pure-functions`, `side-effects`, `testability`

## Question
> What is a pure function, what are side effects, and why do pure functions make code easier to test?

## Short Answer
A pure function always returns the same output for the same input and does not change anything outside itself. That property is often called referential transparency: you can replace the call with its result and the program still behaves the same. Pure functions are easier to test, reason about, and run safely in parallel, but in real applications you still need controlled side effects for I/O, databases, logging, and time.

## Detailed Explanation
### What makes a function pure
A function is pure when it has two properties:

1. **Deterministic output**: the same inputs always produce the same output.
2. **No observable side effects**: it does not mutate shared state, write files, call a database, log, read the clock, or depend on random values unless those are passed in as inputs.

That means `Add(2, 3)` is pure, but `GetPriceWithCurrentTax()` is usually impure if it reads configuration, time, or shared mutable state internally.

| Characteristic | Pure function | Impure function |
| --- | --- | --- |
| Output stability | Same input, same output | May vary between calls |
| State changes | None outside return value | May change external state |
| Hidden dependencies | Avoided | Common |
| Testability | Very high | Often needs mocks or setup |

### Referential transparency and why it matters
Referential transparency means an expression can be replaced with its value without changing program behavior. If `CalculateVat(100m, 0.2m)` always returns `20m`, then anywhere that call appears, you can mentally replace it with `20m`.

That sounds academic, but it matters in interviews and production code because it reduces cognitive load. You do not need to ask, “Did this method also update a cache, read the system clock, or mutate a field?” With pure code, the answer is no.

> Warning: reading `DateTime.UtcNow`, `Guid.NewGuid()`, `Random.Shared`, environment variables, or static mutable state makes a function impure unless those values are supplied as inputs.

### Why pure functions improve testability
Pure functions are easy to test because tests only need input and expected output. There is no mocking of repositories, clocks, HTTP clients, or static singletons. They are also easier to debug: if a test fails, the cause is usually in the transformation logic, not in test setup.

Purity also helps with concurrency. If a function does not mutate shared state, two threads can run it at the same time without locks. That does not make the whole application thread-safe, but it reduces the number of places where thread-safety is even a concern.

### When purity is not practical
Real applications cannot be 100% pure. Web APIs must read requests, query databases, publish messages, and write logs. The practical goal in C# is usually **not** “make everything pure,” but “push side effects to the edges.”

A common design is:
- Keep domain calculations pure.
- Put I/O in application services, repositories, controllers, or infrastructure adapters.
- Pass dependencies like time, random values, or configuration into pure logic instead of reading them internally.

For example, instead of calling `DateTime.UtcNow` inside discount logic, pass `now` into the method. That small change makes behavior explicit and testable.

### Trade-offs and interview-ready nuance
Pure style can add extra parameters or small wrapper types, which some teams see as more verbose. Also, copying data instead of mutating it may create more allocations in hot paths. In most business code, the clarity benefit is worth it, but in performance-critical code you should measure instead of assuming.

So the balanced answer is: pure functions are ideal for business rules and transformations, but side effects are unavoidable at system boundaries. Strong designs isolate impurity rather than pretending it does not exist.

## Code Example
```csharp
using System;

namespace OopAndDesign.FunctionalPatterns;

public static class Program
{
    public static void Main()
    {
        decimal subtotal = 100m;
        decimal taxRate = 0.20m;
        decimal discount = 10m;

        // Pure functions: output depends only on input arguments.
        decimal total = Pricing.CalculateTotal(subtotal, taxRate, discount);
        Console.WriteLine($"Pure total: {total}");

        // The impure method reads the current clock instead of receiving it.
        Console.WriteLine($"Impure stamp: {Pricing.CreateAuditMessage()}");
    }
}

public static class Pricing
{
    public static decimal CalculateTotal(decimal subtotal, decimal taxRate, decimal discount)
    {
        decimal taxedAmount = subtotal * (1 + taxRate);
        return taxedAmount - discount;
    }

    public static string CreateAuditMessage()
    {
        // Reading the system clock is a side effect dependency.
        return $"Calculated at {DateTime.UtcNow:O}";
    }
}
```

## Common Follow-up Questions
- How would you make time-dependent logic testable without calling `DateTime.UtcNow` directly?
- Are local variable mutations inside a method considered a side effect?
- Why do pure functions help with parallel execution?
- What parts of an ASP.NET Core application are naturally impure?
- Can a method that writes to a cache still be considered pure if it returns the same value?

## Common Mistakes / Pitfalls
- Assuming a function is pure just because it does not write to a database, while it still reads hidden state like the current time.
- Confusing local mutation with external side effects; changing a local variable is fine if nothing outside observes it.
- Trying to force purity into infrastructure code where I/O is the whole purpose.
- Treating `Random.Shared`, static fields, or ambient context as harmless dependencies.
- Ignoring performance trade-offs when copying large object graphs to avoid mutation.

## References
- [Functional programming vs. imperative programming](https://learn.microsoft.com/en-us/dotnet/standard/linq/functional-vs-imperative-programming)
- [Functional design is intrinsically testable](https://blog.ploeh.dk/2015/05/07/functional-design-is-intrinsically-testable/)
- [Lambda expressions - C# reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/lambda-expressions)
- [Work with delegate types in C#](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/delegates/)
