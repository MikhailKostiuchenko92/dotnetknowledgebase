# Adapter Pattern

**Category:** OOP & Design / Structural Patterns
**Difficulty:** 🟢 Junior
**Tags:** `adapter`, `structural`, `legacy-code`, `wrapper`

## Question
> What is the Adapter pattern, and when would you use it to wrap legacy code in C#? Also, what is the difference between a class adapter and an object adapter?

## Short Answer
The Adapter pattern lets two incompatible interfaces work together by translating one API into another that the client expects. In .NET, it is commonly used to wrap legacy code, third-party libraries, or awkward infrastructure APIs without changing the client code. In C#, object adapters are far more common because they use composition, while class adapters rely on inheritance and are limited by single inheritance.

## Detailed Explanation
### What problem Adapter solves
Adapter is a structural pattern that sits between a client and an existing class whose interface does not match what the client wants. The client talks to a clean, application-friendly contract, while the adapter translates calls to the legacy or external API. That is useful when you cannot change the old code, do not own the third-party package, or want to keep ugly compatibility logic away from the rest of the system.

A typical .NET example is wrapping an old SOAP client, XML-based API, or static helper library behind an interface such as `IPaymentGateway` or `IPriceFeed`. The rest of the application depends on your interface, not on the old dependency.

### Class adapter vs object adapter
The classic GoF pattern distinguishes two styles:

| Style | How it works | Pros | Cons |
| --- | --- | --- | --- |
| Class adapter | Inherits from the adaptee and implements the target interface | Simple call forwarding, can override base behavior | Rare in C# because you only get single inheritance |
| Object adapter | Holds the adaptee as a field and implements the target interface | Flexible, testable, can wrap sealed classes and swap implementations | Slightly more boilerplate |

In C#, object adapters are usually preferred because composition is more flexible and fits dependency injection. A class adapter may still work when the legacy type is inheritable and the target is an interface, but it is not the default choice.

### How it works internally
Internally, an adapter performs translation. That translation may be as small as renaming a method, or as large as converting data formats, exceptions, units, or asynchronous behavior. For example, an adapter might convert `string` prices into `decimal`, map a legacy DTO to a domain model, or catch vendor-specific exceptions and rethrow application-specific ones.

A small generic contract such as `IAdapter<T>` can make the intent explicit: the class exists to expose something in a different shape. In real systems, though, the more important contract is usually the target interface used by the application, such as `IPriceFeed`.

> Warning: if the adapter starts containing business rules, retries, caching, and validation all at once, it is no longer “just an adapter.” At that point, split responsibilities into separate services or decorators.

### Why it matters
Adapter reduces coupling. Your application code becomes stable even if the legacy API changes slowly or is difficult to test. It also improves migration: you can introduce a new interface, adapt the old implementation today, and replace the underlying system later with minimal client changes.

This is especially helpful in refactoring legacy .NET applications. You can carve out seams around old code instead of rewriting everything at once. That lowers risk and supports incremental modernization.

### Trade-offs and when not to use it
Adapter adds one more layer, so debugging can involve an extra hop. Poor adapters can also hide inefficient or leaky abstractions. If the old interface is already acceptable, adding an adapter may be unnecessary indirection.

Do not confuse Adapter with Facade. A facade simplifies a subsystem; an adapter translates one interface into another. Also, do not use adapters as a permanent excuse to keep a broken domain model forever. Sometimes the right solution is to fix the underlying contract.

## Code Example
```csharp
using System.Globalization;

namespace OopDesignSamples;

public interface IPriceFeed
{
    decimal GetPrice(string sku);
}

public interface IAdapter<out T>
{
    T Adapt();
}

public sealed class LegacyPriceService
{
    public string FetchPrice(string sku)
    {
        // Legacy code returns strings instead of decimals.
        return sku.ToLowerInvariant() switch
        {
            "book-1" => "19.99",
            _ => "0.00"
        };
    }
}

public sealed class PriceFeedAdapter(LegacyPriceService legacyService)
    : IPriceFeed, IAdapter<IPriceFeed>
{
    private readonly LegacyPriceService _legacyService = legacyService;

    public IPriceFeed Adapt() => this;

    public decimal GetPrice(string sku)
    {
        var raw = _legacyService.FetchPrice(sku); // Translate legacy output.
        return decimal.Parse(raw, CultureInfo.InvariantCulture);
    }
}

public static class Program
{
    public static void Main()
    {
        IPriceFeed priceFeed = new PriceFeedAdapter(new LegacyPriceService()).Adapt();
        Console.WriteLine($"Price: {priceFeed.GetPrice("book-1"):C}");
    }
}
```

## Common Follow-up Questions
- How is Adapter different from Facade and Decorator?
- Why is object adapter usually preferred over class adapter in C#?
- Where would you place an adapter in Clean Architecture?
- Should an adapter convert exceptions or let vendor exceptions leak out?
- Can an adapter also handle async-to-sync or sync-to-async translation?

## Common Mistakes / Pitfalls
- Letting the rest of the codebase depend directly on the legacy type instead of the target interface.
- Putting business rules inside the adapter instead of only translation logic.
- Creating an adapter when simple renaming or refactoring of your own code would be cleaner.
- Assuming inheritance-based class adapters are always possible in C#.
- Forgetting to translate legacy error types, null semantics, or units consistently.

## References
- [Adapter](https://refactoring.guru/design-patterns/adapter)
- [Anti-Corruption Layer pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer)
- [Dependency injection in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/overview)
