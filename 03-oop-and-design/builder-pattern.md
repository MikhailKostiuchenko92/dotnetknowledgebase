# Builder Pattern

**Category:** OOP & Design / Creational Patterns
**Difficulty:** 🟡 Middle
**Tags:** `builder`, `creational`, `fluent-api`, `immutability`

## Question
> When would you use the Builder pattern in C#, how does a fluent builder help with complex object creation, and why is it often better than telescoping constructors?

## Short Answer
Builder is useful when an object has many optional parts, validation rules, or multi-step construction logic that would make constructors hard to read. A fluent builder lets callers express intent step by step and often produces an immutable result at the end. It is usually better than telescoping constructors because parameter order becomes clearer, defaults are easier to manage, and validation can happen once in `Build()`.

## Detailed Explanation
### What problem Builder solves
Builder addresses construction complexity. If a type needs many optional values, nested settings, or combinations of features, a constructor can become unreadable very quickly. That leads to the telescoping constructor problem: multiple overloaded constructors with slightly different parameter lists, or one huge constructor where half the arguments are optional.

A builder separates **how an object is assembled** from **the final object itself**. Instead of calling one massive constructor, client code describes the desired configuration step by step and then calls `Build()`.

### Fluent API and immutable result
In C#, builders are often exposed as fluent APIs where each method returns the builder itself. That enables readable chains such as `WithHost(...).UseSsl().WithTimeout(...)`. Internally, the builder stores temporary mutable state. When `Build()` is called, it validates that state and returns the final object, which is commonly immutable.

| Approach | Strength | Weakness |
| --- | --- | --- |
| Telescoping constructors | No extra type needed | Hard to read and maintain as options grow. |
| Object initializer | Good for simple DTOs | Weak for invariants or ordered construction steps. |
| Builder | Clear intent + central validation | Adds another abstraction and more code. |

This is why Builder is popular for configuration objects, HTTP requests, report definitions, query objects, and test data setup.

### How it works internally
A typical builder has methods that set individual options and a `Build()` method that creates the product. Some implementations also use a “director” object that defines standard build sequences, but in modern C# the fluent builder itself is often enough.

The most important implementation detail is validation. Builders are not valuable just because method chaining looks nice. They are valuable because they provide one place to enforce invariants before the final object is created. For example, a builder can reject a missing base URL or a negative timeout.

> Warning: A builder should not silently produce invalid objects. If construction rules matter, validate in `Build()` and fail fast.

### Why it matters
Builder improves readability and makes call sites self-documenting. `WithPort(443)` is easier to understand than passing `443` as the sixth constructor argument. It also reduces accidental bugs caused by parameter ordering, especially when many parameters share the same type.

Builder also pairs well with immutability. The builder can be mutable during assembly, while the resulting record or class is immutable after creation. That gives you safer runtime behavior without making the construction process painful.

### Trade-offs and when not to use it
Builder adds ceremony. If a type has only two or three obvious parameters, a constructor or static factory is simpler. Overusing Builder can make a codebase verbose and create classes whose only job is to move values around.

Also remember that modern C# offers alternatives such as optional parameters, object initializers, `required` members, and records with `init` setters. Those tools cover many simple cases. Builder becomes worth it when you need richer validation, construction sequencing, reusable presets, or a particularly expressive fluent API.

In interviews, the key idea is: Builder is for making complex construction readable and safe, especially when the final object should be immutable.

## Code Example
```csharp
using System;

namespace KnowledgeBase.OopDesign;

public sealed record ApiClientOptions(string BaseUrl, int TimeoutSeconds, bool UseRetry, string ApiKey);

public sealed class ApiClientOptionsBuilder
{
    private string? _baseUrl;
    private int _timeoutSeconds = 30;
    private bool _useRetry;
    private string _apiKey = "demo-key";

    public ApiClientOptionsBuilder WithBaseUrl(string baseUrl)
    {
        _baseUrl = baseUrl;
        return this; // Fluent chaining.
    }

    public ApiClientOptionsBuilder WithTimeoutSeconds(int timeoutSeconds)
    {
        _timeoutSeconds = timeoutSeconds;
        return this;
    }

    public ApiClientOptionsBuilder EnableRetry()
    {
        _useRetry = true;
        return this;
    }

    public ApiClientOptionsBuilder WithApiKey(string apiKey)
    {
        _apiKey = apiKey;
        return this;
    }

    public ApiClientOptions Build()
    {
        // Centralized validation before creating the immutable result.
        if (string.IsNullOrWhiteSpace(_baseUrl))
            throw new InvalidOperationException("BaseUrl is required.");

        if (_timeoutSeconds <= 0)
            throw new InvalidOperationException("Timeout must be positive.");

        return new ApiClientOptions(_baseUrl, _timeoutSeconds, _useRetry, _apiKey);
    }
}

internal static class Program
{
    private static void Main()
    {
        var options = new ApiClientOptionsBuilder()
            .WithBaseUrl("https://api.contoso.test")
            .WithTimeoutSeconds(10)
            .EnableRetry()
            .WithApiKey("secret-from-config")
            .Build();

        Console.WriteLine(options);
    }
}
```

## Common Follow-up Questions
- How is Builder different from object initializers or optional parameters?
- When should the final object be immutable?
- What is the role of a Director, and do you always need one?
- How would you validate required fields in a Builder implementation?
- Can builders be reused safely across threads?

## Common Mistakes / Pitfalls
- Using Builder for very small objects where a constructor would be clearer.
- Returning partially built or invalid objects instead of validating in `Build()`.
- Reusing the same mutable builder instance across requests or threads.
- Treating fluent syntax as the goal instead of construction safety and readability.
- Forgetting reasonable defaults, which makes the builder noisy instead of helpful.

## References
- [Builder](https://refactoring.guru/design-patterns/builder)
- [Object and Collection Initializers - C#](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/object-and-collection-initializers)
- [The init keyword - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/init)
- [required modifier - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/required)
